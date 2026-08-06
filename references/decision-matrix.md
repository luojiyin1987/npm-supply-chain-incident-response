# Incident Decision Matrix

Use this table after collecting registry, dependency-tree, timeline, and credential evidence.

| State | Evidence | Host/CI response | Credential response | Registry/user response |
|---|---|---|---|---|
| Reported version only | Advisory names the version; no local or CI installation evidence | Preserve advisory and registry metadata | No blanket rotation | Deprecate exact existing version; verify safe `latest`; publish notice |
| Downloaded or cached | Tarball/cache metadata exists; execution not established | Preserve hashes and logs; inspect statically | Rotate only where uncertainty and impact justify it | Same as above |
| Installed, no secret access | Exact affected version appears in dependency tree or logs; secrets were unavailable | Inspect host, CI logs, processes, persistence, and network evidence | Selective rotation based on remaining uncertainty | Same as above; tell users to upgrade and inspect |
| Executed with accessible secrets | Install hook, package entry point, build, test, or import ran while secrets were available | Isolate affected environment; preserve evidence; inspect unauthorized actions | Revoke/rotate exposed npm, GitHub, cloud, SSH, signing, and deployment credentials; invalidate sessions | Contain package and accounts; coordinate with registry/platform support; publish advisory |
| Unauthorized account activity confirmed | Unknown release, owner, token, workflow, commit, or access event | Escalate incident; preserve audit logs | Immediate revocation and recovery of affected accounts | Coordinate with npm/GitHub; communicate confirmed facts and affected window |
| Version missing from registry | `npm view package@version` returns `E404`/`No version found` on the verified registry | Preserve command output and advisory evidence | Depends on execution evidence, not registry absence | Do not deprecate a missing version; record it as unavailable; do not claim who removed it |

## Credential accessibility questions

Ask these independently for each relevant credential:

1. Was the affected code executed?
2. Was the credential present in an environment variable?
3. Was it written to a plaintext file, npm config, CI workspace, shell history, or process argument?
4. Was a credential agent unlocked or cached at the time?
5. Could the process read the credential store or invoke the agent?
6. Is there evidence of unauthorized use after the suspected execution time?

GPG encryption at rest lowers static exposure. It does not protect a secret that was already decrypted into the environment or made available through an unlocked agent.

## Confidence labels

- **Confirmed:** directly supported by registry metadata, package contents, dependency trees, CI logs, audit logs, or unauthorized activity.
- **Probable:** multiple independent signals align, but a decisive artifact is missing.
- **Possible:** technically plausible, with limited supporting evidence.
- **Not observed:** checks found no evidence; this is not the same as impossible.
- **Unknown:** evidence was unavailable, incomplete, or no longer retained.

## Common mistakes

- Querying `npm view package dependencies` and assuming it describes an older installed version.
- Treating a scoped package-name match as proof that every release is malicious.
- Treating a clean `npm audit` as proof that a newly disclosed supply-chain attack did not occur.
- Treating `npm cache ls` as a complete installation history.
- Assuming a missing npm version was removed by a specific party.
- Rotating all credentials before determining which environment actually executed affected code.
- Publishing a vague warning without exact affected and fixed versions.
