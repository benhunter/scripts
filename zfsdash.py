#!/usr/bin/env python3
import re
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer

HOST = "0.0.0.0"
PORT = 8787

def get_zpool_status() -> str:
    p = subprocess.run(
        ["/sbin/zpool", "status", "-P"],
        capture_output=True,
        text=True,
        timeout=5,
    )
    out = p.stdout if p.returncode == 0 else (p.stdout + "\n" + p.stderr)
    return out.rstrip("\n")

def parse_resilver_info(zpool_output: str) -> dict:
    """
    Tries to extract resilver progress/ETA from the 'scan:' line(s) of `zpool status`.

    Common patterns include:
      scan: resilver in progress since ...
            ... , 28.4% done, 0 days 12:34:56 to go

    Returns:
      {
        "active": bool,
        "state": str,        # e.g., "resilver in progress", "scrub repaired ...", etc.
        "pct_done": float|None,
        "eta": str|None      # the trailing "X to go" portion, without "to go"
      }
    """
    lines = zpool_output.splitlines()

    scan_line = None
    for i, line in enumerate(lines):
        if line.strip().startswith("scan:"):
            # Include up to a couple continuation lines (indented) because zpool status wraps
            buf = [line.strip()]
            for j in range(i + 1, min(i + 4, len(lines))):
                if lines[j].startswith(" ") or lines[j].startswith("\t"):
                    buf.append(lines[j].strip())
                else:
                    break
            scan_line = " ".join(buf)
            break

    if not scan_line:
        return {"active": False, "state": "scan: (not found)", "pct_done": None, "eta": None}

    # Example scan_line:
    # "scan: resilver in progress since ... 1.23T resilvered, 28.4% done, 0 days 12:34:56 to go"
    # We'll keep the 'scan:' prefix out of the state.
    state = scan_line
    if state.lower().startswith("scan:"):
        state = state[5:].strip()

    # Determine whether it's a resilver in progress
    active = bool(re.search(r"\bresilver\b", state, re.IGNORECASE) and re.search(r"\bin progress\b", state, re.IGNORECASE))

    # Percent done (optional)
    pct_done = None
    m_pct = re.search(r"(\d+(?:\.\d+)?)%\s+done", state)
    if m_pct:
        try:
            pct_done = float(m_pct.group(1))
        except ValueError:
            pct_done = None

    # ETA / remaining time (optional)
    eta = None
    m_eta = re.search(r",\s*([^,]+?)\s+to go\b", state)
    if m_eta:
        eta = m_eta.group(1).strip()
    else:
        # Some variants may not have a comma before ETA
        m_eta2 = re.search(r"\b(\d+\s+days?\s+)?\d{1,2}:\d{2}:\d{2}\s+to go\b", state)
        if m_eta2:
            eta = m_eta2.group(0).replace("to go", "").strip()

    return {"active": active, "state": state, "pct_done": pct_done, "eta": eta}

INDEX_HTML = """<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>ZFS zpool status</title>
  <style>
    body { margin: 16px; font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; }
    .bar { display:flex; gap:12px; align-items:center; margin-bottom:12px; flex-wrap: wrap; }
    button { padding: 6px 10px; cursor: pointer; }
    .meta { color:#666; font-size: 0.9rem; }

    .widget {
      border: 1px solid #ddd;
      border-radius: 12px;
      padding: 12px;
      margin-bottom: 12px;
      box-shadow: 0 1px 2px rgba(0,0,0,0.04);
    }
    .widget-title { font-size: 0.95rem; color:#444; margin-bottom: 6px; }
    .widget-row { display:flex; gap: 16px; flex-wrap: wrap; align-items: baseline; }
    .big { font-size: 1.25rem; font-weight: 650; }
    .kv { color:#555; }
    .pill {
      display:inline-block; padding: 2px 8px; border-radius: 999px;
      border: 1px solid #ddd; font-size: 0.85rem; color:#444;
    }

    pre { padding: 12px; border: 1px solid #ddd; border-radius: 12px; overflow:auto; }
  </style>
</head>
<body>

  <div class="bar">
    <button id="refresh">Refresh</button>
    <label class="meta">
      Auto-refresh:
      <select id="interval">
        <option value="0">off</option>
        <option value="2">2s</option>
        <option value="5" selected>5s</option>
        <option value="10">10s</option>
        <option value="30">30s</option>
      </select>
    </label>
    <span class="meta" id="stamp"></span>
  </div>

  <div class="widget" id="resilverWidget">
    <div class="widget-title">Resilver</div>
    <div class="widget-row">
      <div class="big" id="resilverHeadline">Loading...</div>
      <div class="kv" id="resilverDetail"></div>
    </div>
  </div>

  <pre id="out">Loading...</pre>

<script>
const out = document.getElementById("out");
const stamp = document.getElementById("stamp");
const intervalSel = document.getElementById("interval");

const resilverHeadline = document.getElementById("resilverHeadline");
const resilverDetail = document.getElementById("resilverDetail");

let timer = null;

function formatResilverWidget(r) {
  // r = { active, state, pct_done, eta }
  if (!r) {
    resilverHeadline.textContent = "Unknown";
    resilverDetail.textContent = "";
    return;
  }

  if (r.active) {
    // Headline: remaining time if present, else "In progress"
    const eta = r.eta ? r.eta : "In progress";
    resilverHeadline.innerHTML = `<span class="pill">ACTIVE</span> &nbsp; ${eta}`;

    // Detail: percent + state
    const pct = (typeof r.pct_done === "number") ? `${r.pct_done.toFixed(1)}% done` : null;
    const parts = [];
    if (pct) parts.push(pct);
    if (r.state) parts.push(r.state);
    resilverDetail.textContent = parts.join(" — ");
  } else {
    resilverHeadline.innerHTML = `<span class="pill">IDLE</span> &nbsp; No resilver in progress`;
    resilverDetail.textContent = r.state ? r.state : "";
  }
}

async function load() {
  try {
    const r = await fetch("/api/status", { cache: "no-store" });
    if (!r.ok) throw new Error("HTTP " + r.status);
    const data = await r.json();

    out.textContent = data.output || "";
    formatResilverWidget(data.resilver);

    stamp.textContent = "Last updated: " + new Date(data.ts * 1000).toLocaleString();
  } catch (e) {
    out.textContent = "Error: " + e;
    resilverHeadline.textContent = "Error";
    resilverDetail.textContent = String(e);
  }
}

function setTimer() {
  if (timer) clearInterval(timer);
  timer = null;
  const secs = parseInt(intervalSel.value, 10);
  if (secs > 0) timer = setInterval(load, secs * 1000);
}

document.getElementById("refresh").addEventListener("click", load);
intervalSel.addEventListener("change", () => { setTimer(); load(); });

setTimer();
load();
</script>
</body>
</html>
"""

class Handler(BaseHTTPRequestHandler):
    def _send(self, code: int, body: bytes, content_type: str):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/" or self.path.startswith("/index.html"):
            self._send(200, INDEX_HTML.encode("utf-8"), "text/html; charset=utf-8")
            return

        if self.path.startswith("/api/status"):
            import time, json
            output = get_zpool_status()
            resilver = parse_resilver_info(output)
            payload = json.dumps({"ts": int(time.time()), "output": output, "resilver": resilver})
            self._send(200, payload.encode("utf-8"), "application/json; charset=utf-8")
            return

        self._send(404, b"Not Found", "text/plain; charset=utf-8")

def main():
    httpd = HTTPServer((HOST, PORT), Handler)
    print(f"Serving on http://{HOST}:{PORT}")
    httpd.serve_forever()

if __name__ == "__main__":
    main()
