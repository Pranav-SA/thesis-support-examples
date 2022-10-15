## "Impact of node loss on application" Chaos Experiment

As before, Do NOT use a real production cluster for this experiment without preparation and trial.
Below can be very destructive. You might not be able to recuperate from the mayhem. So, make sure that the cluster is disposable.

Draining nodes is, most of the time, a voluntary action. We tend to drain our nodes when we choose to upgrade our cluster. The previous experiment (experiment-6) was beneficial because it ensured that we are able to upgrade the cluster without (much) fear. However, there is still something worse that can happen to our nodes.
More often than not, nodes will fail without our consent. They will not drain. They will get destroyed or damaged, they will go down, and they will be powered off.

### Prerequisites

To run this you will need the [Chaos Toolkit CLI][chaos-toolkit] >= 0.3.0
installed and have access to a Kubernetes cluster. Checkout Wiki for set up instructions. <br>
*Assuming resources from previous experiments were destroyed. This experiment can be continued after third without any changes.*<br>

```shell
(venv) $ pip install -U chaostoolkit
```

[chaos-toolkit]: https://github.com/chaostoolkit/chaostoolkit
[minikube]: https://kubernetes.io/docs/getting-started-guides/minikube/

You will also need to install the [chaostoolkit-kubernetes][chaosk8s] extension and [chaostoolkit-istio][chaosistio]:

```shell
(venv) $ pip install -U chaostoolkit-kubernetes
```

[chaosk8s]: https://github.com/chaostoolkit/chaostoolkit-kubernetes

```shell
(venv) $ pip install -U chaostoolkit-istio
```

[chaosistio]: https://github.com/chaostoolkit/chaostoolkit-istio

<br>

We make use of istio service mesh since it is the most widely used service mesh. Istio also provides several other features such as Monitoring, tracing, circuit breakers, routing, load balancing, fault injection, retries, timeouts, mirroring, access control, rate limiting, etc. Setup [cluster](../../cluster-setup-multiprovider/) and install istio from [here](../../cluster-setup-multiprovider/istio.sh).

### Running the Experiment to Discover the Weaknesses

Once you have the prerequisites in place you can deploy the application as follows:

```shell
$ kubectl create ns go-app
$ kubectl label namespace go-app istio-injection=enabled
$ kubectl -n go-app apply --filename app
$ kubectl -n go-app rollout status deployment go-app
$ curl -H "Host: go-app.acme.com" "http://$INGRESS_HOST"
``` 

Assuming, we have a multinode cluster. Otherwise, like experiment 6 scale the cluster using the commands [here](../../cluster-setup-multiprovider/scale-cluster.sh) or use the scripts `*.-regional-scalable.sh` in the [multi-provider](../../cluster-setup-multiprovider) setup.


```shell
# label of the targetNode
export NODE_LABEL="beta.kubernetes.io/os=linux"
```

<br>

Checkout the traces and service performance through [Observability](../../../../../wiki/Observability)(Jaeger and grafana).
<br>

To run the experiment use the Chaos Toolkit CLI:

```shell
(venv) $ chaos run node-delete.yaml
```



```shell
$ chaos --log-file=experiment.log run experiment.json 
[2022-06-17 17:28:32 INFO] Validating the experiment's syntax
[2022-06-17 17:28:32 INFO] Experiment looks valid
[2022-06-17 17:28:32 INFO] Running experiment: What happens if we delete a node
[2022-06-17 17:28:32 INFO] Steady state hypothesis: Nodes are indestructible
[2022-06-17 17:28:32 INFO] Probe: all-apps-are-healthy
[2022-06-17 17:28:32 INFO] Steady state hypothesis is met!
[2022-06-17 17:28:32 INFO] Action: delete-node
[2022-06-17 17:28:32 INFO] Pausing after activity for 10s...
[2022-06-17 17:28:42 INFO] Steady state hypothesis: Nodes are indestructible
[2022-06-17 17:28:42 INFO] Probe: all-apps-are-healthy
[2022-06-17 17:28:42 ERROR]   => failed: chaoslib.exceptions.ActivityFailed: the system is unhealthy
[2022-06-17 17:28:42 WARNING] Probe terminated unexpectedly, so its tolerance could not be validated
[2022-06-17 17:28:43 CRITICAL] Steady state probe 'all-apps-are-healthy' is not in the given t... this experiment
[2022-06-17 17:28:43 INFO] Let's rollback...
[2022-06-17 17:28:43 INFO] No declared rollbacks, let's move on.
[2022-06-17 17:28:43 INFO] Experiment ended with status: deviated
[2022-06-17 17:28:43 INFO] The steady-state has deviated, a weakness may have been discovered

```

**Learning:** The initial steady-state hypothesis was met, and the action to delete a node was executed. Then we were waiting for 10 seconds, and after that, the node was destroyed. The post-action steady-state hypothesis was unsuccessful, so we can conclude that our applications running in go-app Namespace are not functioning. There are other problems, such as the possibility that additional replicas might be running on the node that went rogue.

It might be the case that the above experiment turns out to be successful. The output depends upon the application and cluster setup. In the above scenario, upon inspecting the pods, it turns out that the db instance was lost and caused issues. As in experiment 2 db chart needs to be installed with multiple primary and secondary replicas.

<br>
Checkout `chaostoolkit.log` for more detailed logs.

### Making the application deployments spread over regions.

First of all, we should have created our Kubernetes cluster with **Cluster Autoscaler** so that it automatically scales up and down depending on the traffic. Not only would our cluster scale up and down to accommodate an increase and decrease in the workload, but when a node goes down, it would be recreated by Cluster Autoscaler. The cluster would also figure out that there is not enough capacity. Cluster Autoscaler itself would solve fully (or partly) the problems that we could have encountered if we continued running the previous experiment and continued deleting nodes.

The second issue is that we are running a zonal cluster i.e, it is not fault-tolerant. If that zone (data center) goes down, we’d be lost. So, the second change we should have done to our cluster is to make it regional. It should span multiple zones within the same region. It shouldn’t run in different regions because that would increase latency unnecessarily. Every cloud provider, at least the big three, has a concept of a region, even though it might be named differently. By region implies a group of zones (data centers) that are close enough to each other so that there is no high latency, while they still operate as entirely separate entities. Failure of one should not affect the other. At least, that’s how it should be in theory.

### Making a regional cluster
Therefore, we should make our cluster regional, and we should make it scalable. Please consult before using the scripts for Kubernetes cluster in Google, Azure, or AWS.
- [Regional and scalable GKE](../../cluster-setup-multiprovider/gke-regional-scalable.sh)
- [Regional and scalable EKS](../../cluster-setup-multiprovider/eks-regional-scalable.sh)
- [Regional and scalable AKS](../../cluster-setup-multiprovider/aks-regional-scalable.sh)


