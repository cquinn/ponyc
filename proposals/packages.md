# Pony Packages

This proposal discusses a number of facets of packaging systems, and uses the systems of a few recent languages as examples: [Golang](https://golang.org/), [Nim](http://nim-lang.org/) and [Rust](http://www.rust-lang.org/). I am most familar with Go, using it daily for the last couple of years, somewhat with Rust, tinkering with it on occasion, and my Nim knowledge is just through reading. So please feel free to correct anything I got wrong regarding these languages.


## Source vs Binary

Source package management works with version managed source trees as the form of package distribution and consumption. One example of a language that handles packages this way is [Golang and its `go get` tool](https://golang.org/doc/code.html).

Binary package management works with descrete binary bundles that contained pre-built sources plus symbols and metadata. One example of a language that handles packages this way is [Rust with its crates and the `cargo` tool](https://doc.rust-lang.org/book/crates-and-modules.html).

### Source Package Highlights

- Source is simpler to work with: no special symbols or metadata to define, generate and parse.
- Source eliminates many versioning problems related to downstream dependencies as well as compiler and stdlib versions.
- Source allows (simplifies) whole program optimizations.
- Source is acceptible for Pony since ponyc is quite fast at parsing and code generation.

### Binary Package Highlights

- Binary is more self-contained.
- Binary might have cleaner or at least more concrete versioning.
- Binary retrieval could be faster.

### Proposal

I propose that Pony use a source package management approach.


## Composition

The Pony tutorial currently defines a single unit of componentization of Pony code, and that is the package. This is similar to Go's packages, with Pony's `use` command being equivalent to Go's `import` statement. One apparent difference though seems to be that Pony's package references are simple short path identifiers, while Go's package references are effectively global URLs. (github.com/op/go-logging is mechanically mapped to git:github.com/op/go-logging)

Learning from experience with Go, this works quite well at build time, with the compiler only needing to have a local package search path available to locate referenced packages by name at compile time. But complications arise in Go when retrieving packages, since multiple packages are often bundled together with a single unit of retrieval and versioning (typically a repo and a tag). So there ends up being a many-to-one relationship between the unit of import (package) and the unit of retrieval (repo), and this makes the fetch tools a bit funky.

Take a look at Go's `go get` which retrieves packages given a package name (and optionally tag), and [`Godep`](https://github.com/tools/godep) a popular tool that wraps `go get` and manages packages and versions for a Go project. Godep maintains a separate Godep.json file that tracks each package referenced from the project and its version (tag) to be used. It also handles vendoring, where the dependent packages are actually copied into the project, and the source imports are rewritten to use the doubled-up paths.

Most Go developers don't like the import rewriting, and the whole vendoring approach has its pros and cons. The Go community is currently working on a proposal to standardize the godeps format and the mechanism that vendored packages are referenced by the compiler. This would allow vendoring to be used without import rewriting, and maybe allow for non-vendored packages.

But, I think defining one higher level of containment for packages could simplify this complexity. This could be a new level of grouping above package, like a `project`, `bundle` (or `satchel`... is that too cute?), where packages were always contained within a bundle, and each bundle had exactly one remote repo defined. The bundle name would just be the first segment of the package path which would be used locally by the compiler.

Then the imported bundles could be defined in a project-level `project.yaml` (or json, etc) which would describe the name to repo URL mapping, as well as the version (range?) to retrieve. Here's an example:

project.yaml
```
bundle: mysample
version: a.b.c
description: This is just a sample.
other-project-metadata: here.
uses:
- bundle superparser
  - repo: "github.com/cquinn/superparser"
  - version: "0e45c2228aab9921ef50cc7d0bf7186082cc51a4"
- bundle ultralogging
  - repo: "github.com/cquinn/ultralogging"
  - version: "1.2.0"
```

sample.pony
```
use "superparser/parser/types"
use "superparser/parser/api"
use "ultralogging/log"
...
```

An alternative would be to use fuller package identifiers in the `use` commands like Go does, but still have the notion of a bundle that is the shared root of one or more packages, and that bundle would be described in the bundle file as above.

sample.pony
```
use "github.com/cquinn/superparser/parser/api"
use "github.com/cquinn/superparser/parser/types"
use "github.com/cquinn/ultralogging/log"
...
```

### Proposal

I propose that Pony have a package bundle notion, with bundle locators and versions being defined in a per-project `project.yaml` file.


## Catalog

The above bundle file is structured around using a distributed form of bundle location. This is where each project locally defines where it is getting each bundle from. This is the approach Go takes, and it makes it easier for users to use locally cached or forked versions of public libraries.

Nim, on the other hand, uses a centralized catalog where all of their package definitions live in a [global Github repo](https://github.com/nim-lang/packages), and their `nimble` tool looks up packages by name there to discover from where to retrieve them.

These two are not mutually exclusive, however. It would be possible to have a system where the local bundle reference in the `project.yaml` took precedence, but a central catalog could be referenced when there was no project local definition. The looked-up bundle information could then be written back into the local project.yaml file.

### Proposal

I propose that Pony support both per-project distributed bundle location, and a central catalog for initial lookup of well-known public library bundles to be stored in the `project.yaml`.


## Workflow

There are a number of advantages to decoupling the retrieval of packages from their reference at compile time. Compile speed being one, but mostly it is to maintain separation of concerns: during development it is desirable to only update dependencies when explicitly requested to do so by the developer.

With the above bundle definition being outside of the Pony source, and the desire to have retrieval decoupled from compile, it seems to make sense to have an external tool perform the retrieval and project.yaml update. Something like Go's 'go get', maybe 'pony fetch', would read the project.yaml and retrieve all of the used bundles and store them locally.

This does raise the question of introducing another tool. But this is what Go has, and the Go toolset and pattern are generally considered to be one of Go's best features. How about having a general 'pony' tool that would have specific sub-commands that would fork out and run other tools. Like 'pony build' invoking ponyc, or 'pony test' running tests, or 'pony fetch' fetching bundles?

### Proposal

I propose a new 'pony' tool (written in Pony of course) that would serve as the Pony language tool hub. This tool could initially perform the following sub commands for a given project:

- **pony bundle init**: generate a skeleton project.yaml file and populate it with bundles used in the Pony source, and looking up default locations when available in the central catalog.
- **pony bundle update [*bundle*]**: update an existing project.yaml file, adding missing bundles, and optionally updating all or specific version references.
- **pony bundle fetch**: fetch all referenced bundles.
- **pony build**: build project using ponyc.
- **pony test**: run the tests, building first if needed.
- **pony doc**: generate doc using ponyc.


## Summary

- Packages are always published and managed in source form.
- Packages are combined into bundles that are the unit of retrieval and versioning.
- Pony projects have a project.yaml that describes the project, including its dependant bundles.
- There is a pony tool that manages retreiving bundles and updating project.yaml.
