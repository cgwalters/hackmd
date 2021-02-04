# osbuild is from Mars, coreos-assembler is from Venus


### Containerized vs RPM

coreos-assembler runs *unprivileged* (just wants `/dev/kvm` ideally) in both OpenShift as well as `podman` on standalone systems.  Scheduling multiple builds is just multiple Kubernetes pods; shared state can be NFS or S3.

osbuild installs as an RPM and uses privileged systemd containers.

### Declarative vs imperative

Overall CoreOS philosophy is very declarative; e.g. Ignition.  And notably on this topic `rpm-ostree compose tree` on the server side is very oriented towards 100% declarative YAML.  `coreos-assembler build` is even further opinionated that the input should come from a git repository with a particular structure.  Client side `rpm-ostree X` is imperative but writes a declarative state file in the background (see also [this issue](https://github.com/coreos/rpm-ostree/issues/2326)).

osbuild seems very imperative; oriented towards supporting interactive Cockpit UI?

### Languages (somewhat aligned?)

Everyone loves a hot mess of Go and Python and shell apparently.

### Distributions

coreos-assembler only comes as a container from Fedora userspace today; osbuild ships as an RPM in

### Product

osbuild is a product, coreos-assembler is not.

### Building and testing

coreos-assembler only supports Ignition-and-ostree based operating systems and is very opinionated about this combination.  We heavily rely on this for integrated building+testing of CoreOS.

osbuild doesn't do testing?

#### What can be shared?

The "mantle" subcomponent of coreos-assembler supports uploading images to clouds; perhaps we could try to share some of that?  There was an effort to use mantle for "traditional"
Maybe we can have shared Go libraries for e.g.