# Emacs Personal Task Workflow System — Implementation Plan

## Decisions Already Made

- Configuration layout: modular Elisp files with distinct purposes.
- Keybinding prefix for workflow commands: `C-c n`.
- Note model: one note per document/buffer (Org-roam style).
- Link model: backlinks are first-class and treated symmetrically with forward links in core operations.
- Workflow style: knowledge-first with lightweight task lifecycle, not deadline-driven planning.

## User Stories

### Core capture, search, and linking

- I want to be able to capture an idea quickly from Emacs using a short key sequence, so that I can externalize thoughts without interrupting flow.
- I want to be able to capture reference information (including bookmarks/links) as notes using templates, so that useful context is preserved and easy to revisit.
- I want to be able to search all notes and tasks with plaintext regex using in-Emacs commands, so that I can quickly find relevant past work and information.
- I want to be able to create links between notes using stable IDs, so that relationships are durable even if files are moved or renamed.
- I want to be able to see linked notes/backlinks while viewing a note in the same interaction model as forward links, so that links behave symmetrically in practice.

### Task lifecycle

- I want to be able to promote an idea note into one or more task notes using a command, so that exploratory thinking can become actionable work.
- I want to be able to define a done criterion in each task note using a required field, so that every task has a definite endpoint.
- I want to be able to promote a task note into a resolved note with required resolution reason and consequences, so that completion context is captured for future decisions.
- I want to be able to review open tasks and recently resolved items via saved views/queries, so that I can triage and execute intentionally without a heavy deadline system.

### Media and future AI assistance

- I want to be able to paste or insert an image directly into a note using an automated save-and-link flow, so that visual information is captured with minimal friction.
- I want to be able to run an AI assistant against either SaaS or local models through one Emacs interface, so that model hosting can change without rewriting workflow.
- I want to be able to get AI suggestions for similar notes and candidate links with explicit approval, so that graph quality improves without silent modifications.
- I want to be able to get AI suggestions that convert idea notes into proposed tasks and implementation options with explicit approval, so that planning accelerates while I retain control.

## Planned Action Phases

### Phase 1 — Foundation (Org + notes + capture)

Status: completed on 2026-03-07.

1. [x] Create modular Emacs config structure (`early-init.el`, `init.el`, and `lisp/*.el`).
2. [x] Bootstrap package management and core UI/navigation stack.
3. [x] Install/configure Org and Org-roam.
4. [x] Define base directories (`~/org/roam`, `~/org/assets`, optional inbox fallback).
5. [x] Add capture templates for note types: `idea`, `task`, `resolved`, `ref`.
6. [x] Bind core workflow commands under `C-c n`.
7. [x] Add quick capture (`C-c n c`) with no title prompt.
8. [x] Ensure capture uses full-screen window behavior.
9. [x] Fix `org-id-locations` warning by setting/creating a valid locations file under `~/org`.

### Phase 2 — Lifecycle semantics (idea -> task -> resolved)

Status: completed on 2026-03-07.

1. [x] Define task metadata fields and required sections (notably done criteria).
2. [x] Implement command to promote current idea note into one or multiple tasks.
3. [x] Implement command to resolve a task into resolved state/note.
4. [x] Add validation guards for required fields on transitions.

### Phase 2.5 — Triage workflow for quick captures

Status: completed on 2026-03-07.

1. [x] Add a triage command to list/process notes tagged `:quick:`.
2. [x] Add actions to convert quick notes into structured idea notes.
3. [x] Add actions to promote quick/idea notes into tasks during triage.
4. [x] Add actions to archive/cancel notes that are no longer relevant.
5. [x] Add a one-by-one triage loop command for low-friction inbox processing.

### Phase 3 — Search, navigation, and link symmetry in use

Status: completed on 2026-03-07.

1. [x] Configure regex search over notes (`consult-ripgrep` or equivalent).
2. [x] Add backlinks/related-items views in the primary reading workflow.
3. [x] Add saved query commands for open tasks, linked tasks, and recent resolutions.
4. [x] Define and implement tag-based open-task semantics: `:task:` and not tagged `:resolved:`, `:cancelled:`, or `:archived:`.
5. [x] Add active-task view as open tasks excluding `:blocked:`.

### Phase 4 — Image workflow

Status: completed on 2026-03-07.

1. [x] Configure `org-download` for paste/screenshot flows.
2. [x] Ensure images are stored in `~/org/assets` (or per-note subdirs if preferred).
3. [x] Add helper command/keybinding to insert and preview images inline.

### Phase 5 — AI extension layer (optional, approval-based)

1. Add `gptel` abstraction supporting SaaS and local endpoints.
2. Implement similar-note/link suggestion command (preview + accept/reject).
3. Implement idea-to-task suggestion command (preview + accept/reject).
4. Keep all AI writes explicit and user-confirmed.

## Modular File Intent (implemented in Phase 1)

- `early-init.el`: startup/performance defaults and package startup behavior.
- `init.el`: orchestrator that loads all modules in a clear order.
- `lisp/core-packages.el`: package repositories/bootstrap and package install setup.
- `lisp/core-ui.el`: completion/search UX defaults (e.g., vertico/orderless/marginalia/consult).
- `lisp/org-core.el`: base Org behavior, files, and capture defaults.
- `lisp/org-roam-config.el`: Org-roam directories, DB autosync, node/capture templates.
- `lisp/workflow-lifecycle.el`: custom commands and validation for idea/task/resolved transitions.
- `lisp/workflow-triage.el`: quick-capture triage actions and one-by-one triage loop.
- `lisp/workflow-search.el`: regex/search commands, saved task views, linked-task views, and related-notes panel helpers.
- `lisp/workflow-media.el`: image capture commands (clipboard/screenshot), asset directory policy, and inline display helpers.
- `lisp/workflow-keys.el`: all `C-c n` keybindings in one place.
- `lisp/workflow-ai.el`: optional AI integration scaffold, disabled unless configured.

## Definition of Done for Initial Build

- Fast note capture works from `C-c n` flows for idea/task/ref/resolved notes.
- Regex search across the note corpus is available and discoverable.
- Backlinks are visible and practically symmetric with forward-link workflows.
- Idea-to-task and task-to-resolved transitions are implemented with required fields.
- Image paste into notes saves files and inserts valid links.
- Config is modular, each file has a distinct purpose documented at top.

## Current Status Snapshot

- Completed now: foundational modular config, fast capture workflow, and lifecycle transitions (`idea -> task -> resolved`).
- Completed now: quick-capture triage workflow (`quick -> idea/task/archive/cancel`) with one-by-one inbox loop.
- Completed now: Phase 3 search/navigation with tag-based open-task semantics and active-task filtering.
- Completed now: Phase 4 image workflow with org-download and inline preview commands.
- Ready next: Phase 5 AI extension layer (optional).
- Deferred by design: AI suggestions (Phase 5).
