######################
# Create The Cluster #
######################

az login

az provider register -n Microsoft.Network

az provider register -n Microsoft.Storage

az provider register -n Microsoft.Compute

az provider register -n Microsoft.ContainerService

az extension add --name aks-preview

az group create \
    --name chaos \
    --location eastus

az aks create \
    --resource-group chaos \
    --name chaos \
    --node-count 3 \
    --node-vm-size Standard_D4s_v3 \
    --generate-ssh-keys \
    --enable-cluster-autoscaler \
    --min-count 1 \
    --max-count 6

az aks get-credentials \
    --resource-group chaos \
    --name chaos

#################
# Install Istio #
#################

istioctl manifest install \
    --skip-confirmation

export INGRESS_HOST=$(kubectl \
    --namespace istio-system \
    get service istio-ingressgateway \
    --output jsonpath="{.status.loadBalancer.ingress[0].ip}")

echo $INGRESS_HOST

# Repeat the `export` command if the output of `echo` is empty

#######################
# Destroy the cluster #
#######################

az group delete --name chaos --yes

kubectl config delete-cluster chaos

kubectl config delete-context chaos

kubectl config unset \
    users.clusterUser_chaos_chaos