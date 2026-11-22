#!/bin/bash
# build-site.sh builds the Pages site for the production and staging builds
# named in a deploy file, and writes a copy of the deploy file with each
# build's digest filled in. A build whose digest is already recorded must
# reproduce it exactly, so production always serves the bytes that were
# tested in staging.
#
# Usage: build-site.sh DEPLOY-IN DEPLOY-OUT SITE-DIR
set -euo pipefail
in=$1 out=$2 site=$(realpath -m "$3")
src=$(mktemp -d)
git clone -q --filter=blob:none "https://github.com/$(jq -r .source "$in")" "$src"
mkdir -p "$site"
cp "$in" "$out"

# Each build goes in a directory named for its commit, so a browser never
# combines cached files from different builds: the asset names are fixed.
build() {
	local slot=$1 commit dir digest want
	commit=$(jq -r ".$slot.commit" "$out")
	dir=$site/${commit:0:12}
	if [ ! -d "$dir" ]; then
		git -C "$src" checkout -q --detach "$commit"
		npm ci --prefix "$src/webui" --no-audit --no-fund
		GOTOOLCHAIN=$(jq -r ".$slot.go" "$out") make -C "$src" -f Makefile.wasm WASM_OUT="$dir"
	fi
	digest=$(cd "$dir" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
	want=$(jq -r ".$slot.digest // empty" "$out")
	if [ -n "$want" ] && [ "$want" != "$digest" ]; then
		echo "error: $slot build of $commit has digest $digest, but $want is recorded" >&2
		exit 1
	fi
	jq --arg s "$slot" --arg d "$digest" '.[$s].digest = $d' "$out" >"$out.tmp"
	mv "$out.tmp" "$out"
}

# pointer writes PAGE as a copy of the slot's index.html whose base URL is
# the slot's build directory, so the page's URL stays the same across builds.
pointer() {
	local slot=$1 page=$site/$2 up=$3 commit
	mkdir -p "$(dirname "$page")"
	if [ "$(jq ".$slot" "$out")" = null ]; then
		printf '<!DOCTYPE html>\n<title>SatPulse Workbench</title>\n<p>No %s build is deployed.</p>\n' "$slot" >"$page"
		return
	fi
	commit=$(jq -r ".$slot.commit" "$out")
	grep -q '<head>' "$site/${commit:0:12}/index.html"
	sed "0,/<head>/s||<head>\n<base href=\"$up${commit:0:12}/\">|" "$site/${commit:0:12}/index.html" >"$page"
}

for slot in production staging; do
	if [ "$(jq ".$slot" "$out")" != null ]; then
		build "$slot"
	fi
done
pointer production index.html ./
pointer staging staging/index.html ../
