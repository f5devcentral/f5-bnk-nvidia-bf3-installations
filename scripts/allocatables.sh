#!/usr/bin/env bash
set -euo pipefail

KUBECONFIG=$PWD/inventory/f5-bnk-cluster/artifacts/admin.conf

nodes=$(kubectl get nodes | grep ' Ready ' | awk '{print $1}')
echo $nodes
for node in $nodes; do
  echo "$node ..."
  kubectl get nodes $node -o json | jq '.status.allocatable'
  echo ""
done

kubectl get network-attachment-definitions
