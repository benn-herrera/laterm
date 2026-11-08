#!/usr/bin/env bash
# After a release is pushed: points the tap's formula at the v<version> source
# tarball and its sha256, commits that change in the tap where the formula changed (pushing nothing), then
# keeps go.mod's `go` line inside Go's supported window.
#
# The window is the two newest minors https://go.dev/dl/?mode=json lists. A
# go.mod line older than the older of them is raised to 1.<older>.0 and left
# uncommitted in this repository; this script makes no commit here.
#
# Inputs (environment): TAP_DIR, the tap clone's location relative to this
# repository's root.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1
cd "${script_dir}/.." || exit 1

: "${TAP_DIR:?TAP_DIR is not set: the tap clone location relative to this repository}"

ver="v$(go run ./cmd --version)"
url="https://github.com/benn-herrera/laterm/archive/refs/tags/${ver}.tar.gz"
sha="$(curl -fsSL "${url}" | shasum -a 256 | cut -d' ' -f1)" || \
  { printf 'ensure laterm tag %s was created and pushed to github\n' "${ver}"; exit 1; }
f="${TAP_DIR}/Formula/laterm.rb"
tools/scripts/tap-formula-set.sh "${f}" "${url}" "${sha}"
if ! git -C "${TAP_DIR}" diff --quiet HEAD -- Formula/laterm.rb; then
    git -C "${TAP_DIR}" commit -S -m "laterm ${ver}" -- Formula/laterm.rb
fi
