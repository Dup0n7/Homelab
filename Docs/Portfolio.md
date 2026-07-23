# Public Portfolio Website

## Why this is in the plan

This repo already documents real, dated infrastructure/automation/AI work in public (see [README.md](../README.md), [LessonsLearned.md](LessonsLearned.md)) — a portfolio site is a natural front door onto that, aimed at the [[user-career-goals]] target ($150k+ IAM/platform engineering roles), rather than a hand-maintained resume page disconnected from the actual work.

**Idea captured 2026-07-23.** Not started.

## Goal

A single, modern, aesthetically polished landing page that:
- Introduces Kyle and the career direction (IAM/Ai & Automation engineering — see [[user-career-goals]])
- Summarizes the skills/stack this lab is built around (README "Goals"/"Technologies")
- Highlights the homelab itself as a live portfolio project, not just a resume line
- Has a **continuously updating "latest activity" section** surfacing recent GitHub activity and the newest entries from this repo's ongoing work — so a visitor sees something current, not a snapshot frozen at build time

Most content on one page — this isn't meant to be a multi-page site.

## New file: `Docs/Activity.md` (proposed)

[LessonsLearned.md](LessonsLearned.md) is a detailed technical journal — long-form, dated, written for the next work session, not a visitor. It's not a good direct feed source for a public page.

Proposal: a new, separate file — short, structured, one entry per notable milestone, written specifically to be parsed cleanly by whatever builds the site (frontmatter-style fields: date, title, one-line summary, optional link). Kept in sync with real work rather than written in a different voice than the rest of the repo — likely a short entry added alongside (not instead of) the matching `LessonsLearned.md` entry when something noteworthy ships. Exact filename/format still open (see below).

## Open questions

- **Hosting**: GitHub Pages (static, free, zero new infra, matches "this is already a public repo") vs. self-hosting on `automation01` behind a reverse proxy + real domain (bigger lift, but exercises Reverse Proxy/SSL/Internal DNS — already-listed README "Future Projects" — and is more directly platform-engineering-relevant as a portfolio piece in its own right)
- **Site build**: a static site generator (e.g. Astro/Eleventy/Hugo) vs. a small hand-rolled HTML/CSS/JS page — the latter is simpler and may be plenty for a single landing page
- **Update mechanism**: a GitHub Action that rebuilds/redeploys on push (mirrors the existing self-hosted-runner + Ansible auto-deploy pattern from [Ansible.md](Ansible.md)) vs. an n8n workflow (mirrors the n8n/AI automation skill-building already underway) that polls GitHub + `Docs/Activity.md` and triggers a redeploy
- **GitHub activity source**: GitHub's public Events API (no auth needed for public activity) is the likely fit — just needs picking a refresh cadence
- **`Docs/Activity.md` format** — exact schema (frontmatter block per entry vs. a simple table) not yet decided
- **Domain name** — none registered yet
- How much personal/contact detail belongs on a public landing page vs. staying limited to skills and project links — a landing page is a higher-visibility surface than a docs folder buried in a repo, worth a deliberate call rather than defaulting to "everything"

## Status

Idea only, 2026-07-23. If self-hosting is chosen, this depends on Reverse Proxy/SSL/DNS work (README "Future Projects") happening first.
