# Fedora guidelines for vendored Rust dependencies

https://lists.fedoraproject.org/archives/list/rust@lists.fedoraproject.org/thread/UE4FU27OAHXQ2EOV5OFSXGHELUWZYSJM/
lists the rationale for the "exploded Rust sources" (i.e. non-vendoring) approach.

However, several upstream projects we use must build on multiple distributions including RHEL, where there are no plans to ship these source crates.

These guidelines recommend how to 