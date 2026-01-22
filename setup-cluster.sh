#!/bin/bash
set -e

echo "🚀 Setting up k3d cluster with FluxCD..."

# Check prerequisites
command -v k3d >/dev/null 2>&1 || { echo "❌ k3d is required but not installed. Install from https://k3d.io"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed."; exit 1; }
command -v flux >/dev/null 2>&1 || { echo "❌ flux CLI is required but not installed. Install from https://fluxcd.io"; exit 1; }

# Create k3d cluster
echo "📦 Creating k3d cluster..."
k3d cluster create --config k3d-config.yaml

# Wait for cluster to be ready
echo "⏳ Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

# Install FluxCD
echo "🔧 Installing FluxCD..."
flux install

# Wait for Flux to be ready
echo "⏳ Waiting for Flux to be ready..."
kubectl -n flux-system wait --for=condition=available --timeout=300s --all deployments

echo "✅ Cluster setup complete!"
echo ""
echo "Next steps:"
echo "  1. Configure your Git repository:"
echo "     flux bootstrap github --owner=<org> --repository=<repo> --path=clusters/fluxcd-platform"
echo ""
echo "  2. Or use GitLab:"
echo "     flux bootstrap gitlab --owner=<org> --repository=<repo> --path=clusters/fluxcd-platform"
echo ""
echo "  3. Check Flux status:"
echo "     flux check"
echo "     kubectl -n flux-system get pods"
