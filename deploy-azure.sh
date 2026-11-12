#!/bin/bash

# Gluesync Azure/AKS Deployment Script
# Deploys Gluesync to Azure Kubernetes Service with LoadBalancer service

set -e

NAMESPACE="${NAMESPACE:-gluesync-prod}"
RELEASE_NAME="${RELEASE_NAME:-gluesync}"
LB_SCHEME="${LB_SCHEME:-public}"  # or "internal"

echo "=========================================="
echo "Gluesync AKS Deployment"
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
    
    # Set Azure-specific annotations for Traefik LoadBalancer
    if [ "${LB_SCHEME}" = "internal" ]; then
        TRAEFIK_ANNOTATIONS="--set-string service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal=true"
    else
        TRAEFIK_ANNOTATIONS=""
    fi
    
    # Install Traefik with LoadBalancer for AKS
    helm upgrade --install traefik traefik/traefik \
        --namespace ${NAMESPACE} \
        --set deployment.kind=Deployment \
        --set service.type=LoadBalancer \
        ${TRAEFIK_ANNOTATIONS} \
        --set ingressClass.enabled=true \
        --set ingressClass.isDefaultClass=false \
        --set providers.kubernetesCRD.enabled=true \
        --set providers.kubernetesIngress.enabled=true \
        --wait
    
    echo "✅ Traefik installed successfully"
else
    echo "✅ Traefik already installed"
fi

# Set Azure-specific annotations based on scheme
if [ "${LB_SCHEME}" = "internal" ]; then
    ANNOTATIONS="--set-string service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal=true"
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
sleep 10  # Give Azure time to provision

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

# NSG rule reminder
echo "🔐 Network Security Group (NSG) Configuration:"
echo "   Ensure your Azure NSG allows inbound traffic to these ports:"
echo "   - TCP: 80, 443"
echo ""
echo "   Example Azure CLI command to create NSG rule:"
echo "   az network nsg rule create \\"
echo "     --resource-group <your-resource-group> \\"
echo "     --nsg-name <your-nsg-name> \\"
echo "     --name allow-gluesync \\"
echo "     --priority 100 \\"
echo "     --source-address-prefixes '*' \\"
echo "     --source-port-ranges '*' \\"
echo "     --destination-address-prefixes '*' \\"
echo "     --destination-port-ranges 80 443 \\"
echo "     --access Allow \\"
echo "     --protocol Tcp \\"
echo "     --description 'Allow Gluesync ports'"
echo ""

echo "To check status:"
echo "  kubectl get all -n ${NAMESPACE}"
echo ""
echo "To view logs:"
echo "  kubectl logs -n ${NAMESPACE} deployment/traefik -f"
echo ""

echo "💡 Tip: For production deployments, consider:"
echo "   - Assigning a static public IP to the LoadBalancer"
echo "   - Using Azure DNS zones for custom domain names"
echo "   - Configuring Azure Application Gateway for advanced routing"
echo ""
