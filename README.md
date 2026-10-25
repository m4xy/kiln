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

kiln needs [fckt](https://github.com/m4xy/fckt) and OCaml 5.1 or newer, with `ocaml` and
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
`kiln -C dir build` builds the project in `dir`.

| Task | |
| --- | --- |
| `compile` | Compiles the program to `build/bin/<name>`; a library, which has no `src/main.fk`, has every package checked |
| `test` | Compiles and runs each program in `test`: each file there with a `main`; the others are what the tests share |
| `build` | `compile`, then `test` |
| `run` | Runs the program, with what follows `--`; it failing fails the build |
| `clean` | Deletes `build` |
| `publishLocal` | Compiles and tests, then publishes the project as a library to the local repository |
| `roots` | Prints the folders the project's packages, and its dependencies', are in |
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

A project's packages are then found in its own folders, its libraries' in the repository, with
theirs, and its folder projects', with theirs, as `kiln -C <folder> roots` says. Where two ask
for a library in different versions, the higher is used.

## How it works

kiln adds a `main` to the build script, which hands `project`, and `tasks` if it declares them, to
`uk.m4xy.kiln.Builds.runBuild`. It compiles that with `fckt --import ...` to `.kiln/build.ml`,
again only when the script or kiln changes, and runs it with `ocaml`. The tasks are fckt too, in
`src/uk/m4xy/kiln`: they call `fckt` and `ocamlopt`. `build` and `.kiln` are what to leave out of
version control.

| Variable | |
| --- | --- |
| `FCKT` | The fckt compiler, if it isn't `fckt` on `PATH` |
| `KILN` | kiln, for the tasks that run it, if it isn't `kiln` on `PATH` |
| `KILN_HOME` | Where `kiln install` installs to, instead of `~/.kiln` |
| `KILN_LIB` | Where kiln's library is, instead of beside the program |
| `KILN_REPOSITORY` | The local repository, instead of `~/.kiln/repository` |

kiln's own tests, in `test`, build projects in `build/test-projects` with the kiln just built.
