# Foundry GPT-4o validator

Aplicação Python mínima para validar os deployments GPT-4o (East US + West US 3)
do Azure AI Foundry usando autenticação Microsoft Entra (sem API key).

## Pré-requisitos

- Python 3.10+
- `az login` no Windows com a conta que tem `Cognitive Services OpenAI User`
  nos dois accounts (`aif-azllmdev-eus-01` e `aif-azllmdev-wus3-01`).
- Seu IP público liberado nos `networkAcls` dos Foundry accounts (ver
  `prisma_cloud_cidrs` no `dev.tfvars`).

## Setup

```powershell
cd samples\python-validator
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

## Uso

```powershell
python validate.py
```

Saída esperada: status 200 + completion para cada região.
