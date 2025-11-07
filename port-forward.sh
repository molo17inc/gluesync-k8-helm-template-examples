#!/bin/bash

# Gluesync Port Forwarding Script
# This script forwards the Kubernetes services to localhost for easy access

# Function to start port forwarding
start_port_forward() {
    local service=$1
    local port=$2
    local target_port=$3
    
    # Kill any existing port-forward for this service
    pkill -f "kubectl port-forward.*${service}" || true
    
    echo "Forwarding ${service} to http://localhost:${port}"
    nohup kubectl port-forward -n ${NAMESPACE} svc/${service} ${port}:${target_port} > /dev/null 2>&1 &
}

# Auto-detect namespace or use environment variable
NAMESPACE="${NAMESPACE:-}"
if [ -z "$NAMESPACE" ]; then
    # Try to find gluesync namespace (exclude 'default')
    NAMESPACE=$(kubectl get namespaces -o name | grep 'gluesync' | head -1 | sed 's|namespace/||')
    
    if [ -z "$NAMESPACE" ]; then
        echo "❌ Error: No Gluesync namespace found automatically."
        echo ""
        echo "Available namespaces:"
        kubectl get namespaces -o custom-columns=NAME:.metadata.name --no-headers
        echo ""
        echo -n "Enter namespace name (or press Ctrl+C to cancel): "
        read NAMESPACE
        
        if [ -z "$NAMESPACE" ]; then
            echo "❌ Error: No namespace specified."
            exit 1
        fi
        
        # Verify namespace exists
        if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
            echo "❌ Error: Namespace '$NAMESPACE' does not exist."
            exit 1
        fi
    else
        echo "✅ Auto-detected namespace: ${NAMESPACE}"
    fi
fi

# Start port forwarding for services
start_port_forward "gluesync" 8080 8080
start_port_forward "traefik" 8081 9000
start_port_forward "portainer" 9000 9000
start_port_forward "prometheus" 9090 9090
start_port_forward "grafana" 3000 3000

echo ""
echo "Port forwarding started for all services"
echo "------------------------------------"
echo "Gluesync UI:     http://localhost:8080"
echo "Traefik UI:      http://localhost:8081"
echo "Portainer:       http://localhost:9000"
echo "Prometheus:      http://localhost:9090"
echo "Grafana:         http://localhost:3000"
echo ""
echo "To stop all port forwarding, run: pkill -f \"kubectl port-forward\""
echo ""

# Check if running with sudo for privileged ports
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️  Running without sudo - ports 443 and 80 will be skipped"
    echo "   To include them, run: sudo ./port-forward.sh"
    echo ""
    kubectl port-forward -n ${NAMESPACE} svc/traefik \
      9443:443
else
    echo "✅ Running with sudo - all ports will be forwarded"
    echo ""
    kubectl port-forward -n ${NAMESPACE} svc/traefik \
      9443:443 \
      443:443 \
      80:80
fi
