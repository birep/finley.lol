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
BRANCH="${2:-master}"

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

# Create Pages project (or update if it exists)
echo ""
echo "Creating/updating Cloudflare Pages project..."

# Check if project exists first
PROJECT_EXISTS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/pages/projects/${GAME_NAME}" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" | python3 -c "import sys,json; print('true' if json.load(sys.stdin).get('success') else 'false')")

if [ "$PROJECT_EXISTS" = "true" ]; then
    echo "Project exists, updating..."
    curl -s -X PATCH "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/pages/projects/${GAME_NAME}" \
      -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{
        \"build_config\": {
          \"build_command\": \"echo 'Static HTML - no build step'\",
          \"destination_dir\": \"${GAME_DIR}\",
          \"root_dir\": \".\"
        }
      }" > /dev/null
    echo "✅ Pages project updated"
else
    curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/pages/projects" \
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
      }" > /dev/null
    echo "✅ Pages project created"
fi

# Upload files to Pages
echo ""
echo "Uploading files via wrangler..."
if ! command -v npx >/dev/null 2>&1; then
    echo "❌ npx not found — install Node.js to enable file upload"
    exit 1
fi
CLOUDFLARE_API_TOKEN="$CLOUDFLARE_API_TOKEN" \
CLOUDFLARE_ACCOUNT_ID="$CLOUDFLARE_ACCOUNT_ID" \
  npx --yes wrangler@latest pages deploy "$GAME_DIR" \
    --project-name="$GAME_NAME" \
    --branch="$BRANCH" \
    --commit-dirty=true

# Add DNS record
echo ""
echo "Setting up DNS..."
./scripts/add-dns.sh "$GAME_NAME"

# Attach custom domain to the Pages project (idempotent)
CUSTOM_DOMAIN="${GAME_NAME}.finley.lol"
echo ""
echo "Attaching custom domain ${CUSTOM_DOMAIN} to Pages project..."
DOMAIN_ATTACHED=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/pages/projects/${GAME_NAME}/domains" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
target = '${CUSTOM_DOMAIN}'
attached = any(x.get('name') == target for x in d.get('result', []))
print('true' if attached else 'false')
")

if [ "$DOMAIN_ATTACHED" = "true" ]; then
    echo "✅ Custom domain already attached"
else
    curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/pages/projects/${GAME_NAME}/domains" \
      -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"${CUSTOM_DOMAIN}\"}" > /dev/null
    echo "✅ Custom domain attached (cert provisioning may take ~30–90s)"
fi

echo ""
echo "=== Deploy Complete ==="
echo ""
echo "Visit: https://${CUSTOM_DOMAIN}"
