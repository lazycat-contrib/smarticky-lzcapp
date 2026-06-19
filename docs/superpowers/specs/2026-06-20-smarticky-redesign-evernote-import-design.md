# Smarticky redesign, editor upgrade, and Evernote import design

Date: 2026-06-20

## Context

This repository is the LazyCat packaging repository for Smarticky. The package manifest points at an upstream Smarticky application image, while the application source currently lives in the upstream Go project at `https://github.com/dockers-x/smarticky`.

The inspected upstream application is a Go + Echo + Ent + SQLite app with server-rendered HTML templates, embedded static assets, and vanilla JavaScript/CSS. The current UI already has notes, tags, attachments, backup, users, fonts, locking, markdown preview, image export, themes, and i18n, but many workflows are concentrated in one large `web/static/js/app.js` file and modal-heavy templates.

The frontend is not a hard constraint for this project. The backend, data model, deployment shape, and existing user data are real constraints. The current vanilla JS implementation should be treated as reference behavior and migration material, not as the target architecture.

## Product thesis

Smarticky should move from "a notes app with many feature buttons" to "a quiet personal notes workspace that can absorb migrated content and keep it organized." The Smartisan-inspired visual language is the surface expression of that product model: restrained, precise, warm, and low-noise.

Evernote import is not a backup/restore feature. It is a content migration feature with preview, mapping, import history, partial failure reporting, and a clear way to understand what entered the library.

The clean technical model is: keep the Go backend as the durable API and storage layer, rebuild the frontend as a modern typed workspace, and embed the compiled frontend assets into the Go binary for the same deployment ergonomics.

## Refactor thesis

This redesign should include a real frontend re-architecture. The current all-in-one `app.js`, inline event handlers, modal-heavy template, and scattered inline styles encode the wrong model: the UI is organized around where features were added, not around how a person writes, finds, imports, and organizes notes.

The target is a small single-page app served by the Go backend. The selected stack is Svelte + TypeScript + Vite for the app shell and stateful UI, plus CodeMirror 6 for the writing surface. This keeps the runtime light while giving the editor, import flow, and workspace enough structure to evolve.

## Goals

1. Redesign the main note workspace using the approved Smartisan-style design language.
2. Improve the editing experience as a core workflow, not as cosmetic polish.
3. Add an Evernote import center for `.enex` files with preview and reliable import results.
4. Preserve current core features: authentication, notes, tags, attachments, backup, fonts, image export, i18n, dark mode, and LazyCat deployment.
5. Keep the Go backend, SQLite data, API authentication, embedded static asset deployment, and LazyCat packaging compatible.
6. Replace the current frontend architecture where that makes the product materially easier to build and maintain.

## Non-goals

1. Do not rewrite the Go backend for novelty. Backend refactors should serve import, editor, API, data model, or deployment needs.
2. Do not create a marketing landing page.
3. Do not merge Evernote import into backup/restore.
4. Do not build full Evernote sync. This is one-time `.enex` import only.
5. Do not preserve every Evernote-specific feature if it has no stable place in Smarticky. The importer should preserve notes, timestamps, tags, resources, and readable content first.
6. Do not keep the vanilla JS architecture merely for compatibility. If a feature moves into the new frontend, remove the old duplicate path.

## Architecture direction

### Backend

Keep Go + Echo + Ent + SQLite. The backend owns:

- Auth and setup.
- Notes, tags, attachments, fonts, backup, users.
- Evernote import parsing, conversion, import history, and attachment persistence.
- Serving the compiled frontend assets.

Backend route handlers should move toward smaller service-backed handlers where import or shared note logic becomes substantial. Direct Ent usage in handlers is acceptable for simple CRUD, but import should have a dedicated parser and service layer.

### Frontend

Selected target stack:

- Svelte + TypeScript for workspace UI.
- Vite for build tooling.
- CodeMirror 6 for Markdown editing and command handling.
- Existing `marked`/image export logic may be reused or replaced if the new editor architecture makes a cleaner path available.
- A small app-level store for auth, notes, filters, editor state, import jobs, theme, and language.

The new frontend should compile to static assets that Go embeds and serves. Go templates should become a thin fallback/container only, not the primary UI composition layer.

### Frontend kill list

Remove or retire these concepts from the redesigned workspace:

- Inline `onclick` handlers for core note, editor, import, and settings flows.
- Inline styles for repeated UI elements.
- A single global `app.js` as the owner of all app behavior.
- `window.alert()` and `window.confirm()` for redesigned flows.
- Feature-specific modal sprawl for primary workflows.
- Duplicated editor modes or compatibility functions that no longer match the chosen editor model.

## Design language

The implementation should use the provided Smartisan-style prompt as the design source of truth, adapted to web constraints and the existing app.

### Colors

Use warm neutrals and a single restrained brand accent.

- Primary brand: `#E8450A`
- Surface page: `#FAFAF8`
- Surface card: `#FFFFFF`
- Surface secondary: `#F1EFE8`
- Text primary: `#1A1A18`
- Text secondary: `#444441`
- Text muted: `#888780`
- Placeholder: `#B4B2A9`
- Divider: `#E8E6E0`
- Dark background: `#1C1C1A`
- Dark card: `#242420`
- Dark divider: `#333330`
- Destructive: `#E24B4A`

### Typography

Use system-native fonts with a warm Chinese-first stack:

`-apple-system, BlinkMacSystemFont, "PingFang SC", "Source Han Sans SC", "Noto Sans CJK SC", "Microsoft YaHei", "Segoe UI", sans-serif`

Use only regular `400` and medium `500` for the redesigned workspace. Avoid heavy bold weights. Use `letter-spacing: 0` in implementation for app UI stability; create precision with size, line-height, weight, and spacing.

Core sizes:

- Note title: `19px`, weight `500`, line-height `1.35`
- Body editor: `15px`, weight `400`, line-height `1.85`
- List preview: `13px`, weight `400`, line-height `1.6`
- Group header: `11px`, weight `400`, uppercase-style label where appropriate, muted color
- Metadata: `11px`, weight `400`

### Spacing and surfaces

Use an 8px spacing grid. The main repeated values are:

- Page horizontal padding: `20px`
- Card padding: `16px`
- Card gap: `8px`
- Toolbar height: `48px`
- Bottom action bar height: `64px`
- FAB: `48px` square, right `20px`, bottom safe area plus `16px`
- Card radius: `10px`
- Search radius: `10px`
- Tag radius: `999px`
- Dividers: visually hairline, implemented as `1px` with low-contrast color for browser reliability

## Information architecture

The desktop app should keep the three-pane mental model, but reduce visual noise.

1. Navigation pane
   - Main groups: All notes, Starred, Tags, Trash.
   - Secondary tools move into a quiet settings/tools area: Backup, Font management, Profile, User management, Import.
   - The active state uses the orange-red accent sparingly.

2. Note list pane
   - Search is first-class and visually calm.
   - Notes are grouped by Today, Yesterday, This week, Earlier.
   - Cards show title, short preview, tags, attachment/lock/star metadata, and updated time.
   - Sorting and filtering are available near search, not hidden in unrelated footer icons.
   - Empty state follows the approved copy:
     - Main: "写下你的第一篇笔记"
     - Secondary: "记录想法，沉淀思考"

3. Editor pane
   - Title and body should feel like one writing surface.
   - Toolbars are divided into primary writing actions and secondary note actions.
   - Tags and attachments should become quiet inspector sections, not intrusive blocks inside the writing flow.
   - On mobile, the app should behave as a list-to-editor flow with a clear back action.

## Editor experience

The editor upgrade is part of the core scope.

### Entry behavior

- Selecting an existing note opens the editor and keeps focus behavior predictable.
- Creating a new note creates the note, opens the editor, and focuses the title.
- If a note already has a title, entering edit mode should place the caret at the title end only when the user explicitly starts editing the title. It should not steal focus from search or from list navigation unexpectedly.

### Writing surface

- Title and body use borderless inputs/textarea or equivalent content areas with visual hierarchy only through typography.
- The body line-height is intentionally generous.
- The source editor should not feel like a developer textarea. It should use a calm paper-like writing surface.
- Preview should be available, but the source/preview switch must not feel like two unrelated pages.

### Markdown controls

The writing toolbar should provide:

- Bold
- Italic
- Unordered list
- Ordered list
- Task item
- Insert image or attachment
- Preview/source toggle

Controls should be icon-first, 18px visual size, with clear tooltips. Active/pressed states use `#F1EFE8` in light mode and a warm dark equivalent in dark mode.

### Save state

- Autosave remains debounced.
- Saving/saved/error state appears near the editor header as quiet inline status, not as alerts.
- Manual save shortcut should confirm current state without implying a separate save model.
- Failed save shows a persistent inline message with retry guidance.

### Tags and attachments

- Tags are visible in the editor header/inspector and editable without pushing the writing surface down.
- Attachments are attached through the writing toolbar and managed in a collapsible inspector.
- Imported Evernote resources become attachments and referenced images should be rendered in the imported markdown where possible.

### Focus mode

Add a focus mode as a stretch target in this redesign phase if the main editor refactor lands cleanly:

- Hide note list and secondary toolbars.
- Keep title, body, save state, and a minimal exit control.
- Preserve keyboard shortcuts.

## Evernote import center

Evernote import should be a dedicated content workflow.

### Supported input

- File type: `.enex`
- Upload mode: multipart upload through authenticated API.
- Initial version supports one uploaded `.enex` file per import job.
- The UI may later allow multiple files, but the backend model should not assume only one job ever exists.

### Preview flow

1. User opens Import from navigation/tools.
2. User uploads an `.enex` file.
3. Server parses the file and returns a preview:
   - note count
   - tag count
   - resource/attachment count
   - notes with missing title
   - resources that cannot be decoded
   - estimated import size
4. User chooses import options:
   - import all notes
   - skip probable duplicates
   - map exported notebook name to a tag, using the uploaded filename as default notebook label
5. User confirms import.

### Import execution

The importer should convert Evernote ENEX notes into Smarticky notes:

- Evernote title maps to Smarticky note title.
- Evernote ENML content converts to readable Markdown or sanitized HTML-like Markdown.
- Evernote created/updated timestamps map to note `created_at` and `updated_at`.
- Evernote tags map to Smarticky tags for the current user.
- Evernote resources map to Smarticky attachments.
- Embedded image references should be rewritten to local attachment URLs when possible.

### Import data model

Add import tracking instead of directly creating notes without history.

Recommended entities:

- `ImportJob`
  - `id`
  - `user_id`
  - `source`: fixed value `evernote` for this feature
  - `filename`
  - `status`: `previewed`, `running`, `completed`, `completed_with_errors`, `failed`
  - `note_count`
  - `imported_count`
  - `skipped_count`
  - `failed_count`
  - `created_at`
  - `completed_at`
  - `options_json`

- `ImportItem`
  - `id`
  - `import_job_id`
  - `source_note_key`
  - `note_id`, optional until created
  - `title`
  - `status`: `pending`, `imported`, `skipped`, `failed`
  - `message`

Duplicate detection should use a pragmatic key for the first version: normalized title plus Evernote created timestamp plus content hash. This avoids a hard dependency on Evernote GUID availability.

### Import error handling

- Preview parse failure returns a clear error: invalid file, unreadable XML, unsupported structure, oversized upload, or resource decode failure.
- A single bad note should not fail the whole import after confirmation.
- Completed imports with failed items should show a result summary and let the user inspect failed items.
- The first version does not need full rollback, but ImportJob history must make imported notes identifiable.

## Backend changes

1. Add parser package for Evernote ENEX.
2. Add importer service that converts parsed notes into Ent entities.
3. Add authenticated import API routes:
   - `POST /api/import/evernote/preview`
   - `POST /api/import/evernote/confirm`
   - `GET /api/import/jobs`
   - `GET /api/import/jobs/:id`
4. Add Ent schemas for `ImportJob` and `ImportItem`.
5. Extend note creation path or importer path to set original `created_at` and `updated_at`.
6. Reuse existing attachment storage through the filesystem abstraction.
7. Fix tag filtering in `ListNotes`; imported tags must immediately be usable for navigation and search.

## Frontend changes

Build a new frontend app rather than incrementally stretching the current vanilla JS file.

Target source organization:

- `web/app/package.json`: frontend build entry and scripts.
- `web/app/src/main.ts`: app bootstrap.
- `web/app/src/App.svelte`: root layout and route/view switching.
- `web/app/src/lib/api/`: typed API client.
- `web/app/src/lib/stores/`: auth, notes, filters, editor, theme, i18n, import.
- `web/app/src/lib/components/workspace/`: navigation, search, note list, note card, empty states.
- `web/app/src/lib/components/editor/`: title field, CodeMirror editor, toolbar, save state, inspector.
- `web/app/src/lib/components/import/`: Evernote import center.
- `web/app/src/lib/components/settings/`: backup, fonts, profile, users, tools.
- `web/app/src/lib/styles/tokens.css`: Smartisan token system.
- `web/app/src/lib/styles/global.css`: base, accessibility, motion, dark mode.

Target compiled output:

- `web/static/app/` or another generated directory embedded by Go.
- The Go root route serves the compiled SPA shell.
- Legacy templates can remain temporarily for login/setup if that lowers migration risk, but the main authenticated workspace should move to the new frontend.

The first frontend milestone should not attempt to preserve the old DOM structure. It should preserve user-facing behavior through typed API calls and explicit state, then delete old paths once equivalent flows exist.

### Frontend framework rationale

Svelte is selected over React for this project because the app is interaction-heavy but not ecosystem-heavy. It gives a compact component model, low runtime weight, and straightforward CSS ownership, which fits the Smartisan-style precision requirement. Do not revisit the framework choice unless implementation finds a concrete blocker that cannot be solved cleanly in Svelte.

CodeMirror 6 is preferred for the editor because Markdown editing, selection-aware commands, keyboard handling, history, and future syntax features are editor-domain problems. Hand-rolling those behaviors in a textarea would recreate known edge cases.

## Interaction and motion

Use restrained motion:

- Pane transitions: small `translateX(20px)` and opacity, 280-320ms.
- New note card: `translateY(8px)` and opacity, 280ms.
- Pressed FAB: scale to `0.92`, 180ms.
- Deletion: opacity and height collapse, around 240ms.

Respect `prefers-reduced-motion`.

## Accessibility

- All icon-only buttons need accessible labels and visible tooltips or titles.
- Keyboard focus states must be visible.
- Avoid `window.alert()` and `window.confirm()` in redesigned flows. Use inline messages or app dialogs.
- Search, editor, import confirm, and destructive actions must be usable by keyboard.
- Color must not be the only signal for selected, error, or destructive states.

## Testing and verification

Backend:

- Unit tests for ENEX parser:
  - normal note
  - note with tags
  - note with image resource
  - malformed XML
  - missing title
  - undecodable resource
- Handler tests for preview and confirm routes.
- Import service tests for duplicate skipping and partial failure handling.

Frontend/manual:

- Create, edit, autosave, delete, restore note.
- Search and tag filter after importing notes.
- Upload attachment from editor.
- Preview/import `.enex` with and without resources.
- Dark mode visual pass.
- Mobile list-to-editor flow.
- LazyCat package starts with data stored under `/data`.
- TypeScript build passes.
- Frontend type checks pass.
- CodeMirror toolbar commands work for selected text and empty-line insertion cases.

Visual verification:

- Desktop screenshot at 1440px width.
- Mobile screenshot at 390px width.
- Check text overflow in note cards, toolbar buttons, import result rows, and settings lists.
- Check that the page does not collapse into a one-note orange/red palette.

## Implementation sequence

1. Source setup
   - Work in the upstream Smarticky source repo or vendor it into a development workspace.
   - Keep this LazyCat repo for manifest/image version updates after the app image is built.
   - Add frontend build tooling under `web/app`.
   - Wire Go embedding to serve the compiled frontend assets.

2. Frontend foundation
   - Add design tokens.
   - Build the authenticated app shell, API client, stores, layout, and routing/view switching.
   - Keep login/setup on legacy templates temporarily unless moving them is equally cheap.
   - Prove the new frontend can authenticate, fetch notes, create a note, and render the workspace.

3. Editor and workspace
   - Redesign main workspace shell.
   - Redesign note cards, grouping, search, filters, and empty states.
   - Build the CodeMirror-based editor, toolbar, save state, tag/attachment placement, and preview.
   - Replace the old authenticated workspace route with the compiled frontend.

4. Organization fixes
   - Complete tag filtering backend and frontend.
   - Move secondary tools into settings/tools structure.
   - Replace old alerts/confirms in migrated flows with app-level dialogs/messages.
   - Delete old workspace code once the new flow owns the equivalent behavior.

5. Evernote import
   - Add ENEX parser tests.
   - Add import schemas and APIs.
   - Add import center UI.
   - Verify imported tags, timestamps, content, and attachments.

6. Packaging
   - Build the new Smarticky app image.
   - Update `lzc-manifest.yml` image tag/digest and version.
   - Build new `.lpk`.

## Migration strategy

Use a strangler-style migration for user-facing risk, but do not keep dual implementations long term.

1. Introduce the new frontend app behind the same authenticated root route in development.
2. Keep old templates available only as reference or temporary fallback during the first milestone.
3. Move one complete vertical slice first: authenticate, list notes, select note, edit title/body, autosave.
4. Once a slice is verified, remove the equivalent old workspace behavior from the served path.
5. Avoid compatibility shims between old DOM functions and new components. Internal callers should be updated directly.
6. Preserve API compatibility where existing user data or LazyCat deployment depends on it.

## Acceptance criteria

The work is complete when:

1. The app visibly follows the approved Smartisan-style token system in light and dark modes.
2. Daily note editing feels calmer than the current source/preview textarea flow.
3. Users can create and edit notes without interacting with backup, font, or admin controls.
4. Imported Evernote notes preserve title, content, timestamps, tags, and attachments where the source file provides them.
5. Import failures are visible per note/resource and do not silently lose the rest of the import.
6. Tags imported from Evernote can be used immediately to filter the note list.
7. Existing LazyCat deployment still stores app data under `/data`.
8. The redesigned authenticated workspace is no longer owned by the old all-in-one `app.js`.
9. Core workspace interactions have no inline event handlers in the served UI.
