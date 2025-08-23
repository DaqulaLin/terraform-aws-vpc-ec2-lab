# Project 1 · Terraform on AWS with GitHub OIDC
**Stack:** VPC / ALB / EC2 / RDS · **Controls:** OIDC (no keys), Remote State + Lock, Least-Privilege

A minimal, interview-ready Infrastructure-as-Code project that demonstrates **GitHub Actions OIDC** (short-lived credentials), **S3 state + DynamoDB lock**, and a pragmatic path to **least privilege** across **VPC, ALB, EC2, and RDS**. Modules are switchable via `enable_*` flags and use `for_each` for clean create/destroy by PR.

---

## Highlights
- **OIDC to AWS (no static keys):** PR uses **read-only** role; `main` uses **approval-gated apply**.
- **Remote state with locking:** S3 + DynamoDB to avoid concurrent writes.
- **Modular & switchable:** `enable_*` flags (with `for_each`) cleanly create/destroy by PR.
- **Least-privilege journey:** Admin → Service scope → Resource-level (tighten gradually).
- **Ops-friendly:** SSM Session Manager (no SSH), SG-to-SG rules, RDS private only.

---

## Table of Contents
- [System Architecture](#system-architecture)
- [CI/CD Flow](#cicd-flow)
- [Repository Layout](#repository-layout)
- [Quick Start (Day-0 → Day-1)](#quick-start-day-0--day-1)
- [Security Model (OIDC & Least Privilege)](#security-model-oidc--least-privilege)
- [Remote State & Locking](#remote-state--locking)
- [Cost & Networking Notes](#cost--networking-notes)
- [Operate / Toggle / Clean Up](#operate--toggle--clean-up)
- [Troubleshooting](#troubleshooting)
- [Interview Talking Points](#interview-talking-points)
- [Keep terraform-docs away from this README](#keep-terraform-docs-away-from-this-readme)
- [License](#license)

---

## System Architecture

```mermaid
flowchart LR
  %% Simpler subgraph syntax to support GitHub's Mermaid renderer
  subgraph Internet
    Browser[User / Client]
  end

  subgraph AWS_VPC
    direction LR
    subgraph Public_Subnets
      ALB[ALB\n(SG: alb-sg)]
    end
    subgraph Private_Subnets
      EC2[EC2: Nginx + SSM\n(SG: web-sg)]
      RDS[(RDS MySQL\nSG: rds-sg\npublicly_accessible=false)]
    end
  end

  Browser -->|HTTP 80/443| ALB
  ALB -->|HTTP 80\nsource=alb-sg| EC2
  EC2 -->|TCP 3306\nsource=web-sg| RDS
```

**Key choices**
- **RDS private-only** (`publicly_accessible=false`), access via **SG→SG** from EC2 on 3306.
- **ALB public**, forwards only to EC2 on 80.
- **Session Manager (SSM)** on EC2 (no SSH keys).
- **Cost vs. safety:** demo uses minimal NAT assumptions; production should consider NAT per AZ.

---

## CI/CD Flow

```mermaid
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
```

**Why two plans?**
PR plan is read-only (no lock). `main` plan captures the exact changes and produces `plan.out`. The **apply** job must use the **same** `plan.out` (guarded by environment approval) for safety and auditability.

---

## Repository Layout

```
.
├─ envs/
│  └─ dev/
│     ├─ main.tf            # root module (for_each + enable_* flags)
│     ├─ variables.tf       # env-level inputs
│     ├─ dev.tfvars         # values (enable_*, rds_password, azs, CIDRs...)
│     ├─ backend.tf         # S3 + DynamoDB lock
│     └─ outputs.tf
├─ modules/
│  ├─ vpc/                  # VPC + subnets + routes + IGW/NAT (if any)
│  ├─ ec2/                  # EC2 + SSM + SG (user-data installs Nginx)
│  ├─ alb/                  # ALB + target group + listener
│  └─ rds/                  # RDS + subnet group + SG (SG→SG)
└─ .github/workflows/
   └─ terraform-ci.yml      # PR plan (OIDC read-only), main plan/apply (with approvals)
```

---

## Quick Start (Day-0 → Day-1)

### A. Prepare AWS (once)
1. **S3 state bucket** (e.g., `my-terraform-state-<acct>`), **versioning ON**.
2. **DynamoDB lock table** (e.g., `tf-locks`, PK `LockID` as String).
3. **GitHub OIDC provider**: `https://token.actions.githubusercontent.com`.
4. **Two IAM roles** (trust restricted to your repo+ref):
   - `gha-oidc-tf-plan` — read-only plan role.
   - `gha-oidc-tf-apply` — apply role (gated by environment approval).
5. Save role ARNs as GitHub Secrets:
   `AWS_GHA_PLAN_ROLE_ARN`, `AWS_GHA_APPLY_ROLE_ARN`.

### B. Configure backend & variables
- In `envs/dev/backend.tf`, set bucket/region/table.
- In `envs/dev/dev.tfvars`, set CIDRs, subnets, and **enable flags**:
  ```hcl
  enable_vpc = true
  enable_ec2 = true
  enable_alb = true
  enable_rds = true
  rds_password = "CHANGE_ME_FOR_DEMO ONLY"
  ```

### C. Open your first PR
- Commit module changes → open PR.
- Checks run: `fmt`, `validate`, `tflint`, `tfsec`, **plan (-lock=false)**.
- Review plan, merge when green.

### D. On `main`
- `main` workflow runs **plan** (with lock) and uploads `plan.out`.
- Approve the **environment** (e.g., `prod`) → **apply** runs using the uploaded `plan.out`.

---

## Security Model (OIDC & Least Privilege)

- **OIDC**: no long-lived keys, short-lived federated creds.
- **PR plan role** (read-only):
  - S3 state read, limited `iam:Get*`/`iam:List*`, `ec2:Describe*`, `elasticloadbalancing:Describe*`, `rds:Describe*`.
- **Apply role** (elevated but bounded):
  - Initially **service-scoped** (`ec2:*`, `elasticloadbalancing:*`, `rds:*`, `iam:PassRole`, selected `iam:*PolicyVersion`, etc.).
  - Tighten to **resource ARNs** over time.
- **Environment protection**: required reviewers before apply.
- **Branch protection**: PR required, required checks, block force-push & deletion on `main`.

---

## Remote State & Locking

- **State:** S3
- **Locking:** DynamoDB
- PR plan uses `-lock=false` (no lock). `main` plan/apply take the lock to serialize changes and prevent drift or double-apply.

---

## Cost & Networking Notes

- **Private data plane:** RDS is private-only, SG→SG from EC2.
- **Public entry:** ALB in public subnets; forward to EC2 on 80.
- **NAT strategy:** demo keeps costs low; production typically uses **one NAT per AZ** for availability.

---

## Operate / Toggle / Clean Up

- Toggle modules in `dev.tfvars`:
  ```hcl
  enable_ec2 = false
  enable_alb = false
  enable_rds = false
  ```
- Open PR → plan shows destroys → merge → approve apply.
- You may keep the **IAM/OIDC** module for future projects (very low cost).

---

## Troubleshooting (Most Common)

- **403 on S3 / `HeadObject`**
  - Ensure plan/apply roles include: `s3:GetObject`, `s3:GetObjectVersion`, `s3:ListBucket`, `s3:GetBucketLocation`.
  - Bucket policy permits those role ARNs.

- **`GetOpenIDConnectProvider` / `iam:GetPolicy` denied** (during plan)
  - Add read-only IAM `Get*`/`List*` to the **plan** role (safe; no mutation).

- **Apply says “Saved plan is stale”**
  - Re-run `main` plan; then re-run apply (always consume the most recent `plan.out`).

- **Destroy errors (EC2/instance profile)**
  - Allow in **apply** role: `iam:RemoveRoleFromInstanceProfile`, `iam:DetachRolePolicy`, `iam:DeleteInstanceProfile`
    (limit to ARNs created by this project).

- **RDS plan fails on Describe/ListTags**
  - Include `rds:Describe*` and `rds:ListTagsForResource` in the **plan** role.

---

## Interview Talking Points

- **OIDC vs static keys:** no rotations, least privilege per workflow, auditable trust policy, short-lived creds.
- **State & locks:** S3 + DynamoDB prevents concurrent mutations; PR plan avoids locking (read-only).
- **Least-privilege journey:** start service-scoped to move fast; converge to **resource ARNs** once URNs are stable.
- **Network model:** ALB→EC2 (80), EC2→RDS (3306), SG→SG, no public RDS.
- **Safety controls:** branch protection, required checks, environment approvals, apply from saved `plan.out`.

---

## Keep terraform-docs away from this README

Scope `terraform-docs` to modules only so it won’t rewrite the root README:

```yaml
# .pre-commit-config.yaml (snippet)
repos:
  - repo: local
    hooks:
      - id: terraform-docs
        name: terraform-docs (modules only)
        entry: bash -lc 'terraform-docs .'
        language: system
        files: ^modules/
```

---

## License

MIT (or your preference).
