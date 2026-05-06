# 🚀 Azure LLM Platform — Infrastructure as Code

Azure AI Foundry infrastructure with GPT-4o Multi-Region Deployment, automated via Terraform.

> **Lab project** — built to demonstrate real-world IaC skills: modular Terraform, multi-region Azure AI Foundry, enterprise security (Zero Trust / RBAC), and automated CI/CD-ready pipelines.

---

## 📚 Quick Navigation

- **🟢 New here?** Start with [QUICK_START.md](./dev/QUICK_START.md) — 5 min read
- **📘 Full walkthrough:** [DEPLOYMENT_GUIDE.md](./dev/DEPLOYMENT_GUIDE.md)
- **🔗 Module map:** [MODULES_AND_FLOW.md](./dev/docs/MODULES_AND_FLOW.md)
- **⚙️ Terraform root:** [dev/terraform/README.md](./dev/terraform/README.md)

---

## 🎯 Project Overview

This lab automates the deployment of **Azure AI Foundry** with:

| Feature | Detail |
|---------|--------|
| Multi-Region | East US + West US 3 |
| LLM Model | GPT-4o (Global Standard) |
| Security | Zero Trust, RBAC, Private Endpoints |
| State Backend | Azure Storage (RBAC-only, no access keys) |
| IaC | Terraform — fully modular design |

---

## 📦 Repository Structure

```text
azure-llm-platform-iac/
├── dev/
│   ├── backend-storage/          ← Stage 1: Terraform remote state setup
│   ├── terraform/                ← Stage 2: Main platform deployment
│   │   └── modules/
│   │       └── foundry-platform/ ← Core platform module
│   │           └── resources/
│   │               ├── resource-group/
│   │               ├── networking/
│   │               ├── foundry-ai/
│   │               ├── identity-rbac/
│   │               ├── container-apps/
│   │               └── litellm-proxy/
│   ├── docs/                     ← Architecture docs (local only)
│   ├── QUICK_START.md
│   └── DEPLOYMENT_GUIDE.md
├── .gitignore
└── README.md
```

---

## 🚀 Quick Start

### Prerequisites

| Tool | Minimum Version |
|------|----------------|
| Terraform | >= 1.7 |
| Azure CLI | >= 2.50 |
| Azure Subscription | Contributor or Owner |

### Deploy in 2 Stages

```bash
# ── Stage 1: Remote State Backend (~5 min) ───────────────────────────────────
cd dev/backend-storage
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Review/edit names in backend-storage.tfvars
terraform init
terraform apply -auto-approve -var-file=backend-storage.tfvars

# Note output values for Stage 2
terraform output

# ── Stage 2: Foundry Platform (~10 min) ──────────────────────────────────────
cd ../terraform

# Fill backend.tfvars with output values from Stage 1
# Fill dev.tfvars with your subscription/config values

bash ./run_with_backend_access.sh init -reconfigure -backend-config=backend.tfvars
terraform validate
bash ./run_with_backend_access.sh plan -var-file=dev.tfvars -out=plan.tfplan
bash ./run_with_backend_access.sh apply plan.tfplan
```

---

## 🔐 Security Design

| Control | Implementation |
|---------|---------------|
| No static secrets | Managed Identity everywhere |
| Least privilege | RBAC scoped per resource |
| Network isolation | VNet + Subnets + NSGs |
| Private connectivity | Private Endpoints ready |
| Secret management | Azure Key Vault |
| State security | Remote state with RBAC (no SAS keys) |
| Transport | TLS 1.2 minimum enforced |

---

## 🗺️ Career Context

This lab reflects patterns and technologies I have worked with across enterprise cloud AI projects:

- **Azure AI Foundry** — provisioning and managing AI Services hubs and model deployments
- **Terraform / IaC** — modular, reusable infrastructure with remote state and RBAC backends
- **LiteLLM Proxy** — unified LLM gateway routing across multi-region endpoints
- **Zero Trust Networking** — VNet segmentation, NSG deny-by-default, private endpoints
- **Container Apps** — serverless container workloads for inference and validation pipelines
- **Key Vault + Managed Identity** — eliminating static secrets in cloud-native workloads

---

## 🔭 Future Lab Roadmap

- [ ] GitHub Actions CI/CD pipeline (`terraform plan` on PR, `apply` on merge)
- [ ] Drift detection workflow (scheduled `terraform plan`)
- [ ] Azure Policy as Code integration
- [ ] Bicep alternative module side-by-side
- [ ] Cost estimation with Infracost
- [ ] OPA/Conftest policy gates on `plan` output

---

## 📄 License

MIT — feel free to fork and adapt for your own Azure AI labs.
