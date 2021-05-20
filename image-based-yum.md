# "Image based yum/dnf" with containers

This proposal encapsulates two large sub-proposals that are conceptually orthogonal, but make the most sense together.

### "rpm-ostree native container support"

See [this issue](https://github.com/coreos/fedora-coreos-tracker/issues/812).  The TL;DR is that rpm-ostree learns to support "encapsulating" ostree commits (OS update images) inside container images, without throwing away everything we have today.

### rpm-ostree implements parts of /usr/bin/{yum,dnf} CLI

See [this PR](https://github.com/coreos/rpm-ostree/pull/2844).  Basically logging into an rpm-ostree based system and typing `yum update` for example would silently Just Work instead of saying "command not found".  We need to debate exactly what `yum install` would do; the PR so far adds some informative text, but exposes package layering as `yum install-extension`.


## 2022 user story

The goal here is that by the start of 2022, we start talking about how we're shipping an "image based yum" that uses ostree, encapsulates OS updates in containers, and is increasingly written in Rust for safety.

We wouldn't rename the `rpm-ostree` project, but the name makes much less sense once we start interacting with container images; it can't be `rpm-ostree-containers`.


## Why?

For everyone in the ecosystem, even inside Red Hat, understanding RPM, ostree *and* container images is very difficult.  For example, people doing release engineering.  In OpenShift 4 we already made the step of encapsulating ostree in a container (just not in great way), this takes that much further.

To rephrase [this bit](https://github.com/ostreedev/ostree-rs-ext/#allow-hiding-ostree-while-not-reinventing-everything) - we're still using ostree, but we're fading it into the background much more and greatly reducing the need for everyone touching the OS to understand it.

Another good example here is for a RT kernel engineer who needs to install a custom kernel for debugging, we will make it so that `yum install ./kernel-rt-custom.rpm` Just Works - or at least, tells you to use e.g. `yum install --override-base-image ./kernel-rt-custom.rpm` or so.

Going forward we'd try to increase sharing of interfaces/code with the traditional `yum/dnf` much more than we are today, and cross-reference both projects more.
