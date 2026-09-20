#!/usr/bin/env python3
"""PreToolUse closed-set gate. Fail-open. Never grants. No secrets on stderr."""
import json
import os
import sys
import urllib.error
import urllib.request


def allow():
    print(json.dumps({"decision": "allow"}))
    sys.exit(0)


def deny(reason):
    print(json.dumps({"decision": "deny", "reason": reason}))
    sys.exit(0)


UNGATED = {
    "read_file",
    "grep",
    "list_dir",
    "search_tool",
    "web_search",
    "web_fetch",
    "todo_write",
    "Read",
    "Grep",
    "Glob",
}

try:
    event = json.loads(sys.stdin.read() or "{}")
except Exception:
    allow()

tool = str(event.get("toolName") or event.get("tool_name") or "")
if tool in UNGATED:
    allow()

home = os.environ.get("GROK_HOME") or os.path.expanduser("~/.grok-thin")
catalog_path = os.path.join(home, "state", "thin-catalog.json")
try:
    with open(catalog_path) as fh:
        catalog = json.load(fh)
    remaining = [str(n) for n in catalog.get("names") or []]
except Exception:
    allow()

if not remaining:
    allow()

if tool and tool not in remaining:
    deny("Thin session: tool is outside the remaining closed set.")

key_path = os.environ.get("JEV_API_KEY_FILE") or os.path.expanduser(
    "~/.config/dev-approved-lfg/jev_api_key"
)
if not os.path.isfile(key_path):
    allow()
try:
    with open(key_path) as fh:
        key = fh.read().strip()
except Exception:
    allow()
if not key:
    allow()

endpoint = os.environ.get(
    "TYPESAFE_DECISIONS_URL", "https://api.typesafe.ai/v1/system-one"
)
criteria = {n: n for n in (remaining[:31] + ["none"])}
body = json.dumps(
    {
        "state": {"tool": tool, "remaining": remaining[:32]},
        "selectedModels": ["jev-latest"],
        "questions": {
            "next": {
                "type": "choice",
                "instructions": "Which remaining tool should run now?",
                "criteria": criteria,
            }
        },
    }
).encode("utf-8")
req = urllib.request.Request(
    endpoint,
    data=body,
    headers={"Content-Type": "application/json", "Authorization": "Bearer " + key},
    method="POST",
)
try:
    with urllib.request.urlopen(req, timeout=2.5) as resp:
        data = json.loads(resp.read().decode("utf-8"))
except Exception:
    allow()

choice = ((data.get("answers") or {}).get("next") or {}).get("choice")
try:
    conf = float(((data.get("answers") or {}).get("next") or {}).get("confidence") or 0)
except (TypeError, ValueError):
    conf = 0.0
if conf < 0.7:
    allow()
if choice == "none":
    deny("Jev chose none for this step.")
if choice and choice != tool:
    deny("Jev selected a different remaining tool.")
allow()
