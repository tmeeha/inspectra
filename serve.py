#!/usr/bin/env python3
"""Serve this folder on http://localhost and open it in the default browser.

The server listens on this computer only (127.0.0.1), so nothing is reachable from the
network or the internet. Close the window or press Ctrl+C to stop it.
Options: --port N (first port to try, default 8000), --no-browser.
"""
import argparse, functools, http.server, os, socket, sys, threading, webbrowser

ap = argparse.ArgumentParser()
ap.add_argument("--port", type=int, default=8000)
ap.add_argument("--no-browser", action="store_true")
args = ap.parse_args()

root = os.path.dirname(os.path.abspath(__file__))
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=root)

server = None
for port in range(args.port, args.port + 50):          # first free port
    try:
        server = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
        break
    except OSError:
        continue
if server is None:
    sys.exit(f"Could not find a free port from {args.port} to {args.port + 49}.")

url = f"http://localhost:{port}/"
print(f"Serving {root}\nOpen {url}  (this computer only)\nPress Ctrl+C or close this window to stop.")
if not args.no_browser:
    threading.Timer(0.5, webbrowser.open, args=(url,)).start()
try:
    server.serve_forever()
except KeyboardInterrupt:
    print("\nStopped.")
