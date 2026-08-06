# npm Supply Chain Incident Response Skill

Investigate compromised and malicious npm packages without installing or executing them.

This agent skill gives npm maintainers a read-only incident response workflow for verifying affected package versions, inspecting npm tarballs safely, checking local and CI exposure, assessing credential risk, containing compromised releases, and publishing an accurate security notice.

## Quick Start

Clone the repository and run the read-only triage collector with the exact package name and reported affected versions:

```bash
git clone https://github.com/luojiyin1987/npm-supply-chain-incident-response.git
cd npm-supply-chain-incident-response

./scripts/triage-npm-package.sh @scope/package 1.2.3 1.2.4
```

The collector records npm registry metadata, publication times, `dist-tag` values, package scripts and dependencies, global and project-local dependency trees, pnpm dependency paths when available, and whether each reported version still exists in the registry.

Artifacts are written under `incident-artifacts/` for review before any registry mutation.

To download suspicious tarballs for static inspection without installing the package:

```bash
DOWNLOAD_TARBALLS=1 \
  ./scripts/triage-npm-package.sh @scope/package 1.2.3 1.2.4
```

The workflow uses `npm pack`, records hashes and archive file lists, and never executes package contents.

## What it helps with

- Validate a Socket, npm, GitHub, Aikido, or other supply-chain alert.
- Separate a compromised historical release from the current source repository.
- Reconstruct package publication, maintainer handover, installation, and CI timelines.
- Find direct and transitive installations with npm or pnpm.
- Inspect registry metadata and tarballs without installing or running the package.
- Decide whether credential rotation is necessary based on actual execution and secret exposure.
- Deprecate only confirmed affected versions and verify `dist-tag` safety.
- Produce a maintainer-facing incident report and user-facing security notice.

## Safety model

The workflow is read-only by default.

It must not:

- install a suspected package;
- execute code extracted from a suspicious tarball;
- deprecate an entire package when only specific versions are affected;
- infer that a current maintainer caused a release published before they took over;
- treat `npm audit` or the absence of lifecycle scripts as proof that a package is safe;
- rotate every credential without first determining whether malicious code ran while the credential was accessible.

Registry mutations such as `npm deprecate`, changing `dist-tag`, removing owners, or revoking tokens are explicit containment steps and require the operator to confirm the exact target.

## Repository layout

```text
.
├── SKILL.md
├── README.md
├── skill.json
├── agents/
│   └── openai.yaml
├── references/
│   ├── decision-matrix.md
│   └── incident-report-template.md
└── scripts/
    └── triage-npm-package.sh
```

## Install as a skill

### Codex

```bash
git clone https://github.com/luojiyin1987/npm-supply-chain-incident-response.git \
  "${CODEX_HOME:-$HOME/.codex}/skills/npm-supply-chain-incident-response"
```

### Project-local agent skill

```bash
git clone https://github.com/luojiyin1987/npm-supply-chain-incident-response.git \
  .agent/skills/npm-supply-chain-incident-response
```

## Fast triage details

Run the read-only collector from the repository or project you want to inspect:

```bash
./scripts/triage-npm-package.sh @scope/package 1.2.3 1.2.4
```

The script records:

- npm registry configuration;
- current version and `dist-tag` values;
- version history and publication times;
- package scripts, dependencies, deprecation state, tarball URL, and integrity metadata;
- global and project-local npm dependency trees;
- pnpm dependency explanations when pnpm is available;
- whether each reported version still exists in the registry.

Artifacts are written under `incident-artifacts/` and should be reviewed before taking any registry action.

To also download suspicious tarballs for static inspection:

```bash
DOWNLOAD_TARBALLS=1 \
  ./scripts/triage-npm-package.sh @scope/package 1.2.3 1.2.4
```

Downloading uses `npm pack`; the workflow never installs the package and never executes files from the archive. Inspect tarball contents only in an isolated directory.

## Containment examples

Deprecate exact confirmed versions:

```bash
npm deprecate "@scope/package@1.2.3" \
  "Security notice: this version is affected by a supply-chain incident. Upgrade to 1.2.5 or newer."
```

Verify the result:

```bash
npm view "@scope/package@1.2.3" deprecated
npm dist-tag ls @scope/package
npm owner ls @scope/package
```

When `npm deprecate` reports `No version found`, record that the version is no longer present in the registry. Do not claim who removed it unless independent evidence identifies the actor.

`npm deprecate` is an install-time warning, not a broadcast notification. Publish a GitHub Security Advisory, release note, or pinned issue for users who already have the affected version installed.

## Core decision model

Always answer four questions separately:

1. **Advisory scope:** Which exact package names and versions were reported?
2. **Registry state:** Do those versions still exist, and what does `latest` point to now?
3. **Execution exposure:** Were the affected versions installed or executed locally or in CI?
4. **Credential exposure:** Were secrets available in environment variables, plaintext files, CI contexts, or an unlocked credential agent at that time?

See [`references/decision-matrix.md`](references/decision-matrix.md) for the response matrix and [`references/incident-report-template.md`](references/incident-report-template.md) for the final report format.

## Motivation

This skill was created after investigating a real maintainer handover in which security tooling listed historical npm versions as affected, while the current maintainer had taken over later and was using newer versions. The main lesson is that package name matches are not enough: incident response must remain version-scoped, timeline-aware, and evidence-driven.

## License

MIT
