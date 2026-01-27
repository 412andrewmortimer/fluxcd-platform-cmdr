# Flux Reconciliation Scripts Documentation

This document explains the scripts used to mimic and test FluxCD's GitOps reconciliation workflow without requiring Git integration.

## 📋 Table of Contents

- [Overview](#overview)
- [Scripts](#scripts)
- [Usage Guide](#usage-guide)
- [Verification Commands](#verification-commands)
- [Test Scenarios](#test-scenarios)
- [Troubleshooting](#troubleshooting)

---

## Overview

### What is FluxCD Reconciliation?

FluxCD continuously monitors Git repositories and automatically applies changes to your Kubernetes cluster. The reconciliation process involves:

1. **GitRepository Controller** - Fetches latest from Git repository
2. **Kustomization Controller** - Builds manifests from specified paths
3. **Source Controller** - Syncs Helm repositories and charts
4. **Helm Controller** - Installs/upgrades Helm releases
5. **Health Checks** - Monitors deployment status
6. **Drift Detection** - Reverts manual changes back to Git state

### Local Testing Without Git

These scripts allow you to test the Flux reconciliation workflow locally without pushing to Git, perfect for:
- Understanding how Flux works
- Testing Helm configurations
- Validating manifests before committing
- Learning GitOps principles

---

## Scripts

### 1. `mimic-flux-reconcile.sh`

**Purpose**: Simulates the complete Flux reconciliation cycle

**What it does**:
1. Builds Kustomizations from local manifests
2. Validates resources against cluster API
3. Applies HelmRepository and HelmRelease resources
4. Waits for Helm chart sync
5. Monitors HelmRelease reconciliation
6. Verifies deployment health
7. Compares desired vs actual state (drift detection)

**Usage**:
```bash
./mimic-flux-reconcile.sh
```

**When to use**:
- Initial setup of new applications
- After modifying Helm values
- Testing configuration changes
- Verifying manifest syntax

### 2. `test-flux-workflow.sh`

**Purpose**: Comprehensive testing of GitOps workflows and Flux features

**What it tests**:
1. **ClusterIssuer creation** - Config management
2. **Certificate issuance** - Application functionality
3. **Replica scaling** - Helm value updates
4. **Drift detection** - GitOps enforcement
5. **Reconciliation history** - Flux tracking

**Usage**:
```bash
./test-flux-workflow.sh
```

**When to use**:
- After running `mimic-flux-reconcile.sh`
- To validate full GitOps workflow
- Before setting up Git-based Flux
- Learning Flux capabilities

---

## Usage Guide

### Initial Setup

1. **Create k3d cluster with Flux**:
```bash
make up
# or
./setup-cluster.sh
```

2. **Verify Flux installation**:
```bash
flux check
```

3. **Run reconciliation simulation**:
```bash
./mimic-flux-reconcile.sh
```

4. **Test GitOps workflows**:
```bash
./test-flux-workflow.sh
```

### Workflow Example

```bash
# Step 1: Edit Helm values
vim infrastructure/controllers/cert-manager-release.yaml

# Step 2: Simulate Flux reconciliation
./mimic-flux-reconcile.sh

# Step 3: Verify changes
flux get helmreleases -A
kubectl get pods -n cert-manager

# Step 4: Test GitOps features
./test-flux-workflow.sh
```

---

## Verification Commands

### Check Flux Components

```bash
# Check all Flux controllers are running
kubectl get pods -n flux-system

# Verify Flux installation
flux check

# View all Flux-managed resources
flux get all
```

### Check HelmRepository

```bash
# List HelmRepositories
kubectl get helmrepository -n flux-system

# Detailed status
kubectl get helmrepository jetstack -n flux-system -o yaml

# Check artifact
kubectl get helmrepository jetstack -n flux-system -o jsonpath='{.status.artifact.revision}'
```

### Check HelmRelease

```bash
# List HelmReleases
flux get helmreleases -A

# Detailed status
kubectl describe helmrelease cert-manager -n flux-system

# Check reconciliation status
kubectl get helmrelease cert-manager -n flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}'

# View Helm release directly
helm list -n cert-manager

# View Helm values applied
helm get values cert-manager -n cert-manager
```

### Check Cert-Manager

```bash
# View all resources
kubectl get all -n cert-manager

# Check pods
kubectl get pods -n cert-manager

# Check deployments with replicas
kubectl get deployment -n cert-manager -o wide

# Check replica counts
kubectl get deployment -n cert-manager -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.replicas}/{.status.readyReplicas}{"\n"}{end}'

# View logs
kubectl logs -n cert-manager -l app=cert-manager --tail=50
```

### Check ClusterIssuers

```bash
# List ClusterIssuers
kubectl get clusterissuers

# Detailed status
kubectl describe clusterissuer selfsigned-issuer

# View all cert-manager CRDs
kubectl get crds | grep cert-manager
```

### Check Certificates

```bash
# List all certificates
kubectl get certificates -A

# Check specific certificate
kubectl get certificate test-cert -n default

# Detailed status
kubectl describe certificate test-cert -n default

# Check generated secret
kubectl get secret test-cert-tls -n default

# View certificate details
kubectl get secret test-cert-tls -n default -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

### Check Events

```bash
# Flux system events
kubectl get events -n flux-system --sort-by='.lastTimestamp'

# HelmRelease events
kubectl get events -n flux-system --field-selector involvedObject.name=cert-manager

# Cert-manager events
kubectl get events -n cert-manager --sort-by='.lastTimestamp'
```

### Monitor Reconciliation

```bash
# Watch HelmRelease status
flux get helmrelease cert-manager -n flux-system --watch

# Watch pods
kubectl get pods -n cert-manager -w

# Watch deployments
kubectl get deployments -n cert-manager -w

# Follow Flux logs
flux logs --all-namespaces --follow

# Follow helm-controller logs
kubectl logs -n flux-system -l app=helm-controller -f
```

### Force Reconciliation

```bash
# Force HelmRepository sync
flux reconcile source helm jetstack -n flux-system

# Force HelmRelease reconciliation
flux reconcile helmrelease cert-manager -n flux-system

# Force with source refresh
flux reconcile helmrelease cert-manager -n flux-system --with-source
```

---

## Test Scenarios

### Scenario 1: Initial Installation

**Objective**: Install cert-manager via Flux

```bash
# Run reconciliation
./mimic-flux-reconcile.sh

# Verify HelmRepository
kubectl get helmrepository jetstack -n flux-system
flux get sources helm

# Verify HelmRelease
flux get helmrelease cert-manager -n flux-system

# Verify deployment
kubectl get pods -n cert-manager
kubectl get deployments -n cert-manager
```

**Expected Result**: Cert-manager installed with 3 deployments running (cert-manager, webhook, cainjector)

### Scenario 2: Update Configuration

**Objective**: Scale cert-manager replicas from 1 to 2

```bash
# Edit manifest
sed -i '' 's/replicaCount: 1/replicaCount: 2/g' infrastructure/controllers/cert-manager-release.yaml

# Apply changes
./mimic-flux-reconcile.sh

# Verify scaling
kubectl get deployment -n cert-manager
kubectl get deployment -n cert-manager -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.replicas}{"\n"}{end}'
```

**Expected Result**: All 3 deployments scaled to 2 replicas each (6 pods total)

### Scenario 3: Drift Detection

**Objective**: Manual changes are reverted by Flux

```bash
# Make manual change (drift)
kubectl scale deployment cert-manager-cert-manager -n cert-manager --replicas=1

# Check current state
kubectl get deployment cert-manager-cert-manager -n cert-manager

# Force reconciliation
flux reconcile helmrelease cert-manager -n flux-system

# Wait and verify
sleep 15
kubectl get deployment cert-manager-cert-manager -n cert-manager
```

**Expected Result**: Deployment scaled back to 2 replicas (Git state)

### Scenario 4: Certificate Issuance

**Objective**: Cert-manager issues a certificate

```bash
# Apply ClusterIssuers
kubectl apply -f infrastructure/configs/cert-manager-issuers.yaml

# Create test certificate
kubectl apply -f - <<EOF
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

# Monitor certificate
kubectl get certificate test-cert -n default -w

# Verify secret created
kubectl get secret test-cert-tls -n default
```

**Expected Result**: Certificate issued and TLS secret created

### Scenario 5: Rollback

**Objective**: Revert to previous configuration

```bash
# Restore original replica count
mv infrastructure/controllers/cert-manager-release.yaml.bak infrastructure/controllers/cert-manager-release.yaml

# Apply
./mimic-flux-reconcile.sh

# Verify
kubectl get deployment -n cert-manager -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.replicas}{"\n"}{end}'
```

**Expected Result**: All deployments back to 1 replica each

---

## Troubleshooting

### HelmRepository Not Syncing

**Symptoms**:
```bash
kubectl get helmrepository jetstack -n flux-system
# Shows: Ready=False
```

**Debug**:
```bash
# Check source-controller logs
kubectl logs -n flux-system -l app=source-controller --tail=50

# Force reconciliation
flux reconcile source helm jetstack -n flux-system

# Check events
kubectl describe helmrepository jetstack -n flux-system
```

**Common Causes**:
- Network issues accessing Helm repo URL
- Invalid Helm repository URL
- Source controller not running

### HelmRelease Not Reconciling

**Symptoms**:
```bash
flux get helmrelease cert-manager -n flux-system
# Shows: Ready=False or stuck reconciling
```

**Debug**:
```bash
# Check helm-controller logs
kubectl logs -n flux-system -l app=helm-controller --tail=50

# View detailed status
kubectl describe helmrelease cert-manager -n flux-system

# Check HelmChart
kubectl get helmchart -n flux-system

# Force reconciliation
flux reconcile helmrelease cert-manager -n flux-system --with-source
```

**Common Causes**:
- HelmRepository not ready
- Invalid chart version
- Helm values validation errors
- Missing namespace
- Insufficient permissions

### Pods Not Starting

**Symptoms**:
```bash
kubectl get pods -n cert-manager
# Shows: Pending, CrashLoopBackOff, or ImagePullBackOff
```

**Debug**:
```bash
# Check pod status
kubectl describe pod <pod-name> -n cert-manager

# View logs
kubectl logs <pod-name> -n cert-manager

# Check events
kubectl get events -n cert-manager --sort-by='.lastTimestamp'

# Check resource requests/limits
kubectl get pod <pod-name> -n cert-manager -o jsonpath='{.spec.containers[*].resources}'
```

**Common Causes**:
- Insufficient cluster resources
- Image pull errors
- Invalid configuration
- CRDs not installed

### Certificate Not Issuing

**Symptoms**:
```bash
kubectl get certificate test-cert -n default
# Shows: Ready=False
```

**Debug**:
```bash
# Check certificate details
kubectl describe certificate test-cert -n default

# Check certificate request
kubectl get certificaterequest -n default

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager --tail=50

# Check issuer status
kubectl get clusterissuer selfsigned-issuer
kubectl describe clusterissuer selfsigned-issuer
```

**Common Causes**:
- Invalid issuer configuration
- Issuer not ready
- Invalid DNS names
- Webhook errors

### API Version Errors

**Symptoms**:
```bash
error: no matches for kind "HelmRelease" in version "helm.toolkit.fluxcd.io/v2beta1"
```

**Fix**:
```bash
# Check Flux CRDs installed
kubectl get crds | grep helm

# Update API versions in manifests
# v1beta2 -> v1 (HelmRepository)
# v2beta1 -> v2 (HelmRelease)

# Reinstall Flux if needed
flux install
```

### Validation Failed

**Symptoms**:
```bash
./mimic-flux-reconcile.sh
# Shows: validation errors
```

**Debug**:
```bash
# Build and view manifests
kubectl kustomize infrastructure/controllers/

# Validate manually
kubectl apply --dry-run=server -f infrastructure/controllers/

# Check for syntax errors
kubectl apply --dry-run=client -f infrastructure/controllers/
```

### Performance Issues

**Check Resource Usage**:
```bash
# Flux controller resource usage
kubectl top pods -n flux-system

# Cert-manager resource usage
kubectl top pods -n cert-manager

# Node resource usage
kubectl top nodes
```

---

## Advanced Usage

### Custom Intervals

Modify reconciliation intervals in manifests:

```yaml
# HelmRepository - how often to check for new chart versions
spec:
  interval: 1h  # Default: 1 hour

# HelmRelease - how often to reconcile
spec:
  interval: 30m  # Default: 30 minutes
  chart:
    spec:
      interval: 12h  # How often to check for chart updates
```

### Health Checks

Add custom health checks to Kustomizations:

```yaml
spec:
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: cert-manager
      namespace: cert-manager
```

### Dependencies

Configure resource dependencies:

```yaml
# infrastructure-configs.yaml
spec:
  dependsOn:
    - name: infrastructure-controllers
```

### Suspend Reconciliation

Temporarily stop Flux from reconciling:

```bash
# Suspend HelmRelease
flux suspend helmrelease cert-manager -n flux-system

# Resume
flux resume helmrelease cert-manager -n flux-system
```

---

## Next Steps

### Transition to Full GitOps

Once comfortable with local testing, set up Git-based Flux:

```bash
# Push code to Git
git add .
git commit -m "Add cert-manager configuration"
git push origin main

# Bootstrap Flux
export GITHUB_TOKEN=xxx
flux bootstrap github \
  --owner=412andrewmortimer \
  --repository=fluxcd-platform-cmdr \
  --branch=main \
  --path=clusters/fluxcd-platform \
  --personal
```

### Add More Applications

Follow the same pattern for other apps:

```bash
infrastructure/controllers/
├── cert-manager-source.yaml
├── cert-manager-release.yaml
├── ingress-nginx-source.yaml      # New
├── ingress-nginx-release.yaml     # New
└── kustomization.yaml
```

### Monitoring and Alerts

Set up Flux notifications:

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Provider
metadata:
  name: slack
  namespace: flux-system
spec:
  type: slack
  channel: flux-alerts
  address: https://hooks.slack.com/...
```

---

## References

- [FluxCD Documentation](https://fluxcd.io/docs/)
- [Helm Controller API](https://fluxcd.io/flux/components/helm/)
- [Kustomize Controller API](https://fluxcd.io/flux/components/kustomize/)
- [Cert-Manager Documentation](https://cert-manager.io/docs/)

---

## Summary

These scripts provide a complete local testing environment for FluxCD GitOps workflows:

✅ **mimic-flux-reconcile.sh** - Simulates Flux reconciliation cycle  
✅ **test-flux-workflow.sh** - Tests GitOps features comprehensively  
✅ **Verification commands** - Monitor and debug Flux operations  
✅ **Test scenarios** - Common workflows and use cases  
✅ **Troubleshooting** - Solutions to common problems  

Use these scripts to build confidence with Flux before implementing full Git-based GitOps! 🚀
