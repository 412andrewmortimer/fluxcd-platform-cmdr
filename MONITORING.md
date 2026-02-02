# Monitoring Stack with Prometheus & Grafana

This directory contains the FluxCD configuration for deploying a complete monitoring stack using kube-prometheus-stack.

## 📋 Table of Contents

- [Overview](#overview)
- [Components](#components)
- [Installation](#installation)
- [Access Services](#access-services)
- [Configuration](#configuration)
- [Integration with cert-manager](#integration-with-cert-manager)
- [Troubleshooting](#troubleshooting)

---

## Overview

The monitoring stack provides comprehensive observability for your Kubernetes cluster:

- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization and dashboards
- **Alertmanager** - Alert routing and management
- **Prometheus Operator** - CRD-based monitoring configuration
- **Node Exporter** - Node-level metrics
- **Kube State Metrics** - Kubernetes object metrics

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Flux GitOps Controller                       │
│  (Watches infrastructure/controllers/kube-prometheus-stack)     │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Prometheus Operator                           │
│  (Manages Prometheus, Alertmanager, ServiceMonitors)           │
└──┬───────────────┬────────────────────┬────────────────────┬───┘
   │               │                    │                    │
   ▼               ▼                    ▼                    ▼
┌────────┐  ┌──────────┐      ┌──────────────┐      ┌────────────┐
│Prometheus│ │Alertmanager│    │   Grafana    │      │Node Exporter│
│          │ │            │    │              │      │(DaemonSet) │
│ Scrapes: │ │  Alerts    │    │ Dashboards   │      │            │
│ - K8s    │ │  Routing   │    │ - Prometheus │      │ Host       │
│ - Pods   │ │  Silence   │    │ - Data Source│      │ Metrics    │
│ - Apps   │ │            │    │              │      │            │
└────────┘  └──────────┘      └──────────────┘      └────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────────┐
│              ServiceMonitors (Auto-Discovery)                   │
│  - cert-manager metrics                                         │
│  - Kubernetes API server                                        │
│  - Kubelet                                                      │
│  - Custom application metrics                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Components

### Installed Components

| Component | Version | Replicas | Resources | Purpose |
|-----------|---------|----------|-----------|---------|
| **Prometheus Operator** | Latest | 1 | 128Mi-256Mi | Manages Prometheus instances |
| **Prometheus** | Latest | 1 | 512Mi-2Gi | Metrics collection & storage |
| **Alertmanager** | Latest | 1 | 32Mi-128Mi | Alert management |
| **Grafana** | Latest | 1 | 128Mi-256Mi | Dashboards & visualization |
| **Node Exporter** | Latest | DaemonSet | Default | Node-level metrics |
| **Kube State Metrics** | Latest | 1 | Default | K8s object metrics |

### Ports

| Service | Port | Protocol | Access |
|---------|------|----------|--------|
| Grafana | 3000 (80) | HTTP | Dashboard UI |
| Prometheus | 9090 | HTTP | Prometheus UI & API |
| Alertmanager | 9093 | HTTP | Alert management UI |

---

## Installation

### Prerequisites

- k3d cluster running (or any Kubernetes cluster)
- Flux installed and configured
- kubectl configured

### Deploy the Monitoring Stack

1. **Apply the configuration:**

```bash
# Using the mimic script (for non-Git workflow)
./mimic-flux-reconcile.sh

# Or if using Git-based GitOps
git add infrastructure/controllers/
git commit -m "Add kube-prometheus-stack monitoring"
git push origin main
```

2. **Watch the deployment:**

```bash
# Watch Flux reconciliation
flux get helmreleases -A --watch

# Watch pods being created
kubectl get pods -n monitoring --watch

# Check overall status
./check-monitoring.sh
```

3. **Verify installation:**

```bash
# Check all components are running
kubectl get all -n monitoring

# Check HelmRelease status
flux get helmrelease kube-prometheus-stack -n flux-system

# Verify ServiceMonitors
kubectl get servicemonitors -n monitoring
```

---

## Access Services

### Quick Access (Interactive Menu)

```bash
./access-monitoring.sh
```

This launches an interactive menu to access:
1. Grafana Dashboard
2. Prometheus
3. Alertmanager
4. All services at once

### Manual Access

#### Grafana

```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Open browser to: http://localhost:3000
# Username: admin
# Password: admin
```

**Default Credentials:**
- Username: `admin`
- Password: `admin`

⚠️ **IMPORTANT:** Change the default password in production!

#### Prometheus

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Open browser to: http://localhost:9090
```

**Useful Prometheus URLs:**
- Metrics: http://localhost:9090/metrics
- Targets: http://localhost:9090/targets
- Alerts: http://localhost:9090/alerts

#### Alertmanager

```bash
# Port-forward to Alertmanager
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093

# Open browser to: http://localhost:9093
```

### Access All Services at Once

```bash
# Run in background
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 &
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093 &

# Access at:
# Grafana:      http://localhost:3000
# Prometheus:   http://localhost:9090
# Alertmanager: http://localhost:9093
```

---

## Configuration

### Key Configuration Files

```
infrastructure/controllers/
├── prometheus-source.yaml              # Helm repository
├── kube-prometheus-stack-release.yaml  # Main configuration
└── kustomization.yaml                  # Includes all resources
```

### Important Settings

#### Storage (Ephemeral by Default)

The default configuration uses **emptyDir** storage (data is lost on pod restart).

**For production, enable persistent storage:**

```yaml
# In kube-prometheus-stack-release.yaml
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
          # Optional: specify storage class
          # storageClassName: "local-path"
```

#### Retention

```yaml
prometheus:
  prometheusSpec:
    retention: 7d        # Keep metrics for 7 days
    retentionSize: "5GB" # Max storage size
```

#### Resources

Adjust based on your cluster size:

```yaml
prometheus:
  prometheusSpec:
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        memory: 2Gi
```

### Grafana Configuration

#### Change Admin Password

**Method 1: Via values (at installation)**

```yaml
grafana:
  adminPassword: "your-secure-password"
```

**Method 2: Via Grafana UI**

1. Login to Grafana
2. Click your profile (bottom left)
3. Preferences → Change Password

**Method 3: Via kubectl**

```bash
kubectl exec -n monitoring -it \
  $(kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o name) \
  -- grafana-cli admin reset-admin-password <new-password>
```

#### Add Custom Dashboards

1. **Via Grafana UI:**
   - Login to Grafana
   - Click "+" → Import
   - Enter dashboard ID from https://grafana.com/grafana/dashboards/

2. **Via ConfigMap (GitOps way):**

```yaml
# In kube-prometheus-stack-release.yaml
grafana:
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: 'custom'
        orgId: 1
        folder: 'Custom'
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/custom
  
  dashboards:
    custom:
      my-dashboard:
        url: https://raw.githubusercontent.com/user/repo/main/dashboard.json
```

---

## Integration with cert-manager

The monitoring stack is configured to automatically scrape metrics from cert-manager.

### Verification

```bash
# Check cert-manager ServiceMonitor exists
kubectl get servicemonitor -n cert-manager

# Check Prometheus is scraping cert-manager
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Open http://localhost:9090/targets
# Look for "cert-manager" targets
```

### cert-manager Metrics

Available metrics in Prometheus:

```
certmanager_controller_sync_call_count
certmanager_certificate_expiration_timestamp_seconds
certmanager_certificate_ready_status
certmanager_http_acme_client_request_count
certmanager_http_acme_client_request_duration_seconds
```

### Example Queries

```promql
# Certificates expiring in next 7 days
(certmanager_certificate_expiration_timestamp_seconds - time()) / 86400 < 7

# Certificate renewal rate
rate(certmanager_controller_sync_call_count{controller="certificates"}[5m])

# Certificate ready status
certmanager_certificate_ready_status
```

### Pre-built Dashboards

The stack includes pre-built dashboards:

1. **Kubernetes / Compute Resources / Cluster** - Overall cluster metrics
2. **Kubernetes / Compute Resources / Namespace (Pods)** - Per-namespace resources
3. **Kubernetes / Compute Resources / Pod** - Per-pod resources
4. **Node Exporter / Nodes** - Node-level metrics

---

## Troubleshooting

### Check Status

```bash
# Run the status script
./check-monitoring.sh

# Or manually check
kubectl get all -n monitoring
flux get helmrelease kube-prometheus-stack -n flux-system
```

### Common Issues

#### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n monitoring

# View pod logs
kubectl logs -n monitoring <pod-name>

# Describe pod for events
kubectl describe pod -n monitoring <pod-name>
```

#### HelmRelease Failing

```bash
# Check HelmRelease status
kubectl describe helmrelease -n flux-system kube-prometheus-stack

# Check Flux helm-controller logs
kubectl logs -n flux-system deployment/helm-controller -f

# Force reconciliation
flux reconcile helmrelease kube-prometheus-stack -n flux-system
```

#### ServiceMonitor Not Working

```bash
# Check ServiceMonitor exists
kubectl get servicemonitor -n monitoring
kubectl get servicemonitor -n cert-manager

# Check Prometheus Operator logs
kubectl logs -n monitoring deployment/kube-prometheus-stack-operator -f

# Check Prometheus config
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit http://localhost:9090/config
```

#### Grafana Can't Connect to Prometheus

```bash
# Check datasource configuration
kubectl get secret -n monitoring kube-prometheus-stack-grafana -o yaml

# Test Prometheus connection from within cluster
kubectl run -n monitoring test-curl --rm -it --image=curlimages/curl -- \
  curl http://kube-prometheus-stack-prometheus.monitoring.svc:9090/api/v1/status/config
```

#### Storage Issues

```bash
# Check PVCs (if using persistent storage)
kubectl get pvc -n monitoring

# Check storage usage in Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Query: prometheus_tsdb_storage_blocks_bytes
```

### Debug Commands

```bash
# Get all resources in monitoring namespace
kubectl get all -n monitoring -o wide

# Check events
kubectl get events -n monitoring --sort-by='.lastTimestamp'

# Check Flux reconciliation
flux get all

# View Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit http://localhost:9090/targets

# Check Alertmanager config
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# Visit http://localhost:9093/#/status
```

### Reset/Reinstall

```bash
# Delete the HelmRelease
kubectl delete helmrelease kube-prometheus-stack -n flux-system

# Delete the namespace (this will delete all data)
kubectl delete namespace monitoring

# Reapply
./mimic-flux-reconcile.sh
```

---

## Advanced Configuration

### Enable Persistent Storage

```yaml
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
```

### High Availability Setup

```yaml
prometheus:
  prometheusSpec:
    replicas: 2

alertmanager:
  alertmanagerSpec:
    replicas: 3

grafana:
  replicas: 2
```

### External Access via Ingress

```yaml
grafana:
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    hosts:
      - grafana.example.com
    tls:
      - secretName: grafana-tls
        hosts:
          - grafana.example.com
```

### Custom Alertmanager Config

```yaml
alertmanager:
  config:
    global:
      resolve_timeout: 5m
    route:
      group_by: ['alertname']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'slack'
    receivers:
    - name: 'slack'
      slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts'
```

---

## Resources

- [kube-prometheus-stack Documentation](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Prometheus Operator](https://prometheus-operator.dev/)

---

## Quick Reference

### Helper Scripts

```bash
./access-monitoring.sh    # Interactive menu to access services
./check-monitoring.sh     # Check monitoring stack status
./mimic-flux-reconcile.sh # Apply/update configuration
```

### Key kubectl Commands

```bash
# Get all resources
kubectl get all -n monitoring

# Check pods
kubectl get pods -n monitoring -w

# Check services
kubectl get svc -n monitoring

# Check ServiceMonitors
kubectl get servicemonitor -A

# View logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -f

# Port-forward Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

### Default Credentials

- **Grafana**: admin / admin
- **Prometheus**: No authentication
- **Alertmanager**: No authentication

⚠️ **Change default credentials in production!**

---

**For issues or questions, check the Troubleshooting section above or refer to the official documentation.**
