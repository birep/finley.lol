# finley.lol

Cloudflare Pages hosting for static HTML/Three.js games.

## Structure

```
finley.lol/
├── games/
│   ├── horses/          → horses.finley.lol
│   └── seamonsters/     → seamonsters.finley.lol
├── scripts/
│   ├── deploy.sh        → Deploy a game (git + DNS + Pages)
│   └── new-game.sh      → Create a new game from template
└── .cloudflare.env      → API credentials (copy from .example)
```

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
