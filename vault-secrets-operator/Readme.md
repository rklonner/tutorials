# Vault Secrets Operator 

## Install operator via helm chart in kind cluster
```bash
# Create kind cluster
kind create cluster

# Switch to kind context
kubectl config use-context kind-kind

# Install Vault Secrets Operator
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install vault-secrets-operator hashicorp/vault-secrets-operator \
  --create-namespace \
  --namespace vault-secrets-operator

# Verify that Vault Secrets Operator is running
watch kubectl -n vault-secrets-operator get pods
```