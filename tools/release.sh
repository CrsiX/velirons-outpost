#!/bin/bash
# Prepares a release from a clean HEAD: sets the version name in every Android
# export preset, raises their version code by one and writes the fastlane
# changelog for that code (the commit titles since the last release; edit it by
# hand before committing if you like) and stages that file. It never commits,
# tags or pushes: it prints the commands for that and exits.
#
# The committed export_presets.cfg is what F-Droid's update check reads at the
# newest tag, so the version lives there and not only in a build.
#
# usage:
#   tools/release.sh <major.minor.patch>
#
# example:
#   tools/release.sh 0.1.0

set -euo pipefail
cd "$(dirname "$0")/.."

usage="usage: tools/release.sh <major.minor.patch>"
version=${1:?$usage}
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "release: '$version' is not major.minor.patch" >&2
	exit 1
fi
tag="v$version"
presets=export_presets.cfg

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
	echo "release: tag $tag exists already" >&2
	exit 1
fi
# Only from a clean HEAD (no staged or unstaged changes to tracked files;
# untracked files don't count), so the release commit holds the version bump
# and the changelog and nothing else.
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
	echo "release: HEAD is not clean; commit or stash your changes first (git status)" >&2
	exit 1
fi

# The highest version code among the Android presets, plus one, for all of them.
code=$(awk '
	/^\[preset\.[0-9]+\]$/ { android = 0 }
	/^platform="Android"$/ { android = 1 }
	/^\[preset\.[0-9]+\.options\]$/ { in_opts = android }
	/^\[preset\.[0-9]+\]$/ { in_opts = 0 }
	in_opts && /^version\/code=[0-9]+$/ {
		split($0, kv, "="); if (kv[2] + 0 > max) max = kv[2] + 0; found = 1
	}
	END { if (found) print max + 1 }
' "$presets")
if [ -z "$code" ]; then
	echo "release: no Android preset with a version/code in $presets" >&2
	exit 1
fi

# The changelog F-Droid shows as "What's new": the commit titles since the last
# release tag (all of them before the first release).
changelog=fastlane/metadata/android/en-US/changelogs/$code.txt
last_tag=$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)
titles=$(git log --no-merges --format='- %s' --grep='^Release v' --invert-grep \
	${last_tag:+"$last_tag..HEAD"})
if [ -z "$titles" ]; then
	echo "release: no commits since ${last_tag:-the start}, nothing to release" >&2
	exit 1
fi
mkdir -p "$(dirname "$changelog")"
printf '%s\n' "$titles" > "$changelog"
# F-Droid cuts a changelog after 500 characters.
chars=$(wc -m < "$changelog")
if [ "$chars" -gt 500 ]; then
	echo "release: warning: $changelog has $chars characters, F-Droid shows only 500" >&2
fi

tmp=$(mktemp "$presets.XXXXXX")
trap 'rm -f "$tmp"' EXIT
awk -v code="$code" -v name="$version" '
	/^\[preset\.[0-9]+\]$/ { android = 0; in_opts = 0 }
	/^platform="Android"$/ { android = 1 }
	/^\[preset\.[0-9]+\.options\]$/ { in_opts = android }
	in_opts && /^version\/code=/ { print "version/code=" code; next }
	in_opts && /^version\/name=/ { print "version/name=\"" name "\""; next }
	{ print }
' "$presets" > "$tmp"
mv "$tmp" "$presets"

git add "$changelog"

cat <<DONE
Prepared $tag (version code $code): changed $presets, wrote and staged $changelog.
Look at the changes (git diff HEAD), then commit, tag and push:

  git add $presets
  git commit -m "Release $tag"
  git tag -a $tag -m "Release $tag"
  git push --follow-tags

Once CI has made the release, attach the signed APK (the release key stays here):
download the artifact velirons-outpost-android-release from the tag's run
(Actions tab), unzip it, then

  apksigner sign --ks <your keystore> --ks-key-alias <alias> \\
    --out velirons-outpost-$tag.apk velirons-outpost-unsigned.apk
  apksigner verify --print-certs velirons-outpost-$tag.apk

and add velirons-outpost-$tag.apk to the $tag release (Edit, attach binaries).
Keep that exact name: F-Droid's Binaries: URL fetches it. Do it soon after tagging.

If you edit the changelog first, git add it again. To throw it all away instead:

  git checkout -- $presets && git rm -qf $changelog
DONE
