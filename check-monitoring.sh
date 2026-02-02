#!/bin/bash
set -e

echo "🔍 Monitoring Stack Status"
echo "==========================="
echo ""

# Check if monitoring namespace exists
if ! kubectl get namespace monitoring &>/dev/null; then
  echo "❌ Monitoring namespace not found. Stack not installed."
  exit 1
fi

echo "📦 Namespace: monitoring"
echo ""

# Check deployments
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Deployments:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get deployments -n monitoring -o wide
echo ""

# Check statefulsets
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 StatefulSets:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get statefulsets -n monitoring -o wide
echo ""

# Check daemonsets
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 DaemonSets:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get daemonsets -n monitoring -o wide
echo ""

# Check services
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Services:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get services -n monitoring
echo ""

# Check pods
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Pods:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get pods -n monitoring -o wide
echo ""

# Check ServiceMonitors
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 ServiceMonitors:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get servicemonitors -n monitoring
echo ""

# Check cert-manager ServiceMonitor
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 cert-manager ServiceMonitor:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get servicemonitors -n cert-manager 2>/dev/null || echo "No ServiceMonitors found in cert-manager namespace"
echo ""

# Check HelmReleases
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Flux HelmReleases:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
flux get helmrelease kube-prometheus-stack -n flux-system 2>/dev/null || echo "HelmRelease not found"
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

DEPLOYMENTS_READY=$(kubectl get deployments -n monitoring -o json | jq '[.items[] | select(.status.readyReplicas == .spec.replicas)] | length')
DEPLOYMENTS_TOTAL=$(kubectl get deployments -n monitoring -o json | jq '.items | length')

STATEFULSETS_READY=$(kubectl get statefulsets -n monitoring -o json | jq '[.items[] | select(.status.readyReplicas == .spec.replicas)] | length')
STATEFULSETS_TOTAL=$(kubectl get statefulsets -n monitoring -o json | jq '.items | length')

PODS_RUNNING=$(kubectl get pods -n monitoring --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
PODS_TOTAL=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | wc -l | tr -d ' ')

echo "✅ Deployments:  $DEPLOYMENTS_READY/$DEPLOYMENTS_TOTAL ready"
echo "✅ StatefulSets: $STATEFULSETS_READY/$STATEFULSETS_TOTAL ready"
echo "✅ Pods:         $PODS_RUNNING/$PODS_TOTAL running"
echo ""

if [ "$DEPLOYMENTS_READY" == "$DEPLOYMENTS_TOTAL" ] && [ "$STATEFULSETS_READY" == "$STATEFULSETS_TOTAL" ]; then
  echo "🎉 Monitoring stack is healthy!"
  echo ""
  echo "To access services, run:"
  echo "  ./access-monitoring.sh"
else
  echo "⚠️  Some components are not ready yet. Check pod logs for details."
  echo ""
  echo "To watch status:"
  echo "  kubectl get pods -n monitoring --watch"
fi
