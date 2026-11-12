#!/bin/bash

# Gluesync Port Forwarding Script
# This script forwards the Kubernetes services to localhost for easy access

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

echo ""
echo "Port forwarding started"
echo "------------------------------------"
echo "Gluesync UI:     https://localhost:8443/ui"
echo "Grafana:         https://localhost:8443/grafana"
echo "Prometheus:      https://localhost:8443/prometheus"
echo "Chronos:         https://localhost:8443/chronos"
echo ""
echo "To stop all port forwarding, run: pkill -f \"kubectl port-forward\""
echo ""

# Check if running with sudo for privileged ports
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️  Running without sudo - ports 443 and 80 will be skipped"
    echo "   To include them, run: sudo ./port-forward.sh"
    echo ""
    kubectl port-forward -n ${NAMESPACE} svc/traefik \
      8443:443
else
    echo "✅ Running with sudo - all ports will be forwarded"
    echo ""
    kubectl port-forward -n ${NAMESPACE} svc/traefik \
      8443:443 \
      443:443 \
      80:80
fi
