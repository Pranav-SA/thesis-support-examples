
# If Docker Desktop and if kept the cluster from the previous section
kubectl delete \
    --filename https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.1/deploy/static/provider/cloud/deploy.yaml

istioctl manifest install \
    --skip-confirmation

kubectl --namespace istio-system \
    get service istio-ingressgateway

# Confirm that `EXTERNAL-IP` is not `pending`, unless using Minikube. Repeat if it is.

# If Minikube
export INGRESS_PORT=$(kubectl \
    --namespace istio-system \
    get service istio-ingressgateway \
    --output jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')

# If Minikube
export INGRESS_HOST=$(minikube ip):$INGRESS_PORT

# If Docker Desktop
export INGRESS_HOST=127.0.0.1

# If GKE or AKS
export INGRESS_HOST=$(kubectl \
    --namespace istio-system \
    get service istio-ingressgateway \
    --output jsonpath="{.status.loadBalancer.ingress[0].ip}")

# If EKS
export INGRESS_HOST=$(kubectl \
    --namespace istio-system \
    get service istio-ingressgateway \
    --output jsonpath="{.status.loadBalancer.ingress[0].hostname}")

echo $INGRESS_HOST
