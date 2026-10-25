#!/bin/bash
# Toggle UniFi Protect "Color Night Vision" on one camera.
# Usage: cnv.sh on | off | state   (prints true or false; exits 1 on failure)

# Requires local user configured with access to Unifi console/Protect API:
# - In UniFi OS, go to Admins & Users and click Create New (or Add Admin).
# - Turn on Restrict to Local Access Only. This gives you a plain username and password with no UI.com sign-in or MFA.
# - Choose a username and a strong password, to be entered below.
# - Under app permissions, give Protect a role that can change camera settings, such as Full Management or a custom role that can edit cameras. A view-only role can log in and list cameras, but the PATCH will fail.

HOST="your.local.console.ip"  # e.g. 192.168.1.1
USERNAME="protect-api"
PASSWORD="CHANGE_ME"
CAMERA_ID="ENTER_CAMERA_ID" # Get this from the Protect web UI via https://your.local.console.ip/protect/devices > Click Camera > https://your.local.console.ip/protect/devices/CAMERA_ID_IS HERE

DIR="$(cd "$(dirname "$0")" && pwd)"
COOKIE="$DIR/.cnv-cookie"
CSRF_FILE="$DIR/.cnv-csrf"
URL="https://$HOST/proxy/protect/api/cameras/$CAMERA_ID"

fail() { echo "cnv: $*" >&2; exit 1; }

login() {
  local headers
  headers=$(curl -sk -m 10 -c "$COOKIE" -o /dev/null -D - -X POST "https://$HOST/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\",\"rememberMe\":true}")
  grep -i '^x-csrf-token:' <<<"$headers" | awk '{print $2}' | tr -d '\r' > "$CSRF_FILE"
  chmod 600 "$COOKIE" "$CSRF_FILE" 2>/dev/null
  [ -s "$CSRF_FILE" ] || fail "login failed"
}

# request METHOD [JSON] -> sets STATUS and BODY
request() {
  local args=(-sk -m 10 -b "$COOKIE" -H "X-CSRF-Token: $(cat "$CSRF_FILE")" -H "Content-Type: application/json" -X "$1" -w '\n%{http_code}')
  [ -n "$2" ] && args+=(-d "$2")
  local out
  out=$(curl "${args[@]}" "$URL")
  STATUS=${out##*$'\n'}
  BODY=${out%$'\n'*}
}

case "$1" in
  on)    METHOD=PATCH; WANT=true ;;
  off)   METHOD=PATCH; WANT=false ;;
  state) METHOD=GET;   WANT="" ;;
  *)     echo "usage: cnv.sh on | off | state" >&2; exit 2 ;;
esac
DATA=""
[ -n "$WANT" ] && DATA="{\"ispSettings\":{\"isColorNightVisionEnabled\":$WANT}}"

# Reuse the saved session; log in again if there is none or it has expired.
[ -s "$CSRF_FILE" ] || login
request "$METHOD" "$DATA"
if [ "$STATUS" = 401 ] || [ "$STATUS" = 403 ]; then
  login
  request "$METHOD" "$DATA"
fi
[ "$STATUS" = 200 ] || fail "$METHOD failed: HTTP $STATUS"

VALUE=$(grep -Eo '"isColorNightVisionEnabled": *(true|false)' <<<"$BODY" | grep -Eo 'true|false')
[ -n "$VALUE" ] || fail "isColorNightVisionEnabled not found in response"
[ -z "$WANT" ] || [ "$VALUE" = "$WANT" ] || fail "Protect accepted the request but the value is still $VALUE"
echo "$VALUE"
