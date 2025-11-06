# Loftwah UI Philosophy

**App context:** Rails 8.1 • Tailwind CSS v4 • Stimulus • Font Awesome

**Last updated:** 2025/11/06 Australia/Melbourne (UTC+11) • 2025/11/05 UTC

## Purpose

This document defines how we design and build UI so the experience is consistent, accessible, and
fast. It is a reference for pull requests, reviews, and new contributors. It prefers small, boring
decisions, and codifies what we already do. Where guidance is opinionated, it is because we have
already aligned on it or because it reduces risk.

## Scope

- Layout shells and viewport-specific chrome
- Content bricks and grid rules
- Theming, colour, and motion
- Interaction patterns: tabs, buttons, forms, toasts
- Accessibility and performance
- Testing and PR checklists

## Baseline principles

1. Mobile first. iPhone portrait is the baseline target. Tablet and desktop are enhancements.
2. One thing per row by default. Two or three bricks on larger screens are allowed with guard rails.
3. No horizontal scrolling in the main layout.
4. Tabs separate concerns. Buttons always show state and status.
5. Respect both light and dark themes. Avoid low-contrast combinations.
6. Prefer Tailwind inbuilt tokens for colour, spacing, shadows. Avoid custom palettes unless
   justified.
7. Avoid purple as a primary brand colour. It is fine for accents when contrast is correct.
8. Be consistent with padding and margins. Use a small set of spacing scales.
9. Animated gradient highlights are subtle and wrapped in motion-safe.
10. Use rails defaults and the stack we have. No new libraries unless needed.

## Layout architecture

- The main content is rendered **once** per page.
- Viewport-specific **chrome** (navigation, headers, toolbars, footers) are separate partials per
  breakpoint.
- Breakpoint visibility is CSS-only so assistive tech only sees one chrome at a time.

```erb
<!-- app/views/layouts/application.html.erb -->
<body class="min-h-dvh overflow-x-hidden bg-white text-slate-900 antialiased dark:bg-slate-950 dark:text-slate-100">
  <div id="app" class="mx-auto w-full max-w-screen-xl px-4 sm:px-6 lg:px-8">
    <%= render "chrome/mobile" %>
    <%= render "chrome/tablet" %>
    <%= render "chrome/desktop" %>

    <main id="page" class="space-y-4 md:space-y-6">
      <%= yield %>
    </main>

    <%= render "chrome/toasts" %>
    <%= render "chrome/footer" %>
  </div>
</body>
```

```erb
<!-- app/views/chrome/_mobile.html.erb -->
<header class="block sm:hidden safe-y">
  <%= render "chrome/nav_mobile" %>
</header>

<!-- app/views/chrome/_tablet.html.erb -->
<header class="hidden sm:block lg:hidden safe-y">
  <%= render "chrome/nav_tablet" %>
</header>

<!-- app/views/chrome/_desktop.html.erb -->
<header class="hidden lg:block safe-y">
  <%= render "chrome/nav_desktop" %>
</header>
```

### Horizontal scroll guards

- Page shell: `overflow-x-hidden`
- Content wrappers: `max-w-full break-words [overflow-wrap:anywhere]`
- Bricks: `min-w-0 break-inside-avoid`

## Content bricks

- Brick = a full-width card with a consistent border, radius, shadow, and padding.
- Bricks stack vertically by default.
- Optional multi-column on large screens only. The container decides columns. Bricks do not.

```erb
<!-- app/views/shared/_brick_container.html.erb -->
<div class="grid grid-cols-1 gap-4 @lg:grid-cols-2 @xl:grid-cols-3">
  <%= yield %>
</div>

<!-- app/views/shared/_brick.html.erb -->
<section class="min-w-0 break-inside-avoid rounded-xl border border-slate-200 bg-white p-4 shadow-sm dark:border-slate-800 dark:bg-slate-900">
  <%= yield %>
</section>
```

## Theming and colours

- Use Tailwind built-in palettes (e.g. slate, zinc, neutral). Use a small set of accent colours
  (e.g. sky, blue, emerald, amber) as needed.
- Avoid purple as a primary colour. It can be used sparingly as an accent when contrast is
  sufficient.
- Respect system dark mode with a manual override. Prevent theme flash on initial paint.

```html
<html class="h-full" data-theme>
  <script>
    ;(() => {
      const s = localStorage.getItem('theme')
      const prefers = matchMedia('(prefers-color-scheme: dark)').matches
      const dark = s ? s === 'dark' : prefers
      document.documentElement.classList.toggle('dark', dark)
    })()
  </script>
</html>
```

- Base classes live on `<body>` or `<html>`:
  `bg-white text-slate-900 dark:bg-slate-950 dark:text-slate-100`
- Always check contrast. Avoid light-on-light or dark-on-dark pairings.

### Animated gradient headings

Subtle animated highlight for a word or phrase.

```html
<h2 class="text-2xl font-semibold tracking-tight">
  HMAS
  <span
    class="bg-gradient-to-r from-sky-400 via-emerald-400 to-amber-400 bg-clip-text text-transparent motion-safe:[animation:gradient_6s_linear_infinite]"
    >Loftwah</span
  >
</h2>
```

```css
/* app/assets/stylesheets/application.tailwind.css */
.safe-y {
  padding-top: env(safe-area-inset-top);
  padding-bottom: env(safe-area-inset-bottom);
}
.safe-x {
  padding-left: env(safe-area-inset-left);
  padding-right: env(safe-area-inset-right);
}
@keyframes gradient {
  0% {
    background-position: 0% 50%;
  }
  50% {
    background-position: 100% 50%;
  }
  100% {
    background-position: 0% 50%;
  }
}
```

## Tabs for concerns

- Tabs are accessible, keyboard navigable, and maintain `?tab=` in the URL.
- Use Stimulus. Panels toggle using `hidden`.

```erb
<div data-controller="tabs">
  <nav class="flex gap-2 border-b border-slate-200 dark:border-slate-800" role="tablist">
    <button data-tabs-target="tab" data-action="tabs#select" data-id="overview"
      class="px-3 py-2 text-sm font-medium" role="tab" aria-selected="true">Overview</button>
    <button data-tabs-target="tab" data-action="tabs#select" data-id="settings"
      class="px-3 py-2 text-sm font-medium" role="tab" aria-selected="false" tabindex="-1">Settings</button>
  </nav>
  <section data-tabs-target="panel" data-id="overview" role="tabpanel" class="pt-4">…</section>
  <section data-tabs-target="panel" data-id="settings" role="tabpanel" class="hidden pt-4">…</section>
</div>
```

```js
// app/javascript/controllers/tabs_controller.js
import { Controller } from '@hotwired/stimulus'
export default class extends Controller {
  static targets = ['tab', 'panel']
  connect() {
    const qp = new URLSearchParams(location.search).get('tab')
    this.selectById(qp || this.tabTargets[0].dataset.id, { focus: false })
    this.element.addEventListener('keydown', this.onKeyDown)
  }
  select(e) {
    this.selectById(e.currentTarget.dataset.id)
  }
  selectById(id, opts = { focus: true }) {
    this.tabTargets.forEach((t) => {
      const active = t.dataset.id === id
      t.setAttribute('aria-selected', active)
      t.tabIndex = active ? 0 : -1
      if (active && opts.focus) t.focus()
    })
    this.panelTargets.forEach((p) => p.classList.toggle('hidden', p.dataset.id !== id))
    const url = new URL(location)
    url.searchParams.set('tab', id)
    history.replaceState({}, '', url)
  }
  onKeyDown = (e) => {
    if (!['ArrowRight', 'ArrowLeft', 'Home', 'End'].includes(e.key)) return
    e.preventDefault()
    const i = this.tabTargets.findIndex((t) => t.getAttribute('aria-selected') === 'true')
    const wrap = (n) => (n + this.tabTargets.length) % this.tabTargets.length
    const next =
      e.key === 'ArrowRight'
        ? wrap(i + 1)
        : e.key === 'ArrowLeft'
          ? wrap(i - 1)
          : e.key === 'Home'
            ? 0
            : this.tabTargets.length - 1
    this.selectById(this.tabTargets[next].dataset.id)
  }
}
```

## Buttons and visible state

- Buttons show progress, success, and failure. Disabled while working. `aria-busy` is set.
- Icons use Font Awesome. Prefer SVG subsets or sprites where possible.

```erb
<button
  data-controller="btn"
  data-action="click->btn#run"
  data-btn-label-value="Save"
  class="inline-flex items-center gap-2 rounded-lg bg-sky-600 px-4 py-2 text-white disabled:opacity-60">
  <span data-btn-target="icon" class="fa fa-save" aria-hidden="true"></span>
  <span data-btn-target="label">Save</span>
</button>
```

```js
// app/javascript/controllers/btn_controller.js
import { Controller } from '@hotwired/stimulus'
export default class extends Controller {
  static targets = ['label', 'icon']
  static values = { label: String }
  async run() {
    this.start()
    try {
      const evt = new CustomEvent('btn:run', { detail: { controller: this }, cancelable: true })
      this.element.dispatchEvent(evt)
      await new Promise((r) => setTimeout(r, 600))
      this.success()
    } catch (e) {
      console.error(e)
      this.fail()
    } finally {
      setTimeout(() => this.reset(), 800)
    }
  }
  start() {
    this.element.disabled = true
    this.element.setAttribute('aria-busy', 'true')
    this.iconTarget.className = 'fa fa-circle-notch fa-spin'
    this.labelTarget.textContent = 'Working…'
  }
  success() {
    this.iconTarget.className = 'fa fa-check'
    this.labelTarget.textContent = 'Saved'
  }
  fail() {
    this.iconTarget.className = 'fa fa-triangle-exclamation'
    this.labelTarget.textContent = 'Failed'
  }
  reset() {
    this.element.disabled = false
    this.element.removeAttribute('aria-busy')
    this.iconTarget.className = 'fa fa-save'
    this.labelTarget.textContent = this.labelValue || 'Save'
  }
}
```

## Forms

- Inputs are at least 44px tall on touch devices: `h-11 px-3`.
- Use `focus-visible:outline focus-visible:outline-2 focus-visible:outline-sky-500`.
- Labels are always visible. Errors live under fields.
- Disable submit while working. Avoid duplicate submissions.
- Use skeletons for loads longer than 400ms: `animate-pulse`.

## Performance

- Only load what mobile needs first. Heavy widgets load lazily using `<turbo-frame loading="lazy">`.
- Limit icon payload. Prefer SVG subsets over full webfonts.
- Use system font stack or a single variable font with `font-display: swap`.
- Keep the shell to `max-w-screen-xl` for readable line lengths.

## Accessibility

- Check contrast for every component in both themes.
- Respect reduced motion: wrap non-essential animation in `motion-safe:`.
- Provide keyboard navigation for tabs and any composite widgets.
- Use `aria-live` on toasts so status changes are announced.

## Micro-interactions

- Toasts confirm success or failure and auto-dismiss after a short delay.
- Optimistic UI is acceptable when eventual consistency is safe.
- Preserve scroll position when returning to lists where possible.

## Safe areas

- Fixed headers and footers include notch safe areas using `env(safe-area-inset-*)` helpers provided
  above.

## Nielsen’s heuristics (mapped)

1. Visibility of system status. Buttons display progress and results. Toasts summarise outcomes.
2. Match between system and the real world. Plain labels. Verb-first buttons.
3. User control and freedom. Tabs set `?tab=` for back/forward. Cancel actions where appropriate.
4. Consistency and standards. Tailwind tokens and shared spacing rhythm.
5. Error prevention. Disabled submit while working. Confirmation for destructive actions.
6. Recognition rather than recall. Obvious tabs with selected styling. Visible labels.
7. Flexibility and efficiency of use. Keyboard navigation for tabs. Mobile-first with desktop
   enhancements.
8. Aesthetic and minimalist design. Single column by default. Minimal colour accents.
9. Help users recognise, diagnose, and recover from errors. Inline errors and actionable toasts.
10. Help and documentation. Keep a short “About this page” with key shortcuts and refresh rules.

## Testing checklist

- iPhone portrait has no horizontal scroll
- Only one chrome visible at any breakpoint
- Bricks default to one per row; optional 2–3 columns on large screens
- Tabs are keyboard navigable and sync `?tab=`
- Buttons show working/success/failure and set `aria-busy`
- No theme flash on initial paint
- Focus outlines are visible and consistent
- Skeletons use `animate-pulse`
- Fixed bars have safe area padding
- Lighthouse mobile Performance and Accessibility ≥ 90

## PR checklist

- [ ] Layout shells per breakpoint, content rendered once
- [ ] No custom colour palettes without a reason
- [ ] Contrast verified in light and dark
- [ ] Animations use `motion-safe:`
- [ ] Long strings wrap and do not cause width scroll
- [ ] Desktop-only widgets are lazy loaded
- [ ] Icons use SVG subset or sprite
- [ ] Forms meet touch target sizes
