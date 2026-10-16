# Approved RST-001 foundation contract

The backend owns this contract. `openapi.json` is copied byte-for-byte from `restora-backend/docs/openapi.json`; `session.example.json` matches `restora-backend/docs/examples/session.json`. These are the approved initial engineering baseline for this implementation (API version 0.1.0). Automated source/snapshot and consumer tests validate the baseline. Human review by the two developers is still required before merging the foundation PRs; no external approval or deployment is implied.

Source baseline: backend commit `c3a5caa` on `feat/RST-001-mvp-foundation`.

Do not edit the frontend snapshot to invent an API. For changes, use the same RST task ID in both repositories, update Pydantic/routes in the backend, run its snapshot exporter and checks, obtain cross-developer contract review, then copy both artifacts here in the related client PR. Keep changes additive and backward compatible. Deploy compatible backend changes before updating the client.

From the parent workspace, after backend checks and contract review:

```powershell
Copy-Item .\restora-backend\docs\openapi.json .\restora-frontend\contract\openapi.json
Copy-Item .\restora-backend\docs\examples\session.json .\restora-frontend\contract\session.example.json
```

`tracking_mode: simulated` is integration input, not evidence of completed camera tracking. All movement defaults in the assignment require professional review before patient use.
