"""Experiment identity and array-aware NPZ records (numeric arrays + JSON metadata, never pickle)."""

from pathlib import Path
from datetime import datetime
import hashlib
import json
import math
import os
import uuid
import numpy as np


def now_iso():
    return datetime.now().astimezone().isoformat(timespec="seconds")


def _encode(value, arrays, fingerprint=False):
    if isinstance(value, np.ndarray):
        if value.dtype.hasobject:
            raise TypeError("Object arrays are not allowed in saved records")
        if fingerprint:
            return {
                "array_dtype": value.dtype.str,
                "shape": list(value.shape),
                "sha256": hashlib.sha256(np.ascontiguousarray(value).tobytes()).hexdigest(),
            }
        key = "array_%06d" % len(arrays)
        arrays[key] = value
        return {"__array__": key}
    if isinstance(value, np.generic):
        return _encode(value.item(), arrays, fingerprint)
    if isinstance(value, dict):
        if not all(isinstance(k, str) for k in value):
            raise TypeError("Record dictionary keys must be text")
        return {k: _encode(v, arrays, fingerprint) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [_encode(v, arrays, fingerprint) for v in value]
    if isinstance(value, Path):
        return str(value)
    if isinstance(value, complex):
        return {"__complex__": [value.real, value.imag]}
    if isinstance(value, float) and not math.isfinite(value):
        return {"__float__": "nan" if math.isnan(value) else ("inf" if value > 0 else "-inf")}
    if value is None or isinstance(value, (str, bool, int, float)):
        return value
    raise TypeError("Unsupported record type: " + type(value).__name__)


def signature(experiment):
    keys = ("config", "cfg", "packet", "plan")
    if not isinstance(experiment, dict) or any(k not in experiment for k in keys):
        raise ValueError("Use experiment = isac.prepare(cfg)")
    tree = _encode({k: experiment[k] for k in keys}, {}, fingerprint=True)
    return hashlib.sha256(
        json.dumps(tree, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")
    ).hexdigest()


def validate_experiment(experiment):
    if experiment.get("signature") != signature(experiment):
        raise ValueError("Prepared experiment changed. Prepare and transmit again before capture.")


def save_record(path, data):
    path = Path(path)
    if path.suffix.lower() != ".npz":
        path = path.with_suffix(".npz")
    path.parent.mkdir(parents=True, exist_ok=True)
    arrays = {}
    tree = _encode(data, arrays)
    arrays["__metadata__"] = np.array(json.dumps(tree, allow_nan=False, separators=(",", ":")))
    pending = path.with_name(path.name + "." + uuid.uuid4().hex + ".pending")
    try:
        with pending.open("wb") as stream:
            np.savez_compressed(stream, **arrays)
        os.replace(pending, path)
    finally:
        if pending.exists():
            pending.unlink()
    return str(path)


def load_record(path):
    with np.load(path, allow_pickle=False) as archive:
        tree = json.loads(str(archive["__metadata__"].item()))

        def decode(value):
            if isinstance(value, list):
                return [decode(x) for x in value]
            if isinstance(value, dict):
                if set(value) == {"__array__"}:
                    return archive[value["__array__"]].copy()
                if set(value) == {"__complex__"}:
                    return complex(*value["__complex__"])
                if set(value) == {"__float__"}:
                    return float(value["__float__"])
                return {k: decode(v) for k, v in value.items()}
            return value

        return decode(tree)
