# New project quickstart

What this covers: the full walkthrough from "I have an idea" to "I just shipped my first release," using VS Code and this template repo. Written for someone new to version control - every step explains what's happening and why. For VS Code installation and sign-in, see [vscode-setup.md](./vscode-setup.md) first.

## What you'll have at the end

- A new repo on GitHub with your code in it.
- The release workflow from this template repo wired up.
- A first GitHub Release tagged `v0.1.0` with downloadable artifacts attached.
- A clear pattern for tagging future releases (`v0.1.1`, `v0.2.0`, `v1.0.0`, etc.) - usually a one-button operation in VS Code.

Total time: ~10 minutes the first time, ~30 seconds for every release after that.

## Step 1 - Create the new repo on GitHub.com

1. Open [https://github.com/new](https://github.com/new) in your browser.
2. Fill in:
   - **Repository name** - short, lowercase-with-hyphens (e.g. `my-cool-tool`).
   - **Description** - one sentence about what it does.
   - **Public** or **Private** - your call. Public means the world can see it.
   - **Initialize this repository with: README** - check it. (Without this you'd have an empty repo, which is annoying to clone.)
   - **Add .gitignore** - pick the template matching your language (e.g. "Node", "Python"). Pick "None" for shell projects.
   - **Choose a license** - MIT or Apache 2.0 are common, friendly defaults.
3. **Default branch** - leave as `main`. The release workflow assumes `main`.
4. Click **Create repository**.

You now have a repo at `https://github.com/Kinsman4249/<your-repo-name>`.

Now clone it into VS Code - see [vscode-setup.md](./vscode-setup.md#clone-a-repo-into-vs-code).

## Step 2 - Add the release workflow

This wires up automatic release builds whenever you push a version tag.

1. In VS Code, create a new folder: right-click in the Explorer panel -> **New Folder** -> name it `.github`. Inside that, create another: `workflows`. (Yes, the leading `.` is intentional.)
2. Inside `.github/workflows/`, create a new file: right-click -> **New File** -> name it `release.yml`.
3. Copy the contents of `.github/workflows/release.yml` from `Kinsman4249/.github-private` and paste them into your new file. Save (`Ctrl+S` / `Cmd+S`).
4. The default bundle step needs no edits and runs as-is. If you also want a compiled build for your language, uncomment the matching block - see [release-languages.md](./release-languages.md).
5. Save the file.

See [release-workflow.md](./release-workflow.md) for what this workflow actually does.

## Step 3 - (Optional) Add community health files

Skip this for personal projects you don't expect contributions to.

For a public project that may attract contributors, copy these from `.github-private` into your new repo:

- `CODE_OF_CONDUCT.md` (top level)
- `CONTRIBUTING.md` (top level)
- `SECURITY.md` (top level)
- `.github/ISSUE_TEMPLATE/bug_report.md`
- `.github/ISSUE_TEMPLATE/feature_request.md`
- `.github/PULL_REQUEST_TEMPLATE.md`

Each contains placeholders like `<PROJECT_NAME>`, `<REPO_URL>`, `<TESTING_INSTRUCTIONS>`. Use VS Code's find-and-replace (`Ctrl+H` / `Cmd+H`) on each file to fill them in.

## Step 4 - Make your first commit and push

A "commit" is a snapshot of your changes. "Push" sends those snapshots up to GitHub.

1. Click the **Source Control** icon in VS Code's left activity bar (it looks like three dots connected by lines - like a small tree).
2. You'll see a list of changed/new files under **Changes**.
3. Hover over **Changes** and click the **+** icon to stage everything (this means "include in the next commit"). Or click **+** next to individual files.
4. Type a commit message in the text box at the top of the Source Control panel. Something like: `Add release workflow and project setup`.
5. Click the blue **Commit** button (or press `Ctrl+Enter` / `Cmd+Enter`).
6. Click **Sync Changes** (the button that appears after committing) to push to GitHub. Confirm if prompted.

> Equivalent terminal commands:
> ```bash
> git add .
> git commit -m "Add release workflow and project setup"
> git push
> ```

Refresh your repo on github.com - you should see your files there now.

## Step 5 - Tag your first release

This is the magic moment. Tagging triggers the workflow you set up.

### Option A - VS Code UI (recommended for beginners)

1. Click the **Source Control** icon.
2. Click the **`...`** (More Actions) menu at the top of the panel -> **Tags** -> **Create Tag**.
3. Enter `v0.1.0` (the leading `v` is required by the workflow).
4. For "Tag message", just press Enter (empty is fine).
5. Click the **`...`** menu again -> **Push** -> **Push Tags**. (Or pick **Push (Follow Tags)** if shown.)

### Option B - Terminal (faster once you're used to it)

Open a terminal in VS Code with `` Ctrl+` `` (backtick) and run:

```bash
git tag v0.1.0
git push --tags
```

### What happens next

- Go to your repo on github.com -> **Actions** tab. You should see a workflow run named **Release** kicking off within a few seconds.
- It runs for ~1-3 minutes (longer for cross-platform builds).
- When it finishes, go to the **Releases** tab on the right side of your repo page. You'll see **v0.1.0** with downloadable artifacts (`.tar.gz` and `.zip` files) and auto-generated release notes.

You shipped your first release.

## Quick release loop (after the first one)

Once you've done the setup above, every subsequent release is just:

1. Make your changes.
2. Commit them via VS Code's Source Control panel.
3. Push.
4. Open Source Control's **`...`** menu -> **Tags** -> **Create Tag** -> enter the next version -> push tags.

Or in the terminal, in two lines:

```bash
git commit -am "fix: handle empty input"
git push && git tag v0.1.1 && git push --tags
```

The workflow does the rest.

## Where to go next

- [release-workflow.md](./release-workflow.md) - deeper explanation of the release workflow and how to run it manually.
- [release-languages.md](./release-languages.md) - adding a compiled build for your language.
- [versioning.md](./versioning.md) - the `vMAJOR.MINOR.PATCH` convention behind tags.
- [troubleshooting.md](./troubleshooting.md) - common gotchas with this flow.

---

Back to [template index](../README.md)
