#!/usr/bin/env bash
set -euo pipefail
KUBECONFIG=$PWD/inventory/f5-bnk-cluster/artifacts/admin.conf
echo "testing $KUBECONFIG ..."
kubectl --kubeconfig $KUBECONFIG cluster-info
echo "copying $KUBECONFIG to $HOME/.kube/config"
cp -f $PWD/inventory/f5-bnk-cluster/artifacts/admin.conf $HOME/.kube/config
