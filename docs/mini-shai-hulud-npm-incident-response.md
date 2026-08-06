# Mini Shai-Hulud npm Incident Response: A Maintainer Handover Case Study

> Chinese version: [`mini-shai-hulud-npm-incident-response.zh-CN.md`](mini-shai-hulud-npm-incident-response.zh-CN.md)

This case study documents how a maintainer investigated historical `@lint-md` npm releases listed by Socket as affected by the Mini Shai-Hulud supply-chain incident.

The purpose is not to reverse-engineer the malware. It is to show how to move from a package-name alert to an evidence-based incident response without installing suspicious versions, blaming the wrong maintainer, or rotating every credential unnecessarily.

## Executive summary

Socket's affected-package search listed historical releases from three packages:

| Package | Versions shown by Socket |
|---|---|
| `@lint-md/core` | `2.1.0`, `2.2.0` |
| `@lint-md/cli` | `2.1.0`, `2.2.0` |
| `@lint-md/parser` | `0.1.14`, `0.2.14` |

The listed releases were published on May 19, 2026, during the Mini Shai-Hulud malicious publish wave described by Socket. The current maintainer took over the projects in early June 2026, after those releases already existed.

The investigation found:

- the current maintainer did not publish the listed historical versions;
- the installed CLI was initially `@lint-md/cli@2.2.3`, which resolved to `@lint-md/core@2.2.1`, not the listed `core@2.2.0`;
- reinstalling the current CLI produced `@lint-md/cli@2.2.4 -> @lint-md/core@2.3.0`;
- no evidence was found that the listed `core`, `cli`, or `parser` versions had been installed on the maintainer's machine;
- the current known-good versions did not expose `preinstall`, `install`, or `postinstall` scripts in registry metadata;
- attempts to deprecate the two listed parser versions returned `No version found`, meaning those versions were unavailable from the queried registry at that time;
- the correct response was version-scoped containment and documentation, not a blanket claim that every `@lint-md` release or the GitHub source repositories were compromised.

## Why this investigation was easy to get wrong

A scanner result that contains your package name creates several tempting but unsafe conclusions:

1. **"My current repository is compromised."**  
   A malicious npm tarball can exist while the GitHub repository remains clean.

2. **"The current maintainer published it."**  
   Publication timestamps may predate a maintainer handover.

3. **"I installed the CLI, so I must have executed the malicious Core version."**  
   The exact CLI version and its dependency range must be checked.

4. **"`npm audit` is clean, so there is no incident."**  
   Newly disclosed malicious releases may not be represented by traditional vulnerability advisories.

5. **"There is no `postinstall`, so the package is safe."**  
   Lifecycle metadata is useful evidence, but malicious code can also be executed when a package is imported, built, tested, or invoked.

6. **"`No version found` means npm removed it."**  
   It proves only that the queried registry does not currently expose that version. It does not identify who removed it.

The response therefore separated four questions:

1. Which exact versions were reported?
2. Do those versions still exist in the registry?
3. Did those exact versions execute locally or in CI?
4. Were credentials accessible if execution occurred?

## Timeline reconstruction

The first high-value step was building a timeline before attributing responsibility.

```text
2026-05-19
  Socket records the Mini Shai-Hulud malicious publish wave.
  Historical @lint-md versions later appear in the affected-package search.

Early June 2026
  The current maintainer takes over maintenance.

After takeover
  The maintainer works from source repositories and publishes newer releases.
  Publishing 2FA is enabled.

2026-08-06
  The Socket results are investigated against npm registry metadata,
  installed dependency trees, local cache evidence, and package scripts.
```

This timeline changed the initial risk model. The investigation was no longer "Did the current maintainer publish malware?" It became:

> Did the new maintainer inherit packages with malicious historical releases, and did any of those releases execute in the new maintainer's environment?

## Step 1: Freeze the exact affected-version set

The package name alone was not treated as the incident boundary. The exact versions shown by the scanner were recorded first.

```text
@lint-md/core:   2.1.0, 2.2.0
@lint-md/cli:    2.1.0, 2.2.0
@lint-md/parser: 0.1.14, 0.2.14
```

Later versions were not marked affected without evidence.

This distinction matters because a scoped package family may contain:

- malicious historical releases;
- unaffected releases published before the incident;
- repaired or independently published releases after the incident;
- local source links that never came from the registry.

## Step 2: Verify the registry and publication history

Before changing anything, the configured registry and current package metadata should be preserved.

```bash
npm config get registry

npm view @lint-md/core versions --json
npm view @lint-md/core time --json
npm view @lint-md/core dist-tags --json

npm view @lint-md/cli versions --json
npm view @lint-md/cli time --json
npm view @lint-md/cli dist-tags --json

npm view @lint-md/parser versions --json
npm view @lint-md/parser time --json
npm view @lint-md/parser dist-tags --json
```

When a proxy or mirror may be involved, repeat critical checks against the public registry explicitly:

```bash
npm view "@lint-md/parser@0.1.14" version \
  --registry=https://registry.npmjs.org/
```

The important rule is to preserve the registry state before running `npm deprecate`, changing `dist-tag`, or modifying owners.

## Step 3: Query exact package versions, not only `latest`

One confusing result initially looked like a dependency inconsistency.

The current registry query returned:

```bash
npm view @lint-md/cli dependencies
```

```text
@lint-md/core: ^2.3.0
```

But the installed tree showed:

```bash
npm ls -g @lint-md/core
```

```text
@lint-md/cli@2.2.3
└── @lint-md/core@2.2.1
```

There was no npm resolution anomaly. The first command queried the current default CLI release, while the installed parent was `@lint-md/cli@2.2.3`.

The correct historical query was:

```bash
npm view @lint-md/cli@2.2.3 dependencies
```

It returned:

```text
@lint-md/core: ^2.2.1
```

That range legitimately resolved to `2.2.1` in the existing installation.

After reinstalling the current CLI:

```bash
npm uninstall -g @lint-md/cli
npm install -g @lint-md/cli
npm ls -g @lint-md/core
```

The tree became:

```text
@lint-md/cli@2.2.4
└── @lint-md/core@2.3.0
```

### General lesson

Never use this alone when investigating an older installation:

```bash
npm view <package> dependencies
```

Always query the exact installed parent version:

```bash
npm view "<package>@<installed-version>" dependencies
```

## Step 4: Distinguish registry packages from local links

The global dependency tree also contained:

```text
@lint-md/core@2.3.0 -> /home/luo/devOps/lint-md
```

This was a local source link, not a package downloaded from the npm registry. Local links can make `npm ls` output look duplicated or recursive.

Useful checks include:

```bash
npm ls -g @lint-md/core --all
npm explain @lint-md/core
readlink -f "$(npm root -g)/@lint-md/core"
```

A local link should be analyzed as source code and local dependency state, not as evidence that the same registry tarball was installed.

## Step 5: Check direct and transitive exposure

The maintainer had directly installed only the CLI, so the investigation checked whether affected packages were pulled transitively.

```bash
npm ls -g @lint-md/cli --all
npm ls -g @lint-md/core --all
npm ls -g @lint-md/parser --all
```

Inside project repositories:

```bash
npm ls @lint-md/core --all
npm ls @lint-md/parser --all
```

For pnpm projects:

```bash
pnpm why @lint-md/core
pnpm why @lint-md/parser
```

Lockfiles, CI logs, and workflow history should also be checked for the exact affected versions.

The key result in this case was that the installed dependency path did not include the Socket-listed versions.

## Step 6: Interpret npm cache evidence carefully

The npm cache contained tarball references for several `@lint-md` versions, but not the listed malicious versions.

```bash
npm cache ls | grep lint-md
```

This supported the low-exposure assessment, but it was not treated as proof.

Cache evidence has two limitations:

- a cache entry does not prove package code executed;
- an absent entry does not prove a package was never installed, because caches may be cleaned, relocated, or expired.

Entries beginning with `security-advisory:` are advisory metadata, not malicious executable files by themselves.

## Step 7: Inspect lifecycle scripts without installing the package

For the installed known-good Core version, registry metadata was queried directly:

```bash
npm view @lint-md/core@2.2.1 scripts
```

The result included development and publication scripts such as:

```text
lint
test
build
prepublishOnly
package-contract
```

It did not include:

```text
preinstall
install
postinstall
```

This reduced concern about automatic execution during package installation.

It was also important not to misclassify `prepublishOnly`. npm runs `prepublishOnly` during `npm publish`; it is not an install-time hook for downstream users. By contrast, `preinstall`, `install`, and `postinstall` are relevant to `npm install` and `npm ci` execution paths.

However, the absence of installation hooks was not treated as complete proof of safety. Static tarball inspection and execution-path analysis remain necessary when the suspicious tarball is still available.

## Step 8: Download suspicious tarballs only for static inspection

A suspicious package should not be installed for investigation.

Use `npm pack` to collect the archive as evidence:

```bash
mkdir -p incident-artifacts/tarballs
cd incident-artifacts/tarballs

npm pack --ignore-scripts "@scope/package@1.2.3"
sha256sum ./*.tgz
tar -tzf ./*.tgz
```

If extraction is required, use an isolated directory and treat every file as untrusted data:

```bash
mkdir extracted
tar -xzf package-1.2.3.tgz -C extracted
find extracted -type f -print
```

Do not run:

- package entry points;
- tests or build commands;
- JavaScript or shell files from the archive;
- binaries included in the tarball.

In this case, some reported versions were no longer available, so the investigation preserved the missing-version result rather than attempting installation through another source.

## Step 9: Handle `npm deprecate` precisely

The maintainer attempted to deprecate the two parser versions shown by Socket:

```bash
npm deprecate "@lint-md/parser@0.1.14" \
  "Security notice: affected by the Mini Shai-Hulud supply-chain incident."

npm deprecate "@lint-md/parser@0.2.14" \
  "Security notice: affected by the Mini Shai-Hulud supply-chain incident."
```

npm returned:

```text
npm warn deprecate No version found for 0.1.14
npm warn deprecate No version found for 0.2.14
```

The correct interpretation was:

> The queried registry did not currently expose those version records, so they could not be deprecated.

The result did **not** prove whether npm, Socket, a previous maintainer, or another actor removed them.

The follow-up checks were:

```bash
npm view @lint-md/parser versions --json
npm view @lint-md/parser@0.1.14 version
npm view @lint-md/parser@0.2.14 version
```

When an affected version still exists, deprecate the exact version rather than the entire package:

```bash
npm deprecate "@scope/package@1.2.3" \
  "Security notice: affected release. Upgrade to 1.2.5 or newer."
```

A deprecation warning appears during future installs. It does not proactively notify every user who already installed the version, so a separate security advisory or pinned notice is still required.

## Step 10: Assess credentials based on execution, not fear

The maintainer stored many credentials with GPG protection and unlocked them periodically.

GPG encryption reduces static-at-rest exposure, but the response still had to ask:

- Did an affected package execute?
- Was a secret decrypted into an environment variable or plaintext file?
- Was a credential agent unlocked at the time?
- Could the process invoke that agent or read the decrypted material?
- Was there unauthorized npm, GitHub, cloud, or deployment activity afterward?

Because no evidence showed that the listed versions executed on the maintainer's machine or in CI, there was no basis for rotating every credential indiscriminately.

A different conclusion would be required if an affected version had run while npm publishing tokens, GitHub tokens, cloud credentials, SSH material, or an unlocked credential agent were accessible.

## Containment actions for this case

The practical containment plan was:

1. Preserve Socket screenshots and affected-version lists.
2. Record npm registry metadata, publication times, owners, and `dist-tag` values.
3. Verify local and CI dependency trees for each exact affected version.
4. Keep the current CLI and Core on known-good releases.
5. Deprecate exact affected versions only when they still exist.
6. Record unavailable versions as unavailable, without guessing who removed them.
7. Confirm publishing 2FA and review package ownership.
8. Remove inherited or unknown publishing tokens when found.
9. Publish a security notice with exact affected and upgrade versions.
10. Preserve an incident report for future maintainers and users.

## What the response deliberately did not do

- It did not declare every `@lint-md` package version malicious.
- It did not claim the GitHub repositories were compromised without repository evidence.
- It did not attribute the May releases to the maintainer who took over in June.
- It did not install suspicious versions to inspect them.
- It did not treat a clean `npm audit` as exoneration.
- It did not treat missing lifecycle hooks as conclusive proof.
- It did not rotate every GPG-protected credential without an execution path.
- It did not claim npm removed the missing parser versions.

## Repeatable command checklist

Replace the package and versions before running these commands.

```bash
# Registry identity
npm config get registry

# Current package state
npm view @scope/package version
npm view @scope/package versions --json
npm view @scope/package time --json
npm view @scope/package dist-tags --json
npm owner ls @scope/package

# Exact affected-version metadata
npm view "@scope/package@1.2.3" version
npm view "@scope/package@1.2.3" scripts --json
npm view "@scope/package@1.2.3" dependencies --json
npm view "@scope/package@1.2.3" deprecated
npm view "@scope/package@1.2.3" dist --json

# Local exposure
npm ls -g @scope/package --all
npm ls @scope/package --all
pnpm why @scope/package
npm cache ls | grep -F '@scope/package'

# Safe tarball collection
npm pack --ignore-scripts "@scope/package@1.2.3"
sha256sum ./*.tgz
tar -tzf ./*.tgz

# Exact containment when the version still exists
npm deprecate "@scope/package@1.2.3" \
  "Security notice: affected release. Upgrade to 1.2.5 or newer."

# Verify default install target
npm dist-tag ls @scope/package
npm view @scope/package version
```

The repository's collector automates the read-only portion:

```bash
./scripts/triage-npm-package.sh @scope/package 1.2.3 1.2.4
```

Optional tarball collection:

```bash
DOWNLOAD_TARBALLS=1 \
  ./scripts/triage-npm-package.sh @scope/package 1.2.3 1.2.4
```

## Main lessons

### Version scope matters more than package-name scope

A supply-chain alert should begin with exact package versions. Later releases must be assessed independently.

### Timeline prevents incorrect attribution

Publication and maintainer-handover dates can completely change the incident hypothesis.

### Installed trees are more important than current metadata

`npm view <package> dependencies` describes the current default version. Historical investigation requires exact parent versions and actual local dependency trees.

### Registry absence and safety are different facts

A version that returns `No version found` is unavailable from that registry. That does not identify the remover, prove the source repository was safe, or determine whether users installed it previously.

### Credential rotation should follow execution exposure

The decisive question is not whether a package name appears in an advisory. It is whether malicious code ran while a particular secret was accessible.

## Sources

- [Socket: Mini Shai-Hulud supply-chain attack](https://socket.dev/supply-chain-attacks/mini-shai-hulud)
- [Socket: Mini Shai-Hulud malicious npm publish wave](https://socket.dev/blog/antv-packages-compromised)
- [npm documentation: scripts and lifecycle events](https://docs.npmjs.com/cli/using-npm/scripts/)
- [npm documentation: deprecating packages and versions](https://docs.npmjs.com/deprecating-and-undeprecating-packages-or-package-versions/)
- [npm unpublish policy](https://docs.npmjs.com/policies/unpublish/)

## Scope note

This document records the maintainer's response process and the evidence available during the investigation. It does not independently certify every package version as safe, identify the actor who published or removed a historical version, or replace malware analysis by the reporting security vendor.
