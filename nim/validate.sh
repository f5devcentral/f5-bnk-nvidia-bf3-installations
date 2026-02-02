#!/bin/bash

VIP=10.10.40.100
NS=nim
WORKER=worker1
HOST="nim.mwlabs.net"

set -e

echo ""
echo "$PWD"
echo ""
echo "Test reachability to virtual server $VIP from $client ..."
until ssh $WORKER ping -c3 $VIP; do
  echo "waiting 10 secs and try again ..."
  sleep 10
done

echo ""
set -x
kubectl get f5-bnkgateways
kubectl get gatewayclass f5-gateway-class
kubectl get gateway -n $NS my-httproute-gateway
kubectl get httproute -n $NS
set +x
echo ""

echo ""
echo "Test with curl from client $client using invalid host ..."
echo ""
set -x
ssh $WORKER curl -Is -H "HOST: broken.example.com" http://$VIP/v1/models
set +x

echo ""
echo "Test with curl from client $client, quering models ..."
echo ""
set -x
ssh $WORKER curl -s -H "$HOST" http://$VIP/v1/models | jq
set +x
