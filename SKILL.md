---
name: npm-supply-chain-incident-response
description: Investigate and contain suspected npm supply-chain compromises with version-scoped evidence, local exposure analysis, safe tarball inspection, credential triage, package deprecation, and maintainer communication.
---

# npm Supply-Chain Incident Response

Use this skill when a user reports an npm supply-chain warning, a security scanner lists one or more affected package versions, a maintainer discovers unexplained historical releases, or an npm version number was already occupied before a maintainer takeover.

The goal is to reduce response time without confusing four different questions:

1. Was an exact package version reported as affected?
2. Does that version still exist in the npm registry?
3. Did that exact version execute locally or in CI?
4. Were credentials accessible when it executed?

## Operating Rules

- Work at package-and-version granularity. Never generalize from one bad version to every version of a package or scope.
- Start read-only. Collect evidence before changing registry state, credentials, source code, or CI.
- Never install a suspected package.
- Never execute files extracted from a suspicious tarball.
- Treat `npm audit` as one signal only; a clean audit result does not exclude a newly discovered malicious release.
- Treat missing lifecycle scripts as useful evidence, not proof of safety. Malicious behavior can be bundled or invoked through other paths.
- Distinguish registry package contents from the GitHub source repository. A registry release can be compromised while the repository remains clean.
- Build a timeline before attributing responsibility. Record publication dates, maintainer takeover dates, installation dates, CI execution dates, and credential rotation dates.
- Do not claim that npm, a security vendor, or a maintainer removed a version unless evidence identifies who performed the action.
- Do not rotate every secret automatically. Base credential response on confirmed or plausible code execution and secret accessibility.

## Required Inputs

Collect as many of these as available:

- exact package name, including npm scope;
- exact affected version or versions;
- advisory or scanner URL and screenshots;
- npm registry in use;
- current `latest` version and expected safe version;
- maintainer takeover date;
- local installation dates and CI run dates;
- package manager and lockfile type;
- where publishing credentials and other secrets are stored.

Do not block initial triage if some dates are unknown. Mark them as unknown and continue with read-only checks.

## Phase 1: Freeze the Claim

Translate the alert into an explicit version set:

```text
package: @scope/name
affected: 1.2.3, 1.2.4
reported by: <source>
report timestamp: <time>
```

Do not describe the whole package as compromised when the report names only selected releases.

Verify the configured registry:

```bash
npm config get registry
```

For npmjs.org verification, repeat critical lookups with an explicit registry when mirrors or proxies may be involved:

```bash
npm view "@scope/name@1.2.3" version \
  --registry=https://registry.npmjs.org/
```

## Phase 2: Record Registry State

Collect current metadata before making changes:

```bash
npm view @scope/name version
npm view @scope/name versions --json
npm view @scope/name time --json
npm view @scope/name dist-tags --json
npm view @scope/name maintainers --json
npm owner ls @scope/name
```

For each reported version:

```bash
npm view "@scope/name@1.2.3" version
npm view "@scope/name@1.2.3" scripts --json
npm view "@scope/name@1.2.3" dependencies --json
npm view "@scope/name@1.2.3" deprecated
npm view "@scope/name@1.2.3" dist --json
```

Interpretation rules:

- A returned version confirms that registry metadata is still available.
- `E404` or `No version found` means the version is unavailable from the queried registry. It does not prove who removed it.
- A version number that cannot be republished may still have existed historically even when its current metadata is unavailable.
- `npm view @scope/name dependencies` without a version inspects the current default version, not an older installed release. Always add `@version` when reconstructing history.

## Phase 3: Determine Local and CI Exposure

Check exact installed dependency trees:

```bash
npm ls -g @scope/name --all
npm ls @scope/name --all
```

For pnpm projects:

```bash
pnpm why @scope/name
```

Inspect lockfiles and CI definitions for exact versions and ranges. Distinguish:

- direct dependency;
- transitive dependency;
- global installation;
- local source link created by `npm link` or `npm install -g .`;
- package metadata or cache entry without an installed package.

Cache evidence is supporting evidence only:

```bash
npm cache ls | grep -F '@scope/name'
```

The absence of a tarball cache entry does not prove that a version was never installed, because caches can be cleaned or relocated.

When the installed version differs from `npm view <package> dependencies`, query the exact installed parent version:

```bash
npm view "@scope/parent@2.2.3" dependencies
```

Do not assume npm mutated historical package metadata. First compare exact parent versions, lockfiles, local links, and reinstall timing.

## Phase 4: Inspect Without Execution

Use registry metadata first. When tarball inspection is necessary, download rather than install:

```bash
mkdir -p incident-artifacts/tarballs
cd incident-artifacts/tarballs
npm pack --ignore-scripts "@scope/name@1.2.3"
sha256sum ./*.tgz
tar -tzf ./*.tgz
```

Extract only in an isolated directory and inspect as data:

```bash
mkdir extracted

tar -xzf package-name-1.2.3.tgz -C extracted
find extracted -type f -print
```

Review:

- `package/package.json`;
- `preinstall`, `install`, and `postinstall` scripts;
- unexpected executable files;
- obfuscated or minified payloads unrelated to package purpose;
- network, process, credential, filesystem, and environment access;
- differences between the npm tarball and the matching source tag or commit;
- unexpected dependency additions or tarball URL/integrity changes.

Never run suspicious JavaScript, shell scripts, binaries, test commands, or package entry points during inspection.

## Phase 5: Classify Exposure

Use this scale:

### A. Reported only

The version appears in an advisory, but there is no evidence it was installed or executed.

Action: contain the registry version, publish guidance, and avoid blanket host remediation.

### B. Downloaded or cached, execution not established

Metadata or a tarball exists locally, but there is no evidence installation hooks or package code ran.

Action: preserve artifacts, inspect safely, and investigate shell history, lockfiles, and CI logs.

### C. Installed or executed, secrets not accessible

The affected version ran, but relevant secrets were not present in environment variables, plaintext files, CI contexts, unlocked agents, or reachable credential stores.

Action: inspect the host and CI environment; rotate selectively when uncertainty remains material.

### D. Installed or executed while secrets were accessible

The affected version ran while npm tokens, GitHub tokens, cloud credentials, SSH material, decrypted secret files, or an unlocked credential agent were available.

Action: treat those credentials as potentially exposed, revoke or rotate them, invalidate sessions, inspect publication and repository activity, and preserve logs.

### E. Unauthorized release or account activity confirmed

Unexpected package versions, owners, tokens, workflow changes, commits, releases, or access events are confirmed.

Action: contain accounts and packages immediately, coordinate with npm and GitHub support, and publish a security advisory.

Read `references/decision-matrix.md` for the detailed response table.

## Phase 6: Contain Exact Registry Versions

Only after confirming the exact affected versions, deprecate versions that still exist:

```bash
npm deprecate "@scope/name@1.2.3" \
  "Security notice: this version is affected by a supply-chain incident. Do not use it; upgrade to 1.2.5 or newer."
```

Verify:

```bash
npm view "@scope/name@1.2.3" deprecated
```

When npm reports `No version found`:

- record the command, registry, timestamp, and output;
- confirm with `npm view <package> versions --json` and an explicit npmjs.org registry query;
- do not retry destructive operations;
- mark the version as unavailable rather than deprecated.

Confirm default installation safety:

```bash
npm dist-tag ls @scope/name
npm view @scope/name version
```

Only change `latest` after identifying a known-good published version:

```bash
npm dist-tag add @scope/name@1.2.5 latest
```

Do not use `npm unpublish` as the default response. Preserve evidence and follow registry policy or support guidance for malicious historical versions.

## Phase 7: Secure Maintainer and Publishing Access

Review package owners:

```bash
npm owner ls @scope/name
```

Remove only owners who are confirmed to no longer require access:

```bash
npm owner rm <username> @scope/name
```

Review npm account tokens and repository secrets using the currently supported account interfaces. Revoke unknown, inherited, expired, or unnecessary publishing credentials.

Prefer:

- publishing 2FA;
- short-lived credentials;
- trusted publishing through CI identity when supported;
- minimal GitHub Actions permissions;
- no long-lived npm token in repository or organization secrets when it is no longer required;
- locked dependency resolution in CI;
- package tarball validation before release.

GPG-encrypted storage lowers static-at-rest exposure but does not eliminate runtime exposure. Check whether secrets were decrypted into environment variables or plaintext, and whether a credential agent was unlocked when suspicious code ran.

## Phase 8: Communicate

`npm deprecate` warns during future installs. It does not proactively notify everyone who already installed the affected version.

Publish a GitHub Security Advisory, release note, or pinned issue containing:

- exact affected versions;
- exact known-good upgrade versions;
- publication timestamps;
- maintainer takeover timeline when relevant;
- whether versions remain downloadable;
- whether credential theft or code execution is confirmed, suspected, or not observed;
- actions already completed;
- instructions for users who installed an affected version.

Avoid overstating certainty. Use phrases such as:

- `confirmed affected by <source>`;
- `not found in the current npm registry`;
- `no evidence of local installation`;
- `execution not established`;
- `credential exposure cannot be excluded`.

## Output Format

End every response with these sections:

### Finding

State the exact package/version conclusion and confidence level.

### Evidence

List commands, metadata, timestamps, dependency paths, logs, and advisory records that support the finding.

### Exposure

State whether the affected code was reported, downloaded, installed, executed, or executed with accessible secrets.

### Actions completed

List containment and account actions already performed.

### Remaining actions

List the smallest next actions in priority order.

### User communication

Provide the exact upgrade target and a concise notice when users may be affected.

## Automation Script

For fast read-only collection, run:

```bash
<skill-dir>/scripts/triage-npm-package.sh @scope/name 1.2.3 1.2.4
```

Set `DOWNLOAD_TARBALLS=1` only when static tarball inspection is needed:

```bash
DOWNLOAD_TARBALLS=1 \
  <skill-dir>/scripts/triage-npm-package.sh @scope/name 1.2.3
```

Review all generated artifacts before performing registry mutations.

## References

- `references/decision-matrix.md`
- `references/incident-report-template.md`
