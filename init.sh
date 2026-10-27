#!/usr/bin/env bash
# Turn this template into a new project: set the Go module path, rename the
# cmd/ binary directory, and fill in the project name and description.
# Run once from the repository root; the script deletes itself when done.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./init.sh [--name NAME] [--description TEXT] [--module PATH]

  --name         Project and binary name, e.g. my-app (default: from git remote)
  --description  One-line project description
  --module       Go module path, e.g. github.com/you/my-app (default: from git remote)

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
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) name="${2-}"; shift 2 ;;
    --description) description="${2-}"; shift 2 ;;
    --module) module="${2-}"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
done

cd "$(dirname "$0")"
[[ -d cmd/template-go ]] || die "cmd/template-go not found; has the project already been initialized?"

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

export INIT_NAME="$name" INIT_DESCRIPTION="$description" INIT_MODULE="$module"

perl -pi -e 's/^module template-go$/module $ENV{INIT_MODULE}/' go.mod
mv cmd/template-go "cmd/$name"
find . -name '*.go' -not -path './.git/*' -not -path './.jj/*' -exec perl -pi -e \
  's{"template-go/}{"$ENV{INIT_MODULE}/}g; s/template-go/$ENV{INIT_NAME}/g' {} +
perl -pi -e 's/\{\{ project \}\}/$ENV{INIT_NAME}/g; s/\{\{ description \}\}/$ENV{INIT_DESCRIPTION}/g' README.md AGENTS.md
# Drop the template-only note from the README.
perl -0pi -e 's/\n<!-- init\.sh:start -->\n.*?<!-- init\.sh:end -->\n//s' README.md

rm -- "$0"

cat <<EOF
Initialized $name ($module).
Next: mise install && mise run lint
EOF
