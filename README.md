# FluxCD Platform cmdr

A clean setup for running FluxCD against a k3d cluster.

## Prerequisites

Install the following tools:

```bash
# k3d (k3s in Docker)
brew install k3d

# kubectl
brew install kubectl

# FluxCD CLI
brew install fluxcd/tap/flux
```

## Quick Start

### One-Command Provisioning

The easiest way to get started (local development):

```bash
make provision
# Or directly:
./provision-cluster.sh
```

This will:
- Create a k3d cluster with 1 server and 2 agent nodes
- Install FluxCD components
- Apply infrastructure manifests directly (using `kubectl apply -k`)
- Wait for Helm releases to be deployed
- Display status and next steps

**Note:** For local development, this applies manifests directly with kubectl.
For production with Git integration, see the "Bootstrap from Git" section below.

**That's it!** In 5-10 minutes you'll have a complete platform running.

### Manual Setup (Step by Step)

If you prefer more control:

#### 1. Create the Cluster

```bash
make up
# Or:
./setup-cluster.sh
```

This will:
- Create a k3d cluster
- Expose ports 8080 (HTTP) and 8443 (HTTPS)
- Install FluxCD components
- Configure kubectl context

#### 2. Deploy Infrastructure with Flux

```bash
make reconcile
# Or:
kubectl apply -k infrastructure/controllers
kubectl apply -k infrastructure/configs
```

This deploys:
- Cert-manager
- Kube-Prometheus-Stack (Grafana, Prometheus, AlertManager)
- External Secrets Operator
- Sample app with metrics

### Bootstrap from Git (Production)

For production environments with real Git integration:

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
- Create a deploy key in your GitHub repo
- Install Flux in the cluster
- Create a GitRepository pointing to your repo
- Apply all Kustomizations from `clusters/fluxcd-platform/`
- Commit Flux manifests back to the repo
- Enable automatic reconciliation from Git

See [Flux Bootstrap Guide](https://fluxcd.io/flux/installation/bootstrap/) for more options.

### 3. Verify Installation

```bash
# Check all components
make status

# Check Flux specifically
flux check

# View all Flux resources
flux get all

# Watch reconciliation
flux get kustomizations
flux get helmreleases
```

### 4. Access Monitoring Stack

```bash
make monitoring
# Or:
./access-monitoring.sh
```

Choose option 4 to access all services:
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **AlertManager**: http://localhost:9093

See **MONITORING-QUICKSTART.md** for a detailed guide.

### 5. Generate Traffic (Optional)

To see real metrics in action:

```bash
make traffic
# Or:
./generate-metrics-traffic.sh
```

## Cluster Configuration

The `k3d-config.yaml` defines:
- **Cluster name**: fluxcd-platform
- **Nodes**: 1 server + 2 agents
- **Port mapping**: 8080→80, 8443→443
- **Traefik**: Disabled (use your own ingress controller)

## Directory Structure

```
.
├── k3d-config.yaml          # k3d cluster configuration
├── setup-cluster.sh         # Cluster creation script
├── teardown-cluster.sh      # Cluster deletion script
├── clusters/                # FluxCD cluster configs
│   └── fluxcd-platform/     # This cluster's manifests
│       ├── flux-system/     # Flux components (auto-generated)
│       └── apps/            # Your applications
├── infrastructure/          # Shared infrastructure
│   ├── controllers/         # Ingress, cert-manager, etc.
│   └── configs/             # ConfigMaps, Secrets
└── apps/                    # Application definitions
    ├── base/                # Base manifests
    └── overlays/            # Environment-specific overlays
```

## Common Operations

### Check Status

```bash
make status
```

### Access Services

```bash
# Monitoring stack
make monitoring

# Generate sample traffic
make traffic
```

### Force Reconciliation

```bash
make reconcile
```

### View Logs

```bash
make logs

# Or specific controller
kubectl -n flux-system logs deployment/source-controller -f
```

## Cleanup

```bash
make down
# Or:
./teardown-cluster.sh
```

## What's Deployed

After running `make provision`, you get:

### Infrastructure Controllers
- **Cert-Manager** - Automated TLS certificate management
- **Kube-Prometheus-Stack** - Complete monitoring solution
  - Prometheus - Metrics collection and alerting
  - Grafana - Metrics visualization and dashboards
  - AlertManager - Alert routing and management
  - Node Exporter - Hardware and OS metrics
  - Kube-State-Metrics - Kubernetes object metrics
- **External Secrets Operator** - Sync secrets from external stores

### Infrastructure Configs
- **Sample App** - Demo application with Prometheus metrics
- **ServiceMonitors** - Automatic metrics scraping configuration
- **PrometheusRules** - Sample alerts

### Flux Components
- **Source Controller** - Git repository synchronization
- **Kustomize Controller** - Applies Kustomization resources
- **Helm Controller** - Manages Helm releases
- **Notification Controller** - Event forwarding

## Troubleshooting

### Flux not reconciling

```bash
# Check Flux status
flux check

# View all resources
flux get all

# Check events
kubectl -n flux-system get events --sort-by='.lastTimestamp'

# Manually trigger reconciliation
make reconcile
```

### Monitoring stack not ready

```bash
# Check pods
kubectl get pods -n monitoring

# Check HelmRelease status
flux get helmreleases -A

# View Helm controller logs
kubectl -n flux-system logs deployment/helm-controller -f
```

### Access cluster services

```bash
# Port forward a service
kubectl port-forward -n default svc/myapp 8080:80

# Or use the LoadBalancer ports (8080, 8443)
curl http://localhost:8080
```

### Reset Flux

```bash
flux uninstall
flux install
```

## References

- [FluxCD Documentation](https://fluxcd.io/docs/)
- [k3d Documentation](https://k3d.io/)
- [Flux Bootstrap Guide](https://fluxcd.io/flux/installation/bootstrap/)
