---
name: Kızma Birader
description: Akşam Masası — tactile night-tabletop mobile game system
colors:
  night-deep: "#140e2b"
  night: "#1d1438"
  night-plum: "#2a1d52"
  night-lamp: "#3a2a6b"
  paper: "#fffaf2"
  paper-edge: "#e8d3b4"
  ink: "#2a1f3d"
  ink-muted: "#7a6d91"
  mango: "#ff9a1f"
  mango-deep: "#c25f00"
  mint: "#2fd39a"
  berry: "#ff5d8f"
  gold: "#ffc531"
  danger: "#ff5a5f"
typography:
  display:
    fontFamily: "Baloo 2"
    fontSize: "34px"
    fontWeight: 800
    lineHeight: 1.1
  body:
    fontFamily: "Nunito"
    fontSize: "15px"
    fontWeight: 700
    lineHeight: 1.35
rounded:
  small: "10px"
  medium: "16px"
  large: "22px"
  extra-large: "28px"
spacing:
  one: "4px"
  two: "8px"
  three: "12px"
  four: "16px"
  six: "24px"
components:
  button-primary:
    backgroundColor: "{colors.mango}"
    textColor: "{colors.ink}"
    rounded: "{rounded.extra-large}"
    height: "56px"
  button-secondary:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.extra-large}"
    height: "56px"
  card-paper:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.extra-large}"
    padding: "16px"
  card-glass:
    backgroundColor: "rgba(255,255,255,0.07)"
    textColor: "#f6efff"
    rounded: "{rounded.large}"
    padding: "12px"
---

# Design System: Kızma Birader

## Overview

**Creative North Star: "The Lacquered Evening Table"**

Akşam Masası is a composed, physical game night rather than a generic neon arcade. A deep plum field recedes behind warm paper, a small amount of starlight, and a local lamp pool. The player should feel that the board, dice, pawns, rewards, and choices belong to one carefully made tabletop kit.

The interface is friendly but not childish: Baloo 2 gives moments of play a round, confident voice; Nunito keeps explanation, status, and progression legible. The board is the visual crescendo. Menus use restraint so that the board, pawn art, and outcome states can carry the delight.

**Key Characteristics:**

- A sparse night field and contained warm lamp glow, never a noisy decorative backdrop.
- Cream paper and dark glass make content hierarchy tangible.
- One primary mango action per decision area; player colours stay attached to play state.
- Lacquered 3D edges, soft shadows, and press-sink states communicate touch without faux-metal ornament.
- PNG pawn illustrations keep a real game-object feel while a high-contrast symbol medallion protects readability.

## Colors

The palette has two jobs: night surfaces recede and game actions / objects read instantly.

### Primary

- **Mango Signal**: primary confirmation, roll and claim actions. It is a scarce action colour, not a general decorative fill.
- **Plum Night**: the screen field and deep anchors; it lets warm surfaces appear lit rather than floating on black.

### Secondary

- **Warm Paper**: decisions, reward cards, result surfaces, and board substrate.
- **Mint Social**: positive social and online states only.

### Tertiary

- **Berry Reward**: opt-in reward/replay emphasis only.
- **Gold Win**: currency, first place, safe-square stars, and milestone emphasis.

### Neutral

- **Ink**: all major copy on paper.
- **Moonlit Lilac**: restrained copy on night and inactive navigation.

**The Scarce Accent Rule.** Mango appears where a player can complete the next important action; it must not turn every icon, card, and status into a competing call to action.

## Typography

**Display Font:** Baloo 2 (700–800)

**Body Font:** Nunito (700–900)

**Character:** The display face is used for a compact, celebratory game voice. The body face carries labels, rewards, social status, and longer guidance without making a mobile screen feel crowded.

### Hierarchy

- **Display**: match outcome / pivotal count; reserve for a single moment in the viewport.
- **Headline**: screen and game-mode titles.
- **Title**: card and player identity.
- **Body**: explanations, invites, match context, and quest detail.
- **Label**: compact metadata and chips; never use micro type for essential instructions.

**The One-Shout Rule.** Each viewport gets one display-level focal point. A second large headline competes with it and is demoted to title level.

## Layout

Portrait mobile uses a 16 pt outer edge and a 4 / 8 / 12 / 16 / 24 pt rhythm. App screens are scrollable under a compact header and above a five-destination bottom navigation. Content cards have intentional grouping and whitespace; dense data stays in rows, while decisions get a full-width or clearly paired action.

The match scene is spatial rather than card-grid based: player cards frame the square board, then dice and a single instruction establish the turn ritual. Safe-area insets are part of all screen and match layout calculations. Compact portrait heights trade the auxiliary hint for the board rather than shrinking primary tap targets.

## Elevation & Depth

Depth is structural and quiet. Paper cards use a cream lower edge and a diffuse plum shadow; glass panels use a faint rim and much smaller shadow. Buttons and game-mode cards sink on press, making the interaction feel physical. Board, dice, and pawns can have the strongest depth because they are game objects.

**The Tabletop Depth Rule.** A dark shadow always reads as a surface lifting from the night table or as a playable object; it is never used as a glow substitute.

## Shapes

Rounded rectangles are generous and friendly: 10 / 16 / 22 / 28 pt establish the shared silhouette. Pills are reserved for compact status, currency, rarity, and mode context. Board cells use a smaller repeated radius, and colour symbols use the four player geometry cues (triangle, circle, square, diamond).

## Components

### Buttons

- **Character:** tactile, decisive, and stable at 44 pt minimum hit height.
- **Primary:** Mango face with dark ink type and a darker lower edge.
- **Secondary:** warm paper face for a secondary decision, never a washed-out primary.
- **Ghost:** glass on night for low-priority actions.
- **Pressed:** the face and content sink into the visible lower edge; motion is brief.

### Chips

- **Style:** small rounded status surface with an intentional 26 pt canvas height, border, and high-contrast label.
- **Use:** hierarchy markers rather than a replacement for headings.

### Cards / Containers

- **Paper cards:** hold durable content, forms, rewards, and result summaries.
- **Glass cards:** hold navigation, context, and lightweight social state on night.
- **Internal rhythm:** use the token spacing cadence; no arbitrary per-screen padding.

### Navigation

- **Style:** five compact destinations on a dark elevated bottom bar.
- **Selected state:** mango icon and label plus a short top marker; inactive destinations remain lilac and readable.

### Game Objects

- **Board:** a single warm, rimmed square with playable white cells, colour-safe start squares, and gold safety stars.
- **Pawns:** painted PNG pawns with a separate cream symbol medallion; source resolution never changes their gameplay footprint.
- **Dice:** a cream die with deep pips, a limited pulse on the local turn, and a bounded roll/settle motion.

## Do's and Don'ts

### Do:

- **Do** preserve Baloo 2 + Nunito and the plum / cream / mango hierarchy.
- **Do** make the action hierarchy obvious before increasing visual treatment.
- **Do** use player colours only for player identity, board state, and the two explicitly colour-coded home mode cards.
- **Do** preserve shape symbols, generous hit zones, and reduced-motion alternatives.
- **Do** validate visual changes with real non-headless Godot renderer captures.

### Don't:

- **Don't** replace physical button depth with unbounded glow, metallic bevels, or casino-like neon.
- **Don't** fill the night field with random high-contrast stars or add decoration that competes with copy.
- **Don't** add a new generic card pattern when the paper, glass, player-card, or game-object vocabulary already fits.
- **Don't** trade board readability, game mechanics, or existing network/economy behaviour for a cosmetic effect.
