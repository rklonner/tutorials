# Crossplane - Create composition of microservices

**Demonstrate**:
* How to create nested compositions to abstract a set of microservices in one application XR
* How XRDs and Compositions can be structured for individual mircoservices and the parent application
* How to enable/disable microservices with kcl and visualize how Crossplane reconciles changes

**Prerequisites**:
* Crossplane is setup in your cluster (see [Installation](../Readme.md#install-helm-chart-in-kind-cluster))

## Prepare environment

```bash
# apply patch and transform function
kubectl apply -f fn.yaml
```

## Create XRDs and Compositions
```bash
# apply XRD
kubectl apply -f xrds.yaml

# Verify show all xrds, describe one if there are issues
kubectl get xrds
kubectl describe xrd xfrontends.example.com

# create composition
kubectl apply -f comp-frontend.yaml -f comp-backend.yaml -f comp-parent.yaml

# Verify show all compositions, describe one if there are issues
kubectl get compositions.apiextensions.crossplane.io
kubectl describe compositions.apiextensions.crossplane.io xfrontends.example.com

# Create actual application (namespaced XR, "Developer Claim")
kubectl apply -f app.yaml

# Verify 
# Verify status of "parent" XR
kubectl describe xapps.example.com my-web-stack

# resources deployed in the default namespace
kubectl -n default get all
```

## Test microservice toggles
By default, the parent XR `app.yaml` has enabled both microservices

```yaml
# Toggle logic used by the Parent Composition
includeFrontend: true
includeBackend: true
```

Let's look at all resources deployed
```bash
k -n default get all

NAME                                             READY   STATUS    RESTARTS   AGE
pod/razor-deployment-backend-54c98b4f84-c68r6    1/1     Running   0          74m
pod/razor-deployment-frontend-54c98b4f84-5cb69   1/1     Running   0          74m

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   47h

NAME                                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/razor-deployment-backend    1/1     1            1           74m
deployment.apps/razor-deployment-frontend   1/1     1            1           74m

NAME                                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/razor-deployment-backend-54c98b4f84    1         1         1       74m
replicaset.apps/razor-deployment-frontend-54c98b4f84   1         1         1       74m
```

Now we deactivate the backend microservice in `app.yaml`
```yaml
# Toggle logic used by the Parent Composition
includeFrontend: true
includeBackend: false
```

and reconfigure the application. We now see that Crossplane reconciled already and removed the backend microservice.
```bash
kubectl apply -f app.yaml

# Let's check again the deployed resources
k -n default get all
NAME                                             READY   STATUS    RESTARTS   AGE
pod/razor-deployment-frontend-54c98b4f84-5cb69   1/1     Running   0          77m

NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   47h

NAME                                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/razor-deployment-frontend   1/1     1            1           77m

NAME                                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/razor-deployment-frontend-54c98b4f84   1         1         1       77m
```