# FluxCD Platform - Quick Reference

## Getting Started

### Complete Setup (Recommended - Local Development)
```bash
make provision
```
Creates cluster, installs Flux, applies infrastructure with kubectl. Takes 5-10 minutes.

**Note:** For local development, this uses `kubectl apply -k` to deploy manifests.
Flux controllers (helm-controller, source-controller) still manage the Helm releases.

### Production Setup (Git-based)
```bash
export GITHUB_TOKEN=<token>
flux bootstrap github \
  --owner=<org> \
  --repository=fluxcd-platform-cmdr \
  --branch=main \
  --path=clusters/fluxcd-platform
```
This enables automatic Git-based reconciliation.

### Step-by-Step Setup
```bash
make up          # Create cluster + install Flux
make reconcile   # Deploy infrastructure via Flux
make status      # Check everything
```

## Daily Commands

### Check Status
```bash
make status              # Overall cluster status
flux check               # Flux health check
flux get all             # All Flux resources
kubectl get pods -A      # All pods
```

### Access Services
```bash
make monitoring          # Open Grafana/Prometheus/AlertManager
make traffic             # Generate sample metrics
```

### Manage Flux
```bash
make reconcile           # Re-apply all infrastructure with kubectl
make logs                # Follow Flux logs
flux get helmreleases -A # View Helm release status
kubectl apply -k infrastructure/controllers  # Apply controllers only
kubectl apply -k infrastructure/configs      # Apply configs only
```

### Monitoring URLs (after `make monitoring`)
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **AlertManager**: http://localhost:9093

## Architecture

```
provision-cluster.sh (Local Development)
├── Creates k3d cluster
├── Installs FluxCD
└── Applies manifests with kubectl
    ├── infrastructure/controllers (Helm releases)
    │   ├── cert-manager
    │   ├── kube-prometheus-stack
    │   └── external-secrets
    └── infrastructure/configs
        ├── cert-manager issuers
        ├── external-secrets stores
        └── sample-app with metrics

Note: Flux controllers (helm-controller, source-controller) 
      manage the Helm releases, but manifests are applied 
      directly with kubectl for local development.

For production: Use 'flux bootstrap' to enable Git-based 
                reconciliation via Flux Kustomizations.
```

## File Structure

```
.
├── provision-cluster.sh              # 🎯 Complete setup script
├── setup-cluster.sh                  # Cluster creation only
├── teardown-cluster.sh               # Cleanup
├── access-monitoring.sh              # Access monitoring UIs
├── generate-metrics-traffic.sh       # Generate sample traffic
│
├── clusters/fluxcd-platform/         # Flux entry point
│   ├── infrastructure.yaml           # Controllers kustomization
│   └── infrastructure-configs.yaml   # Configs kustomization
│
├── infrastructure/
│   ├── controllers/                  # Helm releases
│   │   ├── kustomization.yaml
│   │   ├── cert-manager-*.yaml
│   │   ├── kube-prometheus-stack-*.yaml
│   │   └── external-secrets-*.yaml
│   │
│   └── configs/                      # Post-deployment configs
│       ├── kustomization.yaml
│       ├── cert-manager-issuers.yaml
│       ├── external-secrets-stores.yaml
│       └── sample-app-with-metrics.yaml
│
└── Makefile                          # Convenience commands
```

## Flux Reconciliation Flow

### Local Development Mode (provision-cluster.sh)
1. Manifests applied directly with `kubectl apply -k`
2. **Helm Controller** watches HelmRelease resources and installs charts
3. **Source Controller** syncs HelmRepository sources
4. Charts deployed: cert-manager, kube-prometheus-stack, external-secrets

### Production Mode (flux bootstrap)
1. **GitRepository** (`flux-system`) syncs from remote Git repo
2. **Kustomization** resources watch Git paths and apply manifests
3. **Helm Controller** installs charts based on HelmRelease resources
4. Automatic reconciliation on Git commits

## Useful Flux Commands

```bash
# View resources
flux get sources helm        # Helm repositories
flux get helmreleases        # Helm releases

# Logs
flux logs --all-namespaces --follow
flux logs --kind=HelmRelease --name=kube-prometheus-stack

# For production (Git-based) only:
flux get sources git
flux get kustomizations
flux reconcile source git flux-system
flux reconcile kustomization infrastructure-controllers
flux suspend kustomization <name>
flux resume kustomization <name>
flux export kustomization <name>
```

## Common Issues

### "Kustomization not ready"
This is expected in local development mode. We apply manifests directly with kubectl.
For production, bootstrap with Git to use Flux Kustomizations.

### "HelmRelease failed"
```bash
flux get helmreleases -A
kubectl describe helmrelease kube-prometheus-stack -n flux-system
kubectl -n flux-system logs deployment/helm-controller -f
```

### "HelmRelease failed"
```bash
flux get helmreleases -A
kubectl describe helmrelease kube-prometheus-stack -n flux-system
kubectl -n flux-system logs deployment/helm-controller
```

### "No metrics in Grafana"
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090/targets

# Check ServiceMonitor
kubectl get servicemonitor -A
```

### "Sample app not generating metrics"
```bash
kubectl get pods -n sample-app
kubectl logs -n sample-app -l app=sample-metrics-app
make traffic  # Restart traffic generator
```

## Cleanup

```bash
make down                            # Delete cluster
./stop-portforward.sh                # Stop port-forwards
k3d cluster delete fluxcd-platform   # Force delete
```

## Documentation

- `README.md` - Main documentation
- `MONITORING-QUICKSTART.md` - Monitoring guide with queries
- `MONITORING.md` - Detailed monitoring setup
- `SETUP-EXTERNAL-SECRETS.md` - External secrets configuration
- `TESTING-CERT-MANAGER.md` - Certificate management

## Key Concepts

### Kustomization (Flux)
A Flux resource that watches a path in a Git repo and applies the Kubernetes manifests found there.

### HelmRelease
A Flux resource that tells Helm Controller to install/upgrade a Helm chart.

### HelmRepository
A Flux resource that points to a Helm chart repository.

### ServiceMonitor
A Prometheus Operator resource that tells Prometheus what to scrape.

### PrometheusRule
A Prometheus Operator resource that defines alerts.

## Bootstrap from Git (Production)

For real Git integration instead of local development:

```bash
export GITHUB_TOKEN=<your-token>
flux bootstrap github \
  --owner=<your-org> \
  --repository=fluxcd-platform-cmdr \
  --branch=main \
  --path=clusters/fluxcd-platform \
  --personal
```

This will:
1. Create deploy key in your repo
2. Install Flux in the cluster
3. Create GitRepository pointing to your repo
4. Apply all Kustomizations from `clusters/fluxcd-platform/`
5. Commit and push Flux manifests back to repo

## Tips

- Use `make provision` for quick setup
- Use `make status` frequently to check health
- HelmReleases take 2-5 minutes to install
- Grafana dashboards may take 1-2 minutes to appear after first start
- Sample app needs traffic to show interesting metrics
- Check MONITORING-QUICKSTART.md for PromQL query examples

## Support

- FluxCD Docs: https://fluxcd.io/docs/
- k3d Docs: https://k3d.io/
- Prometheus Docs: https://prometheus.io/docs/
- Grafana Docs: https://grafana.com/docs/
