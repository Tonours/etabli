import json
import sys


def admissible_prompt_tokens(path):
    last = None
    for line in open(path, encoding="utf-8"):
        try:
            event = json.loads(line)
        except ValueError:
            continue
        message = event.get("message")
        if event.get("type") == "message_end" and isinstance(message, dict) and message.get("role") == "assistant":
            last = message
    if last is None:
        raise SystemExit("no assistant message")
    text = "".join(part.get("text", "") for part in last.get("content", []) if isinstance(part, dict) and part.get("type") == "text").strip()
    usage = last.get("usage") or {}
    counters = [usage.get(key) for key in ("input", "cacheRead", "cacheWrite")]
    if last.get("stopReason") != "stop":
        raise SystemExit(f"inadmissible: stopReason={last.get('stopReason')}")
    if text.rstrip(".") != "OK":
        raise SystemExit(f"inadmissible: text={text[:40]!r}")
    if (last.get("provider"), last.get("model")) != ("zai", "glm-5.3"):
        raise SystemExit(f"inadmissible: model={last.get('provider')}/{last.get('model')}")
    if not all(isinstance(value, int) for value in counters) or sum(counters) <= 0:
        raise SystemExit(f"inadmissible: counters={counters}")
    return sum(counters)


if __name__ == "__main__":
    print(f"pi_prompt_tokens={admissible_prompt_tokens(sys.argv[1])}")
