#!/usr/bin/env bash
# Turn this template into a new project: set the Go module path, rename the
# cmd/ binary directory, fill in the project name and description, and pick
# the operating systems CI runs tests on.
# Run once from the repository root; the script deletes itself when done.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./init.sh [--name NAME] [--description TEXT] [--module PATH]
                 [--macos | --no-macos] [--windows | --no-windows]

  --name         Project and binary name, e.g. my-app (default: from git remote)
  --description  One-line project description
  --module       Go module path, e.g. github.com/you/my-app (default: from git remote)
  --[no-]macos   Also run tests on macOS in CI (default: no)
  --[no-]windows Also run tests on Windows in CI (default: no)

Values not given as flags are prompted for.
EOF
}

die() {
  echo "init.sh: $*" >&2
  exit 1
}

name=""
description=""
module=""
macos=""
windows=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) name="${2-}"; shift 2 ;;
    --description) description="${2-}"; shift 2 ;;
    --module) module="${2-}"; shift 2 ;;
    --macos) macos=y; shift ;;
    --no-macos) macos=n; shift ;;
    --windows) windows=y; shift ;;
    --no-windows) windows=n; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
done

cd "$(dirname "$0")"
[[ -d cmd/template-go ]] || die "cmd/template-go not found; has the project already been initialized?"

ci=.github/workflows/ci.yaml
# LINT.IfChange(test_os)
ci_os_line='        os: ["ubuntu-latest"]'
agents_os_line='CI runs tests on Linux.'
# LINT.ThenChange(//.github/workflows/ci.yaml:test_os, //AGENTS.md:test_os)
grep -qxF -- "$ci_os_line" "$ci" || die "test matrix line not found in $ci"
grep -qxF -- "$agents_os_line" AGENTS.md || die "test OS line not found in AGENTS.md"

# Derive defaults from the origin remote: git@github.com:you/my-app.git and
# https://github.com/you/my-app.git both become github.com/you/my-app.
remote_module=""
if remote="$(git remote get-url origin 2>/dev/null)"; then
  remote_module="$(sed -E -e 's#^[a-z+]+://([^@/]+@)?##' -e 's#^[^@/]+@([^:]+):#\1/#' -e 's#\.git$##' <<<"$remote")"
fi

ask() {
  local prompt="$1" default="$2" reply
  if [[ ! -t 0 ]]; then
    [[ -n "$default" ]] || die "$prompt is required; pass it as a flag when not running interactively"
    echo "$default"
    return
  fi
  if [[ -n "$default" ]]; then
    read -r -p "$prompt [$default]: " reply
  else
    read -r -p "$prompt: " reply
  fi
  echo "${reply:-$default}"
}

[[ -n "$name" ]] || name="$(ask "Project name" "${remote_module##*/}")"
[[ "$name" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || die "name must be lowercase letters, digits, '.', '_' or '-': $name"

[[ -n "$description" ]] || description="$(ask "Description" "")"
[[ -n "$description" ]] || die "description must not be empty"

if [[ -z "$module" ]]; then
  default_module="$remote_module"
  if [[ -z "$default_module" ]] && login="$(gh api user --jq .login 2>/dev/null)"; then
    default_module="github.com/$login/$name"
  fi
  module="$(ask "Go module path" "$default_module")"
fi
[[ "$module" =~ ^[A-Za-z0-9._~/-]+$ ]] || die "invalid Go module path: $module"
# Tools such as go doc -http and go get treat a first element without a dot
# as a local-only path, so require a domain like github.com.
[[ "${module%%/*}" == *.* ]] || die "module path must start with a domain, e.g. github.com/you/$name: $module"

# Answer a yes/no question, defaulting to no; prints y or n.
ask_yes_no() {
  local reply
  [[ -t 0 ]] || { echo n; return; }
  read -r -p "$1 [y/N]: " reply
  case "$reply" in
    [yY] | [yY][eE][sS]) echo y ;;
    *) echo n ;;
  esac
}

[[ -n "$macos" ]] || macos="$(ask_yes_no "Also run tests on macOS in CI?")"
[[ -n "$windows" ]] || windows="$(ask_yes_no "Also run tests on Windows in CI?")"

test_os='"ubuntu-latest"'
os_names="Linux"
os_list=(Linux)
if [[ "$macos" == y ]]; then
  test_os+=', "macos-latest"'
  os_list+=(macOS)
fi
if [[ "$windows" == y ]]; then
  test_os+=', "windows-latest"'
  os_list+=(Windows)
fi
case "${#os_list[@]}" in
  2) os_names="${os_list[0]} and ${os_list[1]}" ;;
  3) os_names="${os_list[0]}, ${os_list[1]}, and ${os_list[2]}" ;;
esac

export INIT_NAME="$name" INIT_DESCRIPTION="$description" INIT_MODULE="$module"
export INIT_CI_OS_LINE="$ci_os_line" INIT_TEST_OS="$test_os"
export INIT_AGENTS_OS_LINE="$agents_os_line" INIT_OS_NAMES="$os_names"

perl -pi -e 's/^module template-go$/module $ENV{INIT_MODULE}/' go.mod
mv cmd/template-go "cmd/$name"
find . -name '*.go' -not -path './.git/*' -not -path './.jj/*' -exec perl -pi -e \
  's{"template-go/}{"$ENV{INIT_MODULE}/}g; s/template-go/$ENV{INIT_NAME}/g' {} +
perl -pi -e 's/\{\{ project \}\}/$ENV{INIT_NAME}/g; s/\{\{ description \}\}/$ENV{INIT_DESCRIPTION}/g' README.md AGENTS.md
# Drop the template-only notes from the README and AGENTS.md.
perl -0pi -e 's/\n<!-- init\.sh:start -->\n.*?<!-- init\.sh:end -->\n//s' README.md AGENTS.md
# Set the CI test matrix and drop the template's sync directives around it.
perl -0pi -e 's/^ *# init\.sh can add .*\n *# LINT\.IfChange\(test_os\)\n\Q$ENV{INIT_CI_OS_LINE}\E\n *# LINT\.ThenChange\(.*\)\n/        os: [$ENV{INIT_TEST_OS}]\n/m' "$ci"
if [[ "$os_names" == Linux ]]; then
  agents_os="CI runs tests on Linux."
else
  agents_os="CI runs tests on $os_names, so keep code and tests portable."
fi
export INIT_AGENTS_OS="$agents_os"
perl -0pi -e 's/<!-- LINT\.IfChange\(test_os\) -->\n\Q$ENV{INIT_AGENTS_OS_LINE}\E\n<!-- LINT\.ThenChange\(.*\) -->\n/$ENV{INIT_AGENTS_OS}\n/' AGENTS.md

rm -- "$0"

cat <<EOF
Initialized $name ($module).
Next: mise install && mise run lint
EOF
