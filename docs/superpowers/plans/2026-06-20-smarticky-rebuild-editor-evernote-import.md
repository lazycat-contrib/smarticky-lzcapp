# Smarticky Rebuild, Editor Upgrade, and Evernote Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild Smarticky's authenticated workspace as a Svelte + TypeScript app, upgrade Markdown editing with CodeMirror 6, add a dedicated Evernote `.enex` import center, and ship the result through the existing LazyCat package.

**Architecture:** Keep Go + Echo + Ent + SQLite as the durable API/storage layer and serve compiled frontend assets from the Go binary. Replace the current all-in-one vanilla JS authenticated workspace with a typed Svelte SPA while preserving existing user data, API auth, uploads, backup, fonts, and LazyCat deployment. Add Evernote import as backend-owned parsing/conversion plus frontend-owned preview/confirm/result UI.

**Tech Stack:** Go, Echo, Ent, SQLite, Svelte, TypeScript, Vite, CodeMirror 6, CSS custom properties, LazyCat LPK packaging.

## Global Constraints

- Source application work happens in `/home/czyt/code/go/smarticky`; this packaging repo remains `/home/czyt/code/go/smarticky-lzcapp`.
- Preserve existing SQLite user data and `/data` storage behavior for LazyCat.
- Do not rewrite the Go backend for novelty; backend refactors must serve import, editor, API, data model, or deployment needs.
- Use Svelte + TypeScript + Vite for the new frontend.
- Use CodeMirror 6 for Markdown editing.
- Use the approved Smartisan-style visual tokens: primary `#E8450A`, page `#FAFAF8`, secondary surface `#F1EFE8`, text `#1A1A18`, divider `#E8E6E0`, dark background `#1C1C1A`.
- Use only font weights `400` and `500` in the redesigned workspace.
- Use `letter-spacing: 0` in implementation.
- Do not merge Evernote import into backup/restore.
- Do not build Evernote sync; support one-time `.enex` import.
- Remove old duplicate workspace paths after the new workspace owns the equivalent behavior.
- Commit after every task.

---

## Source Layout

Execution uses two repositories:

- `/home/czyt/code/go/smarticky`: upstream application source, created in Task 1.
- `/home/czyt/code/go/smarticky-lzcapp`: LazyCat packaging repo, updated only in Task 12.

Target application source layout:

- `web/app/package.json`: frontend package and scripts.
- `web/app/vite.config.ts`: Vite build config.
- `web/app/tsconfig.json`: TypeScript config.
- `web/app/src/main.ts`: frontend bootstrap.
- `web/app/src/App.svelte`: root app composition.
- `web/app/src/lib/api/client.ts`: authenticated fetch wrapper.
- `web/app/src/lib/api/types.ts`: API DTOs.
- `web/app/src/lib/stores/auth.ts`: auth state.
- `web/app/src/lib/stores/notes.ts`: note list, filters, selection, save state.
- `web/app/src/lib/stores/imports.ts`: import job state.
- `web/app/src/lib/components/workspace/`: navigation, note list, search, cards.
- `web/app/src/lib/components/editor/`: CodeMirror editor, toolbar, inspector.
- `web/app/src/lib/components/import/`: Evernote import center.
- `web/app/src/lib/components/settings/`: tools/settings surfaces.
- `web/app/src/lib/styles/tokens.css`: Smartisan token system.
- `web/app/src/lib/styles/global.css`: base app styles.
- `web/static/app/`: generated frontend output embedded by Go.
- `internal/importer/evernote/`: ENEX parser and conversion tests.
- `internal/importer/`: import service.
- `internal/handler/import.go`: import API handlers.
- `ent/schema/importjob.go`: import job entity.
- `ent/schema/importitem.go`: import item entity.

---

## Task 1: Establish Application Source Workspace and Frontend Build Shell

**Files:**
- Create repo directory: `/home/czyt/code/go/smarticky`
- Create: `/home/czyt/code/go/smarticky/web/app/package.json`
- Create: `/home/czyt/code/go/smarticky/web/app/index.html`
- Create: `/home/czyt/code/go/smarticky/web/app/vite.config.ts`
- Create: `/home/czyt/code/go/smarticky/web/app/tsconfig.json`
- Create: `/home/czyt/code/go/smarticky/web/app/src/main.ts`
- Create: `/home/czyt/code/go/smarticky/web/app/src/App.svelte`
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/styles/tokens.css`
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/styles/global.css`
- Modify: `/home/czyt/code/go/smarticky/web/assets.go`
- Modify: `/home/czyt/code/go/smarticky/cmd/server/main.go`
- Modify: `/home/czyt/code/go/smarticky/Dockerfile`

**Interfaces:**
- Consumes: upstream Git repo `https://github.com/dockers-x/smarticky.git`.
- Produces: `web/app` build output at `web/static/app`; Go serves `/` from the compiled SPA shell.

- [ ] **Step 1: Clone the upstream app source**

```bash
cd /home/czyt/code/go
git clone https://github.com/dockers-x/smarticky.git smarticky
cd /home/czyt/code/go/smarticky
git status --short
```

Expected: clean worktree.

- [ ] **Step 2: Create the Svelte frontend package**

Create `web/app/package.json`:

```json
{
  "name": "smarticky-workspace",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite --host 0.0.0.0",
    "build": "vite build",
    "check": "svelte-check --tsconfig ./tsconfig.json",
    "preview": "vite preview --host 0.0.0.0"
  },
  "dependencies": {
    "@codemirror/commands": "^6.8.0",
    "@codemirror/lang-markdown": "^6.3.4",
    "@codemirror/state": "^6.5.2",
    "@codemirror/view": "^6.38.0",
    "@lezer/highlight": "^1.2.1",
    "svelte": "^5.0.0"
  },
  "devDependencies": {
    "@sveltejs/vite-plugin-svelte": "^5.0.0",
    "svelte-check": "^4.0.0",
    "typescript": "^5.6.0",
    "vite": "^6.0.0"
  }
}
```

- [ ] **Step 3: Add Vite and TypeScript config**

Create `web/app/vite.config.ts`:

```ts
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [svelte()],
  base: "/static/app/",
  build: {
    outDir: "../static/app",
    emptyOutDir: true,
    rollupOptions: {
      output: {
        entryFileNames: "assets/index.js",
        chunkFileNames: "assets/[name].js",
        assetFileNames: (assetInfo) => {
          if (assetInfo.name?.endsWith(".css")) return "assets/index.css";
          return "assets/[name][extname]";
        },
      },
    },
  },
});
```

Create `web/app/tsconfig.json`:

```json
{
  "compilerOptions": {
    "allowJs": false,
    "checkJs": false,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "skipLibCheck": true,
    "sourceMap": true,
    "strict": true,
    "target": "ES2022",
    "types": ["svelte"]
  },
  "include": ["src/**/*.ts", "src/**/*.svelte"]
}
```

- [ ] **Step 4: Add the minimum app shell**

Create `web/app/index.html`:

```html
<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Smarticky</title>
  </head>
  <body>
    <div id="smarticky-app"></div>
    <script type="module" src="/src/main.ts"></script>
  </body>
</html>
```

Create `web/app/src/main.ts`:

```ts
import { mount } from "svelte";
import App from "./App.svelte";
import "./lib/styles/tokens.css";
import "./lib/styles/global.css";

const app = mount(App, {
  target: document.getElementById("smarticky-app") as HTMLElement,
});

export default app;
```

Create `web/app/src/App.svelte`:

```svelte
<script lang="ts">
  const title = "Smarticky";
</script>

<main class="app-shell" aria-label="Smarticky workspace">
  <section class="boot-panel">
    <p class="boot-kicker">SMARTICKY</p>
    <h1>{title}</h1>
    <p>正在准备笔记工作台</p>
  </section>
</main>
```

Create `web/app/src/lib/styles/tokens.css`:

```css
:root {
  --color-brand: #e8450a;
  --color-page: #fafaf8;
  --color-card: #ffffff;
  --color-surface-secondary: #f1efe8;
  --color-text: #1a1a18;
  --color-text-secondary: #444441;
  --color-text-muted: #888780;
  --color-placeholder: #b4b2a9;
  --color-divider: #e8e6e0;
  --color-danger: #e24b4a;
  --radius-card: 10px;
  --space-1: 8px;
  --space-2: 16px;
  --space-3: 24px;
  --space-4: 32px;
  --toolbar-height: 48px;
  color-scheme: light;
}

:root[data-theme="dark"] {
  --color-page: #1c1c1a;
  --color-card: #242420;
  --color-surface-secondary: #2a2a26;
  --color-text: #f4f2ea;
  --color-text-secondary: #d5d2c8;
  --color-text-muted: #8f8d86;
  --color-placeholder: #77756e;
  --color-divider: #333330;
  color-scheme: dark;
}
```

Create `web/app/src/lib/styles/global.css`:

```css
html,
body,
#smarticky-app {
  height: 100%;
}

body {
  margin: 0;
  background: var(--color-page);
  color: var(--color-text);
  font-family:
    -apple-system, BlinkMacSystemFont, "PingFang SC", "Source Han Sans SC",
    "Noto Sans CJK SC", "Microsoft YaHei", "Segoe UI", sans-serif;
  font-weight: 400;
  letter-spacing: 0;
  overflow: hidden;
}

button,
input,
textarea {
  font: inherit;
}

button {
  cursor: pointer;
}

.app-shell {
  min-height: 100%;
  display: grid;
  place-items: center;
}

.boot-panel {
  width: min(420px, calc(100vw - 40px));
  padding: 32px;
  border: 1px solid var(--color-divider);
  border-radius: var(--radius-card);
  background: var(--color-card);
}

.boot-kicker {
  margin: 0 0 8px;
  color: var(--color-text-muted);
  font-size: 11px;
}
```

- [ ] **Step 5: Serve the compiled SPA shell from Go**

Modify `web/assets.go` only if the embed pattern needs explicit generated files. Keep:

```go
//go:embed static templates
var Assets embed.FS
```

Modify the root route in `cmd/server/main.go` to serve a minimal SPA shell:

```go
e.GET("/", func(c echo.Context) error {
	html := []byte(`<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Smarticky</title>
  <script type="module" crossorigin src="/static/app/assets/index.js"></script>
  <link rel="stylesheet" crossorigin href="/static/app/assets/index.css">
</head>
<body>
  <div id="smarticky-app"></div>
</body>
</html>`)
	return c.HTMLBlob(http.StatusOK, html)
})
```

- [ ] **Step 6: Update Docker build to compile frontend before Go**

Modify `Dockerfile` so the build stage includes Node, installs dependencies, and runs frontend build before `go build`:

```dockerfile
RUN cd web/app && npm ci && npm run build && cd ../..
```

Place this command before the Go build command.

- [ ] **Step 7: Verify build**

Run:

```bash
cd /home/czyt/code/go/smarticky/web/app
npm install
npm run build
npm run check
cd /home/czyt/code/go/smarticky
go test ./...
go build -o /tmp/smarticky ./cmd/server
```

Expected: all commands pass.

- [ ] **Step 8: Commit**

```bash
cd /home/czyt/code/go/smarticky
git add web/app web/static/app web/assets.go cmd/server/main.go Dockerfile
git commit -m "feat: add Svelte workspace shell"
```

---

## Task 2: Typed API Client, Auth Store, and Workspace Boot Flow

**Files:**
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/api/types.ts`
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/api/client.ts`
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/stores/auth.ts`
- Modify: `/home/czyt/code/go/smarticky/web/app/src/App.svelte`

**Interfaces:**
- Consumes: existing API endpoints `/api/setup/check`, `/api/auth/me`, `/api/notes`.
- Produces:
  - `apiFetch<T>(path: string, init?: RequestInit): Promise<T>`
  - `authStore` with `hydrate(): Promise<void>`, `logout(): void`
  - typed `Note`, `Tag`, `Attachment`, `User`

- [ ] **Step 1: Add DTO types**

Create `web/app/src/lib/api/types.ts`:

```ts
export type UUID = string;

export interface User {
  id: number;
  username: string;
  email?: string;
  nickname?: string;
  role: "admin" | "user";
  avatar?: string;
}

export interface Tag {
  id: UUID;
  name: string;
  color: string;
  created_at?: string;
  updated_at?: string;
}

export interface Attachment {
  id: number;
  filename: string;
  file_size: number;
  mime_type?: string;
  created_at: string;
}

export interface Note {
  id: UUID;
  title: string;
  content: string;
  color: string;
  is_locked: boolean;
  is_starred: boolean;
  is_deleted: boolean;
  tags?: Tag[];
  created_at: string;
  updated_at: string;
}

export interface SetupCheckResponse {
  setup_needed: boolean;
}
```

- [ ] **Step 2: Add authenticated API client**

Create `web/app/src/lib/api/client.ts`:

```ts
const API_BASE = "/api";

export class ApiError extends Error {
  constructor(
    message: string,
    public readonly status: number,
    public readonly payload: unknown,
  ) {
    super(message);
  }
}

export function getToken(): string | null {
  return localStorage.getItem("jwt_token");
}

export async function apiFetch<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers);
  const token = getToken();
  if (token) headers.set("Authorization", `Bearer ${token}`);
  if (init.body && !headers.has("Content-Type") && !(init.body instanceof FormData)) {
    headers.set("Content-Type", "application/json");
  }

  const response = await fetch(`${API_BASE}${path}`, { ...init, headers });
  const text = await response.text();
  const payload = text ? JSON.parse(text) : null;

  if (!response.ok) {
    throw new ApiError(payload?.error || `Request failed: ${response.status}`, response.status, payload);
  }

  return payload as T;
}
```

- [ ] **Step 3: Add auth store**

Create `web/app/src/lib/stores/auth.ts`:

```ts
import { writable } from "svelte/store";
import { apiFetch } from "../api/client";
import type { SetupCheckResponse, User } from "../api/types";

interface AuthState {
  loading: boolean;
  setupNeeded: boolean;
  user: User | null;
  error: string;
}

function createAuthStore() {
  const { subscribe, set, update } = writable<AuthState>({
    loading: true,
    setupNeeded: false,
    user: null,
    error: "",
  });

  return {
    subscribe,
    async hydrate() {
      update((state) => ({ ...state, loading: true, error: "" }));
      const setup = await apiFetch<SetupCheckResponse>("/setup/check");
      if (setup.setup_needed) {
        set({ loading: false, setupNeeded: true, user: null, error: "" });
        window.location.href = "/setup";
        return;
      }
      const token = localStorage.getItem("jwt_token");
      if (!token) {
        set({ loading: false, setupNeeded: false, user: null, error: "" });
        window.location.href = "/login";
        return;
      }
      try {
        const user = await apiFetch<User>("/auth/me");
        set({ loading: false, setupNeeded: false, user, error: "" });
      } catch (error) {
        localStorage.removeItem("jwt_token");
        localStorage.removeItem("user");
        set({ loading: false, setupNeeded: false, user: null, error: "登录已过期" });
        window.location.href = "/login";
      }
    },
    logout() {
      localStorage.removeItem("jwt_token");
      localStorage.removeItem("user");
      set({ loading: false, setupNeeded: false, user: null, error: "" });
      window.location.href = "/login";
    },
  };
}

export const authStore = createAuthStore();
```

- [ ] **Step 4: Wire boot flow in App**

Modify `web/app/src/App.svelte`:

```svelte
<script lang="ts">
  import { onMount } from "svelte";
  import { authStore } from "./lib/stores/auth";

  onMount(() => {
    authStore.hydrate();
  });
</script>

{#if $authStore.loading}
  <main class="app-shell" aria-label="Smarticky workspace">
    <section class="boot-panel">
      <p class="boot-kicker">SMARTICKY</p>
      <h1>Smarticky</h1>
      <p>正在准备笔记工作台</p>
    </section>
  </main>
{:else if $authStore.user}
  <main class="workspace-root" aria-label="Smarticky workspace">
    <p>欢迎回来，{$authStore.user.nickname || $authStore.user.username}</p>
  </main>
{/if}
```

- [ ] **Step 5: Verify**

Run:

```bash
cd /home/czyt/code/go/smarticky/web/app
npm run build
npm run check
```

Expected: build and type check pass.

- [ ] **Step 6: Commit**

```bash
cd /home/czyt/code/go/smarticky
git add web/app/src
git commit -m "feat: add typed frontend API and auth boot"
```

---

## Task 3: Notes Store, Smartisan Workspace Shell, and Note List Vertical Slice

**Files:**
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/stores/notes.ts`
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/components/workspace/Workspace.svelte`
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/components/workspace/Sidebar.svelte`
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/components/workspace/NoteList.svelte`
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/components/workspace/NoteCard.svelte`
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/components/workspace/EmptyState.svelte`
- Modify: `/home/czyt/code/go/smarticky/web/app/src/App.svelte`
- Modify: `/home/czyt/code/go/smarticky/web/app/src/lib/styles/global.css`

**Interfaces:**
- Consumes: `apiFetch<T>()`, `Note`.
- Produces:
  - `notesStore.load(): Promise<void>`
  - `notesStore.create(): Promise<void>`
  - `notesStore.select(note: Note): void`
  - `notesStore.setFilter(filter: NoteFilter): Promise<void>`
  - `notesStore.setSearch(query: string): Promise<void>`

- [ ] **Step 1: Add notes store**

Create `web/app/src/lib/stores/notes.ts`:

```ts
import { get, writable } from "svelte/store";
import { apiFetch } from "../api/client";
import type { Note } from "../api/types";

export type NoteFilter = "all" | "starred" | "trash";

interface NotesState {
  notes: Note[];
  selected: Note | null;
  filter: NoteFilter;
  search: string;
  loading: boolean;
  error: string;
}

function queryFor(state: NotesState): string {
  const params = new URLSearchParams();
  if (state.filter === "starred") params.set("starred", "true");
  if (state.filter === "trash") params.set("trash", "true");
  if (state.search.trim()) params.set("q", state.search.trim());
  return params.toString();
}

function createNotesStore() {
  const { subscribe, set, update } = writable<NotesState>({
    notes: [],
    selected: null,
    filter: "all",
    search: "",
    loading: false,
    error: "",
  });

  async function load() {
    update((state) => ({ ...state, loading: true, error: "" }));
    const state = get({ subscribe });
    const query = queryFor(state);
    const notes = await apiFetch<Note[]>(`/notes${query ? `?${query}` : ""}`);
    update((current) => ({
      ...current,
      notes,
      selected: current.selected ? notes.find((note) => note.id === current.selected?.id) || current.selected : null,
      loading: false,
    }));
  }

  return {
    subscribe,
    load,
    async create() {
      const note = await apiFetch<Note>("/notes", {
        method: "POST",
        body: JSON.stringify({ title: "未命名", content: "", color: "" }),
      });
      await load();
      update((state) => ({ ...state, selected: note, filter: "all", search: "" }));
    },
    select(note: Note) {
      update((state) => ({ ...state, selected: note }));
    },
    async setFilter(filter: NoteFilter) {
      update((state) => ({ ...state, filter, selected: null }));
      await load();
    },
    async setSearch(search: string) {
      update((state) => ({ ...state, search }));
      await load();
    },
    replaceSelected(note: Note) {
      update((state) => ({
        ...state,
        selected: note,
        notes: state.notes.map((item) => (item.id === note.id ? note : item)),
      }));
    },
  };
}

export const notesStore = createNotesStore();
```

- [ ] **Step 2: Add workspace components**

Create `web/app/src/lib/components/workspace/Workspace.svelte`:

```svelte
<script lang="ts">
  import { onMount } from "svelte";
  import Sidebar from "./Sidebar.svelte";
  import NoteList from "./NoteList.svelte";
  import { notesStore } from "../../stores/notes";

  onMount(() => {
    notesStore.load();
  });
</script>

<div class="workspace">
  <Sidebar />
  <NoteList />
  <section class="editor-pane" aria-label="编辑器">
    {#if $notesStore.selected}
      <p class="editor-empty-text">{$notesStore.selected.title}</p>
    {:else}
      <p class="editor-empty-text">选择一篇笔记，或新建一篇</p>
    {/if}
  </section>
</div>
```

Create `web/app/src/lib/components/workspace/Sidebar.svelte`:

```svelte
<script lang="ts">
  import { notesStore, type NoteFilter } from "../../stores/notes";

  const filters: { id: NoteFilter; label: string }[] = [
    { id: "all", label: "全部笔记" },
    { id: "starred", label: "收藏" },
    { id: "trash", label: "废纸篓" },
  ];
</script>

<aside class="sidebar" aria-label="导航">
  <div class="sidebar__brand">Smarticky</div>
  <nav class="sidebar__nav">
    {#each filters as filter}
      <button
        class:active={$notesStore.filter === filter.id}
        type="button"
        on:click={() => notesStore.setFilter(filter.id)}
      >
        {filter.label}
      </button>
    {/each}
  </nav>
  <button class="sidebar__tool" type="button">导入</button>
</aside>
```

Create `web/app/src/lib/components/workspace/NoteList.svelte`:

```svelte
<script lang="ts">
  import { notesStore } from "../../stores/notes";
  import EmptyState from "./EmptyState.svelte";
  import NoteCard from "./NoteCard.svelte";
</script>

<section class="note-list-pane" aria-label="笔记列表">
  <div class="note-list-toolbar">
    <input
      type="search"
      placeholder="搜索笔记"
      value={$notesStore.search}
      on:input={(event) => notesStore.setSearch(event.currentTarget.value)}
    />
  </div>

  {#if $notesStore.notes.length === 0}
    <EmptyState />
  {:else}
    <div class="note-card-list">
      {#each $notesStore.notes as note (note.id)}
        <NoteCard {note} active={$notesStore.selected?.id === note.id} />
      {/each}
    </div>
  {/if}

  <button class="new-note-fab" type="button" aria-label="新建笔记" on:click={() => notesStore.create()}>+</button>
</section>
```

Create `web/app/src/lib/components/workspace/NoteCard.svelte`:

```svelte
<script lang="ts">
  import type { Note } from "../../api/types";
  import { notesStore } from "../../stores/notes";

  export let note: Note;
  export let active = false;

  const preview = note.content ? note.content.replace(/\s+/g, " ").slice(0, 86) : "没有正文";
</script>

<article class:active class="note-card" on:click={() => notesStore.select(note)}>
  <h2>{note.title || "未命名"}</h2>
  <p>{preview}</p>
  <div class="note-card__meta">
    <time datetime={note.updated_at}>{new Date(note.updated_at).toLocaleString()}</time>
  </div>
</article>
```

Create `web/app/src/lib/components/workspace/EmptyState.svelte`:

```svelte
<div class="empty-state">
  <div class="empty-state__mark" aria-hidden="true">✎</div>
  <h2>写下你的第一篇笔记</h2>
  <p>记录想法，沉淀思考</p>
</div>
```

- [ ] **Step 3: Render workspace after auth**

Modify `web/app/src/App.svelte`:

```svelte
<script lang="ts">
  import { onMount } from "svelte";
  import Workspace from "./lib/components/workspace/Workspace.svelte";
  import { authStore } from "./lib/stores/auth";

  onMount(() => {
    authStore.hydrate();
  });
</script>

{#if $authStore.loading}
  <main class="app-shell" aria-label="Smarticky workspace">
    <section class="boot-panel">
      <p class="boot-kicker">SMARTICKY</p>
      <h1>Smarticky</h1>
      <p>正在准备笔记工作台</p>
    </section>
  </main>
{:else if $authStore.user}
  <Workspace />
{/if}
```

- [ ] **Step 4: Add workspace CSS**

Append to `web/app/src/lib/styles/global.css`:

```css
.workspace {
  display: grid;
  grid-template-columns: 216px 360px minmax(0, 1fr);
  height: 100%;
  background: var(--color-page);
}

.sidebar,
.note-list-pane,
.editor-pane {
  min-width: 0;
  border-right: 1px solid var(--color-divider);
}

.sidebar {
  padding: 20px;
}

.sidebar__brand {
  height: var(--toolbar-height);
  display: flex;
  align-items: center;
  color: var(--color-text);
  font-size: 17px;
  font-weight: 500;
}

.sidebar__nav {
  display: grid;
  gap: 8px;
}

.sidebar button {
  height: 40px;
  border: 0;
  border-radius: 10px;
  background: transparent;
  color: var(--color-text-secondary);
  text-align: left;
  padding: 0 12px;
  font-weight: 400;
}

.sidebar button.active {
  background: var(--color-surface-secondary);
  color: var(--color-brand);
}

.note-list-pane {
  position: relative;
  padding: 20px;
  overflow: hidden;
}

.note-list-toolbar input {
  width: 100%;
  height: 40px;
  border: 0;
  border-radius: 10px;
  background: var(--color-surface-secondary);
  color: var(--color-text);
  padding: 0 14px;
}

.note-card-list {
  display: grid;
  gap: 8px;
  margin-top: 16px;
  overflow-y: auto;
  max-height: calc(100vh - 96px);
}

.note-card {
  padding: 16px;
  border: 1px solid var(--color-divider);
  border-radius: 10px;
  background: var(--color-card);
}

.note-card.active {
  border-color: color-mix(in srgb, var(--color-brand) 48%, var(--color-divider));
}

.note-card h2 {
  margin: 0 0 8px;
  font-size: 19px;
  line-height: 1.35;
  font-weight: 500;
}

.note-card p {
  margin: 0;
  color: var(--color-text-secondary);
  font-size: 13px;
  line-height: 1.6;
}

.note-card__meta {
  margin-top: 12px;
  color: var(--color-text-muted);
  font-size: 11px;
}

.new-note-fab {
  position: absolute;
  right: 20px;
  bottom: 16px;
  width: 48px;
  height: 48px;
  border: 0;
  border-radius: 50%;
  background: var(--color-brand);
  color: #fff;
  font-size: 24px;
  box-shadow: 0 2px 8px rgb(232 69 10 / 28%);
}

.empty-state {
  height: calc(100% - 80px);
  display: grid;
  place-content: center;
  text-align: center;
}

.empty-state__mark {
  color: var(--color-brand);
  font-size: 64px;
}

.empty-state h2 {
  margin: 12px 0 4px;
  font-size: 17px;
  font-weight: 500;
}

.empty-state p,
.editor-empty-text {
  color: var(--color-text-muted);
}
```

- [ ] **Step 5: Verify**

Run:

```bash
cd /home/czyt/code/go/smarticky/web/app
npm run build
npm run check
```

Expected: build and type check pass.

- [ ] **Step 6: Commit**

```bash
cd /home/czyt/code/go/smarticky
git add web/app/src
git commit -m "feat: add redesigned notes workspace shell"
```

---

## Task 4: Backend Tag Filtering and Note List API Contract

**Files:**
- Modify: `/home/czyt/code/go/smarticky/internal/handler/note.go`
- Modify: `/home/czyt/code/go/smarticky/internal/handler/tag.go`
- Test: `/home/czyt/code/go/smarticky/internal/handler/note_test.go`

**Interfaces:**
- Consumes: existing `GET /api/notes?tags=name1,name2` query parameter.
- Produces: tag filtering that returns notes containing all requested tag names for the current user.

- [ ] **Step 1: Write failing handler test for tag filtering**

Create `internal/handler/note_test.go` with a focused test using an Ent test client and authenticated Echo context. The test must create a user, two notes, two tags, attach one tag, call `ListNotes` with `tags=work`, and assert only the tagged note returns.

Core assertion:

```go
if len(got) != 1 {
	t.Fatalf("expected 1 note, got %d", len(got))
}
if got[0].Title != "Tagged note" {
	t.Fatalf("expected Tagged note, got %q", got[0].Title)
}
```

- [ ] **Step 2: Run test to verify failure**

Run:

```bash
cd /home/czyt/code/go/smarticky
go test ./internal/handler -run TestListNotesFiltersByTag -count=1
```

Expected: FAIL because the current code does not apply tag filters.

- [ ] **Step 3: Implement tag filtering**

Modify the tag filtering block in `internal/handler/note.go`:

```go
if tagsParam := c.QueryParam("tags"); tagsParam != "" {
	tagNames := strings.Split(tagsParam, ",")
	for _, tagName := range tagNames {
		tagName = strings.TrimSpace(tagName)
		if tagName == "" {
			continue
		}
		query.Where(note.HasTagsWith(tag.NameEQ(tagName), tag.HasUserWith(user.IDEQ(userID))))
	}
}
```

Add the missing import:

```go
"smarticky/ent/tag"
```

- [ ] **Step 4: Tighten tag ownership checks**

In `internal/handler/tag.go`, replace direct `h.client.Tag.Get(ctx, tagID)` in `UpdateTag`, `AddTagToNote`, and `RemoveTagFromNote` with user-scoped queries:

```go
t, err := h.client.Tag.Query().
	Where(
		tag.ID(tagID),
		tag.HasUserWith(user.IDEQ(userID)),
	).
	Only(ctx)
```

In `UpdateTag`, read `userID := c.Get("user_id").(int)` before querying.

- [ ] **Step 5: Run tests**

Run:

```bash
cd /home/czyt/code/go/smarticky
go test ./internal/handler -count=1
go test ./...
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
cd /home/czyt/code/go/smarticky
git add internal/handler/note.go internal/handler/tag.go internal/handler/note_test.go
git commit -m "fix: filter notes by user tags"
```

---

## Task 5: CodeMirror Editor, Markdown Commands, and Autosave

**Files:**
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/components/editor/EditorPane.svelte`
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/components/editor/MarkdownEditor.svelte`
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/components/editor/EditorToolbar.svelte`
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/editor/commands.ts`
- Modify: `/home/czyt/code/go/smarticky/web/app/src/lib/stores/notes.ts`
- Modify: `/home/czyt/code/go/smarticky/web/app/src/lib/components/workspace/Workspace.svelte`
- Modify: `/home/czyt/code/go/smarticky/web/app/src/lib/styles/global.css`

**Interfaces:**
- Consumes: selected note from `notesStore`.
- Produces:
  - `updateSelected(fields: Partial<Pick<Note, "title" | "content" | "color" | "is_starred" | "is_deleted">>): Promise<void>`
  - Markdown commands: `wrapSelection`, `prefixLine`, `insertTask`, `insertImage`

- [ ] **Step 1: Add note update action**

Modify `notesStore` to add:

```ts
async updateSelected(fields: Partial<Pick<Note, "title" | "content" | "color" | "is_starred" | "is_deleted">>) {
  const state = get({ subscribe });
  if (!state.selected) return;
  update((current) => ({ ...current, error: "" }));
  const updated = await apiFetch<Note>(`/notes/${state.selected.id}`, {
    method: "PUT",
    body: JSON.stringify(fields),
  });
  update((current) => ({
    ...current,
    selected: updated,
    notes: current.notes.map((note) => (note.id === updated.id ? { ...note, ...updated } : note)),
  }));
}
```

- [ ] **Step 2: Add markdown command helpers**

Create `web/app/src/lib/editor/commands.ts`:

```ts
import type { EditorView } from "@codemirror/view";

export function wrapSelection(view: EditorView, before: string, after = before): void {
  const { state } = view;
  const changes = state.changeByRange((range) => ({
    changes: [
      { from: range.from, insert: before },
      { from: range.to, insert: after },
    ],
    range: range.empty
      ? range.map({ from: range.from + before.length, to: range.to + before.length })
      : range.map({ from: range.from, to: range.to + before.length + after.length }),
  }));
  view.dispatch(changes);
  view.focus();
}

export function prefixLine(view: EditorView, prefix: string): void {
  const line = view.state.doc.lineAt(view.state.selection.main.from);
  view.dispatch({
    changes: { from: line.from, insert: prefix },
    selection: { anchor: view.state.selection.main.from + prefix.length },
  });
  view.focus();
}

export function insertTask(view: EditorView): void {
  prefixLine(view, "- [ ] ");
}

export function insertImage(view: EditorView): void {
  const pos = view.state.selection.main.from;
  view.dispatch({
    changes: { from: pos, insert: "![图片说明]()" },
    selection: { anchor: pos + 9 },
  });
  view.focus();
}
```

- [ ] **Step 3: Build MarkdownEditor**

Create `web/app/src/lib/components/editor/MarkdownEditor.svelte` with a CodeMirror view that accepts `value` and emits `change`:

```svelte
<script lang="ts">
  import { onDestroy, onMount } from "svelte";
  import { markdown } from "@codemirror/lang-markdown";
  import { EditorState } from "@codemirror/state";
  import { EditorView, keymap } from "@codemirror/view";
  import { defaultKeymap, history, historyKeymap } from "@codemirror/commands";

  export let value = "";
  export let onChange: (value: string) => void;
  export let bindView: (view: EditorView) => void;

  let host: HTMLDivElement;
  let view: EditorView;

  onMount(() => {
    view = new EditorView({
      parent: host,
      state: EditorState.create({
        doc: value,
        extensions: [
          history(),
          markdown(),
          keymap.of([...defaultKeymap, ...historyKeymap]),
          EditorView.updateListener.of((update) => {
            if (update.docChanged) onChange(update.state.doc.toString());
          }),
          EditorView.lineWrapping,
        ],
      }),
    });
    bindView(view);
  });

  $: if (view && value !== view.state.doc.toString()) {
    view.dispatch({
      changes: { from: 0, to: view.state.doc.length, insert: value },
    });
  }

  onDestroy(() => {
    view?.destroy();
  });
</script>

<div class="markdown-editor-host" bind:this={host}></div>
```

- [ ] **Step 4: Add toolbar and editor pane**

Create `EditorToolbar.svelte` with buttons for bold, italic, unordered list, ordered list, task, and image. Each button calls the command helpers against the current `EditorView`.

Create `EditorPane.svelte` that:

- Shows title input.
- Shows save status text: `正在保存`, `已保存`, `保存失败`.
- Debounces `notesStore.updateSelected({ content })` by 500ms.
- Debounces title updates by 500ms.
- Renders `MarkdownEditor`.

The title input event must update local draft immediately and persist through the debounce:

```svelte
<input
  class="editor-title-input"
  value={draftTitle}
  placeholder="未命名"
  on:input={(event) => scheduleTitleSave(event.currentTarget.value)}
/>
```

- [ ] **Step 5: Replace temporary workspace editor text**

Modify `Workspace.svelte`:

```svelte
<script lang="ts">
  import { onMount } from "svelte";
  import EditorPane from "../editor/EditorPane.svelte";
  import Sidebar from "./Sidebar.svelte";
  import NoteList from "./NoteList.svelte";
  import { notesStore } from "../../stores/notes";

  onMount(() => {
    notesStore.load();
  });
</script>

<div class="workspace">
  <Sidebar />
  <NoteList />
  <EditorPane note={$notesStore.selected} />
</div>
```

- [ ] **Step 6: Add editor CSS**

Append editor styles using the Smartisan typography:

```css
.editor-pane {
  display: grid;
  grid-template-rows: 48px minmax(0, 1fr);
  background: var(--color-page);
}

.editor-header {
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 20px;
  border-bottom: 1px solid var(--color-divider);
}

.editor-surface {
  overflow: auto;
  padding: 32px max(40px, 8vw);
}

.editor-title-input {
  width: 100%;
  border: 0;
  outline: 0;
  background: transparent;
  color: var(--color-text);
  font-size: 19px;
  line-height: 1.35;
  font-weight: 500;
  margin-bottom: 16px;
}

.markdown-editor-host .cm-editor {
  min-height: calc(100vh - 160px);
  background: transparent;
  color: var(--color-text);
  font-size: 15px;
  line-height: 1.85;
}

.markdown-editor-host .cm-focused {
  outline: 0;
}

.editor-toolbar {
  display: flex;
  gap: 8px;
}

.editor-toolbar button {
  width: 32px;
  height: 32px;
  border: 0;
  border-radius: 8px;
  background: transparent;
  color: var(--color-text-muted);
}

.editor-toolbar button:active,
.editor-toolbar button:hover {
  background: var(--color-surface-secondary);
}
```

- [ ] **Step 7: Verify commands**

Run:

```bash
cd /home/czyt/code/go/smarticky/web/app
npm run build
npm run check
```

Manual verification:

- Select text and click Bold, expected text is wrapped in `**`.
- Place caret on empty line and click Task, expected line starts with `- [ ] `.
- Type in body, wait 500ms, reload page, expected content persists.

- [ ] **Step 8: Commit**

```bash
cd /home/czyt/code/go/smarticky
git add web/app/src
git commit -m "feat: add CodeMirror note editor"
```

---

## Task 6: Editor Tags, Attachments, Actions, and Focus Mode

**Files:**
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/components/editor/EditorInspector.svelte`
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/stores/tags.ts`
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/stores/attachments.ts`
- Modify: `/home/czyt/code/go/smarticky/web/app/src/lib/components/editor/EditorPane.svelte`
- Modify: `/home/czyt/code/go/smarticky/web/app/src/lib/components/editor/EditorToolbar.svelte`
- Modify: `/home/czyt/code/go/smarticky/web/app/src/lib/styles/global.css`

**Interfaces:**
- Produces:
  - `tagsStore.addToNote(noteId: UUID, tagName: string): Promise<void>`
  - `attachmentsStore.upload(noteId: UUID, file: File): Promise<void>`
  - editor focus mode toggled by local component state.

- [ ] **Step 1: Add tags store**

Create `tags.ts` with methods:

```ts
import { writable } from "svelte/store";
import { apiFetch } from "../api/client";
import type { Tag, UUID } from "../api/types";

export const allTags = writable<Tag[]>([]);

export async function loadTags(): Promise<void> {
  allTags.set(await apiFetch<Tag[]>("/tags"));
}

export async function addToNote(noteId: UUID, tagName: string): Promise<void> {
  const trimmed = tagName.trim();
  if (!trimmed) return;
  const existing = (await apiFetch<Tag[]>("/tags")).find(
    (tag) => tag.name.toLowerCase() === trimmed.toLowerCase(),
  );
  const tag =
    existing ||
    (await apiFetch<Tag>("/tags", {
      method: "POST",
      body: JSON.stringify({ name: trimmed, color: "#E8450A" }),
    }));
  await apiFetch(`/notes/${noteId}/tags/${tag.id}`, { method: "POST" });
  await loadTags();
}
```

- [ ] **Step 2: Add attachments store**

Create `attachments.ts`:

```ts
import { writable } from "svelte/store";
import { apiFetch } from "../api/client";
import type { Attachment, UUID } from "../api/types";

export const attachments = writable<Attachment[]>([]);

export async function loadAttachments(noteId: UUID): Promise<void> {
  attachments.set(await apiFetch<Attachment[]>(`/notes/${noteId}/attachments`));
}

export async function uploadAttachment(noteId: UUID, file: File): Promise<void> {
  const form = new FormData();
  form.set("file", file);
  await apiFetch(`/notes/${noteId}/attachments`, { method: "POST", body: form });
  await loadAttachments(noteId);
}
```

- [ ] **Step 3: Build inspector**

Create `EditorInspector.svelte` that renders tags as capsule chips, an add-tag input, attachments list, and upload button. The upload input must be hidden and triggered by a visible button:

```svelte
<input bind:this={fileInput} type="file" class="visually-hidden" on:change={handleUpload} />
<button type="button" on:click={() => fileInput.click()}>添加附件</button>
```

- [ ] **Step 4: Wire inspector and focus mode**

In `EditorPane.svelte`, add `let focusMode = false;` and a button that toggles it. Add class:

```svelte
<section class:focus-mode class="editor-pane" aria-label="编辑器">
```

Render `EditorInspector` only when a note is selected and focus mode is off.

- [ ] **Step 5: Verify**

Run:

```bash
cd /home/czyt/code/go/smarticky/web/app
npm run build
npm run check
```

Manual verification:

- Add tag to selected note, reload, expected tag remains on the note.
- Upload a small text file, reload, expected attachment appears.
- Toggle focus mode, expected sidebar/list are hidden by CSS and editor remains usable.

- [ ] **Step 6: Commit**

```bash
cd /home/czyt/code/go/smarticky
git add web/app/src
git commit -m "feat: add editor inspector and focus mode"
```

---

## Task 7: App Dialogs, Settings Tools, and Removal of Workspace Alerts

**Files:**
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/stores/dialogs.ts`
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/components/common/DialogHost.svelte`
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/components/settings/ToolsPanel.svelte`
- Modify: `/home/czyt/code/go/smarticky/web/app/src/App.svelte`
- Modify: `/home/czyt/code/go/smarticky/web/app/src/lib/components/workspace/Sidebar.svelte`
- Modify: `/home/czyt/code/go/smarticky/web/app/src/lib/components/editor/EditorPane.svelte`

**Interfaces:**
- Produces:
  - `confirmDialog(options): Promise<boolean>`
  - `notify(message: string, tone: "info" | "success" | "error"): void`
  - tools panel entry for Import, Backup, Fonts, Profile, Users.

- [ ] **Step 1: Add dialogs store**

Create `dialogs.ts`:

```ts
import { writable } from "svelte/store";

export type DialogTone = "info" | "success" | "error";

interface ConfirmRequest {
  title: string;
  message: string;
  confirmLabel: string;
  cancelLabel: string;
  resolve: (value: boolean) => void;
}

export const confirmRequest = writable<ConfirmRequest | null>(null);
export const notifications = writable<{ id: number; message: string; tone: DialogTone }[]>([]);

export function confirmDialog(options: Omit<ConfirmRequest, "resolve">): Promise<boolean> {
  return new Promise((resolve) => {
    confirmRequest.set({ ...options, resolve });
  });
}

export function notify(message: string, tone: DialogTone = "info"): void {
  const id = Date.now();
  notifications.update((items) => [...items, { id, message, tone }]);
  window.setTimeout(() => {
    notifications.update((items) => items.filter((item) => item.id !== id));
  }, 3200);
}
```

- [ ] **Step 2: Add DialogHost**

Create `DialogHost.svelte` rendering confirm dialog and notification stack. Buttons call `resolve(true/false)` and clear `confirmRequest`.

- [ ] **Step 3: Add ToolsPanel**

Create `ToolsPanel.svelte` with a grouped Smartisan list:

- Import
- Backup
- Font management
- Profile
- User management when current user role is admin
- Logout

Each row is 52px high with a right chevron.

- [ ] **Step 4: Wire into app**

Render `DialogHost` in `App.svelte` after `Workspace`.

In `Sidebar.svelte`, replace the bare Import button with a Tools button that opens `ToolsPanel`.

In migrated delete/restore actions, replace `window.confirm` behavior with `confirmDialog`.

- [ ] **Step 5: Verify**

Run:

```bash
cd /home/czyt/code/go/smarticky/web/app
npm run build
npm run check
```

Manual verification:

- Trigger delete confirmation, expected app dialog appears.
- Confirm delete, expected note moves to trash.
- Cancel delete, expected note remains.
- Trigger notification, expected inline toast appears and disappears.

- [ ] **Step 6: Commit**

```bash
cd /home/czyt/code/go/smarticky
git add web/app/src
git commit -m "feat: add app dialogs and tools panel"
```

---

## Task 8: Evernote ENEX Parser and Import Data Model

**Files:**
- Create: `/home/czyt/code/go/smarticky/internal/importer/evernote/parser.go`
- Create: `/home/czyt/code/go/smarticky/internal/importer/evernote/parser_test.go`
- Create: `/home/czyt/code/go/smarticky/ent/schema/importjob.go`
- Create: `/home/czyt/code/go/smarticky/ent/schema/importitem.go`
- Modify: `/home/czyt/code/go/smarticky/ent/generate.go`

**Interfaces:**
- Produces:
  - `evernote.Parse(r io.Reader) (*evernote.Document, error)`
  - `Document{Notes []Note}`
  - `Note{Title, Content, Created, Updated, Tags, Resources}`
  - Ent entities `ImportJob`, `ImportItem`

- [ ] **Step 1: Write parser tests**

Create `parser_test.go` with tests:

```go
func TestParseENEXNoteWithTagsAndResource(t *testing.T) {
	input := strings.NewReader(`<?xml version="1.0" encoding="UTF-8"?>
<en-export>
  <note>
    <title>Meeting</title>
    <content><![CDATA[<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd"><en-note>Hello<img src="evernote:///view/1/s1/guid/res-guid/"/></en-note>]]></content>
    <created>20250101T010203Z</created>
    <updated>20250102T030405Z</updated>
    <tag>work</tag>
    <resource>
      <data encoding="base64">aGVsbG8=</data>
      <mime>text/plain</mime>
      <resource-attributes><file-name>hello.txt</file-name></resource-attributes>
    </resource>
  </note>
</en-export>`)
	doc, err := Parse(input)
	if err != nil {
		t.Fatal(err)
	}
	if len(doc.Notes) != 1 {
		t.Fatalf("expected 1 note, got %d", len(doc.Notes))
	}
	if doc.Notes[0].Title != "Meeting" {
		t.Fatalf("expected title Meeting, got %q", doc.Notes[0].Title)
	}
	if doc.Notes[0].Tags[0] != "work" {
		t.Fatalf("expected tag work, got %q", doc.Notes[0].Tags[0])
	}
	if string(doc.Notes[0].Resources[0].Data) != "hello" {
		t.Fatalf("expected decoded resource")
	}
}
```

- [ ] **Step 2: Run parser test to verify failure**

```bash
cd /home/czyt/code/go/smarticky
go test ./internal/importer/evernote -run TestParseENEXNoteWithTagsAndResource -count=1
```

Expected: FAIL because package does not exist.

- [ ] **Step 3: Implement parser**

Create `parser.go` with XML structs, base64 decoding, and Evernote timestamp parsing using layout `20060102T150405Z`.

Function signature:

```go
func Parse(r io.Reader) (*Document, error)
```

On malformed XML, return `fmt.Errorf("parse enex: %w", err)`. On invalid resource base64, keep the note and append a resource with `DecodeError` set.

- [ ] **Step 4: Add Ent schemas**

Create `ent/schema/importjob.go`:

```go
package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/field"
)

type ImportJob struct {
	ent.Schema
}

func (ImportJob) Fields() []ent.Field {
	return []ent.Field{
		field.String("source").Default("evernote"),
		field.String("filename").NotEmpty(),
		field.String("status").Default("previewed"),
		field.Int("note_count").Default(0),
		field.Int("imported_count").Default(0),
		field.Int("skipped_count").Default(0),
		field.Int("failed_count").Default(0),
		field.Text("options_json").Optional(),
		field.Time("created_at").Default(time.Now).Immutable(),
		field.Time("completed_at").Optional(),
	}
}

func (ImportJob) Edges() []ent.Edge {
	return []ent.Edge{
		edge.From("user", User.Type).Ref("import_jobs").Unique(),
		edge.To("items", ImportItem.Type),
	}
}
```

Create `ent/schema/importitem.go`:

```go
package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/field"
	"github.com/google/uuid"
)

type ImportItem struct {
	ent.Schema
}

func (ImportItem) Fields() []ent.Field {
	return []ent.Field{
		field.String("source_note_key").NotEmpty(),
		field.UUID("note_id", uuid.UUID{}).Optional(),
		field.String("title").Default("Untitled"),
		field.String("status").Default("pending"),
		field.Text("message").Optional(),
	}
}

func (ImportItem) Edges() []ent.Edge {
	return []ent.Edge{
		edge.From("job", ImportJob.Type).Ref("items").Unique().Required(),
	}
}
```

Add `edge.To("import_jobs", ImportJob.Type)` to `User` schema.

- [ ] **Step 5: Generate Ent code and run tests**

```bash
cd /home/czyt/code/go/smarticky
go generate ./ent
go test ./internal/importer/evernote -count=1
go test ./...
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
cd /home/czyt/code/go/smarticky
git add internal/importer ent
git commit -m "feat: parse Evernote ENEX imports"
```

---

## Task 9: Import Service and API Routes

**Files:**
- Create: `/home/czyt/code/go/smarticky/internal/importer/service.go`
- Create: `/home/czyt/code/go/smarticky/internal/importer/service_test.go`
- Create: `/home/czyt/code/go/smarticky/internal/handler/import.go`
- Modify: `/home/czyt/code/go/smarticky/internal/handler/handler.go`
- Modify: `/home/czyt/code/go/smarticky/cmd/server/main.go`

**Interfaces:**
- Produces:
  - `Service.PreviewEvernote(ctx, userID, filename string, r io.Reader) (*PreviewResult, error)`
  - `Service.ConfirmEvernote(ctx, userID int, jobID int) (*ImportResult, error)`
  - Routes:
    - `POST /api/import/evernote/preview`
    - `POST /api/import/evernote/confirm`
    - `GET /api/import/jobs`
    - `GET /api/import/jobs/:id`

- [ ] **Step 1: Write service test for preview**

Create `service_test.go` that feeds one-note ENEX and asserts:

- job status is `previewed`
- `note_count` is `1`
- one `ImportItem` is created with status `pending`

- [ ] **Step 2: Implement preview service**

In `service.go`, create:

```go
type Service struct {
	client *ent.Client
	fs     *storage.FileSystem
}

func NewService(client *ent.Client, fs *storage.FileSystem) *Service {
	return &Service{client: client, fs: fs}
}
```

`PreviewEvernote` parses the ENEX, creates `ImportJob`, creates `ImportItem` rows, and returns counts.

- [ ] **Step 3: Implement confirm service**

`ConfirmEvernote` loads pending import items for the job, converts ENEX content into note content, creates notes for the job user, creates/reuses tags, saves resources through `FileSystem`, creates attachment records, updates item status, and updates job counts.

Duplicate detection key:

```go
func duplicateKey(title string, created time.Time, content string) string {
	sum := sha256.Sum256([]byte(strings.TrimSpace(content)))
	return strings.ToLower(strings.TrimSpace(title)) + "|" + created.UTC().Format(time.RFC3339) + "|" + hex.EncodeToString(sum[:])
}
```

- [ ] **Step 4: Add handlers**

Create `internal/handler/import.go` with methods:

```go
func (h *Handler) PreviewEvernoteImport(c echo.Context) error
func (h *Handler) ConfirmEvernoteImport(c echo.Context) error
func (h *Handler) ListImportJobs(c echo.Context) error
func (h *Handler) GetImportJob(c echo.Context) error
```

Add importer service field to `Handler` or instantiate service from existing `client` and `fs`.

- [ ] **Step 5: Add routes**

In `cmd/server/main.go` protected group:

```go
protected.POST("/import/evernote/preview", h.PreviewEvernoteImport)
protected.POST("/import/evernote/confirm", h.ConfirmEvernoteImport)
protected.GET("/import/jobs", h.ListImportJobs)
protected.GET("/import/jobs/:id", h.GetImportJob)
```

- [ ] **Step 6: Run tests**

```bash
cd /home/czyt/code/go/smarticky
go test ./internal/importer -count=1
go test ./internal/handler -count=1
go test ./...
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
cd /home/czyt/code/go/smarticky
git add internal/importer internal/handler cmd/server/main.go
git commit -m "feat: add Evernote import API"
```

---

## Task 10: Evernote Import Center Frontend

**Files:**
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/api/imports.ts`
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/stores/imports.ts`
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/components/import/ImportCenter.svelte`
- Create: `/home/czyt/code/go/smarticky/web/app/src/lib/components/import/ImportSummary.svelte`
- Modify: `/home/czyt/code/go/smarticky/web/app/src/lib/components/settings/ToolsPanel.svelte`

**Interfaces:**
- Consumes import API from Task 9.
- Produces Import Center with upload, preview, confirm, result state.

- [ ] **Step 1: Add import API types and calls**

Create `web/app/src/lib/api/imports.ts`:

```ts
import { apiFetch } from "./client";

export interface ImportPreview {
  job_id: number;
  filename: string;
  note_count: number;
  tag_count: number;
  resource_count: number;
  warning_count: number;
}

export interface ImportResult {
  job_id: number;
  status: "completed" | "completed_with_errors" | "failed";
  imported_count: number;
  skipped_count: number;
  failed_count: number;
}

export async function previewEvernote(file: File): Promise<ImportPreview> {
  const form = new FormData();
  form.set("file", file);
  return apiFetch<ImportPreview>("/import/evernote/preview", { method: "POST", body: form });
}

export async function confirmEvernote(jobId: number): Promise<ImportResult> {
  return apiFetch<ImportResult>("/import/evernote/confirm", {
    method: "POST",
    body: JSON.stringify({ job_id: jobId }),
  });
}
```

- [ ] **Step 2: Add imports store**

Create `imports.ts` with `preview(file)`, `confirm()`, `reset()` and state fields `loading`, `preview`, `result`, `error`.

- [ ] **Step 3: Build ImportCenter**

Create `ImportCenter.svelte`:

- Accept `.enex` only.
- Show preview counts.
- Confirm button says `开始导入`.
- Result state shows imported/skipped/failed counts.
- Error state shows exact error text from API.

- [ ] **Step 4: Wire ToolsPanel**

Clicking Import in `ToolsPanel` opens `ImportCenter`.

After successful import, call `notesStore.load()` so imported notes appear immediately.

- [ ] **Step 5: Verify**

Run:

```bash
cd /home/czyt/code/go/smarticky/web/app
npm run build
npm run check
```

Manual verification:

- Upload non-ENEX file, expected inline error.
- Upload valid ENEX, expected preview counts.
- Confirm import, expected notes appear in list.
- Tags from ENEX are visible and usable in filtering.

- [ ] **Step 6: Commit**

```bash
cd /home/czyt/code/go/smarticky
git add web/app/src
git commit -m "feat: add Evernote import center"
```

---

## Task 11: Visual Polish, Mobile Flow, and Legacy Workspace Removal

**Files:**
- Modify: `/home/czyt/code/go/smarticky/web/app/src/lib/styles/global.css`
- Modify: `/home/czyt/code/go/smarticky/web/templates/index.html`
- Modify: `/home/czyt/code/go/smarticky/web/static/js/app.js`
- Modify: `/home/czyt/code/go/smarticky/web/static/css/custom.css`

**Interfaces:**
- Produces: new SPA owns authenticated workspace; old workspace template is not served at `/`.

- [ ] **Step 1: Add responsive layout CSS**

Add media query:

```css
@media (max-width: 768px) {
  .workspace {
    grid-template-columns: 1fr;
  }

  .sidebar {
    display: none;
  }

  .note-list-pane.editor-open {
    display: none;
  }

  .editor-pane {
    min-height: 100vh;
  }
}
```

- [ ] **Step 2: Add reduced motion support**

```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    scroll-behavior: auto !important;
    transition-duration: 0.01ms !important;
  }
}
```

- [ ] **Step 3: Remove old authenticated workspace from served path**

Keep legacy `web/templates/index.html` only as reference during this task. The root route must serve the new SPA shell. Remove unused old static references from the root route.

If no route serves `web/templates/index.html`, leave the file for one commit with a comment in commit message. In the next cleanup commit delete it together with old workspace-only JS/CSS once equivalent flows are verified.

- [ ] **Step 4: Visual verification**

Run the server:

```bash
cd /home/czyt/code/go/smarticky
go run ./cmd/server
```

Open:

- `http://localhost:8080`
- desktop width 1440px
- mobile width 390px

Check:

- No text overflow in note card titles.
- FAB remains 48px and does not cover card content.
- Editor title and body do not show browser default borders.
- Dark mode uses warm black, not pure black.
- Import result rows fit on mobile.

- [ ] **Step 5: Run full verification**

```bash
cd /home/czyt/code/go/smarticky/web/app
npm run build
npm run check
cd /home/czyt/code/go/smarticky
go test ./...
go build -o /tmp/smarticky ./cmd/server
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
cd /home/czyt/code/go/smarticky
git add web cmd internal ent
git commit -m "refactor: retire legacy workspace shell"
```

---

## Task 12: LazyCat Packaging Update

**Files:**
- Modify: `/home/czyt/code/go/smarticky-lzcapp/lzc-manifest.yml`
- Modify: `/home/czyt/code/go/smarticky-lzcapp/README.md`
- Generated: `/home/czyt/code/go/smarticky-lzcapp/community.lazycat.czyt.smarticky-v*.lpk`

**Interfaces:**
- Consumes: built Smarticky application image.
- Produces: LazyCat manifest points to the new image digest and version.

- [ ] **Step 1: Build and publish Smarticky image**

From the app repo:

```bash
cd /home/czyt/code/go/smarticky
docker build -t czyt/smarticky:v0.2.0 .
docker tag czyt/smarticky:v0.2.0 registry.lazycat.cloud/czyt/czyt/smarticky:v0.2.0
docker push registry.lazycat.cloud/czyt/czyt/smarticky:v0.2.0
```

Capture the immutable image reference:

```bash
export IMAGE_REF="$(docker inspect --format='{{index .RepoDigests 0}}' registry.lazycat.cloud/czyt/czyt/smarticky:v0.2.0)"
printf '%s\n' "$IMAGE_REF"
```

- [ ] **Step 2: Update LazyCat manifest**

In `lzc-manifest.yml`, set `version: 0.2.0`, set the root and locale descriptions to `一个基于 Go 的现代笔记工作台，支持 Markdown 编辑与 Evernote 导入。`, and set `services.smarticky.image` to the exact `$IMAGE_REF` captured in Step 1.

Use this command after exporting `IMAGE_REF`:

```bash
sed -i 's/version: 0.1.6/version: 0.2.0/' lzc-manifest.yml
sed -i 's/一个基于 Go 的现代便签应用，界面参考锤子便签设计。/一个基于 Go 的现代笔记工作台，支持 Markdown 编辑与 Evernote 导入。/g' lzc-manifest.yml
perl -0pi -e "s|image: registry\\.lazycat\\.cloud/czyt/czyt/smarticky:[^\\n]+|image: $ENV{IMAGE_REF}|" lzc-manifest.yml
```

- [ ] **Step 3: Build LPK**

Run from packaging repo:

```bash
cd /home/czyt/code/go/smarticky-lzcapp
lzc-cli project build
```

Expected: new `.lpk` file is generated with version `0.2.0`.

- [ ] **Step 4: Smoke test LazyCat package**

Install the generated LPK in a LazyCat test environment and verify:

- app starts
- `/data` contains `smarticky.db`
- login/setup works
- create/edit note works
- import center opens

- [ ] **Step 5: Commit packaging changes**

```bash
cd /home/czyt/code/go/smarticky-lzcapp
git add lzc-manifest.yml README.md community.lazycat.czyt.smarticky-v0.2.0.lpk
git commit -m "chore: package Smarticky 0.2.0"
```

---

## Plan Self-Review

Spec coverage:

- Smartisan visual language: Tasks 1, 3, 5, 11.
- Frontend rebuild with Svelte + TypeScript + Vite: Tasks 1 through 7.
- CodeMirror editor: Tasks 5 and 6.
- Evernote import center: Tasks 8 through 10.
- Backend import service and data model: Tasks 8 and 9.
- Tag filtering after import: Task 4.
- LazyCat packaging: Task 12.
- Existing data and `/data` behavior: Global Constraints and Task 12.

Placeholder scan:

- No task uses `TBD`, `TODO`, `implement later`, or unspecified validation language.
- Each task has exact paths, commands, and expected verification.

Type consistency:

- API DTO names in Task 2 are reused by Tasks 3, 5, 6, and 10.
- Import API route names in Task 9 match frontend calls in Task 10.
- `notesStore` methods introduced in Tasks 3 and 5 are consumed by later tasks.
