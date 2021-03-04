---
title: coreos-bootimage-streams
authors:
  - "@cgwalters"
reviewers:
  - "@coreos-team"
approvers:
  - "@coreos-team"
creation-date: 2021-03-04
last-updated: 2021-03-04
status: provisional
---

# Standardized CoreOS bootimage metadata

This is a preparatory subset of the larger enhancement for [in-cluster CoreOS bootimage creation](https://github.com/openshift/enhancements/pull/201).

This enhancement calls for a standardized JSON format for (RHEL) CoreOS bootimage metadata to be placed at https://mirror.openshift.com *and* included in a new `rhel-coreos-bootimages` image included in the release image.

## Release Signoff Checklist

- [ ] Enhancement is `implementable`
- [ ] Design details are appropriately documented from clear requirements
- [ ] Test plan is defined
- [ ] Graduation criteria for dev preview, tech preview, GA
- [ ] User-facing documentation is created in [openshift-docs](https://github.com/openshift/openshift-docs/)

## Summary

Since the initial release of OpenShift 4, we have "pinned" RHCOS bootimage metadata inside [openshift/installer](https://github.com/openshift/installer).  In combination with the binding between the installer and release image, this means that everything needed to install OpenShift (including the operating system "bootimages" such as e.g. AMIs and OpenStack `.qcow2` files) are all captured behind the release image which we can test and ship as an atomic unit.

We have a mechanism to do [in place updates](https://github.com/openshift/machine-config-operator/blob/09fe53e2e47bc6f8129376dfe389e98fc151ff48/docs/OSUpgrades.md), but there is no automated mechanism to update "bootimages" past a cluster installation.

This enhancement does not describe an automated mechanism to do this: the initial goal is to include this metadata in a standardized format in the cluster and at mirror.openshift.com so that UPI installations can do this manually, and we can start work on an IPI mechanism.

#### Stream metadata format

As part of unifying Fedora CoreOS and RHEL CoreOS, we have standardized on the "stream metadata" format used by FCOS.  More in [FCOS docs](https://docs.fedoraproject.org/en-US/fedora-coreos/getting-started/) and [this RHCOS issue](https://github.com/openshift/os/issues/477).

There is a new [stream-metadata-go](https://github.com/coreos/stream-metadata-go) library to consume this data.

#### Adding a new git repository and release image component + configmap with this data

A new git repository https://github.com/openshift/rhel-coreos-bootimages will be created (based on [an existing prototype repository](https://github.com/cgwalters/rhel-coreos-bootimages)).  It will have the stream JSON.

Additionally, this repository will be included in the release image as `rhel-coreos-bootimages` and it will use the CVO to install a `configmap/coreos-bootimages` in the `openshift-machine-config-operator` namespace.

*This metadata will duplicate that in github.com/openshift/installer to start!*  Trying to change the installer to somehow pull the data from the release image would be a huge architectural change ([previously attempted](https://github.com/openshift/installer/pull/1286/files#)) - we cannot block on that.

The RHCOS team will take over maintenance and automation of `rhel-coreos-bootimages` and we will create trivial automation to sync it to github.com/openshift/installer.

#### Add `oc adm release info --coreos-bootimages quay.io/openshift-release-dev/ocp-release:4.7.0-x86_64`

This command will extract the CoreOS bootimage stream metadata from a release image and should be used by UPI installs (including our many existing automated tests for UPI).

Additionally, we will add `oc adm release coreos-download -p openstack` which will e.g. download the OpenStack `.qcow2`, including verifying its integrity.

### Data available at https://mirror.openshift.com

The way we deliver bootimages at http://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.7/latest/ is not friendly to automation.  By placing the stream metadata JSON there, we gain a standardized machine-readable format.

The ART team will synchronize the stream metadata with the data embedded in the latest release image for a particular OpenShift minor.


## Motivation

### Goal 1: Including metadata in the cluster so that we can later write automated IPI/machineAPI updates

Lay the groundwork so that one or both of the MCO or machineAPI operators can act on this data, and e.g. in an AWS cluster update the machineset to use a new base AMI.

### Goal 2: Provide a standardized JSON file UPI installs

See above - this JSON file will be available in multiple ways for UPI installations.

### Non-Goals

#### Replacing the default in-place update path

In-place updates as [managed by the MCO](https://github.com/openshift/machine-config-operator/blob/master/docs/OSUpgrades.md) today works fairly seamlessly.  
We can't require that everyone fully reprovision a machine in order to do in-place updates - that makes updates *much* more expensive, particularly on bare metal environments.
It implies re-downloading all container images, etc.

Today in OpenShift 4, the control plane is also somewhat of a "pet" - we don't have streamlined support for reprovisioning control plane nodes even in IaaS/cloud and hence must continue to do in-place updates.

### User Stories

#### Story 1

An OpenShift core developer can write a PR which reads the configmap from the cluster and acts on it to update the machinesets to e.g. use a new AMI.  

We can start on other nuanced problems like ensuring we only update the machinesets once a controlplane update is complete, or potentially even offering an option in IPI/machineAPI installs to drain and replace workers instead of doing in-place updates.

#### Story 2

ACME Corp runs OpenShift 4 on vSphere in an on-premise environment not connected to the public Internet.  She has (traditional) RHEL 7 already imported into the environment and already pre-configured and managed by her operations team.

She boots an instance there, logs in via ssh, downloads an `oc` binary.  Jane then proceeds to follow the instructions for preparing a [mirror registry](https://docs.openshift.com/container-platform/4.3/installing/install_config/installing-restricted-networks-preparations.html).

Jane also uses `oc adm release coreos-download -p vsphere quay.io/openshift-release-dev/ocp-release:4.7.0-x86_64` to download the required OVA and then upload it to the vSphere instance.

From that point, Jane's operations team can use `openshift-install` in UPI mode, referencing that already uploaded bootimage and the internally mirrored OpenShift release image content.

### Risks and Mitigations

In an intermediate state where we have two "sources of truth" for the RHCOS version (pinned in the installer *and* included in the release image), the potential for confusion increases.

We will need to be on top of ensuring those are in sync.

## Design Details

### Test Plan

### Graduation Criteria

TBD

### Version Skew Strategy

The whole idea of this is to *reduce* skew overall.  However, we do need to ensure that e.g. new bootimages are only replaced in machinesets once a cluster upgrade is fully complete.

## Implementation History

## Drawbacks

For the near term future, having two places where RHCOS bootimage metadata is maintained.

## Alternatives

None, we need to do something here.
