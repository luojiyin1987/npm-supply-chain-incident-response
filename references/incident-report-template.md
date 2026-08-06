# npm Supply-Chain Incident Report

## Executive summary

- Package:
- Reported affected versions:
- Known-good upgrade version:
- Advisory source:
- Incident status: investigating / contained / resolved
- Confidence: confirmed / probable / possible / not observed / unknown
- Maintainer takeover date, when relevant:

## Timeline

| UTC time | Event | Evidence |
|---|---|---|
| | Version published | npm registry metadata |
| | Security report published | advisory URL/screenshot |
| | Maintainer access transferred | npm/GitHub record |
| | Local or CI installation | lockfile, shell history, CI log |
| | Containment completed | command output/audit log |

## Registry evidence

- Registry queried:
- Current `latest`:
- Current `dist-tag` values:
- Affected versions still available:
- Affected versions unavailable:
- Current owners:
- Deprecation status:
- Tarball integrity/hashes:

## Package inspection

For each affected version, record:

- lifecycle scripts;
- dependency changes;
- unexpected files;
- obfuscation or unrelated bundled code;
- environment, filesystem, network, process, or credential access;
- differences from the matching source tag/commit;
- whether code execution was confirmed.

## Local and CI exposure

- Global npm dependency tree:
- Project npm dependency tree:
- pnpm dependency path:
- Lockfile matches:
- CI runs using the affected version:
- Cache evidence:
- Earliest possible execution:
- Latest possible execution:

Classify exposure:

- [ ] Reported only
- [ ] Downloaded or cached; execution not established
- [ ] Installed or executed; secrets not accessible
- [ ] Installed or executed while secrets were accessible
- [ ] Unauthorized account activity confirmed

## Credential assessment

| Credential | Accessible during execution? | Unauthorized use observed? | Action |
|---|---:|---:|---|
| npm publishing | | | |
| GitHub | | | |
| Cloud/deployment | | | |
| SSH | | | |
| Signing/GPG agent | | | |
| Other | | | |

## Actions completed

- [ ] Preserved advisory and screenshots
- [ ] Collected npm metadata and publication times
- [ ] Verified exact affected versions
- [ ] Checked local and CI dependency trees
- [ ] Inspected tarballs without execution
- [ ] Deprecated exact affected versions that still exist
- [ ] Confirmed safe `latest` and `dist-tag` values
- [ ] Reviewed package owners
- [ ] Revoked or rotated exposed credentials
- [ ] Reviewed GitHub Actions and npm publication history
- [ ] Published user-facing security notice
- [ ] Contacted npm/GitHub/security vendor when required

## Remaining actions

1.
2.
3.

## User notice

```text
Security notice for <package>

Affected versions:
- <version>

Upgrade to:
- <known-good version or range>

Status:
<Explain whether the version is deprecated, unavailable, or still downloadable.>

Impact:
<State confirmed facts. Clearly distinguish confirmed execution or credential
exposure from possibilities that were not observed.>

Maintainer timeline:
<Include only when it prevents incorrect attribution or clarifies the affected
publication window.>
```

## Evidence archive

- Artifact directory:
- SHA-256 manifest:
- Command log:
- Registry metadata:
- CI logs:
- Platform audit logs:
- Screenshots:
