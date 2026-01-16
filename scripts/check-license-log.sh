#!/usr/bin/env bash
kubectl logs deployment/f5-spk-cwc -n f5-utils
echo ""
echo "Looking for LicenseExpiryDate ..."
kubectl logs deployment/f5-spk-cwc -n f5-utils| grep LicenseExpiryDate|tail -1
