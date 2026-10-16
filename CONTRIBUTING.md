# Contributing to Restora

Developer B primarily owns the backend; Developer A primarily owns the frontend. Both have review and contribution responsibility in both repositories. Configure both real GitHub users as collaborators after remote targets are supplied; no placeholder CODEOWNERS restricts reviews.

Use GitHub Flow independently in each repository. `main` contains integrated working code. There is no develop or release branch. Use the same task ID on related work, for example `feat/RST-002-camera-adapter` in the frontend and `feat/RST-002-tracking-contract` in the backend. Fixes use `fix/RST-<number>-<description>`.

1. Finish or stash your own work, then `git switch main` and `git pull --ff-only origin main`.
2. Create a short-lived branch: `git switch -c feat/RST-002-camera-adapter` (adapt description per repository).
3. Implement the task, update documentation and meaningful tests, and run the README checks.
4. Commit, push the task branch to its explicitly configured remote, and open a PR against `main`. Link the paired repository PR using the same task ID; use the PR template.
5. The other developer reviews behavior, tests, API compatibility and scope. Address feedback and require passing CI before merging.
6. Squash merge through the PR, delete the remote branch, then update local `main` and delete the merged local branch. Do not rewrite shared history or discard another developer's changes.

Once GitHub repositories exist, configure protection/rules on `main`: one approval from the other developer, required repository CI, resolved discussions, no force pushes/deletion, and squash merge with automatic branch deletion. These remote settings are pending; local files cannot enforce GitHub settings. See [GitHub protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches) and [merge methods](https://docs.github.com/en/pull-requests/reference/pull-request-merges).

The backend owns the OpenAPI schema. Make additive backward-compatible changes, regenerate its snapshot and examples, and copy the approved artifacts into the frontend in a linked PR. Both developers approve the contract. Deploy and smoke-test the compatible backend before releasing an updated client. Never silently change enum meanings or remove fields consumed by an existing app. Expand database schemas before changing clients; defer destructive cleanup to a later coordinated change.

The initial `RST-001` branch is a reviewable local foundation commit. `main` retains its initial scaffold until the other developer reviews the foundation PR. No remote, push, PR or deployment is assumed.
