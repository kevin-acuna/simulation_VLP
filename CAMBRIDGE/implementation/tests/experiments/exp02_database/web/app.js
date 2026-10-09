/* Database Acquisition Tool (exp02) - interfaz. Solo muestra el estado y envia comandos;
   todo el control y el guardado estan en Python (engine.py). */
"use strict";

const $ = (id) => document.getElementById(id);
const BUSY = ["RUNNING", "PAUSED", "STOPPING"];
const STATE_TEXT = { IDLE: "Idle", RUNNING: "Running", PAUSED: "Paused", STOPPING: "Stopping",
  FINISHED: "Finished", STOPPED: "Stopped", CONNECTING: "Connecting" };
const PHASE_TEXT = { MOVING: "moving", SETTLING: "settling", MEASURING: "measuring" };
const COL = {
  grid: "#e4e7eb", frame: "#a9b1bb", text: "#5f6b7a", ink: "#1f2933",
  pending: "#9aa4b1", done: "#2ca02c", doneEdge: "#1e7a1e", partial: "#b9dfb3",
  target: "#ff7f0e", pd: "#1f77b4", trail: "rgba(31,119,180,0.55)",
  x: "#d62728", y: "#2ca02c", z: "#1f77b4", line: "#1f77b4", marker: "#e6550d",
};

const S = {
  state: "CONNECTING", phase: "", message: "", error: null,
  plan: null, planVersion: -1, planMsgs: { errors: [], warnings: [] },
  config: null, defaults: null, workspace: null, viewCfg: {}, modes: {}, scope: {}, mtrs: {},
  sites: [], cells: [], done: [], doneBySite: new Map(),
  progress: {}, tel: null, target: null, fft: null, fftDirty: false, fftYmax: 0,
  log: [], trail: [], sessionDir: null,
  connected: false, locked: false, planOk: false, formDirty: false,
  view: localStorage.getItem("exp02.view") || "top", dirty: true,
};
const cam = { yaw: 30, elev: 28, zoom: 1 };

/* ============================================================
   utilidades
   ============================================================ */
const fmtG = (v) => String(+(+v).toPrecision(6));
const freqLabel = (khz) => `${fmtG(khz)}kHz`;
const num = (id) => parseFloat($(id).value);
const fmt = (v, d = 1) => (v === null || v === undefined || !isFinite(v) ? "–" : (+v).toFixed(d));
function fmtDur(s) {
  if (s === null || s === undefined || !isFinite(s)) return "–";
  s = Math.max(0, Math.round(s));
  if (s < 60) return `${s} s`;
  if (s < 3600) return `${Math.floor(s / 60)} min ${s % 60} s`;
  if (s < 86400) return `${Math.floor(s / 3600)} h ${Math.round((s % 3600) / 60)} min`;
  return `${(s / 86400).toFixed(1)} days`;
}
function fmtBytes(b) {
  if (!isFinite(b)) return "–";
  if (b < 1e6) return `${(b / 1e3).toFixed(0)} kB`;
  if (b < 1e9) return `${(b / 1e6).toFixed(1)} MB`;
  return `${(b / 1e9).toFixed(2)} GB`;
}
function fmtRss(v, units) {
  if (v === null || v === undefined || !isFinite(v)) return "–";
  return units === "dB" ? `${v.toFixed(2)} dB` : `${(v * 1e3).toFixed(3)} mV`;
}
const clock = (sec) => new Date(Date.now() + sec * 1000).toLocaleString([], { weekday: sec > 86400 ? "short" : undefined, hour: "2-digit", minute: "2-digit" });
function axisCount(a, b, s) {
  if (!isFinite(a) || !isFinite(b)) return NaN;
  if (Math.abs(b - a) < 1e-9) return 1;
  if (!(Math.abs(s) > 0)) return NaN;
  return Math.floor(Math.abs(b - a) / Math.abs(s) + 1e-9) + 1;
}
function viridis(t) {
  const c = [[68, 1, 84], [59, 82, 139], [33, 145, 140], [94, 201, 98], [253, 231, 37]];
  t = Math.min(1, Math.max(0, t)) * (c.length - 1);
  const i = Math.min(c.length - 2, Math.floor(t)), f = t - i;
  const m = c[i].map((v, k) => Math.round(v + (c[i + 1][k] - v) * f));
  return `rgb(${m[0]},${m[1]},${m[2]})`;
}
function niceStep(range, n) {
  const raw = range / n, p = 10 ** Math.floor(Math.log10(raw)), r = raw / p;
  return (r < 1.5 ? 1 : r < 3 ? 2 : r < 7 ? 5 : 10) * p;
}
function minStep(vals) {
  const u = [...new Set(vals)].sort((a, b) => a - b);
  let m = Infinity;
  for (let i = 1; i < u.length; i++) m = Math.min(m, u[i] - u[i - 1]);
  return isFinite(m) ? m : 200;
}
async function post(url, body) {
  const r = await fetch(url, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body || {}) });
  const data = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(data.error || `HTTP ${r.status}`);
  return data;
}
function confirmModal(title, text, okLabel = "OK", okClass = "primary") {
  return new Promise((resolve) => {
    $("modalTitle").textContent = title;
    $("modalText").textContent = text;
    const ok = $("modalOk"), cancel = $("modalCancel");
    ok.textContent = okLabel;
    ok.className = `btn ${okClass}`;
    $("modal").classList.add("show");
    const close = (v) => { $("modal").classList.remove("show"); ok.onclick = cancel.onclick = null; resolve(v); };
    ok.onclick = () => close(true);
    cancel.onclick = () => close(false);
  });
}
function fitCanvas(cv) {
  const dpr = window.devicePixelRatio || 1, w = cv.clientWidth, h = cv.clientHeight;
  if (cv.width !== Math.round(w * dpr) || cv.height !== Math.round(h * dpr)) {
    cv.width = Math.round(w * dpr); cv.height = Math.round(h * dpr);
  }
  const ctx = cv.getContext("2d");
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  return { ctx, w, h, dpr };
}
const invalidate = () => { S.dirty = true; };

/* ============================================================
   panel de configuracion (plegable) y pestañas de vista
   ============================================================ */
function setConfigOpen(open) {
  $("body").classList.toggle("cfg-open", open);
  $("btnConfig").setAttribute("aria-expanded", String(open));
  localStorage.setItem("exp02.cfgOpen", open ? "1" : "0");
  S.fftDirty = true; invalidate();
}
$("btnConfig").onclick = () => setConfigOpen(!$("body").classList.contains("cfg-open"));
setConfigOpen(localStorage.getItem("exp02.cfgOpen") !== "0");

function setView(v) {
  S.view = v;
  localStorage.setItem("exp02.view", v);
  for (const b of $("viewTabs").querySelectorAll("button")) b.classList.toggle("active", b.dataset.view === v);
  $("viewWrap").classList.toggle("v3d", v === "3d");
  $("map").classList.toggle("orbit", v === "3d");
  $("viewHint").textContent = v === "3d" ? "drag to rotate · wheel to zoom · double-click to reset"
    : "origin at bottom right · X up · Y left";
  $("tooltip").style.display = "none";
  invalidate();
}
for (const b of $("viewTabs").querySelectorAll("button")) b.onclick = () => setView(b.dataset.view);
setView(S.view);
$("zSel").onchange = $("colorSel").onchange = invalidate;

/* ============================================================
   formulario
   ============================================================ */
const INPUT_IDS = ["x0", "x1", "xs", "y0", "y1", "ys", "z0", "z1", "zs", "kAngles", "pdTilt", "nSamples",
  "settle", "freqs", "serpXY", "serpAng", "saveWave", "label"];

function fillForm(c) {
  [["x", "x0", "x1", "xs"], ["y", "y0", "y1", "ys"], ["z", "z0", "z1", "zs"]].forEach(([k, a, b, s]) => {
    $(a).value = c[k][0]; $(b).value = c[k][1]; $(s).value = c[k][2];
  });
  $("kAngles").value = c.k_angles;
  $("pdTilt").value = c.pd_tilt_deg;
  $("nSamples").value = c.n_samples;
  $("settle").value = c.settle_s;
  $("freqs").value = c.freqs_khz.map(fmtG).join(", ");
  $("serpXY").checked = c.serpentine_xy;
  $("serpAng").checked = c.serpentine_angles;
  $("saveWave").checked = c.save_waveforms;
  $("label").value = c.label || "";
  S.formDirty = false;
  updateFormPreview();
}
const parseFreqs = () => $("freqs").value.split(/[,;\s]+/).filter((s) => s.trim() !== "").map(Number);

function readForm() {
  const base = S.config || S.defaults || {};
  return {
    x: [num("x0"), num("x1"), num("xs")], y: [num("y0"), num("y1"), num("ys")], z: [num("z0"), num("z1"), num("zs")],
    k_angles: parseInt($("kAngles").value, 10), pd_tilt_deg: num("pdTilt"),
    n_samples: parseInt($("nSamples").value, 10), settle_s: num("settle"), freqs_khz: parseFreqs(),
    serpentine_xy: $("serpXY").checked, serpentine_angles: $("serpAng").checked,
    save_waveforms: $("saveWave").checked, time_points: base.time_points ?? 100000, label: $("label").value.trim(),
  };
}

function updateFormPreview() {
  const n = [["x0", "x1", "xs", "xn"], ["y0", "y1", "ys", "yn"], ["z0", "z1", "zs", "zn"]].map(([a, b, s, out]) => {
    const c = axisCount(num(a), num(b), num(s));
    $(out).textContent = isFinite(c) ? c : "?";
    return c;
  });
  const k = parseInt($("kAngles").value, 10), pos = n[0] * n[1] * n[2];
  $("gridCount").textContent = isFinite(pos) && k >= 1 ? `${pos.toLocaleString()} positions × ${k} = ${(pos * k).toLocaleString()} measurements` : "";
  if (k >= 1 && k <= 360) {
    const list = Array.from({ length: Math.min(k, 12) }, (_, i) => `${fmtG((360 * i) / k)}°`);
    $("angleList").textContent = list.join(", ") + (k > 12 ? `, … (step ${fmtG(360 / k)}°)` : "");
  } else $("angleList").textContent = "–";
}
const setFormEnabled = (on) => INPUT_IDS.forEach((id) => { $(id).disabled = !on; });
INPUT_IDS.forEach((id) => $(id).addEventListener("input", () => {
  S.formDirty = true; S.planOk = false; updateFormPreview(); updateButtons();
}));

/* ============================================================
   estado recibido de Python
   ============================================================ */
function rebuildPlanIndex() {
  S.sites = []; S.cells = [];
  const p = S.plan;
  if (!p) return;
  const f = p.sites_flat, byXY = new Map();
  for (let i = 0; i < f.length; i += 4) {
    const s = { site_id: i / 4 + 1, x: f[i], y: f[i + 1], z: f[i + 2], iz: f[i + 3] };
    S.sites.push(s);
    const key = `${s.x}|${s.y}`;
    if (!byXY.has(key)) { const c = { x: s.x, y: s.y, sites: [] }; byXY.set(key, c); S.cells.push(c); }
    byXY.get(key).sites.push(s);
  }
  S.stepXY = Math.min(minStep(p.axes.x), minStep(p.axes.y));
  const zSel = $("zSel"), prev = zSel.value;
  zSel.innerHTML = `<option value="all">all (${p.axes.z.length})</option>` +
    p.axes.z.map((z, i) => `<option value="${i}">${fmtG(z)} mm</option>`).join("");
  zSel.value = [...zSel.options].some((o) => o.value === prev) ? prev : "all";
  const cSel = $("colorSel"), prevC = cSel.value;
  cSel.innerHTML = `<option value="status">status</option>` +
    p.config.freqs_khz.map((f) => `<option value="${freqLabel(f)}">RSS ${fmtG(f)} kHz</option>`).join("");
  cSel.value = [...cSel.options].some((o) => o.value === prevC) ? prevC : "status";
}
function addDoneIndex(d) {
  if (!S.doneBySite.has(d.site_id)) S.doneBySite.set(d.site_id, []);
  S.doneBySite.get(d.site_id).push(d);
}

function applyFull(d) {
  const planChanged = d.plan_version !== S.planVersion;
  Object.assign(S, {
    state: d.state, phase: d.phase, message: d.message, error: d.error, plan: d.plan, planVersion: d.plan_version,
    config: d.config, defaults: d.defaults, workspace: d.workspace, viewCfg: d.view || {}, modes: d.modes || {},
    scope: d.scope || {}, mtrs: d.mtrs || {}, progress: d.progress || {}, tel: d.tel, target: d.target,
    sessionDir: d.session_dir,
  });
  if (d.fft) { S.fft = d.fft; S.fftDirty = true; }
  if (planChanged) { rebuildPlanIndex(); S.trail = []; }
  S.done = (d.done || []).slice();
  S.doneBySite = new Map();
  S.done.forEach(addDoneIndex);
  if (!S.formDirty && S.config) fillForm(S.config);
  if (BUSY.includes(S.state)) S.locked = true;
  else if (planChanged) S.locked = !!S.plan;
  S.planOk = !!S.plan && !S.formDirty;
  if (S.plan && planChanged && !S.planMsgs.errors.length) S.planMsgs = { errors: [], warnings: S.plan.warnings || [] };
  $("log").innerHTML = ""; S.log = [];
  appendLog(d.log || []);
  renderAll(); invalidate();
}

function applyUpdate(d) {
  const prev = S.state;
  Object.assign(S, { state: d.state, phase: d.phase, message: d.message, error: d.error,
    progress: d.progress || {}, tel: d.tel, target: d.target, sessionDir: d.session_dir });
  if (d.fft) { S.fft = d.fft; S.fftDirty = true; }
  if (prev !== "RUNNING" && S.state === "RUNNING" && !S.done.length) S.trail = [];
  for (const m of d.new_done || []) { S.done.push(m); addDoneIndex(m); }
  if (d.new_done && d.new_done.length) renderLast();
  appendLog(d.log || []);
  if (S.tel && BUSY.includes(S.state)) {
    const l = S.trail[S.trail.length - 1];
    if (!l || Math.hypot(l[0] - S.tel.x, l[1] - S.tel.y, l[2] - S.tel.z) > 0.5) S.trail.push([S.tel.x, S.tel.y, S.tel.z]);
    if (S.trail.length > 5000) S.trail.shift();
  }
  if (BUSY.includes(S.state)) S.locked = true;
  renderStatus(); invalidate();
}

/* ============================================================
   paneles de texto
   ============================================================ */
function renderAll() {
  renderDevices(); renderScope(); renderPlanSummary(); renderLast(); renderStatus();
  $("mtrsTiltTarget").textContent = fmtG(S.mtrs.tilt_target_deg ?? 0);
  if (S.workspace) {
    const [a, b] = [S.workspace.min, S.workspace.max];
    $("wsNote").textContent = `Workspace: X ${fmtG(a[0])} to ${fmtG(b[0])}, Y ${fmtG(a[1])} to ${fmtG(b[1])}, ` +
      `Z ${fmtG(a[2])} to ${fmtG(b[2])} mm (Z = 0 at the top).`;
  }
}
function renderDevices() {
  const m = S.modes || {};
  const item = (name, v, bad) => `<span class="${bad ? "bad" : ""}">${name} <b>${v}</b></span>`;
  $("devices").innerHTML = item("Gantry", m.gantry || "?") + item("MTRS", m.mtrs || "?") +
    item("Scope", m.scope || "?") + item("Link", S.connected ? "live" : "lost", !S.connected);
}
function renderScope() {
  const s = S.scope || {};
  const lsb = s.ch_scale_V_div ? (s.ch_scale_V_div * 8) / 256 : null;
  const span = s.fft_span_Hz != null && s.fft_center_Hz != null
    ? `${fmtG((s.fft_center_Hz - s.fft_span_Hz / 2) / 1e3)}–${fmtG((s.fft_center_Hz + s.fft_span_Hz / 2) / 1e3)} kHz` : "–";
  const rows = [
    ["Vertical scale", s.ch_scale_V_div != null ? `${fmtG(s.ch_scale_V_div * 1e3)} mV/div` : "–"],
    ["ADC step (approx.)", lsb ? `${(lsb * 1e3).toFixed(2)} mV` : "–"],
    ["Offset, coupling", `${fmtG((s.ch_offset_V ?? 0) * 1e3)} mV, ${s.ch_coupling ?? "–"}`],
    ["Acquisition", s.acquire_type ?? "–"],
    ["Timebase", s.timebase_s_div ? `${fmtG(s.timebase_s_div * 1e6)} µs/div` : "–"],
    ["Record length", s.timebase_s_div ? `${fmtG(s.timebase_s_div * 10e3)} ms` : "–"],
    ["Sample rate", s.sample_rate_Sa_s ? `${fmtG(s.sample_rate_Sa_s / 1e6)} MSa/s` : "–"],
    ["FFT span", span],
    ["FFT window, units", `${s.fft_window ?? "–"}, ${s.fft_units ?? "–"}`],
    ["Generator (WGEN)", s.wgen_frequency_Hz ? `${fmtG(s.wgen_frequency_Hz / 1e3)} kHz` : "–"],
  ];
  $("scopeInfo").innerHTML = rows.map(([k, v]) => `<tr><td>${k}</td><td>${v}</td></tr>`).join("");
}
function renderPlanSummary() {
  const p = S.plan, msgs = S.planMsgs;
  let html = "";
  if (p) {
    const c = p.config, b = p.est_breakdown || {};
    const sim = Object.entries(S.modes).some(([k, v]) => k !== "sim_speedup" && v === "sim");
    const rows = [
      ["Positions", `${p.n_sites.toLocaleString()} (${p.axes.x.length} × ${p.axes.y.length} × ${p.axes.z.length})`],
      ["Angles per position", `${p.angles.length} (step ${fmtG(360 / p.angles.length)}°)`],
      ["Measurements", `${p.n_meas.toLocaleString()} × ${c.n_samples} sample(s)`],
      ["PD tilt (recorded)", `${fmtG(c.pd_tilt_deg)}°`],
      ["Estimated duration", fmtDur(p.est_total_s)],
    ];
    const sub = [
      ["MTRS rotation", b.mtrs_rotation_s], ["Gantry motion", b.gantry_motion_s],
      ["Arrival checks", b.arrival_s], ["Settling", b.settle_s], ["Acquisition", b.acquisition_s],
    ];
    html += "<table>" + rows.map(([k, v]) => `<tr><td>${k}</td><td>${v}</td></tr>`).join("") +
      sub.filter(([, v]) => v > 0).map(([k, v]) => `<tr class="sub"><td>${k}</td><td>${fmtDur(v)}</td></tr>`).join("") +
      `<tr><td>Finish if started now</td><td>${clock(p.est_total_s)}</td></tr>` +
      `<tr><td>Disk space (approx.)</td><td>${fmtBytes(p.est_bytes)}</td></tr></table>`;
    if (sim) html += `<p class="note">The duration is estimated for the real hardware (nominal speeds in testbed.toml); simulated devices run faster.</p>`;
  }
  html += (msgs.errors || []).map((e) => `<div class="msg err">Error: ${e}</div>`).join("");
  html += (msgs.warnings || []).map((w) => `<div class="msg warn">Warning: ${w}</div>`).join("");
  $("planSummary").innerHTML = html;
}
function renderStatus() {
  const lab = $("stateLabel"), st = S.connected ? S.state : "OFFLINE";
  lab.textContent = S.connected ? STATE_TEXT[S.state] || S.state : "Offline";
  lab.className = `state ${st}`;
  const p = S.progress || {};
  $("pDone").textContent = (p.done ?? 0).toLocaleString();
  $("pTotal").textContent = (p.total ?? 0).toLocaleString();
  const pct = p.total ? (100 * p.done) / p.total : 0;
  $("bar").style.width = `${pct}%`;
  $("pPct").textContent = `${pct.toFixed(pct < 10 && pct > 0 ? 1 : 0)} %`;
  const busy = BUSY.includes(S.state);
  $("pElapsed").textContent = fmtDur(p.elapsed_s);
  $("pEta").textContent = busy ? fmtDur(p.eta_s) : "–";
  $("pFinish").textContent = busy && isFinite(p.eta_s) ? clock(p.eta_s) : "–";
  const c = p.current;
  $("pCurrent").textContent = c ? `#${c.meas_id}, position ${c.site_id}, ${fmtG(c.angle)}°` : "–";
  $("phase").textContent = S.state === "RUNNING" ? PHASE_TEXT[S.phase] || "–" : S.state === "PAUSED" ? "paused" : "–";
  $("message").textContent = S.message || "";
  $("message").className = `message ${S.error ? "error" : ""}`;
  const t = S.tel;
  $("rX").textContent = fmt(t?.x, 1); $("rY").textContent = fmt(t?.y, 1); $("rZ").textContent = fmt(t?.z, 1);
  $("rV").textContent = fmt(t?.v, 1); $("rA").textContent = fmt(t?.angle, 2); $("rT").textContent = fmt(t?.tilt, 3);
  $("rPT").textContent = S.config ? fmtG(S.config.pd_tilt_deg) : "–";
  $("rK").textContent = t ? (t.ok ? "OK" : t.kin) : "–";
  $("liveInfo").textContent = S.connected && t ? "10 Hz" : "no data";
  updateButtons();
}
function renderLast() {
  const d = S.done[S.done.length - 1], el = $("lastMeas");
  if (!d) { $("lastId").textContent = ""; el.innerHTML = `<span class="hint">No measurement yet.</span>`; return; }
  const units = S.scope.fft_units;
  $("lastId").textContent = `#${d.meas_id}, position ${d.site_id}`;
  el.innerHTML = `<div class="pose">X ${fmt(d.x, 1)}  Y ${fmt(d.y, 1)}  Z ${fmt(d.z, 1)} mm  θ ${fmt(d.angle, 2)}°</div>` +
    `<table><thead><tr><th>Freq.</th><th>Scope FFT</th><th>Waveform</th></tr></thead><tbody>` +
    Object.keys(d.rss).map((k) => `<tr><td>${k}</td><td>${fmtRss(d.fft[k], units)}</td><td>${fmtRss(d.rss[k], "Vrms")}</td></tr>`).join("") +
    `</tbody></table>` + (d.clip > 0.001 ? `<div class="clip">${(d.clip * 100).toFixed(1)} % of the samples are clipped (saturation).</div>` : "");
}
function appendLog(entries) {
  const ul = $("log");
  for (const e of entries) {
    S.log.push(e);
    const li = document.createElement("li");
    li.className = e.level;
    li.innerHTML = `<time>${new Date(e.t * 1000).toLocaleTimeString([], { hour12: false })}</time>`;
    li.appendChild(document.createTextNode(e.text));
    ul.appendChild(li);
  }
  while (ul.children.length > 400) ul.removeChild(ul.firstChild);
  if (entries.length) ul.scrollTop = ul.scrollHeight;
}
function updateButtons() {
  const st = S.state, busy = BUSY.includes(st), active = st === "RUNNING" || st === "PAUSED";
  $("btnPreview").disabled = busy || S.locked;
  $("btnReconfig").disabled = busy || !S.locked;
  $("btnStart").disabled = busy || !S.locked || !S.planOk || !S.connected;
  $("btnPause").disabled = !active;
  $("btnPause").textContent = st === "PAUSED" ? "Resume" : "Pause";
  $("btnStop").disabled = !active;
  $("btnScope").disabled = busy;
  setFormEnabled(!busy && !S.locked);
}

/* ============================================================
   acciones
   ============================================================ */
$("btnPreview").onclick = async () => {
  try {
    const r = await post("/api/plan", { config: readForm() });
    S.planMsgs = { errors: r.errors || [], warnings: r.warnings || [] };
    S.formDirty = false;
    if (r.state) applyFull(r.state);
    S.locked = S.planOk = !!r.ok;
    renderPlanSummary(); updateButtons();
  } catch (e) { S.planMsgs = { errors: [String(e.message || e)], warnings: [] }; renderPlanSummary(); }
};
$("btnReconfig").onclick = () => { S.locked = false; S.planOk = false; updateButtons(); };
$("btnStart").onclick = async () => {
  const p = S.plan, c = p.config;
  const ok = await confirmModal("Start acquisition",
    `${p.n_meas.toLocaleString()} measurements at ${p.n_sites.toLocaleString()} positions ` +
    `(K = ${p.angles.length}, ${c.n_samples} sample(s) each).\n` +
    `Estimated duration: ${fmtDur(p.est_total_s)}. Disk space: about ${fmtBytes(p.est_bytes)}.\n\n` +
    `PD tilt recorded as ${fmtG(c.pd_tilt_deg)}°. The MTRS tilt is not moved.\n` +
    `Check that the workspace is clear and that the emergency stop is within reach.`, "Start", "go");
  if (ok) post("/api/start").catch((e) => alert(e.message));
};
$("btnPause").onclick = () => post(S.state === "PAUSED" ? "/api/resume" : "/api/pause").catch((e) => alert(e.message));
$("btnStop").onclick = async () => {
  const ok = await confirmModal("Stop acquisition",
    "The gantry and the MTRS stop immediately and the session is closed.\nThe measurements already saved are kept.",
    "Stop", "stop");
  if (ok) post("/api/stop").catch((e) => alert(e.message));
};
$("btnScope").onclick = async () => {
  try { await post("/api/scope/refresh"); const st = await (await fetch("/api/state")).json(); S.scope = st.scope; renderScope(); }
  catch (e) { alert(e.message); }
};

/* ============================================================
   estadisticas por posicion
   ============================================================ */
const K = () => (S.plan ? S.plan.angles.length : 1);
function siteStats(site, key) {
  const list = S.doneBySite.get(site.site_id) || [];
  let sum = 0, n = 0;
  if (key !== "status") for (const m of list) { const v = m.rss[key]; if (v !== null && v !== undefined) { sum += v; n++; } }
  return { total: K(), done: list.length, value: n ? sum / n : null };
}
function cellStats(cell, zf, key) {
  let total = 0, done = 0, sum = 0, n = 0;
  const means = {}, counts = {};
  for (const s of cell.sites) {
    if (zf !== "all" && s.iz !== +zf) continue;
    total += K();
    const list = S.doneBySite.get(s.site_id) || [];
    done += list.length;
    for (const m of list) for (const [k, v] of Object.entries(m.rss)) {
      if (v === null) continue;
      means[k] = (means[k] || 0) + v; counts[k] = (counts[k] || 0) + 1;
      if (k === key) { sum += v; n++; }
    }
  }
  for (const k in means) means[k] /= counts[k];
  return { total, done, value: n ? sum / n : null, means };
}
function colorRange(values) {
  let lo = Infinity, hi = -Infinity;
  for (const v of values) if (v !== null) { lo = Math.min(lo, v); hi = Math.max(hi, v); }
  return isFinite(lo) ? [lo, hi] : null;
}
const valueColor = (v, range) => (range && v !== null ? viridis(range[1] > range[0] ? (v - range[0]) / (range[1] - range[0]) : 0.5) : COL.done);

/* ============================================================
   vista: capa estatica en cache + capa dinamica (PD, destino, trayectoria)
   ============================================================ */
const mapCv = $("map"), zCv = $("zbar"), dialCv = $("dial"), fftCv = $("fftCv");
const staticCv = document.createElement("canvas");
let staticKey = "", proj = null, hoverPts = [], legendRange = null;

function renderView() {
  const { ctx, w, h, dpr } = fitCanvas(mapCv);
  const key = [S.view, w, h, dpr, S.planVersion, S.done.length, $("zSel").value, $("colorSel").value,
    cam.yaw, cam.elev, cam.zoom, !!S.workspace].join("|");
  if (key !== staticKey) {
    staticCv.width = Math.round(w * dpr); staticCv.height = Math.round(h * dpr);
    const sctx = staticCv.getContext("2d");
    sctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    sctx.clearRect(0, 0, w, h);
    if (S.workspace) (S.view === "3d" ? static3D : staticTop)(sctx, w, h);
    staticKey = key;
  }
  ctx.clearRect(0, 0, w, h);
  ctx.drawImage(staticCv, 0, 0, w, h);
  if (proj) drawDynamic(ctx);
}

function line(ctx, pts, color, width = 1, dash = null) {
  ctx.strokeStyle = color; ctx.lineWidth = width; ctx.setLineDash(dash || []);
  ctx.beginPath();
  pts.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
  ctx.stroke(); ctx.setLineDash([]);
}
function arrow(ctx, [x1, y1], [x2, y2], color, label) {
  line(ctx, [[x1, y1], [x2, y2]], color, 2);
  const a = Math.atan2(y2 - y1, x2 - x1);
  ctx.fillStyle = color; ctx.beginPath(); ctx.moveTo(x2, y2);
  ctx.lineTo(x2 - 8 * Math.cos(a - 0.4), y2 - 8 * Math.sin(a - 0.4));
  ctx.lineTo(x2 - 8 * Math.cos(a + 0.4), y2 - 8 * Math.sin(a + 0.4)); ctx.fill();
  ctx.font = "600 12px Segoe UI, Arial"; ctx.textAlign = "center"; ctx.textBaseline = "middle";
  ctx.fillText(label, x2 + 11 * Math.cos(a), y2 + 11 * Math.sin(a));
  ctx.textBaseline = "alphabetic";
}
function marker(ctx, x, y, r, st, fill) {
  ctx.lineWidth = 1.2;
  if (st.done >= st.total) {
    ctx.fillStyle = fill; ctx.strokeStyle = COL.doneEdge;
    ctx.beginPath(); ctx.arc(x, y, r, 0, 7); ctx.fill(); ctx.stroke();
  } else {
    ctx.fillStyle = "#fff"; ctx.strokeStyle = COL.pending;
    ctx.beginPath(); ctx.arc(x, y, r, 0, 7); ctx.fill(); ctx.stroke();
    if (st.done > 0) {
      ctx.fillStyle = fill; ctx.beginPath(); ctx.moveTo(x, y);
      ctx.arc(x, y, r - 1, -Math.PI / 2, -Math.PI / 2 + (st.done / st.total) * 2 * Math.PI); ctx.closePath(); ctx.fill();
    }
  }
}

/* ---------------- vista superior ---------------- */
function staticTop(ctx, w, h) {
  const [xmin, ymin] = S.workspace.min, [xmax, ymax] = S.workspace.max;
  const m = { l: 12, r: 58, t: 10, b: 38 };
  const aw = w - m.l - m.r, ah = h - m.t - m.b;
  const s = Math.min(aw / (ymax - ymin), ah / (xmax - xmin));
  const ox = m.l + (aw - (ymax - ymin) * s) / 2, oy = m.t + (ah - (xmax - xmin) * s) / 2;
  const PX = (y) => ox + (ymax - y) * s, PY = (x) => oy + (xmax - x) * s;
  proj = { kind: "top", P: (x, y) => [PX(y), PY(x)], s };

  ctx.fillStyle = "#fbfbfc"; ctx.fillRect(PX(ymax), PY(xmax), (ymax - ymin) * s, (xmax - xmin) * s);
  const step = niceStep(Math.max(xmax - xmin, ymax - ymin), 7);
  ctx.font = "11px Consolas, monospace"; ctx.fillStyle = COL.text;
  for (let v = Math.ceil(ymin / step) * step; v <= ymax + 1e-9; v += step) {
    line(ctx, [[PX(v), PY(xmin)], [PX(v), PY(xmax)]], COL.grid);
    ctx.textAlign = "center"; ctx.fillText(fmtG(v), PX(v), PY(xmin) + 15);
  }
  for (let v = Math.ceil(xmin / step) * step; v <= xmax + 1e-9; v += step) {
    line(ctx, [[PX(ymin), PY(v)], [PX(ymax), PY(v)]], COL.grid);
    ctx.textAlign = "left"; ctx.fillText(fmtG(v), PX(ymin) + 6, PY(v) + 4);
  }
  ctx.strokeStyle = COL.frame; ctx.lineWidth = 1;
  ctx.strokeRect(PX(ymax), PY(xmax), (ymax - ymin) * s, (xmax - xmin) * s);
  ctx.fillStyle = COL.text; ctx.textAlign = "center"; ctx.font = "12px Segoe UI, Arial";
  ctx.fillText("Y [mm]", PX((ymin + ymax) / 2), PY(xmin) + 32);
  ctx.save(); ctx.translate(PX(ymin) + 50, PY((xmin + xmax) / 2)); ctx.rotate(-Math.PI / 2);
  ctx.fillText("X [mm]", 0, 0); ctx.restore();
  const O = [PX(ymin), PY(xmin)], L = Math.min(60, 0.14 * (xmax - xmin) * s);
  arrow(ctx, O, [O[0], O[1] - L], COL.x, "X");
  arrow(ctx, O, [O[0] - L, O[1]], COL.y, "Y");

  hoverPts = [];
  if (!S.plan) {
    ctx.fillStyle = COL.text; ctx.font = "13px Segoe UI, Arial"; ctx.textAlign = "center";
    ctx.fillText("Configure the grid and press Preview plan.", PX((ymin + ymax) / 2), PY((xmin + xmax) / 2));
    renderLegend(null); return;
  }
  const zf = $("zSel").value, key = $("colorSel").value;
  const r = Math.max(3, Math.min(10, (S.stepXY * s) / 2.8));
  const path = S.sites.filter((st) => zf === "all" || st.iz === +zf).map((st) => [PX(st.y), PY(st.x)]);
  if (path.length < 6000) line(ctx, path, "rgba(120,130,140,0.35)", 1, [3, 4]);
  const stats = S.cells.map((c) => [c, cellStats(c, zf, key)]);
  const range = key === "status" ? null : colorRange(stats.map(([, st]) => st.value));
  for (const [c, st] of stats) {
    if (!st.total) continue;
    const x = PX(c.y), y = PY(c.x);
    marker(ctx, x, y, r, st, key === "status" ? COL.done : valueColor(st.value, range));
    hoverPts.push({ x, y, cell: c });
  }
  proj.r = r;
  renderLegend(range);
}

/* ---------------- vista 3D ---------------- */
function make3D(w, h) {
  const [xmin, ymin, zmin] = S.workspace.min, [xmax, ymax, zmax] = S.workspace.max;
  const cx = (xmin + xmax) / 2, cy = (ymin + ymax) / 2, cz = (zmin + zmax) / 2;
  const ps = (cam.yaw * Math.PI) / 180, pe = (cam.elev * Math.PI) / 180;
  const cps = Math.cos(ps), sps = Math.sin(ps), cpe = Math.cos(pe), spe = Math.sin(pe);
  // marco de vista: a = -Y (derecha), b = X (arriba en la vista superior), c = Z
  const raw = (x, y, z) => {
    const a = -(y - cy), b = x - cx, c = z - cz;
    const a1 = a * cps - b * sps, b1 = a * sps + b * cps;
    return [a1, c * cpe + b1 * spe, c * spe - b1 * cpe];
  };
  // escala para que la caja del espacio de trabajo llene el area (en cualquier orientacion)
  let u0 = Infinity, u1 = -Infinity, v0 = Infinity, v1 = -Infinity;
  for (const x of [xmin, xmax]) for (const y of [ymin, ymax]) for (const z of [zmin, zmax]) {
    const [u, v] = raw(x, y, z);
    u0 = Math.min(u0, u); u1 = Math.max(u1, u); v0 = Math.min(v0, v); v1 = Math.max(v1, v);
  }
  const s = cam.zoom * Math.min((w - 90) / (u1 - u0), (h - 60) / (v1 - v0));
  const ou = w / 2 - ((u0 + u1) / 2) * s, ov = h / 2 + ((v0 + v1) / 2) * s;
  const P = (x, y, z) => { const [u, v, d] = raw(x, y, z); return [ou + u * s, ov - v * s, d]; };
  return { kind: "3d", P, s, lim: { xmin, xmax, ymin, ymax, zmin, zmax } };
}

function static3D(ctx, w, h) {
  proj = make3D(w, h);
  const { P, s, lim } = proj, { xmin, xmax, ymin, ymax, zmin, zmax } = lim;
  const step = niceStep(Math.max(xmax - xmin, ymax - ymin), 7);
  for (let v = Math.ceil(xmin / step) * step; v <= xmax + 1e-9; v += step) line(ctx, [P(v, ymin, zmin), P(v, ymax, zmin)], COL.grid);
  for (let v = Math.ceil(ymin / step) * step; v <= ymax + 1e-9; v += step) line(ctx, [P(xmin, v, zmin), P(xmax, v, zmin)], COL.grid);
  const corners = [];
  for (const x of [xmin, xmax]) for (const y of [ymin, ymax]) for (const z of [zmin, zmax]) corners.push([x, y, z]);
  for (let i = 0; i < 8; i++) for (let j = i + 1; j < 8; j++) {
    const d = corners[i].reduce((n, v, k) => n + (v !== corners[j][k] ? 1 : 0), 0);
    if (d === 1) line(ctx, [P(...corners[i]), P(...corners[j])], COL.frame);
  }
  ctx.font = "10.5px Consolas, monospace"; ctx.fillStyle = COL.text; ctx.textAlign = "center";
  for (let v = Math.ceil(xmin / step) * step; v <= xmax + 1e-9; v += step) { const [x, y] = P(v, ymin - 50, zmin); ctx.fillText(fmtG(v), x, y + 4); }
  for (let v = Math.ceil(ymin / step) * step; v <= ymax + 1e-9; v += step) { const [x, y] = P(xmin - 50, v, zmin); ctx.fillText(fmtG(v), x, y + 4); }
  const zstep = niceStep(zmax - zmin, 4);
  const [ex, ey] = [[xmin, ymin], [xmin, ymax], [xmax, ymin], [xmax, ymax]]
    .reduce((best, c) => (P(c[0], c[1], zmin)[0] < P(best[0], best[1], zmin)[0] ? c : best));
  ctx.textAlign = "right";
  for (let v = Math.ceil(zmin / zstep) * zstep; v <= zmax + 1e-9; v += zstep) {
    const [x, y] = P(ex, ey, v); ctx.fillText(fmtG(v), x - 6, y + 4);
  }
  { const [x, y] = P(ex, ey, zmax); ctx.fillText("Z [mm]", x - 6, y - 12); }
  const L = 260;
  const o = P(0, 0, 0);
  arrow(ctx, o, P(L, 0, 0), COL.x, "X");
  arrow(ctx, o, P(0, L, 0), COL.y, "Y");
  arrow(ctx, o, P(0, 0, L * 0.6), COL.z, "Z");

  hoverPts = [];
  if (!S.plan) { renderLegend(null); return; }
  const zf = $("zSel").value, key = $("colorSel").value;
  const r = Math.max(2.5, Math.min(7, (S.stepXY * s) / 3));
  const stats = S.sites.map((st) => [st, siteStats(st, key), P(st.x, st.y, st.z)]);
  const range = key === "status" ? null : colorRange(stats.map(([, st]) => st.value));
  if (stats.length < 40000) stats.sort((a, b) => a[2][2] - b[2][2]);
  for (const [site, st, [x, y]] of stats) {
    ctx.globalAlpha = zf === "all" || site.iz === +zf ? 1 : 0.18;
    marker(ctx, x, y, r, st, key === "status" ? COL.done : valueColor(st.value, range));
    if (ctx.globalAlpha === 1) hoverPts.push({ x, y, site });
  }
  ctx.globalAlpha = 1;
  proj.r = r;
  renderLegend(range);
}

/* ---------------- capa dinamica ---------------- */
function drawDynamic(ctx) {
  const busy = BUSY.includes(S.state), r = proj.r || 6;
  const P = (x, y, z) => proj.P(x, y, z);
  if (S.trail.length > 1) line(ctx, S.trail.map(([x, y, z]) => P(x, y, z)), COL.trail, 1.4);
  if (S.target && busy) {
    const [x, y] = P(S.target.x, S.target.y, S.target.z);
    ctx.strokeStyle = COL.target; ctx.lineWidth = 2.2;
    ctx.beginPath(); ctx.arc(x, y, r + 4, 0, 7); ctx.stroke();
  }
  if (S.tel) {
    const [x, y] = P(S.tel.x, S.tel.y, S.tel.z);
    if (proj.kind === "3d") {
      const [fx, fy] = P(S.tel.x, S.tel.y, proj.lim.zmin);
      line(ctx, [[x, y], [fx, fy]], "rgba(31,119,180,0.6)", 1, [3, 3]);
      ctx.fillStyle = "rgba(31,119,180,0.5)"; ctx.beginPath(); ctx.ellipse(fx, fy, 5, 2.5, 0, 0, 7); ctx.fill();
    }
    ctx.fillStyle = COL.pd; ctx.strokeStyle = "#fff"; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(x, y, 6, 0, 7); ctx.fill(); ctx.stroke();
    ctx.strokeStyle = "#0d3b66"; ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(x, y, 7.2, 0, 7); ctx.stroke();
  }
}

function renderLegend(range) {
  const key = $("colorSel").value, sig = `${S.view}|${key}|${range ? range.map((v) => v.toPrecision(3)).join() : ""}`;
  if (sig === legendRange) return;
  legendRange = sig;
  const el = $("legend");
  const dot = (bg, border) => `<i style="background:${bg};border:1.2px solid ${border}"></i>`;
  let html = `<span>${dot("#fff", COL.pending)}pending</span><span>${dot(`conic-gradient(${COL.done} 0 40%, #fff 0)`, COL.pending)}partially recorded</span>` +
    `<span>${dot(COL.done, COL.doneEdge)}recorded</span><span>${dot("#fff", COL.target)}current target</span>` +
    `<span>${dot(COL.pd, "#0d3b66")}PD (live)</span>`;
  if (key !== "status") {
    const grad = `linear-gradient(90deg, ${[0, 0.25, 0.5, 0.75, 1].map(viridis).join(",")})`;
    html += `<span>RSS ${key}, waveform, mean over angles: ${range ? fmtRss(range[0], "Vrms") : "–"}` +
      `<span class="grad" style="background:${grad}"></span>${range ? fmtRss(range[1], "Vrms") : "–"}</span>`;
  }
  el.innerHTML = html;
}

/* ---------------- interaccion: tooltip y orbita ---------------- */
let drag = null;
mapCv.addEventListener("mousedown", (e) => { if (S.view === "3d") drag = { x: e.clientX, y: e.clientY, yaw: cam.yaw, elev: cam.elev }; });
window.addEventListener("mouseup", () => { drag = null; });
window.addEventListener("mousemove", (e) => {
  if (!drag) return;
  cam.yaw = drag.yaw + (e.clientX - drag.x) * 0.4;
  cam.elev = Math.max(-5, Math.min(90, drag.elev + (e.clientY - drag.y) * 0.4));
  $("tooltip").style.display = "none"; invalidate();
});
mapCv.addEventListener("wheel", (e) => {
  if (S.view !== "3d") return;
  e.preventDefault();
  cam.zoom = Math.max(0.4, Math.min(6, cam.zoom * (e.deltaY < 0 ? 1.12 : 1 / 1.12)));
  invalidate();
}, { passive: false });
mapCv.addEventListener("dblclick", () => { if (S.view === "3d") { Object.assign(cam, { yaw: 30, elev: 28, zoom: 1 }); invalidate(); } });

mapCv.addEventListener("mousemove", (ev) => {
  const tip = $("tooltip");
  if (drag || !S.plan || !hoverPts.length) { tip.style.display = "none"; return; }
  const rect = mapCv.getBoundingClientRect(), mx = ev.clientX - rect.left, my = ev.clientY - rect.top;
  let best = null, bd = Math.max(8, (proj.r || 6) + 3);
  for (const p of hoverPts) { const d = Math.hypot(p.x - mx, p.y - my); if (d < bd) { bd = d; best = p; } }
  if (!best) { tip.style.display = "none"; return; }
  let txt;
  if (best.cell) {
    const zf = $("zSel").value, st = cellStats(best.cell, zf, "status");
    const zs = best.cell.sites.filter((s) => zf === "all" || s.iz === +zf).map((s) => fmtG(s.z));
    txt = `X ${fmtG(best.cell.x)}  Y ${fmtG(best.cell.y)} mm\nZ ${zs.join(", ")} mm\nrecorded ${st.done} of ${st.total}`;
    for (const [k, v] of Object.entries(st.means)) txt += `\n${k.padEnd(8)} ${fmtRss(v, "Vrms")}`;
  } else {
    const s = best.site, list = S.doneBySite.get(s.site_id) || [];
    txt = `position ${s.site_id}\nX ${fmtG(s.x)}  Y ${fmtG(s.y)}  Z ${fmtG(s.z)} mm\nrecorded ${list.length} of ${K()}`;
    const keys = list.length ? Object.keys(list[0].rss) : [];
    for (const k of keys) txt += `\n${k.padEnd(8)} ${fmtRss(list.reduce((a, m) => a + (m.rss[k] || 0), 0) / list.length, "Vrms")}`;
  }
  tip.textContent = txt;
  tip.style.display = "block";
  tip.style.left = `${Math.min(mx + 14, rect.width - 200)}px`;
  tip.style.top = `${my + 12}px`;
});
mapCv.addEventListener("mouseleave", () => { $("tooltip").style.display = "none"; });

/* ---------------- barra de Z ---------------- */
function drawZ() {
  if (S.view === "3d") return;
  const { ctx, w, h } = fitCanvas(zCv);
  ctx.clearRect(0, 0, w, h);
  if (!S.workspace) return;
  const zmin = S.workspace.min[2], zmax = S.workspace.max[2], t = 10, b = 38, x0 = 18, bw = 12;
  const PZ = (z) => t + ((zmax - z) / (zmax - zmin)) * (h - t - b);
  ctx.fillStyle = "#fbfbfc"; ctx.fillRect(x0, PZ(zmax), bw, PZ(zmin) - PZ(zmax));
  ctx.strokeStyle = COL.frame; ctx.strokeRect(x0 + 0.5, PZ(zmax) + 0.5, bw, PZ(zmin) - PZ(zmax));
  ctx.font = "10.5px Consolas, monospace"; ctx.fillStyle = COL.text; ctx.textAlign = "left";
  const step = niceStep(zmax - zmin, 7);
  for (let z = Math.ceil(zmin / step) * step; z <= zmax + 1e-9; z += step) {
    ctx.fillRect(x0 + bw, PZ(z), 4, 1); ctx.fillText(fmtG(z), x0 + bw + 6, PZ(z) + 3);
  }
  ctx.textAlign = "center"; ctx.font = "12px Segoe UI, Arial"; ctx.fillText("Z [mm]", w / 2, h - 6);
  if (S.plan) {
    const sel = $("zSel").value;
    S.plan.axes.z.forEach((z, i) => {
      ctx.fillStyle = sel === "all" || +sel === i ? "#4a6f94" : "#b9c6d3";
      ctx.fillRect(x0 - 5, PZ(z) - 1, bw + 10, 2);
    });
  }
  if (S.target && BUSY.includes(S.state)) line(ctx, [[x0 - 7, PZ(S.target.z)], [x0 + bw + 7, PZ(S.target.z)]], COL.target, 2, [3, 3]);
  if (S.tel) {
    const y = PZ(S.tel.z);
    ctx.fillStyle = COL.pd;
    ctx.beginPath(); ctx.moveTo(x0 - 2, y); ctx.lineTo(x0 - 11, y - 5); ctx.lineTo(x0 - 11, y + 5); ctx.fill();
    ctx.fillRect(x0, y - 1.5, bw, 3);
  }
}

/* ---------------- dial del MTRS ---------------- */
function drawDial() {
  const { ctx, w, h } = fitCanvas(dialCv);
  ctx.clearRect(0, 0, w, h);
  const cx = w / 2, cy = h / 2 + 6, R = Math.min(w, h) / 2 - 26;
  const base = { N: -90, E: 0, S: 90, W: 180 }[S.viewCfg.mtrs_zero_location || "N"] ?? -90;
  const dir = S.viewCfg.mtrs_clockwise ? 1 : -1;
  const P = (deg, r) => { const a = ((base + dir * deg) * Math.PI) / 180; return [cx + r * Math.cos(a), cy + r * Math.sin(a)]; };
  ctx.fillStyle = "#fbfbfc"; ctx.strokeStyle = COL.frame; ctx.lineWidth = 1;
  ctx.beginPath(); ctx.arc(cx, cy, R, 0, 7); ctx.fill(); ctx.stroke();
  for (let d = 0; d < 360; d += 10) {
    const major = d % 90 === 0;
    line(ctx, [P(d, R), P(d, R - (major ? 9 : d % 30 === 0 ? 6 : 3))], major ? COL.ink : COL.pending, major ? 1.5 : 1);
  }
  ctx.fillStyle = COL.text; ctx.font = "10.5px Consolas, monospace"; ctx.textAlign = "center"; ctx.textBaseline = "middle";
  for (const d of [0, 90, 180, 270]) { const [x, y] = P(d, R + 12); ctx.fillText(`${d}°`, x, y); }
  if (S.plan) {
    const cur = S.progress.current;
    const doneK = new Set(cur ? (S.doneBySite.get(cur.site_id) || []).map((m) => m.k) : []);
    S.plan.angles.forEach((a, k) => {
      const [x, y] = P(a, R - 17);
      ctx.fillStyle = doneK.has(k) ? COL.done : "#fff"; ctx.strokeStyle = doneK.has(k) ? COL.doneEdge : "#6b7c8f";
      ctx.lineWidth = 1.2; ctx.beginPath(); ctx.arc(x, y, 3.8, 0, 7); ctx.fill(); ctx.stroke();
    });
  }
  if (S.target && BUSY.includes(S.state)) line(ctx, [[cx, cy], P(S.target.angle, R - 3)], COL.target, 1.8, [5, 4]);
  if (S.tel) {
    ctx.lineCap = "round";
    line(ctx, [[cx, cy], P(S.tel.angle, R - 26)], COL.pd, 3.5);
    ctx.lineCap = "butt";
    ctx.fillStyle = COL.ink; ctx.beginPath(); ctx.arc(cx, cy, 3.5, 0, 7); ctx.fill();
    ctx.textAlign = "left"; ctx.textBaseline = "top";
    ctx.font = "15px Consolas, monospace"; ctx.fillStyle = COL.ink;
    ctx.fillText(`${S.tel.angle.toFixed(2)}°`, 4, 2);
    ctx.font = "11px Segoe UI, Arial"; ctx.fillStyle = COL.text;
    ctx.fillText(S.tel.moving ? "rotating" : "stationary", 4, 21);
  }
  ctx.textBaseline = "alphabetic";
}

/* ---------------- FFT ---------------- */
function drawFFT() {
  const { ctx, w, h } = fitCanvas(fftCv);
  ctx.clearRect(0, 0, w, h);
  const f = S.fft, m = { l: 52, r: 10, t: 8, b: 30 };
  if (!f || !f.y.length) { $("fftVals").innerHTML = ""; return; }
  const n = f.y.length, f1 = f.f0 + f.df * (n - 1), isDb = f.units === "dB";
  const ymax = Math.max(...f.y);
  let lo = 0, hi;
  if (isDb) { lo = Math.min(...f.y); hi = ymax + 5; }
  else { S.fftYmax = Math.max(ymax * 1.15, S.fftYmax * 0.97, 1e-6); hi = S.fftYmax; }
  const PX = (fr) => m.l + ((fr - f.f0) / (f1 - f.f0 || 1)) * (w - m.l - m.r);
  const PY = (v) => h - m.b - ((v - lo) / (hi - lo || 1)) * (h - m.t - m.b);
  ctx.font = "10.5px Consolas, monospace"; ctx.fillStyle = COL.text;
  const ystep = niceStep(hi - lo, 4);
  for (let v = Math.ceil(lo / ystep) * ystep; v <= hi + 1e-12; v += ystep) {
    line(ctx, [[m.l, PY(v)], [w - m.r, PY(v)]], COL.grid);
    ctx.textAlign = "right"; ctx.fillText(isDb ? fmtG(v) : fmtG(+(v * 1e3).toPrecision(4)), m.l - 6, PY(v) + 3);
  }
  const fstep = niceStep(f1 - f.f0, 10);
  for (let fr = Math.ceil(f.f0 / fstep) * fstep; fr <= f1 + 1e-6; fr += fstep) {
    line(ctx, [[PX(fr), m.t], [PX(fr), h - m.b]], COL.grid);
    ctx.textAlign = "center"; ctx.fillText(fmtG(fr / 1e3), PX(fr), h - m.b + 13);
  }
  ctx.strokeStyle = COL.frame; ctx.strokeRect(m.l + 0.5, m.t + 0.5, w - m.l - m.r, h - m.t - m.b);
  ctx.font = "12px Segoe UI, Arial"; ctx.textAlign = "center";
  ctx.fillText("Frequency [kHz]", (m.l + w - m.r) / 2, h - 2);
  ctx.save(); ctx.translate(12, (h - m.b + m.t) / 2); ctx.rotate(-Math.PI / 2);
  ctx.fillText(isDb ? "Magnitude [dB]" : "Amplitude [mVrms]", 0, 0); ctx.restore();
  const pts = [];
  for (let i = 0; i < n; i++) pts.push([PX(f.f0 + i * f.df), PY(Math.max(f.y[i], lo))]);
  line(ctx, pts, COL.line, 1.1);
  const freqs = (S.plan ? S.plan.config.freqs_khz : parseFreqs()).filter((v) => v > 0), vals = [];
  for (const fk of freqs) {
    const fr = fk * 1e3;
    if (fr < f.f0 || fr > f1) { vals.push(`<span>${fmtG(fk)} kHz</span> out of span`); continue; }
    const i0 = Math.round((fr - f.f0) / f.df);
    let best = -Infinity;
    for (let i = Math.max(0, i0 - 2); i <= Math.min(n - 1, i0 + 2); i++) best = Math.max(best, f.y[i]);
    line(ctx, [[PX(fr), m.t], [PX(fr), h - m.b]], "rgba(230,85,13,0.6)", 1, [4, 3]);
    ctx.fillStyle = COL.marker; ctx.beginPath(); ctx.arc(PX(fr), PY(best), 3, 0, 7); ctx.fill();
    vals.push(`<span>${fmtG(fk)} kHz</span> ${fmtRss(best, f.units)}`);
  }
  $("fftVals").innerHTML = vals.map((v) => `<div>${v}</div>`).join("");
  $("fftInfo").textContent = `${f.units}, ${fmtG(f.rate)} updates/s`;
}

/* ============================================================
   bucle de dibujo y conexion en vivo
   ============================================================ */
let lastSize = "";
function frame() {
  const size = `${mapCv.clientWidth}x${mapCv.clientHeight}|${fftCv.clientWidth}`;
  if (size !== lastSize) { lastSize = size; S.dirty = true; S.fftDirty = true; }
  if (S.dirty) { S.dirty = false; renderView(); drawZ(); drawDial(); }
  if (S.fftDirty) { S.fftDirty = false; drawFFT(); }
  requestAnimationFrame(frame);
}

function connect() {
  const es = new EventSource("/api/events");
  es.onopen = () => { S.connected = true; renderDevices(); renderStatus(); };
  es.onmessage = (ev) => {
    const d = JSON.parse(ev.data);
    if (!S.connected) { S.connected = true; renderDevices(); }
    d.type === "full" ? applyFull(d) : applyUpdate(d);
  };
  es.onerror = () => { S.connected = false; renderDevices(); renderStatus(); };
}

// ?snapshot=1 -> carga el estado una sola vez (capturas de pantalla / depuracion)
const QS = new URLSearchParams(location.search);
if (QS.has("snapshot")) {
  if (QS.has("view")) setView(QS.get("view"));
  if (QS.has("config")) setConfigOpen(QS.get("config") === "1");
  fetch("/api/state").then((r) => r.json()).then((d) => {
    S.connected = true; applyFull(d);
    if (QS.has("color")) $("colorSel").value = QS.get("color");
    if (QS.has("z")) $("zSel").value = QS.get("z");
    invalidate();
  });
} else {
  connect();
}
requestAnimationFrame(frame);
