# "Immutable" infrastructure

This is going to be a longer blog entry, but here's a TL;DR:

I propose that instead of "immutable" or "read-only" when talking about operating systems (such as [Fedora CoreOS](https://getfedora.org/en/coreos/), [Google COOS](https://cloud.google.com/container-optimized-os/docs) etc.), we use these terms:

 - "fully managed": The system does not have "unmanaged state" - e.g. an admin interactively doing `ssh` and making changes not recorded declaratively somewhere else
 - "image based": Traditional package managers end up with a lot of "hidden state" (related to above); image based updates avoid that
 - Has "anti-hysteresis": See https://en.wikipedia.org/wiki/Hysteresis - I'll talk more about this later

## Why not "immutable" and "read-only"?

Because it's very misleading.  These system *as a whole* is not immutable, or read-only, or stateless - there are writable, persistent data areas.  And more importantly, those writable data areas allow *persistently storing privileged code*.  They have to because these OSes need to support **the user being root on their own computer**.

## But /usr is read-only!

Yes.  And this does have some security benefits, e.g. [this runc vulnerability](https://kubernetes.io/blog/2019/02/11/runc-and-cve-2019-5736/) isn't exploitable.

But in order for the operating system to be updated in place, there must be *some* writable area - so it's not truly immutable.  The details of this vary; e.g. some "image based" operating systems use dual partitions, [OSTree](https://github.com/ostreedev/ostree) is based on hardlinking with a "hidden" writable data store.

The real reason to have a read-only `/usr` is to make clear that the content of that directory (the operating system binaries) are "fully managed" by the OS creator - you shouldn't try to overwrite or replace parts of it because those changes could be overwritten by a future update.

And this "changes in /usr being overwritten" is a real existing problem with traditional package-manager (`apt`/`yum`/etc) based systems.  For example, a while ago I was looking at Keylime and came across [this bit in the installer](https://github.com/keylime/ansible-keylime-tpm-emulator/blob/3b482839708675d7fdf8c25323645d56b9b36152/roles/ansible-keylime-tpm20/tasks/ibm-tpm.yml#L46) - and that change would be silently overwritten by the next `yum/apt` update.  The correct thing instead would be for that playbook to write a "systemd drop in" in `/etc` to override just `ExecStart=`, although even doing that is fragile and what's really desired here is to make this an explicitly configurable option for `tpm2-abrmd`.