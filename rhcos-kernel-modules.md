---
title: RHCOS 3rd party kernel module support
authors:
 - @cgwalters
reviewers:
 - TBD
approvers:
 - TBD
creation-date: 2020-03-16
last-updated: 2020-03-16
status: provisional
---

# Support 3rd party kernel modules for RHEL CoreOS

This enhancement builds on a lot of prior discussion, including:

- https://github.com/coreos/fedora-coreos-tracker/issues/249
- https://github.com/coreos/fedora-coreos-tracker/issues/401
- https://pagure.io/workstation-ostree-config/pull-request/135

In particular, this calls for enhancing [kmods-via-containers](https://github.com/kmods-via-containers) for OpenShift 4.

## Release Signoff Checklist

- [ ] Enhancement is `implementable`
- [ ] Design details are appropriately documented from clear requirements
- [ ] Test plan is defined
- [ ] Graduation criteria for dev preview, tech preview, GA
- [ ] User-facing documentation is created in [openshift-docs](https://github.com/openshift/openshift-docs/)


## Summary

Improved support for 3rd party kernel modules in RHEL CoreOS.

## Motivation

Part of the value of Red Hat Enterprise Linux is a long term stable lifecycle for the OS overall, and specifically for the kernel there is some support for [kernel ABI](https://access.redhat.com/solutions/444773) to specifically enable 3rd party kernel modules.

### Goals

This model should support kernel modules that can be loaded after kubelet has started.  Specific examples:

- nvidia
- IBM Spectrum Scale storage

### Non-Goals

Supporting e.g. RHEL CoreOS root filesystem (or container storage) on a storage system via 3rd party kernel module is not in scope.

## Proposal

Start with https://github.com/kmods-via-containers/kmods-via-containers#steps-for-openshift-rhcos-via-the-mco but make it much less awkward.  In particular, [avoiding entitlements](https://github.com/kmods-via-containers/kmods-via-containers/issues/3) seems quite key for ergonomics (but, if another team/effort solves the entitlements + RHCOS issue, then we can rely on them).

### Sub-topic: kernel headers

Previously in [the realtime kernel enhancement](https://github.com/openshift/enhancements/blob/master/enhancements/support-for-realtime-kernel.md) we blazed the trail of "extensions" for `machine-os-content` that are lifecycle bound with the OS, but not enabled by default.

### User Stories [optional]

Detail the things that people will be able to do if this is implemented.
Include as much detail as possible so that people can understand the "how" of
the system. The goal here is to make this feel real for users without getting
bogged down.

#### Story 1

#### Story 2

### Implementation Details/Notes/Constraints [optional]

What are the caveats to the implementation? What are some important details that
didn't come across above. Go in to as much detail as necessary here. This might
be a good place to talk about core concepts and how they relate.

### Risks and Mitigations

A large risk here is that as the kernel changes, some 3rd party modules may fail to compile.

Also, the situation for OKD with Fedora CoreOS is quite different, as the Fedora project tracks the upstream Linux kernel closely.

## Design Details

### Test Plan

**Note:** *Section not required until targeted at a release.*

Consider the following in developing a test plan for this enhancement:
- Will there be e2e and integration tests, in addition to unit tests?
- How will it be tested in isolation vs with other components?

No need to outline all of the test cases, just the general strategy. Anything
that would count as tricky in the implementation and anything particularly
challenging to test should be called out.

All code is expected to have adequate tests (eventually with coverage
expectations).

### Graduation Criteria

**Note:** *Section not required until targeted at a release.*

Define graduation milestones.

These may be defined in terms of API maturity, or as something else. Initial proposal
should keep this high-level with a focus on what signals will be looked at to
determine graduation.

Consider the following in developing the graduation criteria for this
enhancement:
- Maturity levels - `Dev Preview`, `Tech Preview`, `GA`
- Deprecation

Clearly define what graduation means.

#### Examples

These are generalized examples to consider, in addition to the aforementioned
[maturity levels][maturity-levels].

##### Dev Preview -> Tech Preview

- Ability to utilize the enhancement end to end
- End user documentation, relative API stability
- Sufficient test coverage
- Gather feedback from users rather than just developers

##### Tech Preview -> GA 

- More testing (upgrade, downgrade, scale)
- Sufficient time for feedback
- Available by default

**For non-optional features moving to GA, the graduation criteria must include
end to end tests.**

##### Removing a deprecated feature

- Announce deprecation and support policy of the existing feature
- Deprecate the feature

### Upgrade / Downgrade Strategy

If applicable, how will the component be upgraded and downgraded? Make sure this
is in the test plan.

Consider the following in developing an upgrade/downgrade strategy for this
enhancement:
- What changes (in invocations, configurations, API use, etc.) is an existing
  cluster required to make on upgrade in order to keep previous behavior?
- What changes (in invocations, configurations, API use, etc.) is an existing
  cluster required to make on upgrade in order to make use of the enhancement?

### Version Skew Strategy

How will the component handle version skew with other components?
What are the guarantees? Make sure this is in the test plan.

Consider the following in developing a version skew strategy for this
enhancement:
- During an upgrade, we will always have skew among components, how will this impact your work?
- Does this enhancement involve coordinating behavior in the control plane and
  in the kubelet? How does an n-2 kubelet without this feature available behave
  when this feature is used?
- Will any other components on the node change? For example, changes to CSI, CRI
  or CNI may require updating that component before the kubelet.

## Implementation History

Major milestones in the life cycle of a proposal should be tracked in `Implementation
History`.

## Drawbacks

The idea is to find the best form of an argument why this enhancement should _not_ be implemented.

## Alternatives

Similar to the `Drawbacks` section the `Alternatives` section is used to
highlight and record other possible approaches to delivering the value proposed
by an enhancement.

## Infrastructure Needed [optional]

Use this section if you need things from the project. Examples include a new
subproject, repos requested, github details, and/or testing infrastructure.

Listing these here allows the community to get the process for these resources
started right away.
