---
name: deploy
description: Build the Hugo adscian.be site and upload adscian/public/ to Combell shared hosting via FTP/FTPS. Use when the user asks to deploy, publish, push to production, or upload the site.
---

# Deploy adscian.be

There is no CI/CD for this project (see `CLAUDE.md` at the repo root).
Deploying means
building the static site and syncing `adscian/public/` to Combell shared
hosting over FTP(S). This touches the live production site — treat it as an
outward-facing, hard-to-reverse action.

## Steps

1. **Check credentials exist.** Look for `adscian/.env.deploy`. If it's
   missing, stop and tell the user to copy `adscian/.env.deploy.example` to
   `adscian/.env.deploy` and fill in their Combell FTP host/user/password/
   remote path themselves. Never create, edit, or ask the user to paste the
   password into chat — it belongs only in that gitignored file.

2. **Check the working tree is clean.** Run `git status --short`. If there
   are uncommitted changes, tell the user — the deploy tag (step 6) would
   otherwise not accurately reflect what's actually being pushed live. Let
   them commit first, or proceed without tagging if they explicitly say so.

3. **Build.** From `adscian/`, run `npm run build`. If it fails, report the
   error and stop — do not upload a stale or partial `public/`.

4. **Confirm before uploading.** Find the last deploy tag with
   `git tag --list 'deploy-*' --sort=-creatordate` (take the first line) and
   show `git log <last-deploy-tag>..HEAD --oneline` (or full `git log`/
   `git status` if there is no previous tag) so the user sees exactly what's
   about to go live. Get an explicit go-ahead before running the uploader —
   this overwrites files on the live site.

5. **Upload.** From the repo root, run:
   ```
   bash .claude/skills/deploy/upload.sh
   ```
   It reads `adscian/.env.deploy`, uploads every file under
   `adscian/public/` via `curl` (plain FTP, explicit FTPS, or implicit FTPS
   per `FTP_PROTOCOL`), creating remote directories as needed, and prints
   per-file progress.

6. **Tag the deploy.** If the upload succeeded and the tree was clean (step
   2), tag the deployed commit and push the tag:
   ```
   git tag deploy-$(date +%Y%m%d-%H%M%S)
   git push origin --tags
   ```
   This is the rollback anchor — see "Rolling back" below. Skip this step
   if the tree wasn't clean (there's no single commit that matches what's
   live).

7. **Report plainly.** State how many files were uploaded, the tag created
   (if any), and surface any curl errors verbatim. Note the one remaining
   limitation: the uploader only adds/overwrites files, it never deletes
   anything remotely — if this deploy removed or renamed pages/assets, the
   old files will still exist on the remote host until removed manually
   over FTP.

## Rolling back

Each successful deploy from a clean tree is tagged `deploy-<timestamp>`, so
the previous live state is always a known commit. To roll back:

1. `git checkout <previous-deploy-tag>` (detached HEAD) — or
   `git switch -c rollback <previous-deploy-tag>` for a named branch.
2. `cd adscian && npm run build`
3. Run `bash .claude/skills/deploy/upload.sh` from the repo root to push
   that older build live.
4. `git switch main` (or whichever branch you were on) afterwards.

This is a manual, confirmed procedure — never run it without the user
explicitly asking to roll back.

## Credentials file

`adscian/.env.deploy` (gitignored, never committed) holds:

- `FTP_HOST`, `FTP_USER`, `FTP_PASSWORD`
- `FTP_REMOTE_DIR` — the remote path that maps to the web root (e.g. `/` or
  `/httpdocs`)
- `FTP_PROTOCOL` — `ftp`, `ftpes` (explicit TLS, recommended if Combell
  supports it), or `ftps` (implicit TLS)

Never print the contents of `.env.deploy` or echo the password to chat or
to command output.
