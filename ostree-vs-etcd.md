# OSTree update niceness vs etcd

https://github.com/openshift/machine-config-operator/issues/1897

This is certainly a fantastically complex topic.  I have also seen desktop OSTree users complain about interactivity during updates.

A few further thoughts:

### Control plane vs workers

We want to avoid disrupting etcd (and the control plane in general), but: while we also want to avoid disrupting *workers*, I think we shouldn't let user workloads completely block OS updates either.

### oscontainer wrapping forcing large I/O

The way we pull the whole oscontainer and unpack it means we are always doing 1G+ of I/O, even for small OS updates.  There are several entirely different ways to fix that:

#### Run a HTTP server (kube service) that mounts the oscontainer

This would have several huge advantages, among them that OS updates suddenly work exactly how OSTree was designed from the start - we only write *new* objects to disk.  It would also avoid SELinux problems we've hit trying to get content from the oscontainer to the host.  But it'd be a nontrivial change that would conflict with ongoing work on extensions.

We'd need to be careful to not mount the oscontainer on workers and then pull to the control plane, or we escalate potential worker compromise to control plane.  (Or we need to e.g. GPG sign the oscontainer content)

#### Stream unpacking the oscontainer

Rather than use `podman pull`+`podman mount`, stream the oscontainer and unpack it as we go.  I think the main disadvantage of this is that it'd be a new nontrivial bit of code, and we'd need to do some tricky things like still verify the compressed sha256 at the end, and discard all intermediate work if that fails to verify.

# The IO scheduler

In current Fedora but not yet RHEL8, [bfq is the default](https://github.com/systemd/systemd/pull/13321).  Currently RHEL8 defaults to `mq-deadline`.   And one thing I notice here is that if I do `ionice -c 3 ostree pull ...` it's about a 20% boost for the non-nice test `dd` workload but only if `bfq` is enabled.

# Test criteria

```
#!/bin/bash
# Setup script - suitable to run in a container image, but
# we expect $(pwd) to be a local XFS bind mounted in
# and not the container's overlayfs
set -xeuo pipefail
rm repo -rf
ostree --repo=repo init --mode=bare-user
img42=quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:b64e472b57538ebd6808a1e0528d9ea83877207d29c091634f41627a609f9b04
commit42=f2126cdca6a924938072543aa9d6df4436fe72462f59d3d2ad97794458cb5550
rm tmp -rf
mkdir tmp
oc image extract "${img42}" --path=/srv/repo:tmp
ostree --repo=repo pull-local tmp/repo "${commit42}"
rm tmp -rf
# Flush to avoid mixing in the prep pull with later tests
sync -f .
```

```
#!/bin/bash
# Like above, expects . to be the workdir
# You likely want to mirror this locally, but we pull it because
# we want to simulate all of the temporary data that gets written
# by the podman stack as well.
set -xeuo pipefail
ostree --repo=repo prune --refs-only --depth=0
img45=quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:784456823004f41b2718e45796423bd8bf6689ed6372b66f2e2f4db8e7d6bcb9
commit45=bcfae65a2ab0b4ab5afcd1c9f1cce30b300e5408b04fc8bdec51a143ab593d40
rm tmp etcdtest -rf
sync -f .
# Now, begin the test
mkdir etcdtest tmp
rm -f fio.log
fio --rw=write --ioengine=sync --fdatasync=1 --directory=etcdtest --size=30m --bs=2300 --name=etcd > fio.log &
oc image extract "${img45}" --path=/srv/repo:tmp
ostree --repo=repo pull-local tmp/repo ${commit45}
wait
cat fio.log
```

# Results

Baseline test setup: 

 kernel: 5.7.8-200.fc32.x86_64
 filesystem: xfs
 block device: Samsung SSD 970 EVO 1TB (NVMe)
 scheduler: `[none]`
 
### Baseline fio

```
[root@toolbox testetcd]# fio --rw=write --ioengine=sync --fdatasync=1 --directory=etcdtest --size=30m --bs=2300 --name=etcd
etcd: (g=0): rw=write, bs=(R) 2300B-2300B, (W) 2300B-2300B, (T) 2300B-2300B, ioengine=sync, iodepth=1
fio-3.19
Starting 1 process
Jobs: 1 (f=1): [W(1)][100.0%][w=1970KiB/s][w=877 IOPS][eta 00m:00s]
etcd: (groupid=0, jobs=1): err= 0: pid=408906: Wed Jul 15 02:14:39 2020
  write: IOPS=858, BW=1928KiB/s (1974kB/s)(29.0MiB/15937msec); 0 zone resets
    clat (nsec): min=1024, max=14349k, avg=103520.77, stdev=145454.55
     lat (nsec): min=1082, max=14350k, avg=104346.19, stdev=145488.30
    clat percentiles (usec):
     |  1.00th=[    5],  5.00th=[    7], 10.00th=[   14], 20.00th=[   25],
     | 30.00th=[   25], 40.00th=[   26], 50.00th=[  108], 60.00th=[  147],
     | 70.00th=[  180], 80.00th=[  188], 90.00th=[  200], 95.00th=[  206],
     | 99.00th=[  217], 99.50th=[  225], 99.90th=[  545], 99.95th=[  553],
     | 99.99th=[  586]
   bw (  KiB/s): min= 1832, max= 2061, per=100.00%, avg=1933.16, stdev=56.02, samples=31
   iops        : min=  816, max=  918, avg=860.87, stdev=24.98, samples=31
  lat (usec)   : 2=0.10%, 4=0.78%, 10=5.57%, 20=6.89%, 50=30.48%
  lat (usec)   : 100=3.96%, 250=51.96%, 500=0.16%, 750=0.10%
  lat (msec)   : 20=0.01%
  fsync/fdatasync/sync_file_range:
    sync (usec): min=732, max=4286, avg=1052.51, stdev=278.42
    sync percentiles (usec):
     |  1.00th=[  848],  5.00th=[  906], 10.00th=[  930], 20.00th=[  963],
     | 30.00th=[  988], 40.00th=[ 1020], 50.00th=[ 1037], 60.00th=[ 1045],
     | 70.00th=[ 1074], 80.00th=[ 1090], 90.00th=[ 1123], 95.00th=[ 1123],
     | 99.00th=[ 1434], 99.50th=[ 3884], 99.90th=[ 4113], 99.95th=[ 4178],
     | 99.99th=[ 4228]
  cpu          : usr=1.14%, sys=5.69%, ctx=48686, majf=0, minf=16
  IO depths    : 1=200.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,13677,0,0 short=13677,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
  WRITE: bw=1928KiB/s (1974kB/s), 1928KiB/s-1928KiB/s (1974kB/s-1974kB/s), io=29.0MiB (31.5MB), run=15937-15937msec

Disk stats (read/write):
  nvme1n1: ios=7674/27335, merge=0/0, ticks=909/13768, in_queue=27707, util=99.52%
```

### With concurrent update

```
etcd: (g=0): rw=write, bs=(R) 2300B-2300B, (W) 2300B-2300B, (T) 2300B-2300B, ioengine=sync, iodepth=1
fio-3.19
Starting 1 process
etcd: Laying out IO file (1 file / 30MiB)

etcd: (groupid=0, jobs=1): err= 0: pid=408818: Wed Jul 15 02:12:16 2020
  write: IOPS=381, BW=858KiB/s (878kB/s)(29.0MiB/35815msec); 0 zone resets
    clat (usec): min=2, max=434, avg=18.88, stdev=12.67
     lat (usec): min=3, max=435, avg=19.46, stdev=12.96
    clat percentiles (usec):
     |  1.00th=[    5],  5.00th=[    5], 10.00th=[    6], 20.00th=[    7],
     | 30.00th=[    9], 40.00th=[   12], 50.00th=[   17], 60.00th=[   25],
     | 70.00th=[   26], 80.00th=[   32], 90.00th=[   36], 95.00th=[   37],
     | 99.00th=[   47], 99.50th=[   52], 99.90th=[   60], 99.95th=[   66],
     | 99.99th=[  343]
   bw (  KiB/s): min=    4, max= 1055, per=100.00%, avg=908.57, stdev=253.13, samples=67
   iops        : min=    2, max=  470, avg=404.72, stdev=112.68, samples=67
  lat (usec)   : 4=0.30%, 10=34.99%, 20=19.16%, 50=44.92%, 100=0.60%
  lat (usec)   : 250=0.01%, 500=0.01%
  fsync/fdatasync/sync_file_range:
    sync (usec): min=732, max=1935.7k, avg=2594.14, stdev=19014.96
    sync percentiles (usec):
     |  1.00th=[   832],  5.00th=[   881], 10.00th=[   914], 20.00th=[   971],
     | 30.00th=[  1020], 40.00th=[  1090], 50.00th=[  2933], 60.00th=[  3032],
     | 70.00th=[  3064], 80.00th=[  3130], 90.00th=[  3228], 95.00th=[  3425],
     | 99.00th=[  6194], 99.50th=[  7963], 99.90th=[ 17433], 99.95th=[ 95945],
     | 99.99th=[843056]
  cpu          : usr=0.37%, sys=2.55%, ctx=41884, majf=0, minf=15
  IO depths    : 1=200.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,13677,0,0 short=13677,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
  WRITE: bw=858KiB/s (878kB/s), 858KiB/s-858KiB/s (878kB/s-878kB/s), io=29.0MiB (31.5MB), run=35815-35815msec

Disk stats (read/write):
  nvme1n1: ios=0/43702, merge=0/69266, ticks=0/385455, in_queue=402971, util=99.51%
```

Note that the bandwidth is about halved, the 99th percentile is still under 10ms...but the standard deviation shoots up; there are a few *much, much* longer fsyncs, including one that took nearly a full 2 seconds.

### Attempted tweaks that didn't help

- change scheduler to `bfq`
- Use `ionice -c 3` (with and without `bfq`)

### Use `--disable-fsync` for ostree pull: Big Improvement!

```
  fsync/fdatasync/sync_file_range:
    sync (usec): min=756, max=767233, avg=2449.79, stdev=7291.31
    sync percentiles (usec):
     |  1.00th=[   848],  5.00th=[   906], 10.00th=[   947], 20.00th=[   996],
     | 30.00th=[  1045], 40.00th=[  1106], 50.00th=[  2966], 60.00th=[  3064],
     | 70.00th=[  3130], 80.00th=[  3195], 90.00th=[  3261], 95.00th=[  3589],
     | 99.00th=[  5932], 99.50th=[  6456], 99.90th=[ 23462], 99.95th=[ 96994],
     | 99.99th=[200279]
```

# Reworking ostree to reduce fsync "spike"

https://github.com/ostreedev/ostree/pull/2147


# Other ideas:

Should ostree try doing asynchronous fsync?  https://lwn.net/Articles/789024/


