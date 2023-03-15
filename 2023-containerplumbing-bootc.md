---
author: Colin Walters
title: bootc - A new project for bootable containers
date: March 23, 2023
---

<!-- https://fedorapeople.org/~walters/devconf-rpmostree2022.html -->

### Who/why?

- Colin Walters, Red Hat, Inc. - Fedora/OpenShift/RHEL/CoreOS engineer
- [Why](https://blog.verbum.org/2021/03/05/why-i-work-on-openshift-and-fedora-rhel/): Computing essential to society, FOSS essential to control computing

### Overview

- Transactional background OS upgrades to keep computers up to date
- Separating applications into containers helps upgrades (of host, but also apps)

### <a href="https://fedorapeople.org/~walters/devconf-rpmostree2022.html">Previously at DevConf.cz (virtual 2022)</a>

- Presented and demoed work on bootable containers that can be transactionally updated
- At the time it was classified as experimental

### So what changed in the last ~year?

- The "ostree native container" bits stabilized; we <a href="https://docs.openshift.com/container-platform/4.12/post_installation_configuration/coreos-layering.html#coreos-layering">shipped it in OpenShift 4.12</a>
- People are <a href="https://github.com/ublue-os/">using it for desktops</a>
- [Official Fedora Silverblue|Kinoite containers exist](https://pagure.io/releng/issue/11047#comment-846915)
- We ship "reproducible chunked" images from `rpm-ostree compose image` for somewhat reasonably efficient downloads
- There are [examples](https://github.com/coreos/layering-examples)
- And more!

### But...

- The name "rpm-ostree" is *very literal* and suddenly becomes misleading when we're talking about containers
- While "ostree native container" makes sense...actually it's also a toplevel goal to "hide" ostree

### Hmmm...this is a big change in direction

- All the work to handle "client side" customization in rpm-ostree (package layering) is no longer a focus (but it will continue to work)
- It just makes sense to align with [containers](github.com/containers/) more and more at a technical *and* branding level

### Introducing bootc!

- [New bootc project](github.com/containers/bootc)
- A "fresh new coat of paint" in terms of CLI and implementation on top of existing [ostree container](https://github.com/ostreedev/ostree-rs-ext/#module-container-bridging-between-ostree-and-ocidocker-images) bridge

### How do I use it?

- Install the binary on your host
- `rpm-ostree upgrade` → `bootc upgrade` 
- `rpm-ostree rebase` → `bootc switch`
- [Tracker: opinionated automatic updates](https://github.com/containers/bootc/issues/5)

### Less is more!

- No dependency on rpm
- ostree is a hidden implementation detail; if you have to understand it *we have failed*

### No operating system left behind

- Seamless in-place switch from existing ostree systems!

### bootc install: Actually there is more

- bootc [started out around 500 LoC](https://github.com/containers/bootc/commit/3ab28788ce3a3fe7a57152c57e28ff6e2a36df14); most heavy lifting is in ostree-rust and `skopeo`
- Solving "how do I use it": `podman run --privileged ... ghcr.io/cgwalters/c9s-oscore bootc install /dev/nvme0n1`
- (Though, now there's ~3200 LoC)

### bootc install: How it works

- Creates ESP, installs grub, etc.  *Only* handles simple cases!
- Opinionated install of root filesystem; can boot into target OS and dynamically create other partitions
- There's something neat going on here: Your custom OS container image comes with a *free* installer!
- *Demo time*

### Also bootc install-to-filesystem

- RAID, Stratis, dm-multipath: Use a separate installer
- We're not going to ship a GUI obviously; but those can use this as a backend
- Both of these things are (vaguely) planned for e.g. [Anaconda](https://github.com/rhinstaller/anaconda/)

### What's next

- [A CentOS SIG](https://lists.centos.org/pipermail/centos-devel/2023-March/142809.html) "pairing" with upstream bootc
- But upstream bootc aims to be distro-independent!  Let's see how that goes 😃
- [ConfigMaps and Secrets](https://github.com/containers/bootc/issues/22) (live updates too?)
- [apply-live](https://github.com/containers/bootc/issues/76)

### Belated status

- This project is mainly just me, in my 12.7% time
- I use it to update my desktop, but...probably not "production ready" yet
- The CLI may change!  (Though unlikely)

### What will the next year bring?

- I think current trajectory may be able to stabilize by EOY?
- Obviously, hoping to gather other interested people (and OS/distros) to contribute!

### Links

- [bootc](https://github.com/containers/bootc)
- [centos-devel for SIG discussions](https://lists.centos.org/pipermail/centos-devel/)

Questions?

