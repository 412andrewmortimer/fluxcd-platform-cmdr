#!/bin/bash

echo "🔥 Sample App Metrics Generator"
echo "================================"
echo ""
echo "This script generates traffic to the sample-app to create"
echo "interesting metrics in Prometheus and Grafana."
echo ""

# Check if sample-app exists
if ! kubectl get namespace sample-app &>/dev/null; then
  echo "❌ sample-app namespace not found."
  echo ""
  echo "Deploy the sample app first:"
  echo "  kubectl apply -k infrastructure/configs"
  echo "  # Or use Flux:"
  echo "  flux reconcile kustomization infrastructure-configs"
  echo ""
  exit 1
fi

# Check if the app is ready
echo "📊 Checking sample app status..."
READY=$(kubectl get deployment -n sample-app sample-metrics-app -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

if [ "$READY" == "0" ]; then
  echo "⚠️  Sample app is not ready yet. Waiting..."
  kubectl wait --for=condition=available --timeout=120s deployment/sample-metrics-app -n sample-app
fi

echo "✅ Sample app is ready!"
echo ""
echo "🚀 Starting metrics generation..."
echo "   This will run in the background and generate random HTTP requests"
echo "   to the sample app, creating metrics for you to view in Grafana."
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Start port-forward in background
kubectl port-forward -n sample-app svc/sample-metrics-app 8080:8080 > /dev/null 2>&1 &
PF_PID=$!

# Wait for port-forward to be ready
sleep 2

# Trap Ctrl+C to cleanup
trap "echo ''; echo '🛑 Stopping metrics generation...'; kill $PF_PID 2>/dev/null; echo '✅ Done!'; exit 0" INT

# Generate traffic
echo "📈 Generating metrics..."
echo "   Target: http://localhost:8080"
echo ""

REQUEST_COUNT=0

while true; do
  # Random delay between requests (0.5-2 seconds)
  DELAY=$(awk -v min=0.5 -v max=2 'BEGIN{srand(); print min+rand()*(max-min)}')
  
  # Make request with random status code
  RAND=$((RANDOM % 100))
  if [ $RAND -lt 70 ]; then
    # 70% success
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ 2>/dev/null || echo "000")
  elif [ $RAND -lt 90 ]; then
    # 20% not found
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/not-found 2>/dev/null || echo "000")
  else
    # 10% error (simulated by hitting non-existent endpoint)
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/error 2>/dev/null || echo "000")
  fi
  
  REQUEST_COUNT=$((REQUEST_COUNT + 1))
  
  # Print progress every 10 requests
  if [ $((REQUEST_COUNT % 10)) -eq 0 ]; then
    echo "   Sent $REQUEST_COUNT requests... (last status: $RESPONSE)"
  fi
  
  sleep "$DELAY"
done
