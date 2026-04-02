from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any, Callable

from .contracts import load_contract_catalog


@dataclass(frozen=True)
class EmbeddedFinanceMetadata:
    slug: str
    display_name: str
    version: str
    revision: str | None
    contract_version: str
    minimum_erp_contract_version: str
    status: str
    detail: str
    database_backend: str
    database_mode: str
    erp_surfaces: list[str] = field(default_factory=list)
    api_prefixes: list[str] = field(default_factory=list)

    def as_dict(self) -> dict[str, Any]:
        return asdict(self)


class EmbeddedFinanceService:
    def __init__(self, host_service_factory: Callable[[], Any], metadata: EmbeddedFinanceMetadata) -> None:
        self._host = host_service_factory()
        self._metadata = metadata
        self._contracts = load_contract_catalog()

    def extension_metadata(self) -> dict[str, Any]:
        payload = self._metadata.as_dict()
        payload["contracts"] = {
            key: {
                "name": value.get("name"),
                "version": value.get("version"),
                "description": value.get("description"),
            }
            for key, value in self._contracts.items()
        }
        return payload

    def snapshot_metadata(self) -> dict[str, Any]:
        return {
            "finance_extension_status": self._metadata.status,
            "finance_extension_version": self._metadata.version,
            "finance_extension_revision": self._metadata.revision,
            "finance_extension_contract_version": self._metadata.contract_version,
        }

    def ui_contract(self) -> dict[str, Any]:
        contract = self._contracts.get("ui-contract", {})
        if not isinstance(contract, dict):
            return {}
        return contract

    def __getattr__(self, item: str) -> Any:
        return getattr(self._host, item)


def create_embedded_finance_service(
    *,
    host_service_factory: Callable[[], Any],
    manifest: dict[str, Any],
    state: dict[str, Any],
    settings: dict[str, Any] | None = None,
) -> EmbeddedFinanceService:
    metadata = EmbeddedFinanceMetadata(
        slug=str(state.get("slug") or manifest.get("module_slug") or "muhasebe-otamasyon"),
        display_name=str(state.get("display_name") or manifest.get("display_name") or "Muhasebe Otomasyon Embedded Finance"),
        version=str(state.get("version") or manifest.get("version") or "0.0.0"),
        revision=state.get("revision") or manifest.get("revision"),
        contract_version=str(state.get("contract_version") or manifest.get("contract_version") or "unknown"),
        minimum_erp_contract_version=str(
            state.get("minimum_erp_contract_version") or manifest.get("minimum_erp_contract_version") or "unknown"
        ),
        status=str(state.get("status") or "ready"),
        detail=str(state.get("detail") or "Embedded finance extension aktif."),
        database_backend=str(
            (settings or {}).get("database_backend")
            or state.get("database_backend")
            or manifest.get("database_backend")
            or "sqlite"
        ),
        database_mode=str(
            (settings or {}).get("database_mode")
            or state.get("database_mode")
            or manifest.get("database_mode")
            or "embedded"
        ),
        erp_surfaces=[str(item) for item in (state.get("erp_surfaces") or manifest.get("erp_surfaces") or [])],
        api_prefixes=[str(item) for item in (state.get("api_prefixes") or manifest.get("api_prefixes") or [])],
    )
    return EmbeddedFinanceService(host_service_factory=host_service_factory, metadata=metadata)
