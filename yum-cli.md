# Design for yum/dnf frontend to rpm-ostree

Extracted from https://github.com/coreos/rpm-ostree/pull/2844

## Goal: Be friendlier to admins coming from existing Fedora-derivative ecosystem

I've come to the conclusion that we need to be friendlier
to people who are transitioning from existing yum/dnf
systems. Just saying `yum: command not found` is harsh.

And moreover, there are some things that really *should* work.
Let's take as an example: https://tailscale.com/download/linux/fedora
This is exactly an operating system extension; it doesn't
make sense in `toolbox` or `flatpak`. (It could be containerized
but...let's leave that aside)

The basic goal here is not that `dnf install tailscale` actually works
directly, but it should explain to people what to do.  More on
this below.

## Implementation

Note that the implementation of this will be that `rpm-ostree` gains
a new partial compatible `yum` CLI written in Rust.  There are no
plans to require Python for example, or change the existing `yum/dnf`
code.

(Note: The terms `yum` and `dnf` are used synonymously here because
 in practice in current Fedora and RHEL8 the former is just a symlink to the latter.)

Longer term, we may share more CLI code with "dnf 5" as it migrates to C++,
though this clashes some with rpm-ostree's increasing migration to Rust.

## Non-goal: Reverting emphasisis on containerization

We want people to migrate application code, debugging and development
tools etc. into containers as opposed to layering everything on the host.
So to emphasize: we explicitly do not want `yum install gcc` or `dnf install tailscale`
to silently Just Work out of the box.  More on this below.


## Demonstration CLI examples:

### upgrades

```
$ yum update
Note: This system is image (rpm-ostree) based.  Upgrades queue in the background
by default and will not affect the running system.
...
```

On Fedora CoreOS with automatic upgrades on by default, this would of course error out with:
```
error: Updates and deployments are driven by Zincati (zincati.service)
See Zincati's documentation at https://github.com/coreos/zincati
Use --bypass-driver to bypass Zincati and perform the operation anyways
```

So one would then use e.g.:
```
$ yum update --bypass-driver
```

On current Fedora IoT/Silverblue which do not have automatic upgrades on by default:

```
$ yum update
Receiving objects: ...
Upgraded:
  kernel 5.12.6-300.fc34 -> 5.12.8-300.fc34
  openssh 8.5p1-2.fc34 -> 8.6p1-3.fc34
Completing upgrade requires a reboot.
Partial upgrade can be initiated via `yum apply-live`.
```

Note this proposed text includes analysis of whether the change requires a reboot or not, as well as stabilization of `apply-live`.

```
$ yum apply-live openssh
Applying: openssh 8.5p1-2.fc34 -> 8.6p1-3.fc34
Reloaded: openssh.service
```

### Layering

```
$ yum install gcc
Note: This system is image (rpm-ostree) based.
Before installing packages to the host root filesystem, consider other options:

 - `toolbox`: For command-line development and debugging tools in a privileged container
 - `podman`: General purpose, isolated containers
 - `flatpak`: For desktop (GUI) applications
 - `rpm-ostree install`: For packages which need to be directly on the host. Treat these as "OS extensions". Add `--apply-live` to immediately start using the layered packages.
```

(Exit code 1)

```
$ sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo
Note: This system is image (rpm-ostree) based.
Assuming use of rpm-md repository for operating system extensions.
$ sudo dnf install tailscale
(error text as above)
$ rpm-ostree install -A tailscale
$ sudo systemctl enable --now tailscaled
$ sudo tailscale up
```


### Replacing base components

Background: User is trying to downgrade the kernel on a machine to bisect an issue.

```
$ yum install ./kernel-5.12.6-300.fc34.x86_64.rpm
Note: This system is image (rpm-ostree) based.
The following packages are part of the base image and require
explicit action to override:

 - kernel

To complete this action, use:
  rpm-ostree override replace ./kernel-5.12.6-300.fc34.x86_64.rpm
$ rpm-ostree override replace ./kernel-5.12.6-300.fc34.x86_64.rpm
Downgraded:
  kernel 5.12.8-300.fc34 -> 5.12.6-300.fc34
...
Completing changes requires a reboot.
$
```

### Upgrading just individual packages

```
$ yum update openssh
```

The flow for this will encourage the user to download the full base image
update, and cherry pick just the `openssh` change live if desired via
`apply-live`.
