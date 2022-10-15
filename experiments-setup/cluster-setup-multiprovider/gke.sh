######################
# Instructions - Create The Cluster #
######################

gcloud auth login

# Open https://console.cloud.google.com/cloud-resource-manager to create a new project if you don't have one already

export PROJECT_ID=[...] # Replace [...] with the ID of the project

gcloud container get-server-config \
    --region us-east1

export VERSION=[...] # Replace [...] with k8s version from the `validMasterVersions` section. Make sure that it is v1.14+.

gcloud container clusters \
    create chaos \
    --project $PROJECT_ID \
    --cluster-version $VERSION \
    --zone us-east1-b \
    --machine-type n1-standard-4 \
    --num-nodes 1

kubectl create clusterrolebinding \
    cluster-admin-binding \
    --clusterrole cluster-admin \
    --user $(gcloud config get-value account)

#######################
# Instructions - Destroy the cluster #
#######################

gcloud container clusters \
    delete chaos \
    --zone us-east1-b \
    --quiet

# Remove unused disks to avoid reaching the quota (and save a bit of money)
gcloud compute disks delete \
    --zone us-east1-b \
    $(gcloud compute disks list \
    --filter="zone:us-east1-b AND -users:*" \
    --format="value(id)")

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