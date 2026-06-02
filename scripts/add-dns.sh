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

DNS_NAME="${GAME_NAME}.${DOMAIN}"

# Determine the real Pages subdomain. Cloudflare appends a suffix (e.g. dinos-14u)
# when the bare <name>.pages.dev is already taken by another account. Pointing the
# CNAME at the bare name in that case causes Error 1014 (CNAME Cross-User Banned).
TARGET="${GAME_NAME}.pages.dev"
if [ -n "$CLOUDFLARE_ACCOUNT_ID" ]; then
    REAL_SUBDOMAIN=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/pages/projects/${GAME_NAME}" \
      -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      -H "Content-Type: application/json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',{}).get('subdomain','') if d.get('success') else '')")
    if [ -n "$REAL_SUBDOMAIN" ]; then
        TARGET="$REAL_SUBDOMAIN"
    fi
fi

echo "Adding/updating DNS record: ${DNS_NAME} → ${TARGET}"

# Check if record exists
RECORD_EXISTS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${DNS_NAME}" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" | python3 -c "import sys,json; r=json.load(sys.stdin); print('true' if r.get('success') and r.get('result') and len(r['result']) > 0 else 'false')")

if [ "$RECORD_EXISTS" = "true" ]; then
    # Get the record ID and update it
    RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${DNS_NAME}" \
      -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      -H "Content-Type: application/json" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['result'][0]['id'] if r.get('success') and r.get('result') else '')")

    if [ -n "$RECORD_ID" ]; then
        curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
          -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "{
            \"content\": \"${TARGET}\",
            \"proxied\": true
          }" > /dev/null
        echo "✅ DNS record updated"
    else
        echo "⚠️  Could not find record ID"
    fi
else
    # Create new record
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
      -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{
        \"type\": \"CNAME\",
        \"name\": \"${GAME_NAME}\",
        \"content\": \"${TARGET}\",
        \"ttl\": 1,
        \"proxied\": true
      }" > /dev/null
    echo "✅ DNS record created"
fi
