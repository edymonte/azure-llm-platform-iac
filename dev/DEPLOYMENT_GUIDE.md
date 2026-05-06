# 📖 DEPLOYMENT GUIDE — Azure LLM Platform IaC

Detailed step-by-step deployment guide for the Azure LLM Platform on Azure.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Stage 1: Backend Storage](#stage-1-backend-storage)
4. [Stage 2: Foundry Platform](#stage-2-foundry-platform)
5. [Validation](#validation)
6. [Daily Operations](#daily-operations)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Tools

| Tool | Version | Install |
|------|---------|---------|
| Terraform | >= 1.7 | [terraform.io](https://developer.hashicorp.com/terraform/install) |
| Azure CLI | >= 2.50 | [learn.microsoft.com](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) |
| Git | any | [git-scm.com](https://git-scm.com) |

### Azure Access

- Active Azure subscription
- Role: **Contributor** or **Owner** at subscription scope
- Quota available for GPT-4o Global Standard in East US and West US 3

```bash
# Verify all tools
terraform --version
az --version
git --version

# Login and set subscription
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
az account show --output table
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│         Azure LLM Platform — Terraform                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  LAYER 1: Backend Storage (Remote State)               │
│  ├─ Resource Group                                     │
│  ├─ Storage Account (LRS, HTTPS-only)                  │
│  ├─ Blob Container (tfstate)                           │
│  ├─ Managed Identity                                   │
│  └─ RBAC — Storage Blob Data Contributor               │
│                                                         │
│  LAYER 2: Foundry Platform                             │
│  ├─ Resource Group (East US)                           │
│  ├─ VNet 10.20.0.0/16 + 4 Subnets + NSGs              │
│  ├─ User-Assigned Managed Identity + RBAC              │
│  ├─ AI Services — East US                              │
│  │  └─ GPT-4o Deployment (Global Standard)            │
│  ├─ AI Services — West US 3                            │
│  │  └─ GPT-4o Deployment (Global Standard)            │
│  ├─ Key Vault (Standard)                               │
│  └─ Container Apps — LiteLLM proxy + test + val       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Resource Dependencies

```
terraform init
    │
    ▼
Resource Group
    │
    ├──► VNet + Subnets + NSGs
    │
    ├──► Managed Identity + RBAC
    │
    └──► AI Services (East US, West US 3)
              │
              ├──► GPT-4o Model Deployments
              └──► Key Vault
```

---

## Stage 1: Backend Storage

### What it deploys

- Resource Group: `rg-azllm-tfstate-dev`
- Storage Account: `stazllmtfdev` (LRS, HTTPS-only, versioning on)
- Blob Container: `tfstate`
- Managed Identity: RBAC-scoped for Terraform state access

### Steps

```bash
cd dev/backend-storage

# Review defaults in backend-storage.tfvars
cat backend-storage.tfvars

terraform init
terraform validate
terraform plan -var-file=backend-storage.tfvars -out=backend.plan
terraform apply backend.plan

# Capture output
terraform output
```

### Expected output keys

- `storage_account_name`
- `resource_group_name`
- `blob_container_name`
- `managed_identity_id`

---

## Stage 2: Foundry Platform

### Configure variables

```bash
cd ../terraform

# Copy example and fill in your values
copy dev.tfvars.example dev.tfvars
```

Key values to set in `dev.tfvars`:

| Variable | Description |
|----------|-------------|
| `project_name` | Short name used in all resource naming |
| `primary_location` | Primary Azure region |
| `regions` | Map of enabled deployment regions |
| `foundry_models_config` | Model name, format, version, SKU, capacity |
| `key_vault_name` | Must be globally unique |
| `container_apps_config` | CAE and container app settings |

### Configure backend

Create `backend.tfvars` using values from Stage 1:

```hcl
resource_group_name  = "rg-azllm-tfstate-dev"
storage_account_name = "stazllmtfdev"
container_name       = "tfstate"
key                  = "azllm/foundry/terraform.tfstate"
use_azuread_auth     = true
```

### Deploy

```bash
bash ./run_with_backend_access.sh init -reconfigure -backend-config=backend.tfvars
terraform validate
bash ./run_with_backend_access.sh plan -var-file=dev.tfvars -out=plan.tfplan
bash ./run_with_backend_access.sh apply plan.tfplan
```

---

## Validation

```bash
# All resources
az resource list --resource-group rg-azllm-foundry-dev --output table

# AI Services accounts
az cognitiveservices account list --resource-group rg-azllm-foundry-dev --output table

# Key Vault
az keyvault show --name kv-azllm-fnd-dev --query properties.provisioningState

# Container Apps
az containerapp list --resource-group rg-azllm-foundry-dev --output table
```

---

## Daily Operations

### Re-open backend for manual changes

```bash
bash ./run_with_backend_access.sh open-access
# ... run terraform commands ...
bash ./run_with_backend_access.sh close-access
```

### Refresh state

```bash
bash ./run_with_backend_access.sh plan -refresh-only -var-file=dev.tfvars
```

### Destroy

```bash
bash ./run_with_backend_access.sh destroy -var-file=dev.tfvars
cd ../backend-storage
terraform destroy -var-file=backend-storage.tfvars
```

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `FlagMustBeSetForRestore` | Soft-deleted AI account with same name | Set `enable_soft_deleted_account_purge = true` |
| `QuotaExceeded` | Not enough TPM quota in region | Reduce `capacity` in `foundry_models_config` |
| `AuthorizationFailed` | Missing role assignment | Ensure Contributor/Owner on subscription |
| Backend 403 | Storage closed | Run `open-access` or check Terraform auto-close |
| Key Vault already exists | Soft-delete retention | Purge via `az keyvault purge --name ...` |
