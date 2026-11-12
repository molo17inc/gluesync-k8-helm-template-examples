# Gluesync Kubernetes Deployment Guide

## Overview

This Helm chart deploys Gluesync with **Traefik Ingress Controller** for advanced routing, TLS termination, and path-based traffic management.

### Key Features

- **Automatic Traefik Installation**: Deployment scripts automatically install Traefik if CRDs are not present
- **IngressRoute CRDs**: Advanced routing with priorities and middleware
- **Path-Based Routing**: Multiple services accessible through a single entry point
- **TLS Termination**: Traefik handles frontend TLS, communicates with backends via HTTPS
- **Middleware Support**: Path rewriting for Chronos API routing

## Deployment Modes

### 1. Local Development (Docker Desktop / kind / minikube)

**Service Type**: `NodePort`  
**Ingress**: Traefik with IngressRoute CRDs

Port forwarding is required to access services from localhost:

```bash
# Use the automated deployment script (recommended)
./deploy-local.sh

# Or manual installation:
# 1. Install Traefik first
helm repo add traefik https://traefik.github.io/charts
helm install traefik traefik/traefik \
  --namespace gluesync-dev --create-namespace \
  --set service.type=NodePort \
  --set providers.kubernetesCRD.enabled=true

# 2. Install Gluesync
helm install gluesync . --namespace gluesync-dev

# 3. Forward ports to localhost
kubectl port-forward -n gluesync-dev svc/traefik 8443:443

# Access services via Traefik
# - CoreHub: https://localhost:8443/
# - CoreHub UI: https://localhost:8443/ui
# - Chronos API: https://localhost:8443/chronos/api/jobs
# - Chronos UI: https://localhost:8443/chronos/
# - Grafana: https://localhost:8443/grafana
# - Prometheus: https://localhost:8443/prometheus
```

**Why port-forward?**

- Local Kubernetes clusters don't expose NodePorts to the host machine by default
- Port forwarding creates a tunnel from localhost to the Traefik service

---

### 2. Production on AWS EKS

**Service Type**: `LoadBalancer` (creates AWS Network Load Balancer)  
**Ingress**: Traefik with LoadBalancer service

Services are **automatically accessible** via the LoadBalancer's external IP/DNS:

```bash
# Use the automated deployment script (recommended)
./deploy-eks.sh

# Or manual installation:
# 1. Install Traefik with LoadBalancer
helm repo add traefik https://traefik.github.io/charts
helm install traefik traefik/traefik \
  --namespace gluesync-prod --create-namespace \
  --set service.type=LoadBalancer \
  --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=internet-facing \
  --set providers.kubernetesCRD.enabled=true

# 2. Install Gluesync
helm install gluesync . --namespace gluesync-prod

# Wait for AWS to provision the NLB (takes ~2-3 minutes)
kubectl get svc -n gluesync-prod traefik -w

# Get the LoadBalancer DNS name
export LB_DNS=$(kubectl get svc -n gluesync-prod traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Access your services via Traefik at:"
echo "  - CoreHub: https://${LB_DNS}/"
echo "  - CoreHub UI: https://${LB_DNS}/ui"
echo "  - Chronos API: https://${LB_DNS}/chronos/api/jobs"
echo "  - Chronos UI: https://${LB_DNS}/chronos/"
echo "  - Grafana: https://${LB_DNS}/grafana"
echo "  - Prometheus: https://${LB_DNS}/prometheus"
```

**No port-forward needed!** AWS provisions a real Network Load Balancer with a public DNS name pointing to Traefik.

---

## Configuration Options

### Traefik Routing Architecture

Gluesync uses Traefik IngressRoutes for advanced routing:

```yaml
# IngressRoute for CoreHub (priority: 1 - catch-all)
- match: PathPrefix(`/`)
  services:
    - name: gluesync-core-hub
      port: 1717
      scheme: https

# IngressRoute for Chronos (priority: 10 - higher priority)
- match: PathPrefix(`/chronos`)
  middlewares:
    - name: gluesync-chronos  # Strips /chronos prefix
  services:
    - name: gluesync-chronos
      port: 1717
      scheme: https
```

### Middleware Configuration

**Path Rewriting for Chronos**:

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: gluesync-chronos
spec:
  stripPrefix:
    prefixes:
      - /chronos
```

This allows `/chronos/api/jobs` → `/api/jobs` routing to the Chronos backend.

### ServersTransport for Backend TLS

```yaml
apiVersion: traefik.io/v1alpha1
kind: ServersTransport
metadata:
  name: insecure-transport
spec:
  insecureSkipVerify: true  # Accept self-signed backend certificates
```

### Exposed Ports

| Port | Service | Protocol | Description |
|------|---------|----------|-------------|
| 443 | Traefik HTTPS | TCP | Main HTTPS entry point (all services) |
| 80 | Traefik HTTP | TCP | HTTP entry point (redirects to HTTPS) |
| 1717 | Backend Services | TCP | Internal HTTPS for CoreHub/Chronos |
| 3000 | Grafana | TCP | Grafana monitoring interface |
| 9090 | Prometheus | TCP | Prometheus metrics |

---

## Cloud-Specific Configuration

### AWS EKS - Network Load Balancer

Traefik service automatically configures AWS NLB when using LoadBalancer type:

```yaml
annotations:
  service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"  # or "internal"
  service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
```

### Internal Load Balancer

For private/internal access only:

```bash
helm install gluesync-prod . \
  --set service.type=LoadBalancer \
  --set service.loadBalancerScheme=internal
```

### Security Groups

Ensure your EKS worker nodes' security groups allow:
- Inbound TCP 80 and 443 from the NLB
- The NLB security group allows inbound from your allowed CIDR ranges

---

## SSL/TLS Configuration

### Self-Signed Certificates

By default, backend services use self-signed certificates. Traefik is configured to accept them via ServersTransport:

```yaml
# servertransport-insecure.yaml
apiVersion: traefik.io/v1alpha1
kind: ServersTransport
metadata:
  name: insecure-transport
spec:
  insecureSkipVerify: true  # Accept self-signed backend certs
```

This allows Traefik to communicate with CoreHub and Chronos over HTTPS using self-signed certificates.

### Using Custom Certificates

To use your own certificates, update the `secret-tls.yaml` with your cert and key. The certificates are used by:
- **Frontend**: Traefik TLS termination
- **Backend**: CoreHub, Chronos, and other services

---

## Troubleshooting

### LoadBalancer Stuck in Pending

**Problem**: Service stuck in pending state
```bash
kubectl describe svc -n gluesync-prod traefik
```

**Common causes**:
- EKS: IAM permissions for creating NLB
- GKE: Quota limits on external IPs
- AKS: Insufficient permissions or quota

---

### Connection Refused

**Problem**: Can connect to LB but connection refused

**Check**:
1. Traefik pods running: `kubectl get pods -n gluesync-prod -l app.kubernetes.io/name=traefik`
2. IngressRoutes configured: `kubectl get ingressroute -n gluesync-prod`
3. Security groups allow traffic on ports 80, 443

---

### IngressRoute Not Working

**Problem**: 404 errors when accessing services

**Check**:
1. Traefik CRDs installed: `kubectl get crd ingressroutes.traefik.io`
2. Middleware exists: `kubectl get middleware -n gluesync-prod`
3. ServersTransport exists: `kubectl get serverstransport -n gluesync-prod`
4. Check Traefik logs: `kubectl logs -n gluesync-prod deployment/traefik`

---

## Quick Reference

```bash
# Local development
./deploy-local.sh
./port-forward.sh

# EKS production
./deploy-eks.sh

# Get LoadBalancer URL
kubectl get svc -n gluesync-prod traefik

# Check Traefik logs
kubectl logs -n gluesync-prod deployment/traefik -f

# Check IngressRoutes
kubectl get ingressroute -n gluesync-prod

# Check Middleware
kubectl get middleware -n gluesync-prod

# For Local tear down
kubectl delete namespace gluesync-dev
```
