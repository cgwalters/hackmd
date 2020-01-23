---
author: Colin Walters
title: Fedora CoreOS PXE
date: January 23, 2020
---

### Who/what/why?

- Taking over talk from Andrew Jeddeloh, (former) Ignition maintainer
- Colin Walters, Red Hat, Inc. - CoreOS/OpenShift engineer

### Fedora

- Leading edge operating system
- Great place to contribute
- Upstream for RHEL
- Not just a desktop!

### OS/distros over time

- Operating system role changing
- In IT, historical layers accumulate
- Containerization and virtualization

### (Fedora) CoreOS

- Container focused server OS
- Successor to Container Linux (original CoreOS) and FAH
- Upstream to RHEL CoreOS
- [Part of Fedora](https://getfedora.org/en/coreos/)
- Now [out of preview](https://fedoramagazine.org/fedora-coreos-out-of-preview/)!

### CoreOS Ingredients

- Ignition
- (rpm)-OSTree
- Automatic updates on by default (*)
- Container focused

### PXE

- Bare metal usage
- i.e. FCOS not just for clouds!
- Control over your computers
- Live image is just another FCOS image type

### PXE (actually)

- BIOS/firmware broadcasts a DHCP request
- Server provides kernel/initramfs over network
- Ignition runs in initramfs
- FCOS rootfs in initramfs (squashfs)

### [Live PXE config](https://docs.fedoraproject.org/en-US/fedora-coreos/bare-metal/#_live_pxe)

```
LABEL pxeboot
    KERNEL fedora-coreos-30.20191014.1-live-kernel-x86_64
    APPEND ip=dhcp rd.neednet=1 initrd=fedora-coreos-30.20191014.1-live-initramfs.x86_64.img console=tty0 console=ttyS0 ignition.firstboot ignition.platform.id=metal ignition.config.url=http://192.168.1.101/config.ign
IPAPPEND 2
```

### Live PXE Demo

- [FCOS downloads](https://getfedora.org/en/coreos/download/)
- virt-manager direct kernel boot

### Live PXE details

- "live": OS runs from RAM
- May or may not have disks
- Currently OS is in the initramfs
- Compare w/Anaconda

### Why Live PXE

- On-premise diskless compute
- "stateless"
- Package e.g. numerical simulations as containers
- BYO orchestration

### Why not Live PXE

- Need to script downloading and using PXE images
- BYO orchestration
- Not primary path
- Monthly/periodic reprovisioning is practical too
- If truly stateless, updates are more expensive

### Crafting Ignition

- ssh keys, users, networking
- (optional) partitioning
- Private CA certificates
- systemd units to run podman

### Separate /var with Live PXE

- Ignition can create-or-reuse for a partition
- Mix tradeoffs
- ➕ e.g. don't need to re-pull containers
- ➕ unused files can be paged out
- ➖ Turning off/on again may not fix it
- Keep Ignition config, tar up /var and move it somewhere else

### RHCOS and OpenShift

- Live image not shipped by RHCOS (yet)
- No plans to use in OpenShift 4 yet (but maybe)
- Would need machine-config-operator awareness

### In conclusion

- Fedora CoreOS (incl. Live PXE) available now!
- https://getfedora.org/coreos/

<!-- ----

PREVIOUS NOTES
===

Have Live OS setup in FCOS
---

Fresh OS with ignition run each boot, but 
https://github.com/coreos/ignition/blob/master/doc/operator-notes.md
state in ``/var`

More advanced:
- [Can't use RAID](https://github.com/coreos/ignition/issues/579)


Advantages:
 - Harder for persistent OS compromise
 - No config drift
 - Simple

Disadvantages:
 - Slower boots
 - Must download/set up new OS image for updates (but can w/iPXE point directly at Internet)
 - Don't append to files in /var


Config merging:

- Leaf configs can affect Ignition section for parents
    - if a child config is merged with a CA cert, then that cert can be used to fetch other configs
- How merging works with files/links/directories


Platform independence of persistent data: Boot w/qemu, persistent storage, boot in AWS


Testing PXE:
- https://gist.github.com/cgwalters/bf6f5b6f788d01211dbe6cd362309a0d
- https://gist.github.com/ajeddeloh/15470b6e9b042bb89b00d88627c6216e

-->