#!/bin/bash

# Gluesync GCP/GKE Deployment Script
# Deploys Gluesync to Google Kubernetes Engine with LoadBalancer service

set -e

NAMESPACE="${NAMESPACE:-gluesync-prod}"
# Traefik chart tested with these flags (40.0.0 moved the service type to service.spec.type)
TRAEFIK_CHART_VERSION="${TRAEFIK_CHART_VERSION:-42.3.2}"
RELEASE_NAME="${RELEASE_NAME:-gluesync}"
LB_SCHEME="${LB_SCHEME:-external}"  # or "internal"

echo "=========================================="
echo "Gluesync GKE Deployment"
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
    
    # Set GCP-specific annotations for Traefik LoadBalancer
    if [ "${LB_SCHEME}" = "internal" ]; then
        TRAEFIK_ANNOTATIONS="--set-string service.annotations.cloud\\.google\\.com/load-balancer-type=Internal"
    else
        TRAEFIK_ANNOTATIONS=""
    fi
    
    # Install Traefik with LoadBalancer for GKE
    helm upgrade --install traefik traefik/traefik \
        --version ${TRAEFIK_CHART_VERSION} \
        --namespace ${NAMESPACE} \
        --set deployment.kind=Deployment \
        --set service.spec.type=LoadBalancer \
        ${TRAEFIK_ANNOTATIONS} \
        --set ingressClass.enabled=true \
        --set ingressClass.isDefaultClass=false \
        --set providers.kubernetesCRD.enabled=true \
        --set providers.kubernetesIngress.enabled=true \
        --set ports.courier.port=8090 \
        --set ports.courier.expose.default=true \
        --set ports.courier.exposedPort=8090 \
        --set ports.courier.protocol=TCP \
        --set ports.courier.http.tls.enabled=true \
        --wait
    
    echo "✅ Traefik installed successfully"
else
    echo "✅ Traefik already installed"
fi

# Set GCP-specific annotations based on scheme
if [ "${LB_SCHEME}" = "internal" ]; then
    ANNOTATIONS="--set-string service.annotations.cloud\\.google\\.com/load-balancer-type=Internal"
else
    ANNOTATIONS=""
fi

# Install or upgrade
echo ""
echo "Deploying Gluesync with LoadBalancer service..."
helm upgrade --install ${RELEASE_NAME} . \
    --namespace ${NAMESPACE} \
    --set service.type=LoadBalancer \
    ${ANNOTATIONS} \
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

# Get LoadBalancer IP
echo ""
echo "Fetching LoadBalancer IP address..."
sleep 10  # Give GCP time to provision

LB_IP=$(kubectl get svc -n ${NAMESPACE} traefik \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$LB_IP" ]; then
    echo "⚠️  LoadBalancer IP not ready yet. Check status with:"
    echo "   kubectl get svc -n ${NAMESPACE} traefik -w"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ Deployment Successful!"
echo "=========================================="
echo ""
echo "LoadBalancer IP: ${LB_IP}"
echo ""
echo "Access your services at:"
echo "  📍 Corehub HTTPS:  https://${LB_IP}/"
echo "  📍 Corehub UI:     https://${LB_IP}/ui"
echo "  📍 Grafana:        https://${LB_IP}/grafana"
echo "  📍 Prometheus:     https://${LB_IP}/prometheus"
echo "  📍 Chronos:        https://${LB_IP}/chronos"
echo ""
echo "Note: You may see certificate warnings due to self-signed certificates."
echo "      This is expected and safe for your deployment."
echo ""

# Firewall rule reminder
echo "🔐 Firewall Configuration:"
echo "   Ensure your GCP firewall rules allow traffic to these ports:"
echo "   - TCP: 80, 443, 8090 (8090: Courier inbound endpoints)"
echo ""
echo "   Example gcloud command to create firewall rule:"
echo "   gcloud compute firewall-rules create allow-gluesync \\"
echo "     --allow tcp:80,tcp:443,tcp:8090 \\"
echo "     --source-ranges=0.0.0.0/0 \\"
echo "     --description='Allow Gluesync ports'"
echo ""

echo "To check status:"
echo "  kubectl get all -n ${NAMESPACE}"
echo ""
echo "To view logs:"
echo "  kubectl logs -n ${NAMESPACE} deployment/traefik -f"
echo ""
