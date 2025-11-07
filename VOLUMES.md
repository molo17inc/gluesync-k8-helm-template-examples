# Gluesync Kubernetes - Volume Configuration

This document describes the volume mounts and storage configuration for Gluesync components.

## Grafana Volumes

Grafana uses two volumes matching the Docker Compose configuration:

### 1. Provisioning Volume

- **Mount Path**: `/etc/grafana/provisioning`
- **Type**: ConfigMap (`grafana-provisioning`)
- **Purpose**: Contains Grafana provisioning configuration (datasources, dashboards)
- **Source**: ConfigMap with datasources.yml

### 2. Data Volume

- **Mount Path**: `/var/lib/grafana`
- **Type**: emptyDir (ephemeral) or PersistentVolumeClaim (persistent)
- **Purpose**: Stores Grafana database, plugins, and user data
- **Contents**:
  - `grafana.db` - SQLite database
  - `plugins/` - Installed plugins
  - `csv/`, `pdf/`, `png/` - Export directories

## Storage Options

### Development (Current Configuration)

Uses `emptyDir` volumes:

- **Pros**: Simple, no setup required
- **Cons**: Data lost when pod restarts
- **Use Case**: Local development, testing

```yaml
volumes:
  - name: grafana-data
    emptyDir: {}
```

### Production (Recommended)

Use PersistentVolumeClaims for data persistence:

**Benefits:**

- Data survives pod restarts
- Supports backup/restore
- Better for production use

**Example PVC:**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

Then update deployment:

```yaml
volumes:
  - name: grafana-data
    persistentVolumeClaim:
      claimName: grafana-data
```

## Volume Comparison: Docker vs Kubernetes

| Component | Docker Compose | Kubernetes | Notes |
|-----------|----------------|------------|-------|
| **Grafana Provisioning** | `./grafana:/etc/grafana/provisioning` | ConfigMap → `/etc/grafana/provisioning` | Config files |
| **Grafana Data** | `./data:/var/lib/grafana` | emptyDir → `/var/lib/grafana` | User data, DB |

## Adding Persistent Storage

To enable persistent storage for Grafana:

1. Create a PVC:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-data
  namespace: gluesync-dev
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF
```

2. Update `values.yaml`:

```yaml
grafana:
  persistence:
    enabled: true
    storageClass: "" # or specify your storage class
    size: 5Gi
```

3. Upgrade the deployment:

```bash
helm upgrade gluesync . --namespace gluesync-dev
```

## Verifying Volumes

Check mounted volumes:

```bash
# View volume mounts
kubectl describe pod -n gluesync-dev -l app.kubernetes.io/name=gluesync-grafana | grep -A 5 "Mounts:"

# Check provisioning content
kubectl exec -n gluesync-dev deployment/gluesync-gluesync-grafana -- ls -la /etc/grafana/provisioning/

# Check data directory 
kubectl exec -n gluesync-dev deployment/gluesync-gluesync-grafana -- ls -la /var/lib/grafana/
```

## Backup and Restore

### Backup Grafana Data

```bash
# Create backup
kubectl exec -n gluesync-dev deployment/gluesync-gluesync-grafana -- \
  tar czf - /var/lib/grafana > grafana-backup-$(date +%Y%m%d).tar.gz
```

### Restore Grafana Data

```bash
# Restore from backup
kubectl exec -n gluesync-dev deployment/gluesync-gluesync-grafana -- \
  tar xzf - -C / < grafana-backup-YYYYMMDD.tar.gz

# Restart pod
kubectl rollout restart deployment/gluesync-gluesync-grafana -n gluesync-dev
```

## Troubleshooting

### Issue: Grafana loses data after restart

**Cause**: Using emptyDir volume  
**Solution**: Switch to PersistentVolumeClaim

### Issue: Permission denied errors

**Cause**: Volume permissions don't match Grafana user (UID 472)  
**Solution**: Add securityContext to deployment:

```yaml
securityContext:
  fsGroup: 472
```

### Issue: PVC not binding

**Cause**: No available storage or wrong storage class  
**Solution**: Check available storage classes:

```bash
kubectl get storageclass
kubectl describe pvc grafana-data -n gluesync-dev
```
