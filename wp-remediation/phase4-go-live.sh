#!/usr/bin/env bash
# =============================================================================
# phase4-go-live.sh
#
# Phase 4 — Bring WordPress site back online after remediation.
# Run on the server via SSH from the WordPress root directory.
#
# Usage:
#   chmod +x phase4-go-live.sh
#   cd /path/to/wordpress
#   ./phase4-go-live.sh [wp-root-path]
# =============================================================================

set -euo pipefail

WP_ROOT="${1:-.}"
SEPARATOR="======================================================================"

section() {
    echo ""
    echo "$SEPARATOR"
    echo "  $1"
    echo "$SEPARATOR"
}

if [ ! -f "$WP_ROOT/wp-config.php" ]; then
    echo "ERROR: wp-config.php not found in '$WP_ROOT'."
    exit 1
fi

echo ""
echo "  WordPress Go-Live Checklist"
echo "  Target: $(cd "$WP_ROOT" && pwd)"
echo "  Date:   $(date)"
echo ""

# -------------------------------------------------------------------------
section "4.1 — Remove Maintenance Mode"
# -------------------------------------------------------------------------

HTACCESS="$WP_ROOT/.htaccess"

if [ -f "$HTACCESS" ]; then
    if grep -q "BEGIN MAINTENANCE MODE" "$HTACCESS" 2>/dev/null; then
        echo "  Found maintenance mode block in .htaccess."
        echo "  Removing it now..."

        # Remove the maintenance mode block
        sed -i.bak '/--- BEGIN MAINTENANCE MODE ---/,/--- END MAINTENANCE MODE ---/d' "$HTACCESS"
        echo "  Maintenance mode removed. Backup saved as .htaccess.bak"
    else
        echo "  No maintenance mode block found in .htaccess. (OK)"
        echo "  If you used Cloudflare/hosting panel to block, undo that manually."
    fi
else
    echo "  .htaccess not found. If you blocked via Cloudflare/hosting panel,"
    echo "  undo that block manually now."
fi

if command -v wp &>/dev/null; then
    wp maintenance-mode deactivate --path="$WP_ROOT" 2>/dev/null || true
fi

# -------------------------------------------------------------------------
section "4.2 — Verify Site Loads Correctly"
# -------------------------------------------------------------------------

SITEURL=""
if command -v wp &>/dev/null; then
    SITEURL=$(wp option get siteurl --path="$WP_ROOT" 2>/dev/null || echo "")
fi

if [ -n "$SITEURL" ]; then
    echo "  Site URL: $SITEURL"
    echo ""
    echo "  Testing connectivity..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$SITEURL" 2>/dev/null || echo "000")
    echo "  HTTP Response: $HTTP_CODE"
    if [ "$HTTP_CODE" = "200" ]; then
        echo "  Site is responding with 200 OK."
    elif [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        echo "  Site is redirecting (check that it goes to the right place)."
    else
        echo "  [!] Unexpected response code. Check the site manually."
    fi
else
    echo "  Could not determine site URL. Verify manually by visiting your domain."
fi

# -------------------------------------------------------------------------
section "4.3 — Checklist (verify manually)"
# -------------------------------------------------------------------------

echo "  [ ] Homepage loads without malicious banners or captcha"
echo "  [ ] Admin login works at /wp-admin/"
echo "  [ ] No unexpected redirects on any page"
echo "  [ ] Check 3-5 random pages/posts for injected content"
echo "  [ ] Check that forms (contact, login, registration) still work"
echo "  [ ] Verify SSL certificate is valid (padlock icon in browser)"
echo "  [ ] Check browser console (F12) for suspicious external script loads"
echo ""

# -------------------------------------------------------------------------
section "4.4 — Google Search Console (if site was flagged)"
# -------------------------------------------------------------------------

echo "  If Google flagged your site as compromised:"
echo ""
echo "  1. Go to https://search.google.com/search-console"
echo "  2. Select your property"
echo "  3. Navigate to Security & Manual Actions > Security Issues"
echo "  4. Click 'Request a Review'"
echo "  5. Describe the cleanup steps you performed"
echo ""
echo "  Google typically responds within 1-3 business days."
echo ""

# -------------------------------------------------------------------------
section "4.5 — Monitor Going Forward"
# -------------------------------------------------------------------------

echo "  For the next 7-14 days, regularly check:"
echo ""
echo "  1. Server access logs for suspicious requests:"
echo "     tail -f /var/log/apache2/access.log | grep -i 'wp-login\|xmlrpc\|eval\|base64'"
echo "     (adjust path for your server: nginx uses /var/log/nginx/access.log)"
echo ""
echo "  2. Wordfence dashboard for new alerts"
echo ""
echo "  3. WP Dashboard > Users for new unknown accounts"
echo ""
echo "  4. File modification monitoring (Wordfence does this automatically)"
echo ""
echo "  5. Google Search Console for any new security warnings"
echo ""

# -------------------------------------------------------------------------
section "ALL PHASES COMPLETE"
# -------------------------------------------------------------------------

echo ""
echo "  Remediation is complete. Summary of what was done:"
echo ""
echo "    Phase 1: Blocked public access during cleanup"
echo "    Phase 2: Removed hacker access (credentials, users, plugins, backdoors)"
echo "    Phase 3: Verified integrity, cleaned database, hardened installation"
echo "    Phase 4: Brought site back online with monitoring"
echo ""
echo "  Keep your WordPress, plugins, and themes updated at all times."
echo "  Regular backups + security plugin + 2FA = strong defense."
echo ""

exit 0
