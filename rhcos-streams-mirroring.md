# RHCOS stream metadata, ART and mirror.openshift.com

This is followup to https://github.com/openshift/enhancements/pull/679
aka https://github.com/openshift/enhancements/blob/master/enhancements/coreos-bootimages.md

Basically the current flow isn't changed from before, we just added a new JSON format for the existing data mostly.  But the problem is that the new data is intended to be public, but refers to our "bridge server":

See e.g.:
https://github.com/openshift/installer/blob/6363f3ab700e3976e8655ba0e826843593c7c98f/data/data/rhcos-stream.json#L59
which has:
`"location": "https://releases-art-rhcos.svc.ci.openshift.org/art/storage/releases/rhcos-4.7-ppc64le/47.83.202102091015-0/ppc64le/rhcos-47.83.202102091015-0-openstack.ppc64le.qcow2.gz",`

And the problem is this server was never intended to be truly public facing, and in fact is going to die soon I think when `api.ci` is decomissioned.  (We can easily resurrect it on `app.ci` but...)

# Assumption: ART maintains stream metadata and builds

At http://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos-4.8.json or so.  That in turn refers to content underneath:
`http://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos-4.8/buildid/rhcos-buildid-qemu.qcow2` etc.

Further, ART must manage garbage collection here.  In particular, we cannot prune the official installer-pinned images.  But we may end up with "orphaned" versions that aren't pinned and also aren't the latest that *might* be pinned.

## Option: Mirror-before-PR

- Choose an RHCOS bootimage build that we intend to PR to openshift/installer
- Ask ART to use [plume stream-mirror](https://github.com/coreos/coreos-assembler/pull/2097) to copy it to http://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.8/$buildid/
- Submit PR to openshift/installer with mirrored stream data

Pros: Minor tweak to current process
Cons: We are only getting Prow testing for builds *after* ART has mirrored

## Option: ART mirrors automatically

- Immediately trigger https://github.com/openshift/aos-cd-jobs/blob/e80e34e695cfbc469a049f80d70658772ee707bf/jobs/build/rhcos_sync/build.groovy after an RHCOS build so it appears at http://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/pre-release/4.8/$buildid/
- Stream metadata updated: http://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/pre-release/rhcos-4.8-prerelease.json

## Option: Mirror-before-PR-merge

- PRs submitted to installer already contains intended mirrored URLs
- Add `env OPENSHIFT_INSTALL_COREOS_STREAM_PREFIX=https://releases-art-rhcos.svc.ci.openshift.org/art/storage/releases` or so (or maybe just `env OPENSHIFT_INSTALL_CI_COREOS_BOOTIMAGES=1` and we hardcode the URL in the installer for now)
- Installer CI uses this environment variable override for e.g. e2e-metal etc.
- Add an installer presubmit `art-mirror-validate` that *blocks merge* until all artifacts exist at the ART mirrored location
- Once CI passes, ask ART to mirror
- Retest `art-mirror-validate` and let Prow merge

Pros: Prow testing before any mirroring happens
Cons: Some nontrivial (but also not very difficult) CI work

## Option: Move https://github.com/cgwalters/rhel-coreos-bootimages into openshift/ GH org

- Change RHCOS build system to submit PRs to that repo (like dependabot)
- PRs are e2e tested
- When we are ready to promote to the installer, ask ART to mirror
- Submit mirrored stream data to the installer

Pro: We have a repo we control decoupled from the installer where we can do more CI and stuff
Con: Data is in two places and we also will then need to pass through double CI to update bootimages
Con: Window of time where data isn't synchronized

# Other options

There's obviously a lot more we can do here but they get increasingly invasive to the current RHCOS build system and I am wary about trying to completely rewrite that (though hopefully gangplank will help).

Though, one thing that would likely help a lot is for ART to just default to mirroring the latest RHCOS build.