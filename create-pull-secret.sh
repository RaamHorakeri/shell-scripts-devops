#!/bin/bash

# Check for required arguments
if [ $# -ne 5 ]; then
  echo "Usage: $0 <context> <cluster> <namespace> <docker_registry> <secret_name>"
  exit 1
fi

# Configuration
CONTEXT="$1"
CLUSTER="$2"
NAMESPACE="$3"
DOCKER_REGISTRY="$4"
SECRET_NAME="$5"
DO_API_TOKEN="${DO_API_TOKEN}"

# Ensure the DO_API_TOKEN is set
if [ -z "$DO_API_TOKEN" ]; then
  echo "Error: DO_API_TOKEN environment variable is not set."
  echo "Please export it first or pass it via Jenkins credentials."
  exit 1
fi

# Switch to the specified Kubernetes context
echo "🔁 Switching to context: $CONTEXT"
kubectl config use-context "$CONTEXT" >/dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "❌ Failed to switch to context '$CONTEXT'. Please check your kubeconfig."
  exit 1
fi

# Create or update the image pull secret
echo "🔐 Creating/updating image pull secret '$SECRET_NAME' in namespace '$NAMESPACE'..."

kubectl create secret docker-registry "$SECRET_NAME" \
  --docker-server="$DOCKER_REGISTRY" \
  --docker-username=doctl \
  --docker-password="$DO_API_TOKEN" \
  --namespace "$NAMESPACE" \
  --context "$CONTEXT" \
  --dry-run=client -o yaml | kubectl apply --context "$CONTEXT" -f -

echo "✅ Image pull secret '$SECRET_NAME' has been created or updated in namespace '$NAMESPACE' (context: $CONTEXT, cluster: $CLUSTER)."
