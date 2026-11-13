# my-cost-of-living

Read docs/project_state.md first. Keep it current when decisions or findings change.

## How to work with me
- You write the code; I make the judgment calls and review every change.
- Before writing a model, list the decisions it needs (filters, grain, dedup,
  outliers, units, index, materialization) with your recommendation, and wait for
  my answer. Do not pick one silently.
- After a change, give a short summary: what changed, why, and how you verified it
  (dbt run/test output or a query). Explain any line I ask about.
- Work in small steps: one model (plus its tests and YAML) at a time, on its own
  feature branch. Never work on main; if we are on main, stop and tell me.
- When a model is done: run dbt run and dbt test on it, then tell me it is ready
  for review. I review the diff, then I commit and open the pull request.
- Code comments: short plain notes in my voice.
- Verify claims with queries, lead with the answer, give exact commands.
- Do not commit or push unless I ask. Short imperative messages, one concern each,
  ingestion and dbt changes in separate commits.
- Keep README.md current when models, tests or findings change.

## Environment
- Windows PowerShell, venv at repo root (.venv\Scripts\Activate.ps1).
  `dbt --version` must show Core 1.12.6 (a global dbt Fusion exists outside the venv).
- Run dbt from dbt_project with `--profiles-dir .`
- DuckDB allows one read-write connection: close notebook connections before dbt runs.
- dbt 1.12 syntax: tests under `data_tests:`, test arguments under `arguments:`.