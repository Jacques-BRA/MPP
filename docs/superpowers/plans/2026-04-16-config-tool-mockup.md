# Config Tool HTML/CSS Mockup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a single-file interactive HTML/CSS mockup of the MPP MES Configuration Tool for customer storyboarding and design validation before Ignition Perspective development.

**Architecture:** One self-contained `index.html` with embedded CSS (custom properties for light/dark themes) and vanilla JS (screen routing, rail/nav toggle, tab switching). No dependencies, no build step, no server. 10 screens across 5 categories using 3 reusable layout patterns. Realistic hardcoded MPP sample data.

**Tech Stack:** HTML5, CSS3 (custom properties, flexbox, grid), vanilla JavaScript (no frameworks)

**Design Spec:** `docs/superpowers/specs/2026-04-16-config-tool-mockup-design.md`

---

## File Structure

Single file, logically organized into sections:

```
mockup/index.html
├── <style> — CSS custom properties (light + dark themes), reset, layout, components
├── <body>
│   ├── Header bar (logo, theme toggle, user avatar)
│   ├── App body container
│   │   ├── Rail (5 category icons with labels)
│   │   ├── Nav panel (screen entries per category, toggled)
│   │   └── Content area
│   │       ├── Landing prompt (default)
│   │       ├── screen-plant-hierarchy
│   │       ├── screen-item-master
│   │       ├── screen-operation-templates
│   │       ├── screen-quality-specs
│   │       ├── screen-defect-codes
│   │       ├── screen-downtime-codes
│   │       ├── screen-shift-schedules
│   │       ├── screen-users
│   │       ├── screen-audit-log
│   │       └── screen-failure-log
│   └── Modal overlays (Add Location, Location Type Def Editor, generic edit modals)
└── <script> — routing, rail toggle, tab switching, theme toggle, modal open/close, arrow reorder
```

---

## Task 1: CSS Foundation + Theme System

**Files:**
- Create: `mockup/index.html`

This task creates the file with the full CSS foundation — every subsequent task adds HTML and JS to this file.

- [ ] **Step 1: Create the file with DOCTYPE, head, and CSS custom properties**

Create `mockup/index.html` with the complete CSS theme system. This includes `:root` variables for light mode, `.theme-dark` overrides, CSS reset, typography, and all reusable component classes.

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MPP MES — Configuration Tool</title>
<style>
/* ============================================
   THEME SYSTEM — CSS Custom Properties
   ============================================ */
:root {
  /* Backgrounds */
  --bg-page: #f5f5f5;
  --bg-surface: #ffffff;
  --bg-surface-alt: #fafafa;
  --bg-inset: #f0f0f0;
  --bg-hover: #e8e8e8;
  --bg-selected: #e3f2fd;
  --bg-overlay: rgba(0, 0, 0, 0.4);

  /* Text */
  --text-primary: #333333;
  --text-secondary: #555555;
  --text-muted: #888888;
  --text-placeholder: #aaaaaa;
  --text-on-accent: #ffffff;

  /* Borders */
  --border-default: #e0e0e0;
  --border-light: #f0f0f0;
  --border-focus: #90caf9;

  /* Accent */
  --accent: #1976d2;
  --accent-light: #e3f2fd;
  --accent-hover: #1565c0;

  /* Status */
  --status-success: #2e7d32;
  --status-success-bg: #e8f5e9;
  --status-warning: #e65100;
  --status-warning-bg: #fff3e0;
  --status-error: #c62828;
  --status-error-bg: #ffebee;
  --status-info: #1565c0;
  --status-info-bg: #e3f2fd;

  /* Badge colors */
  --badge-draft-bg: #fff3e0;
  --badge-draft-text: #e65100;
  --badge-published-bg: #e8f5e9;
  --badge-published-text: #2e7d32;
  --badge-deprecated-bg: #f5f5f5;
  --badge-deprecated-text: #999999;

  /* Sizing */
  --header-height: 42px;
  --rail-width: 52px;
  --nav-panel-width: 200px;
  --font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

.theme-dark {
  --bg-page: #1e1e1e;
  --bg-surface: #252526;
  --bg-surface-alt: #2d2d30;
  --bg-inset: #1e1e1e;
  --bg-hover: #3e3e42;
  --bg-selected: #094771;
  --bg-overlay: rgba(0, 0, 0, 0.6);

  --text-primary: #cccccc;
  --text-secondary: #aaaaaa;
  --text-muted: #888888;
  --text-placeholder: #666666;

  --border-default: #3e3e42;
  --border-light: #2d2d30;
  --border-focus: #007acc;

  --accent: #4fc3f7;
  --accent-light: #094771;
  --accent-hover: #81d4fa;

  --badge-draft-bg: #4e3a1e;
  --badge-draft-text: #ffb74d;
  --badge-published-bg: #1b3a1e;
  --badge-published-text: #81c784;
  --badge-deprecated-bg: #2d2d30;
  --badge-deprecated-text: #888888;

  --status-success-bg: #1b3a1e;
  --status-warning-bg: #4e3a1e;
  --status-error-bg: #4e1e1e;
  --status-info-bg: #094771;
}

/* ============================================
   CSS RESET + BASE
   ============================================ */
*, *::before, *::after { margin: 0; padding: 0; box-sizing: border-box; }
html, body { height: 100%; overflow: hidden; }
body {
  font-family: var(--font-family);
  font-size: 13px;
  color: var(--text-primary);
  background: var(--bg-page);
  line-height: 1.5;
}
input, select, button, textarea { font-family: inherit; font-size: inherit; }

/* ============================================
   LAYOUT — Shell
   ============================================ */
.app { display: flex; flex-direction: column; height: 100vh; }

/* Header */
.header {
  height: var(--header-height);
  background: var(--bg-surface);
  border-bottom: 1px solid var(--border-default);
  display: flex;
  align-items: center;
  padding: 0 16px;
  flex-shrink: 0;
  z-index: 100;
}
.header-logo { font-weight: 700; font-size: 14px; color: var(--accent); }
.header-divider { width: 1px; height: 18px; background: var(--border-default); margin: 0 8px; }
.header-subtitle { font-size: 12px; color: var(--text-muted); }
.header-right { display: flex; align-items: center; gap: 14px; margin-left: auto; }
.theme-toggle {
  width: 28px; height: 28px; border-radius: 50%;
  border: 1px solid var(--border-default); background: var(--bg-surface-alt);
  cursor: pointer; display: flex; align-items: center; justify-content: center;
  font-size: 14px; color: var(--text-muted); transition: background 0.15s;
}
.theme-toggle:hover { background: var(--bg-hover); }
.user-display { display: flex; align-items: center; gap: 6px; font-size: 11px; color: var(--text-muted); }
.user-avatar {
  width: 24px; height: 24px; border-radius: 50%;
  background: var(--accent-light); color: var(--accent);
  display: flex; align-items: center; justify-content: center;
  font-size: 10px; font-weight: 700;
}

/* App body (below header) */
.app-body { display: flex; flex: 1; overflow: hidden; }

/* Rail */
.rail {
  width: var(--rail-width);
  background: var(--bg-surface-alt);
  border-right: 1px solid var(--border-default);
  display: flex; flex-direction: column; align-items: center;
  padding-top: 10px; gap: 2px; flex-shrink: 0; z-index: 50;
}
.rail-item {
  width: 42px; padding: 6px 0; border-radius: 6px;
  display: flex; flex-direction: column; align-items: center; gap: 2px;
  cursor: pointer; border: none; background: transparent;
  transition: background 0.15s;
}
.rail-item:hover { background: var(--bg-hover); }
.rail-item.active { background: var(--bg-selected); }
.rail-icon { font-size: 18px; color: var(--text-muted); line-height: 1; }
.rail-item.active .rail-icon { color: var(--accent); }
.rail-label { font-size: 9px; color: var(--text-muted); font-weight: 500; }
.rail-item.active .rail-label { color: var(--accent); font-weight: 600; }

/* Nav panel */
.nav-panel {
  width: 0; overflow: hidden;
  background: var(--bg-surface-alt);
  border-right: 1px solid var(--border-default);
  flex-shrink: 0; transition: width 0.2s ease;
}
.nav-panel.open { width: var(--nav-panel-width); }
.nav-panel-inner { width: var(--nav-panel-width); padding: 12px 0; }
.nav-category-label {
  font-size: 10px; font-weight: 600; color: var(--text-muted);
  text-transform: uppercase; letter-spacing: 0.5px; padding: 4px 16px 8px;
}
.nav-item {
  padding: 8px 16px; font-size: 12px; color: var(--text-secondary);
  cursor: pointer; display: flex; align-items: center; gap: 8px;
  border: none; background: transparent; width: 100%; text-align: left;
  transition: background 0.1s;
}
.nav-item:hover { background: var(--bg-hover); }
.nav-item.active { background: var(--bg-selected); color: var(--accent); font-weight: 600; }
.nav-item-icon { font-size: 14px; width: 18px; text-align: center; }

/* Content area */
.content-area {
  flex: 1; overflow: auto; background: var(--bg-page); display: flex; flex-direction: column;
}
.screen { display: none; flex-direction: column; height: 100%; }
.screen.active { display: flex; }

/* Breadcrumb */
.breadcrumb { font-size: 11px; color: var(--text-muted); padding: 12px 16px 0; flex-shrink: 0; }
.breadcrumb span { cursor: pointer; }
.breadcrumb span:hover { color: var(--accent); }
.breadcrumb .sep { margin: 0 4px; cursor: default; }
.breadcrumb .sep:hover { color: var(--text-muted); }

/* Screen title row */
.title-row {
  display: flex; align-items: center; gap: 8px;
  padding: 4px 16px 12px; flex-shrink: 0;
}
.title-text { font-size: 16px; font-weight: 600; }
.title-actions { display: flex; gap: 6px; margin-left: auto; }

/* Landing prompt */
.landing {
  display: flex; flex-direction: column; align-items: center;
  justify-content: center; height: 100%; color: var(--text-placeholder);
}
.landing-icon { font-size: 48px; margin-bottom: 12px; opacity: 0.5; }
.landing-text { font-size: 14px; }

/* ============================================
   COMPONENTS — Reusable
   ============================================ */

/* Buttons */
.btn {
  padding: 5px 12px; font-size: 11px; border-radius: 4px;
  border: 1px solid var(--border-default); background: var(--bg-surface);
  color: var(--text-secondary); cursor: pointer; white-space: nowrap;
  transition: background 0.1s, border-color 0.1s;
}
.btn:hover { background: var(--bg-hover); }
.btn-primary { background: var(--accent); color: var(--text-on-accent); border-color: var(--accent); }
.btn-primary:hover { background: var(--accent-hover); }
.btn-danger { color: var(--status-error); border-color: var(--status-error-bg); }
.btn-danger:hover { background: var(--status-error-bg); }
.btn-sm { padding: 3px 8px; font-size: 10px; }
.btn-icon {
  width: 28px; height: 28px; padding: 0;
  display: flex; align-items: center; justify-content: center;
  border-radius: 4px; font-size: 14px;
}

/* Badges */
.badge {
  display: inline-block; font-size: 9px; font-weight: 600;
  padding: 1px 7px; border-radius: 3px;
}
.badge-draft { background: var(--badge-draft-bg); color: var(--badge-draft-text); }
.badge-published { background: var(--badge-published-bg); color: var(--badge-published-text); }
.badge-deprecated { background: var(--badge-deprecated-bg); color: var(--badge-deprecated-text); }
.badge-type {
  background: var(--accent-light); color: var(--accent);
  font-size: 10px; padding: 2px 8px;
}

/* Search input */
.search-input {
  width: 100%; padding: 6px 10px; font-size: 11px;
  border: 1px solid var(--border-default); border-radius: 4px;
  background: var(--bg-surface); color: var(--text-primary);
  outline: none;
}
.search-input::placeholder { color: var(--text-placeholder); }
.search-input:focus { border-color: var(--border-focus); }

/* Select dropdown */
.select {
  padding: 5px 8px; font-size: 11px;
  border: 1px solid var(--border-default); border-radius: 4px;
  background: var(--bg-surface); color: var(--text-primary);
  outline: none; cursor: pointer;
}
.select:focus { border-color: var(--border-focus); }

/* Detail panel card */
.detail-panel {
  background: var(--bg-surface); border: 1px solid var(--border-default);
  border-radius: 4px; overflow: hidden;
}
.detail-header {
  background: var(--bg-surface-alt); padding: 8px 12px;
  border-bottom: 1px solid var(--border-default);
  font-size: 12px; font-weight: 600; color: var(--text-primary);
  display: flex; align-items: center; gap: 8px;
}
.detail-header .badge { margin-left: 4px; }
.detail-header-actions { display: flex; gap: 4px; margin-left: auto; }
.detail-body { padding: 12px; }

/* Form fields */
.field { margin-bottom: 10px; }
.field-label { font-size: 10px; color: var(--text-muted); font-weight: 500; margin-bottom: 2px; }
.field-value {
  width: 100%; padding: 5px 8px; font-size: 11px;
  border: 1px solid var(--border-default); border-radius: 3px;
  background: var(--bg-surface-alt); color: var(--text-primary);
  outline: none;
}
.field-value:focus { border-color: var(--border-focus); }
.field-value[readonly] { color: var(--text-muted); cursor: default; }
.field-row { display: flex; gap: 10px; }
.field-row .field { flex: 1; }

/* Table */
.data-table { width: 100%; border-collapse: collapse; }
.data-table th {
  text-align: left; font-size: 10px; font-weight: 600;
  color: var(--text-muted); text-transform: uppercase;
  padding: 6px 10px; border-bottom: 1px solid var(--border-default);
  background: var(--bg-surface-alt); position: sticky; top: 0;
}
.data-table td {
  font-size: 11px; padding: 7px 10px;
  border-bottom: 1px solid var(--border-light);
  color: var(--text-secondary);
}
.data-table tr:hover td { background: var(--bg-hover); }
.data-table tr.selected td { background: var(--bg-selected); color: var(--accent); }

/* Up/down arrows */
.arrows { display: flex; flex-direction: column; gap: 1px; }
.arrow-btn {
  width: 20px; height: 16px; font-size: 9px;
  border: 1px solid var(--border-default); background: var(--bg-surface);
  color: var(--text-muted); display: flex; align-items: center;
  justify-content: center; cursor: pointer; border-radius: 2px;
  padding: 0;
}
.arrow-btn:hover { background: var(--accent-light); color: var(--accent); border-color: var(--border-focus); }
.arrow-btn.disabled { color: var(--border-default); cursor: default; pointer-events: none; }

/* Tab strip */
.tab-strip {
  display: flex; border-bottom: 1px solid var(--border-default);
  padding: 0 14px; background: var(--bg-surface); flex-shrink: 0;
}
.tab-item {
  padding: 8px 16px; font-size: 11px; color: var(--text-muted);
  cursor: pointer; border-bottom: 2px solid transparent;
  margin-bottom: -1px; background: transparent; border-top: none;
  border-left: none; border-right: none; transition: color 0.1s;
}
.tab-item:hover { color: var(--text-secondary); }
.tab-item.active { color: var(--accent); border-bottom-color: var(--accent); font-weight: 600; }

/* Tab content */
.tab-content { display: none; flex: 1; overflow: auto; }
.tab-content.active { display: flex; flex-direction: column; }

/* Tree */
.tree-panel {
  width: 240px; border-right: 1px solid var(--border-default);
  overflow-y: auto; background: var(--bg-surface); flex-shrink: 0;
  display: flex; flex-direction: column;
}
.tree-search { padding: 8px 10px; border-bottom: 1px solid var(--border-light); }
.tree-items { flex: 1; overflow-y: auto; padding: 4px 0; }
.tree-item {
  padding: 5px 10px; font-size: 11px; color: var(--text-secondary);
  cursor: pointer; display: flex; align-items: center; gap: 4px;
  white-space: nowrap;
}
.tree-item:hover { background: var(--bg-hover); }
.tree-item.selected { background: var(--bg-selected); color: var(--accent); font-weight: 600; }
.tree-toggle { width: 14px; font-size: 8px; color: var(--text-muted); text-align: center; flex-shrink: 0; }
.tree-node-icon { font-size: 12px; color: var(--text-muted); width: 16px; text-align: center; flex-shrink: 0; }
.tree-item.selected .tree-node-icon { color: var(--accent); }

/* Filter panel (List-Detail pattern) */
.filter-panel {
  width: 180px; border-right: 1px solid var(--border-default);
  padding: 12px; background: var(--bg-surface); flex-shrink: 0;
  overflow-y: auto;
}
.filter-panel .field { margin-bottom: 14px; }

/* Split layout (Tree-Detail right side) */
.detail-area { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
.detail-top { padding: 14px; border-bottom: 1px solid var(--border-default); flex-shrink: 0; }
.detail-bottom { padding: 14px; flex: 1; overflow: auto; }

/* Checkbox */
.checkbox { font-size: 14px; cursor: pointer; color: var(--text-muted); }
.checkbox.checked { color: var(--accent); }

/* Toast notification */
.toast {
  padding: 8px 16px; font-size: 12px; border-radius: 4px;
  margin: 8px 16px; display: none; align-items: center; gap: 8px;
}
.toast.success { background: var(--status-success-bg); color: var(--status-success); display: flex; }
.toast.error { background: var(--status-error-bg); color: var(--status-error); display: flex; }

/* Modal */
.modal-overlay {
  position: fixed; inset: 0; background: var(--bg-overlay);
  display: none; align-items: center; justify-content: center; z-index: 200;
}
.modal-overlay.open { display: flex; }
.modal {
  background: var(--bg-surface); border-radius: 8px;
  box-shadow: 0 8px 32px rgba(0,0,0,0.2); width: 500px; max-height: 80vh;
  display: flex; flex-direction: column; overflow: hidden;
}
.modal-lg { width: 700px; }
.modal-header {
  padding: 14px 16px; border-bottom: 1px solid var(--border-default);
  font-size: 14px; font-weight: 600; display: flex; align-items: center;
}
.modal-header .close-btn {
  margin-left: auto; background: transparent; border: none;
  font-size: 18px; color: var(--text-muted); cursor: pointer; padding: 0 4px;
}
.modal-header .close-btn:hover { color: var(--text-primary); }
.modal-body { padding: 16px; overflow-y: auto; flex: 1; }
.modal-footer {
  padding: 12px 16px; border-top: 1px solid var(--border-default);
  display: flex; justify-content: flex-end; gap: 8px;
}

/* Version selector */
.version-selector {
  display: flex; align-items: center; gap: 8px;
  margin-bottom: 12px; font-size: 12px;
}
.version-selector .select { min-width: 200px; }
.version-info { font-size: 11px; color: var(--text-muted); }

/* Eligibility matrix */
.elig-matrix { border-collapse: collapse; }
.elig-matrix th { font-size: 10px; padding: 4px 8px; }
.elig-matrix td { text-align: center; padding: 4px 8px; }
.elig-check { font-size: 16px; cursor: pointer; color: var(--text-muted); }
.elig-check.checked { color: var(--accent); }

/* Dashboard tiles (Failure Log) */
.dashboard-tiles { display: flex; gap: 16px; margin-bottom: 16px; }
.dashboard-tile {
  flex: 1; background: var(--bg-surface); border: 1px solid var(--border-default);
  border-radius: 6px; padding: 14px;
}
.dashboard-tile h4 { font-size: 12px; font-weight: 600; margin-bottom: 10px; color: var(--text-primary); }
.tile-row { display: flex; justify-content: space-between; font-size: 11px; padding: 3px 0; }
.tile-row-label { color: var(--text-secondary); }
.tile-row-value { font-weight: 600; color: var(--text-primary); }
.tile-bar { height: 6px; background: var(--accent-light); border-radius: 3px; margin-top: 2px; }
.tile-bar-fill { height: 100%; background: var(--accent); border-radius: 3px; }

/* Expandable row */
.expandable-detail {
  display: none; padding: 8px 10px; background: var(--bg-surface-alt);
  font-size: 11px; color: var(--text-secondary); border-bottom: 1px solid var(--border-light);
}
.expandable-detail.open { display: table-row; }
.json-block {
  background: var(--bg-inset); padding: 8px; border-radius: 3px;
  font-family: 'Consolas', 'Monaco', monospace; font-size: 10px;
  white-space: pre-wrap; color: var(--text-secondary);
}

/* Days of week visual */
.dow-visual { display: flex; gap: 2px; }
.dow-day {
  width: 18px; height: 18px; border-radius: 3px; font-size: 9px;
  display: flex; align-items: center; justify-content: center; font-weight: 600;
}
.dow-day.active { background: var(--accent); color: var(--text-on-accent); }
.dow-day.inactive { background: var(--bg-inset); color: var(--text-muted); }
</style>
</head>
<body>
<!-- Content added in subsequent tasks -->
</body>
</html>
```

- [ ] **Step 2: Open in browser to verify**

Open `mockup/index.html` in a browser. Verify:
- Page loads with no console errors
- Background is light gray (`#f5f5f5`)
- No visible content yet (empty body) — that's expected

- [ ] **Step 3: Commit**

```bash
git add mockup/index.html
git commit -m "mockup: CSS foundation with light/dark theme system"
```

---

## Task 2: Page Shell — Header, Rail, Nav Panel, Content Container

**Files:**
- Modify: `mockup/index.html`

Add the HTML structure for the page shell and the JavaScript for rail/nav/routing/theme.

- [ ] **Step 1: Add the body HTML**

Replace the `<!-- Content added in subsequent tasks -->` comment inside `<body>` with:

```html
<div class="app">
  <!-- Header -->
  <header class="header">
    <span class="header-logo">MPP</span>
    <div class="header-divider"></div>
    <span class="header-subtitle">Configuration Tool</span>
    <div class="header-right">
      <button class="theme-toggle" onclick="toggleTheme()" title="Toggle light/dark theme">
        <span id="theme-icon">&#9790;</span>
      </button>
      <div class="user-display">
        <div class="user-avatar">JP</div>
        J. Potgieter
      </div>
    </div>
  </header>

  <!-- App body -->
  <div class="app-body">
    <!-- Rail -->
    <nav class="rail">
      <button class="rail-item" data-category="plant" onclick="toggleCategory('plant')">
        <span class="rail-icon">&#127981;</span>
        <span class="rail-label">Plant</span>
      </button>
      <button class="rail-item" data-category="parts" onclick="toggleCategory('parts')">
        <span class="rail-icon">&#9881;</span>
        <span class="rail-label">Parts</span>
      </button>
      <button class="rail-item" data-category="quality" onclick="toggleCategory('quality')">
        <span class="rail-icon">&#9745;</span>
        <span class="rail-label">Quality</span>
      </button>
      <button class="rail-item" data-category="operations" onclick="toggleCategory('operations')">
        <span class="rail-icon">&#9200;</span>
        <span class="rail-label">Ops</span>
      </button>
      <button class="rail-item" data-category="system" onclick="toggleCategory('system')">
        <span class="rail-icon">&#128736;</span>
        <span class="rail-label">System</span>
      </button>
    </nav>

    <!-- Nav panel -->
    <div class="nav-panel" id="nav-panel">
      <div class="nav-panel-inner" id="nav-panel-inner"></div>
    </div>

    <!-- Content area -->
    <main class="content-area" id="content-area">
      <!-- Landing -->
      <div class="screen active" id="screen-landing">
        <div class="landing">
          <div class="landing-icon">&#127981;</div>
          <div class="landing-text">Select a category to begin</div>
        </div>
      </div>

      <!-- Screen placeholders — filled in subsequent tasks -->
    </main>
  </div>
</div>

<!-- Modal container — filled in Task 9 -->
```

- [ ] **Step 2: Add the JavaScript before closing `</body>`**

```html
<script>
/* ============================================
   NAVIGATION STATE
   ============================================ */
const NAV_CONFIG = {
  plant: {
    label: 'Plant',
    screens: [
      { id: 'plant-hierarchy', label: 'Plant Hierarchy', icon: '&#127981;' }
    ]
  },
  parts: {
    label: 'Parts',
    screens: [
      { id: 'item-master', label: 'Item Master', icon: '&#128230;' },
      { id: 'operation-templates', label: 'Operation Templates', icon: '&#128203;' }
    ]
  },
  quality: {
    label: 'Quality',
    screens: [
      { id: 'quality-specs', label: 'Quality Specs', icon: '&#128200;' },
      { id: 'defect-codes', label: 'Defect Codes', icon: '&#128683;' }
    ]
  },
  operations: {
    label: 'Operations',
    screens: [
      { id: 'downtime-codes', label: 'Downtime Codes', icon: '&#9200;' },
      { id: 'shift-schedules', label: 'Shift Schedules', icon: '&#128197;' }
    ]
  },
  system: {
    label: 'System',
    screens: [
      { id: 'users', label: 'Users', icon: '&#128100;' },
      { id: 'audit-log', label: 'Audit Log', icon: '&#128220;' },
      { id: 'failure-log', label: 'Failure Log', icon: '&#9888;' }
    ]
  }
};

let activeCategory = null;
let activeScreen = null;

function toggleCategory(category) {
  const panel = document.getElementById('nav-panel');
  const inner = document.getElementById('nav-panel-inner');

  // Toggle off if clicking the active category
  if (activeCategory === category) {
    activeCategory = null;
    panel.classList.remove('open');
    document.querySelectorAll('.rail-item').forEach(r => r.classList.remove('active'));
    return;
  }

  activeCategory = category;

  // Highlight rail item
  document.querySelectorAll('.rail-item').forEach(r => {
    r.classList.toggle('active', r.dataset.category === category);
  });

  // Populate nav panel
  const config = NAV_CONFIG[category];
  inner.innerHTML = `
    <div class="nav-category-label">${config.label}</div>
    ${config.screens.map(s => `
      <button class="nav-item ${activeScreen === s.id ? 'active' : ''}"
              onclick="navigateTo('${category}', '${s.id}')">
        <span class="nav-item-icon">${s.icon}</span>
        ${s.label}
      </button>
    `).join('')}
  `;

  panel.classList.add('open');
}

function navigateTo(category, screenId) {
  activeScreen = screenId;

  // Highlight nav item
  document.querySelectorAll('.nav-item').forEach(n => {
    n.classList.toggle('active', n.textContent.trim() ===
      NAV_CONFIG[category].screens.find(s => s.id === screenId)?.label);
  });

  // Show screen
  document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
  const target = document.getElementById('screen-' + screenId);
  if (target) {
    target.classList.add('active');
  } else {
    // Fallback: show landing with "coming soon" if screen not built yet
    document.getElementById('screen-landing').classList.add('active');
  }
}

/* ============================================
   THEME TOGGLE
   ============================================ */
function toggleTheme() {
  document.body.classList.toggle('theme-dark');
  const icon = document.getElementById('theme-icon');
  icon.innerHTML = document.body.classList.contains('theme-dark') ? '&#9788;' : '&#9790;';
}

/* ============================================
   TAB SWITCHING
   ============================================ */
function switchTab(containerId, tabId) {
  const container = document.getElementById(containerId);
  if (!container) return;
  container.querySelectorAll('.tab-item').forEach(t => {
    t.classList.toggle('active', t.dataset.tab === tabId);
  });
  container.querySelectorAll('.tab-content').forEach(tc => {
    tc.classList.toggle('active', tc.id === tabId);
  });
}

/* ============================================
   MODAL
   ============================================ */
function openModal(modalId) {
  document.getElementById(modalId)?.classList.add('open');
}
function closeModal(modalId) {
  document.getElementById(modalId)?.classList.remove('open');
}

/* ============================================
   TOAST (static demo)
   ============================================ */
function showToast(screenId, type, message) {
  const toast = document.querySelector(`#screen-${screenId} .toast`);
  if (!toast) return;
  toast.className = 'toast ' + type;
  toast.textContent = message;
  setTimeout(() => { toast.className = 'toast'; }, 3000);
}
</script>
```

- [ ] **Step 3: Open in browser to verify**

Open `mockup/index.html`. Verify:
- Header shows "MPP | Configuration Tool" with moon icon and "JP J. Potgieter"
- 5 rail icons visible on the left (Plant, Parts, Quality, Ops, System)
- Clicking "Parts" rail icon: nav panel slides open showing "Item Master" and "Operation Templates"
- Clicking "Parts" again: nav panel collapses
- Clicking "Plant" after "Parts": panel swaps to show "Plant Hierarchy"
- Clicking the moon icon toggles dark mode (background goes dark)
- Clicking a nav item shows the landing screen (screens not built yet — expected)
- No console errors

- [ ] **Step 4: Commit**

```bash
git add mockup/index.html
git commit -m "mockup: page shell with header, rail, nav panel, routing JS"
```

---

## Task 3: Plant Hierarchy Screen

**Files:**
- Modify: `mockup/index.html`

The most complex screen — establishes the Tree-Detail pattern with realistic MPP data.

- [ ] **Step 1: Add Plant Hierarchy screen HTML**

Add the following inside `<main class="content-area">`, after the landing screen div:

```html
<!-- Plant Hierarchy -->
<div class="screen" id="screen-plant-hierarchy">
  <div class="breadcrumb"><span>Plant</span><span class="sep">&rsaquo;</span><span>Plant Hierarchy</span></div>
  <div class="title-row">
    <span class="title-text">Plant Hierarchy</span>
    <div class="title-actions">
      <button class="btn btn-primary" onclick="openModal('modal-add-location')">+ Add Location</button>
      <button class="btn btn-icon" onclick="openModal('modal-loc-type-editor')" title="Location Type Definitions">&#9881;</button>
    </div>
  </div>
  <div class="toast" id="toast-plant-hierarchy"></div>
  <div style="display: flex; flex: 1; overflow: hidden; border-top: 1px solid var(--border-default);">
    <!-- Tree panel -->
    <div class="tree-panel">
      <div class="tree-search">
        <input class="search-input" placeholder="&#128269; Search locations...">
      </div>
      <div class="tree-items">
        <div class="tree-item" style="padding-left: 10px;">
          <span class="tree-toggle">&#9660;</span>
          <span class="tree-node-icon">&#127965;</span> Madison Precision Products
        </div>
        <div class="tree-item" style="padding-left: 28px;">
          <span class="tree-toggle">&#9660;</span>
          <span class="tree-node-icon">&#127963;</span> Madison Facility
        </div>
        <div class="tree-item" style="padding-left: 46px;">
          <span class="tree-toggle">&#9660;</span>
          <span class="tree-node-icon">&#9878;</span> Die Cast
        </div>
        <div class="tree-item selected" style="padding-left: 64px;">
          <span class="tree-toggle">&#9654;</span>
          <span class="tree-node-icon">&#9881;</span> DC Machine #7
        </div>
        <div class="tree-item" style="padding-left: 64px;">
          <span class="tree-toggle">&#9654;</span>
          <span class="tree-node-icon">&#9881;</span> DC Machine #12
        </div>
        <div class="tree-item" style="padding-left: 64px;">
          <span class="tree-toggle">&#9654;</span>
          <span class="tree-node-icon">&#9881;</span> DC Machine #15
        </div>
        <div class="tree-item" style="padding-left: 46px;">
          <span class="tree-toggle">&#9660;</span>
          <span class="tree-node-icon">&#9878;</span> Trim Shop
        </div>
        <div class="tree-item" style="padding-left: 64px;">
          <span class="tree-toggle">&#9654;</span>
          <span class="tree-node-icon">&#9881;</span> Trim Press #1
        </div>
        <div class="tree-item" style="padding-left: 46px;">
          <span class="tree-toggle">&#9654;</span>
          <span class="tree-node-icon">&#9878;</span> Machine Shop
        </div>
        <div class="tree-item" style="padding-left: 46px;">
          <span class="tree-toggle">&#9654;</span>
          <span class="tree-node-icon">&#9878;</span> Production Control
        </div>
        <div class="tree-item" style="padding-left: 46px;">
          <span class="tree-toggle">&#9654;</span>
          <span class="tree-node-icon">&#9878;</span> Quality Control
        </div>
      </div>
    </div>

    <!-- Detail area -->
    <div class="detail-area">
      <!-- Top: Location details -->
      <div class="detail-top">
        <div class="detail-panel">
          <div class="detail-header">
            Location Details
            <span class="badge badge-type">Cell &bull; DieCastMachine</span>
            <div class="detail-header-actions">
              <button class="btn btn-sm" onclick="showToast('plant-hierarchy','success','Location saved.')">Save</button>
              <button class="btn btn-sm btn-danger">Deprecate</button>
            </div>
          </div>
          <div class="detail-body">
            <div class="field-row">
              <div class="field">
                <div class="field-label">Name</div>
                <input class="field-value" value="DC Machine #7">
              </div>
              <div class="field">
                <div class="field-label">Code</div>
                <input class="field-value" value="DC-007">
              </div>
              <div class="field">
                <div class="field-label">Parent</div>
                <input class="field-value" value="Die Cast (Area)" readonly>
              </div>
            </div>
            <div class="field">
              <div class="field-label">Description</div>
              <input class="field-value" value="400-ton Toshiba die cast press, Bay 3">
            </div>
          </div>
        </div>
      </div>

      <!-- Bottom: Attributes -->
      <div class="detail-bottom">
        <div class="detail-panel">
          <div class="detail-header">
            Attributes
            <span style="font-size: 10px; color: var(--text-muted); font-weight: 400;">(DieCastMachine schema)</span>
          </div>
          <div style="overflow: auto;">
            <table class="data-table">
              <thead>
                <tr>
                  <th style="width: 36px;"></th>
                  <th>Attribute</th>
                  <th>Value</th>
                  <th>UOM</th>
                  <th style="width: 50px;">Req</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td><div class="arrows"><button class="arrow-btn disabled">&#9650;</button><button class="arrow-btn">&#9660;</button></div></td>
                  <td>Tonnage</td>
                  <td><input class="field-value" value="400" style="width: 80px;"></td>
                  <td style="color: var(--text-muted); font-size: 10px;">tons</td>
                  <td style="text-align: center;"><span class="checkbox checked">&#9745;</span></td>
                </tr>
                <tr>
                  <td><div class="arrows"><button class="arrow-btn">&#9650;</button><button class="arrow-btn">&#9660;</button></div></td>
                  <td>NumberOfCavities</td>
                  <td><input class="field-value" value="2" style="width: 80px;"></td>
                  <td style="color: var(--text-muted); font-size: 10px;">&mdash;</td>
                  <td style="text-align: center;"><span class="checkbox checked">&#9745;</span></td>
                </tr>
                <tr>
                  <td><div class="arrows"><button class="arrow-btn">&#9650;</button><button class="arrow-btn disabled">&#9660;</button></div></td>
                  <td>RefCycleTimeSec</td>
                  <td><input class="field-value" value="62.5" style="width: 80px;"></td>
                  <td style="color: var(--text-muted); font-size: 10px;">sec</td>
                  <td style="text-align: center;"><span class="checkbox">&#9744;</span></td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
```

- [ ] **Step 2: Open in browser to verify**

Navigate to Plant > Plant Hierarchy. Verify:
- Tree on left with MPP hierarchy (Enterprise > Site > Area > Machines)
- DC Machine #7 highlighted as selected
- Location Details card top-right with Name/Code/Parent/Description fields
- Attributes table bottom-right with Tonnage/NumberOfCavities/RefCycleTimeSec
- Up/down arrows: up disabled on first row, down disabled on last row
- Gear icon in title bar
- "+ Add Location" button in title bar
- "Save" button shows a green toast
- Theme toggle works (dark mode renders correctly)

- [ ] **Step 3: Commit**

```bash
git add mockup/index.html
git commit -m "mockup: Plant Hierarchy screen — tree-detail pattern with sample data"
```

---

## Task 4: Item Master Screen (Hub with Tabs)

**Files:**
- Modify: `mockup/index.html`

The most content-heavy screen — item list on the left, persistent detail card top-right, 5 tabs bottom-right.

- [ ] **Step 1: Add Item Master screen HTML**

Add after the Plant Hierarchy screen div:

```html
<!-- Item Master -->
<div class="screen" id="screen-item-master">
  <div class="breadcrumb"><span>Parts</span><span class="sep">&rsaquo;</span><span>Item Master</span><span class="sep">&rsaquo;</span><span>5G0 Front Cover</span></div>
  <div class="title-row">
    <span class="title-text">Item Master</span>
    <div class="title-actions">
      <button class="btn btn-primary" onclick="openModal('modal-add-item')">+ Add Item</button>
    </div>
  </div>
  <div class="toast" id="toast-item-master"></div>
  <div style="display: flex; flex: 1; overflow: hidden; border-top: 1px solid var(--border-default);">
    <!-- Left: Item list -->
    <div class="tree-panel">
      <div class="tree-search">
        <input class="search-input" placeholder="&#128269; Search part number...">
        <div style="margin-top: 6px;">
          <select class="select" style="width: 100%;">
            <option>All Types</option>
            <option>Raw Material</option>
            <option>Component</option>
            <option>Sub-Assembly</option>
            <option selected>Finished Good</option>
            <option>Pass-Through</option>
          </select>
        </div>
      </div>
      <div class="tree-items">
        <div class="tree-item selected" style="padding-left: 10px;">
          <span class="tree-node-icon" style="font-size: 10px;">&#128230;</span>
          <span><strong>5G0</strong> Front Cover Assy</span>
          <span class="badge badge-type" style="margin-left: auto; font-size: 8px;">FG</span>
        </div>
        <div class="tree-item" style="padding-left: 10px;">
          <span class="tree-node-icon" style="font-size: 10px;">&#128230;</span>
          <span><strong>5G0-C</strong> Front Cover Casting</span>
          <span class="badge" style="margin-left: auto; font-size: 8px; background: var(--bg-inset); color: var(--text-muted);">COMP</span>
        </div>
        <div class="tree-item" style="padding-left: 10px;">
          <span class="tree-node-icon" style="font-size: 10px;">&#128230;</span>
          <span><strong>PNA</strong> Mounting Pin</span>
          <span class="badge" style="margin-left: auto; font-size: 8px; background: var(--bg-inset); color: var(--text-muted);">COMP</span>
        </div>
        <div class="tree-item" style="padding-left: 10px;">
          <span class="tree-node-icon" style="font-size: 10px;">&#128230;</span>
          <span><strong>6MA-HSG</strong> Cam Holder Housing</span>
          <span class="badge" style="margin-left: auto; font-size: 8px; background: var(--badge-draft-bg); color: var(--badge-draft-text);">PT</span>
        </div>
        <div class="tree-item" style="padding-left: 10px;">
          <span class="tree-node-icon" style="font-size: 10px;">&#128230;</span>
          <span><strong>RPY</strong> Assembly Set</span>
          <span class="badge badge-type" style="margin-left: auto; font-size: 8px;">FG</span>
        </div>
      </div>
    </div>

    <!-- Right: Details + Tabs -->
    <div class="detail-area">
      <!-- Top: Item details (persistent) -->
      <div class="detail-top">
        <div class="detail-panel">
          <div class="detail-header">
            Item Details
            <span class="badge badge-type">Finished Good</span>
            <div class="detail-header-actions">
              <button class="btn btn-sm" onclick="showToast('item-master','success','Item saved.')">Save</button>
              <button class="btn btn-sm btn-danger">Deprecate</button>
            </div>
          </div>
          <div class="detail-body">
            <div class="field-row">
              <div class="field">
                <div class="field-label">Part Number</div>
                <input class="field-value" value="5G0" readonly>
              </div>
              <div class="field">
                <div class="field-label">Item Type</div>
                <input class="field-value" value="Finished Good" readonly>
              </div>
              <div class="field">
                <div class="field-label">UOM</div>
                <select class="select" style="width: 100%;"><option selected>EA</option><option>LB</option><option>KG</option></select>
              </div>
            </div>
            <div class="field-row">
              <div class="field">
                <div class="field-label">Description</div>
                <input class="field-value" value="5G0 Front Cover Assembly">
              </div>
              <div class="field">
                <div class="field-label">Macola Part #</div>
                <input class="field-value" value="5G0-MAC-001">
              </div>
            </div>
            <div class="field-row">
              <div class="field">
                <div class="field-label">Unit Weight</div>
                <input class="field-value" value="3.25" style="width: 80px;">
              </div>
              <div class="field">
                <div class="field-label">Weight UOM</div>
                <select class="select" style="width: 100%;"><option selected>LB</option><option>KG</option></select>
              </div>
              <div class="field">
                <div class="field-label">Default Sub-LOT Qty</div>
                <input class="field-value" value="24" style="width: 80px;">
              </div>
              <div class="field">
                <div class="field-label">Max LOT Size</div>
                <input class="field-value" value="100" style="width: 80px;">
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Bottom: Tabs -->
      <div style="flex: 1; display: flex; flex-direction: column; overflow: hidden;" id="item-tabs">
        <div class="tab-strip">
          <button class="tab-item active" data-tab="tab-container-config" onclick="switchTab('item-tabs','tab-container-config')">Container Config</button>
          <button class="tab-item" data-tab="tab-routes" onclick="switchTab('item-tabs','tab-routes')">Routes</button>
          <button class="tab-item" data-tab="tab-boms" onclick="switchTab('item-tabs','tab-boms')">BOMs</button>
          <button class="tab-item" data-tab="tab-quality-specs-link" onclick="switchTab('item-tabs','tab-quality-specs-link')">Quality Specs</button>
          <button class="tab-item" data-tab="tab-eligibility" onclick="switchTab('item-tabs','tab-eligibility')">Eligibility</button>
        </div>

        <!-- Tab: Container Config -->
        <div class="tab-content active" id="tab-container-config" style="padding: 14px;">
          <div class="detail-panel">
            <div class="detail-header">
              Container Configuration
              <div class="detail-header-actions">
                <button class="btn btn-sm">Save</button>
              </div>
            </div>
            <div class="detail-body">
              <div class="field-row">
                <div class="field">
                  <div class="field-label">Trays Per Container</div>
                  <input class="field-value" value="4">
                </div>
                <div class="field">
                  <div class="field-label">Parts Per Tray</div>
                  <input class="field-value" value="12">
                </div>
                <div class="field">
                  <div class="field-label">Serialized</div>
                  <select class="select" style="width: 100%;"><option selected>Yes</option><option>No</option></select>
                </div>
              </div>
              <div class="field-row">
                <div class="field">
                  <div class="field-label">Dunnage Code</div>
                  <input class="field-value" value="RD-5G0F">
                </div>
                <div class="field">
                  <div class="field-label">Customer Code</div>
                  <input class="field-value" value="HONDA-5G0">
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Tab: Routes -->
        <div class="tab-content" id="tab-routes" style="padding: 14px;">
          <div class="version-selector">
            <select class="select">
              <option selected>v2 — Effective 2026-01-15 (Published)</option>
              <option>v1 — Effective 2025-06-01 (Deprecated)</option>
            </select>
            <span class="badge badge-published">Published</span>
            <button class="btn btn-sm">New Version</button>
          </div>
          <div class="detail-panel">
            <div class="detail-header">
              Route Steps <span style="font-size: 10px; color: var(--text-muted); font-weight: 400;">5 steps</span>
            </div>
            <div style="overflow: auto;">
              <table class="data-table">
                <thead><tr><th style="width: 36px;"></th><th style="width: 30px;">#</th><th>Operation</th><th>Area</th><th>Data Collection</th></tr></thead>
                <tbody>
                  <tr><td><div class="arrows"><button class="arrow-btn disabled">&#9650;</button><button class="arrow-btn disabled">&#9660;</button></div></td><td style="color: var(--text-muted);">1</td><td>Die Cast</td><td>Die Cast</td><td style="font-size: 10px; color: var(--text-muted);">Die, Cavity, Weight, Good, Bad</td></tr>
                  <tr><td><div class="arrows"><button class="arrow-btn disabled">&#9650;</button><button class="arrow-btn disabled">&#9660;</button></div></td><td style="color: var(--text-muted);">2</td><td>Trim</td><td>Trim Shop</td><td style="font-size: 10px; color: var(--text-muted);">Weight, Good, Bad</td></tr>
                  <tr><td><div class="arrows"><button class="arrow-btn disabled">&#9650;</button><button class="arrow-btn disabled">&#9660;</button></div></td><td style="color: var(--text-muted);">3</td><td>CNC Machining</td><td>Machine Shop</td><td style="font-size: 10px; color: var(--text-muted);">Good, Bad</td></tr>
                  <tr><td><div class="arrows"><button class="arrow-btn disabled">&#9650;</button><button class="arrow-btn disabled">&#9660;</button></div></td><td style="color: var(--text-muted);">4</td><td>Assembly Front</td><td>Die Cast</td><td style="font-size: 10px; color: var(--text-muted);">Serial, Material Verify, Good, Bad</td></tr>
                  <tr><td><div class="arrows"><button class="arrow-btn disabled">&#9650;</button><button class="arrow-btn disabled">&#9660;</button></div></td><td style="color: var(--text-muted);">5</td><td>Pack &amp; Ship</td><td>Prod Control</td><td style="font-size: 10px; color: var(--text-muted);">Good</td></tr>
                </tbody>
              </table>
            </div>
          </div>
          <div style="margin-top: 8px; font-size: 10px; color: var(--text-muted); font-style: italic;">
            &#128274; Published route — read-only. Click "New Version" to create an editable draft.
          </div>
        </div>

        <!-- Tab: BOMs -->
        <div class="tab-content" id="tab-boms" style="padding: 14px;">
          <div class="version-selector">
            <select class="select">
              <option selected>v1 — Effective 2026-01-15 (Published)</option>
            </select>
            <span class="badge badge-published">Published</span>
            <button class="btn btn-sm">New Version</button>
          </div>
          <div class="detail-panel">
            <div class="detail-header">
              BOM Lines <span style="font-size: 10px; color: var(--text-muted); font-weight: 400;">2 components</span>
            </div>
            <div style="overflow: auto;">
              <table class="data-table">
                <thead><tr><th style="width: 36px;"></th><th style="width: 30px;">#</th><th>Child Item</th><th>Part Number</th><th>Qty Per</th><th>UOM</th></tr></thead>
                <tbody>
                  <tr><td><div class="arrows"><button class="arrow-btn disabled">&#9650;</button><button class="arrow-btn disabled">&#9660;</button></div></td><td style="color: var(--text-muted);">1</td><td>Front Cover Casting</td><td>5G0-C</td><td>1</td><td>EA</td></tr>
                  <tr><td><div class="arrows"><button class="arrow-btn disabled">&#9650;</button><button class="arrow-btn disabled">&#9660;</button></div></td><td style="color: var(--text-muted);">2</td><td>Mounting Pin</td><td>PNA</td><td>2</td><td>EA</td></tr>
                </tbody>
              </table>
            </div>
          </div>
          <div style="margin-top: 8px; font-size: 10px; color: var(--text-muted); font-style: italic;">
            &#128274; Published BOM — read-only. Click "New Version" to create an editable draft.
          </div>
        </div>

        <!-- Tab: Quality Specs (read-only links) -->
        <div class="tab-content" id="tab-quality-specs-link" style="padding: 14px;">
          <div class="detail-panel">
            <div class="detail-header">
              Linked Quality Specs
              <span style="font-size: 10px; color: var(--text-muted); font-weight: 400;">for 5G0 Front Cover</span>
            </div>
            <div style="overflow: auto;">
              <table class="data-table">
                <thead><tr><th>Spec Name</th><th>Active Version</th><th>Status</th><th style="width: 80px;"></th></tr></thead>
                <tbody>
                  <tr>
                    <td>5G0 Dimensional Spec</td>
                    <td>v2</td>
                    <td><span class="badge badge-published">Published</span></td>
                    <td><button class="btn btn-sm" onclick="toggleCategory('quality'); navigateTo('quality','quality-specs');">Go to spec &rarr;</button></td>
                  </tr>
                  <tr>
                    <td>5G0 Visual Inspection</td>
                    <td>v1</td>
                    <td><span class="badge badge-published">Published</span></td>
                    <td><button class="btn btn-sm" onclick="toggleCategory('quality'); navigateTo('quality','quality-specs');">Go to spec &rarr;</button></td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <!-- Tab: Eligibility -->
        <div class="tab-content" id="tab-eligibility" style="padding: 14px;">
          <div style="margin-bottom: 10px;">
            <select class="select"><option>All Areas</option><option selected>Die Cast</option><option>Machine Shop</option></select>
          </div>
          <div class="detail-panel">
            <div class="detail-header">
              Machine Eligibility
              <span style="font-size: 10px; color: var(--text-muted); font-weight: 400;">Die Cast area</span>
            </div>
            <div style="overflow: auto;">
              <table class="data-table">
                <thead><tr><th>Machine</th><th>Code</th><th>Tonnage</th><th style="width: 60px; text-align: center;">Eligible</th></tr></thead>
                <tbody>
                  <tr><td>DC Machine #3</td><td>DC-003</td><td>400 tons</td><td style="text-align: center;"><span class="elig-check checked">&#9745;</span></td></tr>
                  <tr><td>DC Machine #7</td><td>DC-007</td><td>400 tons</td><td style="text-align: center;"><span class="elig-check checked">&#9745;</span></td></tr>
                  <tr><td>DC Machine #12</td><td>DC-012</td><td>400 tons</td><td style="text-align: center;"><span class="elig-check checked">&#9745;</span></td></tr>
                  <tr><td>DC Machine #15</td><td>DC-015</td><td>250 tons</td><td style="text-align: center;"><span class="elig-check">&#9744;</span></td></tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
```

- [ ] **Step 2: Open in browser to verify**

Navigate to Parts > Item Master. Verify:
- Item list on left with 5G0 selected, type badges (FG, COMP, PT)
- Item Details card top-right with all fields, PartNumber and ItemType read-only
- 5 tabs below: Container Config (default active), Routes, BOMs, Quality Specs, Eligibility
- Container Config shows form fields
- Routes tab shows 5-step route with Published badge, all arrows disabled (read-only)
- BOMs tab shows 2 BOM lines with Published badge
- Quality Specs tab shows read-only list with "Go to spec" buttons
- Eligibility tab shows machine checkbox matrix
- Tab switching works correctly

- [ ] **Step 3: Commit**

```bash
git add mockup/index.html
git commit -m "mockup: Item Master screen — hub with 5 tabs, sample 5G0 data"
```

---

## Task 5: Operation Templates + Quality Specs Screens

**Files:**
- Modify: `mockup/index.html`

Two Tree-Detail screens. Operation Templates has the simpler clone-to-modify versioning; Quality Specs has Draft/Published/Deprecated with a tab strip.

- [ ] **Step 1: Add Operation Templates screen HTML**

Add after the Item Master screen div:

```html
<!-- Operation Templates -->
<div class="screen" id="screen-operation-templates">
  <div class="breadcrumb"><span>Parts</span><span class="sep">&rsaquo;</span><span>Operation Templates</span></div>
  <div class="title-row">
    <span class="title-text">Operation Templates</span>
    <div class="title-actions">
      <button class="btn btn-primary">+ New Template</button>
    </div>
  </div>
  <div class="toast"></div>
  <div style="display: flex; flex: 1; overflow: hidden; border-top: 1px solid var(--border-default);">
    <div class="tree-panel">
      <div class="tree-search">
        <input class="search-input" placeholder="&#128269; Search templates...">
        <div style="margin-top: 6px;">
          <select class="select" style="width: 100%;"><option selected>All Areas</option><option>Die Cast</option><option>Trim Shop</option><option>Machine Shop</option></select>
        </div>
      </div>
      <div class="tree-items">
        <div style="padding: 6px 10px; font-size: 10px; color: var(--text-muted); font-weight: 600; text-transform: uppercase;">Die Cast</div>
        <div class="tree-item selected" style="padding-left: 16px;">
          <span>Die Cast Operation</span>
          <span style="margin-left: auto; font-size: 10px; color: var(--text-muted);">v2</span>
        </div>
        <div style="padding: 6px 10px; font-size: 10px; color: var(--text-muted); font-weight: 600; text-transform: uppercase;">Trim Shop</div>
        <div class="tree-item" style="padding-left: 16px;">
          <span>Trim Operation</span>
          <span style="margin-left: auto; font-size: 10px; color: var(--text-muted);">v1</span>
        </div>
        <div style="padding: 6px 10px; font-size: 10px; color: var(--text-muted); font-weight: 600; text-transform: uppercase;">Machine Shop</div>
        <div class="tree-item" style="padding-left: 16px;">
          <span>CNC Machining</span>
          <span style="margin-left: auto; font-size: 10px; color: var(--text-muted);">v1</span>
        </div>
        <div style="padding: 6px 10px; font-size: 10px; color: var(--text-muted); font-weight: 600; text-transform: uppercase;">Assembly</div>
        <div class="tree-item" style="padding-left: 16px;">
          <span>Assembly Front (Serialized)</span>
          <span style="margin-left: auto; font-size: 10px; color: var(--text-muted);">v1</span>
        </div>
        <div class="tree-item" style="padding-left: 16px;">
          <span>Pack &amp; Ship</span>
          <span style="margin-left: auto; font-size: 10px; color: var(--text-muted);">v1</span>
        </div>
      </div>
    </div>

    <div class="detail-area">
      <div class="detail-top">
        <div class="detail-panel">
          <div class="detail-header">
            Template Details
            <span style="font-size: 10px; color: var(--text-muted); font-weight: 400;">v2</span>
            <div class="detail-header-actions">
              <button class="btn btn-sm">Save</button>
              <button class="btn btn-sm">New Version</button>
              <button class="btn btn-sm btn-danger">Deprecate</button>
            </div>
          </div>
          <div class="detail-body">
            <div class="field-row">
              <div class="field">
                <div class="field-label">Code</div>
                <input class="field-value" value="DIE-CAST" readonly>
              </div>
              <div class="field">
                <div class="field-label">Name</div>
                <input class="field-value" value="Die Cast Operation">
              </div>
              <div class="field">
                <div class="field-label">Area</div>
                <select class="select" style="width: 100%;"><option selected>Die Cast</option><option>Trim Shop</option><option>Machine Shop</option></select>
              </div>
            </div>
            <div class="field">
              <div class="field-label">Description</div>
              <input class="field-value" value="Standard die cast production operation — collects die, cavity, weight, and counts.">
            </div>
          </div>
        </div>
      </div>

      <div class="detail-bottom">
        <div class="detail-panel">
          <div class="detail-header">
            Data Collection Fields
            <span style="font-size: 10px; color: var(--text-muted); font-weight: 400;">5 fields</span>
            <div class="detail-header-actions">
              <button class="btn btn-sm btn-primary">+ Add Field</button>
            </div>
          </div>
          <div style="overflow: auto;">
            <table class="data-table">
              <thead><tr><th style="width: 36px;"></th><th>Field</th><th style="width: 70px;">Required</th><th style="width: 60px;"></th></tr></thead>
              <tbody>
                <tr><td><div class="arrows"><button class="arrow-btn disabled">&#9650;</button><button class="arrow-btn">&#9660;</button></div></td><td>CollectsDieInfo</td><td style="text-align: center;"><span class="checkbox checked">&#9745;</span></td><td><button class="btn btn-sm btn-danger">Remove</button></td></tr>
                <tr><td><div class="arrows"><button class="arrow-btn">&#9650;</button><button class="arrow-btn">&#9660;</button></div></td><td>CollectsCavityInfo</td><td style="text-align: center;"><span class="checkbox checked">&#9745;</span></td><td><button class="btn btn-sm btn-danger">Remove</button></td></tr>
                <tr><td><div class="arrows"><button class="arrow-btn">&#9650;</button><button class="arrow-btn">&#9660;</button></div></td><td>CollectsWeight</td><td style="text-align: center;"><span class="checkbox checked">&#9745;</span></td><td><button class="btn btn-sm btn-danger">Remove</button></td></tr>
                <tr><td><div class="arrows"><button class="arrow-btn">&#9650;</button><button class="arrow-btn">&#9660;</button></div></td><td>CollectsGoodCount</td><td style="text-align: center;"><span class="checkbox checked">&#9745;</span></td><td><button class="btn btn-sm btn-danger">Remove</button></td></tr>
                <tr><td><div class="arrows"><button class="arrow-btn">&#9650;</button><button class="arrow-btn disabled">&#9660;</button></div></td><td>CollectsBadCount</td><td style="text-align: center;"><span class="checkbox">&#9744;</span></td><td><button class="btn btn-sm btn-danger">Remove</button></td></tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
```

- [ ] **Step 2: Add Quality Specs screen HTML**

Add after the Operation Templates screen div:

```html
<!-- Quality Specs -->
<div class="screen" id="screen-quality-specs">
  <div class="breadcrumb"><span>Quality</span><span class="sep">&rsaquo;</span><span>Quality Specs</span></div>
  <div class="title-row">
    <span class="title-text">Quality Specs</span>
    <div class="title-actions">
      <button class="btn btn-primary">+ New Spec</button>
    </div>
  </div>
  <div class="toast"></div>
  <div style="display: flex; flex: 1; overflow: hidden; border-top: 1px solid var(--border-default);">
    <div class="tree-panel">
      <div class="tree-search">
        <input class="search-input" placeholder="&#128269; Search specs...">
        <div style="margin-top: 6px;">
          <select class="select" style="width: 100%;"><option selected>All Items</option><option>5G0 Front Cover</option><option>RPY Assembly</option></select>
        </div>
      </div>
      <div class="tree-items">
        <div class="tree-item selected" style="padding-left: 10px;">
          <span>5G0 Dimensional Spec</span>
          <span class="badge badge-published" style="margin-left: auto;">v2</span>
        </div>
        <div class="tree-item" style="padding-left: 10px;">
          <span>5G0 Visual Inspection</span>
          <span class="badge badge-published" style="margin-left: auto;">v1</span>
        </div>
        <div class="tree-item" style="padding-left: 10px;">
          <span>RPY Assembly Check</span>
          <span class="badge badge-draft" style="margin-left: auto;">v1 Draft</span>
        </div>
      </div>
    </div>

    <div class="detail-area">
      <div class="detail-top">
        <div class="detail-panel">
          <div class="detail-header">
            Spec Details
            <div class="detail-header-actions">
              <button class="btn btn-sm">Save</button>
              <button class="btn btn-sm btn-danger">Deprecate</button>
            </div>
          </div>
          <div class="detail-body">
            <div class="field-row">
              <div class="field">
                <div class="field-label">Spec Name</div>
                <input class="field-value" value="5G0 Dimensional Spec">
              </div>
              <div class="field">
                <div class="field-label">Linked Item</div>
                <input class="field-value" value="5G0 — Front Cover Assembly" readonly>
              </div>
              <div class="field">
                <div class="field-label">Linked Operation</div>
                <input class="field-value" value="CNC Machining" readonly>
              </div>
            </div>
          </div>
        </div>
        <div class="version-selector" style="margin-top: 10px;">
          <select class="select">
            <option selected>v2 — Effective 2026-03-01 (Published)</option>
            <option>v1 — Effective 2025-06-01 (Deprecated)</option>
          </select>
          <span class="badge badge-published">Published</span>
          <button class="btn btn-sm">New Version</button>
        </div>
      </div>

      <div style="flex: 1; display: flex; flex-direction: column; overflow: hidden;" id="spec-tabs">
        <div class="tab-strip">
          <button class="tab-item active" data-tab="tab-spec-attrs" onclick="switchTab('spec-tabs','tab-spec-attrs')">Attributes</button>
          <button class="tab-item" data-tab="tab-spec-history" onclick="switchTab('spec-tabs','tab-spec-history')">Version History</button>
        </div>

        <div class="tab-content active" id="tab-spec-attrs" style="padding: 14px;">
          <div class="detail-panel">
            <div class="detail-header">
              Spec Attributes <span style="font-size: 10px; color: var(--text-muted); font-weight: 400;">3 attributes</span>
            </div>
            <div style="overflow: auto;">
              <table class="data-table">
                <thead><tr><th style="width: 36px;"></th><th>Attribute</th><th>Type</th><th>Target</th><th>Lower</th><th>Upper</th><th>UOM</th><th>Trigger</th></tr></thead>
                <tbody>
                  <tr>
                    <td><div class="arrows"><button class="arrow-btn disabled">&#9650;</button><button class="arrow-btn disabled">&#9660;</button></div></td>
                    <td>Surface Flatness</td><td>DECIMAL</td><td>0.002</td><td>0.001</td><td>0.003</td><td>in</td><td>FirstPiece</td>
                  </tr>
                  <tr>
                    <td><div class="arrows"><button class="arrow-btn disabled">&#9650;</button><button class="arrow-btn disabled">&#9660;</button></div></td>
                    <td>Bore Diameter</td><td>DECIMAL</td><td>25.40</td><td>25.38</td><td>25.42</td><td>mm</td><td>FirstPiece</td>
                  </tr>
                  <tr>
                    <td><div class="arrows"><button class="arrow-btn disabled">&#9650;</button><button class="arrow-btn disabled">&#9660;</button></div></td>
                    <td>Porosity Visual</td><td>PASS/FAIL</td><td>Pass</td><td>&mdash;</td><td>&mdash;</td><td>&mdash;</td><td>Hourly</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
          <div style="margin-top: 8px; font-size: 10px; color: var(--text-muted); font-style: italic;">
            &#128274; Published spec — read-only. Click "New Version" to create an editable draft.
          </div>
        </div>

        <div class="tab-content" id="tab-spec-history" style="padding: 14px;">
          <div class="detail-panel">
            <div class="detail-header">Version History</div>
            <div style="overflow: auto;">
              <table class="data-table">
                <thead><tr><th>Version</th><th>Effective</th><th>Status</th><th>Created By</th><th>Created</th></tr></thead>
                <tbody>
                  <tr class="selected"><td>v2</td><td>2026-03-01</td><td><span class="badge badge-published">Published</span></td><td>J. Potgieter</td><td>2026-02-28</td></tr>
                  <tr><td>v1</td><td>2025-06-01</td><td><span class="badge badge-deprecated">Deprecated</span></td><td>J. Potgieter</td><td>2025-05-15</td></tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
```

- [ ] **Step 3: Open in browser to verify**

Verify both screens:
- Parts > Operation Templates: grouped list by area, Die Cast Operation selected, 5 data collection fields with arrows + required toggles + remove buttons, no Publish button (clone-to-modify)
- Quality > Quality Specs: spec list filterable by item, Attributes + Version History tabs, Published spec shows read-only arrows

- [ ] **Step 4: Commit**

```bash
git add mockup/index.html
git commit -m "mockup: Operation Templates + Quality Specs screens"
```

---

## Task 6: List-Detail Screens — Defect Codes, Downtime Codes, Shift Schedules, Users

**Files:**
- Modify: `mockup/index.html`

Four screens using the same List-Detail pattern. Each has a filter panel on the left and a data table on the right.

- [ ] **Step 1: Add all four List-Detail screen HTML blocks**

Add after the Quality Specs screen div. Each screen follows the same structure: breadcrumb, title row, filter panel, data table. Here are all four:

```html
<!-- Defect Codes -->
<div class="screen" id="screen-defect-codes">
  <div class="breadcrumb"><span>Quality</span><span class="sep">&rsaquo;</span><span>Defect Codes</span></div>
  <div class="title-row">
    <span class="title-text">Defect Codes</span>
    <div class="title-actions"><button class="btn btn-primary">+ Add Code</button></div>
  </div>
  <div class="toast"></div>
  <div style="display: flex; flex: 1; overflow: hidden; border-top: 1px solid var(--border-default);">
    <div class="filter-panel">
      <div class="field"><div class="field-label">Area</div><select class="select" style="width: 100%;"><option selected>All Areas</option><option>Die Cast</option><option>Trim Shop</option><option>Machine Shop</option><option>Prod Control</option><option>Quality Control</option><option>HSP</option></select></div>
      <div class="field"><div class="field-label">Search</div><input class="search-input" placeholder="Code or description..."></div>
      <div class="field"><div class="field-label">Show Deprecated</div><div style="font-size: 11px; color: var(--text-muted); cursor: pointer;">&#9744; Include</div></div>
    </div>
    <div style="flex: 1; overflow: auto;">
      <table class="data-table">
        <thead><tr><th>Code</th><th>Description</th><th>Area</th><th>Excused</th><th style="width: 50px;"></th></tr></thead>
        <tbody>
          <tr><td>DC-0135</td><td>Porosity</td><td>Die Cast</td><td>&#9744;</td><td><button class="btn btn-sm">Edit</button></td></tr>
          <tr class="selected"><td>DC-0136</td><td>Cold Shut</td><td>Die Cast</td><td>&#9744;</td><td><button class="btn btn-sm">Edit</button></td></tr>
          <tr><td>DC-0137</td><td>Flash</td><td>Die Cast</td><td>&#9745;</td><td><button class="btn btn-sm">Edit</button></td></tr>
          <tr><td>DC-0138</td><td>Misrun</td><td>Die Cast</td><td>&#9744;</td><td><button class="btn btn-sm">Edit</button></td></tr>
          <tr><td>MS-0001</td><td>Dimensional (OOT)</td><td>Machine Shop</td><td>&#9744;</td><td><button class="btn btn-sm">Edit</button></td></tr>
          <tr><td>MS-0143</td><td>Surface Finish</td><td>Machine Shop</td><td>&#9744;</td><td><button class="btn btn-sm">Edit</button></td></tr>
          <tr><td>MS-0154</td><td>Tool Marks</td><td>Machine Shop</td><td>&#9744;</td><td><button class="btn btn-sm">Edit</button></td></tr>
          <tr><td>TS-0101</td><td>Burr — Trim</td><td>Trim Shop</td><td>&#9744;</td><td><button class="btn btn-sm">Edit</button></td></tr>
          <tr><td>HSP-0247</td><td>Vendor Defect — Dimensional</td><td>HSP</td><td>&#9744;</td><td><button class="btn btn-sm">Edit</button></td></tr>
        </tbody>
      </table>
    </div>
  </div>
</div>

<!-- Downtime Codes -->
<div class="screen" id="screen-downtime-codes">
  <div class="breadcrumb"><span>Operations</span><span class="sep">&rsaquo;</span><span>Downtime Codes</span></div>
  <div class="title-row">
    <span class="title-text">Downtime Codes</span>
    <div class="title-actions"><button class="btn btn-primary">+ Add Code</button></div>
  </div>
  <div class="toast"></div>
  <div style="display: flex; flex: 1; overflow: hidden; border-top: 1px solid var(--border-default);">
    <div class="filter-panel">
      <div class="field"><div class="field-label">Area</div><select class="select" style="width: 100%;"><option selected>All Areas</option><option>Die Cast</option><option>Machine Shop</option><option>Trim Shop</option></select></div>
      <div class="field"><div class="field-label">Reason Type</div><select class="select" style="width: 100%;"><option selected>All Types</option><option>Equipment</option><option>Mold</option><option>Quality</option><option>Setup</option><option>Miscellaneous</option><option>Unscheduled</option></select></div>
      <div class="field"><div class="field-label">Search</div><input class="search-input" placeholder="Code or description..."></div>
      <div class="field"><div class="field-label">Show Deprecated</div><div style="font-size: 11px; color: var(--text-muted); cursor: pointer;">&#9744; Include</div></div>
    </div>
    <div style="flex: 1; overflow: auto;">
      <table class="data-table">
        <thead><tr><th>Code</th><th>Description</th><th>Area</th><th>Type</th><th>Excused</th><th style="width: 50px;"></th></tr></thead>
        <tbody>
          <tr><td>DC-0001</td><td>Die Stuck</td><td>Die Cast</td><td>Equipment</td><td>&#9744;</td><td><button class="btn btn-sm">Edit</button></td></tr>
          <tr><td>DC-0002</td><td>Hydraulic Leak</td><td>Die Cast</td><td>Equipment</td><td>&#9744;</td><td><button class="btn btn-sm">Edit</button></td></tr>
          <tr class="selected"><td>DC-0015</td><td>Mold Change</td><td>Die Cast</td><td>Setup</td><td>&#9745;</td><td><button class="btn btn-sm">Edit</button></td></tr>
          <tr><td>DC-0030</td><td>Quality Hold — Line Stop</td><td>Die Cast</td><td>Quality</td><td>&#9744;</td><td><button class="btn btn-sm">Edit</button></td></tr>
          <tr><td>MS-0001</td><td>Tool Change</td><td>Machine Shop</td><td>Setup</td><td>&#9745;</td><td><button class="btn btn-sm">Edit</button></td></tr>
          <tr><td>MS-0010</td><td>Spindle Error</td><td>Machine Shop</td><td>Equipment</td><td>&#9744;</td><td><button class="btn btn-sm">Edit</button></td></tr>
          <tr><td>TS-0001</td><td>Trim Die Repair</td><td>Trim Shop</td><td>Mold</td><td>&#9744;</td><td><button class="btn btn-sm">Edit</button></td></tr>
        </tbody>
      </table>
    </div>
  </div>
</div>

<!-- Shift Schedules -->
<div class="screen" id="screen-shift-schedules">
  <div class="breadcrumb"><span>Operations</span><span class="sep">&rsaquo;</span><span>Shift Schedules</span></div>
  <div class="title-row">
    <span class="title-text">Shift Schedules</span>
    <div class="title-actions"><button class="btn btn-primary">+ Add Schedule</button></div>
  </div>
  <div class="toast"></div>
  <div style="display: flex; flex: 1; overflow: hidden; border-top: 1px solid var(--border-default);">
    <div style="flex: 1; overflow: auto; padding: 14px;">
      <table class="data-table">
        <thead><tr><th>Name</th><th>Start</th><th>End</th><th>Days</th><th>Effective</th><th style="width: 50px;"></th></tr></thead>
        <tbody>
          <tr class="selected">
            <td>First Shift</td><td>06:00</td><td>14:00</td>
            <td><div class="dow-visual"><span class="dow-day active">M</span><span class="dow-day active">T</span><span class="dow-day active">W</span><span class="dow-day active">T</span><span class="dow-day active">F</span><span class="dow-day inactive">S</span><span class="dow-day inactive">S</span></div></td>
            <td>2026-01-01</td><td><button class="btn btn-sm">Edit</button></td>
          </tr>
          <tr>
            <td>Second Shift</td><td>14:00</td><td>22:00</td>
            <td><div class="dow-visual"><span class="dow-day active">M</span><span class="dow-day active">T</span><span class="dow-day active">W</span><span class="dow-day active">T</span><span class="dow-day active">F</span><span class="dow-day inactive">S</span><span class="dow-day inactive">S</span></div></td>
            <td>2026-01-01</td><td><button class="btn btn-sm">Edit</button></td>
          </tr>
          <tr>
            <td>Weekend OT</td><td>06:00</td><td>16:00</td>
            <td><div class="dow-visual"><span class="dow-day inactive">M</span><span class="dow-day inactive">T</span><span class="dow-day inactive">W</span><span class="dow-day inactive">T</span><span class="dow-day inactive">F</span><span class="dow-day active">S</span><span class="dow-day active">S</span></div></td>
            <td>2026-01-01</td><td><button class="btn btn-sm">Edit</button></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</div>

<!-- Users -->
<div class="screen" id="screen-users">
  <div class="breadcrumb"><span>System</span><span class="sep">&rsaquo;</span><span>Users</span></div>
  <div class="title-row">
    <span class="title-text">Users</span>
    <div class="title-actions"><button class="btn btn-primary">+ Add User</button></div>
  </div>
  <div class="toast"></div>
  <div style="display: flex; flex: 1; overflow: hidden; border-top: 1px solid var(--border-default);">
    <div class="filter-panel">
      <div class="field"><div class="field-label">Search</div><input class="search-input" placeholder="Name or AD account..."></div>
      <div class="field"><div class="field-label">Show Deprecated</div><div style="font-size: 11px; color: var(--text-muted); cursor: pointer;">&#9744; Include</div></div>
    </div>
    <div style="flex: 1; overflow: auto;">
      <table class="data-table">
        <thead><tr><th>Display Name</th><th>AD Account</th><th>Clock #</th><th>Role</th><th style="width: 100px;"></th></tr></thead>
        <tbody>
          <tr class="selected"><td>J. Potgieter</td><td>jpotgieter@mpp.local</td><td>1042</td><td><span class="badge badge-type">Engineering</span></td><td><button class="btn btn-sm">Edit</button> <button class="btn btn-sm">PIN</button></td></tr>
          <tr><td>Bootstrap Admin</td><td>system.bootstrap</td><td>0001</td><td><span class="badge badge-type">Admin</span></td><td><button class="btn btn-sm">Edit</button> <button class="btn btn-sm">PIN</button></td></tr>
          <tr><td>Diane Martinez</td><td>dmartinez@mpp.local</td><td>2015</td><td><span class="badge" style="background: var(--status-warning-bg); color: var(--status-warning);">Quality</span></td><td><button class="btn btn-sm">Edit</button> <button class="btn btn-sm">PIN</button></td></tr>
          <tr><td>Carlos Reyes</td><td>creyes@mpp.local</td><td>3047</td><td><span class="badge" style="background: var(--bg-inset); color: var(--text-muted);">Operator</span></td><td><button class="btn btn-sm">Edit</button> <button class="btn btn-sm">PIN</button></td></tr>
        </tbody>
      </table>
    </div>
  </div>
</div>
```

- [ ] **Step 2: Open in browser to verify**

Navigate to each screen and verify:
- Quality > Defect Codes: filter panel, 9 sample rows, area/search/deprecated filters
- Operations > Downtime Codes: extra Reason Type filter, 7 sample rows
- Operations > Shift Schedules: days-of-week visual (MTWTF filled, SS unfilled for weekday shifts)
- System > Users: 4 users with role badges (Engineering blue, Admin blue, Quality amber, Operator gray), Edit + PIN buttons
- Theme toggle works on all screens

- [ ] **Step 3: Commit**

```bash
git add mockup/index.html
git commit -m "mockup: Defect Codes, Downtime Codes, Shift Schedules, Users screens"
```

---

## Task 7: Audit Log + Failure Log Screens

**Files:**
- Modify: `mockup/index.html`

Audit Log has expandable rows. Failure Log has dashboard tiles at the top.

- [ ] **Step 1: Add Audit Log and Failure Log screen HTML**

Add after the Users screen div:

```html
<!-- Audit Log -->
<div class="screen" id="screen-audit-log">
  <div class="breadcrumb"><span>System</span><span class="sep">&rsaquo;</span><span>Audit Log</span></div>
  <div class="title-row"><span class="title-text">Audit Log</span></div>
  <div style="display: flex; flex: 1; overflow: hidden; border-top: 1px solid var(--border-default);">
    <div class="filter-panel">
      <div class="field"><div class="field-label">Start Date</div><input class="field-value" type="date" value="2026-04-15"></div>
      <div class="field"><div class="field-label">End Date</div><input class="field-value" type="date" value="2026-04-16"></div>
      <div class="field"><div class="field-label">Entity Type</div><select class="select" style="width: 100%;"><option selected>All</option><option>Location</option><option>Item</option><option>Bom</option><option>RouteTemplate</option><option>OperationTemplate</option><option>QualitySpec</option><option>AppUser</option></select></div>
      <div class="field"><div class="field-label">User</div><select class="select" style="width: 100%;"><option selected>All Users</option><option>J. Potgieter</option><option>Bootstrap Admin</option></select></div>
      <div class="field"><div class="field-label">Search</div><input class="search-input" placeholder="Description..."></div>
    </div>
    <div style="flex: 1; overflow: auto;">
      <table class="data-table">
        <thead><tr><th>Timestamp</th><th>User</th><th>Entity Type</th><th>Entity</th><th>Event</th><th>Description</th></tr></thead>
        <tbody>
          <tr style="cursor: pointer;" onclick="this.nextElementSibling.classList.toggle('open')"><td>2026-04-16 09:42:15</td><td>J. Potgieter</td><td>Location</td><td>DC Machine #7</td><td>Updated</td><td>Tonnage changed from 350 to 400</td></tr>
          <tr class="expandable-detail"><td colspan="6"><div class="json-block">{ "OldValue": { "Tonnage": 350 }, "NewValue": { "Tonnage": 400 } }</div></td></tr>
          <tr style="cursor: pointer;" onclick="this.nextElementSibling.classList.toggle('open')"><td>2026-04-16 09:38:02</td><td>J. Potgieter</td><td>Item</td><td>5G0 Front Cover</td><td>Updated</td><td>UnitWeight changed from 3.15 to 3.25</td></tr>
          <tr class="expandable-detail"><td colspan="6"><div class="json-block">{ "OldValue": { "UnitWeight": 3.15 }, "NewValue": { "UnitWeight": 3.25 } }</div></td></tr>
          <tr><td>2026-04-16 09:30:00</td><td>J. Potgieter</td><td>RouteTemplate</td><td>5G0 Route v2</td><td>Created</td><td>New version created from v1</td></tr>
          <tr><td>2026-04-15 16:45:12</td><td>Bootstrap Admin</td><td>AppUser</td><td>D. Martinez</td><td>Created</td><td>User created with role Quality</td></tr>
          <tr><td>2026-04-15 14:22:01</td><td>J. Potgieter</td><td>OperationTemplate</td><td>Die Cast v2</td><td>Updated</td><td>Added CollectsWeight field</td></tr>
        </tbody>
      </table>
    </div>
  </div>
</div>

<!-- Failure Log -->
<div class="screen" id="screen-failure-log">
  <div class="breadcrumb"><span>System</span><span class="sep">&rsaquo;</span><span>Failure Log</span></div>
  <div class="title-row"><span class="title-text">Failure Log</span></div>
  <div style="display: flex; flex: 1; overflow: hidden; border-top: 1px solid var(--border-default);">
    <div class="filter-panel">
      <div class="field"><div class="field-label">Start Date</div><input class="field-value" type="date" value="2026-04-09"></div>
      <div class="field"><div class="field-label">End Date</div><input class="field-value" type="date" value="2026-04-16"></div>
      <div class="field"><div class="field-label">Entity Type</div><select class="select" style="width: 100%;"><option selected>All</option><option>Location</option><option>Item</option><option>Bom</option></select></div>
      <div class="field"><div class="field-label">Procedure</div><select class="select" style="width: 100%;"><option selected>All Procs</option><option>Location_Create</option><option>Item_Deprecate</option><option>Bom_Publish</option></select></div>
      <div class="field"><div class="field-label">Search</div><input class="search-input" placeholder="Failure reason..."></div>
    </div>
    <div style="flex: 1; overflow: auto; padding: 14px 14px 0;">
      <!-- Dashboard tiles -->
      <div class="dashboard-tiles">
        <div class="dashboard-tile">
          <h4>Top Rejection Reasons (7 days)</h4>
          <div class="tile-row"><span class="tile-row-label">Duplicate code exists</span><span class="tile-row-value">12</span></div>
          <div class="tile-bar"><div class="tile-bar-fill" style="width: 100%;"></div></div>
          <div class="tile-row" style="margin-top: 6px;"><span class="tile-row-label">Active dependents exist</span><span class="tile-row-value">8</span></div>
          <div class="tile-bar"><div class="tile-bar-fill" style="width: 67%;"></div></div>
          <div class="tile-row" style="margin-top: 6px;"><span class="tile-row-label">Required parameter missing</span><span class="tile-row-value">5</span></div>
          <div class="tile-bar"><div class="tile-bar-fill" style="width: 42%;"></div></div>
        </div>
        <div class="dashboard-tile">
          <h4>Top Failing Procedures (7 days)</h4>
          <div class="tile-row"><span class="tile-row-label">Location.Location_Create</span><span class="tile-row-value">9</span></div>
          <div class="tile-bar"><div class="tile-bar-fill" style="width: 100%;"></div></div>
          <div class="tile-row" style="margin-top: 6px;"><span class="tile-row-label">Parts.Item_Deprecate</span><span class="tile-row-value">7</span></div>
          <div class="tile-bar"><div class="tile-bar-fill" style="width: 78%;"></div></div>
          <div class="tile-row" style="margin-top: 6px;"><span class="tile-row-label">Parts.Bom_Publish</span><span class="tile-row-value">4</span></div>
          <div class="tile-bar"><div class="tile-bar-fill" style="width: 44%;"></div></div>
        </div>
      </div>

      <!-- Failure table -->
      <table class="data-table">
        <thead><tr><th>Timestamp</th><th>User</th><th>Entity</th><th>Procedure</th><th>Failure Reason</th></tr></thead>
        <tbody>
          <tr style="cursor: pointer;" onclick="this.nextElementSibling.classList.toggle('open')"><td>2026-04-16 09:44:30</td><td>J. Potgieter</td><td>Location</td><td>Location_Create</td><td>A location with this Code already exists.</td></tr>
          <tr class="expandable-detail"><td colspan="5"><div class="json-block">{ "Code": "DC-007", "Name": "DC Machine #7 duplicate", "ParentLocationId": 3 }</div></td></tr>
          <tr style="cursor: pointer;" onclick="this.nextElementSibling.classList.toggle('open')"><td>2026-04-16 09:40:12</td><td>J. Potgieter</td><td>Item</td><td>Item_Deprecate</td><td>Cannot deprecate: active RouteTemplate references exist.</td></tr>
          <tr class="expandable-detail"><td colspan="5"><div class="json-block">{ "ItemId": 1, "ActiveDependents": ["RouteTemplate v2", "Bom v1"] }</div></td></tr>
          <tr><td>2026-04-15 16:50:00</td><td>Bootstrap Admin</td><td>Location</td><td>Location_Create</td><td>Required parameter missing.</td></tr>
          <tr><td>2026-04-15 11:22:33</td><td>J. Potgieter</td><td>Bom</td><td>Bom_Publish</td><td>Cannot publish: BOM has no lines.</td></tr>
        </tbody>
      </table>
    </div>
  </div>
</div>
```

- [ ] **Step 2: Open in browser to verify**

Verify:
- System > Audit Log: date pickers, entity/user filters, expandable rows (click first two rows to see JSON diff)
- System > Failure Log: two dashboard tiles with bar charts (Top Reasons, Top Procs), filterable failure table with expandable parameter JSON
- Theme toggle renders both correctly in dark mode

- [ ] **Step 3: Commit**

```bash
git add mockup/index.html
git commit -m "mockup: Audit Log + Failure Log screens with expandable rows and dashboard tiles"
```

---

## Task 8: Modals — Add Location, Location Type Def Editor, Add Item

**Files:**
- Modify: `mockup/index.html`

Add modal overlays before the closing `</div>` of the `.app` container.

- [ ] **Step 1: Add modal HTML**

Add before the closing `</div>` of the `.app` div (i.e., just before the `<script>` tag):

```html
<!-- Modal: Add Location -->
<div class="modal-overlay" id="modal-add-location">
  <div class="modal">
    <div class="modal-header">Add Location <button class="close-btn" onclick="closeModal('modal-add-location')">&times;</button></div>
    <div class="modal-body">
      <div class="field">
        <div class="field-label">Location Type Definition</div>
        <select class="select" style="width: 100%;"><option>Select...</option><option>DieCastMachine (Cell)</option><option>CNCMachine (Cell)</option><option>TrimPress (Cell)</option><option>Terminal (Cell)</option><option>InventoryLocation (Cell)</option><option>ProductionLine (WorkCenter)</option></select>
      </div>
      <div class="field-row">
        <div class="field"><div class="field-label">Name</div><input class="field-value" placeholder="e.g., DC Machine #20"></div>
        <div class="field"><div class="field-label">Code</div><input class="field-value" placeholder="e.g., DC-020"></div>
      </div>
      <div class="field"><div class="field-label">Description</div><input class="field-value" placeholder="Optional description"></div>
    </div>
    <div class="modal-footer">
      <button class="btn" onclick="closeModal('modal-add-location')">Cancel</button>
      <button class="btn btn-primary" onclick="closeModal('modal-add-location')">Create Location</button>
    </div>
  </div>
</div>

<!-- Modal: Location Type Definition Editor -->
<div class="modal-overlay" id="modal-loc-type-editor">
  <div class="modal modal-lg">
    <div class="modal-header">Location Type Definitions <button class="close-btn" onclick="closeModal('modal-loc-type-editor')">&times;</button></div>
    <div class="modal-body">
      <div style="margin-bottom: 12px; font-size: 11px; color: var(--text-muted);">
        Define the kinds of locations and their attribute schemas. Changes here affect all locations of each type.
      </div>

      <div class="detail-panel" style="margin-bottom: 12px;">
        <div class="detail-header">Cell Types <span style="font-size: 10px; color: var(--text-muted); font-weight: 400;">(ISA-95 tier: Cell)</span></div>
        <div style="overflow: auto;">
          <table class="data-table">
            <thead><tr><th>Code</th><th>Name</th><th>Attributes</th><th style="width: 50px;"></th></tr></thead>
            <tbody>
              <tr class="selected"><td>DieCastMachine</td><td>Die Cast Machine</td><td style="font-size: 10px; color: var(--text-muted);">Tonnage, NumberOfCavities, RefCycleTimeSec</td><td><button class="btn btn-sm">Edit</button></td></tr>
              <tr><td>CNCMachine</td><td>CNC Machine</td><td style="font-size: 10px; color: var(--text-muted);">SpindleCount, CoolantType</td><td><button class="btn btn-sm">Edit</button></td></tr>
              <tr><td>TrimPress</td><td>Trim Press</td><td style="font-size: 10px; color: var(--text-muted);">Tonnage</td><td><button class="btn btn-sm">Edit</button></td></tr>
              <tr><td>Terminal</td><td>Operator Terminal</td><td style="font-size: 10px; color: var(--text-muted);">IpAddress, DefaultPrinter, HasBarcodeScanner</td><td><button class="btn btn-sm">Edit</button></td></tr>
              <tr><td>InventoryLocation</td><td>Inventory Location</td><td style="font-size: 10px; color: var(--text-muted);">IsPhysical, IsLineside, MaxLotCapacity</td><td><button class="btn btn-sm">Edit</button></td></tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="detail-panel">
        <div class="detail-header">Area Types <span style="font-size: 10px; color: var(--text-muted); font-weight: 400;">(ISA-95 tier: Area)</span></div>
        <div style="overflow: auto;">
          <table class="data-table">
            <thead><tr><th>Code</th><th>Name</th><th>Attributes</th><th style="width: 50px;"></th></tr></thead>
            <tbody>
              <tr><td>ProductionArea</td><td>Production Area</td><td style="font-size: 10px; color: var(--text-muted);">(none)</td><td><button class="btn btn-sm">Edit</button></td></tr>
              <tr><td>SupportArea</td><td>Support Area</td><td style="font-size: 10px; color: var(--text-muted);">(none)</td><td><button class="btn btn-sm">Edit</button></td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    <div class="modal-footer">
      <button class="btn" onclick="closeModal('modal-loc-type-editor')">Close</button>
    </div>
  </div>
</div>

<!-- Modal: Add Item -->
<div class="modal-overlay" id="modal-add-item">
  <div class="modal">
    <div class="modal-header">Add Item <button class="close-btn" onclick="closeModal('modal-add-item')">&times;</button></div>
    <div class="modal-body">
      <div class="field-row">
        <div class="field"><div class="field-label">Part Number *</div><input class="field-value" placeholder="e.g., 5G0"></div>
        <div class="field"><div class="field-label">Item Type *</div><select class="select" style="width: 100%;"><option>Select...</option><option>Raw Material</option><option>Component</option><option>Sub-Assembly</option><option>Finished Good</option><option>Pass-Through</option></select></div>
      </div>
      <div class="field"><div class="field-label">Description *</div><input class="field-value" placeholder="Item description"></div>
      <div class="field-row">
        <div class="field"><div class="field-label">UOM *</div><select class="select" style="width: 100%;"><option selected>EA</option><option>LB</option><option>KG</option></select></div>
        <div class="field"><div class="field-label">Unit Weight</div><input class="field-value" placeholder="0.00"></div>
        <div class="field"><div class="field-label">Weight UOM</div><select class="select" style="width: 100%;"><option>LB</option><option>KG</option></select></div>
      </div>
      <div class="field-row">
        <div class="field"><div class="field-label">Default Sub-LOT Qty</div><input class="field-value" placeholder="24"></div>
        <div class="field"><div class="field-label">Max LOT Size</div><input class="field-value" placeholder="100"></div>
        <div class="field"><div class="field-label">Macola Part #</div><input class="field-value" placeholder="Optional"></div>
      </div>
    </div>
    <div class="modal-footer">
      <button class="btn" onclick="closeModal('modal-add-item')">Cancel</button>
      <button class="btn btn-primary" onclick="closeModal('modal-add-item')">Create Item</button>
    </div>
  </div>
</div>
```

- [ ] **Step 2: Open in browser to verify**

Verify:
- Plant Hierarchy > "+ Add Location": modal opens with Definition dropdown, Name, Code, Description. Cancel/Create buttons. Backdrop click or X closes it.
- Plant Hierarchy > gear icon: Location Type Definition Editor opens as a large modal. Two grouped tables (Cell Types, Area Types) with Edit buttons.
- Item Master > "+ Add Item": modal opens with PartNumber, ItemType, Description, UOM, weights, sub-lot qty, max lot size, Macola ref.
- All modals close on X click and Cancel click
- Dark mode renders modals correctly (dark surface, correct borders)

- [ ] **Step 3: Commit**

```bash
git add mockup/index.html
git commit -m "mockup: modals — Add Location, Location Type Def Editor, Add Item"
```

---

## Task 9: Final Polish — Close `</body>`, Verify All Screens, Clean Up

**Files:**
- Modify: `mockup/index.html`

Ensure the file is properly closed and all screens are reachable.

- [ ] **Step 1: Verify the file ends correctly**

Ensure the file ends with:
```html
</script>
</body>
</html>
```

- [ ] **Step 2: Full walkthrough verification**

Open `mockup/index.html` and verify every screen:

1. **Landing:** Shows "Select a category to begin" with icon
2. **Rail:** 5 icons visible, clicking toggles nav panel, clicking same icon collapses
3. **Theme toggle:** Moon/sun switches all screens between light and dark
4. **Plant > Plant Hierarchy:** Tree, details, attributes with arrows, + Add Location modal, gear icon modal
5. **Parts > Item Master:** Item list, details, 5 tabs all switching correctly, Published routes/BOMs read-only
6. **Parts > Operation Templates:** Grouped by area, data collection fields with arrows
7. **Quality > Quality Specs:** Filterable by item, Attributes + Version History tabs
8. **Quality > Defect Codes:** Filter panel, table with edit buttons
9. **Operations > Downtime Codes:** Filter by area + type, table
10. **Operations > Shift Schedules:** Days-of-week visual, edit buttons
11. **System > Users:** Role badges, Edit + PIN buttons
12. **System > Audit Log:** Expandable rows with JSON diff
13. **System > Failure Log:** Dashboard tiles + expandable failure rows

- [ ] **Step 3: Commit**

```bash
git add mockup/index.html
git commit -m "mockup: final polish and verification of all 10 screens"
```

---

## Self-Review

**Spec coverage check:**
- Section 2 (Page Shell): Covered by Tasks 1-2 ✓
- Section 3 (Layout Patterns): Tree-Detail in Tasks 3-5, List-Detail in Task 6, Builder embedded in Tasks 3-5 ✓
- Section 4.1 (Plant Hierarchy): Task 3 ✓
- Section 4.2 (Item Master): Task 4 ✓
- Section 4.3 (Operation Templates): Task 5 ✓
- Section 4.4 (Quality Specs): Task 5 ✓
- Section 4.5 (Defect Codes): Task 6 ✓
- Section 4.6 (Downtime Codes): Task 6 ✓
- Section 4.7 (Shift Schedules): Task 6 ✓
- Section 4.8 (Users): Task 6 ✓
- Section 4.9 (Audit Log): Task 7 ✓
- Section 4.10 (Failure Log): Task 7 ✓
- Section 5.1 (Versioned lifecycle): Shown in Item Master Routes/BOMs (Published read-only) and Quality Specs ✓
- Section 5.2 (Modals): Task 8 ✓
- Section 5.3 (Up/Down arrows): Present in Plant Hierarchy, Operation Templates, and Route/BOM builders ✓
- Section 5.4 (Breadcrumbs): Present on all screens ✓
- Section 5.5 (Toast notifications): Wired on Plant Hierarchy and Item Master saves ✓
- Section 6 (Sample data): Realistic MPP data on all screens ✓
- Section 7 (Perspective notes): Documented in spec, not in mockup — correct ✓
- Section 8 (Out of scope): Verified — no plant floor screens, no Reference Data Manager, no OPC Tags ✓

**Placeholder scan:** No TBDs, TODOs, or "fill in later" markers found.

**Type/name consistency:** `toggleCategory()`, `navigateTo()`, `switchTab()`, `openModal()`, `closeModal()`, `toggleTheme()`, `showToast()` — all used consistently across HTML onclick attributes and JS definitions.
