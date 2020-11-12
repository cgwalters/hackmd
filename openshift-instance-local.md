# Pre-enhancement: Using ephemeral storage

This is a "pre-enhancement": Once we get some consensus on the broad outline we can convert this into a proper https://github.com/openshift/enhancements

## Background: Instance local storage

Azure/GCP/AWS all support "instance local" disks:

- https://docs.microsoft.com/en-us/azure/virtual-machines/ephemeral-os-disks
- https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/add-instance-store-volumes.html
- https://cloud.google.com/compute/docs/disks/local-ssd

Azure even does this by default; in our default cluster install
instance type we have a 64GB disk that's NTFS formatted (of course)
that we just ignore today (they say it's free).

## Speed versus durability

Today default OpenShift 4 (IPI) installs use "maximum durability" storage for the root partition of the control plane and workers.  Our default etcd writes to the root partition.  Most cloud providers don't document exactly how they implement durable storage, but it clearly involves things like writing data to multiple distributed disk drives.

### Ephemeral workers

Not every workload requires this level of durability, particularly on workers - it's pretty silly to e.g. write downloaded container images to a durable store because we can just re-download them from the registry.

### "Less extremely durable" control plane

And a common problem in OpenShift is I/O performance for etcd - what we're doing by default is really having each write be durable to an extreme level - we multiply by 3 durable writes.

Not every cluster requires this level of durability - e.g. an organization fully invested in a "GitOps" model where all critical API objects are committed to Git would likely be fine e.g. gaining 5-10x API server performance for e.g. 0.001% risk of concurrent failure of every control plane node per year. (Numbers are made up)

## Strawman proposal

In both machineAPI and the `install-config.yaml` we support provider-specific configuration that mounts `/var` as an instance-local volume.  And this is very provider specific. 

To start for example, for [AWS m5d instance types](https://aws.amazon.com/ec2/instance-types/m5/), adding a simple stanza into the install config like:

```
apiVersion: v1
baseDomain: example.com
controlPlane:
 ...
compute:
- name: worker
  platform:
    aws:
      instanceVolumes: "stripe"
      type: m5d.xlarge
      zones:
      - us-west-2c
  replicas: 5
```

This would automatically format all instance-local drives and aggregate them into e.g. an LVM raid0 (striped).

### Full instance durability versus `/var`

It will be easier to implement if we don't try to support making the root volume instance-local.  For exmaple, some cloud providers do automatic migration and that will lose the instance store.  We can't 