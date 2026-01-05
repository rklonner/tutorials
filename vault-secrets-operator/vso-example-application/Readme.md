# Example application using the Vault Secret Operator

Demonstrate:
* How secrets are loaded into the cluster and used by an application
* How secrets are updated in the cluster for a change in Vault
* How the Deployment will restart automatically when secrets change (rolloutRestart)

Prerequisites:
* Vault is setup in your cluster (see [Installation](../../vault/Readme.md#install-helm-chart-in-kind-cluster))
* Vault CLI is ready to use (see [Usage](../../vault/Readme.md#usage))
* Vault Secrets Operator is setup in your cluster (see [Installation](../Readme.md))

## Prepare Vault

```bash
# Create policy to control access to our future secret engine
vault policy write vso-example-app -<<EOF
path "vso-example-app/data/app-login" {
   capabilities = ["read", "list"]
}
EOF

# Create secret engine
vault secrets enable --path=vso-example-app kv-v2

# Create secrets in new secret engine
vault kv put vso-example-app/app-login username="static-user" password="static-password"

# Enable kubernetes authentication
vault auth enable --path=kubernetes kubernetes

# Configure kubernetes auth backend
vault write auth/kubernetes/config \
    kubernetes_host=https://kubernetes.default.svc.cluster.local

# Create kubernetes auth app role to control access
vault write auth/kubernetes/role/vso-example-app \
  bound_service_account_names=vso-example-sa \
  bound_service_account_namespaces=vso-example-ns \
  policies=vso-example-app \
  audience=vault \
  ttl=24h
```

## Deploy our example application

```bash
# Create k8s resources
kubectl apply -f vso-example-app.yaml

# Watch the pods for a successful deployment
kubectl -n vso-example-ns get pods --watch
```

This will create:
* the application namespace
* VaultConnection, VaultAuth and VaultStaticSecret
* the application ServiceAccount, Service and Deployment

The VaultStaticSecret object will connection to Vault over the VaultAuth and VaultConnection object. After a successful connection, the Vault Secrets Operator is creating a k8s secret named test-secret. This secret is mounted by the application into the Pod environment and exposed as html text for demonstration purposes.

## Play with the application

```bash
# Execute an example container to curl the application service and get basic index.html back
kubectl -n vso-example-ns run test2 --image=nginx -i --rm --restart=Never -- curl -m 1 vso-example-app.vso-example-ns.svc.cluster.local
```

you will see an output like
```
username: static-user<br>
password: static-password
```

Before we trigger an update in Vault we watch the pods in a terminal to visualize the restartRollout feature where the Deployment is restarted to update the secrets loaded into the environment

```bash
kubectl -n vso-example-ns get pods --watch
```

Now, in a second terminal window we trigger and update to the secrets in Vault and change the password

```bash
vault kv put vso-example-app/app-login username="static-user" password="new-static-password"
```

After some seconds we notice that the pods are restared.

We also check the events of the VaultStaticSecret object 

```bash
kubectl -n vso-example-ns describe vaultstaticsecrets.secrets.hashicorp.com test-static-secret

...
Normal   SecretSynced             4m5s (x3 over 44m)  VaultStaticSecret   Secret synced
Normal   RolloutRestartTriggered  4m5s (x2 over 41m)  VaultStaticSecret   Rollout restart triggered for {Deployment vso-example-app-deployment}
```

and see that a Rollout restart operation is triggered after a Secret sync.

We can also print the html page of our application again to verify the secret content is updated:

```bash
kubectl -n vso-example-ns run test2 --image=nginx -i --rm --restart=Never -- curl -m 1 vso-example-app.vso-example-ns.svc.cluster.local
```

which shows

```
username: static-user<br>
password: new-static-password
```

Alternatively you can also watch the secret update in the browser

```bash
# Port forward application
kubectl -n vso-example-ns port-forward svc/vso-example-app 9000:80

# Open in browser and check secret contents
http://localhost:9000

# Update the secret
vault kv put vso-example-app/app-login username="static-user" password="new-static-password"

# Establish port forward again as the rolloutRestart operation breaks the connection to the pod
kubectl -n vso-example-ns port-forward svc/vso-example-app 9000:80

# Open in browser and check secret contents again
http://localhost:9000
```

## Cleanup
```
kubectl delete -f vso-example-app.yaml
```
