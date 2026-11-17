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

- **CoreHub**: `https://localhost:8443/`
- **CoreHub UI**: `https://localhost:8443/ui`
- **Chronos API**: `https://localhost:8443/chronos/api/jobs`
- **Chronos UI**: `https://localhost:8443/chronos/`
- **Grafana**: `https://localhost:8443/grafana`
- **Prometheus**: `https://localhost:8443/prometheus`

**Note**: Accept certificate warnings (self-signed certificates).

### Cloud Deployments (EKS/GKE/AKS)

Services are directly accessible via the LoadBalancer IP/DNS through Traefik:

- **CoreHub**: `https://YOUR-LB-ADDRESS/`
- **CoreHub UI**: `https://YOUR-LB-ADDRESS/ui`
- **Chronos API**: `https://YOUR-LB-ADDRESS/chronos/api/jobs`
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
  --version 42.3.2 \
  --namespace gluesync-dev --create-namespace \
  --set service.spec.type=NodePort \
  --set providers.kubernetesCRD.enabled=true

# 2. Deploy Gluesync
helm install gluesync . --namespace gluesync-dev \
  --set service.type=NodePort
```

For cloud deployments, adjust the service type and annotations as needed.

## Updating Gluesync

The chart installs the Gluesync Kubernetes Operator (GKO) next to Core Hub. It does on Kubernetes what Conductor does on Docker and Swarm:

1. Core Hub's **Update** button works as on Docker: GKO answers on `/conductor/api` and connects to Core Hub as its Conductor module.
2. Before Core Hub changes, every running pipeline goes into maintenance mode. Pipelines resume as soon as the new Core Hub is ready, or after a rollback.
3. Core Hub is updated first and must stay ready for 20 s (180 s at most). If it fails, it is rolled back.
4. Chronos, Grafana and Prometheus then move to the latest version of the release channel. A module that fails is rolled back on its own.
5. GKO updates itself last. The UI lists it as a module; its version comes from the release channel set in Core Hub. GKO answers the update first, then waits until no update has run for 15 s (`operator.selfUpdate.delaySeconds`) and changes its own image. The new GKO pod starts next to the old one, which keeps running until the new pod has been Ready for 10 s. If the new pod crashes, cannot be pulled or is not ready within 180 s, the old GKO puts its own image back. A new GKO that fails after taking over cannot roll itself back: `kubectl -n <namespace> rollout undo deployment/<release>-gluesync-operator`.

To update from the command line or from Git, change the desired version:

```bash
kubectl -n gluesync-dev patch gluesyncplatform gluesync --type merge -p '{"spec":{"version":"2.3.3.0"}}'
kubectl -n gluesync-dev get gluesyncplatform gluesync -w
```

`kubectl get gsp` shows the running version, the desired version, the version available on the channel and the phase (`Current`, `UpdateAvailable`, `Updating`, `Degraded`, `Failed`). `kubectl describe gsp gluesync` lists each step as an event.

Set `operator.updatePolicy=gitops` if versions live in Git: the UI then cannot start updates, and GKO never changes its own image (set `operator.tag` in Git). A later `helm upgrade` of this chart never reverts an update: the image tags GKO set are kept. For GKO itself, a chart whose `operator.tag` is a newer version than the one running still upgrades it.

GKO signs in to Core Hub with your licence (`secrets.license`) and serves its API with the Gluesync certificate (`secrets.cert`, `secrets.key`). This public chart leaves those values blank: set them, for example with `--set-file`, before you install.

To install without GKO: `--set operator.enabled=false`. Core Hub then cannot update itself from the UI: change the image tags in `values.yaml` and run `helm upgrade`.

## Configuration

### Image Versions

`values.yaml` uses the `latest` tag for every image. The Kubernetes kit you receive from Gluesync pins real version tags at build time; this public template does not. For anything other than a quick test, pin a specific version. Once GKO is running, it owns the versions: a later `helm upgrade` keeps the tags GKO set (see [Updating Gluesync](#updating-gluesync)).

Set the tags in `values.yaml`:

```yaml
gluesyncCoreHub:
  tag: "2.2.6.1"      # Core Hub version
gluesyncChronos:
  tag: "<chronos-version>"
grafana:
  tag: "<grafana-version>"
prometheus:
  tag: "<prometheus-version>"
operator:
  tag: "0.1.1"          # Gluesync Kubernetes Operator (GKO)
```

Or override them on the command line:

```bash
helm upgrade --install gluesync . --namespace gluesync-dev \
  --set gluesyncCoreHub.tag=2.2.6.1 \
  --set gluesyncChronos.tag=<chronos-version>
```

Available tags are published on Docker Hub under `molo17/gluesync-core-hub`, `molo17/gluesync-chronos`, `molo17/grafana`, `molo17/prometheus` and `molo17/gluesync-operator` (GKO). The templates do not set `imagePullPolicy`, so Kubernetes applies its default: `Always` for `latest`, `IfNotPresent` for a pinned tag. With `latest`, a pod restart can therefore start a newer version. GKO also reports `latest` as the running version in `kubectl get gsp` until you pin one.

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
| 8090 | Traefik Courier | TCP | HTTPS entry point of the Courier inbound endpoints (`/api-inbound/`), forwarded over HTTPS to Core Hub's inbound server on port 8090 |
| 1717 | Backend Services | TCP | Internal HTTPS for CoreHub/Chronos |
| 3000 | Grafana | TCP | Monitoring dashboard |
| 9090 | Prometheus | TCP | Metrics collection |

### SSL/TLS

- **Frontend TLS**: Traefik terminates TLS using self-signed certificates
- **Backend TLS**: Services use self-signed certificates (validated by ServersTransport)
- **Certificate Warnings**: Expected in browsers due to self-signed certs

## Firewall Configuration

### AWS EKS
Ensure your security groups allow inbound traffic on ports 80, 443 and 8090 (Courier inbound endpoints).

### Google GKE
```bash
gcloud compute firewall-rules create allow-gluesync \
  --allow tcp:80,tcp:443,tcp:8090 \
  --source-ranges=0.0.0.0/0
```

### Azure AKS
```bash
az network nsg rule create \
  --resource-group <your-rg> \
  --nsg-name <your-nsg> \
  --name allow-gluesync \
  --priority 100 \
  --destination-port-ranges 80 443 8090 \
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
1. Check if ports are already in use: `lsof -i :8443`
2. Ensure the service is running: `kubectl get pods -n gluesync-dev`
3. Try different ports: `kubectl port-forward ... 18443:443`

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
