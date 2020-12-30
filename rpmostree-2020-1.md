# rpm-ostree v2021.1

A goal of rpm-ostree is to *empower* users and developers.  Being able to fearlessly have automatic updates on and know that if your system loses power in the middle everything will be OK - that's empowering.

## rpm-ostree ex apply-live

In this release the functionality formerly known as `rpm-ostree ex livefs` is now `rpm-ostree ex apply-live`, and it's been placed on a much firmer technical foundation and is very safe to use.

I've often heard people say something of the form "with rpm-ostree you need to reboot for updates".  But that's never been true in general, because the goal is to move most software to containers.  Rather than having e.g. `gcc` as part of your root filesystem (in ostree), you have it in your development container updated independently from the host.  Server and desktop applications run as containers, etc.

For all the software as part of the host though, our story until recently has been incomplete.  We've had `rpm-ostree usroverlay` for a long time, which can be very convenient for testing things, but a core problem is that rpm-ostree has no idea what's happening in the transient writable layer, and further we didn't offer any tools to make changes there.



However, an example of something we clearly *should* support is directly 

But let's take the example of [NetworkManager](https://gitlab.freedesktop.org/NetworkManager/NetworkManager) or [podman](https://podman.io/).  


Rebooting operating systems is a polarizing topic.  I had a memorable conversation once with a Red Hat customer who insisted on

## override replace https://bodhi/...



## Demo: combine w/NetworkManager
  
Use override-replace w/NetworkManager build, then `ex apply-live` and test!
If system crashes, you're back in booted deployment.
