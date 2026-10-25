# kiln

kiln builds [fckt](https://github.com/m4xy/fckt) projects: it compiles them, runs them, checks
them, and publishes them as libraries for other projects to use. What it does is tasks; plugins
bring more, as [fk-tests](https://github.com/m4xy/fk-tests) brings tests. It's written in fckt, and
builds itself.

A project is a folder with a `build.fk`, which says what the project is, in fckt; beside it, or
above, `settings.fk` says what build scripts are compiled with:

```kotlin
// settings.fk
settings = Settings(uses = [library("uk.m4xy:fk-tests-kiln:0.1.0")])
```

```kotlin
// build.fk
import uk.m4xy.fktests.kiln.FkTests.*

project = Project(name = "shop")

tasks = [fkTests()]
```

```
$ kiln build
> Task :compile
> Task :test
  prices.fk
    passed sumsItems
    passed emptyIsZero
  2 passed, 0 failed
> Task :check
> Task :build
BUILD SUCCESSFUL
$ kiln run -- a b
```

## Installing

kiln needs [fckt](https://github.com/m4xy/fckt) and OCaml 5.1 or newer, with
`ocamlopt`. The first time, `bootstrap.sh` builds kiln with fckt, publishes fk-tests, whose plugin
kiln's own build uses, and has kiln install itself:

```sh
FCKT=/path/to/fckt ./bootstrap.sh    # FCKT if fckt isn't on PATH
export PATH="$HOME/.kiln/bin:$PATH"
```

It installs `~/.kiln/bin/kiln`, and kiln's library, which build scripts use, in `~/.kiln/lib/kiln`;
`KILN_HOME` puts both elsewhere. After that, kiln builds itself: `kiln build`, `kiln install`.

## Tasks

`kiln build`, run in a project's folder, compiles `src/main.fk` and the packages in `src` to
`build/bin/<name>`, then checks the project: runs the tasks part of `check`, any of which failing
fails the build. kiln has none of its own; a plugin's are, as fk-tests' `test` is. Several tasks
run in turn, each once and after the tasks it depends on: `kiln clean build`. What follows `--`
goes to them, as to the program for `run`. `kiln -C dir build` builds the project in `dir`. What's
up to date isn't done again: a program whose sources, libraries, fckt and OCaml are what they were
isn't compiled again; `kiln clean` forgets.

| Task | |
| --- | --- |
| `compile` | Compiles the program to `build/bin/<name>`; a library, which has no `src/main.fk`, is compiled as a library, to `build/library` |
| `check` | Checks the project: runs the tasks part of it, as a plugin's tests are |
| `build` | `compile`, then `check` |
| `run` | Runs the program, with what follows `--`; it failing fails the build |
| `clean` | Deletes `build` |
| `publishLocal` | Compiles and checks, then publishes the project as a library to the local repository |
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
  output = path("build"),
)
```

A task is a `Task(name, description, dependsOn, partOf, action)`, whose action is fckt that may
print, use files and run programs (`@Building`), given the `Build`: the project, and what follows
`--`. A task `partOf` another runs before it, as if that depended on it. A build script adds its
own by declaring `tasks`, which replace any of the same name, every project's or a plugin's:

```kotlin
project = Project(name = "shop", version = "1.2.0")

tasks = [
  Task("stamp", "Writes the version", dependsOn = ["compile"], action = build -> build.project.output.resolve("VERSION").writeText(build.project.version)),
  Task("lint", "Looks at the code", partOf = ["check"], action = build -> println("  looks fine")),
]
```

## Plugins

A plugin is a module that follows kiln's `spec Plugin`, which says its `name()` and the
`tasks(project)` it makes, kiln adding them to every project's. It's in a library, or a project,
which depends on kiln's library, `uk.m4xy.kiln`, as `kiln()`: kiln has it, so it's never published
with the plugin. `settings.fk` says what build scripts use, and a build script applies the
plugins it wants from them:

```kotlin
// settings.fk
settings = Settings(uses = [library("uk.m4xy:greeting:1.0.0")])    // or projectAt("../greeting")
```

```kotlin
// build.fk
import uk.m4xy.greeting.*

project = Project(name = "shop")

module Howdy : Words {
  greeting(): String = "howdy"
}

plugins = [Greetings(W = Howdy)]
```

A plugin that can be configured is a functor, whose modules have defaults: `Greetings()` greets
with `Hello`, and `Greetings(W = Howdy)` with what the script says. What configures it is checked
against its spec, where it's applied, so nothing is configured by a name that's only looked up.

```kotlin
// greeting's src/uk/m4xy/greeting: Words.fk, Hello.fk and Greetings.fk; its build.fk has dependencies = [kiln()]
spec Words {
  greeting(): String
}

module Hello : Words {
  greeting(): String = "hello"
}

module Greetings(W: Words = Hello) : Plugin {
  name(): String = "greetings"
  tasks(project: Project): List<Task> = [Task("greet", "Greets the project", action = build -> println(W.greeting()))]
}
```

Plugins add tasks, and never change each other's, so the order they're applied in doesn't matter;
tasks run in the order `dependsOn` and `partOf` say. Two plugins can't make a task of the same
name, nor a plugin one every project has: the script makes that task itself, in `tasks`, to say
which it is.

What kiln does for its own tasks, a plugin's can: `resolve` a project's dependencies, with others,
`linking` compiles them, `compileProgram` and `linkProgram` make a program, `buildProgram` makes
one only when `inputs` changed, and `rememberScope` tells editors that a folder's files see more
libraries, as `.kiln/scopes/<name>`.

## settings.fk

What a build is made of, and where what it uses is from, as `settings = Settings(...)`:

```kotlin
settings = Settings(
  // Where libraries are looked for, in the order they're tried: Local is ~/.kiln/repository, or
  // KILN_REPOSITORY, where publishLocal publishes; At, any folder laid out as it is.
  repositories = [At(path("../team-repository")), Local],
  // What build scripts are compiled with, for the plugins they apply.
  uses = [library("uk.m4xy:fk-tests-kiln:0.1.0")],
  // The projects built with the one here: kiln build here builds each, in its folder, then this one.
  projects = [path("runner"), path("kiln")],
)
```

It's in a project's folder, or the nearest above it that lists it in `projects`, which share it; a
folder it doesn't list doesn't. kiln reads it before the build script, compiled with kiln's
library alone, as it says what the script is compiled with; it's fckt, so it's checked as the
script is, and as a value, `settings` can't do anything but say what it is. A library is taken from
the first repository that has it, for a project's dependencies as for what scripts use. A project
without plugins, or libraries from anywhere but `Local`, needs none.

## Libraries and dependencies

A library is a project with a `group`, a reversed domain it owns, and its packages in a folder of
that name, so two libraries' packages never meet. `kiln publishLocal` compiles and checks it, then
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

kiln compiles `settings.fk` with a `main` that prints what it says, and runs it; then it adds a
`main` to the build script, which hands `project`, with the settings' repositories, and `tasks` and
`plugins` if it declares them, to `uk.m4xy.kiln.Builds.runBuild`. It compiles that with `fckt --import ...` and `ocamlopt` to a
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

kiln's own tests, in `test`, are fk-tests', which build projects in `build/test-projects` with the
kiln just built, with a repository and a cache of their own.
