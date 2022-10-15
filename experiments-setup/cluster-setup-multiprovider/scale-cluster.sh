#For GKE clusters
#execute the command that follows only if you are using Google Kubernetes Engine (GKE). Bear in mind that, if you have a newly created account, the command might fail due to insufficient quotas. If that happens, follow the instructions in the output to request a quota increase.

gcloud container clusters \
    resize $CLUSTER_NAME \
    --zone us-east1-b \
    --num-nodes=3

#For EKS clusters#
#Please execute the commands that follow only if you are using Amazon’s Elastic Kubernetes Service (EKS).

eksctl get nodegroup --cluster $CLUSTER_NAME

export NODE_GROUP=[...] # Replace `[...]` with the node group

eksctl scale nodegroup \
    --cluster=$CLUSTER_NAME \
    --nodes 3 \
    $NODE_GROUP

#For AKS clusters#
#Please execute the commands that follow only if you are using Azure Kubernetes Service (AKS).

az aks show \
    --resource-group chaos \
    --name chaos \
    --query agentPoolProfiles

export NODE_GROUP=[...] # Replace `[...]` with the `name` (e.g., `nodepool1`)

az aks scale \
    --resource-group chaos \
    --name chaos \
    --node-count 3 \
    --nodepool-name $NODE_GROUP

#Depending on where you’re running your Kubernetes cluster, the process can take anything from seconds to minutes.
