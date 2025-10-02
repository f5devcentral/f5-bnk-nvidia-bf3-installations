#!/bin/bash

# Read the content of cne_pull_64.json into the SERVICE_ACCOUNT_KEY variable
SERVICE_ACCOUNT_KEY=$(cat cne_pull_64.json)
# Create the SERVICE_ACCOUNT_K8S_SECRET variable by appending "_json_key_base64:" to the base64 encoded SERVICE_ACCOUNT_KEY
SERVICE_ACCOUNT_K8S_SECRET=$(echo "_json_key_base64:${SERVICE_ACCOUNT_KEY}" | base64 -w 0)
# Create the secret.yaml file with the provided content
cat << EOF > far-secret.yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: far-secret
data:
  .dockerconfigjson: $(echo "{\"auths\": {\
\"repo.f5.com\":\
{\"auth\": \"$SERVICE_ACCOUNT_K8S_SECRET\"}}}" | base64 -w 0)
type: kubernetes.io/dockerconfigjson
EOF

kubectl -n f5-utils apply -f far-secret.yaml
kubectl -n default apply -f far-secret.yaml
