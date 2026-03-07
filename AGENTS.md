# AGENTS.md

Guidance for coding agents working in `/home/henry/.config/emacs`.

## Repo Snapshot

- Project type: modular Emacs configuration (Emacs Lisp).
- Entry points: `early-init.el`, `init.el`.
- Main modules live in `lisp/`.
- Package management uses built-in `package.el` + `use-package`.
- Runtime artifacts are ignored via `.gitignore` (`elpa/`, `eln-cache/`, DB/cache files).

## Quick Start Commands

- Smoke test full config load:
  - `emacs --batch -Q -l "/home/henry/.config/emacs/early-init.el" -l "/home/henry/.config/emacs/init.el" --eval "(princ \"ok\")"`
- Byte-compile one module (lint-like syntax check):
  - `emacs --batch -Q -l "/home/henry/.config/emacs/early-init.el" -l "/home/henry/.config/emacs/init.el" -f batch-byte-compile "/home/henry/.config/emacs/lisp/workflow-search.el"`

## Build / Lint / Validation Strategy

- Treat these as the standard validation stack:
  1. Config smoke-load command.
  2. Byte-compile edited module(s).
- Avoid byte-compiling with bare `-Q` only; ensure config/package load-path is initialized.

## Architecture and Module Boundaries

- `early-init.el`: startup defaults/performance knobs only.
- `init.el`: module orchestrator (`require` chain) only.
- `lisp/core-packages.el`: package archives + `use-package` bootstrap.
- `lisp/core-ui.el`: completion and minibuffer UX defaults.
- `lisp/org-core.el`: base Org directories and core Org behavior.
- `lisp/org-roam-config.el`: Org-roam setup and capture templates.
- `lisp/workflow-lifecycle.el`: idea/task/resolved state transitions.
- `lisp/workflow-triage.el`: quick-capture triage loop/actions.
- `lisp/workflow-search.el`: saved views and search commands.
- `lisp/workflow-media.el`: image workflows (`org-download`).
- `lisp/workflow-keys.el`: centralized `C-c n` keymap bindings.

## Code Style Guidelines

### File Header and Module Shape

- Use standard Emacs Lisp file header:
  - `;;; file.el --- short purpose  -*- lexical-binding: t; -*-`
- Add a concise top comment describing file responsibility.
- End each module with `(provide 'feature-name)`.
- Keep one feature per file; avoid mixed-responsibility modules.

### Imports and Dependencies

- Prefer explicit `(require '...)` for every external symbol used.
- Keep `require` statements near top of file.
- In `use-package`, keep `:init` for variable setup and `:config` for behavior/hooks.
- Do not rely on transitive requires from unrelated modules.

### Naming Conventions

- Public commands: `workflow-...`.
- Internal helpers: `workflow--...` (double hyphen).
- Triage-internal helpers: `workflow-triage--...` etc.
- Predicates should end with `-p`.
- Constants/customization vars should be descriptive and namespaced (`workflow-...`).

### Formatting and Layout

- Follow canonical Elisp indentation (let Emacs indent forms).
- Keep expressions readable; split long forms vertically.
- Prefer one logical operation per line in `setq` blocks.
- Keep docstrings short, imperative, and accurate.
- Use ASCII unless file already requires Unicode.

### Types and Data Handling

- Use lists for tags and symbol/string collections consistently.
- Be explicit about string handling (`string-trim`, `string-empty-p`).
- Guard against `nil` where user input is optional.
- For time comparisons, use time-aware comparators (`time-less-p`), not numeric `<`.

### Error Handling and UX

- Use `user-error` for actionable, user-facing failures.
- Validate preconditions before prompting for additional input.
- Fail fast on missing tags/state requirements.
- Keep messages concise and workflow-oriented.
- Preserve user context (buffer/window) where practical.

### Side Effects and Persistence

- When mutating note metadata, save buffer and refresh org-roam DB as needed.
- Keep filesystem writes localized and deterministic.
- Prefer org-roam/Org APIs over ad-hoc text edits where possible.

## Workflow Semantics to Preserve

- Tag-based lifecycle is intentional.
- Open task semantics:
  - tag includes `task`
  - tag excludes `resolved`, `cancelled`, `archived`
- Active task semantics:
  - open task and not tagged `blocked`
- Quick capture semantics:
  - low-friction capture path, triaged later.

## Editing and Safety Rules for Agents

- Do not edit `elpa/`, `eln-cache/`, DB files, or other generated runtime artifacts.
- Do not commit secrets or machine-local credentials.
- Keep keybinding changes centralized in `lisp/workflow-keys.el`.
- Keep search/view behavior centralized in `lisp/workflow-search.el`.
- Prefer additive, minimal changes over broad refactors.

## Suggested Change Checklist

- Updated or added module header and purpose comment.
- Required dependencies declared explicitly.
- New commands are interactive only when intended for user invocation.
- Keybindings added only in `workflow-keys.el`.
- Smoke-load command passes.
- Edited module byte-compiles cleanly.
