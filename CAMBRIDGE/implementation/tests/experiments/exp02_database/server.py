"""
server.py - Servidor local (solo libreria estandar) entre la interfaz web y el Engine.

  GET  /                 interfaz (web/index.html) y /static/* (css, js)
  GET  /api/state        estado completo (plan, mediciones hechas, equipos, telemetria)
  GET  /api/events       transmision en vivo (Server-Sent Events, ~10 Hz)
  POST /api/plan         {config} -> plan + validacion + estimacion
  POST /api/start | /api/pause | /api/resume | /api/stop
  POST /api/scope/refresh   relee la configuracion del osciloscopio

Escucha solo en 127.0.0.1: la interfaz es local al PC del laboratorio.
"""

import json
import mimetypes
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "web")
STREAM_PERIOD_S = 0.1


class Handler(BaseHTTPRequestHandler):
    engine = None
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):          # sin ruido en la consola
        pass

    # ---------------------------------------------------------------
    def _send(self, code, body, ctype="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n) or b"{}") if n else {}

    def do_GET(self):
        path = self.path.split("?")[0]
        if path in ("/", "/index.html"):
            return self._file("index.html")
        if path.startswith("/static/"):
            return self._file(path[len("/static/"):])
        if path == "/api/state":
            return self._send(200, self.engine.full_state())
        if path == "/api/events":
            return self._stream()
        self._send(404, {"error": "not found"})

    def do_POST(self):
        e, path = self.engine, self.path.split("?")[0]
        try:
            if path == "/api/plan":
                res = e.make_plan(self._body().get("config", {}))
                return self._send(200, {"ok": res["ok"], "errors": res.get("errors", []),
                                        "warnings": res.get("warnings", []),
                                        "state": e.full_state()})
            actions = {"/api/start": e.start, "/api/pause": e.pause, "/api/resume": e.resume,
                       "/api/stop": e.stop, "/api/scope/refresh": e.refresh_scope}
            if path in actions:
                actions[path]()
                return self._send(200, {"ok": True})
            self._send(404, {"error": "not found"})
        except Exception as ex:
            self._send(400, {"ok": False, "error": str(ex)})

    # ---------------------------------------------------------------
    def _file(self, name):
        full = os.path.normpath(os.path.join(WEB_DIR, name))
        if not full.startswith(WEB_DIR) or not os.path.isfile(full):
            return self._send(404, {"error": "not found"})
        ctype = mimetypes.guess_type(full)[0] or "application/octet-stream"
        if ctype.startswith("text/") or ctype.endswith("javascript"):
            ctype += "; charset=utf-8"
        with open(full, "rb") as f:
            self._send(200, f.read(), ctype)

    def _stream(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Connection", "keep-alive")
        self.end_headers()
        e, cursor = self.engine, None
        try:
            while not e._shutdown.is_set():
                if cursor is None:
                    payload = e.full_state()
                    cursor = payload["cursor"]
                else:
                    payload, new = e.update(cursor)
                    if payload is None:
                        cursor = None
                        continue
                    cursor = new
                self.wfile.write(b"data: " + json.dumps(payload).encode() + b"\n\n")
                self.wfile.flush()
                time.sleep(STREAM_PERIOD_S)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError, OSError):
            pass


def make_server(engine, host="127.0.0.1", port=8765, tries=10):
    Handler.engine = engine
    for p in range(port, port + tries):
        try:
            srv = ThreadingHTTPServer((host, p), Handler)
            srv.daemon_threads = True
            return srv
        except OSError:
            continue
    raise RuntimeError(f"No free port in {port}-{port + tries - 1}")


def serve_in_thread(server):
    t = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.2}, daemon=True)
    t.start()
    return t
