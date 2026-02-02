#!/bin/bash
export NGC_CLI_API_KEY=$(cat ~/.nvapi)

helm fetch https://helm.ngc.nvidia.com/nim/charts/nim-llm-1.3.0.tgz --username='$oauthtoken' --password=$NGC_CLI_API_KEY
kubectl get ns nim || kubectl create ns nim

kubectl create secret docker-registry registry-secret --docker-server=nvcr.io --docker-username='$oauthtoken' --docker-password=$NGC_CLI_API_KEY -n nim
kubectl create secret generic ngc-api --from-literal=NGC_API_KEY=$NGC_CLI_API_KEY -n nim

helm upgrade --install my-nim nim-llm-1.3.0.tgz -f nim_custom_value.yaml --namespace nim
