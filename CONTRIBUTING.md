# Contributing

## Development workflow

1. Create a feature branch from `main`.
2. Make changes (see guidelines below).
3. Run `terraform validate` in each affected layer under `infra/`.
4. Run tests: `./tests/Test-ClientCredentials.ps1` or `./tests/Test-AuthCodePKCE.ps1`.
5. Open a pull request.

## Guidelines

### Terraform

- New modules go under `modules/` with `main.tf`, `variables.tf`, `outputs.tf`.
- Pin provider versions in `required_providers` (each layer's `main.tf`).
- Mark sensitive variables with `sensitive = true`.
- Never commit `terraform.tfvars` or `*.tfstate*`.

### Policy fragments

- Each reusable APIM concern = one fragment XML in `policies/fragments/`.
- Fragments communicate via context variables (documented in [README.md](README.md)).
- Register new fragments in the `policy_fragments` map in `infra/02-configuration/main.tf`.

### .NET sample apps

- Target .NET 10+, multi-stage Docker builds.
- Use `Microsoft.Identity.Web` for JWT validation.
- Health endpoint at `GET /health` (no auth).
- Listen on port 8080. Run as non-root (`USER $APP_UID`).

## Secret rotation

| Secret | Location | Expiry | How to rotate |
|---|---|---|---|
| OBO client secret | Key Vault | 1 year | Update in Entra ID, Terraform recreates KV secret |
| Test service secret | Terraform state | 90 days | `terraform taint` the password resource, then apply |
| ACR credentials | terraform.tfvars | Varies | Rotate in ACR, update tfvars, apply |
