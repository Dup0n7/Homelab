# Public Portfolio Website

## Status

**Built and live — 2026-07-24.** [kyledupont.github.io](https://kyledupont.github.io/) is a real, one-page portfolio: hero, about, skills, experience, certifications, a homelab project timeline, a condensed "Recently Learned" section, and a live GitHub activity ticker.

## Why this exists

This repo already documents real, dated infrastructure/automation/AI work in public (see [README.md](../README.md), [LessonsLearned.md](LessonsLearned.md)) — a portfolio site is a natural front door onto that, aimed at the [[user-career-goals]] target ($150k+ IAM/platform engineering roles), rather than a hand-maintained resume page disconnected from the actual work.

## What got built (vs. the original plan)

Several of the "open questions" below from the original 2026-07-23 idea got resolved differently than expected once actually building it:

- **Repo**: a separate `kyledupont.github.io` repo, not folded into this one. GitHub Pages for a project repo always serves at `username.github.io/reponame/` — there's no way to drop the repo name from the path short of renaming this actual infra repo (bad idea) or buying a domain (not ready to). Fix: `kyledupont.github.io` is GitHub's special naming convention for a **user site**, which serves at the bare domain with zero path segments.
- **System map stays put — not duplicated.** The map still lives in *this* repo at [Site/index.html](../Site/index.html), served at [kyledupont.github.io/Homelab/](https://kyledupont.github.io/Homelab/) exactly as before. A project repo's Pages and a user-site repo's Pages coexist completely independently on the same GitHub account — the portfolio just links out to the map rather than copying it.
- **No `Docs/Activity.md`.** The original plan proposed a structured feed file to drive the "latest activity" section. In practice, two hand-curated sections in the portfolio HTML do that job directly — "Homelab Updates & Projects" (condensed from this README's build history) and "Recently Learned" (condensed from [LessonsLearned.md](LessonsLearned.md)) — both sorted latest-first, both linking back to the full source. Simpler than maintaining a third parallel file in sync.
- **No static site generator, no build step.** Plain hand-authored HTML/CSS/JS. GitHub Pages serves the portfolio repo's root directly — no GitHub Action needed there, unlike this repo's map (which does need [deploy-pages.yml](../.github/workflows/deploy-pages.yml) since `Site/` isn't at the repo root).
- **Live activity ticker**: client-side JS hitting GitHub's public Events API (`api.github.com/users/kyledupont/events/public`) directly in the browser, refreshing every 5 minutes. Genuinely live — no rebuild or redeploy needed for new activity to show up.
- **Contact info kept minimal**: LinkedIn + email only, no phone number. A public landing page is higher-visibility than a docs folder buried in a repo, so this got a deliberate call rather than defaulting to "everything."
- **Theme**: dark-default with a manual light/dark toggle (choice persisted via `localStorage`), applied identically to both this site's map and the portfolio for one consistent identity. Palette is **Amber Terminal**, picked from a 10-option side-by-side comparison after discovering the original colors' faint text tier measured 3.29:1 (dark) / 2.43:1 (light) contrast — both under WCAG AA's 4.5:1 minimum. The full neutral scale was rebuilt to clear AA in both modes before accent colors were even considered — see [LessonsLearned.md](LessonsLearned.md) 2026-07-24.
- **Domain**: still none — plain `kyledupont.github.io`, no custom domain purchased.

## Source

- [github.com/kyledupont/kyledupont.github.io](https://github.com/kyledupont/kyledupont.github.io) — portfolio source (separate repo from this one)
- Content pulled from the 2026 master resume and `Ideal Role.md` priorities (both outside this repo — see [[user-career-goals]])

## Open questions

- **Domain name** — none registered; would need a purchase + DNS step if ever wanted.
- Whether to eventually replace the hand-curated "Recently Learned"/"Homelab Updates" sections with something scripted (e.g. a small Action that regenerates them from this repo's actual files) instead of manual edits — deferred; hand-curated is working fine at the current update frequency and avoids a second file format to keep in sync.
