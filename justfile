set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

DATA_CDN := "terraform/data-cdn"
ROUTE53 := "terraform/route53"

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

route53-init:
    @test -f {{ ROUTE53 }}/backend.hcl || (echo "Missing {{ ROUTE53 }}/backend.hcl; copy backend.hcl.example and fill in local values." >&2; exit 1)
    cd {{ ROUTE53 }} && terraform init -backend-config=backend.hcl

route53-validate:
    cd {{ ROUTE53 }} && terraform validate

route53-plan:
    cd {{ ROUTE53 }} && terraform plan

route53-apply:
    cd {{ ROUTE53 }} && terraform apply

route53-output:
    cd {{ ROUTE53 }} && terraform output

route53-state-list:
    cd {{ ROUTE53 }} && terraform state list
