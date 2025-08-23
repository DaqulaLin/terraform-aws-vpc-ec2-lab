# Terraform on AWS with GitHub OIDC (VPC/ALB/EC2/RDS)

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

flowchart LR
  subgraph Internet
    Browser[User / Client]
  end

  subgraph AWS [VPC 10.0.0.0/16]
    direction LR
    subgraph Public [Public Subnets]
      ALB[ALB\n(SG: alb-sg)]
    end
    subgraph Private [Private Subnets]
      EC2[EC2: Nginx + SSM\n(SG: web-sg)]
      RDS[(RDS MySQL\nSG: rds-sg\npublicly_accessible=false)]
    end
  end

  Browser -->|HTTP 80/443| ALB
  ALB -->|HTTP 80\nsource=alb-sg| EC2
  EC2 -->|TCP 3306\nsource=web-sg| RDS

## CI/CD Flow
sequenceDiagram
  autonumber
  participant Dev as Developer
  participant GH as GitHub Actions
  participant AWS as AWS (OIDC)
  participant TF as Terraform (S3 + DynamoDB)

  Dev->>GH: Open PR
  GH->>AWS: Assume plan role (OIDC, read-only)
  GH->>TF: fmt / validate / tflint / tfsec / plan (-lock=false)
  GH-->>Dev: PR plan result

  Dev->>GH: Merge PR to main
  GH->>AWS: Assume plan role (read-only)
  GH->>TF: main plan (uses lock)
  GH-->>Dev: Upload plan.out

  Dev->>GH: Approve environment "prod"
  GH->>AWS: Assume apply role (OIDC)
  GH->>TF: Download plan.out & apply
  TF-->>AWS: Create / Update / Destroy
