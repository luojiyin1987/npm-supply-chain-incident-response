#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage:
  triage-npm-package.sh <package> [affected-version ...]

Examples:
  triage-npm-package.sh @scope/name 1.2.3 1.2.4
  DOWNLOAD_TARBALLS=1 triage-npm-package.sh @scope/name 1.2.3

Environment:
  OUTPUT_ROOT          Artifact directory root (default: ./incident-artifacts)
  DOWNLOAD_TARBALLS    Set to 1 to download tarballs with npm pack (default: 0)
  NPM_REGISTRY         Explicit registry for npm view/pack operations (optional)

The script is read-only with respect to the npm registry. It does not install,
execute, deprecate, unpublish, retag, or modify package ownership.
EOF
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 64
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "error: npm is required" >&2
  exit 69
fi

package=$1
shift
versions=("$@")

output_root=${OUTPUT_ROOT:-./incident-artifacts}
download_tarballs=${DOWNLOAD_TARBALLS:-0}
registry_args=()

if [[ -n ${NPM_REGISTRY:-} ]]; then
  registry_args=(--registry "$NPM_REGISTRY")
fi

safe_package=$(printf '%s' "$package" | sed 's/^@//' | tr '/:@' '---' | tr -cd 'A-Za-z0-9._-')
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
out_dir="$output_root/${safe_package:-package}-$timestamp"
metadata_dir="$out_dir/metadata"
versions_dir="$out_dir/versions"
tarballs_dir="$out_dir/tarballs"

mkdir -p "$metadata_dir" "$versions_dir"

commands_log="$out_dir/commands.log"
summary="$out_dir/SUMMARY.md"

printf '# npm Supply-Chain Triage\n\n' >"$summary"
printf -- '- Package: `%s`\n' "$package" >>"$summary"
printf -- '- Started: `%s`\n' "$timestamp" >>"$summary"
printf -- '- Working directory: `%s`\n' "$PWD" >>"$summary"
printf -- '- Tarball download enabled: `%s`\n' "$download_tarballs" >>"$summary"
printf '\n## Reported versions\n\n' >>"$summary"

if [[ ${#versions[@]} -eq 0 ]]; then
  printf '_No affected versions were supplied. Current package metadata only._\n' >>"$summary"
else
  for version in "${versions[@]}"; do
    printf -- '- `%s@%s`\n' "$package" "$version" >>"$summary"
  done
fi

run_capture() {
  local output_file=$1
  shift

  {
    printf '$'
    printf ' %q' "$@"
    printf '\n'
  } >>"$commands_log"

  set +e
  "$@" >"$output_file" 2>&1
  local status=$?
  set -e

  printf '%s\n' "$status" >"${output_file}.exit-code"
  return "$status"
}

npm_capture() {
  local output_file=$1
  shift
  run_capture "$output_file" npm "$@" "${registry_args[@]}"
}

configured_registry=$(npm config get registry 2>&1 || true)
printf '\n## Registry\n\n- Configured registry: `%s`\n' "$configured_registry" >>"$summary"
if [[ -n ${NPM_REGISTRY:-} ]]; then
  printf -- '- Explicit registry override: `%s`\n' "$NPM_REGISTRY" >>"$summary"
fi

npm_capture "$metadata_dir/current-version.txt" view "$package" version || true
npm_capture "$metadata_dir/versions.json" view "$package" versions --json || true
npm_capture "$metadata_dir/time.json" view "$package" time --json || true
npm_capture "$metadata_dir/dist-tags.json" view "$package" dist-tags --json || true
npm_capture "$metadata_dir/maintainers.json" view "$package" maintainers --json || true
npm_capture "$metadata_dir/owners.txt" owner ls "$package" || true

printf '\n## Local exposure checks\n\n' >>"$summary"

if run_capture "$metadata_dir/npm-global-tree.txt" npm ls -g "$package" --all; then
  printf -- '- Global npm tree command completed successfully.\n' >>"$summary"
else
  printf -- '- Global npm tree returned a non-zero status; review `metadata/npm-global-tree.txt`.\n' >>"$summary"
fi

if run_capture "$metadata_dir/npm-project-tree.txt" npm ls "$package" --all; then
  printf -- '- Project npm tree command completed successfully.\n' >>"$summary"
else
  printf -- '- Project npm tree returned a non-zero status; review `metadata/npm-project-tree.txt`.\n' >>"$summary"
fi

if command -v pnpm >/dev/null 2>&1; then
  if run_capture "$metadata_dir/pnpm-why.txt" pnpm why "$package"; then
    printf -- '- pnpm dependency explanation completed successfully.\n' >>"$summary"
  else
    printf -- '- pnpm dependency explanation returned a non-zero status; review `metadata/pnpm-why.txt`.\n' >>"$summary"
  fi
else
  printf -- '- pnpm is not installed; pnpm dependency analysis was skipped.\n' >>"$summary"
fi

if run_capture "$metadata_dir/npm-cache.txt" npm cache ls; then
  grep -F "$package" "$metadata_dir/npm-cache.txt" >"$metadata_dir/npm-cache-package-matches.txt" || true
else
  : >"$metadata_dir/npm-cache-package-matches.txt"
fi

printf '\n## Version checks\n\n' >>"$summary"

for version in "${versions[@]}"; do
  target="$package@$version"
  safe_version=$(printf '%s' "$version" | tr '/:@+' '-----' | tr -cd 'A-Za-z0-9._-')
  version_dir="$versions_dir/${safe_version:-unknown}"
  mkdir -p "$version_dir"

  if npm_capture "$version_dir/version.txt" view "$target" version; then
    printf -- '- `%s`: registry metadata is available.\n' "$target" >>"$summary"
    registry_available=1
  else
    printf -- '- `%s`: not found in the queried registry. This does not identify who removed it.\n' "$target" >>"$summary"
    registry_available=0
  fi

  if [[ $registry_available -eq 1 ]]; then
    npm_capture "$version_dir/scripts.json" view "$target" scripts --json || true
    npm_capture "$version_dir/dependencies.json" view "$target" dependencies --json || true
    npm_capture "$version_dir/deprecated.txt" view "$target" deprecated || true
    npm_capture "$version_dir/dist.json" view "$target" dist --json || true
    npm_capture "$version_dir/publish-time.txt" view "$target" time --json || true

    if grep -Eq '"(preinstall|install|postinstall)"[[:space:]]*:' "$version_dir/scripts.json" 2>/dev/null; then
      printf -- '  - Install lifecycle metadata was found; inspect `versions/%s/scripts.json`.\n' "$safe_version" >>"$summary"
    else
      printf -- '  - No install lifecycle key was found in registry script metadata. This is not proof of safety.\n' >>"$summary"
    fi
  fi

  if [[ $download_tarballs == "1" && $registry_available -eq 1 ]]; then
    package_tarball_dir="$tarballs_dir/${safe_version:-unknown}"
    mkdir -p "$package_tarball_dir"

    {
      printf '$ npm pack --ignore-scripts %q --json' "$target"
      if [[ ${#registry_args[@]} -gt 0 ]]; then
        printf ' %q' "${registry_args[@]}"
      fi
      printf '\n'
    } >>"$commands_log"

    set +e
    (
      cd "$package_tarball_dir"
      npm pack --ignore-scripts "$target" --json "${registry_args[@]}" \
        >pack.json 2>pack.stderr
    )
    pack_status=$?
    set -e
    printf '%s\n' "$pack_status" >"$package_tarball_dir/pack.exit-code"

    if [[ $pack_status -eq 0 ]]; then
      shopt -s nullglob
      tgz_files=("$package_tarball_dir"/*.tgz)
      shopt -u nullglob

      for tgz in "${tgz_files[@]}"; do
        sha256sum "$tgz" >"$tgz.sha256"
        tar -tzf "$tgz" >"$tgz.file-list.txt"
      done

      printf -- '  - Tarball downloaded for static inspection; do not execute its contents.\n' >>"$summary"
    else
      printf -- '  - Tarball download failed; review `tarballs/%s/pack.stderr`.\n' "$safe_version" >>"$summary"
    fi
  fi
done

cat >>"$summary" <<'EOF'

## Interpretation guardrails

- A scanner match is evidence about the named versions, not every release of the package.
- A cache hit is not proof that package code executed.
- A missing cache entry is not proof that the package was never installed.
- Absence of `preinstall`, `install`, or `postinstall` is not proof of safety.
- `No version found` means the queried registry does not currently expose that version; it does not identify the remover.
- Do not perform `npm deprecate`, `npm unpublish`, `npm dist-tag`, owner removal, or token revocation until the evidence is reviewed.
EOF

printf 'Artifacts written to: %s\n' "$out_dir"
printf 'Review first: %s\n' "$summary"
