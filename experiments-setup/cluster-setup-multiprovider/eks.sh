####################
# Instructions - Create a cluster #
####################

# Follow the instructions from https://github.com/weaveworks/eksctl to intall eksctl if you do not have it already

export AWS_ACCESS_KEY_ID=[...] # Replace [...] with the AWS Access Key ID

export AWS_SECRET_ACCESS_KEY=[...] # Replace [...] with the AWS Secret Access Key

export AWS_DEFAULT_REGION=us-west-2

eksctl create cluster \
    --name chaos \
    --region $AWS_DEFAULT_REGION \
    --node-type t2.xlarge \
    --nodes 1 \
    --managed

#######################
# Instructions - Destroy the cluster #
#######################

eksctl delete cluster \
    --name chaos \
    --region $AWS_DEFAULT_REGION

# Delete unused volumes
for volume in `aws ec2 describe-volumes --output text| grep available | awk '{print $8}'`; do 
    echo "Deleting volume $volume"
    aws ec2 delete-volume --volume-id $volume
done

#################
# Install Istio #
#################

istioctl manifest install \
    --skip-confirmation

export INGRESS_HOST=$(kubectl \
    --namespace istio-system \
    get service istio-ingressgateway \
    --output jsonpath="{.status.loadBalancer.ingress[0].hostname}")

echo $INGRESS_HOST