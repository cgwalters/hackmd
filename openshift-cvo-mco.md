Why does the OpenShift upgrade process restart halfway?
===

Since the release of OpenShift 4, a somewhat frequently asked question is: Why sometimes during an `oc adm upgrade` does the process appear to re-start partway through?

The answer to this question is worth explaining in detail, because it illustrates some fundamentals of the [self-driving, operator-focused OpenShift 4](https://blog.openshift.com/openshift-4-a-noops-platform/).  During the initial development of OpenShift 4, the toplevel [cluster-version-operator](https://github.com/openshift/cluster-version-operator/) (CVO) and the [machine-config-operator](https://github.com/openshift/machine-config-operator/) (MCO) were developed concurrently (and still are).

The relationship between the two is interesting; when the CVO pulls down a new release image, that may in turn contain a new MCO as well as new operating system content; the
updated MCO [updates the operating system itself](https://github.com/openshift/machine-config-operator/blob/master/docs/OSUpgrades.md) for the control plane. 

During an upgrade, the MCO will drain each node it is working on updating, then reboot.  The CVO is just a regular pod running in the cluster (`oc -n openshift-cluster-version get pods`); it gets drained and rescheduled just like the rest of the platform, and applications.

Today, there's no special support in the CVO for passing "progress" between the previous and new pod; the new pod just looks at the current cluster state and attemps to reconcile between the observed and desired state.

Hence, the fact that the CVO is terminated and restarted is visible to components watching the `clusterversion` object as the status is recalculated.

I could imagine at some point adding clarification for this; perhaps a basic boolean flag state in e.g. a `ConfigMap` or so that denoted that the pod was drained due to an upgrade, and the new CVO pod would "consume" that flag and include "Resuming upgrade..." text in its status.  But I think that's probably all we should do.

By not special casing upgrading itself, the CVO restart works the same way as it would if the kernel hit a panic and froze, or the hardware died, there was an unrecoverable network partition, etc.  This is known as [crash-only software](https://en.wikipedia.org/wiki/Crash-only_software).  By having the "normal" code path work in exactly the same way as the "exceptional" path, we ensure the upgrade process is robust and tested constantly, and OpenShift administrators can rely on it and keep their cluster up to date.
