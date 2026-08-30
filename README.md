# finley.lol

Cloudflare Pages hosting for static HTML/Three.js games.

## Structure

```
finley.lol/
├── home/                → finley.lol (landing page listing all games)
├── games/
│   ├── horses/          → horses.finley.lol
│   ├── sandcastles/     → sandcastles.finley.lol
│   └── seamonsters/     → seamonsters.finley.lol
├── scripts/
│   ├── deploy.sh        → Deploy a game (git + DNS + Pages)
│   ├── deploy-home.sh   → Deploy the landing page to the apex domain
│   └── new-game.sh      → Create a new game from template
└── .cloudflare.env      → API credentials (copy from .example)
```

Each game directory contains box art named `shot_0.png` (later shots:
`shot_1.png`, …). The landing page loads `https://<game>.finley.lol/shot_0.png`
for its cards, so shots deploy with the game itself — no assets live in `home/`.
If a shot is missing, the card shows an emoji placeholder instead.

When adding a game: generate the box art, drop it in the game dir, add a card to
`home/index.html`, then `./scripts/deploy.sh <name>` and `./scripts/deploy-home.sh`.
The card list is manual — nothing auto-discovers new games.

## Box Art Prompt

Box art is generated from a **style anchor** — pass `games/miniex/shot_0.png` as
Image A so every card stays in the same family. Existing shots are 1448×1086 (4:3).
Fill in the bracketed parts:

> Image A is a style anchor for the series. Create matching kid-friendly indie game
> box art / app-store key art for a game called **[GAME SLUG]**, keeping the same
> cohesive family-friendly art direction as Image A: polished stylized 3D diorama
> look, clean geometric forms, soft rounded edges, chunky toy-like proportions,
> saturated but tasteful candy colors, soft global illumination, warm rim light,
> gentle bloom, subtle sparkles, and clear readable silhouettes in a slightly
> cinematic composition that stays clear at thumbnail size. Show **[HERO + ACTION]**.
> In the lower-left, include **[FOREGROUND PROPS]**. In the lower-right, include
> **[FOREGROUND PROPS]**. In the softly blurred background, show **[BACKGROUND]**.
> Keep the mood cheerful, inviting, and playful. No text, no logos, no UI, no border.

Pull the scene details from the game's own world and palette so the card matches
what the player actually sees.

## Setup (one-time)

1. Copy `.cloudflare.env.example` to `.cloudflare.env`:
   ```bash
   cp .cloudflare.env.example .cloudflare.env
   ```

2. Edit `.cloudflare.env` with your credentials:
   - `CLOUDFLARE_API_TOKEN` - From [API Tokens](https://dash.cloudflare.com/profile/api-tokens)
   - `CLOUDFLARE_ACCOUNT_ID` - From Cloudflare dashboard (bottom left)

3. Add finley.lol to Cloudflare (nameserver swap at Porkbun)

## Adding a New Game

```bash
./scripts/new-game.sh gamename
# Edit games/gamename/index.html
./scripts/deploy.sh gamename
```

## Deploy Updates

```bash
./scripts/deploy.sh horses
```

This commits/pushes changes and updates the Pages project.
