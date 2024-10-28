#!/bin/bash

CRD_NAME="utxorpcports.demeter.run"

resources=$(kubectl get $CRD_NAME -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}')

while read -r namespace resource_name; do
  echo "Processing resource: $resource_name in namespace: $namespace"

  current_manifest=$(kubectl get $CRD_NAME $resource_name -n $namespace -o json)

  authToken=$(echo "$current_manifest" | jq -r '.status.authToken')
  updated_manifest=$(echo "$current_manifest" | jq --arg newValue "$authToken" '.spec.authToken = $newValue')

  echo "$updated_manifest" | kubectl apply -f -
  echo "Updated resource: $resource_name in namespace: $namespace"
done <<< "$resources"
