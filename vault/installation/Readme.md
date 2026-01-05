# Vault

## Install helm chart in kind cluster
```bash
# Create kind cluster
kind create cluster

# Switch to kind context
k config use-context kind-kind

# Install Vault
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install vault hashicorp/vault \
    --set "server.dev.enabled=true" \
    --namespace vault \
    --create-namespace

# Verify that Vault service is running
watch kubectl -n vault get pods

# Check logs for possible issues
kubectl -n vault logs -f vault-0
```

## Usage
```bash
# Port forward Vault server to localhost
kubectl -n vault port-forward vault-0 8200:8200

# Access Vault over the Browser with token `root`
http://localhost:8200/ui/vault/auth

# Prepare vault cli
# Variant a) Use Vault cli within the vault pod
kubectl -n vault exec -ti vault-0 -- sh

# Variant b) Use a locally installed Vault cli
export VAULT_ADDR='http://localhost:8200'
vault login
```
