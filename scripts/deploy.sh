#!/bin/bash
# Deploy a game to Cloudflare Pages
# Usage: ./scripts/deploy.sh <game-name> [branch]
#
# This script:
# 1. Commits and pushes changes to git
# 2. Creates DNS record for the subdomain
# 3. Creates/updates Cloudflare Pages project
#
# Before first deploy, run:
#   echo "CLOUDFLARE_API_TOKEN=your-token" > .cloudflare.env
#   echo "CLOUDFLARE_ACCOUNT_ID=your-account-id" >> .cloudflare.env

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_NAME="${1:-}"
BRANCH="${2:-main}"

cd "$PROJECT_DIR"

if [ -z "$GAME_NAME" ]; then
    echo "Usage: ./scripts/deploy.sh <game-name> [branch]"
    echo ""
    echo "Available games:"
    for dir in games/*/; do
        if [ -f "$dir/index.html" ]; then
            echo "  - ${dir%*/}"
        fi
    done
    exit 1
fi

GAME_DIR="games/${GAME_NAME}"

if [ ! -d "$GAME_DIR" ]; then
    echo "❌ Game folder not found: $GAME_DIR"
    exit 1
fi

if [ ! -f "$GAME_DIR/index.html" ]; then
    echo "❌ No index.html found in $GAME_DIR"
    exit 1
fi

# Load config
if [ -f .cloudflare.env ]; then
    source .cloudflare.env
fi

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "❌ CLOUDFLARE_API_TOKEN not found in .cloudflare.env"
    echo ""
    echo "Create .cloudflare.env with your API token:"
    echo "  echo 'CLOUDFLARE_API_TOKEN=your-token' > .cloudflare.env"
    echo "  echo 'CLOUDFLARE_ACCOUNT_ID=your-account-id' >> .cloudflare.env"
    exit 1
fi

if [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
    echo "❌ CLOUDFLARE_ACCOUNT_ID not found in .cloudflare.env"
    exit 1
fi

echo "=== Cloudflare Pages Deploy ==="
echo "Game: $GAME_NAME"
echo "Branch: $BRANCH"
echo ""

# Initialize git if needed
if [ ! -d ".git" ]; then
    echo "Initializing git repository..."
    git init
    git add .
    git commit -m "Initial commit"
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo "Committing changes..."
    git add .
    git commit -m "Deploy $GAME_NAME"
fi

# Push to remote
if git remote get-url origin >/dev/null 2>&1; then
    echo "Pushing to git..."
    git push origin "$BRANCH"
else
    echo "⚠️  No git remote configured. Push manually to enable auto-deploy."
fi

# Create Pages project
echo ""
echo "Creating Cloudflare Pages project..."

PROJECT_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/pages/projects" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"${GAME_NAME}\",
    \"production_branch\": \"${BRANCH}\",
    \"build_config\": {
      \"build_command\": \"echo 'Static HTML - no build step'\",
      \"destination_dir\": \"${GAME_DIR}\",
      \"root_dir\": \".\"
    }
  }")

if echo "$PROJECT_RESPONSE" | python3 -c "import sys,json; sys.exit(0 if json.load(sys.stdin).get('success') else 1)"; then
    echo "✅ Pages project created/updated"
else
    echo "⚠️  Pages project creation failed (may already exist)"
    echo "$PROJECT_RESPONSE" | python3 -m json.tool
fi

# Add DNS record
echo ""
echo "Setting up DNS..."
./scripts/add-dns.sh "$GAME_NAME"

echo ""
echo "=== Deploy Complete ==="
echo ""
echo "Visit: https://${GAME_NAME}.finley.lol"
