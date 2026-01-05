#!/bin/bash

# Usage: ./bootstrap.sh <username> <password> <email> <orgname> [gitreposdir]
if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
  echo "Usage: $0 <username> <password> <email> <orgname> [gitreposdir]"
  exit 1
fi

USERNAME="$1"
PASSWORD="$2"
EMAIL="$3"
ORGNAME="$4"
GITREPOSDIR="${5:-$HOME/git/sandbox-local}"

# get pod name
pod=$(kubectl -n gitea get pod -l app=gitea -o jsonpath="{.items[0].metadata.name}")

# check if user exists
kubectl -n gitea exec $pod -c gitea -- gitea admin user list | grep -q "$USERNAME"
if [ $? -eq 0 ]; then
  echo "User '$USERNAME' already exists, updating password."
  kubectl -n gitea exec -it $pod -c gitea -- gitea admin user change-password --username "$USERNAME" --password "$PASSWORD" --must-change-password=false
else
  kubectl -n gitea exec -it $pod -c gitea -- gitea admin user create --username "$USERNAME" --password "$PASSWORD" --email "$EMAIL" --must-change-password=false
fi

# create random token name
TOKEN_NAME="access-$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8)"

# create token
result=$(kubectl -n gitea exec -it $pod -c gitea -- gitea admin user generate-access-token --username "$USERNAME" --token-name "$TOKEN_NAME")
token=$(echo $result | cut -d ':' -f 2 | tr -d '[:space:]')
echo "Gitea Access Token: $token (token name: $TOKEN_NAME)"

# check if organization exists using curl GET request
ORG_CHECK_URL="http://localhost:3000/api/v1/orgs/$ORGNAME"
org_status=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $token" "$ORG_CHECK_URL")
if [ "$org_status" -eq 200 ]; then
  echo "Organization '$ORGNAME' already exists, skipping creation."
else
  echo "[INFO] Creating organization '$ORGNAME' via API..."
  curl -X POST "http://localhost:3000/api/v1/orgs" \
       -H "accept: application/json" \
       -H "Authorization: token $token" \
       -H "Content-Type: application/json" \
       -d "{\"username\": \"$ORGNAME\", \"description\": \"Testorg\"}" \
       -i
fi

# Only import repositories if gitreposdir is specified as input
if [ "$#" -eq 5 ]; then
  repos=$(ls "$GITREPOSDIR")
  for repo in $repos;
  do
    echo $repo
    curl -X POST "http://localhost:3000/api/v1/user/repos" \
         -H "accept: application/json" \
         -H "Authorization: token $token" \
         -H "Content-Type: application/json" \
         -d "{\"name\": \"$repo\"}" \
         -i

    curl -X POST "http://localhost:3000/api/v1/repos/$USERNAME/$repo/transfer" \
         -H "accept: application/json" \
         -H "Authorization: token $token" \
         -H "Content-Type: application/json" \
         -d "{\"new_owner\": \"$ORGNAME\"}" \
         -i

    echo "git -C $GITREPOSDIR/$repo push http://$USERNAME:$token@localhost:3000/$ORGNAME/$repo.git"
    git -C "$GITREPOSDIR/$repo" push http://$USERNAME:$token@localhost:3000/$ORGNAME/$repo.git --all
  done
fi