#!/usr/bin/env bash
# Run nvidia-smi on all GPU nodes by exec'ing into the NVIDIA Device Plugin pods.
# It derives the label selector from the DaemonSet to avoid hard-coding labels.

set -euo pipefail

NS="${NS:-gpu-operator}"
DS_NAME="${DS_NAME:-nvidia-device-plugin-daemonset}"
# Try these containers in order until one accepts nvidia-smi
CANDIDATE_CONTAINERS=("nvidia-device-plugin" "driver" "nvidia-driver" "toolkit" "dcgm" "validator")

log()  { printf "%s\n" "$*"; }
err()  { printf "❌ %s\n" "$*" >&2; }
hr()   { printf "%s\n" "-----------------------------------------"; }

# --- Build selector from the DaemonSet's spec.selector.matchLabels
build_selector() {
  local sel
  if ! kubectl get ds -n "$NS" "$DS_NAME" >/dev/null 2>&1; then
    return 1
  fi
  sel="$(kubectl get ds -n "$NS" "$DS_NAME" \
        -o go-template='{{range $k,$v := .spec.selector.matchLabels}}{{printf "%s=%s," $k $v}}{{end}}')"
  sel="${sel%,}" # trim trailing comma
  if [[ -n "$sel" ]]; then
    printf "%s" "$sel"
    return 0
  fi
  return 2
}

selector=""
if selector="$(build_selector)"; then
  :
else
  # Fallbacks seen in GPU Operator deployments
  for try in \
    "name=$DS_NAME" \
    "app.kubernetes.io/name=nvidia-device-plugin" \
    "app=nvidia-device-plugin" \
    "app=$DS_NAME" ; do
    if kubectl get pods -n "$NS" -l "$try" --no-headers 2>/dev/null | grep -q .; then
      selector="$try"
      break
    fi
  done
fi

if [[ -z "${selector:-}" ]]; then
  err "Could not derive a pod selector from DaemonSet '$DS_NAME' in namespace '$NS'."
  log "Hint: check labels with:"
  log "  kubectl get ds -n $NS $DS_NAME -o yaml | yq '.spec.selector.matchLabels'"
  exit 1
fi

log "🔍 Using selector: $selector"
pods=$(kubectl get pods -n "$NS" -l "$selector" -o name 2>/dev/null || true)

if [[ -z "$pods" ]]; then
  err "No pods found for selector '$selector' in namespace '$NS'."
  log "Quick peek:"
  kubectl get pods -n "$NS" -o wide || true
  exit 1
fi

log ""
log "🚀 Executing nvidia-smi on all GPU nodes:"
hr

rc_all=0
for pod in $pods; do
  pod_name=${pod##*/}
  node_name="$(kubectl get pod -n "$NS" "$pod_name" -o jsonpath='{.spec.nodeName}')"
  printf "🖥️  Node: %s\n📦 Pod: %s\n" "$node_name" "$pod_name"
  hr
  ran=0
  for c in "${CANDIDATE_CONTAINERS[@]}"; do
    if kubectl exec -n "$NS" "$pod_name" -c "$c" -- sh -c 'command -v nvidia-smi >/dev/null 2>&1' 2>/dev/null; then
      if kubectl exec -n "$NS" -c "$c" "$pod_name" -- nvidia-smi; then
        ran=1
        break
      fi
    fi
  done
  if [[ $ran -eq 0 ]]; then
    # try without specifying -c (works if single-container pod)
    if kubectl exec -n "$NS" "$pod_name" -- sh -c 'nvidia-smi || command -v nvidia-smi || true' 2>/dev/null; then
      ran=1
    fi
  fi
  if [[ $ran -eq 0 ]]; then
    err "Failed to run nvidia-smi in pod $pod_name on node $node_name"
    rc_all=1
  fi
  echo
done

exit $rc_all
