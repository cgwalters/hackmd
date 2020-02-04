---
title: bootimage-updates
authors:
  - "@cgwalters"
reviewers:
  - "@coreos-team"
approvers:
  - "@coreos-team"
creation-date: 2020-02-04
last-updated: 2020-02-024
status: provisional
---

# Updating bootimages

This proposes a path towards having installed clusters use newer "bootimages", rather than having e.g. newly scaled up workers start from whichever bootimage was created at install time.  This increases speed and (long term) avoids the need to test in-place updates from the original OpenShift 4.1 bootimages to OpenShift 4.X.

## Release Signoff Checklist

- [ ] Enhancement is `implementable`
- [ ] Design details are appropriately documented from clear requirements
- [ ] Test plan is defined
- [ ] Graduation criteria for dev preview, tech preview, GA
- [ ] User-facing documentation is created in [openshift-docs](https://github.com/openshift/openshift-docs/)

## Summary

OpenShift will support fully clusters managing their own bootimages (in IaaS clouds), and come with tooling and documentation to aid operators on e.g. bare metal PXE to keep bootimages up date.

## Motivation

Most discussion of this problem originated in [this issue](https://github.com/openshift/os/issues/381).

Since the creation of OpenShift 4.1 and continuing until the time of this writing, there is no automated mechanism to update "bootimages" past a cluster installation.  We have a mechanism to do [in place updates](https://github.com/openshift/machine-config-operator/blob/09fe53e2e47bc6f8129376dfe389e98fc151ff48/docs/OSUpgrades.md) which has worked quite well, but there is a need to do more.

### Goal 1: Scaling up workers directly into upgraded OS

In an IaaS cloud with [cluster autoscaling](https://docs.openshift.com/container-platform/4.3/machine_management/applying-autoscaling.html) enabled, every worker that comes online will need to pull the latest `machine-os-content` and reboot.  This adds 3-4 minutes (at least) of latency to scaleup, and that time can matter significantly in "burst" scale scenarios, serverless usage, etc.

### Goal 2: Avoid accumulation of technical debt across OS updates

The CoreOS team must today support clusters upgraded in place (e.g. `oc adm upgrade`) from OpenShift 4.1 until the forseeable future.  We would like the ability to make potentially breaking changes, relying on the ability for the cluster to re-provision both the control plane and workers in-place from updated bootimages.
 
### Goal 3: Better integrate bootimage management into disconnected install paths

OpenShift 4 comes as a "release image" which is a *container* image - bootimages do not naturally fit into that, and currently the installer has some ad-hoc support for dealing with bootimages.

A goal here is to make bootimage management more of a first class operation, something like:

```
$ oc adm release generate-bootimage quay.io/openshift/release:4.3 vmware
```

Rather than having an administrator [manually download a bootimage](https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.3/latest/) corresponding to the release version, this command would output a bootimage for the chosen platform/media.

Similarly:

```
$ oc adm release generate-bootimage quay.io/openshift/release:4.3 aws
```

would output data similar to the [aws rhcos.json data](https://github.com/openshift/installer/blob/2055609f95b19322ee6cfdd0bea73399297c4a3e/data/data/rhcos.json#L2) so that AWS UPI installations could use it programatically.

Other output proposals

- `metal`, `openstack`, `qemu`: What's available today for 4.3
- `aws-snapshot` to handle [private AWS regions](https://github.com/openshift/os/blob/411d1f5943ea23f2de7e4f7a04ab0bb185fd9586/FAQ.md#q-how-do-i-get-rhcos-in-a-private-ec2-region).
- `baremetal-iso` generates a "Live" ISO as is used in Fedora CoreOS and points people at how to do [Ignition injection](https://github.com/coreos/coreos-installer/blob/3652e6a767bad593b1b898f239e41bc11a83ab8f/src/iso.rs#L28)
- `baremetal-pxe` outputs the split kernel/initramfs suitable for PXE

### Non-Goals

- Exposing a general purpose "OS build" tool (like https://github.com/coreos/coreos-assembler/ )

## Proposal phase 1: bootimage.json in release image

First, the RHCOS build process is changed to inject the current coreos-assembler `meta.json` output for the build into `machine-os-content`.  This aims to move the "source of truth" for cluster bootimages into the release image.  Nothing would use this to start - however, as soon as we switch to a machine API provisioned control plane, having that process consume this data would be a natural next step.

In fact, we could aim to switch to having workers use the `bootimage.json` from the release payload immediately after it lands.  A downside is this would open up potential for drift between the bootstrap+controlplane and workers.

## Proposal phase 2: oc adm release generate-bootimage

The implementation of this is basically shipping a subset of [coreos-assembler](https://github.com/coreos/coreos-assembler) as part of the OpenShift release payload, and teaching `oc` how to invoke `podman` to run it.

The `generate-bootimage` implementation would download the `machine-os-bootimage-generator` container image along with the existing `machine-os-content` container image (OSTree repository), and effectively run the [create_disk.sh](https://github.com/coreos/coreos-assembler/blob/30fbac4e176c7936362efbd647c8199d927e593c/src/create_disk.sh) process or [buildextend-installer](https://github.com/coreos/coreos-assembler/blob/30fbac4e176c7936362efbd647c8199d927e593c/src/cmd-buildextend-installer) for live media, etc.

This should have three possible runtime choices:

- Run via `--privileged` and use loopback mounts (avoids any virtualization requirements)
- Run via `--device /dev/kvm` (as coreos-assembler is optimized for today)
- Run with `--env COSA_NO_KVM=1` to run in environments without KVM

It would also be theoretically possible to support using e.g. an on-demand provisioned EBS volume, but this would impose a burden on the CoreOS team for another build path.

### User Stories

#### Story 1

ACME Corp runs OpenShift 4 in Google Compute Engine (installed via IPI) and are fairly invested in serverless via KNative.  They regularly keep on top of the latest OpenShift releases via in-place updates. When access to their widget store increases at peak times, their OpenShift cluster quickly boots latest RHCOS nodes in new instances to handle the work.

At no point did the ACME Corp operations team have to worry about managing or updating the GCP bootimages.

#### Story 2

Jane Smith runs OpenShift 4 on VMWare in an on-premise environment not connected to the public Internet.  She has (traditional) RHEL 7 already imported into the environment and already pre-configured and managed by her operations team.  

She boots an instance there, logs in via ssh, downloads an `oc` binary, and then uses `oc adm release generate-bootimage quay.io/openshift/release:4.3 vmware` to generate an OVA that can be imported into the VMWare environment.

Jane then proceeds to use `openshift-install` in UPI mode, referencing that already uploaded bootimage, and is also able to reuse that bootimage across multiple cluster installations.

### Risks and Mitigations

In an intermediate state where we have two "sources of truth" for the RHCOS version (pinned in the installer *and* included in the release image), the potential for confusion increases.

## Design Details

### Test Plan

If we switch to having workers provisioned via `bootimage.json` from the release payload, then the system will be constantly tested by every CI and periodic run today - plus the existing `machine-os-content` promotion gate.

The new `machine-os-bootimage-generator` container would have its own repository with its own e2e test that runs in at least one IaaS cloud and e.g. a VMWare environment too.

### Graduation Criteria

TBD

### Version Skew Strategy

The whole idea of this is to *reduce* skew overall.  However, we do need to ensure that e.g. new bootimages are only replaced in machinesets once a cluster upgrade is fully complete.

## Implementation History


## Drawbacks

Even more moving parts to maintain for the CoreOS/MCO team, and this also requires integration with other components such as machineAPI, the release image, etc.

## Alternatives

We could only try to handle the case of bootimage updates for connected IaaS environments, but that would leave disconnected ones out in the cold and we need to support those too.
