# Vault - Kubernetes auth with custom metadata

Upon login, Vault auto-populates certain metadata like serviceAccountName and namespace.
To cover more complex scenarios, one can add additional metadata with annotations to serviceAccounts and leverage those in templated policies.
This feature is available in Vault >=1.16 and can be activated by `use_annotations_as_alias_metadata=true`.

The following example:
* deploys a Vault instance in a kind cluster
* sets up kubernetes auth and allowing custom metadata (project, stage, component)
* creates example secrets
* deploys simple application with a properly configured service account token
* shows curl commands within this pod to login to Vault, retrieve a token and request secrets

Reference:
* [Configure kubernetes auth custom metadata](https://developer.hashicorp.com/vault/docs/auth/kubernetes#workflows)
* [Debugging kubernetes auth problems](https://support.hashicorp.com/hc/en-us/articles/4404389946387-Kubernetes-auth-method-Permission-Denied-error)

## Prepare Environment

```
# Create kind cluster
kind create cluster

# Switch to kind context
k config use-context kind-kind

# Install Vault by applying the official manifests
kubectl create ns vault
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install vault hashicorp/vault \
    --set "server.dev.enabled=true" \
    --namespace vault

# Verify that Vault service is running
watch kubectl -n vault get pods
kubectl -n vault logs -f vault-0

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

# Enable kubernetes auth
vault auth enable kubernetes

# Configure kubernetes auth
vault write auth/kubernetes/config \
    kubernetes_host=https://kubernetes.default.svc.cluster.local \
    use_annotations_as_alias_metadata=true

# Create secret engine
vault secrets enable -path=apps kv-v2

# Create example secrets with custom structure
vault kv put apps/projects/app1/dev/backend username="backend-user" password="backend-password"
vault kv put apps/projects/app1/dev/frontend username="frontend-user" password="backend-password"

# Retrieve kubernetes auth mount accessfor
MOUNT_ACCESSOR=$(vault auth list -format=json | jq -r '.["kubernetes/"].accessor')

# Create templated policy that will utilize custom metadata
vault policy write apps-custom-metadata -<<EOF
path "apps/data/projects/{{identity.entity.aliases.$MOUNT_ACCESSOR.metadata.project}}/{{identity.entity.aliases.$MOUNT_ACCESSOR.metadata.stage}}/{{identity.entity.aliases.$MOUNT_ACCESSOR.metadata.component}}" {
   capabilities = ["read", "list"]
}
EOF

# Create kubernetes auth role with policy
vault write auth/kubernetes/role/app1 \
    bound_service_account_names=app1-sa \
    bound_service_account_namespaces=app1 \
    policies=apps-custom-metadata \
    audience=vault \
    ttl=24h
```

## Deploy example application

An example application is prepated in the file `vault-custom-metadata-example-app.yaml`

```
# Apply example app manifests
kubectl apply -f vault-custom-metadata-example-app.yaml.yaml
```

Two keypoints that should be highlighted:

* **ServiceAccount annotations**
    ```
    apiVersion: v1
    kind: ServiceAccount
    metadata:
    name: app1-sa
    namespace: app1
    annotations:
        vault.hashicorp.com/alias-metadata-project: app1
        vault.hashicorp.com/alias-metadata-stage: dev
        vault.hashicorp.com/alias-metadata-component: backend
    ```

    Values that are mentioned in the annotations starting with `vault.hashicorp.com/alias-metadata-<KEY>` will be available in the login metadata `identity.entity.aliases.$MOUNT_ACCESSOR.metadata.project.KEY` and can be used in templated Vault policies.

* **Include Vault audience in serviceAccount token**
    ```
    volumeMounts:
        - mountPath: /var/run/secrets/tokens
        name: vault-token
    volumes:
    - name: vault-token
    projected:
        sources:
        - serviceAccountToken:
            path: vault-token
            expirationSeconds: 7200
            audience: vault
    ```

    From Vault 1.21+ kubernetes auth roles will be required to have the audience attribute included in the JWT token. This needs to be configured for the token that is mounted for the serviceAccount like shown above.


## Test Vault login and secret retrieval
```
# Get example app pod name
pod_name=$(kubectl -n app1 get pod -l app=app1 -o jsonpath="{.items[0].metadata.name}")

# Exec into pod
kubectl -n app1 exec -it $pod_name -- bash

# Get token that holds audience 'vault' from projected volume
sa_jwt_token=$(cat /var/run/secrets/tokens/vault-token)

# Option: Try login request and review response
curl -s --request POST --data '{"jwt": "'$sa_jwt_token'", "role": "app1"}' vault.vault.svc.cluster.local:8200/v1/auth/kubernetes/login

# Login to Vault and retrieve token from response (no jq in pod)
vault_client_token=$(curl -s --request POST --data '{"jwt": "'$sa_jwt_token'", "role": "app1"}' vault.vault.svc.cluster.local:8200/v1/auth/kubernetes/login | grep -o '"client_token":"[^"]*' | cut -d'"' -f4)

# Use Vault token and request the backend secret
curl --request GET --header "X-Vault-Token:$vault_client_token" vault.vault.svc.cluster.local:8200/v1/apps/data/projects/app1/dev/backend

# Use Vault token and request the frontend secret
curl --request GET --header "X-Vault-Token:$vault_client_token" vault.vault.svc.cluster.local:8200/v1/apps/data/projects/app1/dev/backend
```

## Debugging

### Analyze login and secret retrieval requests
```
# Enable audit log
vault audit enable file file_path=/home/vault/vault_audit.log

# Watch for activity
tail -f /home/vault/vault_audit.log
```

# one time vault missed read access for service accounts
kubectl create clusterrolebinding vault-read-sa --clusterrole=cluster-admin --serviceaccount=vault:vault
```