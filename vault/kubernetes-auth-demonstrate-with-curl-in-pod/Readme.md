# Vault Kubernetes auth

Demonstrate:
* How to setup a basic kubernetes authentication in Vault
* How to mount a ServiceAccount token with audience vault
* How to access Vault with VAULT API and curl inside the Pod to simulate access of a vault-aware application

Prerequisites:
* Vault is setup in your cluster (see [Installation](../Readme.md#install-helm-chart-in-kind-cluster))
* Vault CLI is ready to use (see [Usage](../Readme.md#usage))

## Prepare Vault

```bash
# Create policy to control access to our future secret engine
vault policy write example-application -<<EOF
path "example-application/data/app-login" {
   capabilities = ["read", "list"]
}
EOF

# Create secret engine
vault secrets enable --path=example-application kv-v2

# Create secrets in new secret engine
vault kv put example-application/app-login username="static-user" password="static-password"

# Enable kubernetes authentication
vault auth enable --path=kubernetes kubernetes

# Configure kubernetes auth backend
vault write auth/kubernetes/config \
    kubernetes_host=https://kubernetes.default.svc.cluster.local

# Create kubernetes auth app role to control access
vault write auth/kubernetes/role/example-application \
  bound_service_account_names=example-application-sa \
  bound_service_account_namespaces=example-application-ns \
  policies=example-application \
  audience=vault \
  ttl=24h
```

## Deploy our example application

```bash
# Create k8s resources
kubectl apply -f example-application.yaml

# Watch the pods for a successful deployment
kubectl -n example-application-ns get pods --watch
```

This will create:
* the application namespace
* the application ServiceAccount and Deployment
* will mount a ServiceAccount token `vault-token` with audience vault

## Read the Vault secret from within the Pod

```bash
# Exec into pod
```bash
pod_name=$(kubectl -n example-application-ns get pod -l app=nginx -o jsonpath='{.items[0].metadata.name}')
kubectl -n example-application-ns exec -it $pod_name -- bash

# Read pod service account token (jwt token)
sa_jwt_token=$(cat /var/run/secrets/tokens/vault-token)

# Make Vault login request for kubernetes auth, defined role and jwt token
# If successful, returned json string contains object "auth.client_token", parse it (no jq in container)

vault_client_token=$(curl -s --request POST --data '{"jwt": "'$sa_jwt_token'", "role": "example-application"}' vault.vault.svc.cluster.local:8200/v1/auth/kubernetes/login | grep -o '"client_token":"[^"]*' | cut -d'"' -f4)

# Request and read secret with retrieved Vault token
curl --request GET --header "X-Vault-Token:$vault_client_token" vault.vault.svc.cluster.local:8200/v1/example-application/data/app-login
```
