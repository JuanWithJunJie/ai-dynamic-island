#!/usr/bin/env python3
# MacIrland hook for Claude Code - sends events via Unix socket
import json
import os
import socket
import sys
import subprocess

SOCKET_PATH = os.path.expanduser(
    "~/Library/Application Support/MacIrland/hook.sock"
)
SOCKET_CONNECT_TIMEOUT = 5
PERMISSION_RESPONSE_TIMEOUT = 300


def get_tty():
    """Get the TTY of the Claude Code process via ps."""
    try:
        result = subprocess.run(
            ["ps", "-p", str(os.getpid()), "-o", "tty="],
            capture_output=True, text=True, timeout=2, check=False
        )
        tty = result.stdout.strip()
        if tty and tty not in ("??", "-"):
            return tty if tty.startswith("/dev/") else f"/dev/{tty}"
    except Exception:
        pass
    try:
        return os.ttyname(sys.stdin.fileno()) if sys.stdin.isatty() else ""
    except Exception:
        return ""


def get_cwd():
    """Get current working directory."""
    try:
        return os.getcwd()
    except Exception:
        return ""


def send_event(data):
    """Send JSON event to MacIrland socket. Returns response for permission requests."""
    try:
        payload = json.dumps(data).encode("utf-8")
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.settimeout(SOCKET_CONNECT_TIMEOUT)
            sock.connect(SOCKET_PATH)
            # 4-byte big-endian length prefix (matches HookSocketServer framing)
            sock.sendall(len(payload).to_bytes(4, "big"))
            sock.sendall(payload)
            # For PermissionRequest, wait for response
            if data.get("event") == "PermissionRequest":
                sock.settimeout(PERMISSION_RESPONSE_TIMEOUT)
                response = sock.recv(4096)
                return json.loads(response.decode("utf-8"))
    except Exception:
        pass
    return None


def handle_permission_response(response):
    """Print permission decision to stdout for Claude Code to consume."""
    if not response:
        print("{}")
        return
    decision = response.get("decision", "ask")
    reason = response.get("reason", "")
    if decision == "allow":
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PermissionRequest",
                "decision": {"behavior": "allow"}
            }
        }))
    elif decision == "deny":
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PermissionRequest",
                "decision": {
                    "behavior": "deny",
                    "message": reason or "Denied by user via MacIrland"
                }
            }
        }))
    else:
        print("{}")


def main():
    """Read hook event from stdin, send to MacIrland, return response via stdout."""
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(1)

    session_id = data.get("session_id", "unknown")
    event_name = data.get("hook_event_name", "")
    cwd = data.get("cwd", "")

    # Build event payload
    payload = {
        "session_id": session_id,
        "cwd": cwd,
        "event": event_name,
        "status": data.get("status", ""),
        "pid": os.getpid(),
        "tty": get_tty(),
    }

    # Add optional fields if present
    if tool := data.get("tool_name"):
        payload["tool"] = tool
    if tool_input := data.get("tool_input"):
        # Stringify tool_input as JSON since Swift expects a String type
        payload["tool_input"] = json.dumps(tool_input)
    if tool_use_id := data.get("tool_use_id"):
        payload["tool_use_id"] = tool_use_id

    # Send to MacIrland
    response = send_event(payload)

    # Permission requests return decision via stdout
    if event_name == "PermissionRequest":
        handle_permission_response(response)
    else:
        print("{}")


if __name__ == "__main__":
    main()
