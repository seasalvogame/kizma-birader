# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Stack

Godot 4.7.2 client (`client/`), TypeScript game engine and Cloudflare Worker services. The visual client is a portrait-first 2D Godot application.

## Users

- Friends and families who want a quick, legible digital Kızma Birader match on one phone, against bots, or online.
- Returning players who check rewards, quests, cosmetics, profile progress, friends, private rooms, and weekly ranking between matches.
- First-time guests who need to understand the play choices without creating an account before they are ready.

## Product Purpose

Kızma Birader turns the familiar tabletop race game into a friendly mobile ritual: choose a match, understand whose turn it is, move a pawn with confidence, and return for social and progression features.

## Positioning

The product combines a readable, local-tabletop board with online rooms, social play, progression, rewards, cosmetics, and server-authoritative matches. The board must remain immediately playable even when a player has never seen a cosmetic before.

## Operating Context

The app is normally used one-handed on a portrait phone in short sessions. A match requires quick visual scanning under time pressure; menu and progression screens are usually visited between matches. Turkish is a first-class language and English localisation ships alongside it.

## Capabilities and Constraints

- Confirmed from repository and user brief: local practice, bot matches, online queue, private rooms, friends/invites, profiles, rewards, quests, achievements, rankings, cosmetics, account flows, and result screens.
- Confirmed preservation boundary: game rules, authentication, Supabase/database shape, Worker/Durable Objects, server authority, economy, rewards, friends, rooms, and security checks are out of scope for visual work.
- Portrait is the supported play orientation. Controls retain at least a 44 pt / 88 canvas-pixel hit target.
- Reduced motion and colour-symbol settings are existing product behaviour and must remain effective.

## Brand Commitments

- The binding visual identity is **Akşam Masası**: deep plum night, warm cream play surfaces, mango primary actions, small star details, Baloo 2 display type, and Nunito body type.
- The user explicitly requested a professional mobile-game finish, including tactile buttons, a refined game board, and PNG-based pawn art rather than plain vector-only pieces.
- Player colours identify players and board state; they are not a general-purpose action palette.

## Evidence on Hand

- Existing visual system: `docs/UI_UX_DESIGN_SYSTEM.md` and `client/scripts/ui/ui_palette.gd`, `ui_tokens.gd`, `ui_theme.gd`.
- Real Godot renderer captures: `artifacts/phase7g/before/`, `artifacts/phase7g/after/`, and `artifacts/phase7g/pawn-refresh/`.
- Pawn PNG assets: `client/assets/pawns/atelier_png/`.
- Inferred from the user brief on 2026-11-19: the desired quality bar is a polished, coherent mobile board game rather than a collection of individually decorated screens.

## Product Principles

- Make the next playable action obvious before adding decoration.
- Let the board, dice, and pawns feel like physical game pieces while preserving rules and colour-independent cues.
- Reuse a small set of tactile surfaces, type roles, and motion rhythms across every subsystem.
- Keep social, reward, and error states honest about their real backend state.

## Accessibility & Inclusion

- Do not communicate player identity by colour alone; retain shape symbols on pawns and board areas.
- Keep text and foreground/background combinations legible at mobile scale.
- Preserve reduced-motion alternatives and generous touch targets.
