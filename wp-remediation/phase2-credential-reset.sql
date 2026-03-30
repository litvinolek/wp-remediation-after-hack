-- =============================================================================
-- Phase 2.1 — Reset WordPress Admin Password
--
-- Run this in phpMyAdmin or MySQL CLI on your WordPress database.
--
-- Steps:
--   1. Replace 'your_admin_username' with your actual WP admin username.
--   2. Replace 'NEW_STRONG_PASSWORD_HERE' with a new strong password.
--   3. Execute the query.
--   4. After this, also change: DB password, FTP/SSH password, hosting panel
--      password, and regenerate WP salts (see instructions below).
-- =============================================================================

-- Reset admin password (MD5 is accepted by WP on first login, then re-hashed)
UPDATE wp_users
SET user_pass = MD5('NEW_STRONG_PASSWORD_HERE')
WHERE user_login = 'your_admin_username';

-- =============================================================================
-- Phase 2.2 — Find All Administrator Accounts
--
-- Review the output. Delete any user you do NOT recognize.
-- NOTE: If your table prefix is not 'wp_', replace 'wp_' with your prefix.
-- =============================================================================

SELECT u.ID, u.user_login, u.user_email, u.user_registered
FROM wp_users u
JOIN wp_usermeta m ON u.ID = m.user_id
WHERE m.meta_key = 'wp_capabilities'
  AND m.meta_value LIKE '%administrator%'
ORDER BY u.user_registered;

-- To delete a suspicious admin (replace 123 with the user's ID):
-- DELETE FROM wp_users WHERE ID = 123;
-- DELETE FROM wp_usermeta WHERE user_id = 123;

-- =============================================================================
-- IMPORTANT: After running these SQL queries, also do the following manually:
--
-- 1. Change the DATABASE password in your hosting panel, then update
--    DB_PASSWORD in wp-config.php to match.
--
-- 2. Change FTP/SFTP/SSH passwords in your hosting panel.
--
-- 3. Change your hosting panel password (cPanel, Plesk, etc.).
--
-- 4. Regenerate WordPress secret keys/salts:
--    Visit: https://api.wordpress.org/secret-key/1.1/salt/
--    Copy the output and replace the entire AUTH_KEY / SECURE_AUTH_KEY /
--    LOGGED_IN_KEY / NONCE_KEY / AUTH_SALT / SECURE_AUTH_SALT /
--    LOGGED_IN_SALT / NONCE_SALT block in wp-config.php.
--    This forces all sessions (including attacker's) to expire immediately.
-- =============================================================================
