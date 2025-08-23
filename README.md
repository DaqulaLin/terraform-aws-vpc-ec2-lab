# Project 1 · Terraform on AWS with GitHub OIDC (VPC/ALB/EC2/RDS)

A minimal, interview-ready IaC project that demonstrates **GitHub Actions OIDC (no long-lived keys)**, **remote state with locking**, and a pragmatic path to **least privilege** across VPC, ALB, EC2, and RDS.

> **Highlights**
> - **OIDC to AWS (no static keys):** PR uses **read-only** role; `main` uses **approval-gated apply**.
> - **S3 + DynamoDB backend:** remote state w/ locking to avoid concurrent writes.
> - **Modular & switchable:** `enable_*` flags (via `for_each`) cleanly create/destroy stacks by PR.
> - **Least privilege journey:** Admin → Service-scope → Resource-level (can be tightened over time).
> - **Ops-friendly:** SSM Session Manager (no SSH), SG-to-SG allow rules, RDS private only.

---

## Table of Contents
- [System Architecture](#system-architecture)
- [CI/CD Flow](#cicd-flow)
- [Repository Layout](#repository-layout)
- [Prerequisites](#prerequisites)
- [How to Use](#how-to-use)
- [Security Model (OIDC & Least Privilege)](#security-model-oidc--least-privilege)
- [Remote State & Locking](#remote-state--locking)
- [Cost & Networking Choices](#cost--networking-choices)
- [Cleanup & Reuse](#cleanup--reuse)
- [Troubleshooting](#troubleshooting)
- [Interview Talking Points](#interview-talking-points)
- [Prevent terraform-docs from touching this README](#prevent-terraform-docs-from-touching-this-readme)

---

## System Architecture

```mermaid
flowchart LR
  subgraph Internet
    UserBrowser
  end

  subgraph AWS[VPC (10.0.0.0/16)]
    direction LR
    subgraph Pub[Public Subnets]
      ALB[ALB (SG: alb-sg)]
    end
    subgraph Pri[Private Subnets]
      EC2[EC2 (Nginx + SSM)\n(SG: web-sg)]
      RDS[(RDS MySQL\npublicly_accessible=false\nSG: rds-sg)]
    end
  end

  UserBrowser -->|HTTP 80/443| ALB
  ALB -->|HTTP 80 only\nSource = alb-sg| EC2
  EC2 -->|TCP 3306\nSource = web-sg| RDS

  classDef pub fill:#eef7ff,stroke:#7aa7d6,color:#1b4b72;
  classDef pri fill:#f6fff0,stroke:#79b66a,color:#275b1b;
  class Pub pub
  class Pri pri

Security group flow

alb-sg: ingress from internet on 80/443

web-sg: ingress only from alb-sg on 80

rds-sg: ingress only from web-sg on 3306

RDS is private-only (publicly_accessible=false)

CI/CD Flow
sequenceDiagram
  autonumber
  participant Dev as Developer
  participant GH as GitHub Actions
  participant AWS as AWS (OIDC)
  participant TF as Terraform (S3 + DynamoDB)

  Dev->>GH: Open PR
  GH->>AWS: Assume plan role (OIDC, read-only)
  GH->>TF: fmt / validate / tflint / tfsec + plan (-lock=false)
  GH-->>Dev: PR plan result (no changes applied)

  Dev->>GH: Merge PR to main
  GH->>AWS: Assume plan role (OIDC, read-only)
  GH->>TF: main plan (locks via DynamoDB)
  GH-->>Dev: Upload plan.out artifact

  Dev->>GH: Approve "prod" environment
  GH->>AWS: Assume apply role (OIDC)
  GH->>TF: Download plan.out & apply
  TF-->>AWS: Create/Update/Destroy resources

Consistency: main plan uploads plan.out; main apply downloads that same file and runs terraform apply plan.out. If the plan is stale, Terraform errors out.

Repository Layout
.
├─ envs/
│  └─ dev/
│     ├─ main.tf            # root module (for_each + enable_* flags)
│     ├─ variables.tf
│     ├─ outputs.tf
│     ├─ backend.tf         # S3 state + DynamoDB lock
│     └─ dev.tfvars         # env values (enable_*, rds_password, etc.)
├─ modules/
│  ├─ vpc/                  # VPC module
│  ├─ ec2/                  # EC2 + SSM + SG (user_data installs Nginx)
│  ├─ alb/                  # ALB + listener + target group
│  └─ rds/                  # RDS + subnet group + SG rule (SG→SG)
└─ .github/workflows/
   └─ terraform-ci.yml      # PR plan & main plan/apply (with approval)
