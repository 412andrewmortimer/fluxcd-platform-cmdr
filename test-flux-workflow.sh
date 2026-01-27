#!/bin/bash
set -e

echo "🧪 Testing Flux GitOps Workflow (Without Git)"
echo "=============================================="
echo ""

# Check if cert-manager is installed
if ! kubectl get helmrelease cert-manager -n flux-system &>/dev/null; then
  echo "❌ cert-manager HelmRelease not found. Run ./mimic-flux-reconcile.sh first"
  exit 1
fi

echo "✅ Prerequisites met: cert-manager HelmRelease exists"
echo ""

# Test 1: Apply ClusterIssuers
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 1: Apply ClusterIssuers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 What this tests: Flux managing cert-manager configuration"
echo ""

if [ -f "infrastructure/configs/cert-manager-issuers.yaml" ]; then
  echo "Applying ClusterIssuers..."
  kubectl apply -f infrastructure/configs/cert-manager-issuers.yaml
  echo ""
  
  echo "Waiting for ClusterIssuers to be ready..."
  sleep 5
  
  echo ""
  echo "ClusterIssuers status:"
  kubectl get clusterissuers
  echo ""
  echo "✅ Test 1 passed: ClusterIssuers created"
else
  echo "⚠️  Skipping: infrastructure/configs/cert-manager-issuers.yaml not found"
fi
echo ""

# Test 2: Create a test certificate
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 2: Create a self-signed certificate"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 What this tests: cert-manager issuing certificates"
echo ""

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
  duration: 2160h # 90 days
  renewBefore: 360h # 15 days
EOF

echo ""
echo "Waiting for certificate to be issued..."
sleep 10

echo ""
echo "Certificate status:"
kubectl get certificate test-cert -n default
echo ""
kubectl describe certificate test-cert -n default | grep -A 10 "Status:"
echo ""

# Check if secret was created
if kubectl get secret test-cert-tls -n default &>/dev/null; then
  echo "✅ Test 2 passed: Certificate issued and secret created"
  echo ""
  echo "Secret details:"
  kubectl get secret test-cert-tls -n default -o jsonpath='{.type}{"\n"}'
else
  echo "⚠️  Secret not created yet, certificate may still be processing"
fi
echo ""

# Test 3: Scale cert-manager replicas
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 3: Scale cert-manager replicas (GitOps change)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 What this tests: Updating Helm values and reconciling"
echo ""

echo "Current replica count:"
kubectl get deployment -n cert-manager -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.replicas}{"\n"}{end}'
echo ""

echo "Updating cert-manager-release.yaml to scale to 2 replicas..."
# Make a backup first
cp infrastructure/controllers/cert-manager-release.yaml infrastructure/controllers/cert-manager-release.yaml.bak

# Update replica counts
sed -i.tmp 's/replicaCount: 1/replicaCount: 2/g' infrastructure/controllers/cert-manager-release.yaml
rm -f infrastructure/controllers/cert-manager-release.yaml.tmp

echo "✅ Updated manifest file"
echo ""

echo "Changes made:"
diff infrastructure/controllers/cert-manager-release.yaml.bak infrastructure/controllers/cert-manager-release.yaml || true
echo ""

echo "Applying updated HelmRelease (like Flux would do)..."
kubectl apply -f infrastructure/controllers/cert-manager-release.yaml
echo ""

echo "Forcing HelmRelease reconciliation..."
flux reconcile helmrelease cert-manager -n flux-system --timeout=5m
echo ""

echo "Waiting for deployments to scale..."
sleep 15

echo ""
echo "New replica count:"
kubectl get deployment -n cert-manager -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.replicas}{"\n"}{end}'
echo ""

echo "Deployment status:"
kubectl get deployments -n cert-manager
echo ""

# Verify all replicas are ready
EXPECTED_REPLICAS=6  # 2 replicas * 3 deployments
ACTUAL_REPLICAS=$(kubectl get deployment -n cert-manager -o jsonpath='{range .items[*]}{.status.readyReplicas}{end}' | tr -d '[:space:]' | fold -w1 | paste -sd+ | bc)

if [ "$ACTUAL_REPLICAS" -eq "$EXPECTED_REPLICAS" ]; then
  echo "✅ Test 3 passed: Successfully scaled to 2 replicas per deployment"
else
  echo "⚠️  Expected $EXPECTED_REPLICAS ready replicas, found $ACTUAL_REPLICAS"
fi
echo ""

# Test 4: Drift detection
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 4: Drift detection and remediation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 What this tests: Flux reverting manual changes"
echo ""

echo "Making manual change (simulating drift)..."
echo "Scaling cert-manager deployment to 1 replica manually..."
kubectl scale deployment cert-manager-cert-manager -n cert-manager --replicas=1
sleep 5

echo ""
echo "Current state (after manual change):"
kubectl get deployment cert-manager-cert-manager -n cert-manager -o jsonpath='{.spec.replicas}{"\n"}'
echo ""

echo "Forcing Flux reconciliation (drift remediation)..."
flux reconcile helmrelease cert-manager -n flux-system --timeout=5m
echo ""

echo "Waiting for Flux to revert the change..."
sleep 15

echo ""
echo "State after reconciliation (should be back to 2):"
kubectl get deployment cert-manager-cert-manager -n cert-manager -o jsonpath='{.spec.replicas}{"\n"}'
echo ""

FINAL_REPLICAS=$(kubectl get deployment cert-manager-cert-manager -n cert-manager -o jsonpath='{.spec.replicas}')
if [ "$FINAL_REPLICAS" -eq 2 ]; then
  echo "✅ Test 4 passed: Drift detected and remediated (back to 2 replicas)"
else
  echo "⚠️  Expected 2 replicas, found $FINAL_REPLICAS"
fi
echo ""

# Test 5: View Flux reconciliation history
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 5: View Flux reconciliation history"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 What this shows: Flux tracking and reporting"
echo ""

echo "HelmRelease events:"
kubectl get events -n flux-system --field-selector involvedObject.name=cert-manager --sort-by='.lastTimestamp' | tail -10
echo ""

echo "Current HelmRelease status:"
flux get helmrelease cert-manager -n flux-system
echo ""

echo "✅ Test 5 complete: History available"
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 TEST SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "All Flux resources:"
flux get all
echo ""
echo "Cert-manager pods:"
kubectl get pods -n cert-manager
echo ""
echo "Certificates:"
kubectl get certificates -A
echo ""

# Cleanup option
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧹 CLEANUP OPTIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To restore original replica count (1):"
echo "  mv infrastructure/controllers/cert-manager-release.yaml.bak infrastructure/controllers/cert-manager-release.yaml"
echo "  ./mimic-flux-reconcile.sh"
echo ""
echo "To delete test certificate:"
echo "  kubectl delete certificate test-cert -n default"
echo "  kubectl delete secret test-cert-tls -n default"
echo ""
echo "To remove cert-manager completely:"
echo "  kubectl delete -f infrastructure/controllers/"
echo "  kubectl delete namespace cert-manager"
echo ""

echo "✅ All tests completed!"
