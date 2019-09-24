Starting from open (and FOSS)
====

As our society becomes increasingly dependent on computing, the importance of security has only risen.  From cities hit by ransomware attacks, to companies doing cutting edge research that are the targets of industrial espionage, to individuals attacked because they have a desirable social media handle or are famous - security is vital to all of us.

When I first got into Linux and FOSS, I have strong memories of the variety of things enabled by the flexibility it enabled.  For example, the first year of college in my dorm room with 3 other people, we only had a shared phone line that we could use with a modem (yes, I'm old).  A friend of a friend ended up setting up a PC Linux box as a NAT system, and the connection was certainly slow, but it worked.  I think it ran Slackware.  That left an impression on me.  (Though the next year the school deployed Ethernet anyways)

Fast forward 20+ years, we have the rise of the cloud (and cheap routers and WiFi of course).  But something also changed about Linux (and operating systems in general) in that time, and that's the the topic of this post: "locked down" operating systems, of which the most notable here are iOS, Android and ChromeOS.

iOS in particular requires code signing - the operating system refuses to execute code not signed by Apple.  And iOS devices can only run iOS of course.

ChromeOS is also a locked-down system by default: While it uses the Linux kernel, it also comes out of the box set up such that the base operating systems only runs the binary ChromeOS builds which come entirely from Google.  This is implemented with dm-verity.  Android also uses the Linux kernel and has a similar setup, although the story of who owns what is more complicated - note in particular the support for privileged "APEX" apps which may be preloaded (and have their own dm-verity chain).

Now, ChromeOS has a documented developer mode - and in fact they've made this process easier than it used to be (previously it could require toggling a hardware switch, which also reset the device if I remember correctly).   Android has documented bootloader unlocking, although (again as I understand it) many popular phones come locked.

In contrast to these types of systems we have the "traditional" Linux distributions, the BSDs, etc.  Most Linux distributions are strongly associated with a "package manager" - which make it fast and easy to add software to your root filesystem.

The flip side of course, is it's also fast and easy for malicious code to end up in your root filesystem (or home directory) if you're running a vulnerable web browser or service, or you pull from untrusted sources, etc.  Particularly if you aren't diligent with upgrades (Though, I like to believe that overall, Linux-based OSes have been getting more secure over time).

Another way to look at this is - the [ChromeOS docs talk about "installing Linux"](https://support.google.com/chromebook/answer/9145439?hl=en).  One the face of it, this sounds silly because ChromeOS is a Linux kernel...but it's *not the flexible Linux* that I first encountered in college.

Where I'm going with this is that I think we need to incrementally move the "mainstream" distributions closer to this model - while preserving the fundamental open nature of the system.  This is in practice I think an extremely hard balance to strike, but we can do it.

Partition (containerize/virtualize)
---

The mainstream default needs to be containers and virtual machines.  This is obviously well understood, but doing it *in practice* is really an enormous shift from how "traditional" default Debian/RHEL/Slackware/Arch installs work.

In most of the Fedora documentation, it's extremely common to reference `sudo yum install`. 

Getting out of the mindset of routinely mutating your root filesystem is hard.  For people used to a "traditional" Linux system, partitioning is hard.  Changing systems management tools to work in this model is hard.  But we need to do it.

On the server side the rise of Kubernetes increasingly does mean that containerization is the default. For [OpenShift 4](https://try.openshift.com/) we created a derivative of Fedora CoreOS in [Red Hat Enterprise Linux CoreOS](https://docs.openshift.com/container-platform/4.1/architecture/architecture-rhcos.html) - I like to describe it as a "Kubernetes-native OS" in concert with the [machine-config-operator](https://github.com/openshift/machine-config-operator/).

For other use cases, we're doing our best to push the ecosystem in this direction with [Fedora CoreOS](https://getfedora.org/coreos/) (container oriented server but not Kubernetes native; e.g. can be used standalone) and other projects like the desktop-focused [Fedora Silverblue](https://silverblue.fedoraproject.org/).  (On the topic of partitioning the desktop, [QubesOS](https://www.qubes-os.org/) is also doing interesting, mostly complementary work)

One of the biggest shifts to make particularly for desktop systems like Silverblue is to live inside a "pet container" system like [debarshiray/toolbox](https://github.com/debarshiray/toolbox) or [my coretoolbox](https://github.com/cgwalters/coretoolbox).

When I see documentation that says `yum install foo` - I now default to doing that inside my toolbox container.  This works well for CLI applications.

But remain open
---

What we're *not* changing with Fedora CoreOS (or other projects) is a "default to open" model.  We will not (by default) for example require code executing our your device be signed by us.  Our source code and build systems are Free Software and will remain that way.  We will continue to discuss and write patches in the open, and ensure that we're continuing to build an operating system in open collaboration with our users.

Today for example, rpm-ostree supports easily replacing the kernel; you just `rpm-ostree override replace /path/to/kernel.rpm`.  Also, the fact that it's *the same kernel package* as "traditional" Fedora installs cannot be emphasized enough - it helps us sustain two different ways to consume the same OS content.

Further, while we continue to debate the role of package layering (`rpm-ostree install`) in Fedora CoreOS, one way to look at this is recasting RPMs as "operating system extensions", much like Firefox extensions.  If you want to `rpm-ostree install fish` (or e.g. PAM modules), you can do so. 

Extending the OS (and replacing parts for testing/development) are first class operations and will remain so; doing so works in a similar way to traditional package systems.  We aren't requiring other shells or PAM modules to containerize somehow, as that would be at odds with keeping the experience first class and avoiding "two ways to do it".

Finally, the [coreos-assembler](https://github.com/coreos/coreos-assembler/) project makes it easy to do fully custom builds.  Our focus of course is on providing a pre-built system that's useful to users, but our build process is pretty easy to replicate and will remain so.

Not tied in with proprietary cloud infrastructure
---

Another thing that needs to be stated here is we will continue to make an operating system that is not deeply tied into proprietary cloud infrastructure.  Currently in this area besides [update rollout infrastructure](https://github.com/openshift/cincinnati) we ship a [counting service](https://github.com/coreos/fedora-coreos-pinger) - the backing service is fully open, and it's easy to turn off.  In contrast of course, ChromeOS for example comes set up such that the operating system accounts are the same as Google cloud accounts.

Adding opt-in security
---

All of the above said; there are a lot of powerful benefits from the approach that ChromeOS/Android are taking with dm-verity (I believe iOS does something similar too).  I've been thinking recently about how we can enable this type of thing while "staying true to our roots".

One thing that's probably an ingredient of this is the [fs-verity](https://lwn.net/Articles/763729/) work which is also being driven by the ChromeOS/Android use case.  They are hitting issues with the inflexibility of dm-verity; per [these slides](https://events.linuxfoundation.org/wp-content/uploads/2017/11/fs-verify_Mike-Halcrow_Eric-Biggers.pdf) - "Intractable complexity when dealing with the Android partner ecosystem".  We can see the manifestation of this looking at the [new Android APKX files](https://arstechnica.com/gadgets/2019/09/android-10-the-ars-technica-review/#h9) - basically, there's a need for 3rd parties to distribute privileged code.  Currently APKX are loopback-mounted ext4 images with dm-verity, which is quite ugly.

fs-verity would mesh much more nicely with OSTree (which has always operated purely at the filesystem level) and other tools.

I haven't yet gotten around to writing an [fedora-coreos-tracker issue](https://github.com/coreos/fedora-coreos-tracker/issues/) for this - but I think a proposal would be something like built-in functionality that allows you to opt-in to a model where after the OS has booted and [Ignition](https://github.com/coreos/ignition) runs, no further privileged code not signed by a keychain including us and your keys could execute.  We'd ensure that the configuration in `/etc` was also part of a verified chain; since even if `/usr` is signed and verity protected, malware could persist in a systemd unit in `/etc` otherwise.  Some people would probably want an "emergency ssh" shell that bypassed this; others would not (perhaps the default would be that anyone who didn't want "emergency ssh" could simply disable the `sshd.service` unit).

For Silverblue, one thing I've been thinking about is ensuring that the user flow works well without `sudo` by default - and if you want to become root, you need to type Ctrl-Alt-Del (like Windows NT) and that switches you to a separate VT.  The reason is that compromise of the user account with `sudo` privileges is really the same as a `root` compromise.  You can't trust your terminal emulators or display (aside: QubesOS approaches this by running everything in VMs with labeled borders).  We need to have a default "safe key" exactly like the single button on an iPhone always takes you to the home screen - allows you to make changes, and applications can't intercept or control that key.

To reiterate, we need to more strongly separate the privileged OS content from your applications (containers/Flatpaks) and development tools by default.  But at the same time we should continue allowing the operating system to truly be owned by you should you so choose.  It's your hardware.

Most important: apply security updates by default
---

As alluded to above: I think one of the most important things we can do for security is simply getting to a world where security updates (*especially* for the operating system/root filesystem) are applied automatically by default.  That is of course the bold move that Container Linux did, and we will be preserving that with Fedora CoreOS. 

Doing automatic updates like that is much more tenable if it's decoupled from core applications, and also if it's fully transactional/safe as [rpm-ostree enables](https://github.com/coreos/rpm-ostree).

While there's still a lot of work on FCOS and derivatives like RHCOS to do; I think we've established that baseline. I'm looking forward to what's next!