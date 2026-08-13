# Editor setup: VS Code

What this covers: one-time VS Code and GitHub sign-in setup, cloning a repo, and the UI landmarks referenced elsewhere in these docs. See [new-project.md](./new-project.md) for the full new-project walkthrough that uses these.

---

## Prerequisites (one-time setup)

Make sure these are installed and signed in. You only ever do this once.

1. **VS Code** - [download here](https://code.visualstudio.com/).
2. **Git** - [download here](https://git-scm.com/downloads). Verify in any terminal: `git --version`.
3. **Sign in to GitHub from VS Code** - click the **Accounts** icon (the little person silhouette at the bottom of VS Code's left activity bar) -> **Sign in to use GitHub**. A browser window opens, you click Authorize, you're done.

### On an immutable Fedora host

If the host OS is immutable (Bazzite, Silverblue, Kinoite), steps 1 and 2 do
not apply as written - you cannot install packages onto the base OS. Run
[vscodium-for-immutable](https://github.com/Kinsman4249/vscodium-for-immutable)
instead. One script builds a `vscodium-box` container and installs VSCodium,
git, gh, and a lint toolchain (shellcheck, actionlint, jq, fd, yamllint)
inside it, then exports the editor to the host application menu. The editor's
integrated terminal runs inside that container, so everything the script
installs is already on PATH.

Keep environment changes in that installer. A tool installed by hand into the
container disappears on the next rebuild, and a missing tool is how a
verification step gets silently skipped.

## Clone a repo into VS Code

"Clone" means downloading the repo to your local machine so you can edit it.

1. On the repo's GitHub page, click the green **Code** button -> copy the HTTPS URL (e.g. `https://github.com/Kinsman4249/my-cool-tool.git`).
2. Open VS Code.
3. Open the **Command Palette** with `Ctrl+Shift+P` (Windows/Linux) or `Cmd+Shift+P` (Mac).
4. Type `Git: Clone` and press Enter.
5. Paste the URL, press Enter.
6. Pick a folder on your machine where the project should live (e.g. `~/projects`). VS Code creates a subfolder named after the repo.
7. When prompted, click **Open** to open the cloned repo.

You're now inside the project in VS Code. The bottom-left status bar should show a branch name (`main`).

> Equivalent terminal command: `git clone https://github.com/Kinsman4249/my-cool-tool.git && cd my-cool-tool && code .`

## UI landmarks used throughout these docs

- **Command Palette** - `Ctrl+Shift+P` / `Cmd+Shift+P`. The fastest way to run any VS Code command by name.
- **Source Control panel** - the icon in the left activity bar that looks like three dots connected by lines. Shows changed/new files, and is where you stage, commit, push, and create tags from the UI.
- **Accounts icon** - the person silhouette at the bottom of the left activity bar. Used for GitHub sign-in.
- **Integrated terminal** - `` Ctrl+` `` (backtick) opens a terminal inside VS Code, for when the terminal command is faster than the UI equivalent.

---

Back to [template index](../README.md)
