"""
Smoke test do Azure AI Foundry (GPT-4o) usando Microsoft Entra ID.

Replica o padrão usado em projetos produtivos: AzureOpenAI client com
azure_ad_token_provider (sem API keys, sem segredos hardcoded).
"""
from __future__ import annotations

import os
import sys
from dataclasses import dataclass

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from openai import AzureOpenAI

API_VERSION = "2024-10-21"
DEPLOYMENT = "gpt-4o"

ENDPOINTS: dict[str, str] = {
    "eastus":  "https://api-azllmdev-eus-01.cognitiveservices.azure.com/",
    "westus3": "https://api-azllmdev-wus3-01.cognitiveservices.azure.com/",
}


@dataclass
class Result:
    region: str
    ok: bool
    detail: str


def call_region(region: str, endpoint: str, token_provider) -> Result:
    try:
        client = AzureOpenAI(
            azure_endpoint=endpoint,
            api_version=API_VERSION,
            azure_ad_token_provider=token_provider,
        )
        resp = client.chat.completions.create(
            model=DEPLOYMENT,
            messages=[
                {"role": "system", "content": "Answer in 5 words or less."},
                {"role": "user", "content": "Say hi from Azure Foundry."},
            ],
            max_tokens=20,
            temperature=0,
        )
        content = (resp.choices[0].message.content or "").strip()
        usage = resp.usage
        return Result(
            region=region,
            ok=True,
            detail=f"{content!r} (in={usage.prompt_tokens} out={usage.completion_tokens})",
        )
    except Exception as exc:  # noqa: BLE001
        return Result(region=region, ok=False, detail=f"{type(exc).__name__}: {exc}")


def main() -> int:
    credential = DefaultAzureCredential()
    token_provider = get_bearer_token_provider(
        credential, "https://cognitiveservices.azure.com/.default"
    )

    results = [call_region(r, ep, token_provider) for r, ep in ENDPOINTS.items()]

    print()
    for r in results:
        flag = "OK " if r.ok else "ERR"
        print(f"[{flag}] {r.region:8s} -> {r.detail}")

    return 0 if all(r.ok for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())
