# URLFavorites 2.0 — Design Refresh Spec

**Date:** 2026-04-10
**Status:** Draft
**Author:** Brainstorming Session

---

## 1. 개요 (Summary)

URLFavorites 2.0의 비주얼 스타일을刷新한다. Notion-inspired에서 **에디토리얼/퍼블리케이션 스타일**로 전환하고, Tailwind 기반 완전한 라이트/다크 테마 시스템을 구축한다.

---

## 2. Design Language

### Visual Style: Warm Editorial

출판물/잡지 스타일. 고유한 개성, 명시적 hierarchy, intentional spacing.

### Color Palette

#### Light Mode (Primary)
```
Background:    #faf7f2 (warm cream)
Surface:       #fffbf5 (soft cream)
Border:        #e8ddd0 (warm taupe)
Accent:         #c2410c (terracotta/burnt orange)
Text Primary:   #1c1917 (warm black)
Text Secondary: #78716c (warm gray)
Tag BG:         #fef3c7 (amber tint)
Tag Text:       #92400e (amber dark)
```

#### Dark Mode (Secondary)
```
Background:    #1c1917 (charcoal)
Surface:       #292524 (dark stone)
Border:        #44403c (stone border)
Accent:         #f59e0b (amber gold)
Text Primary:   #faf7f2 (cream)
Text Secondary: #a8a29e (muted stone)
Tag BG:         #451a03 (deep amber)
Tag Text:       #fed7aa (amber light)
```

### Typography
- **Font:** Inter (기존 유지)
- **Headings:** Large, bold, tight letter-spacing
- **Body:** Readable, comfortable line-height

### Component Style: Editorial Card
- 좌측 4px accent border (terracotta light / amber dark)
- 대형 타이틀 + 상세 URL description
- 태그: pill 형태, amber tones

---

## 3. Implementation Plan

### 3.1 Tailwind Config 확장
```js
// tailwind.config.js
module.exports = {
  darkMode: 'class',  // class-based dark mode
  theme: {
    extend: {
      colors: {
        // Light palette
        cream: { DEFAULT: '#faf7f2', surface: '#fffbf5' },
        taupe: { border: '#e8ddd0' },
        terracotta: { DEFAULT: '#c2410c', hover: '#9a3412' },
        // Dark palette
        charcoal: { DEFAULT: '#1c1917', surface: '#292524' },
        amber: { DEFAULT: '#f59e0b', muted: '#fed7aa' },
        // Shared
        stone: { muted: '#a8a29e' },
        amber: { tag: { bg: '#fef3c7', text: '#92400e', dark: { bg: '#451a03', text: '#fed7aa' } } }
      }
    }
  }
}
```

### 3.2 CSS Variables (Fallback)
```css
:root {
  --color-bg: #faf7f2;
  --color-surface: #fffbf5;
  --color-border: #e8ddd0;
  --color-accent: #c2410c;
  --color-text: #1c1917;
  --color-text-muted: #78716c;
}
.dark {
  --color-bg: #1c1917;
  --color-surface: #292524;
  --color-border: #44403c;
  --color-accent: #f59e0b;
  --color-text: #faf7f2;
  --color-text-muted: #a8a29e;
}
```

### 3.3 Theme Toggle
- ThemeController 수정 (기존 theme_controller.js 활용)
- localStorage에 `'theme': 'dark'|'light'` 저장
- `dark:` class를 `<html>`에 토글

### 3.4 Component Updates

#### Favorite Card
- 좌측 border-left: 4px solid var(--color-accent)
- Title: 22px bold, tight letter-spacing
- URL desc: 13px, muted color, 2줄까지
- Tags: amber pill badges

#### Empty State
- 에디토리얼 느낌의 일러스트레이션
- 크림/다크 배경에 어울리는 그래픽

#### Sidebar
- Light: cream bg, terracotta active indicator
- Dark: charcoal bg, amber active indicator

### 3.5 Files to Modify
```
tailwind.config.js          — 새 palette + darkMode: 'class'
app/assets/stylesheets/app.css  — CSS variables (fallback)
app/views/layouts/application.html.erb — theme init script
app/javascript/controllers/theme_controller.js — 다크 모드 토글
app/views/favorites/_favorite_card.html.erb — 에디토리얼 카드
app/views/favorites/_empty_state.html.erb — 새 empty state
app/views/shared/_sidebar.html.erb — 새 sidebar 스타일
```

---

## 4. Verification Criteria

- [ ] Tailwind dark mode class toggle working
- [ ] Both palettes (light/dark) match spec colors
- [ ] Editorial card renders with left accent border
- [ ] Tags use amber tones consistently
- [ ] No FOUC (flash of unstyled content) on page load
- [ ] All views responsive and functional

---

## 5. Out of Scope (This Phase)

- Animation/interaction polish (separate phase)
- Card layout grid changes
- PWA icon/theme-color updates (separate)

---

## 6. Success Criteria

사용자가 브라우저에서 URLFavorites를 열고 "어디서 많이 봤던 잡지 같은 интерфейс"라는 인상을 받으면 성공.
