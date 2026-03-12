#!/bin/bash
# Add DNS record for a new game subdomain
# Usage: ./scripts/add-dns.sh <game-name>

set -e

if [ -z "$1" ]; then
    echo "Usage: ./scripts/add-dns.sh <game-name>"
    exit 1
fi

GAME_NAME="$1"
DOMAIN="finley.lol"

# Load API token
if [ -f .cloudflare.env ]; then
    source .cloudflare.env
fi

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "❌ CLOUDFLARE_API_TOKEN not found in .cloudflare.env"
    echo ""
    echo "Create .cloudflare.env with your API token:"
    echo "  CLOUDFLARE_API_TOKEN=your-token-here"
    exit 1
fi

# Get zone ID
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('success') and data.get('result'):
    print(data['result'][0]['id'])
else:
    print('', file=sys.stderr)
    sys.exit(1)
")

if [ -z "$ZONE_ID" ]; then
    echo "❌ Could not find zone ID for ${DOMAIN}"
    exit 1
fi

echo "Adding DNS record: ${GAME_NAME}.${DOMAIN} → ${GAME_NAME}.pages.dev"

# Create DNS record
RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"CNAME\",
    \"name\": \"${GAME_NAME}\",
    \"content\": \"${GAME_NAME}.pages.dev\",
    \"ttl\": 1,
    \"proxied\": true
  }")

if echo "$RESPONSE" | python3 -c "import sys,json; sys.exit(0 if json.load(sys.stdin).get('success') else 1)"; then
    echo "✅ DNS record created successfully"
else
    echo "❌ Failed to create DNS record"
    echo "$RESPONSE" | python3 -m json.tool
    exit 1
fi
