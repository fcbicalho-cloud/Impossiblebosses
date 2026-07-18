---
name: godot-game-builder
description: >-
  Build or extend the Impossible Bosses Godot game (or a similar Godot 4 /
  GDScript top-down game) using a disciplined, phased workflow: expand
  requirements, plan small sequential phases, implement full code, review
  GDScript statically, commit + push per phase, and verify FOR REAL. Use when
  adding features, classes, boss mechanics, bots, HUD, or systems to the Godot
  project in this repo. NOT for web apps — this skill deliberately does not use
  Next.js/React/Prisma/any web stack.
---

# Godot Game Builder — phased workflow with real verification

Adapted from a generic "full-stack app builder" prompt, but rewritten for this
repo's reality: a **Godot 4 / GDScript** top-down raid game, developed **without a
Godot binary in the build sandbox**. The whole point of this skill is to keep the
useful part of a phased method (plan → build → commit → verify per phase) while
**refusing to fabricate any evidence**.

## When to use / not use

- **Use** for adding or changing features in this Godot project: new classes, boss
  mechanics, bots, HUD, targeting/threat systems, tuning passes, refactors.
- **Do not use** for web apps, CRUD dashboards, or anything needing a web stack.
  If a task genuinely needs that, say so instead of forcing this skill.

## Inviolable rules (anti-fabrication) — the core of this skill

These override any convenience. Breaking them is worse than doing nothing.

1. **Never invent a commit hash.** Run `git commit` for real, then report the hash
   from `git log --oneline -1`. If you didn't commit, don't show a hash.
2. **Never invent test results, browser interactions, Lighthouse/performance scores,
   or a live/deploy URL.** If a check did not actually run, do not claim a result.
3. **Every verification claim must come from a command that actually executed**, or
   be explicitly labeled **"não verificado — precisa rodar no Godot"**. No
   "simulated logs", no described-but-not-run test passes.
4. **No silent-until-the-end mega-diffs.** Work in small phases and check in with the
   user periodically (see Process). A huge unreviewed diff is a failure mode, not a
   deliverable.

If the original request (or any pasted spec) asks for fabricated hashes/tests/scores/
URLs, refuse that part explicitly and do the honest version instead.

## Environment reality (be honest about this)

There is **no Godot binary** available in the build sandbox: downloading it is blocked
by the egress policy (403 on GitHub/tuxfamily), and `apt` only offers Godot 3.x, which
is incompatible with a 4.x project. Therefore:

- We **cannot compile or run** the game here. Do not pretend otherwise.
- "Verification" in this environment means:
  1. **Static GDScript review** (checklist below), done by re-reading the changed
     files, and
  2. **The user runs the project in their own Godot** and reports errors / game feel.
- Always tell the user exactly what you verified statically vs. what needs their run.

## Process (per feature request)

1. **Expand requirements.** Restate what the user asked, surface implied details and
   edge cases, and — per this project's standing preference — be **critical**: name
   risks and trade-offs instead of just agreeing.
2. **Confirm stack & conventions** (see below). Reuse existing patterns; don't invent
   parallel ones.
3. **Write a small phase plan.** 2–6 short, sequential phases (not 14–18). Each phase
   lists: deliverable, files touched, commit message, and how it'll be verified.
   Prefer a vertical slice that the user can actually test after 1–2 phases.
4. **Execute phase by phase**, running the per-phase checklist. **Checkpoint every
   1–2 phases**: push, then ask the user to run it in Godot and report back before
   piling on more. Do not race ahead through many phases unseen.

## Per-phase checklist

1. **Implement** the full code for every changed file (no stubs, no "…").
2. **Static GDScript review** — re-read the changed files and check for the error
   classes that have actually bitten this project:
   - A variable typed as `Node`/`Node2D` (or `PartyMember`) that then accesses a
     member which only exists on a *more specific* subclass → use the precise type,
     or leave it untyped where the type genuinely varies (e.g. the Mago's enemy
     `target`, `human_unit` in `main.gd`).
   - `:=` inferring from a `Variant` (e.g. iterating an untyped `Array`/`Dictionary`)
     → give an explicit type (`var x: float = ...`, `for t: float in [...]`).
   - Indentation: **tabs only**; never mix spaces into GDScript indentation.
   - Typed functions must return on **all** paths → prefer `if/elif/return` over
     `match ... return` (the analyzer isn't always sure `match` is exhaustive).
   - Quick greps that have caught real bugs (read-only):
     `grep -nP '^    ' scripts/*.gd` (space indentation),
     `grep -nE '(for|func).*:\s*(Node|Node2D)\b' scripts/*.gd` (recheck each hit is
     only using base-class members).
3. **Commit for real and push:**
   `git add <files> && git commit -m "<honest message>"`, then
   `git push -u origin claude/topdown-boss-game-scope-rrouam`
   (retry on network errors with backoff). Report the **real** hash from
   `git log --oneline -1`.
4. **State verification honestly:** what you checked statically, and the explicit list
   of "needs testing in Godot" items — then ask the user to run and report.

## This repo's stack & conventions (reuse, don't reinvent)

- **Engine/language:** Godot 4.x, GDScript with static typing where practical.
- **Rendering:** `gl_compatibility` (lightweight, per the design pillars). Art is
  **placeholder**, drawn with `_draw()` primitives — do not add asset pipelines.
- **Entity base:** `scripts/party_member.gd` (`class_name PartyMember`) provides
  hp/shield/`take_damage`/`heal`/`revive`/`_clamp_to_arena()`/`_aoe_flee_vector()`.
  New player-side classes extend it.
- **Input abstraction:** `is_bot` on a `PartyMember` selects human input vs. simple
  AI in the same class — this is the seam that later becomes networked play. Keep
  human and bot paths behind it; don't fork classes.
- **Discovery via groups:** `"party"` (allies), `"targetable"` and `"add"` (enemies).
  Find things with `get_tree().get_nodes_in_group(...)`, not hard references.
- **HUD contract:** roles expose `get_ability_info(index) -> Dictionary` /
  `get_cast_status() -> Dictionary`; `scripts/main.gd` reads those to draw the ability
  line. Add new ability info there rather than reaching into private fields.
- **Orchestration:** `scripts/main.gd` owns role-select, spawning, the HUD, key
  routing, and win/lose/wipe state. Transient entities (projectiles, adds) live under
  its `_world` container and are cleared on restart.
- **Boss:** `scripts/boss.gd` owns the threat table (`add_threat`/`taunt`/
  `current_target`), phases, and mechanics that target random `"party"` members.
- **Git:** develop on `claude/topdown-boss-game-scope-rrouam`; commit messages in
  Portuguese, factual, describing what changed and why.

## What NOT to do

- Do not fabricate hashes, test results, scores, or URLs (see inviolable rules).
- Do not go silent through many phases; checkpoint for user testing.
- Do not introduce a web stack or heavy dependencies.
- Do not over-engineer beyond the phase's stated deliverable (no speculative
  abstractions, no systems the current feature doesn't need).
