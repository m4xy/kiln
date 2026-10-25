#!/bin/sh
# Builds kiln for the first time, with fckt and ocamlopt, then has it install itself: to ~/.kiln,
# or KILN_HOME. After that, kiln builds itself: kiln build, kiln install.
set -e
cd "$(dirname "$0")"
FCKT=${FCKT:-fckt}
mkdir -p build/ocaml build/bin
"$FCKT" src/main.fk -o build/ocaml/kiln.ml 2>/dev/null
ocamlopt -I +unix unix.cmxa -w -a build/ocaml/kiln.ml -o build/bin/kiln
FCKT="$FCKT" build/bin/kiln install
