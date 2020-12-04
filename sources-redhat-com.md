# sources.redhat.com

As an enterprise software company with a FOSS development model,
source code is fundamental to what Red Hat does.

We are part (or the primary driver for) many different communities
that manage their source code in different ways, from Github, Gitlab,
old Sourceforge projects, GNU Savannah, and more.

However, when we ship (compiled) code to customers, we need to be
able to fix an issue in that project even if the original upstream
source code repository is (temporarily or permanently) unavailable.

Being able to precisely and reliably find the source code to software
we ship is just a fundamental requirement.

## The lookaside cache

However, our primary current approach to managing source code is
to upload it to a [lookaside cache](https://fedoraproject.org/wiki/Package_Source_Control#Lookaside_Cache) - this accepts arbitrary tarballs.

A number of teams maintain their own automation that e.g. periodically
imports code from Github or elsewhere and converts it into a tarball
for upload to this cache.  Others may create that tarball and upload
it to a Github release or equivalent, then import that tarball
to the lookaside.

## Flaws with the lookaside

There is no real standard for how the linkage between
upstream projects and the lookaside cache works.

There is no CI for uploads to the lookaside cache; nothing
that even does basic analysis for license compliance or
looking for pre-compiled binaries.

The lookaside cache is extremely opaque; the Fedora model
puts RPM metadata front and center, hiding the upstream
source code.  This is exactly the inverse of what it should be;
RPM spec files should mostly be automatically derived from
upstream, and we should encourage putting fixes upstream.

## Flaws with upstream sources

Another fundamental requirement for us to ship software
is license compliance.  In theory, upstream projects should
have CI that is validating this.  In practice, that is
spotty.

Of the Fedora "package review" process, license compliance
is really the most important thing.

For example, the Rust https://crates.io/ does zero checking
of uploads - the maintainers explicitly say that they 
will not be gatekeepers.  But someone needs to do that.

## Proposed git.source.redhat.com

Red Hat should create and maintain a source code mirroring
system that automatically ingests source code from everything
we ship as a product; if it's not a git repository to start,
it should be converted to one.

It would be easy to add things to this mirror; something like
submitting a PR.

As a secondary layer tightly integrated with this system, there
would be a "CI" layer that does basic analysis for
"should we ship this software at all", which would include:

 - License auditing
 - Checking for pre-compiled binaries

This tooling exists.  We just do not apply it consistently.

Adding software to this "should be ready to ship" would
be a separate layer.

## Sharing this effort with others

In fact, it would make a lot of sense to have such a
project be not Red Hat specific - there are a lot of
distributions out there that (for good or bad reasons)
maintain separate packaging formats (dpkg/rpm/etc)
but there's not a strong reason to duplicate license
auditing and source code mirroring.  We'd need to define
some sort of incentive to share the license auditing
burden across consumers of such a system, but it
seems tractable.

## Using git.source.redhat.com for non-RPM builds

Currently Fedora too tightly ties "prepare software to ship"
with "ship it as an RPM".  It needs to be possible
to natively consume upstream code and directly e.g. `podman build`
it without involving RPM in the middle.

Further, this system for example could act as an alternative
`crates.io` frontend, as well as implement `GOPROXY` and other
systems so that one can perform language-native builds
using this as a filtered source.


## But sources.redhat.com exists

Yes but it redirects to sourceware which is just one of
our many fragmented upstreams that doesn't have a lot
of traction.  Let's just appropriate that.

## But source.redhat.com exists

Yeah OK, I think they chose a bad name but someone
should feel free to pick another one for this
if they won't change!
