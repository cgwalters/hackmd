# On BTRFS

There's been a lot of discussion on [this proposed Fedora change for Workstation to use BTRFS](https://fedoraproject.org/wiki/Changes/BtrfsByDefault).

First off, I reprovision my workstation about every 2-3 months to avoid it becoming too much of a "pet".  I took the opportunity for this reprovision to try out BTRFS again (it'd been years).

### Executive summary

BTRFS should be an option, even an emphasized one.  It probably shouldn't be the default for Workstation, and shouldn't be a default beyond that for server use cases (e.g. Fedora CoreOS).

### Why are there multiple Linux filesystems?

There are multiple filesystems in the Linux kernel for *good reasons*.  It's basically impossible to optimize for all use cases at once, and there are fundamental tradeoffs to make.  BTRFS in particular has a lot of features...and those features have costs.  Not every use case needs those features, and the costs can be nearly prohibitive.

### BTRFS is good for "pet" systems

There is this terminology in the industry of [pets vs cattle](https://www.google.com/search?q=pets+vs+cattle) - I once saw a talk that proposed "elephants vs ants" instead which is more appealing.

I mentioned above I reprovision my workstation periodically, but it's still *somewhat* of a "pet".  I don't have everything in config management yet (and probably never will); I change things often enough that it's hard to commit to 100% discipline to record every change in git instead of just running a CLI or writing a file.  But I have all the important stuff.

For people who don't have much in configuration management - the server or desktop system that has *years* of individually built up changes, being able to e.g. take a filesystem snapshot of things is an extremely compelling feature.

### The BTRFS cost

Those features though come at a cost.  And this back to the "pets" vs "disposable" systems and where the "source of truth" is.  For users managing disposable systems, the source of truth isn't the Unix filesystem - it's most likely a form of [GitOps](https://www.gitops.tech/).  Or take the case of Kubernetes - it's a cluster with the primary source being [etcd](https://etcd.io/).



The BTRFS developers like to talk about how they have 

https://unix.stackexchange.com/questions/309852/should-the-nodatacow-mount-option-be-used-in-btrfs-in-a-database-server-does-it
