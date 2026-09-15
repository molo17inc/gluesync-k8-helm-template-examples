# Gluesync Kubernetes Deployment

This directory contains the Helm chart and deployment scripts for Gluesync with Traefik ingress controller.

## Prerequisites

The deployment scripts automatically install Traefik if not already present. Traefik provides:
- IngressRoute CRDs for advanced routing
- TLS termination and certificate handling
- Path-based routing for multiple services
- WebSocket support

## Quick Start

Choose the appropriate deployment script for your environment:

### Local Development
```bash
./deploy-local.sh
```
For Docker Desktop, kind, minikube, or other local Kubernetes clusters.
- Automatically installs Traefik with NodePort service
- Requires port forwarding to access services

### AWS EKS
```bash
./deploy-eks.sh
```
Deploys to Amazon EKS with Network Load Balancer.
- Automatically installs Traefik with LoadBalancer
- Direct access via AWS NLB DNS

### Google GKE
```bash
./deploy-gcp.sh
```
Deploys to Google Kubernetes Engine with LoadBalancer.
- Automatically installs Traefik with LoadBalancer
- Direct access via GCP LoadBalancer IP

### Azure AKS
```bash
./deploy-azure.sh
```
Deploys to Azure Kubernetes Service with LoadBalancer.
- Automatically installs Traefik with LoadBalancer
- Direct access via Azure LoadBalancer IP

## Deployment Scripts

| Script | Environment | Service Type | Access Method |
|--------|-------------|--------------|---------------|
| `deploy-local.sh` | Local clusters | NodePort | Port forwarding required |
| `deploy-eks.sh` | AWS EKS | LoadBalancer | Direct via NLB DNS |
| `deploy-gcp.sh` | Google GKE | LoadBalancer | Direct via IP |
| `deploy-azure.sh` | Azure AKS | LoadBalancer | Direct via IP |
| `port-forward.sh` | Any | - | Port forwarding utility |

## Accessing Services

### Local Development

After deploying with `deploy-local.sh`, run port forwarding:

```bash
./port-forward.sh
```

Then access services via Traefik:

- **CoreHub**: `https://localhost:9443/`
- **CoreHub UI**: `https://localhost:9443/ui`
- **Chronos API**: `https://localhost:9443/api/jobs/` or `https://localhost:9443/chronos/api/jobs`
- **Chronos UI**: `https://localhost:9443/chronos/`
- **Grafana**: `https://localhost:9443/grafana`
- **Prometheus**: `https://localhost:9443/prometheus`

**Note**: Accept certificate warnings (self-signed certificates).

### Cloud Deployments (EKS/GKE/AKS)

Services are directly accessible via the LoadBalancer IP/DNS through Traefik:

- **CoreHub**: `https://YOUR-LB-ADDRESS/`
- **CoreHub UI**: `https://YOUR-LB-ADDRESS/ui`
- **Chronos API**: `https://YOUR-LB-ADDRESS/api/jobs/` or `https://YOUR-LB-ADDRESS/chronos/api/jobs`
- **Chronos UI**: `https://YOUR-LB-ADDRESS/chronos/`
- **Grafana**: `https://YOUR-LB-ADDRESS/grafana`
- **Prometheus**: `https://YOUR-LB-ADDRESS/prometheus`

The deployment scripts will display the exact LoadBalancer address after provisioning.

## Environment Variables

All deployment scripts support environment variables for customization:

```bash
# Set custom namespace
NAMESPACE=my-namespace ./deploy-eks.sh

# Set custom release name
RELEASE_NAME=my-gluesync ./deploy-gcp.sh

# For cloud deployments, set load balancer scheme
LB_SCHEME=internal ./deploy-azure.sh
```

## Manual Deployment

If you prefer manual deployment, you must install Traefik first:

```bash
# 1. Install Traefik (required for IngressRoute CRDs)
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik \
  --namespace gluesync-dev --create-namespace \
  --set service.type=NodePort \
  --set providers.kubernetesCRD.enabled=true

# 2. Deploy Gluesync
helm install gluesync . --namespace gluesync-dev \
  --set service.type=NodePort
```

For cloud deployments, adjust the service type and annotations as needed.

## Configuration

### Traefik Routing

Gluesync uses Traefik IngressRoutes for advanced routing:

- **IngressRoute CRDs**: Path-based routing with priorities
- **Middleware**: Path rewriting for Chronos (`/chronos` → `/api`)
- **ServersTransport**: TLS backend communication with `insecureSkipVerify`
- **TLS Termination**: Handled by Traefik at the edge

### Service Ports

| Port | Service | Protocol | Description |
|------|---------|----------|-------------|
| 443 | Traefik HTTPS | TCP | Main HTTPS entry point (Traefik) |
| 80 | Traefik HTTP | TCP | HTTP entry point (redirects to HTTPS) |
| 1717 | Backend Services | TCP | Internal HTTPS for CoreHub/Chronos |
| 3000 | Grafana | TCP | Monitoring dashboard |
| 9090 | Prometheus | TCP | Metrics collection |

### SSL/TLS

- **Frontend TLS**: Traefik terminates TLS using self-signed certificates
- **Backend TLS**: Services use self-signed certificates (validated by ServersTransport)
- **Certificate Warnings**: Expected in browsers due to self-signed certs

## Firewall Configuration

### AWS EKS
Ensure your security groups allow inbound traffic on ports 80 and 443.

### Google GKE
```bash
gcloud compute firewall-rules create allow-gluesync \
  --allow tcp:80,tcp:443 \
  --source-ranges=0.0.0.0/0
```

### Azure AKS
```bash
az network nsg rule create \
  --resource-group <your-rg> \
  --nsg-name <your-nsg> \
  --name allow-gluesync \
  --priority 100 \
  --destination-port-ranges 80 443 \
  --access Allow \
  --protocol Tcp
```

## Troubleshooting

### Check Deployment Status
```bash
kubectl get all -n gluesync-dev
```

### View Logs
```bash
kubectl logs -n gluesync-dev deployment/traefik -f
```

### Check Service
```bash
kubectl get svc -n gluesync-dev
```

### Port Forwarding Issues
If port forwarding fails:
1. Check if ports are already in use: `lsof -i :9443`
2. Ensure the service is running: `kubectl get pods -n gluesync-dev`
3. Try different ports: `kubectl port-forward ... 19443:9443`

## Additional Documentation

See `DEPLOYMENT.md` for comprehensive deployment documentation including:
- Detailed configuration options
- Advanced scenarios
- Migration guides
- Best practices

## Examples

The `examples/` folder contains sample configurations for different deployment scenarios:
- `traefik-helmrelease.yaml` - Flux/GitOps deployment example

## Support

For issues or questions:
1. Check pod status: `kubectl get pods -n <namespace>`
2. Review logs: `kubectl logs -n <namespace> <pod-name>`
3. Verify ingress: `kubectl get ingress -n <namespace>`
