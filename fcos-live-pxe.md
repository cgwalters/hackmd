Advanced Fedora CoreOS PXE
===

https://devconfcz2020a.sched.com/event/YT0S/advanced-ignition-live-pxe-and-chaining-configs

Who/what/why?
---

- Taking over talk from Andrew Jeddeloh, (former) Ignition maintainer
- Colin Walters, Red Hat, Inc. - CoreOS/OpenShift engineer

Fedora
---

- Leading edge operating system
- Great place to contribute
- Upstream for RHEL
- Not just a desktop!

OS/distros over time
---

- Operating system role changing
- In IT, historical layers accumulate
- Containerization and virtualization

(Fedora) CoreOS
---

- Container focused server OS
- Successor to Container Linux (original CoreOS)
- Upstream to RHEL CoreOS
- Part of Fedora
- Now just out of preview!

(Fedora|RHEL) CoreOS
---

- Ignition
- (rpm)-OSTree
- Automatic updates on by default
- Container focused

PXE
---

- Bare metal usage
- i.e. FCOS not just for clouds!
- Control over your computers
- Live image is just another FCOS image type
- BIOS/firmware broadcasts a DHCP request
- Server provides kernel/initramfs over network

Live PXE for real
---

- May or may not have disks
- "live": OS runs from RAM
- Currently OS is in the initramfs
- Compare w/Anaconda

Why Live PXE
---

- On-premise diskless compute
- Package e.g. numerical simulations as containers
- BYO orchestration

Why not Live PXE
---

- Need to script downloading and using PXE images
- If truly stateless, updates are more expensive






----

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