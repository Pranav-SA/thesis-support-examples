## "Denial of Service attack on the application instances" Chaos Experiment

Another scenario that could happen is that we might be under attack. Somebody, intentionally or unintentionally, might be creating a Denial of Service attack (DoS attack). What that really is that our applications, or even the whole cluster, might be under an extreme load. It might be receiving such a vast amount of traffic that our infrastructure cannot handle it. Although uncommon, it is not unheard of for a whole system to collapse when under a DoS attack. It is likely that a system will collapse if we don’t undertake some precautionary measures.
To do so we're goind to use seige. On a lower scale of our cluster, without actually putting it to harm, we simulate the same on a part of the application which is designed in a way that it can handle very few requests.


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

We make use of istio service mesh since it is the most widely used service mesh. Istio also provides several other features such as Monitoring, tracing, circuit breakers, routing, load balancing, fault injection, retries, timeouts, mirroring, access control, rate limiting, etc. Install istio from [here](../../cluster-setup-multiprovider/istio.sh).

### Running the Experiment to Discover the Weaknesses

Once you have the prerequisites in place you can deploy the application as follows:

```shell
$ kubectl create ns go-app
$ kubectl label namespace go-app istio-injection=enabled
$ kubectl -n go-app apply --filename app
$ kubectl -n go-app rollout status deployment go-app
$ kubectl -n go-app apply --filename istio.yaml
$ kubectl -n go-app apply --filename repeater
$ kubectl -n go-app rollout status deployment repeater
$ curl -H "Host: repeater.acme.com" "http://$INGRESS_HOST?addr=http://go-app"
``` 

Application setup is just like before in 3rd and 4th. Whats new is the use of limiter in [code](../../sample-applications/go-app/main.go). We’re going to simulate Denial of Service attacks. For that, the application uses a Go library called rate. Further on, we have the limiter variable set to a NewLimiter(5, 10). That means that it limits the application to have only five requests, with a burst of ten. Real application are usually not designed like that. However, we’re using it to simulate what happens if the number of requests is above the limit of what the application can handle. There are always limits to any application; we’re just forcing this one’s threshold to be very low.
Our applications should scale up and down automatically. But if we have a sudden drastic increase in the number of requests, that might produce some adverse effects. The application might not be able to scale up that fast.
Then, we have the LimiterServer function, which handles requests coming to the /limiter endpoint. It checks whether we reached the five requests limit. If so, it sends 500 response codes. There is also the additional logic that blocks all other requests for fifteen seconds after the limit is reached.
All in all, we’re simulating the situation where our application reached the limit of what it can handle. If it reaches that limit, it becomes unavailable for 15 seconds. It’s a simple code that simulates what happens when an application starts receiving significantly more traffic than it can handle. If a replica of this app receives more than five simultaneous requests, it will be unavailable for fifteen seconds. That’s (roughly) what would happen with requests when the application is under Denial of Service attacks.

<br>

Checkout the traces and service graph through [Observability](../../../../wiki/Observability) setup (Jaeger and Kiali).
<br>

>> **Optional:** We can run the image we use in experiment directly to observe the output at `/` or `/limiter` to observe the difference `kubectl --namespace go-app
    run siege
    --image yokogawa/siege --generator run-pod/v1 -i -t --rm -- --concurrent 50 --time 20S "http://go-app/limiter"` <br> We created a Pod called siege in the go-demo-8 Namespace. It is based on the image yokogawa/siege. We used the -it argument (interactive, terminal), and we used --rm so that the Pod is deleted after the process is the only container inside that Pod is terminated. All those are uneventful. The interesting part of that command is the arguments we passed to the main process in the container. The --concurrent=50 and --time 20S argument tells Siege to run fifty concurrent requests for 20 seconds. The last argument is the address where Siege should be sending requests.

| `http://go-app/`    | `http://go-app/limiter` |
| -------------- | --------------------|
| Transactions:             1676 hits | Transactions:             1845 hits          |
| Availability:            91.94 % | Availability:            92.02 %          |
|Elapsed time:            19.21 secs | Elapsed time:            19.70 secs          |
| Data transferred:         0.05 MB | Data transferred:         0.04 MB          |
| Response time:            0.01 secs | Response time:            0.01 secs          |
| Transaction rate:        87.25 trans/sec | Transaction rate:        93.65 trans/sec          |
| Throughput:               0.00 MB/sec| Throughput:               0.00 MB/sec          |
| Concurrency:              1.07 | Concurrency:              1.12          |
| Successful transactions:  1676| Successful transactions:    20          |
| Failed transactions:       147| Failed transactions:       160         |
| Longest transaction:      0.08 | Longest transaction:      0.09          |
| Shortest transaction:     0.00 | Shortest transaction:     0.00          |

We can see that this time, the number of successful transactions is 20. It’s not only the five successful transactions you would expect because we have multiple replicas of this application. However, the exact number doesn’t matter. What is important is that we can see that the number of successful transactions is much lower than before. In my case, that’s only 20. As a comparison, the first execution of the siege produced, in my case, 1676 successful transactions.
<br>


To run the experiment use the Chaos Toolkit CLI:

```shell
(venv) $ chaos run network.yaml --rollback-strategy=always
```

We have a steady-state hypothesis, which validates that our application does respond with 200 on the endpoint /limiter. Then, we have an action with the type of the provider set to process. 
The **process provider** allows us to execute any command. This is very useful in cases when none of the Chaos Toolkit plugins will enable us to do what we need.
We can always accomplish goals that are not available through plugins by using the process provider, which can execute any command. It could be a script, a shell command, or anything else, as long as it is executable. In this case, the path is kubectl (a command) followed by a list of arguments. Those are the same we just executed manually. We’ll be sending fifty concurrent requests for 20 seconds to the /limiter endpoint.


```shell
$ chaos --log-file=experiment.log run experiment.json 
[2022-07-02 23:51:28 INFO] Validating the experiment's syntax
[2022-07-02 23:51:28 INFO] Experiment looks valid
[2022-07-02 23:51:28 INFO] Running experiment: What happens if we abort responses (DOS)
[2022-07-02 23:51:28 INFO] Steady state hypothesis: The app is healthy
[2022-07-02 23:51:28 INFO] Probe: app-responds-to-requests
[2022-07-02 23:51:28 INFO] Steady state hypothesis is met!
[2022-07-02 23:51:28 INFO] Action: abort-failure
[2022-07-02 23:51:52 INFO] Pausing after activity for 5s...
[2022-07-02 23:51:57 INFO] Steady state hypothesis: The app is healthy
[2022-07-02 23:51:57 INFO] Probe: app-responds-to-requests
[2022-07-02 23:51:57 CRITICAL] Steady state probe 'app-responds-to-requests' is not in the given tolerance so failing this experiment
[2022-07-02 23:51:57 INFO] Let's rollback...
[2022-07-02 23:51:57 INFO] No declared rollbacks, let's move on.
[2022-07-02 23:51:57 INFO] Experiment ended with status: deviated
[2022-07-02 23:51:57 INFO] The steady-state has deviated, a weakness may have been discovered

```

**Learning:** We can see that, after the initial probe was successful, we executed an action that ran the siege Pod. After that, the probe ran again, and it failed. Our application failed to respond because it was under a heavy load, and it collapsed. It couldn’t handle that amount of traffic. This time, the amount of traffic was low, and that’s why we’re simulating DoS attacks. However, in a production situation, you would send high volumes, maybe thousands or hundreds of thousands of concurrent requests, and see whether your application is responsive after that. In this case, we were cheating by configuring the application to handle a very low number of requests.
We can see that, in this case, the application cannot handle the load. The experiment failed.
<br>
Checkout `chaostoolkit.log` for more detailed logs.


### Running the Experiment to Gain Confidence that the Weaknesses have been Overcome

Performance lag can be troublesome. Not only can the delay cascade back through any other calling services but it can also cause the entire system to lag. In such a state retrying against a slow service makes it worse. To control the flow to the affected endpoint we introduce the [circuit breaker](https://istio.io/latest/docs/tasks/traffic-management/circuit-breaking/) which is a proxy that controls flow to an endpoint. The proxy opens the circuit to the container when the endpoint fails or is too slow. In such a case, traffic is routed to other replica containers because of load balancing. The circuit remains open for a preconfigured sleep window (let's say two minutes) after which the circuit is considered "half-open". The next request attempted will determine if the circuit moves to "closed" (where everything is working again), or it it reverts to "open" and the sleep window starts again. Here's a simple State Transition Diagram for the circuit breaker:
![image](https://developers.redhat.com/blog/wp-content/uploads/2018/03/circuit-breaker-1024x430.png)
It's important to note that this is all at the system architecture level, so to speak. At some point your application will need to account for the circuit breaker pattern; common responses include providing a default value or (if possible) ignoring the existence of the service. 

<br>

Deploy this new, improved system and re-run the experiment
```shell
$ kubectl -n go-app apply -f breaker.yaml
```

Now the running the experiment should complete successfully and report general system
steady-state health according to the experiment's probes. <br>
Without changing our source code, we are able to implement the circuit breaker pattern. Combining this with (Istio Pool Ejection), we can eliminate slow containers until they recover. In this example, a container is ejected for three minutes (the "sleepWindow" setting) before being reconsidered.
Note that application's ability to respond to a 503 error is still a function of source code. There are many strategies for handling an open circuit; which one can choose depends on particular situation.