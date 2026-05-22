set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

DATA_CDN := "terraform/data-cdn"

default:
    @just --list

tf-fmt:
    terraform fmt -recursive terraform

data-cdn-init:
    @test -f {{ DATA_CDN }}/backend.hcl || (echo "Missing {{ DATA_CDN }}/backend.hcl; copy backend.hcl.example and fill in local values." >&2; exit 1)
    cd {{ DATA_CDN }} && terraform init -backend-config=backend.hcl

data-cdn-migrate-state:
    @test -f {{ DATA_CDN }}/backend.hcl || (echo "Missing {{ DATA_CDN }}/backend.hcl; copy backend.hcl.example and fill in local values." >&2; exit 1)
    cd {{ DATA_CDN }} && terraform init -migrate-state -force-copy -backend-config=backend.hcl

data-cdn-validate:
    cd {{ DATA_CDN }} && terraform validate

data-cdn-plan:
    cd {{ DATA_CDN }} && terraform plan

data-cdn-apply:
    cd {{ DATA_CDN }} && terraform apply

data-cdn-output:
    cd {{ DATA_CDN }} && terraform output

data-cdn-state-list:
    cd {{ DATA_CDN }} && terraform state list
