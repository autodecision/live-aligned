#!/usr/bin/env python3
"""Run Godot provider checks against a loopback-only fixture. No real accounts."""
import json
import pathlib
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Fixture(BaseHTTPRequestHandler):
    redirects_followed = 0
    def log_message(self, *_args):
        pass

    def reply(self, data, status=200, headers=None):
        payload = data if isinstance(data, bytes) else json.dumps(data).encode()
        try:
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            for key, value in (headers or {}).items():
                self.send_header(key, value)
            self.end_headers()
            self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError):
            pass  # Cancellation and oversized replies intentionally close sockets.

    def do_GET(self):
        if "/unauthorized/" in self.path:
            self.reply({"error": "must never echo fixture details"}, 401)
        elif "/rate-limit/" in self.path:
            self.reply({"error": "quota detail"}, 429)
        elif "/bad-json/" in self.path:
            self.reply(b"not json")
        elif "/redirect/" in self.path:
            self.reply({}, 307, {"Location": "/redirect-target"})
        elif self.path == "/redirect-target":
            Fixture.redirects_followed += 1
            self.reply({"error": "redirect must not be followed"}, 400)
        elif "/huge/" in self.path:
            self.reply(b"x" * (2097152 + 1))
        elif "/slow/" in self.path:
            time.sleep(2)
            self.reply({"data": [{"id": "late"}]})
        else:
            self.reply({"data": [{"id": "fixture-z"}, {"id": "fixture-a"}, {"id": "fixture-a"}]})

    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        body = json.loads(raw)
        try:
            assert body["model"] == "fixture-model" and body["stream"] is False
            if self.path.endswith("/responses"):
                assert body["store"] is False and body["max_output_tokens"] == 512
                assert body["input"][0]["role"] == "system"
                assert self.headers.get("Authorization") == "Bearer fixture-secret"
                self.reply({"output": [{"type": "reasoning", "content": []}, {"type": "message", "content": [{"type": "output_text", "text": "responses fixture"}]}]})
            elif self.path.endswith("/messages"):
                assert body["system"] == "Be kind." and body["max_tokens"] == 512
                assert all(row["role"] != "system" for row in body["messages"])
                assert self.headers.get("x-api-key") == "fixture-secret"
                assert self.headers.get("anthropic-version") == "2023-06-01"
                self.reply({"content": [{"type": "thinking", "thinking": "hidden"}, {"type": "text", "text": "anthropic_messages fixture"}]})
            else:
                assert body["messages"][0]["role"] == "system" and body["max_tokens"] == 512
                assert self.headers.get("Authorization") == "Bearer fixture-secret"
                self.reply({"choices": [{"message": {"content": "chat_completions fixture", "reasoning_content": "hidden"}}]})
        except (AssertionError, KeyError):
            self.reply({"error": "fixture request contract failed"}, 400)


if __name__ == "__main__":
    project = pathlib.Path(__file__).resolve().parents[1]
    server = ThreadingHTTPServer(("127.0.0.1", 0), Fixture)
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    try:
        result = subprocess.run(
            ["godot", "--headless", "--path", str(project), "--script", "res://scripts/check_ai_providers.gd", "--", f"--fixture-url=http://127.0.0.1:{server.server_port}/v1"],
            timeout=60, check=False,
        )
    finally:
        server.shutdown()
        server.server_close()
    if Fixture.redirects_followed:
        raise AssertionError("Credential-bearing redirects must not be followed")
    raise SystemExit(result.returncode)
