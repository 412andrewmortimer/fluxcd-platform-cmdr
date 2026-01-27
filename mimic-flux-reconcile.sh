#!/bin/bash
set -e

echo "🔄 Mimicking Flux Reconciliation"
echo "================================="
echo ""
echo "This script simulates what Flux does when it reconciles:"
echo "  1. Build manifests from Kustomizations"
echo "  2. Validate against cluster API"
echo "  3. Apply HelmRepository and HelmRelease resources"
echo "  4. Wait for Helm controllers to install/upgrade"
echo "  5. Verify deployment health"
echo ""

# Step 1: Build Kustomizations
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Building Kustomizations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Building infrastructure/controllers/..."
kubectl kustomize infrastructure/controllers/ > /tmp/controllers-manifests.yaml
echo "✅ Built $(wc -l < /tmp/controllers-manifests.yaml | tr -d ' ') lines"
echo ""

if [ -d "infrastructure/configs" ]; then
  echo "Building infrastructure/configs/..."
  kubectl kustomize infrastructure/configs/ > /tmp/configs-manifests.yaml
  echo "✅ Built $(wc -l < /tmp/configs-manifests.yaml | tr -d ' ') lines"
  echo ""
fi

# Step 2: Validate
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Validating Manifests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
kubectl apply --dry-run=server -f /tmp/controllers-manifests.yaml
echo ""
echo "✅ Validation passed"
echo ""

# Step 3: Apply Resources
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Applying Resources"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
kubectl apply -f /tmp/controllers-manifests.yaml
echo ""
echo "✅ Resources applied to cluster"
echo ""

# Step 4: Wait for HelmRepository
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📡 Waiting for HelmRepository Sync"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Flux source-controller is fetching Helm repository index..."
kubectl wait --for=condition=Ready \
  helmrepository/jetstack \
  -n flux-system \
  --timeout=120s
echo ""
echo "✅ HelmRepository ready"
echo ""

# Step 5: Wait for HelmRelease
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⎈ Waiting for HelmRelease Reconciliation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Flux helm-controller is running helm install/upgrade..."
kubectl wait --for=condition=Ready \
  helmrelease/cert-manager \
  -n flux-system \
  --timeout=300s
echo ""
echo "✅ HelmRelease reconciled successfully"
echo ""

# Step 6: Verify Deployment
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Verifying Deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Cert-manager pods:"
kubectl get pods -n cert-manager
echo ""
echo "Cert-manager deployments:"
kubectl get deployments -n cert-manager
echo ""

# Step 7: Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Reconciliation Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Flux Resources:"
flux get helmrepositories -A
echo ""
flux get helmreleases -A
echo ""

echo "✅ Success! Cert-manager installed via Flux"
echo ""
echo "Next steps:"
echo "  • Apply configs: kubectl apply -f infrastructure/configs/"
echo "  • Test certificate: See TESTING-CERT-MANAGER.md"
echo "  • View logs: flux logs --kind=HelmRelease --name=cert-manager -f"
echo "  • Force reconcile: flux reconcile helmrelease cert-manager -n flux-system"
