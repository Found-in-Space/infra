# Found in Space - Infrastructure

Part of [Found in Space](https://foundin.space/), a project that turns real
astronomical measurements into interactive explorations of the solar
neighbourhood. See all repositories at
[github.com/Found-in-Space](https://github.com/Found-in-Space).

This repository owns project-level infrastructure for Found in Space: public
DNS, CDN distribution, object storage, certificates, and related cloud
resources.

## Current Layout

```text
terraform/
  data-cdn/  # S3 + CloudFront CDN for Found in Space data assets
  route53/   # Public DNS for foundin.space
```

The `data-cdn` Terraform root was moved as-is from the `octree` repository.
Its local Terraform state and local variable file were moved on disk too, but
they are intentionally ignored by git.

## Requirements

- Terraform >= 1.5
- AWS credentials configured for the target account
- `just` for the convenience commands below

## Commands

```sh
just data-cdn-init
just data-cdn-plan
just data-cdn-apply
```

Or directly:

```sh
cd terraform/data-cdn
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

## State And Secrets

This repository is intended to be public. Do not commit Terraform state, plan
files, local tfvars, backend config, or credentials.

Terraform roots use a committed partial S3 backend:

```hcl
terraform {
  backend "s3" {}
}
```

Copy `backend.hcl.example` to `backend.hcl` inside the Terraform root and fill
in the private state bucket, profile, and other local values. `backend.hcl` is
ignored by git.

Ignored local files include:

```text
.terraform/
terraform.tfstate
terraform.tfstate.*
terraform.tfvars
*.tfplan
backend.hcl
*.tfbackend
```

## License

MIT - see [LICENSE](LICENSE).
