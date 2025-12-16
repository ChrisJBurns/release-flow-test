# Release Flow Threat and Risk Model

## Overview

This document provides a threat and risk analysis for the automated release flow implemented in this repository. The release flow automates version management, container image building, and Helm chart publishing.

### Release Flow Summary

```
1. Developer runs: task release
           │
           ▼
┌─────────────────────────┐
│  Taskfile (local)       │
│  - Prompts for version  │
│  - Creates release/v*   │
│  - Updates VERSION file │
│  - Updates Chart.yaml   │
│  - Updates values.yaml  │
│  - Creates PR via gh    │
└─────────────────────────┘
           │
           ▼
    PR Review & Merge
           │
           ▼
┌──────────────────────────┐
│  create-release-tag.yml  │
│  - Verifies commit msg   │
│  - Verifies file changes │
│  - Creates git tag       │
│  - Creates GitHub Release│
└──────────────────────────┘
           │
           ▼
┌──────────────────────────┐
│  releaser.yml            │
│  - Builds container image│
│  - Signs image (Cosign)  │
│  - Publishes Helm chart  │
│  - Signs chart (Cosign)  │
└──────────────────────────┘
```

---

## Assets

| Asset | Description | Sensitivity |
|-------|-------------|-------------|
| Container Images | Published to GHCR, deployed to production | **Critical** |
| Helm Charts | Kubernetes deployment configurations | **Critical** |
| RELEASE_TOKEN (PAT) | Personal Access Token with elevated permissions | **Critical** |
| GITHUB_TOKEN | Workflow token with repository permissions | **High** |
| VERSION file | Source of truth for release versions | **High** |
| Git Tags | Immutable release markers | **High** |
| GitHub Releases | Public release artifacts and notes | **Medium** |
| Workflow Files | CI/CD pipeline definitions | **High** |

---

## Threat Actors

| Actor | Motivation | Capability |
|-------|------------|------------|
| External Attacker | Supply chain compromise, cryptomining, data theft | Low-Medium (requires initial access) |
| Malicious Insider | Sabotage, unauthorized releases | High (has repository access) |
| Compromised Dependency | Supply chain attack via upstream | Medium (indirect access) |
| Compromised GitHub Action | Malicious code execution in workflows | High (runs in workflow context) |
| Accidental Insider | Unintentional misconfigurations or errors | High (human error) |

---

## Threats and Risks

### T1: RELEASE_TOKEN Compromise

| Attribute | Value |
|-----------|-------|
| **Threat** | Attacker obtains the RELEASE_TOKEN (PAT) and uses it to create unauthorized releases |
| **Attack Vector** | Token leakage via logs, compromised developer machine, phishing, or secret exposure |
| **Impact** | **Critical** - Attacker can push malicious tags, create releases, and trigger downstream deployments |
| **Likelihood** | Medium |
| **Risk Level** | **High** |

**Current Mitigations:**
- Token stored as GitHub Secret (encrypted at rest)
- Token not exposed in workflow logs

**Recommended Mitigations:**
- [ ] Set token expiration (90 days max)
- [ ] Scope token to minimum required permissions
- [ ] Scope token to only this repository
- [ ] Consider replacing PAT with GitHub App for better audit trails
- [ ] Enable GitHub secret scanning
- [ ] Rotate token periodically

---

### T2: Unauthorized Tag Creation

| Attribute | Value |
|-----------|-------|
| **Threat** | Attacker or malicious insider creates a release tag directly, bypassing the PR review process |
| **Attack Vector** | Direct git push of tag using compromised credentials or insider access |
| **Impact** | **High** - Triggers release workflow, publishes potentially malicious artifacts |
| **Likelihood** | Medium |
| **Risk Level** | **High** |

**Current Mitigations:**
- Release workflow verifies commit message pattern matches release PR format
- PR review required before merge triggers tag creation

**Recommended Mitigations:**
- [ ] Enable tag protection rules (GitHub repository settings)
- [ ] Restrict tag creation to specific users/teams
- [ ] Add webhook validation for tag events
- [ ] Implement signed tags requirement

---

### T3: VERSION File Tampering

| Attribute | Value |
|-----------|-------|
| **Threat** | Attacker modifies VERSION file directly on main branch, triggering unauthorized release |
| **Attack Vector** | Direct push to main, compromised PR review, or bypassing branch protection |
| **Impact** | **High** - Creates unauthorized release tag and publishes artifacts |
| **Likelihood** | Low-Medium |
| **Risk Level** | **Medium** |

**Current Mitigations:**
- Commit message verification in create-release-tag.yml
- Verification that VERSION content matches commit message

**Recommended Mitigations:**
- [ ] Enforce branch protection on main (require PR, require reviews)
- [ ] Require signed commits
- [ ] Add CODEOWNERS file requiring specific reviewers for VERSION changes
- [ ] Block direct pushes to main

---

### T4: Compromised GitHub Action

| Attribute | Value |
|-----------|-------|
| **Threat** | A third-party GitHub Action used in workflows is compromised and executes malicious code |
| **Attack Vector** | Supply chain attack on action repository, tag mutation, or maintainer account compromise |
| **Impact** | **Critical** - Full access to secrets, ability to modify releases, push malicious artifacts |
| **Likelihood** | Low |
| **Risk Level** | **High** |

**Third-party actions in use:**
- `actions/checkout@v4`
- `actions/setup-go@v5`
- `docker/login-action@v3`
- `azure/setup-helm@v4`
- `sigstore/cosign-installer@v3`
- `ko-build/setup-ko@v0.9`
- `peter-evans/create-pull-request@v6`

**Current Mitigations:**
- Using well-known, widely-used actions
- Actions from official organizations (actions/, sigstore/, docker/)

**Recommended Mitigations:**
- [ ] Pin actions to full SHA commits instead of tags
- [ ] Regularly audit and update action versions
- [ ] Consider forking critical actions
- [ ] Use GitHub's Dependabot for action updates
- [ ] Replace `peter-evans/create-pull-request` with `gh pr create` (native)

---

### T5: Unauthorized Release PR Content

| Attribute | Value |
|-----------|-------|
| **Threat** | Release PR contains unexpected file changes beyond version files |
| **Attack Vector** | Malicious or accidental inclusion of non-version files in release PR |
| **Impact** | **Medium** - Unexpected code changes shipped in release |
| **Likelihood** | Low |
| **Risk Level** | **Low** |

**Current Mitigations:**
- ✅ File change verification - create-release-tag.yml only allows VERSION, Chart.yaml, and values.yaml changes
- ✅ Blocks release if unexpected files were modified in the PR
- ✅ Commit message verification - Must match "Release v{semver}" pattern
- ✅ PR review required before merge
- Tag existence check prevents duplicate tags

**Recommended Mitigations:**
- [ ] Add workflow concurrency controls (`concurrency` key in workflows)
- [ ] Add CODEOWNERS requiring specific reviewers for release PRs

---

### T6: Container Image Tampering

| Attribute | Value |
|-----------|-------|
| **Threat** | Published container image is modified after signing, or unsigned image is deployed |
| **Attack Vector** | Registry compromise, tag mutation, or deployment of unverified images |
| **Impact** | **Critical** - Malicious code execution in production |
| **Likelihood** | Low |
| **Risk Level** | **Medium** |

**Current Mitigations:**
- Images signed with Cosign (keyless/OIDC)
- Signature includes workflow identity for verification

**Recommended Mitigations:**
- [ ] Enforce signature verification in deployment pipelines
- [ ] Use image digests instead of tags in Helm values
- [ ] Implement admission controller (e.g., Sigstore Policy Controller)
- [ ] Enable GHCR immutable tags (if available)

---

### T7: Helm Chart Tampering

| Attribute | Value |
|-----------|-------|
| **Threat** | Published Helm chart is modified or replaced with malicious version |
| **Attack Vector** | Registry compromise, tag mutation, or deployment of unverified charts |
| **Impact** | **Critical** - Malicious Kubernetes resources deployed |
| **Likelihood** | Low |
| **Risk Level** | **Medium** |

**Current Mitigations:**
- Charts signed with Cosign (keyless/OIDC)
- Signature verification instructions provided in release summary

**Recommended Mitigations:**
- [ ] Enforce signature verification before helm install
- [ ] Document verification process for end users
- [ ] Consider Helm provenance files (.prov)

---

### T8: Workflow File Modification

| Attribute | Value |
|-----------|-------|
| **Threat** | Attacker modifies workflow files to exfiltrate secrets or inject malicious steps |
| **Attack Vector** | Malicious PR, compromised reviewer, or direct push |
| **Impact** | **Critical** - Secret exfiltration, malicious artifact publication |
| **Likelihood** | Low-Medium |
| **Risk Level** | **High** |

**Current Mitigations:**
- PR review required for changes
- Workflows only run on specific triggers

**Recommended Mitigations:**
- [ ] Add CODEOWNERS requiring security team review for .github/ changes
- [ ] Enable GitHub's "Require approval for all outside collaborators"
- [ ] Use `pull_request_target` carefully (not currently used)
- [ ] Implement workflow change detection and alerts

---

### T9: Secret Exposure in Logs

| Attribute | Value |
|-----------|-------|
| **Threat** | Secrets accidentally exposed in workflow logs |
| **Attack Vector** | Misconfigured echo statements, error messages, or debug output |
| **Impact** | **High** - Token compromise leading to unauthorized access |
| **Likelihood** | Low |
| **Risk Level** | **Medium** |

**Current Mitigations:**
- GitHub automatically masks known secrets
- Secrets passed via stdin where possible

**Recommended Mitigations:**
- [ ] Audit workflows for potential secret exposure
- [ ] Use `add-mask` for dynamic secrets
- [ ] Disable debug logging in production workflows
- [ ] Regular log review

---

### T10: Denial of Service via Release Spam

| Attribute | Value |
|-----------|-------|
| **Threat** | Attacker floods the release process with RC tags, consuming CI resources |
| **Attack Vector** | Automated tag creation using compromised credentials |
| **Impact** | **Low** - CI resource exhaustion, release process disruption |
| **Likelihood** | Low |
| **Risk Level** | **Low** |

**Current Mitigations:**
- Tag creation requires authentication
- GitHub rate limiting

**Recommended Mitigations:**
- [ ] Add workflow concurrency limits
- [ ] Implement rate limiting on tag creation
- [ ] Monitor for unusual release activity

---

## Risk Matrix

| Threat | Likelihood | Impact | Risk Level |
|--------|------------|--------|------------|
| T1: RELEASE_TOKEN Compromise | Medium | Critical | **High** |
| T2: Unauthorized Tag Creation | Medium | High | **High** |
| T3: VERSION File Tampering | Low-Medium | High | **Medium** |
| T4: Compromised GitHub Action | Low | Critical | **High** |
| T5: Race Condition | Low | Medium | **Low** |
| T6: Container Image Tampering | Low | Critical | **Medium** |
| T7: Helm Chart Tampering | Low | Critical | **Medium** |
| T8: Workflow File Modification | Low-Medium | Critical | **High** |
| T9: Secret Exposure in Logs | Low | High | **Medium** |
| T10: Denial of Service | Low | Low | **Low** |

---

## Prioritized Recommendations

### Critical Priority

1. **Enable branch protection on main**
   - Require pull request reviews (minimum 1 reviewer)
   - Require status checks to pass
   - Block force pushes
   - Block direct pushes

2. **Enable tag protection rules**
   - Restrict who can create tags matching `v*`

3. **Pin GitHub Actions to SHA commits**
   ```yaml
   # Instead of:
   uses: actions/checkout@v4
   # Use:
   uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608 # v4.1.1
   ```

### High Priority

4. **Secure RELEASE_TOKEN**
   - Set 90-day expiration
   - Scope to this repository only
   - Document minimum required permissions
   - Consider migrating to GitHub App

5. **Add CODEOWNERS file**
   ```
   # .github/CODEOWNERS
   /.github/ @security-team
   /VERSION @release-team @security-team
   /deploy/charts/ @platform-team
   ```

6. **Add workflow concurrency controls**
   ```yaml
   concurrency:
     group: release-${{ github.ref }}
     cancel-in-progress: false
   ```

### Medium Priority

7. **Implement signature verification in deployments**
   - Add cosign verify step before deployments
   - Document verification process for users

8. **Replace peter-evans/create-pull-request with native gh CLI**
   - Reduces third-party action dependency

9. **Enable Dependabot for GitHub Actions**
   ```yaml
   # .github/dependabot.yml
   version: 2
   updates:
     - package-ecosystem: "github-actions"
       directory: "/"
       schedule:
         interval: "weekly"
   ```

### Low Priority

10. **Add release monitoring and alerting**
    - Alert on unexpected release activity
    - Monitor for failed signature verifications

---

## Appendix: Security Controls Checklist

| Control | Status | Notes |
|---------|--------|-------|
| Container image signing | ✅ Implemented | Cosign keyless |
| Helm chart signing | ✅ Implemented | Cosign keyless |
| Release PR verification | ✅ Implemented | Commit message pattern check |
| File change verification | ✅ Implemented | Blocks if non-release files changed |
| Branch protection | ⚠️ Recommended | Not verified |
| Tag protection | ⚠️ Recommended | Not verified |
| Action SHA pinning | ❌ Not implemented | Using version tags |
| CODEOWNERS | ❌ Not implemented | Recommended |
| Workflow concurrency | ❌ Not implemented | Recommended |
| GitHub App (vs PAT) | ❌ Not implemented | Optional |
| Dependabot for actions | ❌ Not implemented | Recommended |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2024-12-16 | Claude | Initial threat model |
