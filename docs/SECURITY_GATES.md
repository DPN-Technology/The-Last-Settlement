# DPN Security and CI Gates

The Last Settlement uses layered repository controls.

## Required validation layers

1. **Source Integrity** — validates required Godot project files, project entry points, GDScript hygiene, conflict markers, and repository structure.
2. **Security Audit** — rejects embedded credential patterns, tracked executables in source paths, unpinned third-party GitHub Actions, oversized source/config files, and selected high-risk GDScript APIs.
3. **Security Policy Surface** — requires SECURITY.md, CONTRIBUTING.md, CODEOWNERS, Dependabot configuration, and this gate specification.
4. **CodeQL** — scans GitHub Actions workflows with the security-and-quality query suite.
5. **Dependency Review** — blocks pull requests that introduce dependencies with moderate-or-higher known vulnerabilities.
6. **OpenSSF Scorecard** — audits repository supply-chain posture and publishes SARIF results.
7. **Settlement Green Gate** — aggregates required validation jobs into one explicit pass/fail status.

## Security-sensitive changes

Any change introducing OS process execution, dynamic JavaScript evaluation, networking, external services, credential storage, encrypted save material, or executable binary assets must receive explicit security review.

## Release expectation

A release candidate should not be considered clean unless the latest commit has passing Source Integrity, Security Policy Surface, CodeQL, and Supply Chain checks.
