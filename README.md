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

Every existing `shot_0.png` is 1448×1086 (4:3) in the same house style. Fill in
the bracketed parts and hand this to an image generator:

> Glossy 3D-rendered children's game box art, Pixar/mobile-game style.
> [SUBJECT: the hero character, mid-action, big friendly eyes, chunky rounded
> forms], set in [SETTING: the game's world]. [FOREGROUND PROPS] scattered in the
> lower corners, [BACKGROUND LANDMARK] softly blurred behind. Saturated candy
> colors, warm rim light, sparkles and soft bloom, cheerful and inviting, no
> text, no logos, no UI. 4:3 aspect ratio, 1448×1086.

Keep the hero large and centered-right, the camera low and close, and pull the
palette from the game's actual background colors so the card matches the game.

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
