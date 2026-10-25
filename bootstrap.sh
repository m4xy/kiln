#!/bin/sh
# Builds kiln for the first time, with fckt and ocamlopt; publishes fk-tests, whose plugin kiln's
# build uses for its tests, from FK_TESTS, ../fk-tests, or a clone of it in build; then has kiln
# install itself: to ~/.kiln, or KILN_HOME. After that, kiln builds itself: kiln build, kiln install.
set -e
cd "$(dirname "$0")"
FCKT=${FCKT:-fckt}
mkdir -p build/ocaml build/bin
"$FCKT" src/main.fk -o build/ocaml/kiln.ml 2>/dev/null
ocamlopt -I +unix unix.cmxa -w -a build/ocaml/kiln.ml -o build/bin/kiln
KILN="$PWD/build/bin/kiln"
FK_TESTS=${FK_TESTS:-../fk-tests}
if [ ! -d "$FK_TESTS" ]; then
  FK_TESTS=build/fk-tests
  [ -d "$FK_TESTS" ] || git clone -q https://github.com/m4xy/fk-tests "$FK_TESTS"
fi
for project in runner . kiln; do
  FCKT="$FCKT" KILN="$KILN" KILN_LIB="$PWD/src" "$KILN" -C "$FK_TESTS/$project" publishLocal
done
FCKT="$FCKT" "$KILN" install
