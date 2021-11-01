---
title: OpenShift CoreOS Layering
authors:
  - "@cgwalters"
  - "@darkmuggle"
reviewers:
  - "@mrunalp"
approvers:
  - "@yuqi-zhang"
  - "@mrunalp"
creation-date: 2021-10-19
last-updated: 2021-10-19
status: provisional
---

# OpenShift Layered CoreOS

## Release Signoff Checklist

- [ ] Enhancement is `implementable`
- [ ] Design details are appropriately documented from clear requirements
- [ ] Test plan is defined
- [ ] Operational readiness criteria is defined
- [ ] Graduation criteria for dev preview, tech preview, GA
- [ ] User-facing documentation is created in [openshift-docs](https://github.com/openshift/openshift-docs/)

## Summary

A key feature of OpenShift 4 is that the cluster manages the operating system too.  Today there is a hybrid management/update mechanism through rpm-ostree and the Machine Config Daemon, see [OSUpgrades.md](https://github.com/openshift/machine-config-operator/blob/master/docs/OSUpgrades.md).

There is an effort to add "ostree native containers" or [CoreOS layering](https://github.com/coreos/enhancements/pull/7).  This enhancement details how we can rework OpenShift 4 after that functionality has landed in Fedora and RHEL.

## Motivation

While we ship the binaries as part of a container image in the same way that the platform itself runs applications, Ignition and the Machine Config Daemon mutate the on-disk configuration during provisioning and upgrades of the cluster nodes.  A significant amount of logic in the MCO tries to deal with the pair of (base os image, configuration).

There are various flaws with this:

- A significant amount of mutation happens per-node
- [Filesystem modifications are not transactional](https://github.com/openshift/machine-config-operator/issues/1190)
- Related to the above, `rpm-ostree rollback` does not do the right thing, and it's also hard to rollback at the cluster level
- There is no way to validate without rebooting a node (and booting a new test node in the new config is not obvious or easy)
- Users have been exposed to the internal templating engine of the MCO


### Goals

- [ ] Administrators can add custom code alongside configuration via a familiar build system
- [ ] Transactional configuration changes
- [ ] Avoid breaking existing workflow via MachineConfig (including extensions)
- [ ] Avoid overwriting existing custom modifications (such as files managed by other operators) during upgrades


### Non-Goals

- While the base CoreOS layer/ostree-container functionality will be accessible outside of OpenShift, this enhancement does not cover or propose any in-cluster functionality for generating or using images outside of the OpenShift node use case.

## Proposal

1. The `machine-os-content` shipped as part of the release payload will change format to the new "native ostree-container" format (and become runnable as a container directly for testing).  Internally, this will be a `openshift-machine-config-operator/coreos` object of type `imagestream`, owned by the MCO.
2. There will be a new default `mco-coreos` `BuildConfig` owned by the MCO (also in the `openshift-machine-config-operator` namespace).  This is where most `MachineConfig` changes will be handled.
3. The MCO will honor an `custom-coreos` `BuildConfig` object created in the `openshift-machine-config-operator` namespace.  This build must use the `mco-coreos` imagestream as a base.  Output from this build must push to a `custom-coreos` imagestream.  The result of this will be rolled out by the MCO to nodes.
4. The MCO will also honor a `custom-external-coreos` imagestream for pulling externally built images
5. MCD continues to perform drains and reboots, but writes much less configuration per node
6. The Machine Configuration Server (MCS) will only serve a "bootstrap" Ignition configuration (pull secret, network configuration) sufficient for the node to pull the target container image.

For clusters without any custom MachineConfig at all, `machine-os-source` == `machine-os-target`.

### User Stories

#### What works now continues to work

An OpenShift administrator at example.corp is happily using OpenShift 4 (with RHEL CoreOS) in several AWS clusters today, and has only a small custom MachineConfig object to tweak host level auditing.  They do not plan to use any complex derived builds, and just expect that upgrading their existing cluster continues to work and respect their small audit configuration change.


#### Adding a 3rd party security scanner/IDS

example.bank's security team requires a 3rd party security agent to be installed on bare metal machines in their datacenter.  The 3rd party agent comes as an RPM today, and requires its own custom configuration.  While the 3rd party vendor has support for execution as a privileged daemonset on their roadmap, it is not going to appear soon. 

After initial cluster provisioning is complete, the administrators at example.bank supply a `BuildConfig` object named `machine-os-build` with an [inline Dockerfile](https://docs.openshift.com/container-platform/4.8/cicd/builds/creating-build-inputs.html#builds-dockerfile-source_creating-build-inputs) that adds a repo file to `/etc/yum.repos.d/agentvendor.repo` and invokes `RUN yum -y install some-3rdparty-security-agent`).


The MCO notices the build object creation and starts an initial build, which gets succesfully pushed to the `machine-os-target` imagestream.  This gets added to both the master and worker pools, and is rolled out in the same way the MCO performs configuration and OS updates today.

A few weeks later, after a cluster level upgrade has started, a new base RHEL CoreOS image is updated in the  `coreos` imagestream by the MCO.  This triggers a rebuild of `openshift-coreos`, which succeeds.  This in turn triggers a rebuild of the `user-coreos`


A month after that, the administrator wants to make a configuration change, and creates a `machineconfig` object.  This triggers a new image build.  But, the 3rd party yum repository is down, and the image build fails.  The operations team gets an alert, and resolves the repository connectivity issue.  They manually restart the build via `oc -n openshift-machine-config-operator start-build machine-os-build` which succeeds.

### Implementation details

#### Preserving `MachineConfig`

We cannot just drop `MachineConfig` as an interface to node configuration.  Hence, the MCO will be responsible for starting new builds on upgrades or when new machine config content is rendered.

For most configuration, instead of having the MCD write files on each node, it will be added into the image build run on the cluster.  To be more specific, most content from the Ignition `systemd/units` and `storage/files` sections (in general, files written into `/etc`) will instead be injected into an internally-generated `Dockerfile` (or equivalent) that performs an effect similar to this:

```dockerfile=
FROM <coreos>
ADD /etc /etc
```

This build process will be tracked via a `mco-coreos-build` `BuildConfig` object which will be monitored by the operator.

The output of this build process will be pushed to the `openshift-coreos-base` imagestream, which should be used by further build processes.

#### Preserving old MCD behaviour for RHEL nodes

The RHEL 8 worker nodes in-cluster will require us to continue support existing file/unit write as well as provision (`once-from`) workflows.  See also [openshift-ansible and MCO](https://github.com/openshift/machine-config-operator/issues/1592).

#### Handling extensions

We need to preserve support for [extensions](https://github.com/openshift/enhancements/blob/master/enhancements/rhcos/extensions.md).  For example, `kernel-rt` support is key to many OpenShift use cases.

Extensions move to a `machine-os-content-extensions` container that has RPMs.  Concretely, switching to `kernel-rt` would look like e.g.:

```
FROM machine-os-extensions as extensions

FROM <machine-os-content>
WORKDIR /root
COPY --from=extensions /srv/extensions/*.rpm .
RUN rpm-ostree switch-kernel ./kernel-rt*.rpm
```


#### Kernel Arguments

Not currently in scope for CoreOS derivation.  See also https://github.com/ostreedev/ostree/issues/479

For now, updating kernel arguments will continue to happen via the MCD on each node via executing `rpm-ostree kargs` as it does today.


#### Ignition

Ignition will continue to handle the `disks` and `filesystem` sections - for example, LUKS will continue to be applied as it has been today.

Further, it is likely that we will need to ship a targeted subset of the configuration via Ignition too - for example, the pull secret will be necessary to pull the build containers. 

#### Drain and reboot

The MCD will continue to perform drain and reboots.


#### Reboots and live apply

The MCO has invested in performing some types of updates without rebooting.  We will need to retain that functionality.

Today, `rpm-ostree` does have `apply-live`.  One possibility is that if just e.g. the pull secret changes, the MCO still builds a new image with the change, but compares the node state (current, new) and executes a targeted command like `rpm-ostree apply-live --files /etc/kubernetes/pull-secret.json` that applies just that change live.

Or, the MCD might handle live changes on its own, writing files instead to e.g. `/run/kubernetes/pull-secret.json` and telling the kubelet to switch to that.

#### Intersection with https://github.com/openshift/enhancements/pull/201

In the future, we may also generate updated "bootimages" from the custom operating system container.

#### Intersection with https://github.com/openshift/os/issues/498

It would be very natural to split `machine-os-content` into `machine-coreos` and `machine-kubelet` for example, where the latter derives from the former.


#### Using RHEL packages - entitlements and bootstrapping

Today, installing OpenShift does not require RHEL entitlements - all that is necessary is a pull secret.

This CoreOS layering functionality will immediately raise the question of supporting `yum -y install $something` as part of their node, where `$something` is not part of our extensions that are available without entitlement.

For cluster-internal builds, it should work to do this "day 2" via [existing RHEL entitlement flows](https://docs.openshift.com/container-platform/4.9/cicd/builds/running-entitled-builds.html#builds-source-secrets-entitlements_running-entitled-builds).  

Another alternative will be providing an image built outside of the cluster.

It may be possible in the future to perform initial custom builds on the bootstrap node for "day 1" customized CoreOS flows, but adds significant complexity around debugging failures.  We suspect that most users who want this will be better served by out-of-cluster image builds.

### Risks and Mitigations

We're introducing a whole new level of customization for nodes, and because this functionality will be new, we don't yet have significant experience with it.  There are likely a number of potentially problematic "unknown unknowns".

To say this another way: until now we've mostly stuck to the model that user code should run in a container, and keep the host relatively small.  This could be perceived as a major backtracking on that model.

This also intersects heavily with things like [out of tree drivers](https://github.com/openshift/enhancements/pull/357).

We will need some time to gain experience with what works and best practices, and develop tooling and documentation.

#### Supportability of two update mechanisms

If for some reason we cannot easily upgrade existing systems and need to support *two* ways to update CoreOS nodes, it will become an enormous burden.

#### Versioning of e.g. kubelet

We will need to ensure that we detect and handle the case where core components e.g. the `kubelet` binary is coming from the wrong place, or is the wrong version.


#### Registry availability

If implemented in the obvious way, we OS updates would fail if the cluster-internal registry is down.

A strong mitigation for this is to use ostree's native ability to "stage" the update across all machines before starting any drain at all.  However, we should probably still be careful to only stage the update on one node at a time (or `maxUnavailable`) in order to avoid "thundering herd" problems, particularly for the control plane with etcd.

Another mitigation here may be to support peer-to-peer upgrades, or have the control plane host a "bootstrap registry" that just contains the pending OS update.



## Design Details

### Open Questions

- Would we offer multiple base images, e.g. users could now choose to use RHEL 8.X versus RHEL 8.$latest?

### Test Plan

Attempting to convert as much of the default MachineConfig flow to use this functionality will heavily exercise the code.

### Graduation Criteria

(skipped)


### Upgrade / Downgrade Strategy

See above - this is a large risk.  Nontrivial work may need to land in the MCO to support transitioning nodes.

### Version Skew Strategy

Similar to above.


## Implementation History

There was a prior version of this proposal which was OpenShift specific and called for a custom build strategy.  Since then, the "CoreOS layering" effort has been initiated, and this proposal is now dedicated to the OpenShift-specific aspects of using this functionality, rather than also containing machinery to build custom images.

## Drawbacks

If we are succesful; not many.  If it turns out that e.g. upgrading existing RHCOS systems in place is difficult, that will be a problem.

## Alternatives

Continue as is - supporting both RHEL CoreOS and traditional RHEL (where it's more obvious how to make arbitrary changes at the cost of upgrade reliability), for example.
