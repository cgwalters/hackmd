# Committed to the integrity of your root filesystem

Quite a while ago I came across the [SQLite testing page](https://www.sqlite.org/testing.html) and was impressed (and since then it's gotten even better).  They've clearly invested a lot in it, and I think SQLite's ubiquity is well deserved.

When I started the [ostree project](https://github.com/ostreedev/ostree/) I had this in mind but...testing is hard.  We have decent "unit test style" coverage but that's not very "real world".  We've gone through a few test frameworks over the years.  I finally had a chance to write some new testing code and I'm happy with how it turned out!  There were some twists and turns along the way.

TL;DR: There's a new "transactionality" test run on every PR that uses a mix of e.g. `kill -9 ostree` and `reboot -ff` while updates are running, and verifies that you either have the old or new system safely. (PRs: [ostree#2048](https://github.com/ostreedev/ostree/pull/2048) and [ostree#2127](https://github.com/ostreedev/ostree/pull/2127)).

But along the way there were some interesting twists.

## Test frameworks and rebooting

I mentioned we'd been through a few test frameworks.  An important thing to me is that ostree is a distribution-independent project; it's used by a variety of systems today.  Ideally, our tests can be run in multiple frameworks.  That works easily for our "unit tests" of course, same as it does for many other projects.

But our OSTree tests want a "real" system (usually a VM), and further the most interesting tests need to be destructive.  More than that, we need to support rebooting the system under test.

I'd known about the [Debian autopkgtest specification](https://salsa.debian.org/ci-team/autopkgtest/raw/master/doc/README.package-tests.rst) for a while, and when I was looking at testing I re-evaluated it.  There are some things that are very Debian-specific (how tests are defined in the metadata), but in particular I really liked how it supports reboots.

There's a big tension in test systems like this - is the test logic primarily run on the "system under test", or is it on some external system which manages the target via e.g. `ssh`?  We had lots of problems in our prior test frameworks was dealing with reboots with the latter style.

In the Fedora CoreOS group we use a system called "kola" which came from the original CoreOS project.  I added partial support for the Debian Autopkgtest specification to it ([cosa#1528](https://github.com/coreos/coreos-assembler/pull/1528)).

## Avoiding shell script

A lot of the original ostree tests were in shell script.  I keep finding myself writing shell even though I also keep being badly burned by it from time to time.  

So another tangent along the way here: For writing new tests I'd resolved to use "not shell script". Python would be an obvious choice but...another large wrinkle here is that in CoreOS we [don't want interpreters in the base OS](https://github.com/coreos/fedora-coreos-tracker/blob/master/Design.md#approach-towards-shipping-Python) - they should run as containers (a shell is obviously an interpreter too but...).  This would drive us towards having our test framework run as a privileged container...I decided not to do this basically because it makes it much harder to test the system as other processes see it.

My preferred language nowadays is Rust, and it generates static-except-libc binaries that we can just copy to the host.  Further, fortuitously someone else created [Rust bindings to ostree](https://crates.io/crates/ostree) and I'd been wanting an excuse to use that for a while too!  However...some things are just too verbose via API, and plus we want to test the CLI too.  Invoking subprocesses via [Rust std::process::Command](https://doc.rust-lang.org/std/process/struct.Command.html) is also *very* verbose.  So I ended up creating [a sh-inline crate for Rust](https://crates.io/crates/sh-inline) that makes it ergonomic to include snippets of [strict mode](http://redsymbol.net/articles/unofficial-bash-strict-mode/) bash in the code.  [This snippet](https://github.com/ostreedev/ostree/blob/81321f2c6bc935ef2927e63dea0b17d441bf3e5d/tests/inst/src/destructive.rs#L168) is a good example.  (I'd like to [make this even more ergonomic](https://github.com/cgwalters/rust-sh-inline/issues/1) too)

## Actually writing the test

OK so all those prerequisites out of the way, the first thing I did was write the code to do the "try upgrading and while that's running, kill -9 it".  That went reasonably quickly and so I moved on to adding `reboot -ff` as another "interrupt strategy".  However, this required completely rewriting the control flow because here the "test harness" is *also* being killed - I ended up [serializing the process state into JSON](https://github.com/ostreedev/ostree/blob/81321f2c6bc935ef2927e63dea0b17d441bf3e5d/tests/inst/src/destructive.rs#L89) which gets stored in the `AUTOPKGTEST_REBOOT_MARK`.  Effectively then 

kola external tests
  upstream CI vs downstream

Introduction of

Shell scripts, compiled languages, Rust
  https://gi.readthedocs.io/en/latest/ and interpreters vs CoreOS
  https://crates.io/crates/sh-inline
  

  

https://github.com/ostreedev/ostree/pull/2048