# Codex Context Window Visualizer

Live FastAPI page that reads the newest `~/.codex/sessions/**/rollout-*.jsonl` file and visualizes context-window usage.

Run:

```bash
uvicorn app:app --host 127.0.0.1 --port 8765
```
