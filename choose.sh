#!/bin/bash
# choose.sh applies a deploy action to a deploy file and writes the result.
# stage puts the head of the source branch in staging, after checking that
# the required CI workflows passed on it; promote copies staging to
# production; redeploy changes nothing. It prints the commit message for
# the change as a GitHub Actions output.
#
# Usage: choose.sh ACTION DEPLOY-IN DEPLOY-OUT
set -euo pipefail
action=$1 in=$2 out=$3
case $action in
stage)
	src=$(jq -r .source "$in")
	commit=$(gh api "repos/$src/commits/$(jq -r .branch "$in")" --jq .sha)
	passed=$(gh api "repos/$src/actions/runs?head_sha=$commit&event=push&per_page=100" \
		--jq '.workflow_runs[] | select(.conclusion == "success") | .name')
	readarray -t checks < <(jq -r '.checks[]' "$in")
	for c in "${checks[@]}"; do
		if ! grep -qxF "$c" <<<"$passed"; then
			echo "error: $c has not passed on $commit" >&2
			exit 1
		fi
	done
	jq --arg c "$commit" --arg g "$(go env GOVERSION)" \
		'.staging = {commit: $c, go: $g, digest: null}' "$in" >"$out"
	echo "message=Stage ${commit:0:12}"
	;;
promote)
	if [ "$(jq .staging "$in")" = null ]; then
		echo "error: nothing is staged" >&2
		exit 1
	fi
	jq '.production = .staging' "$in" >"$out"
	echo "message=Promote $(jq -r '.staging.commit[0:12]' "$in")"
	;;
redeploy)
	cp "$in" "$out"
	echo "message=Record build digests"
	;;
*)
	echo "error: unknown action $action" >&2
	exit 1
	;;
esac
