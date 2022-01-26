---
author: Colin Walters
title: What's new in rpm-ostree - 2022 Edition!
date: January 23, 2022
---

<!-- https://devconfcz2022.sched.com/event/siFe/whats-new-in-rpm-ostree-2022-edition -->

### Who/what/why?

- Colin Walters, Red Hat, Inc. - Fedora/OpenShift/RHEL/CoreOS engineer
- Why: FOSS is essential to computing

### Overview

- Transactional, automatic, safe OS upgrades
- Image based by default, but [still a Linux system](https://blog.verbum.org/2019/12/23/starting-from-open-and-foss/)
- Separating applications into containers helps upgrades

### Where's rpm-ostree used today?

- RHEL: for Edge
- OpenShift 4
- Fedora Silverblue and derivatives/sibilings

- ostree: lots of places

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
- Why: Create a bridge between worlds
- How: ~6000 lines of new Rust code in [ostree-rs-ext](https://github.com/ostreedev/ostree-rs-ext/), including a [proxy to the containers/Go ecosystem](https://github.com/containers/containers-image-proxy-rs/).

### Rethinking rpm-ostree systems as *base images*

- Note: **Everything that works today will continue to work**
- Server side package layering...but also bind configuration and code
- Also, inject non-RPM content

### Status: Works, but still experimental

- Breaking changes may occur, e.g. [container commit](https://github.com/ostreedev/ostree-rs-ext/issues/159)
- But please do try it out!

