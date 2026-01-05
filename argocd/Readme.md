# ArgoCD

## Install over kustomize in kind cluster
```bash
# Create kind cluster
kind create cluster

# Switch to kind context
kubectl config use-context kind-kind

# Install ArgoCD by applying the official manifests
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Verify that ArgoCD is running
watch kubectl -n argocd get pods
```

## Usage
```bash
# Port forward ArgoCD server to localhost:8000
kubectl -n argocd port-forward svc/argocd-server 8000:80

# Get initial admin password for ArgoCD UI access
ADMIN_PASSWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo $ADMIN_PASSWD

# Login with ArgoCD CLI
argocd login localhost:8000 --insecure --username=admin --password=${ADMIN_PASSWD}
```

## Configuration
```bash
# Add repository credentials to ArgoCD for a whole gitea organization
argocd repocreds add http://gitea-http.gitea.svc.cluster.local:3000/example-org / --username <username> --password <password>
```
