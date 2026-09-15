# Gluesync Kubernetes volume configuration

The chart enables persistent storage by default. Configure storage in the
`persistence` section of `values.yaml` before installation.

## Default persistent volumes

| Component | Purpose | Default size | Mount path |
|---|---|---:|---|
| Core Hub | Data | 100 GiB | `/opt/gluesync/data` |
| Core Hub | Logs | 10 GiB | `/opt/gluesync/logs` |
| Chronos | Data | 1 GiB | `/app/data` |
| Chronos | Logs | 2 GiB | `/app/logs` |
| Prometheus | Metrics | 10 GiB | `/prometheus` |
| Grafana | Database, plugins, and user data | 5 GiB | `/var/lib/grafana` |

The chart uses `ReadWriteOnce`. Set `persistence.storageClass` to a storage
class available in your cluster, or leave it empty to use the cluster default.

Grafana datasource provisioning is mounted from the `grafana-datasources`
ConfigMap. Dashboards and the dashboard provider are included in the
`molo17/grafana` image and are not mounted from a chart ConfigMap.

## Customize storage

Edit the supplied `values.yaml`; do not replace it with the blank values from
the public chart example because the generated file also contains the trial
licence and security material.

```yaml
persistence:
  enabled: true
  storageClass: "your-storage-class"
  accessMode: ReadWriteOnce
  coreHub:
    enabled: true
    data:
      enabled: true
      size: 100Gi
      mountPath: /opt/gluesync/data
    logs:
      enabled: true
      size: 10Gi
      mountPath: /opt/gluesync/logs
  grafana:
    enabled: true
    size: 5Gi
    mountPath: /var/lib/grafana
```

After changing values, upgrade the release from this chart directory:

```bash
helm upgrade gluesync . --namespace gluesync-dev
```

## Ephemeral Grafana storage

If global persistence or Grafana persistence is disabled, the Grafana
deployment falls back to an `emptyDir` volume. Its data is then lost whenever
the Pod is replaced.

## Verify storage

```bash
kubectl get pvc -n gluesync-dev
kubectl describe pvc gluesync-core-hub -n gluesync-dev
kubectl describe pod -n gluesync-dev \
  -l app.kubernetes.io/name=gluesync-grafana
```

If a claim remains `Pending`, confirm that the configured storage class exists:

```bash
kubectl get storageclass
kubectl describe pvc -n gluesync-dev
```
