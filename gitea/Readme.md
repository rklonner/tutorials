# Gitea

## Install helm chart in kind cluster
```bash
# Create kind cluster
kind create cluster

# Switch to kind context
kubectl config use-context kind-kind

# Install Gitea
helm repo add add gitea-charts https://dl.gitea.com/charts/
helm repo update
helm install gitea gitea-charts/gitea \
  --namespace gitea \
  --create-namespace

# Verify that Gitea is running
watch kubectl -n gitea get pods
```

## Usage
```bash
# Port forward Gitea server to localhost:3000
kubectl -n gitea port-forward svc/gitea-http 3000:3000

# Use Gitea CLI within pod
pod_name=$(kubectl -n gitea get pod -l app=gitea -o jsonpath="{.items[0].metadata.name}")
kubectl -n gitea exec -it $pod_name -c gitea -- gitea admin user list
```

## Configuration

### Boostrap Gitea instance
The script `gitea-bootstrap.sh` provided alongside this Readme will create a user account and organization. 
In addition, the script will return a token that can be used for API access or with ArgoCD.

On top of that it has an optional parameter for a local path containing git repositories that will be imported into the newly created organization.

```bash
./gitea-bootstrap.sh username password me@example.com example-org /path/to/local/git/repositories
```