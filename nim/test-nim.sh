#!/usr/bin/env bash
set -euo pipefail

VIP=10.10.40.100
NS=nim
WORKER=worker1
HOST="nim.mwlabs.net"

ssh "$WORKER" curl -sS -X POST \
  "http://$VIP/v1/chat/completions" \
  -H "Host:$HOST" \
  -H "Accept:application/json" \
  -H "Content-Type:application/json" \
  --data-binary @- <<'EOF' | jq
{
  "model": "nvidia/Llama-3.1-Nemotron-Nano-4B-v1.1",
  "messages": [
    { "role": "user", "content": "Explain how a transformer neural network works." }
  ],
  "max_tokens": 64
}
EOF
exit

#
# test service directly via port forwarding:
# requires kubectl port-forward service/my-nim-nim-llm 8000:8000 -n nim"
#
echo ""
curl -X 'POST' \
  'http://0.0.0.0:8000/v1/chat/completions' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "nvidia/Llama-3.1-Nemotron-Nano-4B-v1.1",
        "messages": [{"role":"user", "content":"Explain how a transformer neural network works."}],
            "max_tokens": 64
          }' | jq

