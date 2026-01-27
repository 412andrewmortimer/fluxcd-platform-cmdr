# Testing cert-manager with FluxCD

This guide shows how to test cert-manager installation using Flux's HelmRelease.

## Structure

```
infrastructure/
├── controllers/
│   ├── cert-manager-source.yaml    # HelmRepository
│   ├── cert-manager-release.yaml   # HelmRelease
│   └── kustomization.yaml
└── configs/
    ├── cert-manager-issuers.yaml   # ClusterIssuers
    └── kustomization.yaml

clusters/fluxcd-platform/
├── infrastructure.yaml              # Kustomization for controllers
└── infrastructure-configs.yaml      # Kustomization for configs (depends on controllers)
```

## Test Without Git (Local Mode)

### 1. Apply the HelmRepository and HelmRelease directly:

```bash
# Apply cert-manager Helm resources
kubectl apply -f infrastructure/controllers/

# Watch Flux reconcile the HelmRelease
watch flux get helmreleases -A

# Or watch the helm-controller logs
flux logs --kind=HelmRelease --name=cert-manager -f
```

### 2. Check installation progress:

```bash
# Check HelmRepository sync
kubectl -n flux-system get helmrepositories

# Check HelmRelease status
kubectl -n flux-system get helmreleases

# Check cert-manager pods
kubectl -n cert-manager get pods

# Verify CRDs are installed
kubectl get crds | grep cert-manager
```

### 3. Apply the ClusterIssuers:

```bash
# Wait for cert-manager to be ready
kubectl -n cert-manager wait --for=condition=available --timeout=300s deployment/cert-manager

# Apply issuers
kubectl apply -f infrastructure/configs/cert-manager-issuers.yaml

# Check issuers
kubectl get clusterissuers
```

### 4. Test with a certificate:

```bash
# Create a test certificate
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-cert
  namespace: default
spec:
  secretName: test-cert-tls
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  dnsNames:
    - test.example.com
EOF

# Check certificate
kubectl get certificate test-cert
kubectl describe certificate test-cert

# Check the secret was created
kubectl get secret test-cert-tls
```

## Test With Git (GitOps Mode)

### 1. Commit and push:

```bash
git add infrastructure/ clusters/
git commit -m "Add cert-manager via Flux HelmRelease"
git push
```

### 2. Bootstrap Flux (if not done):

```bash
export GITHUB_TOKEN=xxx
flux bootstrap github \
  --owner=412andrewmortimer \
  --repository=fluxcd-platform-cmdr \
  --branch=main \
  --path=clusters/fluxcd-platform \
  --personal
```

### 3. Apply the infrastructure Kustomization:

```bash
# This tells Flux to watch the infrastructure directory
kubectl apply -f clusters/fluxcd-platform/infrastructure.yaml
kubectl apply -f clusters/fluxcd-platform/infrastructure-configs.yaml

# Watch reconciliation
flux get kustomizations --watch
```

### 4. Force reconciliation (if needed):

```bash
flux reconcile kustomization infrastructure-controllers
flux reconcile kustomization infrastructure-configs
```

## Verify Everything Works

```bash
# Check all Flux resources
flux get all

# Check Helm releases
flux get helmreleases -A

# Check cert-manager health
kubectl -n cert-manager get all

# Check cert-manager logs
kubectl -n cert-manager logs -l app=cert-manager

# Test certificate creation
kubectl get certificates -A
kubectl get certificaterequests -A
```

## Customize cert-manager

Edit `infrastructure/controllers/cert-manager-release.yaml` and modify the `values:` section:

```yaml
values:
  installCRDs: true
  replicaCount: 3  # Change replica count
  resources:       # Add resource limits
    requests:
      cpu: 10m
      memory: 32Mi
```

Then either:
- **Local mode**: `kubectl apply -f infrastructure/controllers/`
- **GitOps mode**: `git commit && git push` (Flux auto-reconciles)

## Troubleshooting

### HelmRelease not reconciling:

```bash
# Check helm-controller logs
flux logs --kind=HelmRelease --name=cert-manager

# Check HelmRelease status
kubectl -n flux-system describe helmrelease cert-manager

# Force reconciliation
flux reconcile helmrelease cert-manager -n flux-system
```

### HelmRepository not syncing:

```bash
# Check source-controller logs
kubectl -n flux-system logs deployment/source-controller

# Force reconciliation
flux reconcile source helm jetstack -n flux-system
```

### Cert-manager not issuing certificates:

```bash
# Check cert-manager logs
kubectl -n cert-manager logs -l app=cert-manager

# Check certificate status
kubectl describe certificate test-cert
```

## Clean Up

```bash
# Remove test certificate
kubectl delete certificate test-cert

# Remove cert-manager (Flux will not recreate if files are deleted)
kubectl delete -f infrastructure/controllers/
kubectl delete namespace cert-manager
```
