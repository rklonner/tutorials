# Crossplane - Create a simple composition

**Demonstrate**:
* How to simulate a local mssql server
* How to configure a crossplane provider for mssql
* How to create a database, users and permissions (grant)
* How to verify the permissions

**Prerequisites**:
* Crossplane is setup in your cluster (see [Installation](../Readme.md#install-helm-chart-in-kind-cluster))

## Prepare environment

```bash
# apply patch and transform function
kubectl apply -f fn.yaml

# Verify the installation
kubectl get functions.pkg.crossplane.io crossplane-contrib-function-patch-and-transform
```

## Create composition
```bash
# apply XRD
kubectl apply -f xrd.yaml

# Verify
kubectl get customresourcedefinitions.apiextensions.k8s.io apps.example.crossplane.io

# create composition
kubectl apply -f composition.yaml

# Verify
kubectl get compositions.apiextensions.crossplane.io app-yaml

# create app (namespaced XR)
kubectl apply -f app.yaml

# Verify resources and nginx
kubectl -n default get all

kubectl -n default run test --image=nginx -i --rm --restart=Never -- curl -m 1 my-app.default.svc.cluster.local:8080
```