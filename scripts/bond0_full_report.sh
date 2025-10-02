#!/usr/bin/env bash
# ----------------------------------------------------------------------
# bond_status.sh
#   • Prints a nicely‑formatted “global” section for a bonding device.
#   • Prints a compact, pipe‑separated table for each slave (your awk
#     program) – the global Partner‑MAC address is injected automatically.
#
# Usage:   ./bond0_full_report.sh <dpu ip>
# Example: ./bond0_full_report.sh worker1-dpu
# ----------------------------------------------------------------------

set -euo pipefail

# ---------- helpers ----------------------------------------------------
die() { echo "ERROR: $*" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: $(basename "$0") <dpu ip>

Prints

  1) a readable block with the bond‑level (global) configuration
  2) a one‑line‑per‑slave LACP summary (your original awk script)

EOF
    exit 0
}

# ---------- argument handling -------------------------------------------
[[ "${1-}" == "-h" || "${1-}" == "--help" ]] && usage
[[ $# -ne 1 ]] && die "Exactly one argument (bond interface) required."

IP="${1}"
BOND="bond0"
PROC="/tmp/bond0-proc$$"
ssh ubuntu@$IP sudo cat /proc/net/bonding/$BOND > $PROC

[[ -f "$PROC" ]] || die "File $PROC does not exist – is $BOND a bonding device?"

# ----------------------------------------------------------------------
# 1) GLOBAL SECTION
# ----------------------------------------------------------------------
# Extract the fields we want, give them a short “pretty” name,
# then feed to `column` for alignment.
global_info=$(awk -v iface="$BOND" '
BEGIN {
    # map raw keys → pretty names (empty value means “skip this line”)
    map["Ethernet Channel Bonding Driver"] = "Driver"
    map["Bonding Mode"]                     = "Mode"
    map["Transmit Hash Policy"]             = "Hash Policy"
    map["MII Status"]                       = "MII Status"
    map["MII Polling Interval"]             = "MII Polling Interval (ms)"
    map["Up Delay"]                         = "Up Delay (ms)"
    map["Down Delay"]                       = "Down Delay (ms)"
    map["Peer Notification Delay"]         = "Peer Notification Delay (ms)"
    map["LACP active"]                      = "LACP active"
    map["LACP rate"]                        = "LACP rate"
    map["Min links"]                        = "Min links"
    map["Aggregator selection policy"]      = "Aggregator selection policy"
    map["System priority"]                  = "System priority"
    map["System MAC address"]               = "System MAC address"
    map["Active Aggregator Info"]           = ""          # start of a sub‑block
    map["Aggregator ID"]                    = "Active Aggregator ID"
    map["Number of ports"]                  = "Number of ports"
    map["Actor Key"]                        = "Actor Key"
    map["Partner Key"]                      = "Partner Key"
    map["Partner Mac Address"]              = "Partner MAC address"
}
# Ignore completely empty lines
/^[[:space:]]*$/ { next }

{
    # split the line at the first colon
    split($0, kv, ":")
    raw = kv[1]; sub(/[[:space:]]+$/,"",raw)   # trim trailing blanks
    val = ""; if (length(kv) > 1) { val = kv[2]; sub(/^[[:space:]]+/,"",val) }

    if (raw in map) {
        pretty = map[raw]
        if (pretty != "") {
            printf "%s|%s\n", pretty, val
        } else {
            # we have entered the “Active Aggregator Info” sub‑section
            in_agg = 1
        }
    } else if (in_agg && (raw in map)) {
        pretty = map[raw]
        if (pretty != "") printf "%s|%s\n", pretty, val
    }
}
' "$PROC" | column -t -s'|')

# Print the global block with a decorative header
printf "─── $IP Bond “%s” ────────────────────────────────────────────────────────────────────────\n" "$BOND"
printf "%s\n\n" "$global_info"

# ----------------------------------------------------------------------
# 2) PER‑SLAVE SECTION (your original awk program)
# ----------------------------------------------------------------------
# First, pull the *Partner MAC address* out of the global block – this is the
# same value we used above, but we keep a separate variable for the awk
# program (the awk script expects the variable name `partner_mac_global`).
partner_mac=$(awk -F': *' '
    $1 ~ /Partner[[:space:]]*Mac[[:space:]]*Address/ { print $2; exit }
' "$PROC")
partner_mac=${partner_mac:-"-"}

# Run the awk program you supplied, feeding it the whole /proc file and the
# extracted partner‑MAC address.
awk -v partner_mac_global="${partner_mac}" '
  # ------------------------------------------------------------------
  # Helper functions (unchanged from your original script)
  # ------------------------------------------------------------------
  function fmt_speed(s) {
    gsub(/[^0-9]/,"", s)
    if (s == "") return "-"
    if (s >= 1000) return int(s/1000) "G"
    return s "M"
  }
  function hasbit(v, bit) { return int((v+0)/bit) % 2 }

  function dec_state(n,    v,out) {
    v = (n + 0)
    if (hasbit(v,1))   out=out "activity,"
    if (hasbit(v,2))   out=out "timeout,"
    if (hasbit(v,4))   out=out "aggregation,"
    if (hasbit(v,8))   out=out "sync,"
    if (hasbit(v,16))  out=out "collecting,"
    if (hasbit(v,32))  out=out "distributing,"
    if (hasbit(v,64))  out=out "defaulted,"
    if (hasbit(v,128)) out=out "expired,"
    if (out == "") return "-"
    sub(/,$/, "", out); return out
  }

  function print_row() {
    if (iface == "") return
    printf "%-6s %-4s %-6s %-7s %-5s %-5s | %-6s %-9s %-10s | %-6s %-9s %-10s | %s\n",
      iface, mii, fmt_speed(speed), duplex, fails, aggid,
      a_port_num, a_key, dec_state(a_state),
      p_port_num, p_key, dec_state(p_state),
      partner_mac_global
  }

  # ------------------------------------------------------------------
  # Header (printed once, before the first slave)
  # ------------------------------------------------------------------
  BEGIN {
    printf "%-6s %-4s %-6s %-7s %-5s %-5s | %-6s %-9s %-10s | %-6s %-9s %-10s | %s\n",
           "IFACE","MII","SPD","DUPLEX","FAIL","AGGID",
           "A_PNUM","A_KEY","A_STATE",
           "P_PNUM","P_KEY","P_STATE",
           "PARTNER_MAC"
  }

  # ------------------------------------------------------------------
  # Record parsing – each “Slave Interface:” line starts a new record
  # ------------------------------------------------------------------
  /^Slave Interface:/ {
    print_row()
    iface=$0; sub(/^Slave Interface:[[:space:]]*/, "", iface)
    mii=speed=duplex=fails=aggid="-"
    a_key=a_state=a_port_num="-"
    p_key=p_state=p_port_num="-"
    in_actor=in_partner=0
    next
  }
  /^MII Status:/               { mii=$2; next }
  /^Speed:/                    { speed=$2; next }
  /^Duplex:/                   { duplex=$2; next }
  /^Link Failure Count:/       { fails=$NF; next }
  /^Aggregator ID:/            { aggid=$NF; next }

  /^details actor lacp pdu:/   { in_actor=1;   in_partner=0; next }
  /^details partner lacp pdu:/ { in_partner=1; in_actor=0;   next }

  in_actor   && /port key:/    { a_key=$NF; next }
  in_actor   && /port number:/ { a_port_num=$NF; next }
  in_actor   && /port state:/  { a_state=$NF; next }

  in_partner && /(oper key|port key):/ { p_key=$NF; next }
  in_partner && /port number:/         { p_port_num=$NF; next }
  in_partner && /port state:/          { p_state=$NF; next }

  END { print_row() }
' "$PROC"
