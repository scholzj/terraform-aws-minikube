#!/usr/bin/env bash

# Install the Helm Chart
helm upgrade --install --create-namespace --repo https://kubernetes.github.io/ingress-nginx \
        --set "controller.extraArgs.enable-ssl-passthrough=true,controller.admissionWebhooks.enabled=false,controller.ingressClassResource.default=default" \
        --namespace ingress-nginx \
        ingress-nginx ingress-nginx

# Make sure it is ready
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx --timeout 300s