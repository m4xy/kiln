# kiln

kiln builds [fckt](https://github.com/m4xy/fckt) projects: it compiles them, tests them, runs
them, and publishes them as libraries for other projects to use. It's written in fckt, and builds
itself.

A project is a folder with a `build.fk`, which says what the project is, in fckt:

```kotlin
project = Project(name = "shop")
```

```
$ kiln build
> Task :compile
> Task :test
  passed prices.fk
> Task :build
BUILD SUCCESSFUL
$ kiln run -- a b
```

## Installing

kiln needs [fckt](https://github.com/m4xy/fckt) and OCaml 5.1 or newer, with
`ocamlopt`. The first time, `bootstrap.sh` builds kiln with fckt and has it install itself:

```sh
FCKT=/path/to/fckt ./bootstrap.sh    # FCKT if fckt isn't on PATH
export PATH="$HOME/.kiln/bin:$PATH"
```

It installs `~/.kiln/bin/kiln`, and kiln's library, which build scripts use, in `~/.kiln/lib/kiln`;
`KILN_HOME` puts both elsewhere. After that, kiln builds itself: `kiln build`, `kiln install`.

## Tasks

`kiln build`, run in a project's folder, compiles `src/main.fk` and the packages in `src` to
`build/bin/<name>`, then compiles and runs each program in `test`, any of which failing fails the
build. Several tasks run in turn, each once and after the tasks it depends on: `kiln clean build`.
`kiln -C dir build` builds the project in `dir`. What's up to date isn't done again: a program
whose sources, libraries, fckt and OCaml are what they were isn't compiled again, and a test that
passed with them isn't run again; `kiln clean` forgets.

| Task | |
| --- | --- |
| `compile` | Compiles the program to `build/bin/<name>`; a library, which has no `src/main.fk`, is compiled as a library, to `build/library` |
| `test` | Compiles and runs each program in `test`: each file there with a `main`; the others are what the tests share |
| `build` | `compile`, then `test` |
| `run` | Runs the program, with what follows `--`; it failing fails the build |
| `clean` | Deletes `build` |
| `publishLocal` | Compiles and tests, then publishes the project as a library to the local repository |
| `roots` | Prints the folders the project's packages, and its folder projects', are in, and the libraries it uses |
| `tasks` | Lists the tasks |

## build.fk

A build script is fckt, with a `project`. It imports kiln's library, `uk.m4xy.kiln`, with
`Builds` and `Dependencies`, and `fckt.io`'s `Path`, `Paths`, `Files` and `Processes`, without
saying. `Project`'s fields have defaults, but its `name`:

```kotlin
project = Project(
  name = "shop",
  version = "0.1.0",
  group = "",                     // who publishes it: uk.m4xy
  dependencies = [],              // library("uk.m4xy:json:1.2.0"), projectAt("../pricing")
  main = path("src/main.fk"),
  sources = [path("src")],
  tests = path("test"),
  output = path("build"),
)
```

A task is a `Task(name, description, dependsOn, action)`, whose action is fckt that may print, use
files and run programs (`@Building`). A build script adds its own by declaring `tasks`:

```kotlin
project = Project(name = "shop", version = "1.2.0")

tasks = standardTasks + [
  Task("stamp", "Writes the version", dependsOn = ["compile"], action = p -> p.output.resolve("VERSION").writeText(p.version)),
]
```

## Libraries and dependencies

A library is a project with a `group`, a reversed domain it owns, and its packages in a folder of
that name, so two libraries' packages never meet. `kiln publishLocal` compiles and tests it, then
copies its packages to the local repository, `~/.kiln/repository/<group>/<name>/<version>`, with a
list of what it depends on. A package outside its group, or a dependency on a folder project, which
might change under it, stops it.

```kotlin
// units/build.fk, with its packages in src/uk/m4xy/units
project = Project(name = "units", group = "uk.m4xy", version = "1.0.0")

// money/build.fk
project = Project(name = "money", group = "uk.m4xy", version = "2.1.0", dependencies = [library("uk.m4xy:units:1.0.0")])

// shop/build.fk: a published library, and a project straight from its folder, as it is now
project = Project(name = "shop", dependencies = [library("uk.m4xy:money:2.1.0"), projectAt("../pricing")])
```

A project's packages are then found in its own folders, and its folder projects', with the
libraries each uses, as `kiln -C <folder> roots` says. Where two ask for a library in different
versions, the higher is used.

A library is compiled once, not with every build: the first build that uses it compiles it, after
the libraries it uses, into kiln's cache, `~/.kiln/cache`, with its interface, which the project
is checked against, and then links each program with it. It's compiled again only for a different
fckt or OCaml, a different version of a library it uses, or when it's published again. What a
library shows is in its interface without its code, so its public functions and values say their
types, which `kiln compile` checks:

```kotlin
module Prices {
  label(pounds: Int): String = "costs ${Money.format(pounds)}"   // not label(pounds: Int) = ...
}
```

## How it works

kiln adds a `main` to the build script, which hands `project`, and `tasks` if it declares them, to
`uk.m4xy.kiln.Builds.runBuild`. It compiles that with `fckt --import ...` and `ocamlopt` to a
program, `.kiln/build`, again only when the script or kiln changes, and runs it. The tasks are fckt too, in
`src/uk/m4xy/kiln`: they call `fckt` and `ocamlopt`. `build` and `.kiln` are what to leave out of
version control.

Programs are compiled separately: the standard library (`fckt --standard`) and each library
(`fckt --library`) once, with `ocamlopt -c`, into the cache, in a folder for each fckt and OCaml;
then each program on its own (`fckt -L`), which is linked with them. `fckt --version`, which says
which fckt compiled them, is asked once for each fckt, as it starts a JVM: a build with nothing to
do takes a few hundredths of a second. Each compile also writes `.kiln/paths`: the
project's source folders and its libraries' interfaces, where fckt's IntelliJ plugin finds them.

| Variable | |
| --- | --- |
| `FCKT` | The fckt compiler, if it isn't `fckt` on `PATH` |
| `KILN` | kiln, for the tasks that run it, if it isn't `kiln` on `PATH` |
| `KILN_HOME` | Where `kiln install` installs to, instead of `~/.kiln` |
| `KILN_LIB` | Where kiln's library is, instead of beside the program |
| `KILN_REPOSITORY` | The local repository, instead of `~/.kiln/repository` |
| `KILN_CACHE` | Where compiled libraries are kept, instead of `~/.kiln/cache` |

kiln's own tests, in `test`, build projects in `build/test-projects` with the kiln just built, with
a repository and a cache of their own.
