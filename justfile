set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

DATA_CDN := "terraform/data-cdn"

default:
    @just --list

tf-fmt:
    terraform fmt -recursive terraform

data-cdn-init:
    cd {{ DATA_CDN }} && terraform init

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

