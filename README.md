# kiln

kiln builds projects: it runs their tasks, each once and after what it depends on, and publishes
them as libraries for other projects to use. What a project is in is its plugins' to know: kiln's
own, `Fckt`, builds [fckt](https://github.com/m4xy/fckt), compiling, running and publishing it, and
[fk-tests](https://github.com/m4xy/fk-tests) brings tests. Its build scripts are fckt, and it's
written in fckt, and builds itself.

A project is a folder with a `build.fk`, which says what the project is, in fckt; beside it, or
above, `settings.fk` says what build scripts are compiled with:

```kotlin
// settings.fk
settings = Settings(uses = [library("uk.m4xy:fk-tests-kiln:0.1.0")])
```

```kotlin
// build.fk
import uk.m4xy.kiln.fckt.Fckt
import uk.m4xy.fktests.kiln.*

project = Project(name = "shop")

plugins = [Fckt(), FkTests()]
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

Every project has `clean`, `check` and `build`; its plugins bring the rest, as `Fckt` brings
`compile`, part of `check`, and fk-tests `test`. Several tasks run in turn, each once and after the
tasks it depends on, and the tasks part of it: `kiln clean build`. What follows `--` goes to them,
as to the program for `run`. `kiln -C dir build` builds the project in `dir`; with `--quiet`, only
what the tasks print is printed, for the project alone, for another program to read.

| Task | |
| --- | --- |
| `clean` | Deletes `build` |
| `check` | Checks the project: runs the tasks part of it, as `compile` and a plugin's tests are; any of them failing fails it |
| `build` | `check`, then the tasks part of it |
| `tasks` | Lists the tasks |

## build.fk

A build script is fckt, with a `project`, and, if it has them, `plugins`, `tasks` and, beside it
from `settings.fk`, `settings`; kiln compiles it as it is, with a `main` that hands them on, so
what it leaves out is fckt's to say. It imports kiln's library, `uk.m4xy.kiln`, with `Builds` and
`Dependencies`, and `fckt.io`'s `Path`, `Paths`, `Files` and `Processes`, `Console` and `Fail`,
without saying. `Project`'s fields have defaults, but its `name`:

```kotlin
project = Project(
  name = "shop",
  version = "0.1.0",
  group = "",                     // who publishes it: uk.m4xy
  dependencies = [],              // library("uk.m4xy:json:1.2.0"), projectAt("../pricing")
  output = path("build"),
)
```

A task is a `Task(name, description, dependsOn, partOf, action)`, whose action is fckt that may
print, use files and run programs (`@Building`), given the `Invocation`: the project, and what follows
`--`. A task `partOf` another runs before it, as if that depended on it. A build script adds its
own by declaring `tasks`, which replace any of the same name, every project's or a plugin's.

A task is named by a `TaskName`, never by a string: one of the `StandardTask`s every project has,
`Clean`, `Check` and `Build`, or `Named(...)`, whose name is written once, by what makes the task,
as a value the rest use, so that a name mistyped doesn't compile. Fckt's are `FcktTasks`';
the command line's `kiln compile` is the only place a task's name is text:

```kotlin
import uk.m4xy.kiln.fckt.Fckt
import uk.m4xy.kiln.fckt.FcktTasks

project = Project(name = "shop", version = "1.2.0")

plugins = [Fckt()]

stamp = Named("stamp")

tasks = [
  Task(stamp, "Writes the version", dependsOn = [FcktTasks.compile], action = build -> build.project.output.resolve("VERSION").writeText(build.project.version)),
  Task(Named("lint"), "Looks at the code", partOf = [Check], action = build -> println("  looks fine")),
]
```

## fckt

`Fckt`, in kiln's library, as `uk.m4xy.kiln.fckt.Fckt`, builds a project in fckt: it compiles
`src/main.fk` and the packages in `src` to `build/bin/<name>`, or, with no `src/main.fk`, checks
them as a library, to `build/library`. What's up to date isn't done again: a program whose sources,
libraries, fckt and OCaml are what they were isn't compiled again; `kiln clean` forgets. Every
project has fckt's standard library, `fckt:std`, the one beside the fckt it's built with, which
`Fckt` compiles once and gives it as it does any library: its files import what they use of it,
`import fckt.io.Console`.

| Task | |
| --- | --- |
| `compile` | Compiles the program to `build/bin/<name>`, or the library to `build/library`; part of `check` |
| `run` | Runs the program, with what follows `--`; it failing fails the build |
| `publishLocal` | Checks the project, then publishes its packages, under its group's folder, as a library to the local repository |
| `roots` | Prints the folders the project's packages, and its folder projects', are in, the libraries it uses, and its repositories: `root src`, `library uk.m4xy:json:1.2.0`, and any OCaml packages, `ocaml-package ssl`, a line each, as `ResolvedText` writes and reads them; another project that depends on it asks for them, `kiln --quiet roots` |
| `format` | Lays out the project's code, `src`, `test`, `build.fk` and `settings.fk`, as `fckt --format` does: a list too wide for its line, at 100 columns, goes an item to a line |
| `checkFormat` | Part of `check`: fails, saying where, if the project's code isn't laid out as `format` lays it out |

A project laid out otherwise says so with a module that follows `FcktConfiguration`, whose
`layout()` is a `FcktLayout(main, sources, standardLibrary, ocamlPackages)`, as fckt's standard library does, which
can't have itself:

```kotlin
import uk.m4xy.kiln.fckt.*

module WithoutStd : FcktConfiguration {
  layout(): FcktLayout = FcktLayout(standardLibrary = false)
}

plugins = [Fckt(WithoutStd)]
```

A project whose externals call OCaml packages, as installed by [opam](https://opam.ocaml.org), lists
them in `ocamlPackages`: `FcktLayout(ocamlPackages = ["ssl"])`, as fk-http does. It's then compiled
and linked through `ocamlfind`, or through `opam exec -- ocamlfind` where `ocamlfind` isn't on PATH.
The packages are published with the library, in its `ocaml-packages` file, and passed on to folder
projects that depend on it, through `kiln roots`. So a program that uses it, directly or through
another library, is linked with them without saying so; their names are all it needs.

### Processors

A processor writes code from what a project declares, before it's compiled, as a serialization
library writes a serializer for each type annotated for it. It's a module in a library that follows
[fckt.symbols](https://github.com/m4xy/fckt/tree/main/symbols)' `Processor`, and a project lists it,
by its full name, with the libraries it's in:

```kotlin
module Described : FcktConfiguration {
  layout(): FcktLayout = FcktLayout(processors = [
    Processor("uk.m4xy.describe.Describer", [library("uk.m4xy:describe:0.1.0")]),
  ])
}

plugins = [Fckt(Described), FkTests(StandardTests, Described)]
```

A project with processors has the task `process`, which `compile`, and fk-tests' `test`, depend on.
It makes each processor a program, of its libraries and a main that has `Processing` run it, gives
it what `fckt --symbols` says the project's sources declare, and has it write its files to
`build/generated/<module>`, the layout's `generated`, emptied first. Those folders are then the
project's sources too: its code, and its tests, use what was written as their own, and it's
published with the library. What a processor stops at, it says where, as a compiler's errors do,
and the build fails. A processor runs again only when the project's sources, or it, have changed.

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
  tasks(project: Project): List<Task> = [Task(Named("greet"), "Greets the project", action = build -> println(W.greeting()))]
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

A library is a project with a `group`, a reversed domain it owns. Publishing it puts what its
plugin publishes in the local repository, `~/.kiln/repository/<group>/<name>/<version>`, with a
list of what it depends on, which is all of it kiln reads: a dependency on a folder project, which
might change under it, stops it. `Fckt`'s `kiln publishLocal` checks it, and publishes its
packages, which must be in a folder of the group's name, so two libraries' never meet.

```kotlin
// units/build.fk, with its packages in src/uk/m4xy/units, and plugins = [Fckt()], as each has
project = Project(name = "units", group = "uk.m4xy", version = "1.0.0")

// money/build.fk
project = Project(name = "money", group = "uk.m4xy", version = "2.1.0", dependencies = [library("uk.m4xy:units:1.0.0")])

// shop/build.fk: a published library, and a project straight from its folder, as it is now
project = Project(name = "shop", dependencies = [library("uk.m4xy:money:2.1.0"), projectAt("../pricing")])
```

A project's packages are then found in its own folders, and its folder projects', with the
libraries each uses, as `kiln -C <folder> --quiet roots` says. Where two ask for a library in different
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

kiln reads nothing of its scripts but what they declare, as values, as fckt checks them: none of it
passes as text. It finds `settings.fk`, here or in the nearest folder above, and compiles it, as it
is, beside a `main` that hands the `settings` it declares to `uk.m4xy.kiln.launch.Launch`, and runs
that: what's said there, where libraries are looked for, what build scripts use and which projects
are built with this one, applies here if `settings.fk` is here, or lists this folder in its
projects, with its folders, as `Folders` makes them, from where it is. Then it compiles `build.fk`,
with `settings.fk` beside it if it applies and what that says build scripts use, beside a `main`
that hands `project`, `tasks`, `plugins` and `settings` to `uk.m4xy.kiln.Builds.runBuild`, with
`fckt --import ...` and `ocamlopt`, to a program, `.kiln/build`, again only when the scripts or kiln
change, and runs it. A script that doesn't declare `tasks`, `plugins` or `settings` has
`uk.m4xy.kiln.defaults`', none, none and `Settings()`'s; one that doesn't declare `project`, or a
`settings.fk` without `settings`, is told so by fckt. That's `uk.m4xy.kiln.launch`, internal to kiln
but for `Launch`'s `withSettings`, which build scripts don't see; `src/main.fk` reads the command
line. The one text that passes between programs is what `kiln roots` prints, for a project that
depends on this one, as `ResolvedText`, which follows the standard library's `Format`, so it reads
back what it writes, as a test checks. The tasks are fckt too, in
`src/uk/m4xy/kiln`: they call `fckt` and `ocamlopt`. `build` and `.kiln` are what to leave out of
version control.

`Fckt` compiles programs separately: fckt's core (`fckt --core`), the standard library, from the source
`fckt --std-path` says is beside fckt, and each library (`fckt --library`) once, with `ocamlopt
-c`, into the cache, in a folder for each fckt and OCaml; then each program on its own (`fckt -L`),
which is linked with them. `fckt --version`, which says
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
