#!/usr/bin/env bash
#
# mayhem/build.sh — build the hevcesbrowser fuzz harness, its standalone reproducer,
# and the project's own boost.test functional suite.
#
# Runs inside the commit image (mayhem/Dockerfile) as `mayhem` in /mayhem. The base image
# exports the build contract (CC, CXX, LIB_FUZZING_ENGINE, SANITIZER_FLAGS, DEBUG_FLAGS,
# STANDALONE_FUZZ_MAIN, SRC). This script is idempotent and air-gapped: every dependency
# (boost) is baked into the image by the Dockerfile, so a `--network none` re-run succeeds.
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' (empty) — must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
: "${STANDALONE_FUZZ_MAIN:=/opt/mayhem/StandaloneFuzzTargetMain.c}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

CXXSTD="-std=c++11"
PARSER_INC="-I$SRC/hevcparser/include"
PARSER_SRCS=(
  hevcparser/src/HevcParser.cpp
  hevcparser/src/Hevc.cpp
  hevcparser/src/HevcParserImpl.cpp
  hevcparser/src/BitstreamReader.cpp
  hevcparser/src/HevcUtils.cpp
)

# ---------------------------------------------------------------------------
# 1) Build the parser library instrumented with $SANITIZER_FLAGS + $DEBUG_FLAGS
#    (so the FUZZED code — not just the harness — is instrumented and carries
#    DWARF < 4 symbols).
# ---------------------------------------------------------------------------
BUILD_FUZZ="$SRC/build-fuzz"
rm -rf "$BUILD_FUZZ"
mkdir -p "$BUILD_FUZZ"

objs=()
for s in "${PARSER_SRCS[@]}"; do
  o="$BUILD_FUZZ/$(basename "${s%.cpp}").o"
  $CXX $CXXSTD $SANITIZER_FLAGS $DEBUG_FLAGS $PARSER_INC -fPIC -c "$s" -o "$o"
  objs+=("$o")
done
ar rcs "$BUILD_FUZZ/libhevcparser.a" "${objs[@]}"

# ---------------------------------------------------------------------------
# 2) The libFuzzer harness (target: hevcesbrowser-console) and a standalone,
#    non-fuzzer reproducer over the same harness.
# ---------------------------------------------------------------------------
$CXX $CXXSTD $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE $PARSER_INC \
  "$SRC/mayhem/fuzz_hevcparser.cpp" "$BUILD_FUZZ/libhevcparser.a" \
  -o /mayhem/hevcesbrowser-console

# C++ harness: compile the standalone driver as a C object first so its
# LLVMFuzzerTestOneInput reference keeps C linkage (clang++ would mangle it).
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o "$BUILD_FUZZ/standalone_main.o"
$CXX $CXXSTD $SANITIZER_FLAGS $DEBUG_FLAGS $PARSER_INC \
  "$SRC/mayhem/fuzz_hevcparser.cpp" "$BUILD_FUZZ/standalone_main.o" "$BUILD_FUZZ/libhevcparser.a" \
  -o /mayhem/hevcesbrowser-console-standalone

# ---------------------------------------------------------------------------
# 3) Build the project's OWN functional test suite (upstream boost.test target
#    hevcparser_test) with the project's NORMAL flags — a separate, clean build.
#    mayhem/test.sh only RUNS this; it never compiles.
# ---------------------------------------------------------------------------
BUILD_TESTS="$SRC/build-tests"
rm -rf "$BUILD_TESTS"
mkdir -p "$BUILD_TESTS"
cmake -S "$SRC" -B "$BUILD_TESTS" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_C_FLAGS="$COVERAGE_FLAGS" -DCMAKE_CXX_FLAGS="$COVERAGE_FLAGS" \
  -DCMAKE_EXE_LINKER_FLAGS="$COVERAGE_FLAGS" >/dev/null
cmake --build "$BUILD_TESTS" -j"$MAYHEM_JOBS" --target hevcparser_test

# The upstream CMake writes executables to hevcparser/build/ (EXECUTABLE_OUTPUT_PATH),
# so the test runner lands at $SRC/build/hevcparser_test. Expose a stable path too.
if [ -x "$SRC/build/hevcparser_test" ]; then
  cp -f "$SRC/build/hevcparser_test" "$BUILD_TESTS/hevcparser_test"
fi

echo "build.sh: done"
