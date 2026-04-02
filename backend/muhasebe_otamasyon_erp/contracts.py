from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def load_contract_catalog() -> dict[str, dict]:
    contract_root = ROOT / "contracts"
    catalog: dict[str, dict] = {}
    for contract_path in sorted(contract_root.glob("*.json")):
        catalog[contract_path.stem] = json.loads(contract_path.read_text(encoding="utf-8"))
    return catalog
