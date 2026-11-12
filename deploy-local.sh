#!/bin/bash

# Gluesync Local Development Deployment Script
# For Docker Desktop, kind, minikube, or other local Kubernetes clusters

set -e

NAMESPACE="${NAMESPACE:-gluesync-dev}"
RELEASE_NAME="${RELEASE_NAME:-gluesync}"

echo "=========================================="
echo "Gluesync Local Deployment"
echo "=========================================="
echo "Namespace: ${NAMESPACE}"
echo "Release: ${RELEASE_NAME}"
echo "Service Type: NodePort"
echo ""

# Check if namespace exists
if ! kubectl get namespace ${NAMESPACE} &> /dev/null; then
    echo "Creating namespace ${NAMESPACE}..."
    kubectl create namespace ${NAMESPACE}
fi

# Check if Traefik is installed in the namespace
echo "Checking for Traefik..."
if ! kubectl get deployment traefik -n ${NAMESPACE} &> /dev/null; then
    echo "Traefik not found. Installing Traefik..."
    
    # Add Traefik Helm repository
    helm repo add traefik https://traefik.github.io/charts 2>/dev/null || true
    helm repo update
    
    # Install Traefik with minimal configuration
    helm upgrade --install traefik traefik/traefik \
        --namespace ${NAMESPACE} \
        --set deployment.kind=Deployment \
        --set service.type=NodePort \
        --set ports.websecure.nodePort=32443 \
        --set ports.web.nodePort=32080 \
        --set ingressClass.enabled=true \
        --set ingressClass.isDefaultClass=false \
        --set providers.kubernetesCRD.enabled=true \
        --set providers.kubernetesIngress.enabled=true \
        --wait
    
    echo "✅ Traefik installed successfully"
else
    echo "✅ Traefik already installed"
fi

# Install or upgrade with NodePort
echo ""
echo "Deploying Gluesync with NodePort service..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change to the directory containing the chart
cd "${SCRIPT_DIR}"

# Install the chart
helm upgrade --install ${RELEASE_NAME} . \
    --namespace ${NAMESPACE} \
    --set service.type=NodePort \
    --wait

echo ""
echo "Deployment complete!"
echo ""

# Wait for pods
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=traefik \
    -n ${NAMESPACE} \
    --timeout=300s

echo ""
echo "=========================================="
echo "✅ Deployment Successful!"
echo "=========================================="
echo ""
echo "📌 Local Kubernetes Cluster Detected"
echo ""
echo "To access services from your localhost, you need to use port forwarding:"
echo ""
echo "Option 1: Use the convenience script (recommended)"
echo "  ./port-forward.sh              # Port 8443 only"
echo "  sudo ./port-forward.sh         # All ports (443, 80, 8443)"
echo ""
echo "Option 2: Manual port forwarding"
echo "  # Without privileged ports:"
echo "  kubectl port-forward -n ${NAMESPACE} svc/traefik 8443:443"
echo ""
echo "  # With privileged ports (requires sudo):"
echo "  sudo kubectl port-forward -n ${NAMESPACE} svc/traefik 8443:443 443:443 80:80"
echo ""
echo "Once port forwarding is active, access your services at:"
echo "  📍 Corehub HTTPS:  https://localhost:8443/"
echo "  📍 Corehub UI:     https://localhost:8443/ui"
echo "  📍 Grafana:        https://localhost:8443/grafana"
echo "  📍 Prometheus:     https://localhost:8443/prometheus"
echo "  📍 Chronos:        https://localhost:8443/chronos"
echo "  📍 Via Ingress:    https://localhost:443/ (requires sudo)"
echo ""
echo "Note: Accept certificate warnings (self-signed certificates)"
echo ""
echo "Useful commands:"
echo ""
echo "# View all resources:"
echo "  kubectl get all -n ${NAMESPACE}"
echo ""
echo "# Check pod status:"
echo "  kubectl get pods -n ${NAMESPACE}"
echo ""
echo "# View logs for specific services:"
echo "  # Traefik Ingress Controller:"
echo "  kubectl logs -n ${NAMESPACE} deployment/traefik -f"
echo ""
echo "  # Core Hub:"
echo "  kubectl logs -n ${NAMESPACE} statefulset/${RELEASE_NAME}-gluesync-core-hub -f"
echo ""
echo "  # Chronos:"
echo "  kubectl logs -n ${NAMESPACE} statefulset/${RELEASE_NAME}-gluesync-chronos -f"
echo ""
echo "  # Grafana:"
echo "  kubectl logs -n ${NAMESPACE} deployment/${RELEASE_NAME}-gluesync-grafana -f"
echo ""
echo "  # Prometheus:"
echo "  kubectl logs -n ${NAMESPACE} deployment/${RELEASE_NAME}-gluesync-prometheus -f"
echo ""
echo "# Describe a pod for troubleshooting:"
echo "  kubectl describe pod <pod-name> -n ${NAMESPACE}"
echo ""
echo "# Execute commands inside a pod:"
echo "  kubectl exec -it <pod-name> -n ${NAMESPACE} -- /bin/sh"
echo ""
