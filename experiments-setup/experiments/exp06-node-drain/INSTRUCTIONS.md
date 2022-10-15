## "Impact of node drain on application availability" Chaos Experiment

Unlike other experiments, this chaos experiment cannot be run targeting the nodes of cluster on Minikube or Docker Desktop. If we drain or delete a node and that node is the only one in our cluster, then control plane of cluster may get affected. In a cluster like Azure, Google, AWS, DigitalOcean, or even on-prem, this shouldn’t be a problem since we’d have multiple nodes, and we can scale our cluster up and down. K3d allows multinode simulation using agents and servers. For performing the described experiment on k3d, we need to target the servers or worker nodes specifically.

Do NOT use a real production cluster.
Below can be very destructive. You might not be able to recuperate from the mayhem. So, make sure that the cluster is disposable.


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

*We’re going to try to drain everything from a random worker node.*

**Why we might want to do something like this?** One possible reason for doing that is in upgrades. The draining process is the same as the one we use to upgrade our Kubernetes cluster.
Upgrading a Kubernetes cluster usually involves a few steps. Typically, we’d drain a node, we’d shut it down, and we’d replace it with an upgraded version of the node. Alternatively, we might upgrade a node without shutting it down, but that would be more appropriate for bare-metal servers that cannot be destroyed and created at will. Further on, we’d repeat the steps. We’d drain a node, shut it down, and create a new one based on an upgraded version. This would continue over and over again, one node after another, until the whole cluster is upgraded. The process is often called rolling updates (or rolling upgrades), and it is employed by most Kubernetes distributions.
We want to make sure nothing wrong happens while or after upgrading a cluster. To do that, we design an experiment that would perform the most critical step of the process. It will drain a random node, and we will validate whether our applications are just as healthy as before.

```shell
# label of the targetNode
export NODE_LABEL="beta.kubernetes.io/os=linux"
```

<br>

Checkout the traces and service performance through [Observability](../../../../../wiki/Observability)(Jaeger and grafana).
<br>

To run the experiment use the Chaos Toolkit CLI:

```shell
(venv) $ chaos run node-drain.yaml
```

The action has a couple of arguments. There is the label_selector set to the value of the variable ${node_label}. To depict the system which nodes are eligible for draining. Even though all nodes are the same most of the time, that might not always be the case. Through that argument, we can select which nodes are eligible and which are not.
Further on, we have the count argument set to 1, meaning that only one node will be drained.
There is also pod_namespace. This one might sound weird since we are not draining any Pods. We are draining nodes. Even though it might not be self-evident, this argument is instrumental. It tells the action to select a random node among the ones that have at least one Pod running in that Namespace. So, it will choose a random node among those where Pods inside the go-app Namespace are running. That way, we can check what happens to the applications in that Namespace when one of the servers they are running is gone.
Finally, we pause for one second. That should be enough for us to validate whether applications are healthy soon after one of the nodes is drained.

```shell
$ chaos --log-file=experiment.log run experiment.json 
[2022-06-16 16:22:28 INFO] Validating the experiment's syntax
[2022-06-16 16:22:28 INFO] Experiment looks valid
[2022-06-16 16:22:28 INFO] Running experiment: What happens if we drain a node
[2022-06-16 16:22:28 INFO] Steady state hypothesis: Nodes are indestructible
[2022-06-16 16:22:28 INFO] Probe: all-apps-are-healthy
[2022-06-16 16:22:28 INFO] Steady state hypothesis is met!
[2022-06-16 16:22:28 INFO] Action: drain-node
[2022-06-16 16:22:28 ERROR]   => failed: chaoslib.exceptions.ActivityFailed: Failed to evict pod istio-ingressgateway-8577f4c6f8-xwcpb: {"kind":"Status","apiVersion":"v1","metadata":{},"status":"Failure","message":"Cannot evict pod as it would violate the pod's disruption budget.","reason":"TooManyRequests","details":{"causes":[{"reason":"DisruptionBudget","message":"The disruption budget ingressgateway needs 1 healthy pods and has 1 currently"}]},"code":429}
[2022-06-16 16:22:28 INFO] Pausing after activity for 1s...
[2022-06-16 16:22:29 INFO] Steady state hypothesis: Nodes are indestructible
[2022-06-16 16:22:29 INFO] Probe: all-apps-are-healthy
[2022-06-16 16:22:29 ERROR]   => failed: chaoslib.exceptions.ActivityFailed: the system is unhealthy
[2022-06-16 16:22:29 WARNING] Probe terminated unexpectedly, so its tolerance could not be validated
[2022-06-16 16:22:29 CRITICAL] Steady state probe 'all-apps-are-healthy' is not in the given t... this experiment
[2022-06-16 16:22:30 INFO] Let's rollback...
[2022-06-16 16:22:30 INFO] No declared rollbacks, let's move on.
[2022-06-16 16:22:30 INFO] Experiment ended with status: deviated
[2022-06-16 16:22:30 INFO] The steady-state has deviated, a weakness may have been discovered

```

**Learning:** It tried to drain a node, and it failed miserably.
Experiment attempted to drain a node hoping to see what effect that produces on the applications in the go-app Namespace. However, instead got an error stating that the node cannot be drained at all. It could not match the disruption budget of the istio-ingressgateway.
The Gateway is configured to have a disruption budget of 1. That means that there must be at least one Pod running at any given moment. Cluster has a single replica of the Gateway.
All in all, the Gateway, in its current form, has one replica. However, it has the disruption budget that prevents the system from removing a replica without guaranteeing that at least one Pod is always running. This is a good thing. Istio’s design decision is correct because the Gateway should be running at any given moment. Istio component should scale to at least 2 or more replicas. Also, (assumed) we are running a single-node cluster. Or, to be more precise, if instructions from one of the previous experiments are used, then it might be a single-node cluster. It will do no good to scale Istio components to multiple replicas if they’re all going to run on that single node. That would result in precisely the same failure. The system could not drain the node because that would mean that all the replicas of the Istio components would need to be shut down, and they are configured with the disruption budget of 1.

<br>

Checkout `chaostoolkit.log` for more detailed logs.
Make sure that rollback succeeded and node can schedule again. Otherwise, uncordon the node.

### Running the Experiment to Gain Confidence that the Weaknesses have been Overcome

It would be pointless to increase the number of replicas of Istio components, as a way to solve the problem of not being able to drain a node, if that is the only node in a cluster. We need the Gateway not only scaled but also distributed across different nodes of the cluster. Only then can we hope to drain a node successfully while the Gateway is running in it. Assuming that the experiment might shut down one replica, while others are still running somewhere else. Fortunately, Kubernetes always does its best to distribute instances of our apps across different nodes. As long as it can, it will not run multiple replicas on a single node.
So, our first action is to scale our cluster. However, scaling a cluster is not the same everywhere. Therefore, the commands to scale the cluster will differ depending on where you’re running it.

Scale the cluster using the commands [here](../../cluster-setup-multiprovider/scale-cluster.sh) or use the scripts `*.-regional-scalable.sh` in the [multi-provider](../../cluster-setup-multiprovider) setup.

<br>
Scale istio-system and gateway

```shell
$ kubectl --namespace istio-system get hpa
$ kubectl --namespace istio-system patch hpa istio-ingressgateway --patch '{"spec": {"minReplicas": 2}}
$ kubectl --namespace istio-system get hpa
$ kubectl --namespace istio-system get pods --output wide
```
Observe that istio-ingressgateway now has the minimum and the actual number of Pods set to 2. If, the number of replicas is still 1, the second Pod is still not up and running. If that’s the case, wait for a few moments and repeat the command that retrieves all the HPAs. For istio-ingressgateway Pods, observe that they are running on different nodes. A quick glance depicts that they’re all distributed across the cluster with each of its replicas running on different servers.
<br>
Now the running the experiment should complete successfully and report general system
steady-state health according to the experiment's probes. <br>
