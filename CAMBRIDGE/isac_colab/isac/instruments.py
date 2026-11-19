"""Explicit M8195A (AWG) / MSO-X 4154A (oscilloscope) I/O through VISA. Never reads AWG samples during playback.

    rig = connect(cfg)                  opens and identifies both instruments (no reset, no output change)
    rig.check(experiment)               AWG profile / memory report
    rig.transmit(experiment, folder)    loads the combined pilot/OFDM waveform (or reuses it when the AWG already
                                        holds it) and starts the continuous playback on channel 1
    rig.capture(experiment)             one fresh oscilloscope record (:DIGitize, raw WORD codes)
    rig.disconnect()                    stops the playback, output 1 off, closes the connections

PyVISA is imported only by connect(); offline analysis needs no VISA driver.
"""

from __future__ import annotations
from contextlib import contextmanager
from copy import deepcopy
from datetime import datetime
from pathlib import Path
import math
import os
import re
import uuid
import warnings
import numpy as np
from .common import validate_experiment, save_record, now_iso

REUSE_CHECK_BLOCKS = 32  # extra 128-sample blocks compared before reusing a loaded waveform
# Oscilloscope settings that shape the record (read only; stored in session.json and the Excel "session" sheet)
SCOPE_SETTING_QUERIES = {
    "idn": "*IDN?", "acquire_type": ":ACQuire:TYPE?", "sample_rate_Sa_s": ":ACQuire:SRATe?",
    "timebase_s_div": ":TIMebase:SCALe?", "timebase_mode": ":TIMebase:MODE?", "trigger_sweep": ":TRIGger:SWEep?",
    "ch_scale_V_div": ":CHANnel{ch}:SCALe?", "ch_offset_V": ":CHANnel{ch}:OFFSet?",
    "ch_coupling": ":CHANnel{ch}:COUPling?", "ch_impedance": ":CHANnel{ch}:IMPedance?",
    "ch_bw_limit": ":CHANnel{ch}:BWLimit?", "ch_probe": ":CHANnel{ch}:PROBe?", "ch_invert": ":CHANnel{ch}:INVert?",
}
_DLL_DIRS = {}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def numbers(reply, count=None):
    try:
        values = np.array([float(v.strip()) for v in str(reply).strip().strip('"').split(",")])
    except ValueError as exc:
        raise RuntimeError(f"Invalid numeric SCPI response: {reply!r}") from exc
    require(np.all(np.isfinite(values)), f"Nonfinite SCPI response: {reply!r}")
    require(
        count is None or len(values) == count,
        f"SCPI response has {len(values)} values; expected {count}: {reply!r}",
    )
    return float(values[0]) if count == 1 else values


def _integer(value, name, low=1):
    require(
        np.isscalar(value) and np.isfinite(value) and value == int(value) and value >= low,
        f"{name} must be an integer >= {low}.",
    )
    return int(value)


class Transport:
    """Own one opened PyVISA resource; exact IEEE488.2 binary blocks."""

    def __init__(self, resource, address, timeout_s):
        self.device, self.address, self.closed = resource, str(address), False
        try:
            require(math.isfinite(timeout_s) and timeout_s > 0, "VISA timeout must be positive.")
            resource.timeout = int(math.ceil(1000 * timeout_s))
            resource.read_termination = "\n"
            resource.write_termination = "\n"
            resource.encoding = "ascii"
            resource.chunk_size = 1024 * 1024
        except BaseException:
            self.close()
            raise

    def _ensure_open(self):
        require(not self.closed and self.device is not None, "VISA connection is closed.")

    @staticmethod
    def _command(command):
        require(
            isinstance(command, str) and command and "\r" not in command and "\n" not in command,
            "SCPI command must be a single nonempty text line.",
        )
        command.encode("ascii")
        return command

    def query(self, command):
        self._ensure_open()
        command = self._command(command)
        try:
            reply = str(self.device.query(command)).strip()
        except Exception as exc:
            raise RuntimeError(f"VISA query failed on {self.address}: {command}: {exc}") from exc
        require(bool(reply), f"Empty VISA reply to {command} on {self.address}.")
        return reply

    def send(self, command):
        self._ensure_open()
        command = self._command(command)
        try:
            self.device.write(command)
        except Exception as exc:
            raise RuntimeError(f"VISA write failed on {self.address}: {command}: {exc}") from exc

    @staticmethod
    def make_block(prefix, codes):
        require(
            isinstance(prefix, str) and prefix and all(32 <= ord(c) <= 126 for c in prefix),
            "Binary command prefix must be printable ASCII.",
        )
        codes = np.asarray(codes)
        require(
            codes.dtype == np.int8 and codes.ndim == 1 and codes.size > 0,
            "Binary DAC samples must be a nonempty int8 vector.",
        )
        payload = codes.tobytes()
        length = str(len(payload)).encode("ascii")
        require(len(length) <= 9, "IEEE block payload is too large.")
        return prefix.encode("ascii") + b"#" + str(len(length)).encode("ascii") + length + payload + b"\n"

    def write_block(self, prefix, codes):
        self._ensure_open()
        data = self.make_block(prefix, codes)
        try:
            written = self.device.write_raw(data)
        except Exception as exc:
            raise RuntimeError(f"VISA binary write failed on {self.address}: {prefix}: {exc}") from exc
        require(written == len(data), f"Short binary write: {written} of {len(data)} bytes.")

    def _read_exact(self, count):
        if count == 0:
            return b""
        data = bytes(self.device.read_bytes(count, break_on_termchar=False))
        require(len(data) == count, f"Short binary read: {len(data)} of {count} bytes.")
        return data

    def read_block(self, command, datatype, expected_elements, max_elements=None):
        self._ensure_open()
        if max_elements is None:
            max_elements = expected_elements
        max_elements = _integer(max_elements, "Maximum binary elements")
        dtype = {"int8": np.dtype("i1"), "uint16": np.dtype("<u2")}.get(datatype)
        require(dtype is not None, "Only int8 and little-endian uint16 transfers are supported.")
        old_termination = self.device.read_termination
        try:
            # Disables VISA termchar recognition even if an LF is in binary data.
            self.device.read_termination = None
            self.send(command)
            require(
                self._read_exact(1) == b"#", "Expected IEEE488.2 # header; reconnect after protocol error."
            )
            digit = self._read_exact(1)
            require(b"1" <= digit <= b"9", "A definite-length IEEE488.2 block is required.")
            length_text = self._read_exact(int(digit))
            require(length_text.isdigit(), "Invalid IEEE488.2 length field.")
            count = int(length_text)
            require(
                count % dtype.itemsize == 0 and count <= max_elements * dtype.itemsize,
                f"Announced binary size {count} is incompatible with the requested transfer.",
            )
            payload = self._read_exact(count)
            ending = self._read_exact(1)
            if ending == b"\r":
                ending = self._read_exact(1)
            require(ending == b"\n", "Expected LF or CR/LF after binary payload.")
            values = np.frombuffer(payload, dtype=dtype).copy()
            require(
                expected_elements is None or values.size == expected_elements,
                f"Received {values.size} samples; expected {expected_elements}.",
            )
            return values
        except Exception as exc:
            raise RuntimeError(f"VISA binary read failed on {self.address}: {command}: {exc}") from exc
        finally:
            self.device.read_termination = old_termination

    def close(self):
        if self.closed:
            return
        self.closed = True
        device, self.device = self.device, None
        if device is not None:
            device.close()


class Rig:
    """A successful upload belongs to this live connection session only."""

    def __init__(self, awg, scope, config, manager=None, owns_manager=False):
        self.awg, self.scope = awg, scope
        self.config = deepcopy(config)
        self.manager, self.owns_manager = manager, owns_manager
        self.session_id = uuid.uuid4().hex
        self.last_transmission = None
        self.connected, self.busy = True, False
        self.idn, self.connection_errors = {}, {}

    @contextmanager
    def operation(self):
        require(self.connected, "Connect the instruments before this operation.")
        require(not self.busy, "Wait for the current instrument operation to finish.")
        self.busy = True
        try:
            yield
        finally:
            self.busy = False

    def check(self, experiment):
        return check(self, experiment)

    def transmit(self, experiment, folder=None, backup_dir=None):
        return transmit(self, experiment, folder, backup_dir)

    def capture(self, experiment):
        return capture(self, experiment)

    def stop(self):
        return stop(self)

    def disconnect(self):
        return disconnect(self)

    def scope_settings(self):
        with self.operation():
            return read_scope_settings(self.scope, int(self.config.get("scope_channel", 1)))

    def recover(self):
        """Device clear of the oscilloscope after a VISA error: a late reply would shift the next ones."""
        try:
            self.scope.device.clear()
            scpi_errors(self.scope, "recovering the oscilloscope", fail_on_error=False)
        except Exception as exc:
            warnings.warn(f"Oscilloscope device clear failed: {exc}")

    def close(self):
        self.last_transmission = None
        self.connected, self.busy = False, False
        for device in (self.awg, self.scope):
            try:
                device.close()
            except Exception as exc:
                warnings.warn(f"VISA close failed: {exc}")
        if self.owns_manager and self.manager is not None:
            try:
                self.manager.close()
            finally:
                self.manager = None


def scpi_errors(device, stage, fail_on_error=True):
    messages = []
    for _ in range(32):
        reply = device.query(":SYSTem:ERRor?")
        match = re.match(r"^\s*([+-]?\d+)", reply)
        require(match is not None, f"Invalid error response during {stage}: {reply}")
        if int(match.group(1)) == 0:
            if messages and fail_on_error:
                raise RuntimeError(f"Instrument error during {stage}: {' | '.join(messages)}")
            return messages
        messages.append(reply)
    raise RuntimeError(f"Instrument error queue did not end during {stage}: {' | '.join(messages)}")


def read_scope_settings(scope, channel=1):
    """Oscilloscope settings (vertical scale, offset, coupling, impedance, BW limit, acquisition, timebase,
    trigger). Read only: a failed query is recorded as text and the error queue is emptied afterwards."""
    out = {"channel": channel}
    for key, command in SCOPE_SETTING_QUERIES.items():
        try:
            value = scope.query(command.format(ch=channel)).strip()
        except Exception as exc:
            out[key] = f"not read ({exc})"
            continue
        try:
            value = float(value)
        except ValueError:
            pass
        out[key] = bool(value) if key in ("ch_bw_limit", "ch_invert") and isinstance(value, float) else value
    scpi_errors(scope, "reading the oscilloscope settings", fail_on_error=False)
    return out


def add_keysight_dll_dir(folder):
    """Lets VISA find the Keysight IO Libraries DLLs (lab PC: VI_ERROR_LIBRARY_NFOUND without it).

    Same effect as the former START_ICS_KEYSIGHT_FIX.cmd, for this Python process only."""
    if folder and os.name == "nt" and os.path.isdir(folder) and folder not in _DLL_DIRS:
        _DLL_DIRS[folder] = os.add_dll_directory(folder)


def open_resource_manager(cfg):
    add_keysight_dll_dir(cfg.get("keysight_dll_dir", ""))
    try:
        import pyvisa
    except ImportError as exc:
        raise RuntimeError(
            "Install PyVISA and keep Keysight IO Libraries installed; see requirements.txt."
        ) from exc
    return pyvisa.ResourceManager(cfg.get("visa_library", "@ivi"))


def connect(config, resource_manager=None):
    """Open and identify both instruments. Never resets or enables outputs."""
    cfg = deepcopy(config)
    addresses = [cfg["awg_address"], cfg["scope_address"]]
    for address in addresses:
        require(
            isinstance(address, str)
            and address.strip()
            and not any(
                marker in address.upper() for marker in ("EDIT_", "YOUR_", "<", "VISA-TCPIP-", "VISA-USB-")
            ),
            "Enter complete VISA resource addresses, not MATLAB display names.",
        )
    require(
        addresses[0].strip().upper() != addresses[1].strip().upper(), "AWG and scope addresses must differ."
    )
    owns_manager = resource_manager is None
    if owns_manager:
        resource_manager = open_resource_manager(cfg)
    awg = scope = None
    try:
        awg = Transport(resource_manager.open_resource(addresses[0]), addresses[0], cfg["awg_timeout_s"])
        scope = Transport(resource_manager.open_resource(addresses[1]), addresses[1], cfg["scope_timeout_s"])
        awg_id, scope_id = awg.query("*IDN?"), scope.query("*IDN?")
        require("M8195A" in awg_id.upper(), f"AWG address reports {awg_id}.")
        require(
            "MSOX4154A" in re.sub("[^A-Z0-9]", "", scope_id.upper()), f"Scope address reports {scope_id}."
        )
        rig = Rig(awg, scope, cfg, resource_manager, owns_manager)
        rig.idn = {"awg": awg_id, "scope": scope_id}
        rig.connection_errors = {
            "awg": scpi_errors(awg, "opening AWG connection", False),
            "scope": scpi_errors(scope, "opening scope connection", False),
        }
        for name, errors in rig.connection_errors.items():
            if errors:
                print(f"Existing {name} errors recorded: {' | '.join(errors)}")
        print(f"AWG connected: {awg_id}\nScope connected: {scope_id}")
        print("No reset, upload, output change or scope acquisition was requested.")
        return rig
    except BaseException:
        for device in (awg, scope):
            if device is not None:
                try:
                    device.close()
                except Exception:
                    pass
        if owns_manager:
            resource_manager.close()
        raise


def _number(device, command):
    return numbers(device.query(command), 1)


def awg_snapshot(device):
    s = {"idn": device.query("*IDN?")}
    require("M8195A" in s["idn"].upper(), f"Expected M8195A; received {s['idn']}.")
    for key, command in [
        ("options", "*OPT?"),
        ("functionMode", ":FUNCtion:MODE?"),
        ("dacMode", ":INSTrument:DACMode?"),
        ("divider", ":INSTrument:MEMory:EXTended:RDIVider?"),
        ("referenceClock", ":ROSCillator:SOURce?"),
    ]:
        s[key] = device.query(command)
    s.update(
        rasterRate=_number(device, ":FREQuency:RASTer?"),
        Vpp=_number(device, ":VOLTage1:AMPLitude?"),
        offset=_number(device, ":VOLTage1:OFFSet?"),
        outputs=[],
        memoryModes=[],
        catalogs=[],
        freeMemory=np.full((4, 3), np.nan),
        extChannels=[],
    )
    for ch in range(1, 5):
        s["outputs"].append(_number(device, f":OUTPut{ch}?"))
        mode = device.query(f":TRACe{ch}:MMODe?")
        s["memoryModes"].append(mode)
        catalog = []
        if mode.upper().startswith("EXT"):
            values = numbers(device.query(f":TRACe{ch}:CATalog?"))
            require(
                values.size % 2 == 0 and np.all(values >= 0) and np.all(values == np.floor(values)),
                f"Invalid waveform catalogue for channel {ch}.",
            )
            catalog = [[int(a), int(b)] for a, b in values.reshape(-1, 2) if a > 0]
            mem = numbers(device.query(f":TRACe{ch}:FREE?"), 3)
            require(
                np.all(mem >= 0) and np.all(mem == np.floor(mem)), f"Invalid memory reply for channel {ch}."
            )
            s["freeMemory"][ch - 1] = mem
            s["extChannels"].append(ch)
        s["catalogs"].append(catalog)
    scpi_errors(device, "reading AWG configuration")
    return s


def _profile(s, cfg):
    mode = (
        s["dacMode"].upper().startswith("FOUR")
        and s["divider"].upper() == "DIV4"
        and s["memoryModes"][0].upper().startswith("EXT")
        and abs(s["rasterRate"] / 4 - cfg["awg_sample_rate_hz"]) <= 1
    )
    voltage = abs(s["Vpp"] - cfg["awg_vpp"]) <= 1e-6 and abs(s["offset"] - cfg.get("awg_offset_v", 0)) <= 1e-6
    return mode, voltage, all(v == 0 for v in s["outputs"][1:])


def check(rig, experiment):
    validate_experiment(experiment)
    with rig.operation():
        report = awg_snapshot(rig.awg)
        cfg, plan = experiment["config"], experiment["plan"]
        report["modeReady"], report["voltageReady"], report["otherOutputsOff"] = _profile(report, cfg)
        report["requiredWaveformBytes"] = plan["waveformBytes"]
        report["contiguousFreeBytes"] = report["freeMemory"][0, 2]
        report["fitsCurrentFreeMemory"] = bool(
            np.isfinite(report["contiguousFreeBytes"])
            and report["contiguousFreeBytes"] >= plan["waveformBytes"]
        )
        report["scopeIdn"] = rig.scope.query("*IDN?")
        report["scopeTimebase_sPerDiv"] = _number(rig.scope, ":TIMebase:SCALe?")
        scpi_errors(rig.scope, "reading scope timebase")
        report["minimumCaptureDuration_s"] = plan["minimumCaptureDuration_s"]
        report["minimumReturnedSampleRate_Hz"] = cfg["scope_min_sample_rate_hz"]
        report["ready"] = all(
            report[key] for key in ("modeReady", "voltageReady", "otherOutputsOff", "fitsCurrentFreeMemory")
        )
        print(
            f"Mode ready: {report['modeReady']}; voltage ready: {report['voltageReady']}; other outputs off: {report['otherOutputsOff']}."
        )
        print(
            f"Free contiguous memory: {report['contiguousFreeBytes']/1e6:.3f} MB; required {plan['waveformBytes']/1e6:.3f} MB."
        )
        print(
            f"Scope currently {1000*report['scopeTimebase_sPerDiv']:.6g} ms/div; capture setting {cfg.get('scope_timebase_s_per_div')} s/div."
        )
        print("SEQ is not required; no waveform has been uploaded or started.")
        return report


def arb_chunk(tone, frame, plan, offset, count):
    offset = _integer(offset, "Offset", 0)
    count = _integer(count, "Chunk size")
    tone, frame = np.asarray(tone), np.asarray(frame)
    require(
        tone.dtype == np.int8 and frame.dtype == np.int8 and tone.ndim == frame.ndim == 1,
        "Tiles must be int8 vectors.",
    )
    require(
        tone.size == plan["toneTileSamplesAWG"]
        and frame.size == plan["ofdmFrameSamplesAWG"]
        and plan["toneSamplesAWG"] == tone.size * plan["toneTotalRepeats"]
        and plan["totalSamplesAWG"] == plan["toneSamplesAWG"] + frame.size * plan["communicationFrames"],
        "Tiles disagree with plan.",
    )
    require(offset + count <= plan["totalSamplesAWG"], "Chunk exceeds allocated record.")
    out = np.empty(count, dtype=np.int8)
    nt = max(0, min(count, int(plan["toneSamplesAWG"]) - offset))
    if nt:
        out[:nt] = tone[(offset + np.arange(nt)) % tone.size]
    if count > nt:
        start = offset + nt - int(plan["toneSamplesAWG"])
        out[nt:] = frame[(start + np.arange(count - nt)) % frame.size]
    return out


def _settings_unchanged(a, b):
    require(
        abs(a["Vpp"] - b["Vpp"]) <= 1e-6
        and abs(a["offset"] - b["offset"]) <= 1e-6
        and abs(a["rasterRate"] - b["rasterRate"]) <= 1
        and all(a[k] == b[k] for k in ("dacMode", "divider", "referenceClock", "memoryModes"))
        and all(x == 0 for x in b["outputs"][1:]),
        "AWG settings changed during upload.",
    )


def _backup_existing(device, channels, catalog, previous, experiment, chunk_size, folder):
    backup = {"folder": "", "records": []}
    if not catalog:
        return backup
    folder = Path(folder) / datetime.now().strftime("%Y%m%d-%H%M%S")
    folder.mkdir(parents=True, exist_ok=False)
    backup["folder"] = str(folder)
    segment, total = catalog[0]
    for ch in channels:
        path = folder / f"channel{ch}_segment{segment}_int8.bin"
        with path.open("wb") as stream:
            for offset in range(0, total, chunk_size):
                count = min(chunk_size, total - offset)
                data = device.read_block(
                    f":TRACe{ch}:DATA:BLOCk? {segment},{offset},{count}", "int8", count, count
                )
                require(stream.write(data.tobytes()) == count, "Incomplete waveform backup write.")
                scpi_errors(device, "reading previous EXT samples for backup")
        require(path.stat().st_size == total, "Waveform backup size mismatch.")
        backup["records"].append({"channel": ch, "segment": segment, "samples": total, "path": str(path)})
    save_record(
        folder / "backup_metadata.npz", {"backup": backup, "previous": previous, "experiment": experiment}
    )
    return backup


def _spot_offsets(plan, extra=0):
    """Start offsets of the 128-sample blocks read back (tone/OFDM boundaries + `extra` evenly spaced)."""
    total = int(plan["totalSamplesAWG"])
    offsets = {
        0,
        int(plan["toneSamplesAWG"]) - 128,
        int(plan["toneSamplesAWG"]),
        int(plan["toneSamplesAWG"] + plan["ofdmFrameSamplesAWG"]) - 128,
        int(plan["toneSamplesAWG"] + plan["ofdmFrameSamplesAWG"]),
        total - 128,
    }
    if extra:
        offsets |= {int(o) // 128 * 128 for o in np.linspace(0, total - 128, extra)}
    # A one-frame communication slot has no second frame to inspect.
    return [o for o in sorted(offsets) if 0 <= o <= total - 128]


def _readback(device, tone, frame, plan, segment, offsets):
    """[(offset, expected, actual)] of 128-sample blocks (AWG stopped: reads are refused while playing)."""
    out = []
    for offset in offsets:
        expected = arb_chunk(tone, frame, plan, offset, 128)
        actual = numbers(device.query(f":TRACe1:DATA? {segment},{offset},128"), 128)
        out.append((offset, expected, actual))
    return out


def transmit(rig, experiment, folder=None, backup_dir=None):
    """Load (or reuse), verify while stopped, and start one repeating combined record.

    If the AWG already holds a record of the planned length whose read-back blocks equal this waveform, it is
    reused (no backup, no upload). Otherwise a different existing record is backed up to `backup_dir`
    (default folder/awg_backup) and the new one is uploaded. The transmission metadata is saved to
    folder/transmission.npz."""
    validate_experiment(experiment)
    from .modem import awg_frame

    with rig.operation():
        rig.last_transmission = None
        cfg, core, packet, plan = (experiment[k] for k in ("config", "cfg", "packet", "plan"))
        require(
            all(
                str(cfg[k]).strip().upper() == str(rig.config[k]).strip().upper()
                for k in ("awg_address", "scope_address")
            ),
            "Instrument addresses changed; reconnect first.",
        )
        require(cfg.get("awg_channel", 1) == 1, "This profile uses AWG channel 1.")
        started = False
        backup = {"folder": "", "records": []}
        try:
            scpi_errors(rig.awg, "before upload preparation")
            previous = awg_snapshot(rig.awg)
            mode, voltage, outputs = _profile(previous, cfg)
            require(mode, "Use FOUR, DIV4, CH1 EXT and 16 GSa/s waveform rate.")
            require(voltage, f"Set AWG to {cfg['awg_vpp']} Vpp and {cfg.get('awg_offset_v',0)} V offset.")
            require(outputs, "Turn AWG outputs 2, 3 and 4 off.")
            catalog, channels = previous["catalogs"][0], previous["extChannels"]
            require(len(catalog) <= 1, "Multiple EXT segments exist; uploader will not replace this setup.")
            for ch in channels:
                require(
                    previous["catalogs"][ch - 1] == catalog, "Shared EXT catalogues differ between channels."
                )
            chunk_size = _integer(cfg["upload_chunk_samples"], "Upload chunk samples", 640)
            require(chunk_size % 128 == 0, "Upload chunk must be a multiple of 128 samples.")
            frame = awg_frame(packet)
            require(
                frame.dtype == np.int8 and frame.size == plan["ofdmFrameSamplesAWG"],
                "OFDM waveform length/type changed.",
            )
            values = 127 * np.sin(
                2
                * np.pi
                * core["toneFrequencyHz"]
                / core["FsAWG"]
                * np.arange(int(plan["toneTileSamplesAWG"]))
            )
            tone = (np.sign(values) * np.floor(np.abs(values) + 0.5)).astype(np.int8)
            segment = catalog[0][0] if catalog else 1
            total = int(plan["totalSamplesAWG"])
            started = True
            rig.awg.send(":ABORt")
            require(_number(rig.awg, "*OPC?") == 1, "AWG did not complete stop command.")
            scpi_errors(rig.awg, "stopping before readback")
            reused = catalog == [[segment, total]] and all(
                np.array_equal(actual, expected)
                for _, expected, actual in _readback(
                    rig.awg, tone, frame, plan, segment, _spot_offsets(plan, REUSE_CHECK_BLOCKS)
                )
            )
            scpi_errors(rig.awg, "reading back the loaded record")
            if reused:
                print(
                    f"The AWG already holds this waveform (segment {segment}, {total} samples): reused, "
                    f"no backup and no upload."
                )
            else:
                for ch in channels:
                    require(
                        previous["freeMemory"][ch - 1, 2] >= plan["waveformBytes"],
                        "Insufficient contiguous AWG memory.",
                    )
                require(
                    not catalog or cfg.get("backup_existing", True),
                    "Existing EXT data must be backed up before replacement.",
                )
                print(
                    f"Uploading {plan['waveformBytes']/1e6:.3f} MB; cycle {plan['cycleDuration_s']*1000:.6f} ms."
                )
                backup_dir = backup_dir or (Path(folder) / "awg_backup" if folder is not None else None)
                require(not catalog or backup_dir is not None, "Give a folder to back up the waveform in the AWG.")
                backup = _backup_existing(
                    rig.awg, channels, catalog, previous, experiment, chunk_size, backup_dir
                )
                if catalog:
                    print(f"A different waveform was in the AWG; backup: {backup['folder']}")
                    rig.awg.send(f":TRACe1:DELete {segment}")
                    scpi_errors(rig.awg, "replacing backed-up record")
                rig.awg.send(f":TRACe1:DEFine {segment},{total}")
                scpi_errors(rig.awg, "allocating combined record")
                last_progress = -1
                for offset in range(0, total, chunk_size):
                    count = min(chunk_size, total - offset)
                    rig.awg.write_block(
                        f":TRACe1:DATA {segment},{offset},", arb_chunk(tone, frame, plan, offset, count)
                    )
                    scpi_errors(rig.awg, f"upload at sample {offset}")
                    progress = min(100, 10 * int(10 * (offset + count) / total))
                    if progress > last_progress:
                        print(f"Waveform upload: {progress}%")
                        last_progress = progress
                require(_number(rig.awg, "*OPC?") == 1, "AWG upload did not complete.")
                after = awg_snapshot(rig.awg)
                require(
                    all(after["catalogs"][ch - 1] == [[segment, total]] for ch in channels),
                    "Allocated waveform length differs from plan.",
                )
            offsets = _spot_offsets(plan)
            spots = []
            for offset, expected, actual in _readback(rig.awg, tone, frame, plan, segment, offsets):
                require(
                    np.array_equal(actual, expected),
                    f"Readback mismatch at {offset}; playback remains stopped.",
                )
                spots.append(expected)
            for command in [
                ":FUNCtion:MODE ARB",
                f":TRACe1:SELect {segment}",
                ":INITiate:CONTinuous 1",
                ":INITiate:CONTinuous:ENABle SELF",
                ":INITiate:GATE 0",
            ]:
                rig.awg.send(command)
            scpi_errors(rig.awg, "selecting continuous ARB playback")
            require(
                rig.awg.query(":FUNCtion:MODE?").upper().startswith("ARB")
                and _number(rig.awg, ":TRACe1:SELect?") == segment
                and _number(rig.awg, ":INITiate:CONTinuous?") == 1
                and rig.awg.query(":INITiate:CONTinuous:ENABle?").upper() == "SELF"
                and _number(rig.awg, ":INITiate:GATE?") == 0,
                "AWG continuous/self readback failed.",
            )
            _settings_unchanged(previous, awg_snapshot(rig.awg))
            rig.awg.send(":OUTPut1 ON")
            require(_number(rig.awg, ":OUTPut1?") == 1, "AWG output 1 did not enable.")
            scpi_errors(rig.awg, "enabling output")
            rig.awg.send(":INITiate:IMMediate")
            require(_number(rig.awg, "*OPC?") == 1, "AWG start did not complete.")
            scpi_errors(rig.awg, "starting combined waveform")
            tx = dict(
                signature=experiment["signature"],
                sessionId=rig.session_id,
                idn=previous["idn"],
                address=cfg["awg_address"],
                channel=1,
                segment=segment,
                sampleRate=core["FsAWG"],
                Vpp=previous["Vpp"],
                offset=previous["offset"],
                rasterRate=previous["rasterRate"],
                divider=previous["divider"],
                memoryMode=previous["memoryModes"][0],
                totalSamples=plan["totalSamplesAWG"],
                waveformBytes=plan["waveformBytes"],
                plan=plan,
                backup=backup,
                previousSettings=previous,
                spotOffsets=offsets,
                spotData=spots,
                reused=reused,
                transmittedAt=now_iso(),
                savedPath="",
                playbackMethod="Single repeating ARB; no SEQ",
                status="AWG start accepted; receiver capture must verify the optical signal.",
            )
            if folder is not None:
                path = Path(folder) / "transmission.npz"
                tx["savedPath"] = str(path)
                save_record(path, {"tx": tx, "experiment": experiment})
            rig.last_transmission = deepcopy(tx)
            print(f"AWG start accepted at {tx['Vpp']:.3f} Vpp.")
            return tx
        except BaseException:
            rig.last_transmission = None
            if started:
                for command in (":ABORt", ":OUTPut1 OFF"):
                    try:
                        rig.awg.send(command)
                    except Exception:
                        pass
                print("Transmit failed; AWG stop/output-off was requested.")
                if backup["folder"]:
                    print(f"Existing waveform backup: {backup['folder']}")
            raise


def _verify_playback(device, tx, cfg):
    # No DATA?/DATA:BLOCk?: M8195A sample reads only work when STOPPED.
    require(device.query("*IDN?") == tx["idn"], "AWG identity changed since upload.")
    require(
        device.query(":FUNCtion:MODE?").upper().startswith("ARB")
        and _number(device, ":TRACe1:SELect?") == tx["segment"]
        and _number(device, ":OUTPut1?") == 1,
        "Uploaded ARB record is not selected with output enabled.",
    )
    require(
        device.query(":INSTrument:DACMode?").upper().startswith("FOUR")
        and device.query(":INSTrument:MEMory:EXTended:RDIVider?").upper() == "DIV4"
        and device.query(":TRACe1:MMODe?").upper().startswith("EXT")
        and abs(_number(device, ":FREQuency:RASTer?") / 4 - cfg["awg_sample_rate_hz"]) <= 1
        and abs(_number(device, ":VOLTage1:AMPLitude?") - cfg["awg_vpp"]) <= 1e-6
        and abs(_number(device, ":VOLTage1:OFFSet?") - cfg.get("awg_offset_v", 0)) <= 1e-6,
        "AWG mode, sample rate or voltage changed since upload.",
    )
    require(
        device.query(":ROSCillator:SOURce?").strip().upper()
        == tx["previousSettings"]["referenceClock"].strip().upper(),
        "AWG reference clock changed since upload; restore it and transmit again.",
    )
    require(
        _number(device, ":INITiate:CONTinuous?") == 1
        and device.query(":INITiate:CONTinuous:ENABle?").upper() == "SELF"
        and _number(device, ":INITiate:GATE?") == 0,
        "AWG continuous/self configuration changed.",
    )
    require(
        all(_number(device, f":OUTPut{ch}?") == 0 for ch in (2, 3, 4)), "Other AWG outputs must remain off."
    )
    require(
        np.array_equal(numbers(device.query(":TRACe1:CATalog?"), 2), [tx["segment"], tx["totalSamples"]]),
        "AWG waveform allocation changed since upload.",
    )
    scpi_errors(device, "verifying active transmit settings")


def capture(rig, experiment):
    """Acquire one fresh scope record (volts + raw WORD codes); invalid rate/span is flagged, not raised."""
    validate_experiment(experiment)
    with rig.operation():
        tx = rig.last_transmission
        require(isinstance(tx, dict), "Run transmit(rig,experiment) successfully before capture.")
        require(
            tx["signature"] == experiment["signature"] and tx["sessionId"] == rig.session_id,
            "Prepared experiment or connection differs from upload; prepare and transmit again.",
        )
        cfg = experiment["config"]
        try:
            _verify_playback(rig.awg, tx, cfg)
        except BaseException:
            rig.last_transmission = None
            raise
        scope = rig.scope
        channel = _integer(cfg.get("scope_channel", 1), "Scope channel")
        require(channel <= 4, "Scope channel must be 1 through 4.")
        requested = _integer(cfg["scope_requested_points"], "Requested scope points", 2)
        scpi_errors(scope, "before scope capture")
        idn = scope.query("*IDN?")
        require("MSOX4154A" in re.sub("[^A-Z0-9]", "", idn.upper()), f"Unexpected scope: {idn}")
        require(scope.query(":TIMebase:MODE?").upper().startswith("MAIN"), "Use scope MAIN timebase.")
        scale = cfg.get("scope_timebase_s_per_div")
        if scale is not None:
            require(np.isfinite(scale) and scale > 0, "Scope timebase must be positive.")
            scope.send(f":TIMebase:SCALe {scale:.15g}")
            scpi_errors(scope, "applying configured scope timebase")
        timebase = _number(scope, ":TIMebase:SCALe?")
        scope.send(f":WAVeform:SOURce CHANnel{channel}")
        scope.send(":ACQuire:TYPE NORMal")
        scpi_errors(scope, "selecting normal scope acquisition")
        scope.send(f":DIGitize CHANnel{channel}")
        require(_number(scope, "*OPC?") == 1, "Scope acquisition did not finish; inspect trigger/timebase.")
        scpi_errors(scope, "acquiring fresh scope record")
        for command in [
            f":WAVeform:SOURce CHANnel{channel}",
            ":WAVeform:POINts:MODE RAW",
            f":WAVeform:POINts {requested}",
            ":WAVeform:FORMat WORD",
            ":WAVeform:BYTeorder LSBFirst",
            ":WAVeform:UNSigned 1",
        ]:
            scope.send(command)
        scpi_errors(scope, "configuring scope waveform transfer")
        require(
            scope.query(":WAVeform:FORMat?").upper().startswith("WORD")
            and scope.query(":WAVeform:BYTeorder?").upper().startswith("LSB")
            and _number(scope, ":WAVeform:UNSigned?") == 1,
            "Scope did not accept unsigned little-endian WORD transfer.",
        )
        text = scope.query(":WAVeform:PREamble?")
        p = numbers(text, 10)
        require(p[0] == 1 and p[1] == 0, "Expected normal acquisition/WORD preamble.")
        count = _integer(p[2], "Returned scope points", 2)
        require(
            count <= requested and p[4] > 0 and p[7] > 0, "Invalid scope point count or scale increments."
        )
        fs = 1 / p[4]
        raw = scope.read_block(":WAVeform:DATA?", "uint16", count, requested)
        scpi_errors(scope, "reading raw scope waveform")
        require(
            not np.any((raw == 0) | (raw >= 65534)),
            "Scope returned boundary/overrange codes; inspect vertical scale.",
        )
        y = (raw.astype(float) - p[9]) * p[7] + p[8]
        t = (np.arange(count) - p[6]) * p[4] + p[5]
        require(np.all(np.isfinite(y)), "Converted voltage samples are nonfinite.")
        names = [
            "Format",
            "Type",
            "Points",
            "Count",
            "XIncrement",
            "XOrigin",
            "XReference",
            "YIncrement",
            "YOrigin",
            "YReference",
        ]
        record = dict(
            YData=y,
            XData=t,
            codes=raw,
            FsCapture=fs,
            XIncrement=p[4],
            preamble=dict(zip(names, p)),
            preambleText=text,
            idn=idn,
            channel=channel,
            requestedPoints=requested,
            actualPoints=count,
            durationSeconds=(count - 1) / fs,
            peakToPeakVolts=float(np.ptp(y)),
            timebase_sPerDiv=timebase,
            capturedAt=now_iso(),
            experimentSignature=experiment["signature"],
            txMetadata=deepcopy(tx),
            validForProcessing=False,
            validationError="",
            status="Fresh normal acquisition; scope remains stopped.",
        )
        if fs < cfg["scope_min_sample_rate_hz"] * (1 - 1e-9):
            record["validationError"] = (
                f"Returned rate {fs/1e6:.6g} MSa/s is below {cfg['scope_min_sample_rate_hz']/1e6:.6g} MSa/s."
            )
        elif record["durationSeconds"] < experiment["plan"]["minimumCaptureDuration_s"]:
            record["validationError"] = (
                f"Returned span {record['durationSeconds']*1000:.6g} ms is below required {experiment['plan']['minimumCaptureDuration_s']*1000:.6g} ms."
            )
        else:
            record["validForProcessing"] = True
        print(f"Scope record: {count} samples, {fs/1e6:.6g} MSa/s, {record['durationSeconds']*1000:.6g} ms.")
        if not record["validForProcessing"]:
            warnings.warn(
                record["validationError"] + " Raw record kept for diagnosis; do not decode as valid."
            )
        return record


def stop(rig):
    rig.last_transmission = None
    with rig.operation():
        rig.awg.send(":ABORt")
        rig.awg.send(":OUTPut1 OFF")
        require(
            _number(rig.awg, "*OPC?") == 1 and _number(rig.awg, ":OUTPut1?") == 0,
            "AWG did not confirm output 1 off.",
        )
        scpi_errors(rig.awg, "stopping generation")
        print("AWG playback stopped; channel 1 output off.")


def disconnect(rig):
    if not rig.connected:
        return
    require(not rig.busy, "Wait for current operation before disconnecting.")
    error = None
    try:
        stop(rig)
    except Exception as exc:
        error = exc
    finally:
        rig.close()
    if error is not None:
        warnings.warn(f"Connections closed but AWG output-off unconfirmed: {error}. Check AWG control panel.")
    else:
        print("This program's AWG and scope connections are closed.")
