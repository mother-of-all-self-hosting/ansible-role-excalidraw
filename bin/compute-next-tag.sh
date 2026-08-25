#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Prints the tag that the currently checked out commit should be released as,
# or nothing at all if it does not warrant a release.
#
# Usage: bin/compute-next-tag.sh
#
# Tags look like `v<version>-<release>`, which is what this repository has always
# published (v2023.12.15-0 ... v2025.12.5-6).
#
# Excalidraw is unusual among the roles of this fleet in that the software it
# deploys has no versions at all: `excalidraw/excalidraw` on Docker Hub carries a
# single usable tag, `latest`, the image has no version label, and the self-build
# path this role takes by default compiles the `master` branch. There is nothing
# to read a version out of, which is why `excalidraw_version` says `latest` and
# why the version component of the tags here is a date somebody picked by hand.
# `ansible-role-excalidraw-room`, in the same situation, is at v2023.12.15-9.
#
# So:
#
# - while `excalidraw_version` is `latest`, the version component is inherited
#   from the newest tag that already exists, and only the release counter moves
# - should Excalidraw ever start publishing versions and `excalidraw_version`
#   name one, that version is used instead, and its counter starts at 0
#
# Either way the answer comes from defaults/main.yml and the existing tags rather
# than from the commit message of whatever pull request got merged. That makes it
# independent of the order in which pull requests land, and lets any change to
# the role - a bugfix, a feature, a dependency bump - release itself without a
# human tagging it. The workflow this replaced looked for a `renovate[bot]`
# commit whose subject mentioned "docker tag to"; because Renovate has never had
# a version here to bump, it had never once produced a tag.

set -euo pipefail

repository_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$repository_path"

defaults_path='defaults/main.yml'

# Paths that shape the behavior of the role for its consumers. A commit touching
# only other paths (a README fix, CI configuration, Molecule tests) does not
# change what a playbook run does, and releasing it would only create churn in
# the repositories that consume this role.
role_defining_paths=(
	'defaults'
	'meta'
	'tasks'
	'templates'
)

# Anchored on `excalidraw_version:` so that none of the variables which merely
# start with it - `excalidraw_version_foo`, were one ever added - and none of the
# ones derived from it, such as `excalidraw_container_image_tag`, can be mistaken
# for it.
version="$(sed -nE 's|^excalidraw_version:[[:space:]]*"?([^"[:space:]]+)"?.*$|\1|p' "$defaults_path" | head -n1)"

if [ -z "$version" ]; then
	echo >&2 "Could not determine the Excalidraw version from $defaults_path"
	exit 1
fi

# Every tag this repository has ever published, newest last. The pattern is
# strict on purpose: only `v<numbers separated by dots>-<number>` counts, so a
# stray or hand-made tag cannot decide which series the next release belongs to.
released_tags="$(git tag --list 'v*' | grep -E '^v[0-9]+(\.[0-9]+)*-[0-9]+$' | sort -V || true)"

if [ "$version" = 'latest' ]; then
	# `latest` is a pointer, not a version. Stay in the series that is already
	# being published and move the release counter.
	newest_tag="$(echo "$released_tags" | tail -n1)"

	if [ -z "$newest_tag" ]; then
		echo >&2 "excalidraw_version is 'latest' and there is no previous tag to continue from"
		exit 1
	fi

	tag_prefix="${newest_tag%-*}-"
else
	# Excalidraw's own version is carried without a leading `v` (the `v` lives in
	# the tags), but tolerate one so that a future change of convention does not
	# produce a doubled prefix.
	tag_prefix="v${version#v}-"
fi

# Of all releases in this series, the highest release number. Sorted numerically,
# so that -10 is recognized as newer than -9. The dots are escaped because the
# prefix is about to be used as a regular expression.
tag_prefix_pattern="${tag_prefix//./\\.}"
last_release="$(echo "$released_tags" | sed -ne "s|^${tag_prefix_pattern}||p" | grep -E '^[0-9]+$' | sort -n | tail -n1 || true)"

if [ -z "$last_release" ]; then
	echo >&2 "Version ${tag_prefix%-} has never been released"
	echo "${tag_prefix}0"
	exit 0
fi

previous_tag="${tag_prefix}${last_release}"

if git diff --quiet "$previous_tag" HEAD -- "${role_defining_paths[@]}"; then
	echo >&2 "Nothing affecting the role has changed since $previous_tag"
	exit 0
fi

echo >&2 "The role has changed since $previous_tag"
echo "${tag_prefix}$((last_release + 1))"
