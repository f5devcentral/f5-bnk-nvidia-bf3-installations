#!/usr/bin/env bash
kubectl get node -o json | jq '.items[] | {name: .metadata.name, labels: .metadata.labels}'
