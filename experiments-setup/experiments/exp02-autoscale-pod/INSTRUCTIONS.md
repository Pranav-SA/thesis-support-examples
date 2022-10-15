## "Impact of Pod loss on application availability - scalability check" Chaos Experiment

This sample experiment demonstrates whether the loss of instance of an application or its dependencies impact **SLI** and further SLO. Looped implementation of experiment allows you to define the expected downtime upon a crucial instance loss.
Measured metrics such as mean time to recover can be used to adjust values in HPAs for instances for autoscaling.<br>
*Adapt as per need*

### Prerequisites

To run this you will need the [Chaos Toolkit CLI][chaos-toolkit] >= 0.3.0
installed and have access to a Kubernetes cluster. Checkout Wiki for set up instructions.<br>
*Assuming resources from previous experiments were destroyed*<br>

```shell
(venv) $ pip install -U chaostoolkit
```

[chaos-toolkit]: https://github.com/chaostoolkit/chaostoolkit
[minikube]: https://kubernetes.io/docs/getting-started-guides/minikube/

You will also need to install the [chaostoolkit-kubernetes][chaosk8s] extension:

```shell
(venv) $ pip install -U chaostoolkit-kubernetes
```

[chaosk8s]: https://github.com/chaostoolkit/chaostoolkit-kubernetes

<br>

For availability check we also make use of ingress (can be a LB endpoint or mesh endpoint, presumed). Check instructions for setup [here](../../cluster-setup-multiprovider/ingress.sh).

### Running the Experiment to Discover the Weaknesses

Once you have the prerequisites in place you can deploy the application as follows:

```shell
$ kubectl create ns go-app
$ kubectl -n go-app apply --filename app
$ kubectl -n go-app get ingress
$ kubectl -n go-app apply --filename ingress.yaml
$ curl -H "Host: go-app.acme.com" "http://$INGRESS_HOST" #test the endpoint from where execution is scheduled i.e, vm or user machine. Append JWT in header if needed for mTLS.
``` 

To run the experiment use the Chaos Toolkit CLI:

```shell
(venv) $ chaos run experiment-app.yaml
```

The experiment will highlight a weakness, app is unable to recover from loss of a pod.
shown in the following experiment sample output:

```shell
$ chaos --log-file=experiment-app.log run experiment-app.json 
[2022-06-30 15:36:20 INFO] Validating the experiment's syntax
[2022-06-30 15:36:21 INFO] Experiment looks valid
[2022-06-30 15:36:21 INFO] Running experiment: What happens if we terminate an instance of the application?
[2022-06-30 15:36:21 INFO] Steady-state strategy: default
[2022-06-30 15:36:21 INFO] Rollbacks strategy: default
[2022-06-30 15:36:21 INFO] Probe: app-responds-to-requests
[2022-06-30 15:36:21 INFO] Steady state hypothesis is met!
[2022-06-30 15:36:21 INFO] Playing your experiment's method now...
[2022-06-30 15:36:21 INFO] Action: terminate-app-pod
[2022-06-30 15:36:21 INFO] Pausing after activity for 2s...
[2022-06-30 15:36:23 INFO] Steady state hypothesis: The app is healthy
[2022-06-30 15:36:23 INFO] Probe: app-responds-to-requests
[2022-06-30 15:36:23 CRITICAL] Steady state probe 'app-responds-to-requests' is not in the given tolerance so failing this experiment
[2022-06-30 15:36:23 INFO] Experiment ended with status: deviated
[2022-06-30 15:36:24 INFO] The steady-state has deviated, a weakness may have been discovered
```

*Similar results with db loss, use [experiment-db.yaml](./experiment-db.yaml) with stateful configuration.*

**Learning:** The application is not highly available. It does not continue serving requests after a Pod, or an instance is destroyed because there is only one instance. Every application, when architecture allows, should run multiple instances as a way to prevent this type of situation. If, for example, we would have three instances of our application and we’d destroy one of them, the other two should be able to continue serving requests while Kubernetes is recreating the failed Pod. In other words, we need to increase the number of replicas of our application.
We could scale up in quite a few ways. We could just go to the definition of the Deployment and say that there should be two or three or four replicas of that application. But that’s a bad idea. That’s static. That would mean that if we say three replicas, then our app would always have three replicas. What we want is for our application to go up and down. It should increase and decrease the number of instances depending on their memory or CPU utilization. We could even define more complicated criteria based on Prometheus or other node exporter metrics.


### Running the Experiment to Gain Confidence that the Weaknesses have been Overcome

Deploy this new, improved system and re-run the experiment
```shell
$ kubectl -n go-app apply -f hpa.yaml
```

Now the experiment should complete successfully and report general system
steady-state health according to the experiment's probes.
<br>
That definition specifies a HorizontalPodAutoscaler called go-app. It is targeting the Deployment with the same name go-app. The minimum number of replicas will be 2, and the maximum number will be 6. Our application will have anything between two and six instances. The exact number depends on the metrics.
In this case, we have two basic metrics. The average utilization of CPU should be around 80%, and the average usage of memory should be 80% as well. In most “real-world” cases, those two metrics would be insufficient and should be used along with `requests per second` or with golden metrics. Nevertheless, they are sufficient here.
All in all, that HPA will make our application run at least two replicas. That should hopefully make it highly available. If you’re unsure about the validity of that statement, try to guess what happens if we destroy one or multiple replicas of an application. The others should continue serving requests. For DB instance both primary and secondary instance replication can be set to more than one in helm values and associated with an HPA.