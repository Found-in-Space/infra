# Agent Instructions

This repository owns public Found in Space infrastructure: DNS, CDN, object
storage, certificates, and other project-level cloud resources.

## Terraform

- Keep Terraform roots under `terraform/`.
- Run commands through the repo `justfile` when possible.
- Run `terraform fmt -recursive terraform` before committing Terraform changes.
- Do not mix pure moves with behavior changes. When migrating infrastructure
  from another repo, first commit the moved configuration as-is, then make
  follow-up commits for Route 53 adoption, backend changes, or CDN changes.

## Public Repository Safety

This repo is intended to be public.

Never commit:

- `.terraform/`
- `terraform.tfstate` or `terraform.tfstate.*`
- `*.tfplan`
- `terraform.tfvars` or other private `*.tfvars`
- `backend.hcl` / `*.tfbackend`
- AWS credentials, local profiles, private hostnames, or secret parameter values

Committing Terraform source, examples, public DNS records, CloudFront aliases,
and ACM validation record names is fine unless they reveal a private service.

