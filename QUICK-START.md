# Gluesync Kubernetes - Quick Start Guide

## One-Command Deployment

Choose your platform and run the corresponding script:

### 🖥️ Local Development
```bash
./deploy-local.sh
```
Then run: `./port-forward.sh`

### ☁️ AWS EKS
```bash
./deploy-eks.sh
```

### ☁️ Google GKE  
```bash
./deploy-gcp.sh
```

### ☁️ Azure AKS
```bash
./deploy-azure.sh
```

## What Gets Deployed

- ✅ Traefik Ingress Controller (HTTPS routing to corehub)
- ✅ Gluesync Core Hub (HTTPS on port 1717)
- ✅ Chronos
- ✅ Grafana Monitoring (port 3000)
- ✅ Prometheus Metrics
- ✅ All application services routed through Traefik on ports 80 and 443

## Access After Deployment

### Local
```bash
./port-forward.sh
# Then open: https://localhost:8443/ui
```

### Cloud (EKS/GKE/AKS)
The deployment script displays the LoadBalancer address:
```
https://YOUR-LOADBALANCER-ADDRESS/ui
```

## Customization

```bash
# Custom namespace
NAMESPACE=my-namespace ./deploy-eks.sh

# Custom release name
RELEASE_NAME=my-gluesync ./deploy-gcp.sh

# Internal load balancer (cloud only)
LB_SCHEME=internal ./deploy-eks.sh
```

## Files in This Directory

| File | Description |
|------|-------------|
| `deploy-local.sh` | Local Kubernetes deployment (Docker Desktop/kind/minikube) |
| `deploy-eks.sh` | AWS EKS deployment with NLB |
| `deploy-gcp.sh` | Google GKE deployment |
| `deploy-azure.sh` | Azure AKS deployment |
| `port-forward.sh` | Port forwarding utility for local access |
| `README.md` | Comprehensive deployment guide |
| `DEPLOYMENT.md` | Advanced deployment documentation |

## Need Help?

1. Check `README.md` for detailed instructions
2. See `DEPLOYMENT.md` for advanced configuration
3. View logs: `kubectl logs -n NAMESPACE deployment/traefik -f`

## SSL Certificates

Self-signed certificates are used by default. This is safe but will show browser warnings. Accept the warnings to proceed.
