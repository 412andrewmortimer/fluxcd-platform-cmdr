# FluxCD Platform Commander

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

### 1. Create the Cluster

```bash
chmod +x setup-cluster.sh teardown-cluster.sh
./setup-cluster.sh
```

This will:
- Create a k3d cluster with 1 server and 2 agent nodes
- Expose ports 8080 (HTTP) and 8443 (HTTPS)
- Install FluxCD components
- Configure kubectl context

### 2. Bootstrap FluxCD with Git

#### Option A: GitHub

```bash
export GITHUB_TOKEN=<your-token>
flux bootstrap github \
  --owner=<your-org> \
  --repository=<your-repo> \
  --branch=main \
  --path=clusters/fluxcd-platform \
  --personal
```

#### Option B: GitLab

```bash
export GITLAB_TOKEN=<your-token>
flux bootstrap gitlab \
  --owner=<your-org> \
  --repository=<your-repo> \
  --branch=main \
  --path=clusters/fluxcd-platform
```

#### Option C: Local Development (without Git)

For quick testing without Git integration:

```bash
# Create a local structure
mkdir -p clusters/fluxcd-platform/apps

# Apply manifests directly
kubectl apply -k clusters/fluxcd-platform
```

### 3. Verify Installation

```bash
# Check Flux components
flux check

# View Flux pods
kubectl -n flux-system get pods

# Watch reconciliation
flux get sources git
flux get kustomizations
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

### Deploy an Application

```bash
# Create a GitRepository source
flux create source git myapp \
  --url=https://github.com/org/repo \
  --branch=main \
  --interval=1m

# Create a Kustomization
flux create kustomization myapp \
  --source=myapp \
  --path="./deploy" \
  --prune=true \
  --interval=5m
```

### View Logs

```bash
# Flux logs
flux logs --all-namespaces

# Specific controller
kubectl -n flux-system logs deployment/source-controller
```

### Force Reconciliation

```bash
flux reconcile source git flux-system
flux reconcile kustomization flux-system
```

### Suspend/Resume

```bash
flux suspend kustomization myapp
flux resume kustomization myapp
```

## Cleanup

```bash
./teardown-cluster.sh
```

## Troubleshooting

### Flux not reconciling

```bash
flux check
flux get all
kubectl -n flux-system get events --sort-by='.lastTimestamp'
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
