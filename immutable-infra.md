# "Immutable" infrastructure

This is going to be a longer blog entry, but here's a TL;DR:

I propose that instead of "immutable" or "read-only" when talking about operating systems (such as [Fedora CoreOS](https://getfedora.org/en/coreos/), [Google COOS](https://cloud.google.com/container-optimized-os/docs) etc.), we use these terms:

 - "fully managed": The system does not have "unmanaged state" - e.g. an admin interactively doing `ssh` and making changes not recorded declaratively somewhere else
 - "image based": Traditional package managers end up with a lot of "hidden state" (related to above); image based updates avoid that
 - "Has anti-hysteresis properties": (Yes I know this is an awkward term) See https://en.wikipedia.org/wiki/Hysteresis - I'll talk more about this later

## Why not "immutable"/"read-only"?

Because it's very misleading.  These system *as a whole* is not immutable, or read-only, or stateless - there are writable, persistent data areas.  And more importantly, those writable data areas allow *persistently storing privileged code*.  They have to because these OSes need to support **the user being root on their own computer**.

## But /usr is read-only!

Yes.  And this does have some security benefits, e.g. [this runc vulnerability](https://kubernetes.io/blog/2019/02/11/runc-and-cve-2019-5736/) isn't exploitable.

But in order for the operating system to be updated in place, there must be *some* writable area to add new OS content - so it's not immutable.  The details of this vary; e.g. some "image based" operating systems use dual partitions, [OSTree](https://github.com/ostreedev/ostree) is based on hardlinking with a "hidden" writable data store.

The real reason to have a read-only `/usr` is to make clear that the content of that directory (the operating system binaries) are "fully managed" or "owned" by the OS creator - you shouldn't try to overwrite or replace parts of it because those changes could be overwritten by a future update.

And this "changes in /usr being overwritten" is a real existing problem with traditional package-manager (`apt`/`yum`/etc) based systems.  For example, a while ago I was looking at Keylime and came across [this bit in the installer](https://github.com/keylime/ansible-keylime-tpm-emulator/blob/3b482839708675d7fdf8c25323645d56b9b36152/roles/ansible-keylime-tpm20/tasks/ibm-tpm.yml#L46).  That change would be silently overwritten by the next `yum/apt` update, so the system administrator experience would be:

- Provision system
- Install things (including keylime)
- ⌛ Time passes
- Apply OS updates (not on by default), then keylime breaks
 
The more correct thing instead would be for that playbook to write a [systemd drop in](https://www.freedesktop.org/software/systemd/man/systemd.unit.html) in `/etc` to override just `ExecStart=`, although even doing that is fragile and what'd be best desired here is to make this an explicitly configurable option for `tpm2-abrmd`.

The overall point is that the reason `/usr` read-only is *primarily* to enforce that user configuration is cleanly separate from the OS content - which becomes particularly important when OS updates are automatic by default, as they are in Fedora CoreOS.

(Aside: I think having automatic updates on by default fundamentally changes the *perception of responsibility* around updates; if I'm a system administrator and I typed `apt/yum update` and things broke, it's my fault, but if updates are on by default and I'm doing something else and the machine just falls over - it's the OS vendor's fault.  Linking these two together: Since FCOS has automatic updates on, we need to be clear what's our responsibility and what's yours)

Now, this isn't a new problem, and most people maintaining systems know not to do the kinds of things that Keylime Ansible playbook is doing.  But it's an extremely easy mistake to make without strong discipline when `/usr` is sitting there writable by any process that runs as root.

Nothing actually stops traditional package managers from mounting `/usr` read-only by default - they could do the equivalent of `unshare -m /bin/sh -c 'mount -o remount,rw /usr && apt update`' internally.  But the challenges there grow into adjusting the rest of the filesystem layout to handle a readonly `/usr`, such as how [OSTree suggests moving /usr/local to /var/usrlocal](https://ostree.readthedocs.io/en/latest/manual/adapting-existing/) etc.

## Image based updates

Usually instead of talking about an "immutable" system, it'd be more useful and accurate to say "image based". 

And this gets into another huge difference between traditional package managers and image based systems: The amount of "internal state".

The way most package managers work is when you type `$pkgmgr install foo`, the fact that you want `foo` installed is recorded by adding it to the database.  But the package manager database *also* includes a whole set of "base packages" that usually *you didn't choose*.  Those "base packages" might come from a base container when you `podman/docker pull`, or for physical systems they often come from a distribution-specific default list embedded in the installer or downloaded.

A problem with this model then is "drift" - by default if the distribution decides to add a package to the base set by default, you don't get it by default.  One solution to this is [metapackages](https://help.ubuntu.com/community/MetaPackages), but if not everything in the base is covered you still have drift that can be hard to notice over time.

I think for many package managers like yum/apt this "initial state" is hard to disentangle from things you typically *do* care about like the packages you chose to install.  There is e.g. `apt-mark showmanual` and `dnf history userinstalled` commands.

And...trying that out by pulling the `docker.io/debian:stable` image, it claims:

```
# apt-mark showmanual
iproute2
iputils-ping
#
```

And that's the first command I ran in the image; clearly a bug somewhere.  For the `fedora:32` base image it lists a bunch of packages.

One solution to this type of "drift" is to not use packages at all (pure "base OS" + "apps/containers") like Google COOS, or to group things at a higher level (Clear Linux is more in this bucket).

I'm pretty happy though with the design we came up with for rpm-ostree; there is a clear "base image" that comes via OSTree, and you can add packages on top - really, recasting RPMs as "operating system extensions".  The great thing is that there's very little "hidden" state like user installed packages.  `rpm-ostree status` tells you everything you need to know.  You can see an example of this in [this recent LWN article](https://lwn.net/Articles/828966/).  And at any point you can reset exactly back to the "base image" with `rpm-ostree reset`.

It's interesting to contrast with the docker/podman situation because there the 
