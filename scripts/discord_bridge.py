#!/usr/bin/env python3
import os
import requests
from flask import Flask, request

app = Flask(__name__)
DISCORD_WEBHOOK_URL = os.environ.get("DISCORD_WEBHOOK_URL")

def format_alert(alert):
    status = alert.get("status", "unknown").upper()
    name = alert.get("labels", {}).get("alertname", "Unknown Alert")
    severity = alert.get("labels", {}).get("severity", "unknown").upper()
    summary = alert.get("annotations", {}).get("summary", "No summary provided")
    emoji = "🔴" if status == "FIRING" and severity == "CRITICAL" else "🟡" if status == "FIRING" else "✅"
    return f"{emoji} **{name}** [{severity}]\n{summary}\nStatus: **{status}**"

@app.route("/", methods=["POST"])
def receive_alert():
    data = request.get_json()
    if not data:
        return "No data", 400
    alerts = data.get("alerts", [])
    if not alerts:
        return "OK", 200
    lines = ["**🔔 OmniNode Alert**\n"]
    for alert in alerts:
        lines.append(format_alert(alert))
    message = "\n\n".join(lines)
    resp = requests.post(DISCORD_WEBHOOK_URL, json={"content": message})
    print(f"Discord response: {resp.status_code}")
    return "OK", 200

if __name__ == "__main__":
    print("OmniNode Discord Bridge running on port 9094")
    app.run(host="0.0.0.0", port=9094)
