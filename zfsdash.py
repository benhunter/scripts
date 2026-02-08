#!/usr/bin/env python3
import re
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer

HOST = "0.0.0.0"
PORT = 8787

def get_zpool_status() -> str:
    p = subprocess.run(
        ["/sbin/zpool", "status", "-v"],
        capture_output=True,
        text=True,
        timeout=8,
    )
    out = p.stdout if p.returncode == 0 else (p.stdout + "\n" + p.stderr)
    return out.rstrip("\n")

def _extract_pool_blocks(zpool_output: str) -> list[dict]:
    """
    Split `zpool status` output into per-pool blocks.
    Returns list of { "pool": "<name>", "lines": [..], "scan": "<scan joined>"|None }.
    """
    lines = zpool_output.splitlines()
    blocks = []
    cur = None

    for line in lines:
        m_pool = re.match(r"^\s*pool:\s*(\S+)\s*$", line)
        if m_pool:
            if cur:
                blocks.append(cur)
            cur = {"pool": m_pool.group(1), "lines": [], "scan": None}
            continue
        if cur is not None:
            cur["lines"].append(line)

    if cur:
        blocks.append(cur)

    for b in blocks:
        scan = None
        for i, line in enumerate(b["lines"]):
            if line.strip().startswith("scan:"):
                buf = [line.strip()]
                # scan block typically wraps across indented lines
                for j in range(i + 1, min(i + 6, len(b["lines"]))):
                    if b["lines"][j].startswith(" ") or b["lines"][j].startswith("\t"):
                        buf.append(b["lines"][j].strip())
                    else:
                        break
                scan = " ".join(buf)
                break
        b["scan"] = scan
    return blocks

def parse_resilver_info(zpool_output: str) -> dict:
    """
    Returns summary for ANY pool that has 'resilver in progress'.
    If multiple pools are resilvering, returns the first one found.
    """
    for b in _extract_pool_blocks(zpool_output):
        scan = b["scan"] or ""
        if not scan:
            continue

        state = scan[5:].strip() if scan.lower().startswith("scan:") else scan.strip()
        active = bool(re.search(r"\bresilver\b", state, re.IGNORECASE) and re.search(r"\bin progress\b", state, re.IGNORECASE))
        if not active:
            continue

        pct_done = None
        m_pct = re.search(r"(\d+(?:\.\d+)?)%\s+done", state)
        if m_pct:
            try:
                pct_done = float(m_pct.group(1))
            except ValueError:
                pct_done = None

        eta = None
        m_eta = re.search(r",\s*([^,]+?)\s+to go\b", state)
        if m_eta:
            eta = m_eta.group(1).strip()
        else:
            m_eta2 = re.search(r"\b(\d+\s+days?\s+)?\d{1,2}:\d{2}:\d{2}\s+to go\b", state)
            if m_eta2:
                eta = m_eta2.group(0).replace("to go", "").strip()

        return {"active": True, "pool": b["pool"], "state": state, "pct_done": pct_done, "eta": eta}

    return {"active": False, "pool": None, "state": "No resilver in progress", "pct_done": None, "eta": None}

def parse_scrub_info(zpool_output: str) -> dict:
    """
    Scrub widget logic:
      - If any pool has "scrub in progress", show that (first match).
      - Else, show the most recent "scrub repaired ..." line (first match).
    """
    blocks = _extract_pool_blocks(zpool_output)

    # Prefer active scrub
    for b in blocks:
        scan = b["scan"] or ""
        if not scan:
            continue

        state = scan[5:].strip() if scan.lower().startswith("scan:") else scan.strip()
        active = bool(re.search(r"\bscrub\b", state, re.IGNORECASE) and re.search(r"\bin progress\b", state, re.IGNORECASE))
        if not active:
            continue

        pct_done = None
        m_pct = re.search(r"(\d+(?:\.\d+)?)%\s+done", state)
        if m_pct:
            try:
                pct_done = float(m_pct.group(1))
            except ValueError:
                pct_done = None

        eta = None
        m_eta = re.search(r",\s*([^,]+?)\s+to go\b", state)
        if m_eta:
            eta = m_eta.group(1).strip()
        else:
            # Many scrubs will explicitly say "no estimated completion time"
            if re.search(r"\bno estimated completion time\b", state, re.IGNORECASE):
                eta = None

        return {
            "active": True,
            "pool": b["pool"],
            "state": state,
            "pct_done": pct_done,
            "eta": eta,
            "result": None,
            "duration": None,
            "when": None,
        }

    # Otherwise: completed scrub line (example you gave):
    # scan: scrub repaired 0B in 00:00:12 with 0 errors on Sun Feb  8 03:45:13 2026
    for b in blocks:
        scan = b["scan"] or ""
        if not scan:
            continue

        state = scan[5:].strip() if scan.lower().startswith("scan:") else scan.strip()
        if not re.search(r"\bscrub\b", state, re.IGNORECASE):
            continue
        if re.search(r"\bin progress\b", state, re.IGNORECASE):
            continue

        m_done = re.search(
            r"scrub\s+repaired\s+(\S+)\s+in\s+(\S+)\s+with\s+(\d+)\s+errors\s+on\s+(.+)$",
            state,
            re.IGNORECASE,
        )
        if m_done:
            repaired, duration, errors, when = m_done.group(1), m_done.group(2), m_done.group(3), m_done.group(4)
            return {
                "active": False,
                "pool": b["pool"],
                "state": state,
                "pct_done": None,
                "eta": None,
                "result": f"repaired {repaired}, {errors} errors",
                "duration": duration,
                "when": when,
            }

        # Fallback: show whatever scan line exists
        return {
            "active": False,
            "pool": b["pool"],
            "state": state,
            "pct_done": None,
            "eta": None,
            "result": None,
            "duration": None,
            "when": None,
        }

    return {
        "active": False,
        "pool": None,
        "state": "No scrub information found",
        "pct_done": None,
        "eta": None,
        "result": None,
        "duration": None,
        "when": None,
    }

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

    .widgets { display: grid; grid-template-columns: 1fr; gap: 12px; margin-bottom: 12px; }
    @media (min-width: 900px) {
      .widgets { grid-template-columns: 1fr 1fr; }
    }

    .widget {
      border: 1px solid #ddd;
      border-radius: 12px;
      padding: 12px;
      box-shadow: 0 1px 2px rgba(0,0,0,0.04);
    }
    .widget-title { font-size: 0.95rem; color:#444; margin-bottom: 6px; display:flex; gap:10px; align-items: baseline; }
    .widget-title .pool { color:#777; font-size: 0.9rem; }
    .widget-row { display:flex; gap: 16px; flex-wrap: wrap; align-items: baseline; }
    .big { font-size: 1.20rem; font-weight: 650; }
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

  <!-- Widgets moved BELOW the bar (as requested) -->
  <div class="widgets">
    <div class="widget" id="resilverWidget">
      <div class="widget-title">
        <span>Resilver</span>
        <span class="pool" id="resilverPool"></span>
      </div>
      <div class="widget-row">
        <div class="big" id="resilverHeadline">Loading...</div>
        <div class="kv" id="resilverDetail"></div>
      </div>
    </div>

    <div class="widget" id="scrubWidget">
      <div class="widget-title">
        <span>Scrub</span>
        <span class="pool" id="scrubPool"></span>
      </div>
      <div class="widget-row">
        <div class="big" id="scrubHeadline">Loading...</div>
        <div class="kv" id="scrubDetail"></div>
      </div>
    </div>
  </div>

  <pre id="out">Loading...</pre>

<script>
const out = document.getElementById("out");
const stamp = document.getElementById("stamp");
const intervalSel = document.getElementById("interval");

const resilverPool = document.getElementById("resilverPool");
const resilverHeadline = document.getElementById("resilverHeadline");
const resilverDetail = document.getElementById("resilverDetail");

const scrubPool = document.getElementById("scrubPool");
const scrubHeadline = document.getElementById("scrubHeadline");
const scrubDetail = document.getElementById("scrubDetail");

let timer = null;

function setPool(el, poolName) {
  el.textContent = poolName ? `pool: ${poolName}` : "";
}

function formatResilverWidget(r) {
  if (!r) {
    setPool(resilverPool, null);
    resilverHeadline.textContent = "Unknown";
    resilverDetail.textContent = "";
    return;
  }
  setPool(resilverPool, r.pool);

  if (r.active) {
    const eta = r.eta ? r.eta : "In progress";
    resilverHeadline.innerHTML = `<span class="pill">ACTIVE</span> &nbsp; ${eta}`;

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

function formatScrubWidget(s) {
  if (!s) {
    setPool(scrubPool, null);
    scrubHeadline.textContent = "Unknown";
    scrubDetail.textContent = "";
    return;
  }
  setPool(scrubPool, s.pool);

  if (s.active) {
    const eta = s.eta ? s.eta : "No ETA";
    scrubHeadline.innerHTML = `<span class="pill">ACTIVE</span> &nbsp; ${eta}`;

    const pct = (typeof s.pct_done === "number") ? `${s.pct_done.toFixed(2)}% done` : null;
    const parts = [];
    if (pct) parts.push(pct);
    if (s.state) parts.push(s.state);
    scrubDetail.textContent = parts.join(" — ");
  } else {
    scrubHeadline.innerHTML = `<span class="pill">IDLE</span> &nbsp; Last scrub result`;
    const parts = [];
    if (s.result) parts.push(s.result);
    if (s.duration) parts.push(`duration ${s.duration}`);
    if (s.when) parts.push(`on ${s.when}`);
    if (parts.length === 0 && s.state) parts.push(s.state);
    scrubDetail.textContent = parts.join(" — ");
  }
}

async function load() {
  try {
    const r = await fetch("/api/status", { cache: "no-store" });
    if (!r.ok) throw new Error("HTTP " + r.status);
    const data = await r.json();

    out.textContent = data.output || "";
    formatResilverWidget(data.resilver);
    formatScrubWidget(data.scrub);

    stamp.textContent = "Last updated: " + new Date(data.ts * 1000).toLocaleString();
  } catch (e) {
    out.textContent = "Error: " + e;

    resilverHeadline.textContent = "Error";
    resilverDetail.textContent = String(e);
    scrubHeadline.textContent = "Error";
    scrubDetail.textContent = String(e);
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
            payload = json.dumps({
                "ts": int(time.time()),
                "output": output,
                "resilver": parse_resilver_info(output),
                "scrub": parse_scrub_info(output),
            })
            self._send(200, payload.encode("utf-8"), "application/json; charset=utf-8")
            return

        self._send(404, b"Not Found", "text/plain; charset=utf-8")

def main():
    httpd = HTTPServer((HOST, PORT), Handler)
    print(f"Serving on http://{HOST}:{PORT}")
    httpd.serve_forever()

if __name__ == "__main__":
    main()
