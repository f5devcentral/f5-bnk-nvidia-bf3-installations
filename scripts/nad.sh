#!/usr/bin/env bash
echo ""
for nad in $(kubectl get network-attachment-definition -o jsonpath='{.items[*].metadata.name}'); do
  echo "$nad:"
  kubectl get network-attachment-definition $nad -o json | jq .spec
done
