#!/usr/bin/env bash
#
# mayhem/test.sh — RUN the project's OWN boost.test functional suite (built by build.sh).
# This is the ENTIRE upstream test suite (hevcparser_test: tests/main.cpp, Params.cpp,
# Parsing.cpp) — 15 known-answer parsing tests that assert exact syntax-element values
# decoded from real HEVC sample streams. A PATCH that neuters the parser to a no-op /
# exit(0) breaks these assertions and FAILS here (anti-reward-hacking).
#
# Emits a CTRF report + a `CTRF {...}` stdout marker; exits non-zero iff failed>0.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

# Locate the pre-built runner (build.sh must have produced it; do NOT compile here).
RUNNER=""
for c in "$SRC/build-tests/hevcparser_test" "$SRC/build/hevcparser_test"; do
  [ -x "$c" ] && RUNNER="$c" && break
done
if [ -z "$RUNNER" ]; then
  echo "test.sh: hevcparser_test runner not found — build.sh did not produce it" >&2
  emit_ctrf "boost-test" 0 1
  exit 1
fi

JUNIT="${TMPDIR:-/tmp}/hevcparser_junit.xml"
rm -f "$JUNIT"

# Run the whole suite; JUnit logger gives machine-readable per-case counts.
set +e
"$RUNNER" --logger=JUNIT,all,"$JUNIT" --report_level=no --color_output=no
run_rc=$?
set -e

if [ ! -s "$JUNIT" ]; then
  echo "test.sh: boost test produced no JUnit report (rc=$run_rc)" >&2
  emit_ctrf "boost-test" 0 1
  exit 1
fi

# Parse the aggregate <testsuite ...> attributes from the boost JUnit XML.
attrs=$(tr '\n' ' ' < "$JUNIT")
get_attr() { echo "$attrs" | grep -oE "$1=\"[0-9]+\"" | head -1 | grep -oE '[0-9]+'; }
tests=$(get_attr tests);      tests=${tests:-0}
failures=$(get_attr failures); failures=${failures:-0}
errors=$(get_attr errors);    errors=${errors:-0}
skipped=$(get_attr skipped);  skipped=${skipped:-0}

failed=$(( failures + errors ))
passed=$(( tests - failed - skipped ))
[ "$passed" -lt 0 ] && passed=0

emit_ctrf "boost-test" "$passed" "$failed" "$skipped"
