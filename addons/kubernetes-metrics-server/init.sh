#!/usr/bin/env bash

# Install the Helm Chart
helm upgrade --install --create-namespace --repo https://kubernetes-sigs.github.io/metrics-server/ \
        --set "args={--kubelet-insecure-tls}" \
        --namespace monitoring \
        metrics-server metrics-server

# Make sure it is ready
kubectl rollout status deployment metrics-server -n monitoring --timeout 300s