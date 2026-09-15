#!/bin/bash

# Gluesync EKS Deployment Script
# Deploys Gluesync to AWS EKS with LoadBalancer service

set -e

NAMESPACE="${NAMESPACE:-gluesync-prod}"
RELEASE_NAME="${RELEASE_NAME:-gluesync}"
LB_SCHEME="${LB_SCHEME:-internet-facing}"  # or "internal"

echo "=========================================="
echo "Gluesync EKS Deployment"
echo "=========================================="
echo "Namespace: ${NAMESPACE}"
echo "Release: ${RELEASE_NAME}"
echo "Load Balancer: ${LB_SCHEME}"
echo ""

# Check if namespace exists
if ! kubectl get namespace ${NAMESPACE} &> /dev/null; then
    echo "Creating namespace ${NAMESPACE}..."
    kubectl create namespace ${NAMESPACE}
fi

# Check if Traefik is installed in the target namespace
echo "Checking for Traefik..."
if ! kubectl get deployment traefik -n ${NAMESPACE} &> /dev/null; then
    echo "Traefik not found in ${NAMESPACE}. Installing Traefik..."
    
    # Add Traefik Helm repository
    helm repo add traefik https://traefik.github.io/charts 2>/dev/null || true
    helm repo update
    
    # Install Traefik with LoadBalancer for EKS
    helm upgrade --install traefik traefik/traefik \
        --namespace ${NAMESPACE} \
        --set deployment.kind=Deployment \
        --set service.type=LoadBalancer \
        --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=${LB_SCHEME} \
        --set ingressClass.enabled=true \
        --set ingressClass.isDefaultClass=false \
        --set providers.kubernetesCRD.enabled=true \
        --set providers.kubernetesIngress.enabled=true \
        --wait
    
    echo "✅ Traefik installed successfully"
else
    echo "✅ Traefik already installed"
fi

# Check if Portainer is installed in the namespace
echo "Checking for Portainer..."
if ! kubectl get deployment portainer -n ${NAMESPACE} &> /dev/null; then
    echo "Portainer not found. Installing Portainer..."
    
    # Add Portainer Helm repository
    helm repo add portainer https://portainer.github.io/k8s/ 2>/dev/null || true
    helm repo update
    
    # Install Portainer with LoadBalancer for EKS
    helm upgrade --install portainer portainer/portainer \
        --namespace ${NAMESPACE} \
        -f "$(dirname "$0")/portainer-config/values.yaml" \
        --set service.type=LoadBalancer \
        --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=${LB_SCHEME} \
        --wait
    
    echo "✅ Portainer installed successfully"
    echo ""
    echo "To access Portainer UI, wait for the LoadBalancer to be provisioned, then run:"
    echo "  kubectl get svc -n ${NAMESPACE} portainer -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
    echo ""
else
    echo "✅ Portainer already installed"
fi

# Install or upgrade
echo ""
echo "Deploying Gluesync with LoadBalancer service..."
helm upgrade --install ${RELEASE_NAME} . \
    --namespace ${NAMESPACE} \
    --set service.type=LoadBalancer \
    --set service.loadBalancerScheme=${LB_SCHEME} \
    --wait

echo ""
echo "Deployment complete! Waiting for LoadBalancer to be provisioned..."
echo "This may take 2-3 minutes..."
echo ""

# Wait for LoadBalancer
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=traefik \
    -n ${NAMESPACE} \
    --timeout=300s

# Get LoadBalancer DNS
echo ""
echo "Fetching LoadBalancer DNS name..."
sleep 10  # Give AWS time to provision

LB_DNS=$(kubectl get svc -n ${NAMESPACE} traefik \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$LB_DNS" ]; then
    echo "⚠️  LoadBalancer DNS not ready yet. Check status with:"
    echo "   kubectl get svc -n ${NAMESPACE} traefik -w"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ Deployment Successful!"
echo "=========================================="
echo ""
echo "LoadBalancer DNS: ${LB_DNS}"
echo ""
echo "Access your services at:"
echo "  📍 Corehub HTTPS:  https://${LB_DNS}/"
echo "  📍 Corehub UI:     https://${LB_DNS}/ui"
echo "  📍 Grafana:        https://${LB_DNS}/grafana"
echo "  📍 Prometheus:     https://${LB_DNS}/prometheus"
echo "  📍 Chronos:        https://${LB_DNS}/chronos"
echo ""
echo "Note: You may see certificate warnings due to self-signed certificates."
echo "      This is expected and safe for your deployment."
echo ""
echo "To check status:"
echo "  kubectl get all -n ${NAMESPACE}"
echo ""
echo "To view logs:"
echo "  kubectl logs -n ${NAMESPACE} deployment/traefik -f"
echo ""
