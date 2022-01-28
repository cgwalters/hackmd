---
author: Colin Walters
title: What's new in rpm-ostree - 2022 Edition!
date: January 23, 2022
---

<!-- https://devconfcz2022.sched.com/event/siFe/whats-new-in-rpm-ostree-2022-edition -->

### Who/what/why?

- Colin Walters, Red Hat, Inc. - Fedora/OpenShift/RHEL/CoreOS engineer
- Why: Computing essential to society, FOSS essential to control computing

### Overview

- Transactional background OS upgrades
  <!-- Either old or new; background: won't disrupt running system -->
- Image based by default, but [still a Linux system](https://blog.verbum.org/2019/12/23/starting-from-open-and-foss/)
- Separating applications into containers helps upgrades
- Good integration with RPM because we can't change (our subset of the) world at once
  <!-- Same kernel!  Replacing it is first class -->

### Where's rpm-ostree used today?

- [RHEL For Edge](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/composing_installing_and_managing_rhel_for_edge_images/introducing-rhel-for-edge-images_composing-installing-managing-rhel-for-edge-images)
- [OpenShift 4](https://github.com/openshift/machine-config-operator/)
- [Fedora Silverblue](https://getfedora.org/en/silverblue/) and derivatives/sibilings
- Derivatives of the above

- Uses [ostree](https://github.com/ostreedev/ostree/) (separate project!): lots of places; Debian/OpenEmbedded derivatives too

### What's actually new in the last ~year?

- [OSTree native containers](https://fedoraproject.org/wiki/Changes/OstreeNativeContainer)
- Increasing oxidation (conversion to Rust)
- Finally support for modularity
- Reproducible builds
- Big shuffle of support for sqlite rpmdb
- Respect systemd inhibitors for `rpm-ostree upgrade -r`
- DNF Count Me support

### What's actually new page 2

- [2021.1](https://github.com/coreos/rpm-ostree/releases/tag/v2021.1): `ex apply-live` 
- [2021.3](https://github.com/coreos/rpm-ostree/releases/tag/v2021.3) `rpm-ostree install -A` stabilized 🎉
- Also in that release, we switched to a Rust app with C++ library

### OK more about ostree native containers

- What: `FROM quay.io/fedora/coreos RUN rpm-ostree install usbguard && ADD usbguard.conf`
- Why: Create a bridge between worlds ("pristine/golden/immutable" host, traditional OS)
  <!-- Agents, security tools -->
- Also between container stack and host
- How: ~6000 lines of new Rust code in [ostree-rs-ext](https://github.com/ostreedev/ostree-rs-ext/), including a [proxy to the containers/Go ecosystem](https://github.com/containers/containers-image-proxy-rs/).

### Rethinking rpm-ostree systems as *base images*

- Note: **Everything that works today will continue to work**
- (Except we will probably switch Fedora and derivatives to transport via container image)
- One might think of this as "Server side package layering"...but also bind configuration and code
- Also, inject non-RPM content!  Should be equally "first class".
- Could also e.g. derive Fedora Silverblue from FCOS

### Status: Works, but still experimental

- **Breaking changes may occur**, e.g. [container commit](https://github.com/ostreedev/ostree-rs-ext/issues/159) and we may change the format.
- But please do try it out!

### More on the (configuration, code, state) 3-tuple

- Corresponds to `/etc`, `/usr`, `/var`
- OSTree operates on `/etc` and `/usr`, will never ever touch `/var`
- The "base images" we ship are unconfigured (obviously!).  Configuration
  systems: Anaconda (often paired with something else), Ignition (or cloud-init)
- With this model, you can exactly **bind your configuration
  with your code as a container image**.
  <!-- Your configs can go in /etc and get updated -->
  <!-- TBD: secrets -->
- Big change vs Ignition's "configure once" model 
- Related: NixOS, OpenShift MCO, Ansible

### User story

- Build a container with preferred OS state
- Boot from our disk images, early at install/boot run
  `rpm-ostree rebase ostree-unverified-registry:quay.io/example/custom:latest --reboot`
- Probably expose ability to go container → disk image in e.g. Image Builder and the like

### What will happen in 2022?

- Several people are committed to layering
- But willing to help with other PRs!
- Would like to push forward more docs and `ex apply-live`,
  continue oxidation.  And [rethinking origins](https://github.com/coreos/rpm-ostree/issues/2326).

### Links

- [rpm-ostree](https://github.com/coreos/rpm-ostree/)
- [ostree Rust extensions](https://github.com/ostreedev/ostree-rs-ext/)

Questions?

