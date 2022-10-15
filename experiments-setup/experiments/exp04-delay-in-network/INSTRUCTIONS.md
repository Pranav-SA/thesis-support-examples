## "Impact on application due to lag in the network" Chaos Experiment

Networking issues are very common. They happen more often than many people think.<br>
So, what can we do?
We saw in experiment three how we can deal with network failures. To be more precise, we saw one possible way to simulate network failures and one way to solve the adverse outcomes it produces. However, it’s not always going to be that easy. Sometimes the network does not fail, and requests do not immediately return 500 response codes. Sometimes there is a delay. Our applications might wait for responses for milliseconds, seconds, or even longer. How can we deal with that?
What happens if we introduce a delay to requests’ responses. Is our application, in its current state, capable of handling this well and without affecting end users?


### Prerequisites

To run this you will need the [Chaos Toolkit CLI][chaos-toolkit] >= 0.3.0
installed and have access to a Kubernetes cluster. Checkout Wiki for set up instructions.<br>
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

We make use of istio service mesh since it is the most widely used service mesh. Istio also provides several other features such as Monitoring, tracing, circuit breakers, routing, load balancing, fault injection, retries, timeouts, mirroring, access control, rate limiting, etc. Install istio from [here](../../cluster-setup-multiprovider/istio.sh).

### Running the Experiment to Discover the Weaknesses

Once you have the prerequisites in place you can deploy the application as follows:

```shell
$ kubectl create ns go-app
$ kubectl label namespace go-app istio-injection=enabled
$ kubectl -n go-app apply --filename app
$ kubectl -n go-app rollout status deployment go-app
$ kubectl -n go-app apply --filename istio.yaml
``` 

We have a Virtual Service called go-app that will allow internal traffic to our application. We can see that we have the host set to go-app (the name of the Service associated with the app). The destination is also set to the same host, and the subset is set to primary. Typically, we would have primary (and secondary) subsets if we’d use Canary Deployments. But, in this case, we are not going to do that. In any case, we are going to define only the primary subset as being the only one since we won’t have canary deployments this time. Finally, the port is set to 80. That is the port through which network requests will be coming to this Virtual Service.
Then we have the DestinationRule resource, which is pretty straightforward. It is called go-app, the host is also go-app. It points to the primary subset, which will forward all the requests to go-app Pods that have the label release set to primary.
Let’s apply that definition before we see what else we might need.<br>

```shell
$ kubectl -n go-app apply --filename repeater
$ kubectl -n go-app rollout status deployment repeater
$ curl -H "Host: repeater.acme.com" "http://$INGRESS_HOST?addr=http://go-app"
``` 

Next, we’re introducing a new (third) application, besides the API and the DB. For us to do chaos to networking, we will need an additional app so that we can, for example, do some damage to the networking of the API and see how that new application connected to it works.
The repeater is a very simple application. All it does is forward requests coming into it to the specified address. So, for example, if we send a request to the repeater, and we specify that we would like it to forward that request to go-app, that’s where it will go. It is intentionally very simple because the objective is to see how multiple applications collaborate together through networking and what happens when we do some damage to the network.
<br>

Checkout the traces and service graph through [Observability](https://github.com/Pranav-SA/thesis-support-examples/wiki/Observability) setup (Jaeger and Kiali).
<br>
To run the experiment use the Chaos Toolkit CLI:

```shell
(venv) $ chaos run network.yaml
```

The action uses the function add_delay_fault, and the arguments are very similar to what we had before. It introduces a fixed delay of 15 seconds. So, when a request comes to this Virtual Service, it will be delayed for 15 seconds. Because the delay of 15 seconds plus whatever number of milliseconds the request itself takes is more than the timeout, our probe might fail. The vital thing to note is that the delay is applied only to 50 percent of the requests.
Then, we have a rollback action to remove that same delay.


```shell
$ chaos --log-file=network.log run network.json 
[2022-07-01 23:45:33 INFO] Validating the experiment's syntax
[2022-07-01 23:45:33 INFO] Experiment looks valid
[2022-07-01 23:45:33 INFO] Running experiment: What happens if we abort and delay responses
[2022-07-01 23:45:34 INFO] Steady state hypothesis: The app is healthy
[2022-07-01 23:45:34 INFO] Probe: app-responds-to-requests
[2022-07-01 23:45:34 INFO] Probe: app-responds-to-requests
[2022-07-01 23:45:34 INFO] Probe: app-responds-to-requests
[2022-07-01 23:45:34 INFO] Probe: app-responds-to-requests
[2022-07-01 23:45:34 INFO] Probe: app-responds-to-requests
[2022-07-01 23:45:34 INFO] Steady state hypothesis is met!
[2022-07-01 23:45:34 INFO] Action: abort-failure
[2022-07-01 23:45:34 INFO] Action: delay
[2022-07-01 23:45:34 INFO] Pausing after activity for 1s...
[2022-07-01 23:45:35 INFO] Steady state hypothesis: The app is healthy
[2022-07-01 23:45:35 INFO] Probe: app-responds-to-requests
[2022-07-01 23:45:35 INFO] Probe: app-responds-to-requests
[2022-07-01 23:45:35 INFO] Probe: app-responds-to-requests
[2022-07-01 23:45:35 INFO] Probe: app-responds-to-requests
[2022-07-01 23:45:50 ERROR]   => failed: activity took too long to complete
[2022-07-01 23:45:50 WARNING] Probe terminated unexpectedly, so its tolerance could not be validated
[2022-07-01 23:45:50 CRITICAL] Steady state probe 'app-responds-to-requests' is not in the given tolerance so failing this experiment
[2022-07-01 23:45:50 INFO] Let's rollback...
[2022-07-01 23:45:50 INFO] Rollback: remove-abort-failure
[2022-07-01 23:45:50 INFO] Action: remove-abort-failure
[2022-07-01 23:45:50 INFO] Rollback: remove-delay
[2022-07-01 23:45:50 INFO] Action: remove-delay
[2022-07-01 23:45:50 INFO] Experiment ended with status: deviated
[2022-07-01 23:45:50 INFO] The steady-state has deviated, a weakness may have been discovered

```

After the experiment check if the rollback fixed the configuration `
kubectl --namespace go-app describe virtualservice go-app` otherwise apply virtual service configuration again.<br>

Curl to observe output. An output of `fault filter abort` indicates that experiment hasn't rolled back.
```shell
for i in {1..10}; do 
  curl -H "Host: repeater.acme.com" "http://$INGRESS_HOST?addr=http://go-app"
done
```

**Learning:** The message activity took too long to complete should be self-explanatory. If we focus on the timestamp of the failed probe, we can see that there is precisely a 15 seconds difference from the previous experiment. In above case, the last successful probe started at 35 seconds, and then it failed at 50 seconds. The request was sent, and given that it has a timeout of 15 seconds, that’s how much it waited for the response.
We can conclude that application does not know how to cope with delays. What could be the fix for that?


### Running the Experiment to Gain Confidence that the Weaknesses have been Overcome

We have the retries section with attempts set to 10 and with perTryTimeout set to 2 seconds. In addition, we now have connect-failure added to the retryOn values.
We are going to retry this ten times with a 2 second time out. We’ll do that not only if we have response codes in the five hundred range (5xx), but also when we have connection failures (connect-failure). That 2 seconds timeout is crucial in this case. If we send the request and it happens to be delayed, Istio Virtual Service will wait for 2 seconds, even though the delay is 15 seconds. It will abort that request after 2 seconds, and it will try again, and again, and again until it is successful, or until it does it for 10 times. The total timeout is 10 seconds, so it might fail faster than that. It all depends on whether the timeout is reached first or the number of attempts.

<br>

Deploy this new, improved system and re-run the experiment

```shell
$ kubectl -n go-app apply -f istio-delay.yaml
(venv) $ chaos run network.yaml
```

Now the running the experiment should complete successfully and report general system
steady-state health according to the experiment's probes.
<br>

```shell
[2022-07-01 23:46:30 INFO] Validating the experiment's syntax
[2022-07-01 23:46:30 INFO] Experiment looks valid
[2022-07-01 23:46:30 INFO] Running experiment: What happens if we abort and delay responses
[2022-07-01 23:46:30 INFO] Steady state hypothesis: The app is healthy
[2022-07-01 23:46:30 INFO] Probe: app-responds-to-requests
[2022-07-01 23:46:30 INFO] Probe: app-responds-to-requests
[2022-07-01 23:46:30 INFO] Probe: app-responds-to-requests
[2022-07-01 23:46:30 INFO] Probe: app-responds-to-requests
[2022-07-01 23:46:30 INFO] Probe: app-responds-to-requests
[2022-07-01 23:46:30 INFO] Steady state hypothesis is met!
[2022-07-01 23:46:30 INFO] Action: abort-failure
[20-03-13 23:46:31 INFO] Action: delay
[2022-07-01 23:46:31 INFO] Pausing after activity for 1s...
[2022-07-01 23:46:32 INFO] Steady state hypothesis: The app is healthy
[2022-07-01 23:46:32 INFO] Probe: app-responds-to-requests
[2022-07-01 23:46:38 INFO] Probe: app-responds-to-requests
[2022-07-01 23:46:44 INFO] Probe: app-responds-to-requests
[2022-07-01 23:46:46 INFO] Probe: app-responds-to-requests
[2022-07-01 23:46:48 INFO] Probe: app-responds-to-requests
[2022-07-01 23:46:54 INFO] Steady state hypothesis is met!
[2022-07-01 23:46:54 INFO] Let's rollback...
[2022-07-01 23:46:54 INFO] Rollback: remove-abort-failure
[2022-07-01 23:46:54 INFO] Action: remove-abort-failure
[2022-07-01 23:46:54 INFO] Rollback: remove-delay
[2022-07-01 23:46:54 INFO] Action: remove-delay
[2022-07-01 23:46:54 INFO] Experiment ended with status: completed

```

If we focus on the timestamps from the first and the second post-action probe, we can see that the first one took around six seconds. There were probably some delays. Maybe there was one delay and one network abort. Or, there could be some other combination. What matters is that it managed to respond within 6 seconds. In my case, the second request also took around 6 seconds. Therefore, we can guess that there were problems and that they were resolved. The rest of the probes were also successful even though they required varied durion to finish.
The responses to some, if not all the probes, took longer than usual. Nevertheless, they were all successful. Our application, in above case, managed to survive delays and abort failures.

### What happens if complete network is down?
Experiment file can be found [here](./network-100.yaml).

In this scenario, assuming that we have other processes in place that deal with infrastructure when the network completely fails, it will be recuperated at one moment. We cannot expect Kubernetes and Istio and software around our applications to fix all of the problems. This is the case where the design of our applications should be able to handle it.
Let’s say that your frontend application is accessible, but that the backend is not. If, for example, your frontend application cannot, under any circumstance, communicate with the backend application, it should probably show a message like “shopping cart is currently not available, but feel free to browse our products” because they go to different backend applications. That’s why we like microservices. The smaller the applications are, the smaller the scope of an issue. Maybe your frontend application is not accessible, and then you would serve your users some static version of your frontend. 
There can be many different scenarios. Similarly, there are many things that we can do to limit the blast radius. 