---
title: "Building DROO.FOO: Module 1 Content Infrastructure."
date: "2025-01-18"
description: "I am building my gundam slowly, one module at a time."
author: "DROO AMOR"
tags: ["elixir", "phoenix", "architecture", "systems"]
slug: "building-droo-foo"
pattern_style: "circuit"
---

<div class="post-pattern-header">
  <object data="/patterns/building-droo-foo?style=circuit&animate=true" type="image/svg+xml" style="width: 100%; height: 300px; display: block;">
    <img src="/patterns/building-droo-foo?style=circuit" alt="Generative pattern for building-droo-foo" style="width: 100%; height: 300px; object-fit: cover;" />
  </object>
</div>

# Module 1: Proof of architecture

Like building a gundam, one module at a time.

This site is Module 1. If the content system isn't modular, [mana](/projects#mana) won't be. If the monospace grid breaks here, it breaks in [raxol](/projects#raxol). If patterns can't handle blog posts, they can't handle validator dashboards.

The stack is Phoenix 1.8 and LiveView, MDEx, file-based content, deterministic SVG generation. The test is a character-perfect terminal grid that holds across browsers. The workflow runs Obsidian or Zed to an API endpoint to live.

---

## The constraints

The architecture has to satisfy:

- A monospace terminal interface with character-perfect grid alignment
- No layout shifts or font rendering surprises across browsers
- Portability, meaning minimal dependencies and file-based data
- Accessibility as a first-class constraint: WCAG compliance, proper ARIA, screen reader support
- [Raxol](/projects#raxol) compatibility, since the terminal framework uses the same rendering

It also has to pass the squint test. A visible monospace grid with precise character spacing, optimized hard for legibility and visual rhythm.

I handled the font constraints with the [monaspace font family](https://monaspace.githubnext.com/). Monaspace does texture healing, adjusting letter spacing dynamically so text density reads as even while the alignment stays strictly monospace.

Character-perfect grid alignment turned out to be the first real problem. CSS handles 1ch units differently across browsers. Safari rendered 1ch about 0.1ch wider than Chrome, which is enough to break alignment after 80 characters.

---

## Pattern generation

Every post needs a visual. Manual design doesn't scale, and the site looked too stark without imagery.

So: deterministic pattern generation. Hash the slug, seed the RNG, generate SVG. Reproducible, cacheable, zero manual work.

I used functional patterns idiomatic to Elixir, partly because imperative patterns give me existential dread.

```elixir
def generate_svg(slug, opts \\ []) do
  # Hash the slug to get a deterministic seed
  seed = :erlang.phash2(slug)
  :rand.seed(:exsplus, {seed, seed, seed})

  # Choose style based on slug hash
  style = choose_style(slug)
  generate_pattern(style, opts)
end
```

Eight basic styles for now, and the slug hash picks one. No database, no storage, just deterministic math. See them at [/dev/pattern-gallery](/dev/pattern-gallery).

The infrastructure is reusable. Posts, projects, validator dashboards, anything gets deterministic artwork out of the same code.

## Phoenix LiveView

LiveView handles server-side rendering and real-time updates without JavaScript bloat. Components are pure functions: data in, UI out.

```elixir
def render(assigns) do
  ~H"""
  <.page_layout title={@post.title}>
    <.pattern slug={@post.slug} />
    <.content markdown={@post.content} />
  </.page_layout>
  """
end
```

## File-based content

No database. Git for version control, `resume.json` as the data source. Posts are markdown with YAML frontmatter. Files version naturally, backups are trivial, migration is straightforward.

Projects pull from resume data:

```elixir
def all do
  resume = ResumeData.get_resume_data()

  # Defense and portfolio projects handled uniformly
  defense = convert_defense_projects(resume[:defense_projects])
  portfolio = convert_portfolio_projects(resume[:portfolio][:projects])

  portfolio ++ defense
end
```

Pattern matching transforms data shapes. Defense and portfolio projects become the same struct. No if/else, no type checking, just data transformation.

## Obsidian to web

I write in [Obsidian](https://obsidian.md/) or [Zed](https://zed.dev/). The API endpoint accepts markdown and writes to `priv/posts/slug.md`:

```bash
# From Obsidian, run via plugin or script:
curl -X POST https://droo.foo/api/posts \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -d '{
    "content": "# My Post\n\nContent here",
    "metadata": {
      "title": "My Post",
      "description": "Post description",
      "tags": ["elixir"]
    }
  }'
```

No GUI, no admin panel. The endpoint extends to any content type.

### Security

Three layers: bearer token authentication, IP-based rate limiting at 10/hour and 50/day, and content validation covering path traversal, slug sanitization, and a 1MB cap. There is no token bypass. The endpoint returns 401 if it isn't configured.

---

## What broke

### CSS precision

Safari rendered 1ch about 0.1ch wider than Chrome, enough to misalign the grid after 80 characters. Firefox had its own quirks with `font-feature-settings`.

The grid isn't decoration here, it's architecture. If it breaks in this codebase it breaks in Raxol, because the terminal framework depends on character-perfect alignment.

The fix:

1. `font-feature-settings: 'liga' 0, 'calt' 0` to disable ligatures
2. CSS cascade control, so nothing inherits text transforms or letter spacing
3. JavaScript validation on resize to lock the grid

The monospace grid is the [agalma](/posts/the-agalma) of this project, the idealized constraint driving every architectural decision. If the foundation breaks, everything on top of it goes with it.

Next: tests against more browsers (Ladybird, Edge, terminal browsers) and a closer look at rendering execution.

### GitHub API rate limiting

The API allows 60 requests/hour unauthenticated. With 10+ projects, a single visitor exhausted the limit on one page load.

I built a caching layer on ETS, Erlang's in-memory key-value store. One GenServer fetches on startup, caches, and refreshes hourly. Cache hit rate after warmup is 98%.

That buys no external dependencies, no token management, and instant response times, at the cost of single-server state. Distributed cache or authenticated API calls when that becomes the problem.

### Pattern generation iterations

Three iterations. The third was a full refactor: each pattern type became its own module, pattern selection moved to pattern matching on hash ranges, and the SVG builder became a pure function, same input to same output every time. Generation dropped from about 15ms to under 5ms.

### Accessibility

ARIA roles conflicting with semantic HTML. Terminal grids don't map cleanly onto web semantics, because the terminal is a grid of cells and a dynamic application at the same time. Screen readers expected one thing and the DOM provided another.

Claiming accessibility as a first-class constraint means nothing if screen readers can't navigate the interface or keyboard users get trapped in the grid.

Two halves to the problem. Structure: terminal cells needed proper ARIA roles without breaking semantic HTML, navigable but not chatty. Updates: LiveView pushes constantly, and screen readers needed to know when content changed without announcing every cell modification.

The fix was roving tabindex for keyboard navigation, so only one element is focusable at a time and arrow keys move focus; `aria-live="polite"` regions for terminal output, so new content gets announced without interrupting; and semantic grouping with a real role hierarchy, terminal as application with the grid structure underneath.

Not perfect. Still testing with NVDA, VoiceOver, and JAWS. Navigable and usable, which is the baseline.

## The numbers

- Pattern generation: under 5ms per SVG, 2000 lines of code total
- GitHub cache: 98% hit rate, under 1ms on cached responses
- Page load: under 200ms to first paint, 50ms LiveView connection, zero layout shift
- Build: 8s full, under 1s incremental

## What this unlocks

- Pattern generator -> reusable library
- Components -> design system
- Files -> data layer
- LiveView -> real-time features

The same patterns that render blog posts will render validator dashboards and real-time terminal interfaces. [Raxol](/projects#raxol) applies this grid system to terminal UIs. Then [mana](/projects#mana) (Ethereum client) and [riddler](/projects#riddler) (cross-chain solver) build on the proven foundation.

See all projects at [/projects](/projects). Track progress at [/now](/now).

---

This post's pattern: [animated](/patterns/building-droo-foo?animate=true) | [static](/patterns/building-droo-foo)
