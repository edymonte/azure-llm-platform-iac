"""
Azure AI Foundry — Smart Router com auto-failover por região.

Funcionalidades:
  - Valida todos os endpoints antes de iniciar (health check)
  - Roteia chamadas para a região primária configurada
  - Faz failover automático para outra região quando:
      * Rate limit (429 / RateLimitError)
      * Quota excedida (tokens TPM/RPM esgotados)
      * Endpoint indisponível (timeout / connection error)
  - Modo CLI interativo para testes manuais
  - Modo programático (importável como módulo)

Autenticação: Microsoft Entra ID via DefaultAzureCredential
(sem API keys, sem segredos hardcoded)

Uso:
  python router.py                        # health check + prompt interativo
  python router.py --validate-only        # apenas health check, exit 0/1
  python router.py --prompt "Olá mundo"   # uma chamada, imprime resposta
"""
from __future__ import annotations

import argparse
import os
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Iterator

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from openai import AzureOpenAI, RateLimitError
from openai.types.chat import ChatCompletionMessageParam

# ─── Configuração ───────────────────────────────────────────────────────────────

API_VERSION = "2024-10-21"
DEPLOYMENT  = "gpt-4o"

# Ordem de preferência: primary → fallback(s)
REGIONS: list[dict] = [
    {
        "name":     "eastus",
        "endpoint": os.environ.get(
            "FOUNDRY_ENDPOINT_EASTUS",
            "https://api-azllmdev-eus-01.cognitiveservices.azure.com/",
        ),
    },
    {
        "name":     "westus3",
        "endpoint": os.environ.get(
            "FOUNDRY_ENDPOINT_WESTUS3",
            "https://api-azllmdev-wus3-01.cognitiveservices.azure.com/",
        ),
    },
]

# Segundos para considerar uma região "em cooldown" após rate-limit
COOLDOWN_SECS = int(os.environ.get("FOUNDRY_COOLDOWN_SECS", "60"))

# ─── Tipos ──────────────────────────────────────────────────────────────────────


@dataclass
class Region:
    name: str
    endpoint: str
    # timestamp (epoch) após o qual esta região pode ser tentada novamente
    available_after: float = 0.0
    # contadores de saúde
    successes: int = 0
    failures:  int = 0
    rate_limits: int = 0

    @property
    def available(self) -> bool:
        return time.time() >= self.available_after

    def mark_rate_limited(self, retry_after: float | None = None) -> None:
        wait = retry_after if retry_after and retry_after > 0 else COOLDOWN_SECS
        self.available_after = time.time() + wait
        self.rate_limits += 1
        _log(f"[COOLDOWN] {self.name} em cooldown por {wait:.0f}s (total rate-limits: {self.rate_limits})")

    def mark_ok(self) -> None:
        self.successes += 1
        self.available_after = 0.0

    def mark_error(self) -> None:
        self.failures += 1


@dataclass
class CallResult:
    region: str
    ok: bool
    content: str
    prompt_tokens: int   = 0
    completion_tokens: int = 0
    latency_ms: float    = 0.0
    error: str           = ""


# ─── Roteador ───────────────────────────────────────────────────────────────────


class FoundryRouter:
    """
    Roteador multi-região com failover automático.

    Uso básico:
        router = FoundryRouter()
        result = router.chat("Explique o que é computação quântica.")
        print(result.content)
    """

    def __init__(
        self,
        regions: list[dict] | None = None,
        deployment: str = DEPLOYMENT,
        api_version: str = API_VERSION,
    ) -> None:
        self._regions = [Region(**r) for r in (regions or REGIONS)]
        self._deployment = deployment
        self._api_version = api_version
        self._credential = DefaultAzureCredential()
        self._token_provider = get_bearer_token_provider(
            self._credential, "https://cognitiveservices.azure.com/.default"
        )
        # cache de clientes por endpoint
        self._clients: dict[str, AzureOpenAI] = {}

    # ── público ────────────────────────────────────────────────────────────────

    def validate(self) -> list[CallResult]:
        """Health check em todas as regiões configuradas. Retorna os resultados."""
        results = []
        for region in self._regions:
            result = self._try_region(
                region,
                messages=[
                    {"role": "system", "content": "Answer in 5 words or less."},
                    {"role": "user",   "content": "Say hi from Azure Foundry."},
                ],
                max_tokens=20,
            )
            results.append(result)
        return results

    def chat(
        self,
        user_message: str,
        system_prompt: str = "You are a helpful assistant.",
        history: list[ChatCompletionMessageParam] | None = None,
        max_tokens: int = 1024,
        temperature: float = 0.7,
    ) -> CallResult:
        """
        Envia uma mensagem e retorna a resposta.
        Faz failover automático se a região primária estiver indisponível.
        Lança RuntimeError se todas as regiões falharem.
        """
        messages: list[ChatCompletionMessageParam] = [
            {"role": "system", "content": system_prompt},
            *(history or []),
            {"role": "user", "content": user_message},
        ]
        return self._route(messages, max_tokens=max_tokens, temperature=temperature)

    def status(self) -> None:
        """Imprime o status atual de cada região."""
        now = time.time()
        print("\n── Status das regiões ──")
        for r in self._regions:
            if r.available:
                state = "disponível"
            else:
                wait = r.available_after - now
                state = f"cooldown {wait:.0f}s restantes"
            print(
                f"  {r.name:10s} | {state:30s} | "
                f"ok={r.successes} fail={r.failures} rl={r.rate_limits}"
            )

    # ── interno ────────────────────────────────────────────────────────────────

    def _client(self, region: Region) -> AzureOpenAI:
        if region.endpoint not in self._clients:
            self._clients[region.endpoint] = AzureOpenAI(
                azure_endpoint=region.endpoint,
                api_version=self._api_version,
                azure_ad_token_provider=self._token_provider,
            )
        return self._clients[region.endpoint]

    def _route(
        self,
        messages: list[ChatCompletionMessageParam],
        **kwargs,
    ) -> CallResult:
        available = [r for r in self._regions if r.available]
        if not available:
            # Tenta a região com menor tempo de espera como último recurso
            available = sorted(self._regions, key=lambda r: r.available_after)[:1]
            _log(f"[WARN] Todas as regiões em cooldown — forçando tentativa em {available[0].name}")

        last_error = ""
        for region in available:
            result = self._try_region(region, messages, **kwargs)
            if result.ok:
                return result
            last_error = result.error

            # Decide se deve tentar próxima região ou lançar
            if "RateLimitError" in result.error or "429" in result.error:
                _log(f"[FAILOVER] {region.name} → rate-limited, tentando próxima região…")
                continue  # já foi colocado em cooldown dentro de _try_region
            if any(kw in result.error for kw in ("timeout", "connect", "Connection")):
                _log(f"[FAILOVER] {region.name} → erro de rede, tentando próxima região…")
                continue

            # Erro não-recuperável (ex: 401 autenticação): não faz failover
            break

        raise RuntimeError(
            f"Todas as regiões falharam. Último erro: {last_error}"
        )

    def _try_region(
        self,
        region: Region,
        messages: list[ChatCompletionMessageParam],
        max_tokens: int = 1024,
        temperature: float = 0.7,
    ) -> CallResult:
        t0 = time.perf_counter()
        try:
            resp = self._client(region).chat.completions.create(
                model=self._deployment,
                messages=messages,
                max_tokens=max_tokens,
                temperature=temperature,
            )
            latency = (time.perf_counter() - t0) * 1000
            region.mark_ok()
            usage = resp.usage
            return CallResult(
                region=region.name,
                ok=True,
                content=(resp.choices[0].message.content or "").strip(),
                prompt_tokens=usage.prompt_tokens if usage else 0,
                completion_tokens=usage.completion_tokens if usage else 0,
                latency_ms=latency,
            )
        except RateLimitError as exc:
            latency = (time.perf_counter() - t0) * 1000
            # Tenta extrair retry-after do cabeçalho
            retry_after: float | None = None
            if hasattr(exc, "response") and exc.response is not None:
                ra = exc.response.headers.get("retry-after")
                if ra:
                    try:
                        retry_after = float(ra)
                    except ValueError:
                        pass
            region.mark_rate_limited(retry_after)
            return CallResult(
                region=region.name,
                ok=False,
                latency_ms=latency,
                error=f"RateLimitError: {exc}",
            )
        except Exception as exc:  # noqa: BLE001
            latency = (time.perf_counter() - t0) * 1000
            region.mark_error()
            return CallResult(
                region=region.name,
                ok=False,
                latency_ms=latency,
                error=f"{type(exc).__name__}: {exc}",
            )


# ─── Helpers ─────────────────────────────────────────────────────────────────────


def _log(msg: str) -> None:
    ts = datetime.now(timezone.utc).strftime("%H:%M:%S")
    print(f"{ts} {msg}", file=sys.stderr)


def _print_result(result: CallResult) -> None:
    if result.ok:
        print(
            f"\n[{result.region}] {result.latency_ms:.0f}ms | "
            f"in={result.prompt_tokens} out={result.completion_tokens}\n"
            f"{result.content}"
        )
    else:
        print(f"\n[{result.region}] ERRO: {result.error}")


# ─── CLI ─────────────────────────────────────────────────────────────────────────


def _run_validate(router: FoundryRouter) -> int:
    print("\n── Health check ──")
    results = router.validate()
    ok_count = 0
    for r in results:
        flag = "OK " if r.ok else "ERR"
        if r.ok:
            ok_count += 1
            print(
                f"  [{flag}] {r.region:8s} → {r.content!r}  "
                f"({r.latency_ms:.0f}ms | in={r.prompt_tokens} out={r.completion_tokens})"
            )
        else:
            print(f"  [{flag}] {r.region:8s} → {r.error}")

    print(f"\n{ok_count}/{len(results)} regiões saudáveis.")
    return 0 if ok_count > 0 else 1


def _run_single_prompt(router: FoundryRouter, prompt: str) -> int:
    try:
        result = router.chat(prompt)
        _print_result(result)
        return 0
    except RuntimeError as exc:
        print(f"ERRO: {exc}", file=sys.stderr)
        return 1


def _run_interactive(router: FoundryRouter) -> int:
    """Loop interativo de chat com histórico e failover transparente."""
    print("\n── Chat interativo (Ctrl+C ou 'sair' para encerrar) ──")
    print("   Comandos especiais: /status  /limpar  /regioes  /sair\n")

    history: list[ChatCompletionMessageParam] = []
    system_prompt = "You are a helpful assistant. Respond in the same language as the user."

    while True:
        try:
            user_input = input("você: ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nEncerrando.")
            break

        if not user_input:
            continue

        cmd = user_input.lower()
        if cmd in ("/sair", "sair", "exit", "quit"):
            print("Encerrando.")
            break
        if cmd == "/status":
            router.status()
            continue
        if cmd == "/limpar":
            history.clear()
            print("  [histórico limpo]")
            continue
        if cmd == "/regioes":
            for r in router._regions:
                print(f"  {r.name}: {r.endpoint}")
            continue

        try:
            result = router.chat(
                user_input,
                system_prompt=system_prompt,
                history=history,
            )
        except RuntimeError as exc:
            print(f"  ERRO: {exc}")
            continue

        # Avisa se houve failover
        if history and result.region != getattr(history[-1], "_region", result.region):
            print(f"  ⚡ failover → {result.region}")

        _print_result(result)

        # Adiciona ao histórico
        history.append({"role": "user", "content": user_input})
        history.append({"role": "assistant", "content": result.content})

        # Mantém histórico em no máximo 20 turnos (40 mensagens)
        if len(history) > 40:
            history = history[-40:]

    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Azure AI Foundry Smart Router — validação e failover automático"
    )
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Apenas health check em todas as regiões, sem prompt interativo",
    )
    parser.add_argument(
        "--prompt",
        metavar="TEXT",
        help="Envia um prompt único e imprime a resposta",
    )
    parser.add_argument(
        "--deployment",
        default=DEPLOYMENT,
        help=f"Nome do deployment (padrão: {DEPLOYMENT})",
    )
    parser.add_argument(
        "--cooldown",
        type=int,
        default=COOLDOWN_SECS,
        help=f"Segundos de cooldown após rate-limit (padrão: {COOLDOWN_SECS})",
    )
    args = parser.parse_args()

    global COOLDOWN_SECS
    COOLDOWN_SECS = args.cooldown

    router = FoundryRouter(deployment=args.deployment)

    # 1. Sempre faz health check primeiro
    rc = _run_validate(router)

    if args.validate_only:
        return rc

    # 2. Prompt único
    if args.prompt:
        return _run_single_prompt(router, args.prompt)

    # 3. Chat interativo
    return _run_interactive(router)


if __name__ == "__main__":
    sys.exit(main())
