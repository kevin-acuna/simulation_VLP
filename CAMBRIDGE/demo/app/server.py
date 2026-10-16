"""
server.py - Local server (standard library only) between the web interface and the DemoEngine.

  GET  /                  interface (web/index.html) and /static/* (css, js)
  GET  /api/state         full state
  GET  /api/events        live stream (Server-Sent Events, ~10 Hz)
  POST /api/check         {config} -> validation (errors, warnings, normalized config)
  POST /api/start         {config}
  POST /api/pause | /api/resume | /api/stop
  POST /api/target        {x, y, z} gantry position [mm] -> queued (measured next)
  POST /api/queue/clear
  POST /api/mode          {mode: "random" | "manual"}

Listens on 127.0.0.1 by default: the interface is local to the lab PC.
"""

import json
import mimetypes
import os
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from storage import _clean

WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "web")
STREAM_PERIOD_S = 0.1


class Handler(BaseHTTPRequestHandler):
    engine = None
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        pass

    def _send(self, code, body, ctype="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(_clean(body)).encode()
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
            body = self._body()
            if path == "/api/check":
                c, errors, warnings = e.check_config(body.get("config", {}))
                return self._send(200, {"ok": not errors, "errors": errors, "warnings": warnings, "config": c})
            if path == "/api/start":
                e.start(body.get("config", {}))
            elif path == "/api/target":
                e.add_target([body["x"], body["y"], body["z"]])
            elif path == "/api/mode":
                e.set_mode(body.get("mode", "random"))
            else:
                actions = {"/api/pause": e.pause, "/api/resume": e.resume, "/api/stop": e.stop,
                           "/api/queue/clear": e.clear_queue}
                if path not in actions:
                    return self._send(404, {"error": "not found"})
                actions[path]()
            return self._send(200, {"ok": True})
        except Exception as ex:
            self._send(400, {"ok": False, "error": str(ex)})

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
                self.wfile.write(b"data: " + json.dumps(_clean(payload)).encode() + b"\n\n")
                self.wfile.flush()
                time.sleep(STREAM_PERIOD_S)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError, OSError):
            pass


class Server(ThreadingHTTPServer):
    daemon_threads = True

    def handle_error(self, request, client_address):
        if isinstance(sys.exc_info()[1], (ConnectionAbortedError, ConnectionResetError, BrokenPipeError)):
            return
        super().handle_error(request, client_address)


def make_server(engine, host="127.0.0.1", port=8766, tries=10):
    Handler.engine = engine
    for p in range(port, port + tries):
        try:
            return Server((host, p), Handler)
        except OSError:
            continue
    raise RuntimeError(f"No free port in {port}-{port + tries - 1}")


def serve_in_thread(server):
    t = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.2}, daemon=True)
    t.start()
    return t
