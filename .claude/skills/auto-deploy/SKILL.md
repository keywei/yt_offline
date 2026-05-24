---
name: auto-deploy
description: One-shot poll for the yt_offline project — if an iOS device is plugged in AND origin/main has new commits, fast-forward, build release, and install. Pass a number (`/auto-deploy 60`) to keep polling every N seconds.
---

# auto-deploy

A single iteration of "is there new code? is the device plugged in? if both — ship it."

## Argument handling

Look at the user-supplied args (`$ARGUMENTS`):

- **Empty / no argument** → run the one-shot logic below, then exit. Do NOT schedule anything.
- **Numeric (e.g. `60`, `90`, `300`)** → user wants periodic polling at that interval in **seconds**. Translate to a `/loop` invocation:
  - Use the Skill tool: `Skill(skill: "loop", args: "<N>s /auto-deploy")`.
  - That hands control to `/loop`, which then re-fires `/auto-deploy` (no arg) every N seconds.
  - Do NOT run the one-shot logic in this turn — let `/loop` drive the first iteration. Reply with a single sentence telling the user the loop is armed.
- **Anything else** → reply with the usage hint and exit.

Note: the `/loop` runtime clamps to [60s, 3600s]. Anything under 60 is treated as 60.

## Steps

Each Bash call must prepend `export PATH="$HOME/development/flutter/bin:$PATH" && ` because Flutter is not on the default PATH.

1. **Find the iOS device.** Run `flutter devices`. Filter the output for a line matching `mobile.*ios` and grab the device id (the `XXXXXXXX-...` token after `•`). If no iOS device, **exit and report `no device — skipped`**. Do not hardcode the id.

2. **Check git is clean.** Run `git status --porcelain`. If non-empty, **exit and report `working tree dirty — skipped`**. Don't touch the user's in-progress work.

3. **Fetch and compare.**
   ```
   git fetch --quiet origin main
   git rev-list --count HEAD..origin/main   # commits behind
   git rev-list --count origin/main..HEAD   # commits ahead
   ```
   - Behind == 0 → `up to date — skipped`.
   - Ahead > 0 → `local ahead — skipped` (user has un-pushed work; not our call).
   - Behind > 0 and ahead == 0 → fast-forward case, continue.
   - Both > 0 → `diverged — manual resolution needed`, exit.

4. **Inspect the diff for pubspec change.** Capture `git diff --name-only HEAD..origin/main`. If `pubspec.yaml` is in the list, remember to run `flutter pub get` after pulling.

5. **Pull.** `git pull --ff-only`. Bail if this fails for any reason.

6. **Refresh deps if needed.** If step 4 flagged pubspec, run `flutter pub get`.

7. **Build.** Kick off the build in the background and stream the log:
   ```
   flutter build ios --release > /tmp/flutter_build.log 2>&1
   ```
   Use `run_in_background: true` on the Bash call, then `Monitor` with:
   ```
   tail -F /tmp/flutter_build.log | grep --line-buffered -E \
     "Building|Xcode|error:|ERROR|FAILED|Failed|✓|Built|Exception|Encountered"
   ```
   Wait for `✓ Built` (success) or any failure line (bail with the error).

8. **Install.** `xcrun devicectl device install app --device <device-id> build/ios/iphoneos/Runner.app`. Do NOT use `flutter install` — its wrapper does `Uninstalling old version` first, which wipes the iOS app sandbox (Documents/) and deletes every downloaded video. devicectl on its own does an update-install when bundle ID + signing identity match, so `Documents/videos/` is preserved.

9. **Verify.** `xcrun devicectl device info apps --device <device-id> | grep ytoffline`. Report the new short-SHA (`git rev-parse --short HEAD`) and exit.

## Hard constraints

- **Never** commit, push, stash, rebase, merge, or amend. This skill is read-only against the user's local state.
- **Never** force-build when up-to-date — just report and exit.
- **Never** run `pod install` manually — `flutter build` handles CocoaPods.
- **Never** override / change settings, env, or branch (the user is on `main` by convention; if not, exit).
- **No timers, no sleeps inside the skill** — the periodicity comes from `/loop`.

## Periodic use

- Fixed cadence — `/auto-deploy 60` (every minute, the fastest the runtime allows).
- Dynamic cadence — `/loop /auto-deploy` (Claude self-paces between 60–3600s, backing off when nothing's happening).

Stop the loop normally (interrupt or `/loop stop`).

## Output expectations

Always finish with a one-line summary the user can scan at a glance:
- `up to date — skipped` (no work)
- `no device — skipped`
- `working tree dirty — skipped`
- `installed <short-sha> on <device-name>` (success path)
- `build failed: <first error line>` (or analogous failure messages)
