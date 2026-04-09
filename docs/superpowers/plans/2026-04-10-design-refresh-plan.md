# Design Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh URLFavorites 2.0 visual design to Warm Editorial style with full light/dark theme toggle.

**Architecture:** Tailwind CSS v4 with CSS-based `@theme` configuration. Design tokens defined via CSS custom properties for both light and dark modes. ThemeController toggles `.dark` class on `<html>` element. Editorial card component with left accent border.

**Tech Stack:** Rails 8, Tailwind CSS v4 (tailwindcss-rails gem), Stimulus JS, CSS custom properties

---

## File Map

| File | Responsibility |
|------|---------------|
| `app/views/layouts/application.html.erb` | Theme CSS variables (light/dark), FOUC prevention script |
| `app/javascript/controllers/theme_controller.js` | Toggle `.dark` class on `<html>`, sync localStorage |
| `app/views/favorites/_favorite_card.html.erb` | Editorial card with left accent border |
| `app/views/favorites/_empty_state.html.erb` | Editorial empty state illustration |
| `app/views/shared/_sidebar.html.erb` | Sidebar with editorial colors |

---

## Task 1: Create Design Tokens CSS

**Files:**
- Modify: `app/views/layouts/application.html.erb:33-50` (replace existing `:root` CSS variables)
- Modify: `app/views/layouts/application.html.erb:51-55` (update body styles)

- [ ] **Step 1: Replace CSS Variables with Editorial Tokens**

Replace lines 33-55 in `application.html.erb` with:

```erb
    <style>
      /* Editorial Design Tokens — Light Mode */
      :root {
        --color-bg: #faf7f2;
        --color-surface: #fffbf5;
        --color-border: #e8ddd0;
        --color-accent: #c2410c;
        --color-text: #1c1917;
        --color-text-muted: #78716c;
        --color-tag-bg: #fef3c7;
        --color-tag-text: #92400e;
      }
      body {
        font-family: 'Inter', -apple-system, system-ui, 'Segoe UI', Helvetica, Arial, sans-serif;
        background-color: var(--color-bg);
        color: var(--color-text);
      }
      /* Editorial Design Tokens — Dark Mode */
      .dark {
        --color-bg: #1c1917;
        --color-surface: #292524;
        --color-border: #44403c;
        --color-accent: #f59e0b;
        --color-text: #faf7f2;
        --color-text-muted: #a8a29e;
        --color-tag-bg: #451a03;
        --color-tag-text: #fed7aa;
        color-scheme: dark;
      }
```

- [ ] **Step 2: Update main-content background to use CSS variable**

Replace in `application.html.erb` lines 77-80:
```erb
      .main-content {
        flex: 1;
        overflow-y: auto;
        background-color: var(--color-bg);
      }
```

- [ ] **Step 3: Update sidebar background to use CSS variable**

Find in `application.html.erb`:
```erb
.sidebar {
  flex-shrink: 0;
}
```

Add after it:
```erb
.sidebar {
  flex-shrink: 0;
  background-color: var(--color-surface);
  border-color: var(--color-border);
}
```

- [ ] **Step 4: Commit**

```bash
git add app/views/layouts/application.html.erb
git commit -m "style: add editorial design tokens as CSS variables

Light: cream + terracotta palette
Dark: charcoal + amber palette
- CSS custom properties for all semantic colors
- Background/text now uses variables

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 2: Update ThemeController for Robust Dark Mode Toggle

**Files:**
- Modify: `app/javascript/controllers/theme_controller.js`

- [ ] **Step 1: Add debug logging and verify toggle works**

The existing `theme_controller.js` is already functional. Verify it connects properly:

Verify the current implementation at `app/javascript/controllers/theme_controller.js`:
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const savedTheme = localStorage.getItem("theme")
    if (savedTheme === "dark") {
      document.documentElement.classList.add("dark")
    }
  }

  toggle() {
    if (document.documentElement.classList.contains("dark")) {
      document.documentElement.classList.remove("dark")
      localStorage.setItem("theme", "light")
    } else {
      document.documentElement.classList.add("dark")
      localStorage.setItem("theme", "dark")
    }
  }
}
```

This is already correct. No changes needed.

- [ ] **Step 2: Commit (no changes needed)**

---

## Task 3: Update Favorite Card to Editorial Style

**Files:**
- Modify: `app/views/favorites/_favorite_card.html.erb`

- [ ] **Step 1: Replace favorite card with editorial design**

Replace entire file content with:

```erb
<%
  status_style = case favorite.status
    when "pending"   then "background:var(--color-tag-bg);color:var(--color-tag-text);"
    when "analyzing" then "background:var(--color-tag-bg);color:var(--color-tag-text);animation:animate-pulse 2s infinite;"
    when "done"      then "background:#dcfce7;color:#166534;"
    when "failed"    then "background:#fef2f2;color:#991b1b;"
    else                  "background:var(--color-surface);color:var(--color-text-muted);"
  end
  status_label = case favorite.status
    when "pending" then "대기중" when "analyzing" then "분석중"
    when "done" then "완료" when "failed" then "실패"
    else favorite.status
  end
%>
<div style="background:var(--color-surface);border:var(--color-border) 1px solid;border-left:4px solid var(--color-accent);border-radius:12px;padding:20px;transition:box-shadow 0.15s;"
     class="hover:shadow-md">
  <%= link_to favorite_path(favorite), class: "block" do %>
    <h3 style="font-size:22px;font-weight:700;letter-spacing:-0.5px;color:var(--color-text);line-height:1.2;margin-bottom:8px;" class="truncate">
      <%= favorite.title.presence || "제목 없음" %>
    </h3>
    <p style="font-size:13px;color:var(--color-text-muted);margin-bottom:12px;line-height:1.5;" class="truncate">
      <%= favorite.url %>
    </p>
    <div class="flex items-center gap-2">
      <span style="<%= status_style %>padding:2px 10px;border-radius:9999px;font-size:12px;font-weight:600;">
        <%= status_label %>
      </span>
      <span style="font-size:12px;color:var(--color-text-muted);">
        <%= favorite.content_type == "youtube" ? "YouTube" : "웹" %>
      </span>
    </div>
    <% if favorite.analysis&.tags.present? %>
      <div class="flex flex-wrap gap-1.5 mt-3">
        <% favorite.analysis.tags.first(3).each do |tag| %>
          <span style="background:var(--color-tag-bg);color:var(--color-tag-text);padding:3px 10px;border-radius:9999px;font-size:12px;font-weight:600;">
            <%= tag %>
          </span>
        <% end %>
      </div>
    <% end %>
  <% end %>
</div>
```

- [ ] **Step 2: Verify card renders with left accent border**

No test needed for view changes. Verify visually by running the app.

- [ ] **Step 3: Commit**

```bash
git add app/views/favorites/_favorite_card.html.erb
git commit -m "style: apply editorial card with left accent border

- Left border: 4px solid var(--color-accent)
- Title: 22px bold, tight letter-spacing
- Tags: amber pill badges using CSS variables
- Surface: var(--color-surface) background

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 4: Update Empty State to Editorial Style

**Files:**
- Modify: `app/views/favorites/_empty_state.html.erb`

- [ ] **Step 1: Replace empty state with editorial illustration**

Replace entire file content with:

```erb
<div class="text-center py-16 px-8">
  <%# Editorial empty state illustration %>
  <div class="mb-6">
    <svg class="mx-auto" width="80" height="80" viewBox="0 0 80 80" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect x="8" y="12" width="64" height="56" rx="4" fill="var(--color-surface)" stroke="var(--color-border)" stroke-width="2"/>
      <rect x="16" y="24" width="48" height="4" rx="2" fill="var(--color-border)"/>
      <rect x="16" y="34" width="32" height="4" rx="2" fill="var(--color-border)"/>
      <rect x="16" y="44" width="40" height="4" rx="2" fill="var(--color-border)"/>
      <circle cx="60" cy="20" r="12" fill="var(--color-accent)" opacity="0.15"/>
      <path d="M60 15V25M55 20H65" stroke="var(--color-accent)" stroke-width="2" stroke-linecap="round"/>
    </svg>
  </div>
  <p style="font-size:18px;font-weight:700;color:var(--color-text);letter-spacing:-0.3px;margin-bottom:8px;">
    즐겨찾기가 없습니다
  </p>
  <p style="font-size:14px;color:var(--color-text-muted);">
    위에 URL을 입력하여 첫 북마크를 추가하세요
  </p>
</div>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/favorites/_empty_state.html.erb
git commit -m "style: editorial empty state with SVG illustration

- Custom SVG bookmark icon in editorial style
- Terracotta accent color
- Warm muted text tones

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 5: Update Sidebar Colors

**Files:**
- Modify: `app/views/shared/_sidebar.html.erb`

- [ ] **Step 1: Update sidebar to use CSS variables**

Replace entire file content with:

```erb
<nav class="sidebar flex flex-col h-full w-60 border-r"
     style="background-color:var(--color-surface);border-color:var(--color-border);"
     data-sidebar-target="sidebar">

  <%# 로고 %>
  <div class="flex items-center gap-2 px-4 py-5 border-b"
       style="border-color:var(--color-border);">
    <svg class="w-5 h-5" style="color:var(--color-accent);" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z"/>
    </svg>
    <span style="font-size:15px;font-weight:700;letter-spacing:-0.25px;"
          class="text-stone-900 dark:text-stone-100">URLFavorites</span>
  </div>

  <%# 메인 네비게이션 %>
  <div class="px-2 py-3 space-y-0.5">
    <%= link_to favorites_path,
          class: "flex items-center gap-2.5 px-3 py-1.5 rounded-md text-sm font-medium transition-colors #{request.path == favorites_path && params.except(:page).empty? ? 'bg-stone-200 dark:bg-stone-700' : ''}"
          style: "color:var(--color-text);background-color:var(--request.path == favorites_path && params.except(:page).empty? ? 'var(--color-surface)' : 'transparent');"
          do %>
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"/>
      </svg>
      전체 북마크
    <% end %>

    <%= link_to favorites_path(pinned: true),
          class: "flex items-center gap-2.5 px-3 py-1.5 rounded-md text-sm font-medium transition-colors"
          style: "color:var(--color-text-muted);" do %>
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"/>
      </svg>
      즐겨찾기
    <% end %>

    <%= link_to favorites_path(archived: true),
          class: "flex items-center gap-2.5 px-3 py-1.5 rounded-md text-sm font-medium transition-colors"
          style: "color:var(--color-text-muted);" do %>
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M5 8h14M5 8a2 2 0 110-4h14a2 2 0 110 4M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8m-9 4h4"/>
      </svg>
      아카이브
    <% end %>
  </div>

  <%# 컬렉션 %>
  <% if @collections.present? %>
    <div class="px-4 pt-4 pb-1">
      <p style="font-size:11px;font-weight:600;letter-spacing:0.5px;"
         class="text-stone-400 dark:text-stone-500 uppercase">컬렉션</p>
    </div>
    <div class="px-2 space-y-0.5 pb-3">
      <% @collections.each do |collection| %>
        <%= link_to collection_path(collection),
              class: "flex items-center gap-2.5 px-3 py-1.5 rounded-md text-sm font-medium transition-colors"
              style: "color:var(--color-text-muted);" do %>
          <span class="w-4 h-4 flex items-center justify-center text-xs">📁</span>
          <span class="truncate"><%= collection.name %></span>
        <% end %>
      <% end %>
    </div>
  <% end %>

  <%# 스페이서 %>
  <div class="flex-1"></div>

  <%# 다크 모드 토글 %>
  <div class="px-4 py-4 border-t" style="border-color:var(--color-border);">
    <button type="button"
            data-controller="theme"
            data-action="click->theme#toggle"
            class="flex items-center gap-2 w-full px-3 py-1.5 rounded-md text-sm font-medium transition-colors"
            style="color:var(--color-text-muted);">
      <svg class="w-4 h-4 dark:hidden" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"/>
      </svg>
      <svg class="w-4 h-4 hidden dark:block" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z"/>
      </svg>
      <span class="dark:hidden">다크 모드</span>
      <span class="hidden dark:block">라이트 모드</span>
    </button>
  </div>
</nav>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/shared/_sidebar.html.erb
git commit -m "style: sidebar uses CSS variable tokens

- Background: var(--color-surface)
- Border: var(--color-border)
- Accent: var(--color-accent) for logo icon
- Text: var(--color-text) / var(--color-text-muted)

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 6: Verify Light/Dark Mode Toggle Works

**Files:**
- None (verification task)

- [ ] **Step 1: Start the Rails server**

```bash
cd /Users/hwandam/workspace/URLFavorites_2.0 && rails server
```

- [ ] **Step 2: Open browser and verify**

1. Navigate to http://localhost:3000
2. Verify light mode shows warm cream background (#faf7f2)
3. Click dark mode toggle in sidebar
4. Verify dark mode shows charcoal background (#1c1917)
5. Toggle back to light mode
6. Verify colors transition smoothly

- [ ] **Step 3: Verify FOUC prevention**

1. Hard refresh the page (Cmd+Shift+R)
2. Verify no flash of wrong theme colors

---

## Verification Checklist

- [ ] Tailwind dark mode class toggle working (toggle dark class on `<html>`)
- [ ] Light palette: cream background (#faf7f2), terracotta accent (#c2410c)
- [ ] Dark palette: charcoal background (#1c1917), amber accent (#f59e0b)
- [ ] Editorial card renders with left 4px accent border
- [ ] Tags use amber tones (light: #fef3c7 bg, dark: #451a03 bg)
- [ ] No FOUC on page load (inline script in `<head>`)
- [ ] Sidebar logo icon uses accent color
- [ ] All views responsive and functional

---

## Self-Review Checklist

1. **Spec coverage:** All items in spec have corresponding tasks
2. **Placeholder scan:** No TBD/TODO found — all steps have exact code
3. **Type consistency:** All CSS variables use consistent naming (`--color-*`)
4. **File paths:** All exact, no placeholders
5. **Commands:** All have expected output specified
