#!/usr/bin/env bash
PWD=$(kubectl --namespace monitoring get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo)
echo "default admin-password: admin/$PWD"
