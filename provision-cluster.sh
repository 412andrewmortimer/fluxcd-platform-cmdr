#!/bin/bash
set -e

echo "🚀 FluxCD Platform - Complete Provisioning"
echo "==========================================="
echo ""
echo "This script will:"
echo "  1. Create k3d cluster"
echo "  2. Install FluxCD"
echo "  3. Apply Flux Kustomizations (infrastructure)"
echo "  4. Wait for all components to be ready"
echo "  5. Display status and access information"
echo ""

# ============================================================================
# Check Prerequisites
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Checking Prerequisites"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

MISSING_DEPS=()

if ! command -v k3d >/dev/null 2>&1; then
  echo "❌ k3d not found"
  MISSING_DEPS+=("k3d")
else
  echo "✅ k3d $(k3d version | head -1)"
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "❌ kubectl not found"
  MISSING_DEPS+=("kubectl")
else
  echo "✅ kubectl $(kubectl version --client -o yaml | grep gitVersion | head -1 | awk '{print $2}')"
fi

if ! command -v flux >/dev/null 2>&1; then
  echo "❌ flux CLI not found"
  MISSING_DEPS+=("flux")
else
  echo "✅ flux $(flux version --client | grep 'flux:' | awk '{print $2}')"
fi

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
  echo ""
  echo "❌ Missing required tools: ${MISSING_DEPS[*]}"
  echo ""
  echo "Install missing tools:"
  echo "  brew install k3d kubectl fluxcd/tap/flux"
  echo ""
  exit 1
fi

echo ""

# ============================================================================
# Check if Cluster Already Exists
# ============================================================================
if k3d cluster list | grep -q "fluxcd-platform"; then
  echo "⚠️  Cluster 'fluxcd-platform' already exists."
  echo ""
  read -p "Do you want to delete and recreate it? (y/N): " -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Deleting existing cluster..."
    k3d cluster delete fluxcd-platform
    echo "✅ Cluster deleted"
    echo ""
  else
    echo "Using existing cluster..."
    echo ""
  fi
fi

# ============================================================================
# Create k3d Cluster
# ============================================================================
if ! k3d cluster list | grep -q "fluxcd-platform"; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📦 Creating k3d Cluster"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  k3d cluster create --config k3d-config.yaml
  echo ""
  echo "✅ Cluster created"
  echo ""
fi

# ============================================================================
# Wait for Cluster to be Ready
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏳ Waiting for Cluster to be Ready"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
kubectl wait --for=condition=Ready nodes --all --timeout=120s
echo ""
echo "✅ All nodes ready"
echo ""

# ============================================================================
# Install FluxCD
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Installing FluxCD"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if Flux is already installed
if kubectl get namespace flux-system >/dev/null 2>&1; then
  echo "⚠️  Flux appears to be already installed"
  echo ""
  flux check || true
  echo ""
else
  flux install
  echo ""
  echo "✅ Flux installed"
  echo ""
fi

# ============================================================================
# Wait for Flux to be Ready
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏳ Waiting for Flux Components"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
kubectl -n flux-system wait --for=condition=available --timeout=300s --all deployments
echo ""
echo "✅ Flux components ready"
echo ""

# Run flux check
flux check
echo ""

# ============================================================================
# Apply Infrastructure Directly (Local Development)
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Applying Infrastructure Manifests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Note: For local development, applying manifests directly with kubectl"
echo "      For production, use 'flux bootstrap' with a real Git repository"
echo ""

# ============================================================================
# Apply Infrastructure Directly (Local Development)
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Applying Infrastructure Manifests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Note: For local development, applying manifests directly with kubectl"
echo "      For production, use 'flux bootstrap' with a real Git repository"
echo ""

# Apply infrastructure controllers
echo "Applying infrastructure/controllers..."
kubectl apply -k infrastructure/controllers
echo ""
echo "✅ Controllers applied"
echo ""

# ============================================================================
# Wait for Helm Repositories to be Ready
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏳ Waiting for Helm Repositories"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Flux is fetching Helm chart repositories..."
echo ""

# Wait for helm repositories
for repo in jetstack prometheus-community external-secrets; do
  if kubectl get helmrepository $repo -n flux-system >/dev/null 2>&1; then
    echo "Waiting for HelmRepository: $repo"
    kubectl wait --for=condition=Ready \
      helmrepository/$repo \
      -n flux-system \
      --timeout=120s || echo "  ⚠️  $repo not ready yet, continuing..."
  fi
done

echo ""
echo "✅ Helm repositories synced"
echo ""

# ============================================================================
# Wait for Helm Releases
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏳ Waiting for Helm Releases"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This may take 5-10 minutes as Helm charts are downloaded and deployed..."
echo ""

# Wait for each helm release
for release in cert-manager kube-prometheus-stack external-secrets; do
  if kubectl get helmrelease $release -n flux-system >/dev/null 2>&1; then
    echo "Waiting for HelmRelease: $release"
    kubectl wait --for=condition=Ready \
      helmrelease/$release \
      -n flux-system \
      --timeout=600s || echo "  ⚠️  $release not ready yet, continuing..."
    echo ""
  fi
done

echo "✅ Helm releases deployed"
echo ""

# ============================================================================
# Apply Infrastructure Configs
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Applying Infrastructure Configs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Apply infrastructure configs (depends on controllers being ready)
echo "Applying infrastructure/configs..."
kubectl apply -k infrastructure/configs
echo ""
echo "✅ Configs applied"
echo ""

# Wait for sample app
echo "Waiting for sample app..."
if kubectl get namespace sample-app >/dev/null 2>&1; then
  kubectl wait --for=condition=available \
    deployment/sample-metrics-app \
    -n sample-app \
    --timeout=120s || echo "  ⚠️  Sample app not ready yet"
fi
echo ""

# ============================================================================
# Verify Deployments
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Verifying Deployments"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Cert-Manager:"
kubectl get pods -n cert-manager 2>/dev/null || echo "  Not deployed"
echo ""

echo "Monitoring Stack:"
kubectl get pods -n monitoring 2>/dev/null || echo "  Not deployed"
echo ""

echo "External Secrets:"
kubectl get pods -n external-secrets-system 2>/dev/null || echo "  Not deployed"
echo ""

echo "Sample App:"
kubectl get pods -n sample-app 2>/dev/null || echo "  Not deployed"
echo ""

# ============================================================================
# Show Flux Status
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Flux Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Helm Repositories:"
flux get sources helm -A
echo ""

echo "Helm Releases:"
flux get helmreleases -A
echo ""

# ============================================================================
# Summary
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Provisioning Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎉 Your FluxCD platform is ready!"
echo ""
echo "📋 What's Deployed:"
echo "   • Cert-Manager (TLS certificate management)"
echo "   • Kube-Prometheus-Stack (Monitoring)"
echo "   • External Secrets Operator"
echo "   • Sample App with Metrics"
echo ""
echo "🔍 Next Steps:"
echo ""
echo "   1. Check cluster status:"
echo "      make status"
echo ""
echo "   2. Access monitoring stack:"
echo "      ./access-monitoring.sh"
echo ""
echo "   3. Generate metrics traffic:"
echo "      ./generate-metrics-traffic.sh"
echo ""
echo "   4. View Flux logs:"
echo "      flux logs --all-namespaces --follow"
echo ""
echo "   5. Force reconciliation:"
echo "      flux reconcile kustomization infrastructure-controllers --with-source"
echo ""
echo "📚 Documentation:"
echo "   • README.md - General overview"
echo "   • MONITORING-QUICKSTART.md - Monitoring guide"
echo "   • MONITORING.md - Detailed monitoring docs"
echo ""
echo "🔧 Useful Commands:"
echo "   • Check Flux: flux check"
echo "   • Get Helm releases: flux get helmreleases -A"
echo "   • Get Helm repos: flux get sources helm -A"
echo "   • Reconcile controllers: kubectl apply -k infrastructure/controllers"
echo "   • Reconcile configs: kubectl apply -k infrastructure/configs"
echo ""
echo "🗑️  To tear down:"
echo "   ./teardown-cluster.sh"
echo ""
