#!/usr/bin/env bash
kubectl logs deployment/f5-spk-cwc -n f5-operators
echo ""
echo "Looking for LicenseExpiryDate ..."
kubectl logs deployment/f5-spk-cwc -n f5-operators| grep LicenseExpiryDate|tail -1
