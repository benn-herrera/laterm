# laterm — Rust build convenience wrapper over cargo.
# (The Go research prototype keeps its own Makefile under prototype/.)
#
# Release targets. Cross-compiling all three from one host needs the target's
# linker/toolchain; in practice build each on its native OS (CI does this on
# tags via .github/workflows/release.yml) or run `make dist` on each machine.
DIST    := "dist"

default:
  @just --list

all: build test

## setup: install rustup targets + cargo-zigbuild for cross-compiling.
## Requires zig (brew install zig) — zig provides the cross-linker so Rust
## cross-compiles from any host (like Go/zig), incl. Mac → Linux/Windows.
setup:
	rustup target add $(TARGETS)
	cargo install cargo-zigbuild || true
	@command -v zig >/dev/null || echo "NOTE: install zig (brew install zig) for cross-compilation"

## build: debug build for the host
build:
	cargo build

## test: run the unit tests
test:
	cargo test

## fmt: format the source
fmt:
	cargo fmt

## lint: clippy across all targets
lint:
	cargo clippy --all-targets

## check: type-check for every release target (validates cross-platform cfg)
check:
	@for t in $(TARGETS); do echo "check $$t"; cargo check --target $$t || exit 1; done

## clean: remove build artifacts
clean:
	cargo clean
	rm -rf $(DIST)

run: build
	./target/debug/laterm

_tag-clean:
    @git diff --quiet HEAD || { echo "tag: tracked files have uncommitted changes — commit them, then tag" >&2; exit 1; }

[doc("NEEDS a signing key git tag -s can use: create and verify a signed annotated tag v<version>, <version> being go run ./cmd --version; runs no gates, pushes nothing")]
tag: _tag-clean
    @ver="v$(cargo run ./src/main.rs --version)"; [[ "${ver}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "tag: version ${ver} is not v<major>.<minor>.<patch>" >&2; exit 1; }; GPG_TTY=$(tty) git tag -s "${ver}" -m "release ${ver}"; git tag -v "${ver}"

# The tap clone's one source: its origin URL, which the clone and the remote
# set-up both take, and the location its .gitignore entry names.
TAP_DIR := "homebrew-laterm"
TAP_URL := "git@github.com:benn-herrera/homebrew-laterm.git"
[doc("set up the sibling Homebrew tap clone at homebrew-laterm/: clone it, or add the missing origin to a clone; leave a correct clone alone, refuse any other; one line says what was done")]
tap:
    @TAP_DIR="{{TAP_DIR}}" TAP_URL="{{TAP_URL}}" scripts/tap.sh

[doc("LIVE; NEEDS the tap clone, a pushed release: set the tap formula's v<version> tarball and sha256 and commit it there, pushing nothing; raise go.mod's go line if Go no longer supports it, uncommitted")]
tap-update:
    @TAP_DIR="{{TAP_DIR}}" scripts/tap-update.sh

[doc("LIVE; NEEDS brew and the tap clone; DESTRUCTIVE to this machine's brew install of laterm: reinstall it from a scratch formula over a tarball of the working tree's tracked files; the tap is untouched")]
tap-local:
    @TAP_DIR="{{TAP_DIR}}" scripts/tap-local.sh


ADJAGENT_VER := "0.15.0"
VENV := justfile_dir() / ".venv"
PYTHON := "\"" + VENV + "/bin/python" + "\""
ADJAGENT := "\"" + VENV + "/bin/adjagent" + "\""
agents:
  #!/usr/bin/env bash
  set -euo pipefail
  [[ -x {{PYTHON}} ]] || python3 -m venv "{{VENV}}"
  [[ -x {{ADJAGENT}} && "$({{ADJAGENT}} --version)" == "{{ADJAGENT_VER}}" ]] || \
    {{PYTHON}} -m pip install --upgrade pip "git+https://github.com/benn-herrera/adjagent@v{{ADJAGENT_VER}}"
  {{ADJAGENT}} install . --harness=claude
  {{ADJAGENT}} install . --harness=opencode
