#!/bin/bash
set -e

echo "🔍 Monitoring Stack Access Helper"
echo "=================================="
echo ""

# Check if monitoring namespace exists
if ! kubectl get namespace monitoring &>/dev/null; then
  echo "❌ Monitoring namespace not found."
  echo ""
  echo "To install the monitoring stack, run:"
  echo "  ./mimic-flux-reconcile.sh"
  echo ""
  exit 1
fi

# Check if pods are ready
echo "📊 Checking monitoring stack status..."
GRAFANA_READY=$(kubectl get deployment -n monitoring monitoring-kube-prometheus-stack-grafana -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
PROM_READY=$(kubectl get statefulset -n monitoring prometheus-monitoring-kube-prometheus-prometheus -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
ALERT_READY=$(kubectl get statefulset -n monitoring alertmanager-monitoring-kube-prometheus-alertmanager -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

if [ "$GRAFANA_READY" == "0" ] || [ "$PROM_READY" == "0" ] || [ "$ALERT_READY" == "0" ]; then
  echo "⚠️  Some components are not ready yet:"
  echo "   Grafana:       $GRAFANA_READY/1"
  echo "   Prometheus:    $PROM_READY/1"
  echo "   Alertmanager:  $ALERT_READY/1"
  echo ""
  echo "Waiting for pods to be ready..."
  kubectl wait --for=condition=ready pod -n monitoring -l app.kubernetes.io/name=grafana --timeout=300s 2>/dev/null || true
  kubectl wait --for=condition=ready pod -n monitoring -l app.kubernetes.io/name=prometheus --timeout=300s 2>/dev/null || true
  kubectl wait --for=condition=ready pod -n monitoring -l app.kubernetes.io/name=alertmanager --timeout=300s 2>/dev/null || true
fi

echo "✅ Monitoring stack is ready!"
echo ""

# Show available services
echo "📋 Available Services:"
kubectl get svc -n monitoring -o wide | grep -E "NAME|grafana|prometheus|alertmanager" | grep -v "operated"
echo ""

# Menu
echo "Select what to access:"
echo "  1) Grafana Dashboard (port 3000)"
echo "  2) Prometheus (port 9090)"
echo "  3) Alertmanager (port 9093)"
echo "  4) All services (in background)"
echo "  5) Show service URLs only"
echo "  q) Quit"
echo ""

read -p "Enter choice [1-5, q]: " choice

case $choice in
  1)
    echo ""
    echo "🚀 Starting Grafana on http://localhost:3000"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   📊 Grafana Dashboard: http://localhost:3000"
    echo "   👤 Username: admin"
    echo "   🔑 Password: admin"
    echo ""
    echo "   📝 Note: Change the default password in production!"
    echo ""
    echo "Press Ctrl+C to stop port-forwarding"
    echo ""
    kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-stack-grafana 3000:80
    ;;
  2)
    echo ""
    echo "🚀 Starting Prometheus on http://localhost:9090"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   📈 Prometheus UI: http://localhost:9090"
    echo "   📊 Metrics: http://localhost:9090/metrics"
    echo "   🎯 Targets: http://localhost:9090/targets"
    echo ""
    echo "Press Ctrl+C to stop port-forwarding"
    echo ""
    kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
    ;;
  3)
    echo ""
    echo "🚀 Starting Alertmanager on http://localhost:9093"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   🚨 Alertmanager UI: http://localhost:9093"
    echo "   📋 Alerts: http://localhost:9093/#/alerts"
    echo ""
    echo "Press Ctrl+C to stop port-forwarding"
    echo ""
    kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093
    ;;
  4)
    echo ""
    echo "🚀 Starting all services in background..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Start port-forwards in background
    kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-stack-grafana 3000:80 > /dev/null 2>&1 &
    PF1=$!
    kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090 > /dev/null 2>&1 &
    PF2=$!
    kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093 > /dev/null 2>&1 &
    PF3=$!
    
    # Wait for port-forwards to be ready
    sleep 3
    
    echo "✅ All services are now accessible:"
    echo ""
    echo "   📊 Grafana:       http://localhost:3000"
    echo "      Username: admin"
    echo "      Password: admin"
    echo ""
    echo "   📈 Prometheus:    http://localhost:9090"
    echo ""
    echo "   🚨 Alertmanager:  http://localhost:9093"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Press Ctrl+C to stop all port-forwards"
    echo ""
    
    # Trap Ctrl+C to cleanup
    trap "echo ''; echo '🛑 Stopping all port-forwards...'; kill $PF1 $PF2 $PF3 2>/dev/null; echo '✅ Done!'; exit 0" INT
    
    # Wait indefinitely
    wait
    ;;
  5)
    echo ""
    echo "📋 Service Access Information"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "To access services, run these commands:"
    echo ""
    echo "Grafana:"
    echo "  kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-stack-grafana 3000:80"
    echo "  URL: http://localhost:3000 (admin/admin)"
    echo ""
    echo "Prometheus:"
    echo "  kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090"
    echo "  URL: http://localhost:9090"
    echo ""
    echo "Alertmanager:"
    echo "  kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093"
    echo "  URL: http://localhost:9093"
    echo ""
    echo "Internal cluster URLs:"
    echo "  Grafana:       http://monitoring-kube-prometheus-stack-grafana.monitoring.svc:80"
    echo "  Prometheus:    http://monitoring-kube-prometheus-prometheus.monitoring.svc:9090"
    echo "  Alertmanager:  http://monitoring-kube-prometheus-alertmanager.monitoring.svc:9093"
    echo ""
    ;;
  q|Q)
    echo "👋 Goodbye!"
    exit 0
    ;;
  *)
    echo "❌ Invalid choice"
    exit 1
    ;;
esac
