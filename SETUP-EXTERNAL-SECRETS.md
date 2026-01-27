# External Secrets Operator Setup Guide

This guide covers setting up External Secrets Operator (ESO) with Azure Key Vault and Workload Identity authentication in your FluxCD-managed Kubernetes cluster.

## Overview

External Secrets Operator (ESO) synchronizes secrets from external secret management systems (like Azure Key Vault) into Kubernetes secrets. This setup uses Azure Workload Identity for secure, credential-less authentication.

## Architecture

```
Azure Key Vault  <-->  ESO Controller  <-->  Kubernetes Secrets
     (Source)         (Sync Engine)          (Target)
                           |
                    Workload Identity
                  (Federated Credential)
```

## Prerequisites

Before deploying ESO, ensure you have:

1. **Azure Key Vault** with your secrets stored
2. **AKS Cluster** with Workload Identity enabled (or k3d with Azure auth configured)
3. **Azure CLI** (`az`) installed locally
4. **Appropriate permissions** to create Azure resources

## Azure Setup Steps

### Step 1: Create Azure Key Vault (if not exists)

```bash
# Set variables
RESOURCE_GROUP="my-resource-group"
KEYVAULT_NAME="my-keyvault"
LOCATION="eastus"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create Key Vault
az keyvault create \
  --name $KEYVAULT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --enable-rbac-authorization
```

### Step 2: Add Secrets to Key Vault

```bash
# Example: Add a Cloudflare API token for cert-manager DNS-01 challenges
az keyvault secret set \
  --vault-name $KEYVAULT_NAME \
  --name "cloudflare-api-token" \
  --value "your-cloudflare-api-token"

# Example: Add Let's Encrypt account private key
az keyvault secret set \
  --vault-name $KEYVAULT_NAME \
  --name "letsencrypt-private-key" \
  --file "./letsencrypt-account.key"

# Example: Add Azure DNS credentials (if using Azure DNS)
az keyvault secret set \
  --vault-name $KEYVAULT_NAME \
  --name "azure-dns-sp-password" \
  --value "your-service-principal-password"
```

### Step 3: Create Azure Managed Identity

```bash
# Create User-Assigned Managed Identity
IDENTITY_NAME="external-secrets-identity"
az identity create \
  --name $IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

# Get the identity details
IDENTITY_CLIENT_ID=$(az identity show \
  --name $IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --query clientId -o tsv)

IDENTITY_OBJECT_ID=$(az identity show \
  --name $IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --query principalId -o tsv)

echo "Client ID: $IDENTITY_CLIENT_ID"
echo "Object ID: $IDENTITY_OBJECT_ID"
```

### Step 4: Grant Key Vault Permissions

```bash
# Get your Azure subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Assign 'Key Vault Secrets User' role to the Managed Identity
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee-object-id $IDENTITY_OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEYVAULT_NAME"
```

### Step 5: Configure Workload Identity Federation

For AKS clusters:

```bash
# Get your AKS cluster OIDC issuer URL
CLUSTER_NAME="my-aks-cluster"
AKS_OIDC_ISSUER=$(az aks show \
  --name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "oidcIssuerProfile.issuerUrl" -o tsv)

# Create federated identity credential
az identity federated-credential create \
  --name "external-secrets-federated-credential" \
  --identity-name $IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --issuer "$AKS_OIDC_ISSUER" \
  --subject "system:serviceaccount:external-secrets-system:external-secrets" \
  --audience "api://AzureADTokenExchange"
```

For non-AKS clusters (k3d, self-managed):
- You'll need to configure your cluster to support Azure Workload Identity
- See: https://azure.github.io/azure-workload-identity/docs/installation/self-managed-clusters.html

### Step 6: Get Azure Tenant ID

```bash
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "Tenant ID: $TENANT_ID"
```

## Configure External Secrets Operator

### Update ESO HelmRelease

Edit `infrastructure/controllers/external-secrets-release.yaml` and replace the placeholder values:

```yaml
serviceAccount:
  annotations:
    azure.workload.identity/client-id: "YOUR_AZURE_CLIENT_ID"  # Use $IDENTITY_CLIENT_ID
    azure.workload.identity/tenant-id: "YOUR_AZURE_TENANT_ID"  # Use $TENANT_ID
```

**Example:**

```bash
# Get the values
echo "Client ID: $IDENTITY_CLIENT_ID"
echo "Tenant ID: $TENANT_ID"
echo "Key Vault URL: https://${KEYVAULT_NAME}.vault.azure.net"
```

Then manually update:
1. `infrastructure/controllers/external-secrets-release.yaml` - Update service account annotations
2. `infrastructure/configs/external-secrets-stores.yaml` - Update `vaultUrl` in SecretStore definitions

### Update SecretStore Configurations

Edit `infrastructure/configs/external-secrets-stores.yaml`:

```yaml
spec:
  provider:
    azurekv:
      vaultUrl: "https://YOUR_KEYVAULT_NAME.vault.azure.net"  # Replace with your Key Vault URL
```

## Deploy with FluxCD

Once configured, commit your changes:

```bash
git add infrastructure/
git commit -m "Add External Secrets Operator with Azure Key Vault integration"
git push
```

FluxCD will automatically:
1. Install ESO Helm chart
2. Create the `external-secrets-system` namespace
3. Deploy ESO controller, webhook, and cert-controller
4. Create SecretStores in `cert-manager` and `default` namespaces
5. Sync example ExternalSecrets (if not annotated with ignore)

## Verify Installation

### Check ESO Pods

```bash
# Check ESO pods are running
kubectl get pods -n external-secrets-system

# Expected output:
# NAME                                               READY   STATUS    RESTARTS   AGE
# external-secrets-xxxxxxxxx-xxxxx                   1/1     Running   0          2m
# external-secrets-xxxxxxxxx-xxxxx                   1/1     Running   0          2m
# external-secrets-cert-controller-xxxxxxxxx-xxxxx   1/1     Running   0          2m
# external-secrets-webhook-xxxxxxxxx-xxxxx           1/1     Running   0          2m
# external-secrets-webhook-xxxxxxxxx-xxxxx           1/1     Running   0          2m
```

### Check FluxCD Reconciliation

```bash
# Check Flux Kustomizations
flux get kustomizations

# Check HelmRelease
flux get helmreleases -n flux-system external-secrets

# Force reconciliation if needed
flux reconcile kustomization infrastructure-controllers
flux reconcile helmrelease -n flux-system external-secrets
```

### Verify SecretStores

```bash
# Check SecretStore status
kubectl get secretstores -A

# Describe a SecretStore
kubectl describe secretstore azure-keyvault-cert-manager -n cert-manager

# Look for status conditions - should show "Valid"
```

### Test Secret Sync

Create a simple test ExternalSecret:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: test-secret
  namespace: cert-manager
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: azure-keyvault-cert-manager
    kind: SecretStore
  target:
    name: test-secret
    creationPolicy: Owner
  data:
    - secretKey: test-value
      remoteRef:
        key: cloudflare-api-token  # Use a secret that exists in your Key Vault
```

Apply and check:

```bash
kubectl apply -f test-externalsecret.yaml

# Check ExternalSecret status
kubectl get externalsecrets -n cert-manager
kubectl describe externalsecret test-secret -n cert-manager

# Check if Kubernetes secret was created
kubectl get secret test-secret -n cert-manager
kubectl get secret test-secret -n cert-manager -o yaml
```

## Using Secrets with cert-manager

### Example: Cloudflare DNS-01 Challenge

1. **Store Cloudflare API token in Azure Key Vault:**

```bash
az keyvault secret set \
  --vault-name $KEYVAULT_NAME \
  --name "cloudflare-api-token" \
  --value "your-cloudflare-api-token"
```

2. **Create ExternalSecret** (already provided in `external-secrets-examples.yaml`):

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: cloudflare-api-token
  namespace: cert-manager
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: azure-keyvault-cert-manager
    kind: SecretStore
  target:
    name: cloudflare-api-token-secret
    creationPolicy: Owner
  data:
    - secretKey: api-token
      remoteRef:
        key: cloudflare-api-token
```

3. **Update cert-manager ClusterIssuer** to use the secret:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod-cloudflare
spec:
  acme:
    email: your-email@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token-secret  # Created by ExternalSecret
              key: api-token
```

## Common Patterns

### Pattern 1: Single Secret per ExternalSecret

Best for isolated, independent secrets:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-api-key
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: azure-keyvault-default
    kind: SecretStore
  target:
    name: my-api-key-secret
  data:
    - secretKey: api-key
      remoteRef:
        key: my-api-key
```

### Pattern 2: Multiple Related Secrets

Group related secrets together:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
  namespace: default
spec:
  refreshInterval: 5m
  secretStoreRef:
    name: azure-keyvault-default
    kind: SecretStore
  target:
    name: db-credentials
    template:
      data:
        username: "{{ .dbUser }}"
        password: "{{ .dbPass }}"
        host: "{{ .dbHost }}"
        connection-string: "postgresql://{{ .dbUser }}:{{ .dbPass }}@{{ .dbHost }}:5432/mydb"
  data:
    - secretKey: dbUser
      remoteRef:
        key: database-username
    - secretKey: dbPass
      remoteRef:
        key: database-password
    - secretKey: dbHost
      remoteRef:
        key: database-host
```

### Pattern 3: Sync All Secrets with Prefix

Use `dataFrom` to sync multiple secrets at once:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-config
  namespace: default
spec:
  refreshInterval: 10m
  secretStoreRef:
    name: azure-keyvault-default
    kind: SecretStore
  target:
    name: app-config-secrets
  dataFrom:
    - find:
        name:
          regexp: "^app-config-.*"
```

## Creating SecretStores for New Namespaces

When adding a new namespace, create a SecretStore:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-keyvault
  namespace: my-new-namespace
spec:
  provider:
    azurekv:
      vaultUrl: "https://YOUR_KEYVAULT_NAME.vault.azure.net"
      authType: WorkloadIdentity
      serviceAccountRef:
        name: external-secrets
        namespace: external-secrets-system
```

Add this to `infrastructure/configs/external-secrets-stores.yaml` and commit.

## Troubleshooting

### ESO Pods Not Starting

```bash
# Check pod status
kubectl get pods -n external-secrets-system
kubectl describe pod <pod-name> -n external-secrets-system

# Check logs
kubectl logs -n external-secrets-system deployment/external-secrets
```

Common issues:
- Image pull errors: Check network/registry access
- CRD conflicts: Ensure no old ESO installation exists

### SecretStore Shows Invalid Status

```bash
kubectl describe secretstore <name> -n <namespace>
```

Common issues:
- **Authentication failure**: Check Workload Identity configuration
  - Verify client ID and tenant ID are correct
  - Ensure federated credential exists and matches service account
- **Key Vault access denied**: Verify RBAC role assignment
- **Key Vault URL wrong**: Double-check the vault URL format

### ExternalSecret Not Syncing

```bash
kubectl describe externalsecret <name> -n <namespace>
kubectl logs -n external-secrets-system deployment/external-secrets
```

Common issues:
- **Secret not found in Key Vault**: Verify secret name matches exactly
- **SecretStore not ready**: Wait for SecretStore to be valid
- **Refresh interval**: Default is 1h, force sync with:
  ```bash
  kubectl annotate externalsecret <name> -n <namespace> \
    force-sync=$(date +%s) --overwrite
  ```

### Azure Authentication Issues

```bash
# Check service account annotations
kubectl get sa external-secrets -n external-secrets-system -o yaml

# Check pod environment variables (Workload Identity injects these)
kubectl get pod -n external-secrets-system -l app.kubernetes.io/name=external-secrets -o yaml | grep -A 5 "env:"
```

Verify:
- Service account has correct annotations
- Pods have label `azure.workload.identity/use: "true"`
- Federated credential subject matches: `system:serviceaccount:external-secrets-system:external-secrets`

### Testing Azure Authentication

Create a debug pod to test Azure authentication:

```bash
kubectl run -it --rm debug \
  --image=mcr.microsoft.com/azure-cli \
  --overrides='
{
  "spec": {
    "serviceAccountName": "external-secrets",
    "labels": {"azure.workload.identity/use": "true"},
    "containers": [{
      "name": "debug",
      "image": "mcr.microsoft.com/azure-cli",
      "stdin": true,
      "tty": true
    }]
  }
}' \
  -n external-secrets-system \
  -- /bin/bash

# Inside the pod:
# Login using workload identity
az login --federated-token "$(cat $AZURE_FEDERATED_TOKEN_FILE)" \
  --service-principal \
  -u $AZURE_CLIENT_ID \
  -t $AZURE_TENANT_ID

# Test Key Vault access
az keyvault secret list --vault-name YOUR_KEYVAULT_NAME
az keyvault secret show --vault-name YOUR_KEYVAULT_NAME --name cloudflare-api-token
```

## Security Best Practices

1. **Least Privilege**: Only grant ESO identity access to specific secrets it needs
2. **RBAC**: Use namespace-scoped SecretStores instead of ClusterSecretStore
3. **Rotation**: Use short `refreshInterval` for sensitive secrets
4. **Audit**: Enable Azure Key Vault logging to track secret access
5. **Secret Encryption**: Ensure Kubernetes secrets encryption at rest is enabled

## Monitoring and Observability

### Prometheus Metrics

ESO exposes metrics on port 8080:

```bash
kubectl port-forward -n external-secrets-system svc/external-secrets 8080:8080

# View metrics
curl http://localhost:8080/metrics
```

Key metrics:
- `externalsecret_sync_calls_total` - Total sync operations
- `externalsecret_sync_calls_error` - Failed sync operations
- `externalsecret_status_condition` - Current status of ExternalSecrets

### Logs

```bash
# Follow ESO controller logs
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets -f

# Filter for specific namespace
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets | grep "namespace=cert-manager"
```

## Additional Resources

- [External Secrets Operator Documentation](https://external-secrets.io/)
- [Azure Workload Identity Documentation](https://azure.github.io/azure-workload-identity/)
- [Azure Key Vault RBAC Guide](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide)
- [cert-manager DNS-01 Challenge](https://cert-manager.io/docs/configuration/acme/dns01/)

## Next Steps

1. Configure Azure resources (Key Vault, Managed Identity, Federated Credential)
2. Update ESO configuration with your Azure credentials
3. Add secrets to Azure Key Vault
4. Create ExternalSecrets for your applications
5. Update cert-manager ClusterIssuers to use synced secrets
6. Set up monitoring and alerting for secret sync failures
