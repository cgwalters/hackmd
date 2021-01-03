# rpm-ostree v2021.1

A goal of rpm-ostree is to *empower* users and developers.  Being able to fearlessly have automatic updates on and know that if your system loses power or the kernel freezes in the middle everything will be OK - that's empowering!  But some implementation choices led to other restrictions that weren't intentional, just bugs.  In this release we've made a large advance in lifting one of the biggest restrictions, read on:

## rpm-ostree ex apply-live

In this release the functionality formerly known as `rpm-ostree ex livefs` is now known as `rpm-ostree ex apply-live`, and it's been placed on a much firmer technical foundation and is considered very safe to use.  It's still under `ex` because we may make some interface changes, and we hope to gather feedback.

One can often see in discussions people say something of the form "with rpm-ostree you need to reboot for updates".  But that's never been true in general, because the goal is to move most software to containers.  Rather than having e.g. `gcc` as part of your root filesystem (in ostree), you have it in your development container updated independently from the host.  Server and desktop applications run as containers, etc.

For all the software that *is* part of the host though, our story until recently has been incomplete.  We've had `rpm-ostree usroverlay` for a long time, which can be very convenient for testing things.  But a core problem is that rpm-ostree has no idea what's happening in the transient writable layer, and further we didn't offer any tools to make changes there.

For example, if you use `rpm-ostree usroverlay` and then `rpm -Uvh https://example.com/some.rpm`, `rpm-ostree status` doesn't show it as layered - it won't persist across upgrades and reboots if you did want that.

Now you can combine e.g.

```
$ rpm-ostree install fish
$ rpm-ostree ex apply-live
```

And have the newly layered `fish` package appear both for the *next* boot (persistently) as well as your running filesystem.  An obvious thing to add will be `rpm-ostree install --apply-live fish` once we stabilize the interface (which will likely be soon).

### Implementation

The big change in implementation that makes this very safe is that changes to the running filesystem tree go into an overlayfs with the upper directory being temporary.  We no longer create a rollback deployment; rebooting will return the previously-booted deployment to its original state.  More information in [this ostree PR](https://github.com/ostreedev/ostree/pull/2103) and an example below.

### Still readonly

One thing that *hasn't* changed (compared to previous `ex livefs`) is that `/usr` is still mounted read-only from the perspective of the rest of the system.  It's worth emphasizing this!  In this model, rpm-ostree is still in full control, `rpm-ostree status` is showing you truth, etc.

### Testing fixes

However this isn't just for layered packages; let's take the example of something commonly shipped in a base image like [NetworkManager](https://gitlab.freedesktop.org/NetworkManager/NetworkManager), [podman](https://podman.io/), or [OpenSSH](https://www.openssh.com/).

Say you're running Fedora CoreOS stable, and you want to test a fix for podman that's in [the testing stream](https://docs.fedoraproject.org/en-US/fedora-coreos/update-streams/).  After you've run e.g. `rpm-ostree rebase fedora/x86_64/coreos/testing` you can now confidently `rpm-ostree ex apply-live` to switch your running filesystem to that without rebooting and start running `podman` commands.  Then you can report success/failure to an upstream issue or bug.

## override replace https://bodhi/...

Another notable feature in this release is support for directly pulling builds from current Fedora testing/build tools [Bodhi](https://bodhi.fedoraproject.org/) and [Koji](https://koji.fedoraproject.org/koji/).

A longstanding tension that rpm-ostree has created is that we want to test the *whole* build (ostree commit) that is shipped to users, but Bodhi is oriented around per-package changes.  Switching to a `testing` stream pulls in everything.  That's how it's shipped to users so we need to test it, but it also means you're testing everything at once.

Now with rpm-ostree v2021.1 you can run e.g.:

```
$ rpm-ostree override replace https://bodhi.fedoraproject.org/updates/FEDORA-2020-2908628031
```

to directly pull in a single Bodhi update applied relative to your booted system (presumably a `stable` stream) without changing anything else.   You can also pull in Koji builds (that may or may not be Bodhi updates):

```
$ rpm-ostree override replace https://koji.fedoraproject.org/koji/buildinfo?buildID=1625029
```

This allows you to more directly interact with Bodhi's current model of testing individual updates.

Note that like all usage of `override replace`, these versions are "pinned" until explicitly removed with a variant of `rpm-ostree override reset`.

## Combining features

And of course, the above two headlining features combine!  Let's say that you're a Fedora Silverblue user, and you're hitting a WiFi issue that is claimed to be fixed in an updated NetworkManager.   With a combination like:

```
$ rpm-ostree override replace https://bodhi.fedoraproject.org/updates/FEDORA-<updateid>
$ rpm-ostree ex apply-live
$ systemctl restart NetworkManager
```

You can quickly test out that change.

What's powerful about using rpm-ostree for this is that if e.g. something goes wrong and the updated NetworkManager is crashing or nonfunctional, you still have the base version from the booted deployment!  There's no need to carefully save previous versions or keep a recovery USB key on hand.  To undo the above:

```
$ rpm-ostree override reset -a       # note actually resets all overrides
$ rpm-ostree ex apply-live
$ systemctl restart NetworkManager
```

But let's look at a more problematic scenario: starting the updated NetworkManager triggers a latent bug in your specific laptop's WiFi card driver, causing a kernel panic and system lockup.

In this scenario, *all you need to do is reboot* (e.g. hold power button for 5 seconds on most PCs) and you will be back exactly to the previous deployment with the working kernel+NetworkManager combination.  You don't even need to manually stop at the bootloader menu to choose a previous deployment!

The reason for this is the overlayfs approach mentioned above; the "live applied" changes are written to a transient overlay rather than changing the persistent filesystem (underlying deployment).

## Other changes

### Internals: FFI and Rust

As you might imagine for rpm-ostree, a project very focused on safety and resilience, the [Rust programming language](https://www.rust-lang.org/) has been very attractive.  Our first Rust code [landed in Jun 2018](479406e6a587809cd38550745c6f74d680d7c809), and since then we've tried to write new code in Rust where possible.  However, our FFI (cross language) calls between C and Rust have required manually written `unsafe` "bridge" code, and this greatly limited the ergonomics of using Rust.  It happened a few times that trying to move some code might initially require more unsafe glue code than actual Rust.

Since the last release, we are working on switching to [cxx.rs](https://cxx.rs/), which has the compelling feature of supporing fully safe bidirectional calls between C++ and Rust.  The obvious hurdle in rpm-ostree using C (mostly, except for libdnf) was solved by reworking our C code to be "C that builds as C++" to start.

To be clear, the goal here is to greatly accelerate our transition to Rust.  The goal is *not* to try to rewrite our "C in C++ mode" code to modern C++.  The latter doesn't offer the memory safety (not to mention ergonomics, libraries, tooling, etc.) that Rust does.
