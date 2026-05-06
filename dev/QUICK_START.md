# 🚀 QUICK START — Azure LLM Platform IaC

Get the full platform running in under 15 minutes.

---

## Prerequisites

```bash
# 1. Terraform >= 1.7
terraform --version

# 2. Azure CLI >= 2.50
az --version

# 3. Authenticate
az login
az account list --output table
az account set --subscription "YOUR_SUBSCRIPTION_ID"
az account show --output table
```

---

## Stage 1: Remote State Backend (~5 min)

```bash
cd dev/backend-storage

# (Optional) Adjust names and tags
notepad backend-storage.tfvars   # Windows
# nano backend-storage.tfvars    # Linux/macOS

terraform init
terraform validate
terraform apply -auto-approve -var-file=backend-storage.tfvars

# Save these outputs — you will need them in Stage 2
terraform output
```

---

## Stage 2: Deploy Foundry Platform (~10 min)

```bash
cd ../terraform

# 1. Copy example files and fill in your values
copy dev.tfvars.example dev.tfvars
notepad dev.tfvars      # set subscription_id, regions, etc.

# 2. Fill backend.tfvars with values from Stage 1 output
notepad backend.tfvars

# 3. Init, plan, apply
bash ./run_with_backend_access.sh init -reconfigure -backend-config=backend.tfvars
terraform validate
bash ./run_with_backend_access.sh plan -var-file=dev.tfvars -out=plan.tfplan
bash ./run_with_backend_access.sh apply plan.tfplan

# Done!
terraform output
```

---

## What Gets Created?

| Resource | Detail |
|----------|--------|
| Resource Group | `rg-azllm-foundry-dev` in East US |
| Virtual Network | `10.20.0.0/16` — 4 subnets |
| Managed Identity | RBAC-scoped to AI Services + Key Vault |
| Key Vault | Secrets for API keys and config |
| Azure AI Foundry | East US + West US 3 |
| GPT-4o Deployment | Global Standard, both regions |
| Container Apps Env | LiteLLM proxy + test + validation apps |

---

## Validate After Deploy

```bash
# List all resources in the resource group
az resource list --resource-group rg-azllm-foundry-dev --output table

# Check AI Services accounts
az cognitiveservices account list --resource-group rg-azllm-foundry-dev --output table

# Test LiteLLM endpoint (if CAE external ingress enabled)
curl -X POST "$LITELLM_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o","messages":[{"role":"user","content":"ping"}]}'
```

---

## Teardown

```bash
cd dev/terraform
bash ./run_with_backend_access.sh destroy -var-file=dev.tfvars

cd ../backend-storage
terraform destroy -var-file=backend-storage.tfvars
```
