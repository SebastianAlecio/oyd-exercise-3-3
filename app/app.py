import os, json
from http.server import HTTPServer, BaseHTTPRequestHandler

COMPUTE = os.getenv("COMPUTE_TYPE", "eks")

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            body = json.dumps({"status": "ok", "compute": COMPUTE}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(body)

    def do_POST(self):
        if self.path == "/echo":
            n = int(self.headers.get("Content-Length", 0))
            data = json.loads(self.rfile.read(n))
            data["compute"] = COMPUTE
            out = json.dumps(data).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(out)

    def log_message(self, *a): pass

if __name__ == "__main__":
    HTTPServer(("", 8080), Handler).serve_forever()
