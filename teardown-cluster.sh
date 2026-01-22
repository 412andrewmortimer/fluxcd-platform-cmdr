#!/bin/bash
set -e

echo "🗑️  Tearing down k3d cluster..."
k3d cluster delete fluxcd-platform
echo "✅ Cluster deleted!"
