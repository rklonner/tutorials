# Crossplane

## Install helm chart in kind cluster
```bash
# Create kind cluster
kind create cluster

# Switch to kind context
kubectl config use-context kind-kind

# Install
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
helm install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system \
  --create-namespace

# Verify the installation
kubectl get pods -n crossplane-system --watch
```