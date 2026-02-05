# Monitoring Stack - Quick Start Guide

This guide shows you how to bring your monitoring stack to life with real metrics from your k3d cluster.

## What We've Added

1. **Enhanced Grafana Configuration**
   - Auto-provisioned dashboards
   - Better datasource configuration
   - Default Kubernetes dashboards enabled

2. **Improved Scrapers**
   - Node exporter with host network access for better node metrics
   - Enhanced kubelet monitoring via HTTPS
   - CoreDNS metrics collection
   - Kube-proxy metrics

3. **Sample Application with Metrics**
   - A demo app that exposes Prometheus metrics
   - ServiceMonitor to automatically scrape metrics
   - Sample alerts to populate AlertManager

4. **Traffic Generator**
   - Script to generate realistic HTTP traffic
   - Creates interesting metrics to view in Grafana/Prometheus

## Getting Started

### 1. Deploy the Enhanced Monitoring Stack

Apply the changes using Flux:

```bash
# Reconcile controllers (updates kube-prometheus-stack)
flux reconcile kustomization infrastructure-controllers --with-source

# Reconcile configs (deploys sample app)
flux reconcile kustomization infrastructure-configs --with-source
```

Or apply directly with kubectl:

```bash
kubectl apply -k infrastructure/controllers
kubectl apply -k infrastructure/configs
```

### 2. Wait for Everything to be Ready

```bash
# Check monitoring stack
kubectl get pods -n monitoring

# Check sample app
kubectl get pods -n sample-app

# Use the helper script
./check-monitoring.sh
```

### 3. Access the Monitoring UIs

```bash
./access-monitoring.sh
```

Choose option **4) All services (in background)** to access all three UIs:
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **AlertManager**: http://localhost:9093

### 4. Generate Traffic for Interesting Metrics

In a new terminal, run:

```bash
./generate-metrics-traffic.sh
```

This will generate random HTTP traffic to the sample app, creating metrics you can view in real-time.

## What to Explore

### In Grafana (http://localhost:3000)

1. **Home → Dashboards**
   - Look for pre-installed dashboards like:
     - "Kubernetes / Compute Resources / Cluster"
     - "Kubernetes / Compute Resources / Namespace (Pods)"
     - "Node Exporter / Nodes"
     - "Prometheus / Overview"

2. **Explore → Metrics**
   - Try queries like:
     ```promql
     # Sample app request rate
     rate(http_requests_total{namespace="sample-app"}[5m])
     
     # Node CPU usage
     node_cpu_seconds_total
     
     # Pod memory usage
     container_memory_usage_bytes{namespace="sample-app"}
     
     # Number of pods
     count(kube_pod_info)
     ```

### In Prometheus (http://localhost:9090)

1. **Status → Targets**
   - See all the endpoints Prometheus is scraping
   - Should see:
     - sample-metrics-app
     - kube-state-metrics
     - node-exporter
     - kubelet
     - coredns
     - Various k8s API server endpoints

2. **Graph → Execute Queries**
   - Try the same queries as above
   - Use the Graph tab to visualize trends

3. **Alerts**
   - View configured alert rules
   - See which alerts are firing (if any)

### In AlertManager (http://localhost:9093)

1. **View Alerts**
   - Initially may be empty
   - Sample alerts will fire if conditions are met:
     - `SampleAppDown` - fires if sample app goes down
     - `SampleAppHighRequestRate` - fires if request rate > 10 req/sec

2. **Silence Alerts** (optional)
   - Click "New Silence" to temporarily mute alerts

## Sample Queries to Try

### Application Metrics
```promql
# Request rate
rate(http_requests_total{namespace="sample-app"}[5m])

# Request latency
rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])

# Total requests
sum(http_requests_total{namespace="sample-app"})
```

### Cluster Metrics
```promql
# Node CPU usage
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Node memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Pod count by namespace
count(kube_pod_info) by (namespace)

# Container CPU usage
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod, namespace)
```

### Prometheus Self-Monitoring
```promql
# Prometheus scrape duration
prometheus_target_scrape_duration_seconds

# Number of active targets
count(up)

# Prometheus memory usage
process_resident_memory_bytes{job="prometheus"}
```

## Troubleshooting

### No Metrics Showing Up

```bash
# Check if Prometheus is scraping targets
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090

# Open http://localhost:9090/targets
# All targets should show as "UP"
```

### Sample App Not Working

```bash
# Check if pods are running
kubectl get pods -n sample-app

# Check logs
kubectl logs -n sample-app -l app=sample-metrics-app

# Restart the app
kubectl rollout restart deployment/sample-metrics-app -n sample-app
```

### ServiceMonitor Not Being Picked Up

```bash
# Check if ServiceMonitor exists
kubectl get servicemonitor -n sample-app

# Check Prometheus config (look for sample-metrics-app)
kubectl get secret -n monitoring prometheus-monitoring-kube-prometheus-prometheus -o json | \
  jq -r '.data["prometheus.yaml.gz"]' | base64 -d | gunzip
```

## Adding More Metrics

### Option 1: Annotate Your Pods

Add these annotations to any pod to enable automatic scraping:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
```

### Option 2: Create a ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: my-namespace
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
  - port: metrics
    interval: 30s
```

## Next Steps

1. **Customize Dashboards**
   - Create your own Grafana dashboards
   - Import community dashboards from grafana.com

2. **Configure Real Alerts**
   - Edit `infrastructure/configs/sample-app-with-metrics.yaml`
   - Add PrometheusRule resources for your apps

3. **Set Up Alert Receivers**
   - Configure AlertManager to send notifications (Slack, email, PagerDuty, etc.)
   - Create an AlertManager configuration in `infrastructure/configs/`

4. **Add Persistent Storage**
   - Uncomment the `storageSpec` section in `kube-prometheus-stack-release.yaml`
   - Metrics will survive pod restarts

## Clean Up

To stop everything:

```bash
# Stop traffic generator
# (Press Ctrl+C in the terminal running generate-metrics-traffic.sh)

# Stop port-forwards
# (Press Ctrl+C in the terminal running access-monitoring.sh)
# Or run:
./stop-portforward.sh

# Remove sample app (optional)
kubectl delete namespace sample-app
```

## References

- [Prometheus Query Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
