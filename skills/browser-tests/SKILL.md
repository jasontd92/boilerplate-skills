---
name: browser-tests
description: Plan and execute Playwright browser tests against the local app. Capture screenshots/video as proof of work and upload evidence to PRs.
argument-hint: [test scope, feature area, or PR number]
---

# Browser Tests

Plan and execute browser tests for **$ARGUMENTS** against the local development environment.

---

## 0. Environment Ready

### Where to run: primary local env vs worktree

Default to the **primary local env** when that is where fixtures, a known test user, and a healthy DB pool live. During a `/sprint`, browser tests are typically a Stage-4 step on MAIN — not a per-workstream worktree.

To target a worktree (single-PR `/ship` flow), set the test base URL to that worktree's app origin and ensure its DB has the fixtures the scenarios need.

Discover the project's commands (`just wt-info`, `just ensure-ready`, Playwright configs). Do not invent stack-specific recipes.

### Docker / local stack

If the app runs in containers, verify the daemon is up (`docker ps`) before anything else. If it hangs, start Docker/OrbStack (or the project's equivalent) and wait for the socket.

After switching branches, restart the UI process if the frontend does not hot-reload checked-out source. Prefer the project's documented recovery verb over a homemade decision tree.

### Compile warmup (Next.js / similar)

After a UI restart, the **first page load can take 60–120s** while the bundler compiles. Wait — don't assume the app is broken. Each route often compiles independently; pre-warm every route you plan to test with an authenticated curl when possible.

**Authed render compiles more than the 401 path.** An unauthenticated warm that short-circuits to login compiles far fewer modules than the real authed page.

### Clean vs warm

- **Don't wipe the bundler cache per run** unless you see chunk-load errors. A full wipe forces a cold compile of every route and is the #1 cause of capture timeouts.
- **Do restart the UI after a branch switch** so screenshots show the PR's code, not the previous branch still sitting in memory.
- **Pre-warm every target route** so the cold compile happens before capture.
- **For substantial multi-spec proof-of-work, prefer a production build** when on-demand compile is expensive. Tradeoff: longer build, then instant loads.

### Screenshots must be render-gated

`page.goto(..., { waitUntil: "domcontentloaded" })` plus an immediate screenshot (or a fixed `waitForTimeout`) captures a **blank, unhydrated frame**. That evidence is useless but silently "passes".

Use a helper that **polls the live DOM** until real content is present (visible testids / non-trivial body text), then capture. If the project has `gotoReady` / `captureVerified`-style helpers, use them.

> Dev-mode portals (e.g. Next.js "N Issue" badge) can make blank-frame heuristics false-negative. Trust those verdicts against a **production build**; in dev, eyeball the frames.

### Health-check gotcha

A `/health` endpoint can report the UI as `not_ready` while pages actually serve (common with Turbopack). **Don't rely on `/health` for usability** — curl a real page and interpret 200 / 401 / 502 yourself.

If the project's environment-ready command fails, abort — the environment is unrecoverable from this context.

---

## 1. Auth Setup

Browser tests usually need authenticated sessions. Discover how this repo does it:

- Encrypted credentials + a just/recipe that exports env and runs Playwright setup
- A Playwright `auth` project that writes `storageState` JSON
- A shared cookie / MCP Chrome profile

### Check session freshness FIRST

Stored auth files often expire (hours, not days). If the file is stale, every test silently hits a login redirect. Re-run auth setup before blaming the feature.

Quick validation: curl a known authed route with the cookie. 200 = valid, 401 = expired.

If you hit an auth wall during an agent session and cannot mint credentials, **do not attempt to fix auth** — skip, note "blocked by auth", continue.

A minted cookie for an identity that **does not exist in the local DB** will look authed at the IdP and then 403/500 on app APIs. Check for the user row before blaming the cookie.

---

## 2. Plan Test Scenarios

Before navigating, define a numbered checklist. Each scenario needs:

- **Route** — the URL path
- **Precondition** — required state
- **Actions** — click, fill, submit, drag, upload
- **Expected result** — what success looks like
- **Evidence** — screenshot name(s) to capture

Base scenarios on the code changes. If testing a PR, read the PR description and changed files.

---

## 3. Execute Tests — Playwright First

### Option A: Playwright specs (preferred)

Write scenarios as specs. Use a proof-of-work config that **always** captures screenshots + video + trace (not only on failure). Timeouts should absorb bundler warmup if you are in dev mode.

```bash
npx playwright test --config <pow-config> <spec-path>
```

> **Two run-gotchas that silently cost evidence:**
>
> 1. **Playwright wipes `outputDir` (`test-results/`) at the START of every run.** A second spec run destroys the first spec's screenshots/video. Run **all** POW specs in **one `workers:1` invocation**, or copy evidence out immediately after each run.
> 2. **Config `testMatch` may be hardcoded** to a filename pattern. A bespoke spec against the POW config can return "No tests found." Author a feature-scoped config that reuses the same `auth` setup project.

**Never** `goto` + `waitForTimeout` + `screenshot`.

```typescript
import { test } from "@playwright/test";

test("feature: description", async ({ page }) => {
  await page.goto("/the-route");
  // Wait for real content — project helper preferred
  await page.getByRole("heading", { name: /.../i }).waitFor();
  await page.screenshot({ path: "test-results/proof-feature-before.png", fullPage: true });

  await page.getByRole("button", { name: "Save" }).click();
  await page.getByText(/saved/i).waitFor();
  await page.screenshot({ path: "test-results/proof-feature-after.png", fullPage: true });
});
```

**Spec-authoring rules:**

- **Make specs self-contained.** Seed fixtures via the API *inside the test* (`page.request` shares `storageState`) and clean up after. External seeds pass alone and fail in CI.
- **Scope selectors** — `data-testid` is not always unique. Duplicate composers, duplicate editors, `.ProseMirror` matching every tiptap instance. Scope to a container testid or use `.first()`.
- **Tolerate model paraphrasing** when asserting on LLM output — distinctive substring, not exact string.

**File uploads** — absolute paths. **Downloads** — `page.waitForEvent("download")` then `saveAs` under `test-results/`.

### Option B: Playwright MCP (interactive)

Ad-hoc exploration: `browser_navigate`, `browser_click`, `browser_type`, `browser_take_screenshot`. Auth cookies must be loaded via storage state.

### Option C: Chrome MCP (interactive — visual)

For live observation or side-by-side visual checks, drive real Chrome with the live session. Use Playwright (Option A) when the result must be reliable, scripted, or captured as PR proof.

---

## 4. Evidence Capture

Every scenario must produce at minimum:

- **Before screenshot** — initial page state
- **After screenshot** — state after actions complete

Name files descriptively: `test-results/proof-{feature}-{state}.png`

A "failed" test's `test-failed-1.png` is often the **best** evidence when an assertion failed on a timing/selector technicality **after** the feature rendered. Copy it out before the next run wipes `test-results/`.

Convert video to GIF for inline PR display:

```bash
ffmpeg -i test-results/video.webm -vf "fps=10,scale=800:-1" -loop 0 test-results/proof.gif
```

---

## 5. Upload Evidence to PR

Upload screenshots/GIFs to a GitHub Release for persistent URLs, then comment on the PR.

```bash
RELEASE_TAG="pow-$(date -u +%Y%m%d-%H%M%S)"
OWNER_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

gh release create "$RELEASE_TAG" \
  --title "Proof of Work $RELEASE_TAG" \
  --notes "Browser test evidence" 2>/dev/null || true

for f in test-results/proof-*.png test-results/proof-*.gif; do
  [ -f "$f" ] && gh release upload "$RELEASE_TAG" "$f" --clobber
done

# Image URL: https://github.com/${OWNER_REPO}/releases/download/${RELEASE_TAG}/filename.png
gh pr comment <PR_NUMBER> --body "$(cat comment.md)"
```

---

## 6. Fix Cycle

After completing all scenarios:

1. **Triage failures** — code bugs vs environment issues
2. **Fix code bugs** — read app logs, inspect DB if needed, patch, full-lint
3. **Re-test failed scenarios only**

Repeat until all scenarios pass or remaining failures are documented.

---

## LLM-in-the-loop chat UIs

Submitting from an *empty* chat often persists the user turn and navigates to a new URL, but the assistant turn may **not** fire in headless (sessionStorage flags don't survive programmatic nav). Symptom: user message + generated title appear, streaming API never called.

**Orphan re-entry:** after submit, capture the new chat path from `page.url()`, `goto('about:blank')`, re-enter the chat URL, then poll the backend for the tool's side effect. Give the stream a generous `test.setTimeout` before the context closes.
