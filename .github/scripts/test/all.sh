#!/usr/bin/env bash
# Every check that does not need Homebrew installed. Needs `gh` authenticated:
# the verification and add-a-tool suites deliberately run against live releases,
# because the failure mode worth catching is "GitHub changed what it returns".
set -uo pipefail
cd "$(dirname "$0")" || exit 1

FAILED=0
for suite in selection verification add-a-tool; do
	echo "== $suite"
	if bash "$suite.sh"; then
		echo
	else
		echo "   suite failed" >&2
		echo
		FAILED=1
	fi
done

if (( FAILED )); then
	echo "one or more suites failed" >&2
	exit 1
fi
echo "all suites passed"
