# Executor prompt

Read AGENTS.md, ai/repo-map.json, ai/governance.json, ai/health-check.summary.json, and ai/current-plan.md if present. Act as executor and primary code maintainer: prefer machine-verifiable contracts, explicit ownership, deterministic validation, and minimal code surface. Make the smallest safe change, follow the repo contract, run python ai/health_check.py --pretty --summary, regenerate the health artifacts, and run python ai/review_check.py --pretty --summary when closing a cycle. If ai/current-plan.md is deferred or absent, report that and stop.
