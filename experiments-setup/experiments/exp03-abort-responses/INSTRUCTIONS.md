## "Impact on dependent application upon loss of responses" Chaos Experiment

Networking issues are very common. They happen more often than many people think.<br>
So, what can we do?
We’re going to terminate requests and see how our application behaves when that happens. We’re not going to abort all the requests, but only some. Terminating 50% of requests should do.
What happens if 50% of the requests coming to our applications are terminated? Is our application resilient enough to survive without negatively affecting users?


### Prerequisites

To run this you will need the [Chaos Toolkit CLI][chaos-toolkit] >= 0.3.0
installed and have access to a Kubernetes cluster. Checkout Wiki for set up instructions.<br>
*Assuming resources from previous experiments were destroyed*<br>

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

The experiment comprises of an action with 50 percentage abort rate. It also probes 200 response 5 times so that fail and success, both can be observed. We will be sending requests to the repeater, but we will be aborting those requests on the go-app API. That’s why we added an additional application. Since the repeater forwards requests to go-app, we will be able to see what happens when we interact with one application that interacts with another while there is a cut in that communication between the two.

```shell
$ chaos --log-file=network.log run network.json 
[2022-06-30 18:28:20 INFO] Validating the experiment's syntax
[2022-06-30 18:28:21 INFO] Experiment looks valid
[2022-06-30 18:28:21 INFO] Running experiment: What happens if we abort responses
[2022-06-30 18:28:21 INFO] Steady-state strategy: default
[2022-06-30 18:28:21 INFO] Rollbacks strategy: default
[2022-06-30 18:28:21 INFO] Probe: app-responds-to-requests
[2022-06-30 18:28:21 INFO] Probe: app-responds-to-requests
[2022-06-30 18:28:21 INFO] Probe: app-responds-to-requests
[2022-06-30 18:28:21 INFO] Probe: app-responds-to-requests
[2022-06-30 18:28:21 INFO] Probe: app-responds-to-requests
[2022-06-30 18:28:21 INFO] Steady state hypothesis is met!
[2022-06-30 18:28:21 INFO] Playing your experiment's method now...
[2022-06-30 18:28:21 INFO] Action: abort-failure
[2022-06-30 18:28:21 INFO] Pausing after activity for 1s...
[2022-06-30 18:28:22 INFO] Steady state hypothesis: The app is healthy
[2022-06-30 18:28:22 INFO] Probe: app-responds-to-requests
[2022-06-30 18:28:22 CRITICAL] Steady state probe 'app-responds-to-requests' is not in the given tolerance so failing this experiment
[2022-06-30 18:28:22 INFO] Experiment ended with status: deviated
[2022-06-30 18:28:22 INFO] The steady-state has deviated, a weakness may have been discovered
```

After the experiment check if the rollback fixed the configuration `
kubectl --namespace go-app describe virtualservice go-app` otherwise apply virtual service configuration again.<br>

Curl to observe output. An output of `fault filter abort` indicates that experiment hasn't rolled back.
```shell
for i in {1..10}; do 
  curl -H "Host: repeater.acme.com" "http://$INGRESS_HOST?addr=http://go-app"
done
```

**Learning:** We can see that some of the requests returned fault filter abort. Those requests are the 50% that were aborted. Now, don’t take 50% seriously because other requests are happening inside the cluster, and the number of those that failed in that output might not be exactly half. Think of it as approximately 50%.
The experiment showed that our application cannot deal with network abortions. If a request is terminated (and that is inevitable), app does not know how to deal with it. The last experiment will not create a complete outage but only partial network failures. We can fix this in quite a few ways. We can either do this at application level using two way requests or look for a solution outside the application itself, probably inside Kubernetes or Istio.


### Running the Experiment to Gain Confidence that the Weaknesses have been Overcome

Istio Virtual Service can be set to retry requests up to 10 times. If a request fails, it will be retried. If it fails again, it will be retried again, and again, and again. The timeout is set to 3 seconds, and retryOn is set to 5xx. That’s telling Istio that it should retry failed requests up to 10 times with a timeout of 3 seconds. It should retry them only if the response code is in the 500 range. If any of the 500 range response codes are received, Istio will repeat a request.
Other error codes can also be supported by [envoy](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter#x-envoy-retry-on).
<br>
Deploy this new, improved system and re-run the experiment
```shell
$ kubectl -n go-app apply -f istio-repeater.yaml
```

Now the running the experiment should complete successfully and report general system
steady-state health according to the experiment's probes.
<br>
Upon successful run, we observe that the five initial probes are executed successfully and that the action injected abort failure set to 50%. After that, the same probes re-run, and we see that this time, all are successful. Application is indeed retrying failed requests up to ten times. Since approximately 50% of them fail, up to ten repetitions are more than sufficient.
Everything is working. Our experiment is successful, and we can conclude that the repeater can handle partial network outages.
Sometimes the network does not fail, and requests do not immediately return 500 response codes.
