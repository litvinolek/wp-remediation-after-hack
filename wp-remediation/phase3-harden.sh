#!/usr/bin/env bash
# =============================================================================
# phase3-harden.sh
#
# Phase 3.6 — Harden WordPress after cleanup.
# Run on the server via SSH from the WordPress root directory.
#
# Usage:
#   chmod +x phase3-harden.sh
#   cd /path/to/wordpress
#   ./phase3-harden.sh [wp-root-path]
#
#   DRY_RUN=1 ./phase3-harden.sh   # preview only
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

echo ""
echo "  WordPress Hardening Script"
echo "  Target: $(cd "$WP_ROOT" && pwd)"
echo "  Date:   $(date)"
echo "  Mode:   $([ "$DRY_RUN" = "1" ] && echo "DRY RUN" || echo "LIVE")"
echo ""

# -------------------------------------------------------------------------
section "3.6a — Update WordPress Core, Plugins, and Themes"
# -------------------------------------------------------------------------

if command -v wp &>/dev/null; then
    if [ "$DRY_RUN" = "1" ]; then
        echo "  DRY RUN — would run:"
        echo "    wp core update"
        echo "    wp plugin update --all"
        echo "    wp theme update --all"
    else
        echo "  Updating WordPress core..."
        wp core update --path="$WP_ROOT" 2>&1 || echo "  (core update failed — check manually)"

        echo ""
        echo "  Updating all plugins..."
        wp plugin update --all --path="$WP_ROOT" 2>&1 || echo "  (some plugin updates may have failed)"

        echo ""
        echo "  Updating all themes..."
        wp theme update --all --path="$WP_ROOT" 2>&1 || echo "  (some theme updates may have failed)"
    fi
else
    echo "  WP-CLI not available. Update manually from WP Dashboard > Updates."
fi

# -------------------------------------------------------------------------
section "3.6b — Remove Unused Themes and Plugins"
# -------------------------------------------------------------------------

if command -v wp &>/dev/null; then
    echo "  Inactive plugins:"
    wp plugin list --status=inactive --path="$WP_ROOT" --format=table 2>/dev/null || true
    echo ""
    echo "  Inactive themes:"
    wp theme list --status=inactive --path="$WP_ROOT" --format=table 2>/dev/null || true
    echo ""
    echo "  >> DELETE any inactive theme/plugin you don't need:"
    echo "     wp plugin delete <slug> --path=$WP_ROOT"
    echo "     wp theme delete <slug> --path=$WP_ROOT"
else
    echo "  WP-CLI not available. Remove inactive plugins/themes from WP Dashboard."
fi

# -------------------------------------------------------------------------
section "3.6c — Fix File Permissions"
# -------------------------------------------------------------------------

echo "  Setting directory permissions to 755..."
if [ "$DRY_RUN" = "1" ]; then
    echo "  DRY RUN — would run: find $WP_ROOT -type d -exec chmod 755 {} \\;"
else
    find "$WP_ROOT" -type d -exec chmod 755 {} \;
    echo "  Done."
fi

echo "  Setting file permissions to 644..."
if [ "$DRY_RUN" = "1" ]; then
    echo "  DRY RUN — would run: find $WP_ROOT -type f -exec chmod 644 {} \\;"
else
    find "$WP_ROOT" -type f -exec chmod 644 {} \;
    echo "  Done."
fi

echo "  Locking down wp-config.php to 400..."
if [ "$DRY_RUN" = "1" ]; then
    echo "  DRY RUN — would run: chmod 400 $WP_ROOT/wp-config.php"
else
    chmod 400 "$WP_ROOT/wp-config.php"
    echo "  Done."
fi

# -------------------------------------------------------------------------
section "3.6d — Disable File Editing from Dashboard"
# -------------------------------------------------------------------------

WPCONFIG="$WP_ROOT/wp-config.php"

if grep -q "DISALLOW_FILE_EDIT" "$WPCONFIG" 2>/dev/null; then
    echo "  DISALLOW_FILE_EDIT already set in wp-config.php. (OK)"
else
    if [ "$DRY_RUN" = "1" ]; then
        echo "  DRY RUN — would add: define('DISALLOW_FILE_EDIT', true); to wp-config.php"
    else
        # Temporarily make wp-config.php writable for this edit
        chmod 644 "$WPCONFIG"
        # Insert before the "That's all, stop editing!" line or at end of file
        if grep -q "stop editing" "$WPCONFIG" 2>/dev/null; then
            sed -i.bak "/stop editing/i\\
define('DISALLOW_FILE_EDIT', true);" "$WPCONFIG"
        else
            echo "define('DISALLOW_FILE_EDIT', true);" >> "$WPCONFIG"
        fi
        chmod 400 "$WPCONFIG"
        echo "  Added DISALLOW_FILE_EDIT to wp-config.php."
    fi
fi

# -------------------------------------------------------------------------
section "3.6e — Install Security Plugin (Wordfence)"
# -------------------------------------------------------------------------

if command -v wp &>/dev/null; then
    if wp plugin is-installed wordfence --path="$WP_ROOT" 2>/dev/null; then
        echo "  Wordfence is already installed."
    else
        if [ "$DRY_RUN" = "1" ]; then
            echo "  DRY RUN — would install Wordfence."
        else
            echo "  Installing Wordfence security plugin..."
            wp plugin install wordfence --activate --path="$WP_ROOT" 2>&1 || echo "  (install failed — install manually from WP Dashboard)"
        fi
    fi
    echo ""
    echo "  After installing, run a full Wordfence scan from the WP Dashboard."
    echo "  Also recommended: enable Wordfence 2FA for all admin accounts."
else
    echo "  WP-CLI not available. Install Wordfence manually:"
    echo "  WP Dashboard > Plugins > Add New > search 'Wordfence'"
fi

# -------------------------------------------------------------------------
section "3.6f — Additional Hardening Recommendations"
# -------------------------------------------------------------------------

echo "  Manual steps to complete:"
echo ""
echo "  1. Enable Two-Factor Authentication (2FA) for all admin accounts."
echo "     - Wordfence has built-in 2FA support."
echo "     - Alternatively: install 'Two Factor Authentication' plugin."
echo ""
echo "  2. If your database table prefix is 'wp_', consider changing it."
echo "     (This reduces exposure to automated SQL injection attacks.)"
echo ""
echo "  3. Block XML-RPC if not needed (add to .htaccess):"
echo "     <Files xmlrpc.php>"
echo "       Order Deny,Allow"
echo "       Deny from all"
echo "     </Files>"
echo ""
echo "  4. Block direct access to wp-includes (add to .htaccess):"
echo "     <IfModule mod_rewrite.c>"
echo "       RewriteEngine On"
echo "       RewriteBase /"
echo "       RewriteRule ^wp-admin/includes/ - [F,L]"
echo "       RewriteRule !^wp-includes/ - [S=3]"
echo "       RewriteRule ^wp-includes/[^/]+\\.php$ - [F,L]"
echo "       RewriteRule ^wp-includes/js/tinymce/langs/.+\\.php - [F,L]"
echo "       RewriteRule ^wp-includes/theme-compat/ - [F,L]"
echo "     </IfModule>"
echo ""
echo "  5. Set up regular automated backups (UpdraftPlus or hosting-level)."
echo ""
echo "  6. Monitor access logs for the next 7-14 days."
echo ""

# -------------------------------------------------------------------------
section "DONE — Hardening Complete"
# -------------------------------------------------------------------------

echo ""
echo "  Next: Proceed to Phase 4 — bring the site back online."
echo ""

exit 0
