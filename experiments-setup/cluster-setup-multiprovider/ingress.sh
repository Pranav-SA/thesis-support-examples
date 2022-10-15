# If Minikube
minikube addons enable ingress

# If Docker Desktop, GKE, or AKS
kubectl apply \
    --filename https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.0/deploy/static/provider/cloud/deploy.yaml

# If EKS
kubectl apply \
    --filename https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.0/deploy/static/provider/aws/deploy.yaml

# If Minikube
export INGRESS_HOST=$(minikube ip)

# If k3d
# disable traefik during setup
# depending upon version - may require steps as for Docker or minikube
# https://github.com/scaamanho/k3d-cluster/blob/master/Ingress-Controller.md

# port_number from nodeport service if any
# Then try Gateway 127.0.0.1:port_number

# If Docker Desktop or EKS
export INGRESS_HOST=$(kubectl \
    --namespace ingress-nginx \
    get service ingress-nginx-controller \
    --output jsonpath="{.status.loadBalancer.ingress[0].hostname}")

# If GKE or AKS
export INGRESS_HOST=$(kubectl \
    --namespace ingress-nginx \
    get service ingress-nginx-controller \
    --output jsonpath="{.status.loadBalancer.ingress[0].ip}")

echo $INGRESS_HOST