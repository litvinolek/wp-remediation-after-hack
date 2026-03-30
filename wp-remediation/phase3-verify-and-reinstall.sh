#!/usr/bin/env bash
# =============================================================================
# phase3-verify-and-reinstall.sh
#
# Phase 3 — Verify WordPress integrity and reinstall clean copies.
# Run on the server via SSH from the WordPress root directory.
#
# Prerequisites:
#   - WP-CLI installed (https://wp-cli.org)
#   - SSH access to the server
#
# Usage:
#   chmod +x phase3-verify-and-reinstall.sh
#   cd /path/to/wordpress
#   ./phase3-verify-and-reinstall.sh [wp-root-path]
#
#   DRY_RUN=1 ./phase3-verify-and-reinstall.sh   # preview only
# =============================================================================

set -euo pipefail

WP_ROOT="${1:-.}"
DRY_RUN="${DRY_RUN:-0}"
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

if ! command -v wp &>/dev/null; then
    echo "ERROR: WP-CLI (wp) not found. Install it first:"
    echo "  curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"
    echo "  chmod +x wp-cli.phar && sudo mv wp-cli.phar /usr/local/bin/wp"
    exit 1
fi

echo ""
echo "  WordPress Integrity Verification & Reinstall"
echo "  Target: $(cd "$WP_ROOT" && pwd)"
echo "  Date:   $(date)"
echo "  Mode:   $([ "$DRY_RUN" = "1" ] && echo "DRY RUN (no changes)" || echo "LIVE")"
echo ""

# -------------------------------------------------------------------------
section "3.1 — Verify Core File Checksums"
# -------------------------------------------------------------------------

echo "  Comparing core files against official WordPress checksums..."
echo ""
wp core verify-checksums --path="$WP_ROOT" 2>&1 || true
echo ""
echo "  Any file listed above has been modified and should be replaced."

# -------------------------------------------------------------------------
section "3.2 — Verify Plugin Checksums (wordpress.org plugins only)"
# -------------------------------------------------------------------------

echo "  Comparing plugin files against official checksums..."
echo ""
wp plugin verify-checksums --all --path="$WP_ROOT" 2>&1 || true
echo ""
echo "  Plugins not in the wordpress.org repository will show an error —"
echo "  compare those manually against the vendor's distribution."

# -------------------------------------------------------------------------
section "3.4 — Audit .htaccess"
# -------------------------------------------------------------------------

HTACCESS="$WP_ROOT/.htaccess"
if [ -f "$HTACCESS" ]; then
    echo "  Contents of .htaccess (review for suspicious redirects):"
    echo "  --------------------------------------------------------"
    cat "$HTACCESS"
    echo ""
    echo "  --------------------------------------------------------"
    echo "  Look for: redirects to external domains, unfamiliar RewriteRules,"
    echo "  base64-encoded strings, or php_value directives."
else
    echo "  .htaccess not found — this is unusual for Apache-hosted WordPress."
fi

# -------------------------------------------------------------------------
section "3.4 — Audit wp-config.php for injected code"
# -------------------------------------------------------------------------

echo "  Scanning wp-config.php for suspicious patterns..."
echo ""

WPCONFIG="$WP_ROOT/wp-config.php"
SUSPICIOUS_PATTERNS=("eval(" "base64_decode(" "gzinflate(" "file_get_contents(" "curl_exec(" "str_rot13(" "@include" "assert(")

FOUND=0
for pattern in "${SUSPICIOUS_PATTERNS[@]}"; do
    MATCH=$(grep -n "$pattern" "$WPCONFIG" 2>/dev/null || true)
    if [ -n "$MATCH" ]; then
        echo "  [!] Found '$pattern' in wp-config.php:"
        echo "      $MATCH"
        FOUND=1
    fi
done

if [ "$FOUND" -eq 0 ]; then
    echo "  No suspicious patterns found in wp-config.php. (OK)"
fi

echo ""
echo "  Also verify DB_HOST, DB_NAME, DB_USER, DB_PASSWORD point to your server."

# -------------------------------------------------------------------------
section "3.5 — Reinstall Clean Copies"
# -------------------------------------------------------------------------

if [ "$DRY_RUN" = "1" ]; then
    echo "  DRY RUN — would execute the following commands:"
    echo ""
    echo "    wp core download --force --path=$WP_ROOT"
    echo "    wp plugin install <each-plugin> --force --path=$WP_ROOT"
    echo "    wp theme install <each-theme> --force --path=$WP_ROOT"
    echo ""
    echo "  Set DRY_RUN=0 to execute for real."
else
    echo "  Reinstalling WordPress core (overwrites wp-admin/ and wp-includes/)..."
    wp core download --force --path="$WP_ROOT"
    echo ""
    echo "  Core reinstalled."
    echo ""
    echo "  Reinstalling all wordpress.org plugins..."
    wp plugin list --path="$WP_ROOT" --format=csv --fields=name,status 2>/dev/null | tail -n +2 | while IFS=',' read -r name status; do
        if [ "$status" != "dropin" ]; then
            echo "    Reinstalling plugin: $name"
            wp plugin install "$name" --force --path="$WP_ROOT" 2>/dev/null || echo "    (could not reinstall $name — may be a premium/custom plugin)"
        fi
    done

    echo ""
    echo "  Reinstalling themes..."
    wp theme list --path="$WP_ROOT" --format=csv --fields=name 2>/dev/null | tail -n +2 | while IFS=',' read -r name; do
        echo "    Reinstalling theme: $name"
        wp theme install "$name" --force --path="$WP_ROOT" 2>/dev/null || echo "    (could not reinstall $name — may be a premium/custom theme)"
    done
fi

echo ""
echo "  Reinstall phase complete."

# -------------------------------------------------------------------------
section "DONE — Phase 3 Complete"
# -------------------------------------------------------------------------

echo ""
echo "  Next steps:"
echo "    1. Run phase3-harden.sh to lock down the installation."
echo "    2. Run phase3-db-audit.sql in phpMyAdmin to check the database."
echo "    3. Proceed to Phase 4 (go live) when everything is clean."
echo ""

exit 0
