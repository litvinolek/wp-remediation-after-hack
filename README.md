# WordPress Hack Remediation Plan

---

## Phase 1 — Immediately Block Public Access (do this first)

Blocking the site prevents customers from seeing the malicious banner/captcha and stops the attacker's payload from spreading to visitors.

### Option A — Maintenance mode via `.htaccess` (fastest, no WP login needed)

Connect to the server via **SSH** or **SFTP** and edit (or create) the `.htaccess` file in the WordPress root directory. Add the following **at the very top**, before any existing rules:

```apache
RewriteEngine On
RewriteCond %{REMOTE_ADDR} !^YOUR\.IP\.ADDRESS$
RewriteRule ^(.*)$ - [R=503,L]
ErrorDocument 503 "Site is temporarily under maintenance."
```

Replace `YOUR\.IP\.ADDRESS` with your own IP (escape dots with `\`). This returns a 503 to everyone except you.

### Option B — Block at hosting / DNS level

- **Cloudflare / DNS proxy:** Enable "Under Attack Mode" or create a firewall rule that blocks all traffic except your IP.
- **Hosting panel (cPanel / Plesk):** Use "IP Blocker" or "Directory Privacy" to password-protect the entire site root.
- **If you have server-level access (nginx/Apache config):** add a `deny all; allow YOUR_IP;` block.

### Option C — `wp-cli` maintenance mode (requires SSH + working WP)

```bash
wp maintenance-mode activate --path=/path/to/wordpress
```

> Pick whichever option you have access to. Option A works in almost every shared-hosting scenario.

---

## Phase 2 — Remove Hacker Access

### 2.1 Change all credentials immediately

- **WordPress admin password** — change via phpMyAdmin if you cannot log in:

```sql
  UPDATE wp_users SET user_pass = MD5('NEW_STRONG_PASSWORD') WHERE user_login = 'your_admin_username';
  

```

- **Database password** — update in hosting panel, then update `DB_PASSWORD` in `wp-config.php`.
- **FTP / SFTP / SSH passwords** — change in your hosting panel.
- **Hosting panel password** (cPanel, Plesk, etc.).
- **WordPress secret keys / salts** — generate new ones at [https://api.wordpress.org/secret-key/1.1/salt/](https://api.wordpress.org/secret-key/1.1/salt/) and replace the block in `wp-config.php`. This invalidates all existing login cookies and forces everyone (including the attacker) to log out.

### 2.2 Remove unknown admin accounts

```sql
SELECT u.ID, u.user_login, u.user_email
FROM wp_users u
JOIN wp_usermeta m ON u.ID = m.user_id
WHERE m.meta_key = 'wp_capabilities'
  AND m.meta_value LIKE '%administrator%';
```

Delete any user you do not recognize.

### 2.3 Remove the suspicious plugin

- Via SFTP: delete its folder from `wp-content/plugins/`.
- Check for **other** unknown plugins in that directory — attackers often install more than one.
- Also check `wp-content/mu-plugins/` (must-use plugins) — malware is frequently hidden there.

### 2.4 Check for backdoor files

Common locations and patterns:


| What to look for                                                      | Where                                       |
| --------------------------------------------------------------------- | ------------------------------------------- |
| PHP files in `wp-content/uploads/`                                    | There should be almost no `.php` files here |
| Files named `wp-tmp.php`, `wp-feed.php`, `class-wp-cache.php` in root | These are not core WP files                 |
| Any file with `eval(`, `base64_decode(`, `gzinflate(`, `str_rot13(`   | Entire `wp-content/` and root               |
| Recently modified core files                                          | `wp-includes/`, `wp-admin/`                 |


Run these via SSH to find suspects:

```bash
# PHP files in uploads (should be nearly zero)
find wp-content/uploads -name '*.php'

# Files modified in the last 7 days
find . -name '*.php' -mtime -7

# Obfuscated code patterns
grep -rl 'eval(' wp-content/
grep -rl 'base64_decode(' wp-content/
grep -rl 'gzinflate(' wp-content/
```

### 2.5 Remove any rogue cron jobs

```bash
wp cron event list --path=/path/to/wordpress
```

Or check the `wp_options` table for the `cron` option:

```sql
SELECT option_value FROM wp_options WHERE option_name = 'cron';
```

Look for unfamiliar hook names or URLs. Delete any you do not recognize.

---

## Phase 3 — Validate and Harden WordPress

### 3.1 Verify core file integrity

```bash
wp core verify-checksums --path=/path/to/wordpress
```

This compares every core file against the official checksums. Any modified file will be listed — replace it from a clean WordPress download of the same version.

### 3.2 Verify plugin/theme integrity

```bash
wp plugin verify-checksums --all --path=/path/to/wordpress
```

For themes and plugins not in the WordPress.org repo, manually compare files against your original copies or the vendor's distribution.

### 3.3 Check the database for injected content

```sql
-- Look for script injections in posts
SELECT ID, post_title FROM wp_posts WHERE post_content LIKE '%<script%';
SELECT ID, post_title FROM wp_posts WHERE post_content LIKE '%<iframe%';

-- Look for suspicious options
SELECT option_name, option_value FROM wp_options
WHERE option_name LIKE '%siteurl%' OR option_name LIKE '%home%';
-- Verify these point to YOUR domain

-- Check for injected widgets
SELECT option_value FROM wp_options WHERE option_name = 'widget_text';
```

### 3.4 Check `.htaccess` and `wp-config.php`

- `.htaccess` — look for unfamiliar redirect rules (especially to external domains).
- `wp-config.php` — look for any `require`, `include`, or `eval` lines that should not be there.

### 3.5 Reinstall clean copies

```bash
wp core download --force --path=/path/to/wordpress
wp plugin install PLUGIN_SLUG --force   # for each legitimate plugin
wp theme install THEME_SLUG --force     # for your active theme
```

### 3.6 Harden going forward

- Update WordPress core, all plugins, and themes to latest versions.
- Delete unused themes and plugins entirely.
- Set file permissions: directories `755`, files `644`, `wp-config.php` to `440` or `400`.
- Install a security plugin (Wordfence or Sucuri) and run a full scan.
- Add two-factor authentication for all admin accounts.
- Disable file editing from the dashboard by adding to `wp-config.php`:

```php
  define('DISALLOW_FILE_EDIT', true);
  

```

- Consider changing the default database table prefix if it is still `wp_`.

---

## Phase 4 — Bring the Site Back Online

1. Remove the maintenance block you added in Phase 1.
2. Test the site thoroughly: visit every page, check for redirects, verify no banners/captchas appear.
3. Submit a malware review to Google if your site was flagged (via Google Search Console > Security Issues).
4. Monitor server logs (`access.log`, `error.log`) for the next few days for suspicious activity.

---

## Quick-Reference Checklist

- Block public access (Phase 1)
- Change all passwords and salts (Phase 2.1)
- Remove unknown admin users (Phase 2.2)
- Delete suspicious plugin(s) including `mu-plugins` (Phase 2.3)
- Scan for backdoor files in uploads, root, and `wp-content` (Phase 2.4)
- Remove rogue cron jobs (Phase 2.5)
- Verify core checksums and reinstall clean files (Phase 3.1, 3.5)
- Check database for injected scripts (Phase 3.3)
- Audit `.htaccess` and `wp-config.php` (Phase 3.4)
- Harden: update everything, enforce permissions, add 2FA (Phase 3.6)
- Bring site back online and monitor (Phase 4)

