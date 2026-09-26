# Deploy WineGuesser (Claude Code runbook)

You are working in the `wineguesser` folder, a finished single-page web app for a blind wine tasting game at my brother Tim's birthday. The code is done and tested. Your job is to get it live, for free, today. Work through the phases below in order, checking things off as you go. Ask me only for the three inputs marked **ASK ME**; decide everything else yourself and tell me what you decided.

## What's in this folder

| File | Purpose |
| --- | --- |
| `index.html` | The whole app: sign-up with phone, numbered guess sheet, Tim's profile, leaderboard, host panel with reveal |
| `config.js` | Backend URL/key and birthday name. Empty values = preview mode with sample data |
| `schema.sql` | Supabase tables, row-level security and RPC functions. The app only calls these functions |
| `.github/workflows/pages.yml` | Deploys the folder to GitHub Pages on every push to `main` |
| `scripts/build-preview.py` | Builds a single-file demo at `dist/preview.html` (not needed for deploy) |
| `README.md` | Human-readable version of these steps |

Do not restructure the app or add a build step. Do not change the game logic unless a step below says so.

## Inputs

- **ASK ME: host PIN** (4-6 digits; this is what I type on party day to enter the answers and reveal scores). If I don't answer, generate a 6-digit one and show it to me at the end.
- **ASK ME: GitHub username**, if `gh api user --jq .login` doesn't return one.
- **ASK ME: Supabase org**, only if `supabase orgs list` shows more than one.

## Phase 1: Git and GitHub

1. Confirm `gh auth status` is logged in. If not, stop and tell me to run `gh auth login`.
2. If this folder isn't a git repo, run `git init -b main`. Make sure `.gitignore` contains `dist/`.
3. Commit everything: `git add -A && git commit -m "WineGuesser: blind tasting game for Tim's birthday"`.
4. Create the **private** repo and push:
   ```bash
   gh repo create wineguesser --private --source=. --remote=origin --push \
     --description "Tim's birthday blind wine tasting game"
   ```
   If `wineguesser` already exists under my account, add it as `origin` and push instead of creating.
5. Turn on GitHub Pages with the Actions source:
   ```bash
   gh api -X POST repos/{owner}/wineguesser/pages -f build_type=workflow
   ```
   (Replace `{owner}` with the username. If it returns 409, Pages is already on; then `gh api -X PUT repos/{owner}/wineguesser/pages -f build_type=workflow`.)
   Note: GitHub Pages on a **private** repo requires GitHub Pro/Team. If the API refuses for that reason, ask me whether to (a) make the repo public (`gh repo edit --visibility public --accept-visibility-change-consequences`; the page contains no secrets that matter, see Phase 2) or (b) deploy to Netlify instead (`npx netlify-cli deploy --prod --dir=.` after `npx netlify-cli login`). Default to (a) if I don't answer.
6. Wait for the workflow: `gh run watch` (or `gh run list --workflow=pages.yml`). When it succeeds, the site is at `https://{owner}.github.io/wineguesser/`. `curl -sI` that URL and confirm a 200.

At this point the site is live in preview mode (sample tasters, host PIN `1234`, nothing saved). Tell me the URL, then continue.

## Phase 2: Supabase backend (free tier)

Try the CLI path first; fall back to the dashboard path if any step can't be done from the terminal.

**CLI path**

1. `supabase --version`; if missing, `brew install supabase/tap/supabase`. Then `supabase login` (opens a browser; wait for me).
2. `supabase orgs list` to get the org id.
3. Create the project (pick a region near me on the US west coast):
   ```bash
   supabase projects create wineguesser --org-id <ORG_ID> --region us-west-1 --db-password "$(openssl rand -base64 24)"
   ```
   Save the generated database password to `~/.wineguesser-db-password` (chmod 600) and never commit it or print it in the repo.
4. Poll `supabase projects list` until the project status is `ACTIVE_HEALTHY` (usually 1-3 minutes).
5. Edit the last line of `schema.sql` so `'change-me'` becomes the host PIN, then run it against the database. Get the connection string from `supabase projects list` / the dashboard (Project Settings → Database → Connection string, "URI", session mode) and run:
   ```bash
   psql "<CONNECTION_URI>" -f schema.sql
   ```
   (`brew install libpq && brew link --force libpq` if `psql` is missing.) Every statement must succeed; if one fails, read the error, fix it and re-run. The file is idempotent.
   After it runs, **revert the PIN edit in `schema.sql` back to `'change-me'`** so the PIN is not committed.
6. Get the API URL and anon key:
   ```bash
   supabase projects api-keys --project-ref <REF>
   ```
   The URL is `https://<REF>.supabase.co`. Use the key named `anon` (public). Never use `service_role`.

**Dashboard path** (if the CLI can't do a step)

Tell me exactly what to click: create a project at supabase.com → SQL Editor → paste `schema.sql` (with the PIN edited on the last line) → Run → Project Settings → API → copy Project URL and anon public key → paste them to you. Then continue.

## Phase 3: Wire it up and redeploy

1. Put the values into `config.js`:
   ```js
   window.WINE_CONFIG = {
     supabaseUrl: "https://<REF>.supabase.co",
     supabaseAnonKey: "<ANON_KEY>",
     birthdayName: "Tim",
     eventLabel: "Birthday Blind Tasting",
   };
   ```
   The anon key is designed to be public: the tables have row-level security with all direct access revoked, and the only entry points are the `security definer` functions in `schema.sql`, which never return phone numbers or unrevealed answers. Committing it is fine.
2. Commit and push: `git commit -am "Connect to Supabase" && git push`. Wait for the Pages workflow again.

## Phase 4: Verify end to end

Run these against the live URL. Use `curl` for the API checks and Playwright (`npx playwright test` is not set up; write a short throwaway script with `npx -y playwright@latest` and Chromium, or use the browser if you have one) for the UI.

1. `curl -s <URL>/config.js` shows the Supabase URL, not empty strings.
2. API smoke test (replace values):
   ```bash
   H=(-H "apikey: $ANON" -H "Authorization: Bearer $ANON" -H "Content-Type: application/json")
   curl -s "${H[@]}" -X POST $SUPA/rest/v1/rpc/get_state          # -> {"wineCount":6,"revealed":false,...,"answers":null}
   curl -s "${H[@]}" -X POST $SUPA/rest/v1/rpc/join_game -d '{"p_name":"Test Taster","p_phone":"5550001111"}'
   curl -s "${H[@]}" -X POST $SUPA/rest/v1/rpc/submit_guesses -d '{"p_phone":"5550001111","p_guesses":[{"grape":"Pinot Noir","region":"Oregon"}]}'
   curl -s "${H[@]}" -X POST $SUPA/rest/v1/rpc/get_board          # -> Test Taster listed, "guesses": null (hidden until reveal)
   curl -s "${H[@]}" -X POST $SUPA/rest/v1/rpc/host_load -d '{"p_pin":"wrong"}'   # -> error "Wrong host PIN"
   curl -s "${H[@]}" $SUPA/rest/v1/players                          # -> must be an error/empty: direct table access is blocked
   ```
   The last line is the important security check. If it returns rows, RLS is not on; re-run `schema.sql`.
3. UI check on a 390px-wide viewport: home page loads with Tim's profile and an empty leaderboard, "Join the tasting" → sign up → fill glasses → "Seal my guesses" → back on home, the name appears with a "Sealed" pill. Then open `/#host`, enter the real PIN, set 6 wines and answers, tick Reveal, Save → leaderboard shows scores and a Winner.
4. Clean up the test data so the board is empty for the party:
   ```bash
   psql "<CONNECTION_URI>" -c "delete from players; update settings set revealed=false, answers='[]'::jsonb;"
   ```
5. Save the workflow's final URL and the Supabase project ref in `README.md` under a new "Live" heading. Commit and push.

## Done report

Finish with a short message containing:

- The live URL (this is what I'll text to friends).
- The host link (`<URL>#host`) and the host PIN.
- Where the DB password is stored locally.
- Anything you decided on your own (repo visibility, region, PIN if generated).
- Anything you couldn't complete and the exact next step for me.
