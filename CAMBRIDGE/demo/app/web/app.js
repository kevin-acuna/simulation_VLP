/* VLP Positioning Demo - user interface. It only displays the state and sends commands; all the
   control, estimation and saving happen in Python (engine.py). Same style as the Database Acquisition Tool. */
"use strict";

const $ = (id) => document.getElementById(id);
const BUSY = ["RUNNING", "PAUSED", "STOPPING"];
const STATE_TEXT = { IDLE: "Idle", RUNNING: "Running", PAUSED: "Paused", STOPPING: "Stopping",
  FINISHED: "Finished", STOPPED: "Stopped", CONNECTING: "Connecting" };
const COL = {
  grid: "#e4e7eb", frame: "#a9b1bb", text: "#5f6b7a", ink: "#1f2933", pending: "#9aa4b1",
  truth: "#1f2933", link: "rgba(95,107,122,0.55)", target: "#ff7f0e", pd: "#1f77b4",
  x: "#d62728", y: "#2ca02c", z: "#1f77b4", led: "#f2c200", rss: "#1f77b4", fit: "#d62728", active: "#e6550d",
  accent: "#24527a", p90: "#e6550d", fail: "#b3261e",
};
const ERR_SCALE_MM = 200;                 // color scale of the errors: 0 to 20 cm

const S = {
  state: "CONNECTING", phase: "", message: "", error: null, config: null, defaults: null,
  workspace: null, box: null, led: null, ledFreq: 500, nominalOffset: 65, viewCfg: {}, modes: {},
  queue: [], done: [], current: null, prev: null, stats: {}, tel: null, log: [], sessionDir: null,
  connected: false, formDirty: false, mode: "random", pick: null, checkMsgs: { errors: [], warnings: [] },
  view: localStorage.getItem("vlpdemo.view") || "top", dirty: true, plotsDirty: true, focus: false, histHover: null,
};
const cam = { yaw: 32, elev: 22, zoom: 1 };

/* ============================================================
   helpers
   ============================================================ */
const fmtG = (v) => String(+(+v).toPrecision(6));
const fmt = (v, d = 1) => (v === null || v === undefined || !isFinite(v) ? "–" : (+v).toFixed(d));
const cm = (mm, d = 2) => fmt(mm === null || mm === undefined ? NaN : mm / 10, d);
async function post(url, body) {
  const r = await fetch(url, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body || {}) });
  const data = await r.json().catch(() => ({}));
  if (!r.ok || data.ok === false) throw new Error(data.error || `HTTP ${r.status}`);
  return data;
}
function confirmModal(title, text, okLabel = "OK", okClass = "primary") {
  return new Promise((resolve) => {
    $("modalTitle").textContent = title; $("modalText").textContent = text;
    const ok = $("modalOk"), cancel = $("modalCancel");
    ok.textContent = okLabel; ok.className = `btn ${okClass}`;
    cancel.hidden = okLabel === "Close";
    $("modal").classList.add("show");
    const close = (v) => { $("modal").classList.remove("show"); ok.onclick = cancel.onclick = null; resolve(v); };
    ok.onclick = () => close(true); cancel.onclick = () => close(false);
  });
}
function fitCanvas(cv) {
  const dpr = window.devicePixelRatio || 1, w = cv.clientWidth, h = cv.clientHeight;
  if (cv.width !== Math.round(w * dpr) || cv.height !== Math.round(h * dpr)) { cv.width = Math.round(w * dpr); cv.height = Math.round(h * dpr); }
  const ctx = cv.getContext("2d");
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  return { ctx, w, h, dpr };
}
function niceStep(range, n) {
  const raw = range / n, p = 10 ** Math.floor(Math.log10(raw)), r = raw / p;
  return (r < 1.5 ? 1 : r < 3 ? 2 : r < 7 ? 5 : 10) * p;
}
function line(ctx, pts, color, width = 1, dash = null) {
  ctx.strokeStyle = color; ctx.lineWidth = width; ctx.setLineDash(dash || []);
  ctx.beginPath(); pts.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
  ctx.stroke(); ctx.setLineDash([]);
}
function arrow(ctx, [x1, y1], [x2, y2], color, label) {
  line(ctx, [[x1, y1], [x2, y2]], color, 2);
  const a = Math.atan2(y2 - y1, x2 - x1);
  ctx.fillStyle = color; ctx.beginPath(); ctx.moveTo(x2, y2);
  ctx.lineTo(x2 - 8 * Math.cos(a - 0.4), y2 - 8 * Math.sin(a - 0.4)); ctx.lineTo(x2 - 8 * Math.cos(a + 0.4), y2 - 8 * Math.sin(a + 0.4)); ctx.fill();
  ctx.font = "600 12px Segoe UI, Arial"; ctx.textAlign = "center"; ctx.textBaseline = "middle";
  ctx.fillText(label, x2 + 11 * Math.cos(a), y2 + 11 * Math.sin(a)); ctx.textBaseline = "alphabetic";
}
function errColor(mm) {                  // green (0) -> amber (10 cm) -> red (>= 20 cm)
  if (mm === null || mm === undefined || !isFinite(mm)) return "#9aa4b1";
  const t = Math.min(1, Math.max(0, mm / ERR_SCALE_MM));
  const c = t < 0.5 ? [[44, 160, 44], [242, 177, 0]] : [[242, 177, 0], [214, 39, 40]];
  const f = t < 0.5 ? t / 0.5 : (t - 0.5) / 0.5;
  const m = c[0].map((v, k) => Math.round(v + (c[1][k] - v) * f));
  return `rgb(${m[0]},${m[1]},${m[2]})`;
}
function star(ctx, x, y, r, fill, stroke) {
  ctx.beginPath();
  for (let i = 0; i < 10; i++) {
    const a = -Math.PI / 2 + (i * Math.PI) / 5, rr = i % 2 ? r * 0.45 : r;
    i ? ctx.lineTo(x + rr * Math.cos(a), y + rr * Math.sin(a)) : ctx.moveTo(x + rr * Math.cos(a), y + rr * Math.sin(a));
  }
  ctx.closePath(); ctx.fillStyle = fill; ctx.fill(); ctx.strokeStyle = stroke; ctx.lineWidth = 1; ctx.stroke();
}
const invalidate = () => { S.dirty = true; };
const shownDone = () => {
  const n = $("showSel").value;
  return n === "all" ? S.done : S.done.slice(-parseInt(n, 10));
};
const mag = () => parseFloat($("magSel").value) || 1;
// estimated position as drawn: real + mag * (estimated - real); the numbers always use the true values
const drawnEst = (t, e) => t.map((v, i) => v + mag() * (e[i] - v));
$("magSel").value = "1";                 // always true scale when the page opens
$("magSel").onchange = () => { renderLegend(); invalidate(); };
function rememberCurrent(c) {          // keeps the last finished point (RSS + fit) while the next one starts
  if (c && c.result) S.prev = c;
}

/* ============================================================
   panels, view tabs, mode
   ============================================================ */
function setConfigOpen(open) {
  $("body").classList.toggle("cfg-open", open);
  $("btnConfig").setAttribute("aria-expanded", String(open));
  localStorage.setItem("vlpdemo.cfgOpen", open ? "1" : "0");
  invalidate(); S.plotsDirty = true;
}
$("btnConfig").onclick = () => {
  if (S.focus) { setFocus(false); setConfigOpen(true); return; }
  setConfigOpen(!$("body").classList.contains("cfg-open"));
};
setConfigOpen(localStorage.getItem("vlpdemo.cfgOpen") !== "0");

// enlarged view: only "Real vs estimated position" below the header (Esc or the button to go back)
function setFocus(on) {
  S.focus = on;
  $("body").classList.toggle("focus", on);
  $("btnFocus").textContent = on ? "Back to normal view" : "Enlarge";
  $("tooltip").style.display = "none";
  invalidate(); S.plotsDirty = true;
}
$("btnFocus").onclick = () => setFocus(!S.focus);
window.addEventListener("keydown", (e) => { if (e.key === "Escape" && S.focus && !$("modal").classList.contains("show")) setFocus(false); });

function setView(v) {
  S.view = v; localStorage.setItem("vlpdemo.view", v);
  for (const b of $("viewTabs").querySelectorAll("button")) b.classList.toggle("active", b.dataset.view === v);
  $("map").classList.toggle("orbit", v === "3d");
  $("tooltip").style.display = "none"; renderModeUi(); invalidate();
}
for (const b of $("viewTabs").querySelectorAll("button")) b.onclick = () => setView(b.dataset.view);
$("showSel").onchange = invalidate;

function renderModeUi() {
  for (const b of $("modeTabs").querySelectorAll("button")) b.classList.toggle("active", b.dataset.mode === S.mode);
  $("modeNote").textContent = S.mode === "random"
    ? "The gantry goes to random positions in this box, one after the other, until Stop."
    : "The gantry measures the queued positions and then waits for the next one.";
  $("map").classList.toggle("pick", S.view === "top");
  $("viewHint").textContent = S.view === "3d" ? "drag to rotate · wheel to zoom · double-click to reset"
    : "origin at bottom right · X up · Y left · click to pick a position";
}
for (const b of $("modeTabs").querySelectorAll("button")) b.onclick = async () => {
  S.mode = b.dataset.mode; renderModeUi(); invalidate();
  if (BUSY.includes(S.state)) { try { await post("/api/mode", { mode: S.mode }); } catch (e) { alertError(e); } }
  else formChanged();
};

/* ============================================================
   form
   ============================================================ */
const FORM_IDS = ["rx0", "rx1", "ry0", "ry1", "rz0", "rz1", "kAngles", "maxPoints", "tiltMode", "tiltDeg", "tiltMin",
  "tiltMax", "freqs", "nSamples", "settle", "seed", "recordMs", "recordFs", "saveWave", "label"];
const num = (id) => parseFloat($(id).value);
function fillForm(c) {
  $("rx0").value = c.region_x[0]; $("rx1").value = c.region_x[1];
  $("ry0").value = c.region_y[0]; $("ry1").value = c.region_y[1];
  $("rz0").value = c.region_z[0]; $("rz1").value = c.region_z[1];
  $("kAngles").value = c.k_angles; $("maxPoints").value = c.max_points;
  $("tiltMode").value = c.mtrs_tilt_mode || "fixed"; $("tiltDeg").value = c.mtrs_tilt_deg ?? 0;
  $("tiltMin").value = c.mtrs_tilt_min_deg ?? -3; $("tiltMax").value = c.mtrs_tilt_max_deg ?? 3;
  renderTiltUi();
  $("freqs").value = c.freqs_khz.map(fmtG).join(", ");
  $("nSamples").value = c.n_samples; $("settle").value = c.settle_s; $("seed").value = c.seed ?? "";
  $("recordMs").value = c.record_ms; $("recordFs").value = c.record_fs_msa;
  $("saveWave").checked = !!c.save_waveforms; $("label").value = c.label || "";
  S.mode = c.mode || "random";
  if (!$("mz").value) $("mz").value = -300;
  S.formDirty = false; renderModeUi(); updateAngles();
}
function readForm() {
  return {
    mode: S.mode, region_x: [num("rx0"), num("rx1")], region_y: [num("ry0"), num("ry1")], region_z: [num("rz0"), num("rz1")],
    k_angles: parseInt($("kAngles").value, 10), max_points: parseInt($("maxPoints").value, 10) || 0,
    mtrs_tilt_mode: $("tiltMode").value, mtrs_tilt_deg: num("tiltDeg"),
    mtrs_tilt_min_deg: num("tiltMin"), mtrs_tilt_max_deg: num("tiltMax"),
    freqs_khz: $("freqs").value.split(/[,;\s]+/).filter(Boolean).map(parseFloat),
    n_samples: parseInt($("nSamples").value, 10), settle_s: num("settle"),
    seed: $("seed").value === "" ? null : parseInt($("seed").value, 10),
    record_ms: num("recordMs"), record_fs_msa: num("recordFs"), save_waveforms: $("saveWave").checked,
    label: $("label").value.trim(),
  };
}
function renderTiltUi() {
  const random = $("tiltMode").value === "random";
  $("tiltFixedBox").style.visibility = random ? "hidden" : "";
  $("tiltRandomBox").style.display = random ? "" : "none";
  $("tiltNote").textContent = random
    ? "Commanded at every new position: one value per position, uniform in [min, max] (range ±3°)."
    : "Commanded at every new position (range ±3°).";
}
$("tiltMode").addEventListener("change", renderTiltUi);
function updateAngles() {
  const K = parseInt($("kAngles").value, 10);
  if (!(K >= 1)) { $("angleList").textContent = "–"; return; }
  const a = [...Array(K).keys()].map((k) => (S.nominalOffset + (360 * k) / K) % 360).sort((p, q) => p - q);
  $("angleList").textContent = a.map((v) => `${fmtG(+v.toFixed(2))}°`).join(", ");
}
let checkTimer = null;
function formChanged() {
  S.formDirty = true; updateAngles();
  clearTimeout(checkTimer);
  checkTimer = setTimeout(async () => {
    try {
      const r = await fetch("/api/check", { method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ config: readForm() }) }).then((x) => x.json());
      S.checkMsgs = { errors: r.errors || [], warnings: r.warnings || [] };
    } catch (e) { S.checkMsgs = { errors: [String(e.message || e)], warnings: [] }; }
    renderCheck(); updateButtons();
  }, 250);
}
for (const id of FORM_IDS) $(id).addEventListener("input", formChanged);
function renderCheck() {
  $("checkMsgs").innerHTML = S.checkMsgs.errors.map((e) => `<div class="msg err">Error: ${e}</div>`).join("") +
    S.checkMsgs.warnings.map((w) => `<div class="msg warn">Note: ${w}</div>`).join("");
}
function setFormEnabled(on) {
  for (const id of FORM_IDS) $(id).disabled = !on;
}
function alertError(e) { confirmModal("Error", String(e.message || e), "Close"); }

/* ============================================================
   state from the server
   ============================================================ */
function applyStatic(d) {
  Object.assign(S, { workspace: d.workspace, box: d.phys_box, led: d.led_mm, ledFreq: d.led_freq_khz,
    nominalOffset: d.nominal_offset_deg, viewCfg: d.view || {}, modes: d.modes || {} });
}
function applyFull(d) {
  applyStatic(d);
  Object.assign(S, { state: d.state, phase: d.phase, message: d.message, error: d.error, config: d.config,
    defaults: d.defaults, queue: d.queue || [], done: d.done || [], current: d.current, stats: d.stats || {},
    tel: d.tel, sessionDir: d.session_dir });
  rememberCurrent(S.current);
  if (!S.formDirty && S.config) fillForm(S.config);
  $("log").innerHTML = ""; S.log = []; appendLog(d.log || []);
  renderAll();
}
function applyUpdate(d) {
  Object.assign(S, { state: d.state, phase: d.phase, message: d.message, error: d.error, queue: d.queue || [],
    tel: d.tel, sessionDir: d.session_dir });
  if (BUSY.includes(S.state) && d.mode && d.mode !== S.mode) { S.mode = d.mode; renderModeUi(); }
  if (d.new_done && d.new_done.length) { S.done.push(...d.new_done); S.plotsDirty = true; }
  if ("current" in d) { S.current = d.current; rememberCurrent(d.current); renderRssList(); }
  if (d.stats) S.stats = d.stats;
  appendLog(d.log || []);
  renderStatus(); invalidate();
}

/* ============================================================
   text panels
   ============================================================ */
function renderAll() {
  renderDevices(); renderStatus(); renderRssList(); renderCheck(); updateAngles(); renderModeUi();
  $("ledPos").textContent = `positioning LED ${fmtG(S.ledFreq)} kHz`;
  if (S.workspace) {
    const [a, b] = [S.workspace.min, S.workspace.max];
    $("wsNote").textContent = `Gantry coordinates. Workspace X ${fmtG(a[0])}–${fmtG(b[0])}, Y ${fmtG(a[1])}–${fmtG(b[1])}, ` +
      `Z ${fmtG(a[2])}–${fmtG(b[2])} mm (Z = ${fmtG(a[2])} is the highest PD position).`;
  }
  S.plotsDirty = true; invalidate();
}
function renderDevices() {
  const m = S.modes || {}, item = (n, v, bad) => `<span class="${bad ? "bad" : ""}">${n} <b>${v}</b></span>`;
  $("devices").innerHTML = item("Gantry", m.gantry || "?") + item("MTRS", m.mtrs || "?") + item("Scope", m.scope || "?") +
    item("Link", S.connected ? "live" : "lost", !S.connected);
}
function renderStatus() {
  const lab = $("stateLabel");
  lab.textContent = S.connected ? STATE_TEXT[S.state] || S.state : "Offline";
  lab.className = `state ${S.connected ? S.state : "OFFLINE"}`;
  const st = $("statusLine");
  st.textContent = S.message || "";
  st.title = S.message || "";
  st.className = `status-line ${S.error ? "error" : ""}`;
  $("sessionDir").textContent = S.sessionDir || "–";
  $("queueInfo").textContent = S.queue.length ? `Queue: ${S.queue.map((q) => `(${q.map(fmtG).join(", ")})`).join(" ")}` : "Queue empty.";
  updateButtons();
}
const rssPoint = () => {                 // point shown in the RSS panel: the current one, or the last finished
  const c = S.current;
  const n = c ? c.rss_mV.filter((v) => v !== null).length : 0;
  return c && (n > 0 || !S.prev || S.prev.id === c.id) ? c : S.prev;
};
function renderRssList() {
  const c = rssPoint();
  if (!c) { $("rssList").innerHTML = ""; $("rssInfo").textContent = ""; return; }
  $("rssInfo").textContent = `point ${c.id}, ${S.ledFreq} kHz LED, ${c.rss_mV.filter((v) => v !== null).length} of ${c.angles.length}` +
    (c !== S.current ? " (finished)" : "");
  $("rssList").innerHTML = c.angles.map((a, k) => `<span class="${c.active_k === k ? "active" : ""}">${fmtG(+a.toFixed(1))}°` +
    ` <b>${c.rss_mV[k] === null ? "…" : `${c.rss_mV[k].toFixed(3)} mV`}</b></span>`).join("");
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
  $("btnStart").disabled = busy || !S.connected || S.checkMsgs.errors.length > 0;
  $("btnPause").disabled = !active;
  $("btnPause").textContent = st === "PAUSED" ? "Resume" : "Pause";
  $("btnStop").disabled = !active;
  $("btnClearQueue").disabled = !S.queue.length;
  setFormEnabled(!busy);
}

/* ============================================================
   actions
   ============================================================ */
$("btnStart").onclick = async () => {
  try { await post("/api/start", { config: readForm() }); S.formDirty = false; }
  catch (e) { alertError(e); }
};
$("btnPause").onclick = () => post(S.state === "PAUSED" ? "/api/resume" : "/api/pause").catch(alertError);
$("btnStop").onclick = async () => {
  if (await confirmModal("Stop the demo", "Stop now? The point in progress is not estimated (its orientations stay saved).", "Stop", "stop"))
    post("/api/stop").catch(alertError);
};
$("btnTarget").onclick = () => post("/api/target", { x: num("mx"), y: num("my"), z: num("mz") })
  .then(() => { S.pick = null; invalidate(); }).catch(alertError);
$("btnClearQueue").onclick = () => post("/api/queue/clear").catch(alertError);

/* ============================================================
   real vs estimated view (top and 3D)
   ============================================================ */
const mapCv = $("map");
const staticCv = document.createElement("canvas");
let staticKey = "", proj = null, hoverPts = [];

function makeTop(w, h) {
  const [xmin, ymin] = S.box.min, [xmax, ymax] = S.box.max;
  const m = { l: 12, r: 58, t: 12, b: 38 }, aw = w - m.l - m.r, ah = h - m.t - m.b;
  const s = Math.min(aw / (ymax - ymin), ah / (xmax - xmin));
  const ox = m.l + (aw - (ymax - ymin) * s) / 2, oy = m.t + (ah - (xmax - xmin) * s) / 2;
  const PX = (y) => ox + (ymax - y) * s, PY = (x) => oy + (xmax - x) * s;
  return { kind: "top", s, PX, PY, P: (x, y) => [PX(y), PY(x)], inv: (px, py) => [xmax - (py - oy) / s, ymax - (px - ox) / s],
    lim: { xmin, xmax, ymin, ymax } };
}
function make3D(w, h) {
  const [xmin, ymin, zmin] = S.box.min, [xmax, ymax, zmax] = S.box.max;
  const zTopDraw = S.led ? zmax + 0.45 * (zmax - zmin) : zmax;   // room above the box for the LED marker
  const cx = (xmin + xmax) / 2, cy = (ymin + ymax) / 2, cz = (zmin + zmax) / 2;
  const ps = (cam.yaw * Math.PI) / 180, pe = (cam.elev * Math.PI) / 180;
  const cps = Math.cos(ps), sps = Math.sin(ps), cpe = Math.cos(pe), spe = Math.sin(pe);
  const raw = (x, y, z) => {
    const a = -(y - cy), b = x - cx, c = z - cz;
    const a1 = a * cps - b * sps, b1 = a * sps + b * cps;
    return [a1, c * cpe + b1 * spe, c * spe - b1 * cpe];
  };
  let u0 = Infinity, u1 = -Infinity, v0 = Infinity, v1 = -Infinity;
  for (const x of [xmin, xmax]) for (const y of [ymin, ymax]) for (const z of [zmin, zTopDraw]) {
    const [u, v] = raw(x, y, z);
    u0 = Math.min(u0, u); u1 = Math.max(u1, u); v0 = Math.min(v0, v); v1 = Math.max(v1, v);
  }
  const s = cam.zoom * Math.min((w - 90) / (u1 - u0), (h - 50) / (v1 - v0));
  const ou = w / 2 - ((u0 + u1) / 2) * s, ov = h / 2 + ((v0 + v1) / 2) * s;
  return { kind: "3d", s, P: (x, y, z) => { const [u, v, d] = raw(x, y, z); return [ou + u * s, ov - v * s, d]; },
    lim: { xmin, xmax, ymin, ymax, zmin, zmax }, ledZ: zTopDraw };
}

function renderView() {
  const { ctx, w, h, dpr } = fitCanvas(mapCv);
  ctx.clearRect(0, 0, w, h);
  if (!S.box) return;
  const done = shownDone();
  const key = [S.view, w, h, dpr, S.done.length, $("showSel").value, mag(), cam.yaw, cam.elev, cam.zoom, S.mode,
    S.config ? S.config.region_x.join() + S.config.region_y.join() : ""].join("|");
  if (key !== staticKey) {
    staticCv.width = Math.round(w * dpr); staticCv.height = Math.round(h * dpr);
    const sctx = staticCv.getContext("2d");
    sctx.setTransform(dpr, 0, 0, dpr, 0, 0); sctx.clearRect(0, 0, w, h);
    proj = S.view === "3d" ? make3D(w, h) : makeTop(w, h);
    (S.view === "3d" ? static3D : staticTop)(sctx, w, h);
    drawPoints(sctx, done);
    staticKey = key;
  }
  ctx.drawImage(staticCv, 0, 0, w, h);
  drawDynamic(ctx);
}

function staticTop(ctx, w, h) {
  const { PX, PY, s, lim } = proj, { xmin, xmax, ymin, ymax } = lim;
  ctx.fillStyle = "#fbfbfc"; ctx.fillRect(PX(ymax), PY(xmax), (ymax - ymin) * s, (xmax - xmin) * s);
  const step = niceStep(Math.max(xmax - xmin, ymax - ymin), 7);
  ctx.font = "11px Consolas, monospace"; ctx.fillStyle = COL.text;
  for (let v = Math.ceil(ymin / step) * step; v <= ymax + 1e-9; v += step) {
    line(ctx, [[PX(v), PY(xmin)], [PX(v), PY(xmax)]], COL.grid); ctx.textAlign = "center"; ctx.fillText(fmtG(v), PX(v), PY(xmin) + 15);
  }
  for (let v = Math.ceil(xmin / step) * step; v <= xmax + 1e-9; v += step) {
    line(ctx, [[PX(ymin), PY(v)], [PX(ymax), PY(v)]], COL.grid); ctx.textAlign = "left"; ctx.fillText(fmtG(v), PX(ymin) + 6, PY(v) + 4);
  }
  ctx.strokeStyle = COL.frame; ctx.lineWidth = 1; ctx.strokeRect(PX(ymax), PY(xmax), (ymax - ymin) * s, (xmax - xmin) * s);
  ctx.fillStyle = COL.text; ctx.textAlign = "center"; ctx.font = "12px Segoe UI, Arial";
  ctx.fillText("Y [mm]", PX((ymin + ymax) / 2), PY(xmin) + 32);
  ctx.save(); ctx.translate(PX(ymin) + 50, PY((xmin + xmax) / 2)); ctx.rotate(-Math.PI / 2); ctx.fillText("X [mm]", 0, 0); ctx.restore();
  const O = [PX(ymin), PY(xmin)], L = Math.min(60, 0.14 * (xmax - xmin) * s);
  arrow(ctx, O, [O[0], O[1] - L], COL.x, "X"); arrow(ctx, O, [O[0] - L, O[1]], COL.y, "Y");
  if (S.config && S.mode === "random") {                    // random region
    const c = S.config, x0 = PX(c.region_y[1]), y0 = PY(c.region_x[1]);
    ctx.strokeStyle = "rgba(36,82,122,0.45)"; ctx.setLineDash([5, 4]); ctx.lineWidth = 1.2;
    ctx.strokeRect(x0, y0, (c.region_y[1] - c.region_y[0]) * s, (c.region_x[1] - c.region_x[0]) * s); ctx.setLineDash([]);
  }
  if (S.led) {
    const [x, y] = proj.P(S.led[0], S.led[1]);
    star(ctx, x, y, 10, COL.led, "#8a6d00");
    ctx.fillStyle = COL.ink; ctx.font = "11px Segoe UI, Arial"; ctx.textAlign = "left";
    ctx.fillText(`LED ${fmtG(S.ledFreq)} kHz (${(S.led[2] / 1e3).toFixed(2)} m)`, x + 12, y + 4);
  }
}

function static3D(ctx, w, h) {
  const { P, lim, ledZ } = proj, { xmin, xmax, ymin, ymax, zmin, zmax } = lim;
  const step = niceStep(Math.max(xmax - xmin, ymax - ymin), 7);
  for (let v = Math.ceil(xmin / step) * step; v <= xmax + 1e-9; v += step) line(ctx, [P(v, ymin, zmin), P(v, ymax, zmin)], COL.grid);
  for (let v = Math.ceil(ymin / step) * step; v <= ymax + 1e-9; v += step) line(ctx, [P(xmin, v, zmin), P(xmax, v, zmin)], COL.grid);
  const corners = [];
  for (const x of [xmin, xmax]) for (const y of [ymin, ymax]) for (const z of [zmin, zmax]) corners.push([x, y, z]);
  for (let i = 0; i < 8; i++) for (let j = i + 1; j < 8; j++) {
    if (corners[i].reduce((n, v, k) => n + (v !== corners[j][k] ? 1 : 0), 0) === 1) line(ctx, [P(...corners[i]), P(...corners[j])], COL.frame);
  }
  ctx.font = "10.5px Consolas, monospace"; ctx.fillStyle = COL.text; ctx.textAlign = "center";
  for (let v = Math.ceil(xmin / step) * step; v <= xmax + 1e-9; v += step) { const [x, y] = P(v, ymin - 60, zmin); ctx.fillText(fmtG(v), x, y + 4); }
  for (let v = Math.ceil(ymin / step) * step; v <= ymax + 1e-9; v += step) { const [x, y] = P(xmin - 60, v, zmin); ctx.fillText(fmtG(v), x, y + 4); }
  const zstep = niceStep(zmax - zmin, 4);
  const [ex, ey] = [[xmin, ymin], [xmin, ymax], [xmax, ymin], [xmax, ymax]]
    .reduce((best, c) => (P(c[0], c[1], zmin)[0] < P(best[0], best[1], zmin)[0] ? c : best));
  ctx.textAlign = "right";
  for (let v = Math.ceil(zmin / zstep) * zstep; v <= zmax + 1e-9; v += zstep) { const [x, y] = P(ex, ey, v); ctx.fillText(fmtG(v), x - 6, y + 4); }
  { const [x, y] = P(ex, ey, zmax); ctx.fillText("Z height [mm]", x - 6, y - 14); }
  const o = P(xmin, ymin, zmin), L = 0.2 * (xmax - xmin);
  arrow(ctx, o, P(xmin + L, ymin, zmin), COL.x, "X"); arrow(ctx, o, P(xmin, ymin + L, zmin), COL.y, "Y");
  arrow(ctx, o, P(xmin, ymin, zmin + 0.6 * (zmax - zmin)), COL.z, "Z");
  if (S.led) {
    const top = P(S.led[0], S.led[1], ledZ), bottom = P(S.led[0], S.led[1], zmax);
    line(ctx, [top, bottom], "rgba(138,109,0,0.6)", 1.2, [4, 4]);
    line(ctx, [P(S.led[0], S.led[1], zmin), bottom], "rgba(138,109,0,0.25)", 1, [2, 4]);
    star(ctx, top[0], top[1], 10, COL.led, "#8a6d00");
    ctx.fillStyle = COL.ink; ctx.font = "11px Segoe UI, Arial"; ctx.textAlign = "left";
    ctx.fillText(`LED ↑ ${(S.led[2] / 1e3).toFixed(2)} m (not to scale)`, top[0] + 12, top[1] + 4);
  }
}

function drawPoints(ctx, done) {
  hoverPts = [];
  const P = (v) => proj.P(v[0], v[1], v[2]);
  const pts = done.map((d) => ({ d, t: P(d.true), e: d.est ? P(drawnEst(d.true, d.est)) : null }));
  if (proj.kind === "3d") pts.sort((a, b) => a.t[2] - b.t[2]);
  const r = done.length > 300 ? 3.2 : 4.6;
  for (const { d, t, e } of pts) {
    if (e) line(ctx, [t, e], COL.link, 1.2);
    ctx.lineWidth = 1.4; ctx.strokeStyle = COL.truth; ctx.fillStyle = "#fff";
    ctx.beginPath(); ctx.arc(t[0], t[1], r, 0, 7); ctx.fill(); ctx.stroke();
    hoverPts.push({ x: t[0], y: t[1], d });
    if (e) {
      ctx.fillStyle = errColor(d.err_3d_mm); ctx.strokeStyle = "rgba(0,0,0,0.35)"; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.arc(e[0], e[1], r, 0, 7); ctx.fill(); ctx.stroke();
      hoverPts.push({ x: e[0], y: e[1], d });
    } else {
      line(ctx, [[t[0] - r, t[1] - r], [t[0] + r, t[1] + r]], COL.fail, 1.4);
    }
  }
}

function drawDynamic(ctx) {
  const P = (v) => proj.P(v[0], v[1], v[2]);
  for (const [i, q] of S.queue.entries()) {                   // queued manual positions
    const [x, y] = proj.kind === "top" ? proj.P(q[0], q[1]) : P([q[0], q[1], gantryToHeight(q[2])]);
    ctx.strokeStyle = COL.target; ctx.lineWidth = 1.6; ctx.strokeRect(x - 5, y - 5, 10, 10);
    ctx.fillStyle = COL.target; ctx.font = "600 11px Segoe UI, Arial"; ctx.textAlign = "left"; ctx.fillText(String(i + 1), x + 7, y - 6);
  }
  if (S.pick && proj.kind === "top") {
    const [x, y] = proj.P(S.pick[0], S.pick[1]);
    line(ctx, [[x - 9, y], [x + 9, y]], COL.target, 1.4); line(ctx, [[x, y - 9], [x, y + 9]], COL.target, 1.4);
  }
  const c = S.current;
  if (c && BUSY.includes(S.state)) {
    const [x, y] = P(c.true_cmd_mm);
    ctx.strokeStyle = COL.target; ctx.lineWidth = 2.2; ctx.beginPath(); ctx.arc(x, y, 10, 0, 7); ctx.stroke();
    if (c.result && c.result.ok) {
      const t = P(c.result.true), e = P(drawnEst(c.result.true, c.result.est));
      line(ctx, [t, e], COL.ink, 2);
      ctx.fillStyle = errColor(c.result.err_3d_mm); ctx.strokeStyle = COL.ink; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.arc(e[0], e[1], 7, 0, 7); ctx.fill(); ctx.stroke();
    }
  }
  if (S.tel) {
    const [x, y] = P(S.tel.phys);
    if (proj.kind === "3d") {
      const [fx, fy] = P([S.tel.phys[0], S.tel.phys[1], proj.lim.zmin]);
      line(ctx, [[x, y], [fx, fy]], "rgba(31,119,180,0.6)", 1, [3, 3]);
    }
    ctx.fillStyle = COL.pd; ctx.strokeStyle = "#fff"; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(x, y, 6, 0, 7); ctx.fill(); ctx.stroke();
    ctx.strokeStyle = "#0d3b66"; ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(x, y, 7.2, 0, 7); ctx.stroke();
  }
}
const gantryToHeight = (z) => {                   // queued gantry z -> approximate PD height (display only)
  if (!S.box || !S.workspace) return z;
  const [zg0, zg1] = [S.workspace.max[2], S.workspace.min[2]], [h0, h1] = [S.box.min[2], S.box.max[2]];
  return h0 + ((z - zg0) / (zg1 - zg0)) * (h1 - h0);
};

function renderLegend() {
  const grad = `linear-gradient(90deg, ${[0, 0.25, 0.5, 0.75, 1].map((t) => errColor(t * ERR_SCALE_MM)).join(",")})`;
  $("legend").innerHTML =
    `<span><i style="background:#fff;border:1.4px solid ${COL.truth}"></i>real position</span>` +
    `<span><i style="background:${errColor(30)};border:1px solid rgba(0,0,0,.35)"></i>estimated (colour = 3D error` +
    `${mag() > 1 ? `, error drawn ×${mag()}` : ""})</span>` +
    `<span>0<span class="grad" style="background:${grad}"></span>${ERR_SCALE_MM / 10} cm</span>` +
    `<span><i style="background:#fff;border:2px solid ${COL.target}"></i>current point</span>` +
    `<span><i style="background:${COL.pd};border:1px solid #0d3b66"></i>PD (live)</span>` +
    `<span>Z = PD height above the floor</span>`;
}

/* interaction: orbit, tooltip, pick */
let drag = null;
mapCv.addEventListener("mousedown", (e) => { if (S.view === "3d") drag = { x: e.clientX, y: e.clientY, yaw: cam.yaw, elev: cam.elev, moved: false }; });
window.addEventListener("mouseup", () => { drag = null; });
window.addEventListener("mousemove", (e) => {
  if (!drag) return;
  cam.yaw = drag.yaw + (e.clientX - drag.x) * 0.4;
  cam.elev = Math.max(-5, Math.min(90, drag.elev + (e.clientY - drag.y) * 0.4));
  $("tooltip").style.display = "none"; invalidate();
});
mapCv.addEventListener("wheel", (e) => {
  if (S.view !== "3d") return;
  e.preventDefault(); cam.zoom = Math.max(0.4, Math.min(6, cam.zoom * (e.deltaY < 0 ? 1.12 : 1 / 1.12))); invalidate();
}, { passive: false });
mapCv.addEventListener("dblclick", () => { if (S.view === "3d") { Object.assign(cam, { yaw: 32, elev: 22, zoom: 1 }); invalidate(); } });
mapCv.addEventListener("click", (ev) => {
  if (S.view !== "top" || !proj || proj.kind !== "top") return;
  const rect = mapCv.getBoundingClientRect(), [x, y] = proj.inv(ev.clientX - rect.left, ev.clientY - rect.top);
  const L = proj.lim;
  if (x < L.xmin || x > L.xmax || y < L.ymin || y > L.ymax) return;
  S.pick = [Math.round(x / 10) * 10, Math.round(y / 10) * 10];
  $("mx").value = S.pick[0]; $("my").value = S.pick[1];
  if (S.mode !== "manual") { S.mode = "manual"; renderModeUi(); if (BUSY.includes(S.state)) post("/api/mode", { mode: "manual" }).catch(alertError); }
  if (!S.focus) setConfigOpen(true);
  invalidate();
});
mapCv.addEventListener("mousemove", (ev) => {
  const tip = $("tooltip");
  if (drag || !hoverPts.length) { tip.style.display = "none"; return; }
  const rect = mapCv.getBoundingClientRect(), mx = ev.clientX - rect.left, my = ev.clientY - rect.top;
  let best = null, bd = 9;
  for (const p of hoverPts) { const d = Math.hypot(p.x - mx, p.y - my); if (d < bd) { bd = d; best = p; } }
  if (!best) { tip.style.display = "none"; return; }
  const d = best.d, v3 = (v) => (v ? v.map((x) => fmt(x, 1)).join(", ") : "–");
  tip.textContent = `point ${d.id} (${d.origin}, K = ${d.K})\nreal       ${v3(d.true)} mm\nestimated  ${v3(d.est)} mm\n` +
    (d.ok ? `error      ${cm(d.err_3d_mm)} cm (horizontal ${cm(d.err_h_mm)}, vertical ${cm(d.err[2])})` : `status     ${d.status}`);
  tip.style.display = "block";
  tip.style.left = `${Math.min(mx + 14, rect.width - 330)}px`; tip.style.top = `${my + 12}px`;
});
mapCv.addEventListener("mouseleave", () => { $("tooltip").style.display = "none"; });

/* ============================================================
   RSS per orientation (polar: MTRS angle around, RSS radial)
   ============================================================ */
const rssCv = $("rssCv");
function drawRss() {
  const { ctx, w, h } = fitCanvas(rssCv);
  ctx.clearRect(0, 0, w, h);
  const cx = w / 2, cy = h / 2 + 8, R = Math.min(w, h) / 2 - 28;
  if (R < 10) return;                     // no room (e.g. panel hidden): arc() would throw
  const base = { N: -90, E: 0, S: 90, W: 180 }[S.viewCfg.mtrs_zero_location || "N"] ?? -90;
  const dir = S.viewCfg.mtrs_clockwise ? 1 : -1;
  const P = (deg, r) => { const a = ((base + dir * deg) * Math.PI) / 180; return [cx + r * Math.cos(a), cy + r * Math.sin(a)]; };
  const c = rssPoint();
  const vals = c ? c.rss_mV.filter((v) => v !== null) : [];
  const fit = c && c.fit && c.fit.rss_mV ? c.fit.rss_mV : null;
  let vmax = Math.max(1e-3, ...vals, ...(fit || []));
  const step = niceStep(vmax, 4); vmax = Math.ceil((vmax * 1.05) / step) * step;
  const Rv = (v) => (Math.max(0, v) / vmax) * R;
  ctx.fillStyle = "#fbfbfc"; ctx.strokeStyle = COL.frame; ctx.lineWidth = 1;
  ctx.beginPath(); ctx.arc(cx, cy, R, 0, 7); ctx.fill(); ctx.stroke();
  ctx.font = "10px Consolas, monospace"; ctx.fillStyle = COL.text; ctx.textAlign = "left";
  for (let v = step; v < vmax - 1e-9; v += step) {
    ctx.strokeStyle = COL.grid; ctx.beginPath(); ctx.arc(cx, cy, Rv(v), 0, 7); ctx.stroke();
    const [lx, ly] = P(45, Rv(v)); ctx.fillText(`${fmtG(+v.toPrecision(3))}`, lx + 2, ly);
  }
  for (let d = 0; d < 360; d += 30) line(ctx, [P(d, R), P(d, R - (d % 90 ? 4 : 8))], d % 90 ? COL.pending : COL.ink, 1);
  ctx.textAlign = "center"; ctx.textBaseline = "middle"; ctx.font = "10.5px Consolas, monospace"; ctx.fillStyle = COL.text;
  for (const d of [0, 90, 180, 270]) { const [x, y] = P(d, R + 12); ctx.fillText(`${d}°`, x, y); }
  ctx.textBaseline = "alphabetic";
  if (c) {
    c.angles.forEach((a, k) => line(ctx, [[cx, cy], P(a, R)], "rgba(154,164,177,0.6)", 1, [2, 3]));
    if (fit) {                                                  // fitted model after the estimate
      const pts = c.fit.angles.map((a, i) => P(a, Rv(fit[i])));
      pts.push(pts[0]); line(ctx, pts, COL.fit, 1.8);
    }
    c.angles.forEach((a, k) => {
      const v = c.rss_mV[k];
      if (v === null) return;
      ctx.lineCap = "round"; line(ctx, [[cx, cy], P(a, Rv(v))], COL.rss, 6); ctx.lineCap = "butt";
      const [x, y] = P(a, Rv(v)); ctx.fillStyle = "#fff"; ctx.strokeStyle = COL.rss; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.arc(x, y, 3.5, 0, 7); ctx.fill(); ctx.stroke();
    });
    if (c === S.current && c.active_k !== null && c.active_k !== undefined && BUSY.includes(S.state)) {
      const [x, y] = P(c.angles[c.active_k], R - 6);
      ctx.strokeStyle = COL.active; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(x, y, 7, 0, 7); ctx.stroke();
    }
  }
  if (S.tel) {                                                   // live MTRS angle
    line(ctx, [[cx, cy], P(S.tel.angle, R + 2)], "rgba(31,41,51,0.75)", 1.4);
    ctx.fillStyle = COL.ink; ctx.beginPath(); ctx.arc(cx, cy, 3, 0, 7); ctx.fill();
    ctx.textAlign = "left"; ctx.font = "14px Consolas, monospace"; ctx.fillText(`${S.tel.angle.toFixed(2)}°`, 4, 16);
    ctx.font = "11px Segoe UI, Arial"; ctx.fillStyle = COL.text; ctx.fillText(S.tel.moving ? "MTRS rotating" : "MTRS stationary", 4, 31);
  }
  ctx.textAlign = "right"; ctx.font = "11px Segoe UI, Arial"; ctx.fillStyle = COL.text;
  ctx.fillText("RSS [mV]", w - 4, 14);
  if (fit) { ctx.fillStyle = COL.fit; ctx.fillText("— fitted model", w - 4, 29); }
  ctx.fillStyle = COL.rss; ctx.fillText("▮ measured", w - 4, fit ? 44 : 29);
}

/* ============================================================
   error plots: per point and CDF
   ============================================================ */
const histCv = $("histCv"), cdfCv = $("cdfCv");
let histBars = [];                        // [{x0, x1, d}] slot of every bar, for the hover tooltip
function drawHist() {
  const { ctx, w, h } = fitCanvas(histCv);
  ctx.clearRect(0, 0, w, h);
  histBars = [];
  const m = { l: 40, r: 10, t: 10, b: 28 }, pts = S.done.slice(-80);
  const errs = pts.filter((d) => d.ok).map((d) => d.err_3d_mm / 10);
  let ymax = Math.max(1, ...errs) * 1.15;
  const step = niceStep(ymax, 4); ymax = Math.ceil(ymax / step) * step;
  const PY = (v) => h - m.b - (v / ymax) * (h - m.t - m.b);
  ctx.font = "10.5px Consolas, monospace"; ctx.fillStyle = COL.text; ctx.textAlign = "right";
  for (let v = 0; v <= ymax + 1e-9; v += step) { line(ctx, [[m.l, PY(v)], [w - m.r, PY(v)]], COL.grid); ctx.fillText(fmtG(v), m.l - 5, PY(v) + 3); }
  ctx.save(); ctx.translate(11, (h - m.b + m.t) / 2); ctx.rotate(-Math.PI / 2); ctx.textAlign = "center";
  ctx.font = "12px Segoe UI, Arial"; ctx.fillText("3D error [cm]", 0, 0); ctx.restore();
  ctx.strokeStyle = COL.frame; ctx.strokeRect(m.l + 0.5, m.t + 0.5, w - m.l - m.r, h - m.t - m.b);
  if (!pts.length) { ctx.textAlign = "center"; ctx.font = "12px Segoe UI, Arial"; ctx.fillText("No points yet.", (m.l + w) / 2, h / 2); return; }
  const n = Math.max(pts.length, 20), bw = (w - m.l - m.r) / n;
  pts.forEach((d, i) => {
    const x = m.l + i * bw + bw * 0.15;
    histBars.push({ x0: m.l + i * bw, x1: m.l + (i + 1) * bw, d });
    if (S.histHover === d.id) { ctx.fillStyle = "rgba(36,82,122,0.08)"; ctx.fillRect(m.l + i * bw, m.t, bw, h - m.t - m.b); }
    if (d.ok) {
      ctx.fillStyle = errColor(d.err_3d_mm); ctx.fillRect(x, PY(d.err_3d_mm / 10), bw * 0.7, PY(0) - PY(d.err_3d_mm / 10));
      if (S.histHover === d.id) { ctx.strokeStyle = COL.ink; ctx.lineWidth = 1.2; ctx.strokeRect(x, PY(d.err_3d_mm / 10), bw * 0.7, PY(0) - PY(d.err_3d_mm / 10)); }
    } else { ctx.fillStyle = COL.fail; ctx.font = "11px Segoe UI, Arial"; ctx.textAlign = "center"; ctx.fillText("×", x + bw * 0.35, PY(0) - 3); }
  });
  ctx.textAlign = "center"; ctx.fillStyle = COL.text; ctx.font = "10.5px Consolas, monospace";
  const every = Math.max(1, Math.ceil(pts.length / 12));
  pts.forEach((d, i) => { if (i % every === 0 || i === pts.length - 1) ctx.fillText(String(d.id), m.l + (i + 0.5) * bw, h - m.b + 13); });
  ctx.font = "12px Segoe UI, Arial"; ctx.fillText("point", (m.l + w - m.r) / 2, h - 2);
  const s = S.stats;
  if (s.mean_mm !== undefined) {
    line(ctx, [[m.l, PY(s.mean_mm / 10)], [w - m.r, PY(s.mean_mm / 10)]], COL.accent, 1.4, [6, 4]);
    line(ctx, [[m.l, PY(s.p90_mm / 10)], [w - m.r, PY(s.p90_mm / 10)]], COL.p90, 1.2, [2, 3]);
    ctx.textAlign = "right"; ctx.font = "11px Segoe UI, Arial";
    ctx.fillStyle = COL.accent; ctx.fillText(`mean ${cm(s.mean_mm)} cm`, w - m.r - 4, PY(s.mean_mm / 10) - 4);
    ctx.fillStyle = COL.p90; ctx.fillText(`P90 ${cm(s.p90_mm)} cm`, w - m.r - 4, PY(s.p90_mm / 10) - 4);
  }
}
histCv.addEventListener("mousemove", (ev) => {
  const tip = $("histTip"), rect = histCv.getBoundingClientRect(), mx = ev.clientX - rect.left, my = ev.clientY - rect.top;
  const bar = histBars.find((b) => mx >= b.x0 && mx < b.x1);
  const id = bar ? bar.d.id : null;
  if (id !== S.histHover) { S.histHover = id; S.plotsDirty = true; }
  if (!bar) { tip.style.display = "none"; return; }
  const d = bar.d;
  tip.textContent = d.ok ? `point ${d.id}: ${(d.err_3d_mm / 10).toFixed(2)} cm` : `point ${d.id}: no estimate (${d.status})`;
  tip.style.display = "block";
  tip.style.left = `${Math.min(mx + 12, rect.width - 190)}px`; tip.style.top = `${Math.max(0, my - 30)}px`;
});
histCv.addEventListener("mouseleave", () => {
  $("histTip").style.display = "none";
  if (S.histHover !== null) { S.histHover = null; S.plotsDirty = true; }
});

function drawCdf() {
  const { ctx, w, h } = fitCanvas(cdfCv);
  ctx.clearRect(0, 0, w, h);
  const m = { l: 34, r: 10, t: 10, b: 28 };
  const e = S.done.filter((d) => d.ok).map((d) => d.err_3d_mm / 10).sort((a, b) => a - b);
  let xmax = Math.max(1, e.length ? e[e.length - 1] : 1) * 1.05;
  const step = niceStep(xmax, 4); xmax = Math.ceil(xmax / step) * step;
  const PX = (v) => m.l + (v / xmax) * (w - m.l - m.r), PY = (p) => h - m.b - p * (h - m.t - m.b);
  ctx.font = "10.5px Consolas, monospace"; ctx.fillStyle = COL.text;
  for (let p = 0; p <= 1.0001; p += 0.25) { line(ctx, [[m.l, PY(p)], [w - m.r, PY(p)]], COL.grid); ctx.textAlign = "right"; ctx.fillText(p.toFixed(2), m.l - 4, PY(p) + 3); }
  for (let v = 0; v <= xmax + 1e-9; v += step) { line(ctx, [[PX(v), m.t], [PX(v), h - m.b]], COL.grid); ctx.textAlign = "center"; ctx.fillText(fmtG(v), PX(v), h - m.b + 13); }
  ctx.strokeStyle = COL.frame; ctx.strokeRect(m.l + 0.5, m.t + 0.5, w - m.l - m.r, h - m.t - m.b);
  ctx.font = "12px Segoe UI, Arial"; ctx.textAlign = "center"; ctx.fillText("3D error [cm]", (m.l + w - m.r) / 2, h - 2);
  if (!e.length) return;
  const pts = [[PX(0), PY(0)]];
  e.forEach((v, i) => { pts.push([PX(v), PY(i / e.length)]); pts.push([PX(v), PY((i + 1) / e.length)]); });
  pts.push([PX(xmax), PY(1)]);
  line(ctx, pts, COL.accent, 1.8);
  ctx.textAlign = "left"; ctx.font = "11px Segoe UI, Arial"; ctx.fillStyle = COL.text;
  ctx.fillText(`${e.length} points`, m.l + 6, m.t + 12);
}

/* ============================================================
   drawing loop and live connection
   ============================================================ */
let lastSize = "";
const visible = (cv) => cv.clientWidth > 0 && cv.clientHeight > 0;     // hidden panels (enlarged view) are not drawn
function safely(draw, cv) {               // an error in one panel must never stop the drawing loop
  if (cv && !visible(cv)) return;
  try { draw(); } catch (e) { console.error(e); }
}
function frame() {
  requestAnimationFrame(frame);           // scheduled first: the loop keeps running whatever happens below
  const size = `${mapCv.clientWidth}x${mapCv.clientHeight}|${histCv.clientWidth}|${rssCv.clientWidth}`;
  if (size !== lastSize) { lastSize = size; S.dirty = true; S.plotsDirty = true; }
  if (S.dirty) { S.dirty = false; safely(renderView, mapCv); safely(drawRss, rssCv); }
  if (S.plotsDirty) {
    S.plotsDirty = false; safely(drawHist, histCv); safely(drawCdf, cdfCv);
    $("errInfo").textContent = S.done.length ? `last ${Math.min(80, S.done.length)} points · CDF of all` : "";
  }
}
let lastStatsN = -1;
setInterval(() => { if (S.stats && S.stats.n !== lastStatsN) { lastStatsN = S.stats.n; S.plotsDirty = true; } }, 300);

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

renderLegend();
setView(S.view);
const QS = new URLSearchParams(location.search);
if (QS.has("snapshot")) {                         // ?snapshot=1: state loaded once (screenshots)
  if (QS.has("view")) setView(QS.get("view"));
  if (QS.has("config")) setConfigOpen(QS.get("config") === "1");
  if (QS.has("focus")) setFocus(QS.get("focus") === "1");
  fetch("/api/state").then((r) => r.json()).then((d) => { S.connected = true; applyFull(d); });
} else {
  connect();
}
requestAnimationFrame(frame);
