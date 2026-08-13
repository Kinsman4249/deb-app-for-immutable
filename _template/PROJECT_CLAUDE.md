# Starter Claude directives

Project-local rules for this repo. Where these overlap the global
`~/.claude/CLAUDE.md`, these win; only project-specific deltas belong here.

<!-- DELETE-ON-ADOPT --------------------------------------------------------
     Everything from this marker down explains what belongs in this file, and
     is meant to be deleted when the file is adopted as `/CLAUDE.md`. The
     `newproj` skill deletes it automatically and rewrites the heading above
     with the project name. Adopting by hand? Delete from this marker to the
     end of the file yourself.
-->

## What actually belongs here

Once adopted, this file is gitignored. Three consequences follow, and they are
the whole reason this section exists:

- It loads into every session opened in this repo, and the global directives
  load alongside it. A rule written in both places is paid for twice and obeyed
  once.
- No reviewer ever sees it, and no CI can lint it, cap its size, or check it
  for drift. `lint-ascii.yml` cannot see it either.
- Nothing can update it in bulk. A rule copied here from the global directives
  or from a skill keeps saying the old thing long after the original changes,
  quietly, in every repo that copied it.

So do not restate the defaults. Style, comments, ASCII, the release process,
and the changelog entry rules already live in the global directives and in the
`release-*` skills, which enforce them at the moment they apply rather than
hoping someone remembered to read them.

Write down only what someone would otherwise get wrong in THIS repo:

- A build, test, or run command that is not discoverable from the repo itself.
- A convention this project deliberately breaks, and why it breaks it.
- A path that must not be hand-edited, and what owns it instead.
- A gotcha that has already cost someone an hour.

Delete a heading rather than filling it in with the default answer. An empty
file is a correct file. One that restates the global directives is a slow leak
that nothing downstream can find.
