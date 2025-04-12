#!/usr/bin/env bash

# Install the Helm Chart
helm upgrade --install --create-namespace --repo https://kubernetes-sigs.github.io/external-dns/ \
        --set "provider.name=aws,interval=5m,txtOwnerId=${CLUSTER_NAME}" \
        --namespace external-dns \
        external-dns external-dns

# Make sure it is ready
kubectl rollout status deployment external-dns -n external-dns --timeout 300s