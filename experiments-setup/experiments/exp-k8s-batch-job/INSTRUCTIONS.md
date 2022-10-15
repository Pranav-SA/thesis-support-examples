## "How to move the setup inside the cluster?" 

Previously, experiments were being run from the user machine, assuming user has got the required permissions to make such changes.
Now, we explore how we can do the same from inside the cluster and schedule the same as a job. We make use of the chaostoolkit base image
and extensions (Dockerfile inside the repo).  

### Prerequisites

For running this experiment, as expected we need a cluster. Since we know the advantages of multi-zonal clusters we can use those
(described in cluster setup wiki) or we can use any cluster for test and trial.

### Application Setup

Once you have the prerequisites in place you can deploy the `before` conditions
of the application as follows:

```shell
$ kubectl create ns go-app
$ kubectl label namespace go-app istio-injection=enabled
$ kubectl --namespace go-app apply --filename k8s/app-full
$ kubectl --namespace go-app rollout status deployment go-app
``` 
<br>

Sending a request to confirm accessibility:
```shell
curl -H "Host: repeater.acme.com" "http://$INGRESS_HOST?addr=http://go-app"
```

### Defining configuration in Kubernetes using the ConfigMap

For running chaos experiments inside the Kubernetes cluster, below two steps are required:<br>
1. Experiment definitions are to be stored somewhere in the cluster. The most common and the most logical way to define a configuration in Kubernetes is to use ConfigMap.<br>
1. Apart from having experiment definitions readily available, a ServiceAccount is needed to add the necessary privileges to processes that will run the experiments.

All in all, experiments will be defined as [ConfigMaps](./experiments.yaml), and permissioned using [Service Account](./sa.yaml).

```shell
$ kubectl --namespace go-app apply --filename experiments.yaml
$ kubectl --namespace go-app describe configmap chaostoolkit-experiments
$ kubectl --namespace go-app apply --filename sa.yaml
```

**Note:** Service Account allows almost all actions, but limited to a specific Namespace.<br>
To be safe, it needs to be more restrictive than that. Permissions will effectively allow processes in that Namespace to do anything inside it. On the other hand, it is tough to be restrictive with permissions which are needed for chaos experiments. Theoretically, one might want to affect anything inside a Namespace or even the whole cluster through experiments. So, no matter how strong our desire is to be restrictive with the permissions in general, one might need to be generous to chaos experiments. For them to work correctly, one needs to likely allow a wide range of permissions. As a minimum, one can permit to perform the actions planned to be run.
From permissions point of view, the only real restriction that here, we’re setting up is that we are creating the RoleBinding and not a ClusterRoleBinding. Those permissions will be assigned to the ServiceAccount inside that Namespace. As a result, we’ll limit the capability of Chaos Toolkit to that Namespace, and it will not be able to affect the whole cluster.


### Running One-Shot Experiment

We can run one-shot experiments by executing experiments on demand. We can say, “let’s run that experiment right now.” I’m calling them “one-shot” because such experiments would not be recurring. We’ll be able to choose when to execute them, and they will exist only while they’re running. We’ll be able to monitor the progress and observe what’s going on. We could run those experiments manually, or we could hook them into our continuous delivery. In the latter case, they would be part of our pipelines and, for example, executed whenever we deploy a new release.


```shell
$ kubectl -n go-app apply --filename once.yaml
```

Observe the pods till you have `completed` which implies success or `error` which implies failed.

```shell
NAME                READY STATUS    RESTARTS AGE
go-app-chaos-... 0/1   Completed 0        275s
```

Observe the logs of the pod before deleting the job. The only substantial difference between now and then is that we run the experiment from a container, instead of user console. As a result, Kubernetes added timestamps and log levels to each output entry.

### Testing for objectiveness
We want to test the system and be objective. This might sound strange, but being objective with chaos engineering often means being, more or less, random. If we know when something potentially disrupting might happen, we might react differently than when in unexpected situations. We might be biased and schedule the execution of experiments at the time when we know that there will be no adverse effect on the system. Instead, it might be a good idea to run experiments at some random intervals during the day or a week so that we cannot easily predict what will happen. We often don’t control when “bad” things will happen in production. Most of the time, we don’t know when a node will die, and we often cannot guess when a network will stop being responsive.
Similarly, we should try to include some additional level of randomness to the experiments. If we run them only when we deploy a new release, we might not discover the adverse effects that might be produced hours later. We can partly mitigate that by running experiments periodically.

### Running Periodic Experiment

We can also run experiments periodically. We might choose to do chaos every few minutes, every few hours, once a day, or whatever the schedule we’ll define is.


```shell
$ kubectl -n go-app apply --filename periodic.yaml
```

<br>

Periodic YAML is slightly bigger than the previous one. The major difference is that this time we are not defining a Job. Instead, we have a CronJob, which will create the Jobs in scheduled intervals.<br>
If you take a closer look, you’ll notice that the CronJob is almost the same as the Job we used before. There are a few significant differences, though.
First of all, we probably don’t want to run the same Jobs concurrently. Running one copy of an experiment at a time should be enough. So, we set concurrencyPolicy to Forbid.
The schedule, in this case, is set to */5 * * * *. That means that the Job will run every five minutes unless the previous one did not yet finish since that would contradict the concurrencyPolicy.
If you’re not familiar with the syntax like `*/5 * * * *`, it is the standard syntax from crontab available in (almost) every Linux distribution.

Observe the cronjobs, jobs, pod jobs (may take some time to be scheduled) till you have `completed` which implies success or `error` which implies failed. Do not forget to `delete` the cronjob after.

```shell
kubectl --namespace go-app get cronjobs
NAME            SCHEDULE    SUSPEND ACTIVE LAST SCHEDULE AGE
go-app-chaos */5 * * * * False   1      6s            84s

kubectl --namespace go-app get jobs
NAME                COMPLETIONS DURATION AGE
go-app-chaos-... 0/1         19s      19s

kubectl --namespace go-app get pods
NAME                READY STATUS    RESTARTS AGE
go-app-chaos-... 0/1   Completed 0        275s
```

<br>
We configured Jobs not to restart on failure. That’s what we’re doing in that definition by `setting spec.template.spec.restartPolicy` to Never. Experiments can be successful or failed, and no matter the outcome of an experiment, the Pod created by that Job will run only once. Also, here only one container is defined. We could have more if we’d like to run multiple experiments.
