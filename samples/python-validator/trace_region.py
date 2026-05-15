# -*- coding: utf-8 -*-
"""
trace_region.py — Teste de roteamento regional do Azure AI Foundry.

Envia N requisições sequenciais e exibe, para cada uma, qual região
atendeu, a latência e os tokens usados. Útil para confirmar failover.

Uso:
  python trace_region.py                   # 5 requisições com pergunta padrão
  python trace_region.py -n 10             # 10 requisições
  python trace_region.py -n 3 -q "Ola"    # pergunta customizada
  python trace_region.py --force westus3  # força região inicial (ignora ordem)
"""
from __future__ import annotations

import argparse
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

from router import FoundryRouter, REGIONS


REGION_LABEL = {
    "eastus":  "East US  ",
    "westus3": "West US 3",
}

REGION_MARKER = {
    "eastus":  "[EUS]",
    "westus3": "[WUS3]",
}


def run(n: int, question: str, force_region: str | None) -> int:
    regions = REGIONS
    if force_region:
        # move a região forçada para o topo para ser a primária
        ordered = [r for r in REGIONS if r["name"] == force_region]
        ordered += [r for r in REGIONS if r["name"] != force_region]
        if not ordered:
            print(f"Regiao desconhecida: {force_region}. Opcoes: {[r['name'] for r in REGIONS]}")
            return 1
        regions = ordered

    router = FoundryRouter(regions=regions)

    print(f"\n{'='*60}")
    print(f"  Trace regional — {n} requisicoes")
    if force_region:
        print(f"  Regiao primaria forcada: {force_region}")
    print(f"  Pergunta: {question!r}")
    print(f"{'='*60}\n")

    header = f"  {'#':>3}  {'Regiao':<12}  {'Latencia':>8}  {'in':>5}  {'out':>5}  Resposta"
    print(header)
    print(f"  {'-'*3}  {'-'*12}  {'-'*8}  {'-'*5}  {'-'*5}  {'-'*20}")

    errors = 0
    region_counts: dict[str, int] = {}

    for i in range(1, n + 1):
        result = router.chat(question, max_tokens=60)

        marker = REGION_MARKER.get(result.region, f"[{result.region.upper()}]")
        label  = REGION_LABEL.get(result.region, result.region)

        if result.ok:
            region_counts[result.region] = region_counts.get(result.region, 0) + 1
            snippet = result.content.replace("\n", " ")[:50]
            print(
                f"  {i:>3}  {marker} {label}  {result.latency_ms:>6.0f}ms"
                f"  {result.prompt_tokens:>5}  {result.completion_tokens:>5}  {snippet}"
            )
        else:
            errors += 1
            print(f"  {i:>3}  [ERR] {result.region:<10}  {result.error}")

    print(f"\n{'='*60}")
    print("  Resumo por regiao:")
    for region, count in region_counts.items():
        pct = count / n * 100
        bar = "#" * count + "." * (n - count)
        print(f"    {REGION_MARKER.get(region, region):<7} {count:>3}/{n}  ({pct:5.1f}%)  [{bar}]")
    if errors:
        print(f"    [ERR]  {errors:>3}/{n} erros")
    print(f"{'='*60}\n")

    return 0 if errors < n else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Trace de regiao por requisicao")
    parser.add_argument("-n", "--count",  type=int, default=5,
                        help="Numero de requisicoes (default: 5)")
    parser.add_argument("-q", "--question", default="Which Azure region are you hosted in?",
                        help="Pergunta a enviar (default: perguntar sobre a regiao)")
    parser.add_argument("--force", metavar="REGION", default=None,
                        help="Forcas regiao primaria: eastus | westus3")
    args = parser.parse_args()
    return run(args.count, args.question, args.force)


if __name__ == "__main__":
    sys.exit(main())
