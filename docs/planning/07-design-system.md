# 07 — 디자인 시스템

## 디자인 방향

**에디토리얼/매거진 스타일**

Medium, 브런치, Notion과 같이 텍스트 위계와 레이아웃 리듬감에 집중.
콘텐츠가 주인공이고 UI는 조용히 뒤로 빠지는 방식.

**핵심 특성**
- 타이포그래피 강조: 제목과 본문의 명확한 위계
- 여백의 리듬감: 균일한 padding이 아닌 의도적인 공간
- 미니멀 크롬: 버튼, 테두리, 그림자를 최소화
- 콘텐츠 집중: 카드 안에 정보 밀도를 높이되 여백으로 숨 쉬게
- 라이트 모드 기본 (다크 모드 지원)

---

## 색상 시스템

```css
:root {
  /* 배경 */
  --color-bg:          #FAFAF8;   /* 따뜻한 오프화이트 */
  --color-surface:     #FFFFFF;   /* 카드, 사이드바 */
  --color-surface-2:   #F5F4F1;   /* 인라인 폼, 코드 배경 */

  /* 텍스트 */
  --color-text:        #1A1A1A;   /* 본문 */
  --color-text-muted:  #6B6B6B;   /* 보조 텍스트 (도메인, 날짜) */
  --color-text-faint:  #A8A8A8;   /* 플레이스홀더 */

  /* 강조 */
  --color-accent:      #2D6A4F;   /* 그린 — 저장, 완료 상태 */
  --color-accent-light:#D8F3DC;   /* 그린 연한 배경 */
  --color-link:        #2563EB;   /* 파란 링크 */

  /* 상태 */
  --color-pending:     #9CA3AF;   /* 회색 — 대기 중 */
  --color-analyzing:   #3B82F6;   /* 파란 — 분석 중 */
  --color-done:        #10B981;   /* 에메랄드 — 완료 */
  --color-failed:      #EF4444;   /* 빨간 — 실패 */

  /* 테두리 */
  --color-border:      #E8E6E1;   /* 카드, 입력 테두리 */
  --color-border-focus:#2D6A4F;   /* 포커스 테두리 */

  /* 사이드바 */
  --color-sidebar-bg:  #F0EFE9;   /* 크림색 사이드바 */
  --color-sidebar-active: #E0DDD5; /* 활성 컬렉션 배경 */
}
```

**다크 모드** (Tailwind `dark:` prefix)
```css
@media (prefers-color-scheme: dark) {
  :root {
    --color-bg:         #111110;
    --color-surface:    #1C1C1B;
    --color-text:       #EBEBEA;
    --color-text-muted: #9A9A99;
    --color-border:     #2A2A28;
    --color-sidebar-bg: #161615;
  }
}
```

---

## 타이포그래피

```css
:root {
  /* 폰트 패밀리 */
  --font-sans: 'Pretendard Variable', -apple-system, BlinkMacSystemFont, sans-serif;
  --font-mono: 'JetBrains Mono', 'Fira Code', monospace;

  /* 스케일 */
  --text-xs:   0.75rem;   /* 12px — 날짜, 도메인 */
  --text-sm:   0.875rem;  /* 14px — 태그, 보조 */
  --text-base: 1rem;      /* 16px — 본문 */
  --text-lg:   1.125rem;  /* 18px — 카드 제목 */
  --text-xl:   1.25rem;   /* 20px — 섹션 제목 */
  --text-2xl:  1.5rem;    /* 24px — 페이지 제목 */
  --text-3xl:  1.875rem;  /* 30px — 컬렉션명 */

  /* 행간 */
  --leading-tight:  1.25;
  --leading-normal: 1.5;
  --leading-relaxed:1.625;

  /* 자간 */
  --tracking-tight: -0.025em;
  --tracking-normal: 0;
}
```

**폰트 로딩 전략**
- Pretendard: `font-display: swap`, subset (한국어 + Latin)
- 시스템 폰트 fallback 유지

---

## 간격 시스템

Tailwind의 4px 기반 스케일을 기준으로 의도적으로 사용.

| 용도 | 값 | Tailwind |
|------|-----|---------|
| 컴포넌트 내부 소형 간격 | 4px | `p-1`, `gap-1` |
| 카드 패딩 | 16px | `p-4` |
| 섹션 간격 | 24px | `gap-6` |
| 페이지 패딩 | 32px | `px-8` |
| 사이드바 너비 | 240px | `w-60` |
| 컬렉션 드로어 너비 (모바일) | 280px | `w-70` |

---

## 카드 스타일

### 카드형 (`card` view)

```html
<article class="
  bg-white
  border border-[--color-border]
  rounded-lg
  p-4
  hover:border-[--color-accent] hover:shadow-sm
  transition-all duration-200
  cursor-pointer
">
  <!-- 파비콘 + 도메인 -->
  <div class="flex items-center gap-2 mb-2">
    <img class="w-4 h-4" src="{favicon_url}" />
    <span class="text-xs text-[--color-text-muted]">{domain}</span>
    <span class="ml-auto text-xs text-[--color-text-faint]">{relative_time}</span>
  </div>

  <!-- 제목 -->
  <h2 class="text-base font-semibold leading-snug line-clamp-2 mb-2">
    {title}
  </h2>

  <!-- 태그 + 상태 뱃지 -->
  <div class="flex items-center gap-2 flex-wrap">
    {tags.first(3).map { |t| tag_chip(t) }}
    {status_badge}
  </div>
</article>
```

### 리스트형 (`list` view)

```html
<article class="
  flex items-start gap-3
  py-3
  border-b border-[--color-border]
  hover:bg-[--color-surface-2]
  px-2 -mx-2 rounded
  cursor-pointer
">
  <img class="w-4 h-4 mt-1 flex-shrink-0" src="{favicon_url}" />
  <div class="flex-1 min-w-0">
    <h2 class="text-sm font-medium truncate">{title}</h2>
    <p class="text-xs text-[--color-text-muted]">{domain} · {relative_time}</p>
  </div>
  {status_badge}
</article>
```

---

## 뱃지 & 칩

### 상태 뱃지

```html
<!-- pending -->
<span class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-gray-100 text-gray-500">
  ⏳ 대기 중
</span>

<!-- analyzing -->
<span class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-blue-50 text-blue-600 animate-pulse">
  ⚡ 분석 중
</span>

<!-- failed -->
<span class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-red-50 text-red-600">
  ✗ 실패
</span>
```

### 태그 칩

```html
<span class="inline-block text-xs px-2 py-0.5 rounded bg-[--color-surface-2] text-[--color-text-muted] hover:bg-[--color-accent-light] hover:text-[--color-accent] cursor-pointer transition-colors">
  {tag}
</span>
```

### 콘텐츠 타입 뱃지

```html
<!-- youtube -->
<span class="text-xs px-2 py-0.5 rounded bg-red-50 text-red-600">▶ YouTube</span>

<!-- webpage -->
<span class="text-xs px-2 py-0.5 rounded bg-gray-50 text-gray-600">🌐 웹페이지</span>
```

---

## 버튼

```css
/* 기본 (Primary) */
.btn-primary {
  @apply px-4 py-2 bg-[--color-accent] text-white text-sm font-medium rounded-md
    hover:opacity-90 active:scale-[0.98] transition-all;
}

/* 보조 (Secondary) */
.btn-secondary {
  @apply px-4 py-2 bg-[--color-surface-2] text-[--color-text] text-sm font-medium rounded-md
    border border-[--color-border]
    hover:border-[--color-accent] transition-all;
}

/* 위험 (Danger) */
.btn-danger {
  @apply px-4 py-2 bg-red-50 text-red-600 text-sm font-medium rounded-md
    hover:bg-red-100 transition-all;
}

/* 아이콘 전용 */
.btn-icon {
  @apply p-2 rounded-md text-[--color-text-muted]
    hover:bg-[--color-surface-2] hover:text-[--color-text] transition-all;
}
```

---

## 입력 필드

```css
.input {
  @apply w-full px-4 py-3 text-sm
    bg-white border border-[--color-border] rounded-lg
    placeholder:text-[--color-text-faint]
    focus:outline-none focus:border-[--color-border-focus] focus:ring-2 focus:ring-[--color-accent]/20
    transition-all;
}
```

---

## 통합 입력바 스타일

```html
<div class="
  flex items-center gap-2
  bg-white border border-[--color-border] rounded-xl shadow-sm
  px-4 py-3
  focus-within:border-[--color-border-focus] focus-within:shadow-md
  transition-all duration-200
">
  <span class="text-[--color-text-muted] text-lg">🔍</span>
  <input
    class="flex-1 text-sm bg-transparent focus:outline-none"
    placeholder="URL 저장 또는 검색..."
  />
  <button class="btn-primary text-sm px-3 py-1.5">저장</button>
</div>
```

---

## 사이드바 스타일

```css
.sidebar {
  @apply w-60 h-screen sticky top-0
    bg-[--color-sidebar-bg]
    border-r border-[--color-border]
    flex flex-col
    overflow-y-auto;
}

.sidebar-item {
  @apply flex items-center gap-2 px-3 py-2 mx-2 rounded-md text-sm
    text-[--color-text-muted] cursor-pointer
    hover:bg-[--color-sidebar-active] hover:text-[--color-text]
    transition-colors;
}

.sidebar-item.active {
  @apply bg-[--color-sidebar-active] text-[--color-text] font-medium;
}
```

---

## 반응형 그리드

```css
/* 카드 그리드 */
.card-grid {
  @apply grid gap-4;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
}

/* 모바일: 1열 고정 */
@media (max-width: 640px) {
  .card-grid {
    grid-template-columns: 1fr;
  }
}
```

---

## 애니메이션

```css
/* 카드 진입 (저장 직후) */
@keyframes slide-in-fade {
  from { opacity: 0; transform: translateY(-8px); }
  to   { opacity: 1; transform: translateY(0); }
}
.animate-slide-in { animation: slide-in-fade 0.2s ease-out; }

/* 분석 중 pulse */
/* Tailwind animate-pulse 사용 */

/* 드로어 슬라이드 */
/* Stimulus에서 translate-x-0 / -translate-x-full 토글 */
```

**원칙**
- 애니메이션 속성: `opacity`, `transform`만 사용 (compositor-friendly)
- `prefers-reduced-motion` 미디어쿼리 준수: 모션 비활성화 시 애니메이션 제거

---

## 아이콘

Heroicons (Tailwind 생태계, SVG inline)

| 용도 | 아이콘 |
|------|--------|
| 검색 | `magnifying-glass` |
| 저장 | `bookmark` |
| 컬렉션 | `folder` |
| 삭제 | `trash` |
| 편집 | `pencil` |
| 재분석 | `arrow-path` |
| 햄버거 | `bars-3` |
| 닫기 | `x-mark` |
| 외부 링크 | `arrow-top-right-on-square` |
| YouTube | `play-circle` |
| 웹페이지 | `globe-alt` |
