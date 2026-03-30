#!/usr/bin/env bash
# =============================================================================
# phase2-scan-backdoors.sh
#
# Scans a WordPress installation for common backdoor indicators.
# Run this on the server via SSH from the WordPress root directory.
#
# Usage:
#   chmod +x phase2-scan-backdoors.sh
#   cd /path/to/wordpress
#   ./phase2-scan-backdoors.sh [wp-root-path]
#
# If no path is given, defaults to the current directory.
# =============================================================================

set -euo pipefail

WP_ROOT="${1:-.}"
SEPARATOR="======================================================================"
WARN_COUNT=0

warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    echo "  [!] $1"
}

section() {
    echo ""
    echo "$SEPARATOR"
    echo "  $1"
    echo "$SEPARATOR"
}

if [ ! -f "$WP_ROOT/wp-config.php" ]; then
    echo "ERROR: wp-config.php not found in '$WP_ROOT'."
    echo "       Make sure you're running this from the WordPress root directory,"
    echo "       or pass the path as an argument."
    exit 1
fi

echo ""
echo "  WordPress Backdoor Scanner"
echo "  Target: $(cd "$WP_ROOT" && pwd)"
echo "  Date:   $(date)"
echo ""

# -------------------------------------------------------------------------
section "2.3 — Suspicious Plugins"
# -------------------------------------------------------------------------

echo "  Listing all plugins in wp-content/plugins/:"
echo ""
ls -la "$WP_ROOT/wp-content/plugins/" 2>/dev/null || echo "  (directory not found)"
echo ""
echo "  >> Review the list above. Remove any plugin you did not install."

echo ""
echo "  Checking wp-content/mu-plugins/ (must-use plugins — often used to hide malware):"
echo ""
if [ -d "$WP_ROOT/wp-content/mu-plugins" ]; then
    ls -la "$WP_ROOT/wp-content/mu-plugins/"
    MU_COUNT=$(find "$WP_ROOT/wp-content/mu-plugins" -name '*.php' | wc -l | tr -d ' ')
    if [ "$MU_COUNT" -gt 0 ]; then
        warn "Found $MU_COUNT PHP file(s) in mu-plugins — inspect each one carefully."
    fi
else
    echo "  (mu-plugins directory does not exist — OK)"
fi

# -------------------------------------------------------------------------
section "2.4a — PHP Files in Uploads Directory"
# -------------------------------------------------------------------------

echo "  There should be almost no .php files in wp-content/uploads/."
echo ""
PHP_IN_UPLOADS=$(find "$WP_ROOT/wp-content/uploads" -name '*.php' 2>/dev/null)
if [ -n "$PHP_IN_UPLOADS" ]; then
    echo "$PHP_IN_UPLOADS"
    COUNT=$(echo "$PHP_IN_UPLOADS" | wc -l | tr -d ' ')
    warn "Found $COUNT PHP file(s) in uploads — these are almost certainly malicious. DELETE THEM."
else
    echo "  None found. (OK)"
fi

# -------------------------------------------------------------------------
section "2.4b — Known Fake Core Files in WP Root"
# -------------------------------------------------------------------------

FAKE_FILES=(
    "wp-tmp.php"
    "wp-feed.php"
    "wp-vcd.php"
    "class-wp-cache.php"
    "wp-config.bak.php"
    "db.php"
    "wp-options.php"
    "wp-user.php"
    "wp-info.php"
    "about.php"
    "admin.php"
    "content.php"
    "social.php"
)

for f in "${FAKE_FILES[@]}"; do
    if [ -f "$WP_ROOT/$f" ]; then
        warn "Suspicious file in root: $f — NOT a standard WP core file. INSPECT/DELETE."
    fi
done

echo "  Scan of root for known fake filenames complete."

# -------------------------------------------------------------------------
section "2.4c — Obfuscated Code Patterns (eval, base64_decode, etc.)"
# -------------------------------------------------------------------------

PATTERNS=("eval(" "base64_decode(" "gzinflate(" "str_rot13(" "gzuncompress(" "rawurldecode(" "assert(" "preg_replace.*\/e" "create_function(" "call_user_func(" "\\\$GLOBALS\[" "file_put_contents.*php")

for pattern in "${PATTERNS[@]}"; do
    MATCHES=$(grep -rl "$pattern" "$WP_ROOT/wp-content/" 2>/dev/null | head -50 || true)
    if [ -n "$MATCHES" ]; then
        warn "Pattern '$pattern' found in:"
        echo "$MATCHES" | while read -r line; do echo "       $line"; done
    fi
done

echo ""
echo "  Obfuscation pattern scan complete."

# -------------------------------------------------------------------------
section "2.4d — Recently Modified PHP Files (last 7 days)"
# -------------------------------------------------------------------------

RECENT=$(find "$WP_ROOT" -name '*.php' -mtime -7 2>/dev/null | head -100)
if [ -n "$RECENT" ]; then
    echo "$RECENT"
    COUNT=$(echo "$RECENT" | wc -l | tr -d ' ')
    warn "Found $COUNT PHP file(s) modified in the last 7 days — review each one."
else
    echo "  No PHP files modified in the last 7 days. (OK)"
fi

# -------------------------------------------------------------------------
section "2.4e — Files with Suspicious Permissions (world-writable)"
# -------------------------------------------------------------------------

WRITABLE=$(find "$WP_ROOT" -type f -perm -o+w -name '*.php' 2>/dev/null | head -50)
if [ -n "$WRITABLE" ]; then
    echo "$WRITABLE"
    COUNT=$(echo "$WRITABLE" | wc -l | tr -d ' ')
    warn "Found $COUNT world-writable PHP file(s) — fix permissions (644)."
else
    echo "  No world-writable PHP files found. (OK)"
fi

# -------------------------------------------------------------------------
section "2.4f — Hidden Files and Directories"
# -------------------------------------------------------------------------

HIDDEN=$(find "$WP_ROOT/wp-content" -name '.*' -not -name '.htaccess' 2>/dev/null | head -50)
if [ -n "$HIDDEN" ]; then
    echo "$HIDDEN"
    COUNT=$(echo "$HIDDEN" | wc -l | tr -d ' ')
    warn "Found $COUNT hidden file(s)/dir(s) in wp-content — inspect these."
else
    echo "  No suspicious hidden files found. (OK)"
fi

# -------------------------------------------------------------------------
section "2.5 — Cron Jobs (WP-CLI)"
# -------------------------------------------------------------------------

if command -v wp &>/dev/null; then
    echo "  WP-CLI found. Listing cron events:"
    echo ""
    wp cron event list --path="$WP_ROOT" 2>/dev/null || echo "  (wp cron list failed — check WP-CLI installation)"
    echo ""
    echo "  >> Review for unfamiliar hook names or URLs."
else
    echo "  WP-CLI not found. Check cron manually via SQL:"
    echo "  SELECT option_value FROM wp_options WHERE option_name = 'cron';"
fi

# -------------------------------------------------------------------------
section "SCAN SUMMARY"
# -------------------------------------------------------------------------

if [ "$WARN_COUNT" -gt 0 ]; then
    echo ""
    echo "  *** $WARN_COUNT WARNING(S) FOUND ***"
    echo "  Review each [!] warning above and take action."
    echo ""
else
    echo ""
    echo "  No warnings. The filesystem looks clean."
    echo "  Still recommended: run 'wp core verify-checksums' (Phase 3)."
    echo ""
fi

exit 0
