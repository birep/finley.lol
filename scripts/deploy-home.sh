#!/bin/bash
# Deploy the landing page (home/) to Cloudflare Pages at the apex domain finley.lol
# Usage: ./scripts/deploy-home.sh [branch]

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANCH="${1:-master}"
PROJECT_NAME="finley-lol"
HOME_DIR="home"
DOMAIN="finley.lol"

cd "$PROJECT_DIR"

if [ ! -f "$HOME_DIR/index.html" ]; then
    echo "❌ No index.html found in $HOME_DIR"
    exit 1
fi

# Load config
if [ -f .cloudflare.env ]; then
    source .cloudflare.env
fi
if [ -z "$CLOUDFLARE_API_TOKEN" ] || [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
    echo "❌ CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID not found in .cloudflare.env"
    exit 1
fi

echo "=== Cloudflare Pages Deploy: landing page ==="

# Commit + push
if [ -n "$(git status --porcelain)" ]; then
    echo "Committing changes..."
    git add .
    git commit -m "Deploy landing page"
fi
if git remote get-url origin >/dev/null 2>&1; then
    git push origin "$BRANCH"
fi

# Create Pages project if missing
PROJECT_EXISTS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/pages/projects/${PROJECT_NAME}" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" | python3 -c "import sys,json; print('true' if json.load(sys.stdin).get('success') else 'false')")

if [ "$PROJECT_EXISTS" != "true" ]; then
    curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/pages/projects" \
      -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{
        \"name\": \"${PROJECT_NAME}\",
        \"production_branch\": \"${BRANCH}\",
        \"build_config\": {
          \"build_command\": \"echo 'Static HTML - no build step'\",
          \"destination_dir\": \"${HOME_DIR}\",
          \"root_dir\": \".\"
        }
      }" > /dev/null
    echo "✅ Pages project created"
fi

# Upload files
CLOUDFLARE_API_TOKEN="$CLOUDFLARE_API_TOKEN" \
CLOUDFLARE_ACCOUNT_ID="$CLOUDFLARE_ACCOUNT_ID" \
  npx --yes wrangler@latest pages deploy "$HOME_DIR" \
    --project-name="$PROJECT_NAME" \
    --branch="$BRANCH" \
    --commit-dirty=true

# Apex DNS record: CNAME @ -> <project>.pages.dev (Cloudflare flattens at apex)
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d['result'][0]['id'] if d.get('success') and d.get('result') else '')")

if [ -n "$ZONE_ID" ]; then
    EXISTING=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${DOMAIN}&type=CNAME" \
      -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('true' if d.get('result') else 'false')")
    if [ "$EXISTING" != "true" ]; then
        curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
          -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "{\"type\":\"CNAME\",\"name\":\"@\",\"content\":\"${PROJECT_NAME}.pages.dev\",\"proxied\":true}" > /dev/null
        echo "✅ Apex DNS record created"
    fi
fi

# Attach the apex custom domain to the Pages project (idempotent)
DOMAIN_ATTACHED=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/pages/projects/${PROJECT_NAME}/domains" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('true' if any(x.get('name') == '${DOMAIN}' for x in d.get('result', [])) else 'false')")

if [ "$DOMAIN_ATTACHED" != "true" ]; then
    curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/pages/projects/${PROJECT_NAME}/domains" \
      -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"${DOMAIN}\"}" > /dev/null
    echo "✅ Custom domain attached (cert provisioning may take ~30–90s)"
fi

echo ""
echo "=== Deploy Complete ==="
echo "Visit: https://${DOMAIN}"
