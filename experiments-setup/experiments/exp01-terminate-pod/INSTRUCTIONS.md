## "Impact of Pod loss on application stability" Chaos Experiment

This sample experiment demonstrates a simple learning loop where applications need to be managed through replicasets or deployments and what happens if a crucial **provider** pod is down in an application such as from a stateful set.

**Note:** This experiment instruction set is designed to provide you with an intuition of how a general sequence of steps in a chaos experimentation world would look like. Of course, using a deployment is an obvious practice. Further experiments will be more pertinent.

### Prerequisites

To run this you will need the [Chaos Toolkit CLI][chaos-toolkit] >= 0.3.0
installed and have access to a Kubernetes cluster. Checkout Wiki for set up instructions

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

### Running the Experiment to Discover the `before` Weaknesses

Once you have the prerequisites in place you can deploy the `before` conditions
of the application as follows:

```shell
$ kubectl create ns go-app
$ kubectl -n go-app apply --filename db
$ kubectl -n go-app create -f pod.yaml
``` 

To run the experiment against the `before` conditions use the Chaos Toolkit CLI:

```shell
(venv) $ chaos run experiment.yaml
```

The experiment will highlight a weakness, app is unable to recover from loss of a pod.
shown in the following experiment sample output:

```shell
$ chaos --log-file=experiment.log run experiment.json 
[2022-06-30 15:17:44 INFO] Validating the experiment's syntax
[2022-06-30 15:17:46 INFO] Experiment looks valid
[2022-06-30 15:17:46 INFO] Running experiment: What happens if we terminate a Pod?
[2022-06-30 15:17:46 INFO] Steady-state strategy: default
[2022-06-30 15:17:46 INFO] Rollbacks strategy: default
[2022-06-30 15:17:46 INFO] Steady state hypothesis: Pod exists
[2022-06-30 15:17:46 INFO] Probe: pod-exists
[2022-06-30 15:17:46 INFO] Probe: pod-in-phase
[2022-06-30 15:17:46 INFO] Probe: pod-in-conditions
[2022-06-30 15:17:46 INFO] Steady state hypothesis is met!
[2022-06-30 15:17:46 INFO] Playing your experiment's method now...
[2022-06-30 15:17:46 INFO] Action: terminate-pod
[2022-06-30 15:17:46 INFO] Pausing after activity for 10s...
[2022-06-30 15:17:56 INFO] Steady state hypothesis: Pod exists
[2022-06-30 15:17:56 INFO] Probe: pod-exists
[2022-06-30 15:17:56 CRITICAL] Steady state probe 'pod-exists' is not in the given tolerance so failing this experiment
[2022-06-30 15:17:56 INFO] Experiment ended with status: deviated
[2022-06-30 15:17:56 INFO] The steady-state has deviated, a weakness may have been discovered
```

**Learning:** This new learning from the experiment invites us to learn how to overcome this
and, in our case, we'll do that using a fallback mechanism, like a deployment or replicaset.

Notice how you can enable a log file that will contain more traces of the run.

### Running the Experiment to Gain Confidence that the `before` Weaknesses have been Overcome

Now you can deploy this new, improved system and re-run the experiment:

```shell
$ kubectl -n go-app apply --filename deployment.yaml
```

You can re-run the experiment with the Chaos Toolkit CLI:

```shell
(venv) $ chaos run experiment.json
```

Now the experiment should complete successfully and report general system
steady-state health according to the experiment's probes as shown in the
following experiment sample output:

```shell
$ chaos --log-file=experiment.log run experiment.json 
[2022-06-30 15:30:50 INFO] Validating the experiment's syntax
[2022-06-30 15:30:51 INFO] Experiment looks valid
[2022-06-30 15:30:51 INFO] Running experiment: What happens if we terminate a Pod?
[2022-06-30 15:30:51 INFO] Steady-state strategy: default
[2022-06-30 15:30:51 INFO] Rollbacks strategy: default
[2022-06-30 15:30:51 INFO] Steady state hypothesis: Pod exists
[2022-06-30 15:30:51 INFO] Probe: pod-exists
[2022-06-30 15:30:51 INFO] Probe: pod-in-phase
[2022-06-30 15:30:51 INFO] Probe: pod-in-conditions
[2022-06-30 15:30:51 INFO] Steady state hypothesis is met!
[2022-06-30 15:30:51 INFO] Playing your experiment's method now...
[2022-06-30 15:30:51 INFO] Action: terminate-pod
[2022-06-30 15:30:51 INFO] Pausing after activity for 10s...
[2022-06-30 15:31:01 INFO] Steady state hypothesis: Pod exists
[2022-06-30 15:31:01 INFO] Probe: pod-exists
[2022-06-30 15:31:01 INFO] Probe: pod-in-phase
[2022-06-30 15:31:02 INFO] Probe: pod-in-conditions
[2022-06-30 15:31:02 INFO] Steady state hypothesis is met!
[2022-06-30 15:31:02 INFO] Let's rollback...
[2022-06-30 15:31:02 INFO] No declared rollbacks, let's move on.
[2022-06-30 15:31:02 INFO] Experiment ended with status: completed
```