####################
# Instructions - Create a cluster #
####################

k3d cluster create chaos --agents 2 --servers 3 --k3s-arg "--disable=traefik@server:0,1,2" --k3s-arg "--disable=servicelb@server:0,1,2"

# --no-lb  --api-port 6443 Or change load balancer port using 
# k3d node edit k3d-chaos-serverlb --port-add port_number:port_number
# port_number from nodeport service if any
# Then try Gateway 127.0.0.1:port_number


#######################
# Instructions - Destroy the cluster #
#######################

k3d cluster delete chaos