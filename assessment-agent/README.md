# Kangxiaoban Assessment Agent

This directory contains the server-side AsLive voice-assessment runtime used
by KangxiaobanAI. The active deployment is managed separately on the AI host;
model checkpoints, generated reports, logs, environment secrets, and runtime
caches are intentionally excluded from Git.

The institutional source of truth remains the Kangxiaoban Go backend. This
runtime receives a versioned question snapshot through the protected
`/assessment-ws` WebSocket and returns speech/assessment events. It must not
connect directly to the institution database.

Run the deterministic workflow tests with:

```shell
python -m unittest -v test_assessment_flow.py
```
