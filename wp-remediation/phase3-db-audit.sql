-- =============================================================================
-- Phase 3.3 — Database Audit for Injected Content
--
-- Run these queries in phpMyAdmin or MySQL CLI against your WP database.
-- NOTE: If your table prefix is not 'wp_', replace 'wp_' throughout.
-- =============================================================================

-- -------------------------------------------------------------------------
-- 3.3a — Injected <script> tags in post content
-- -------------------------------------------------------------------------
SELECT ID, post_title, post_date, post_status,
       SUBSTRING(post_content, 1, 200) AS content_preview
FROM wp_posts
WHERE post_content LIKE '%<script%'
ORDER BY post_date DESC;

-- -------------------------------------------------------------------------
-- 3.3b — Injected <iframe> tags in post content
-- -------------------------------------------------------------------------
SELECT ID, post_title, post_date, post_status,
       SUBSTRING(post_content, 1, 200) AS content_preview
FROM wp_posts
WHERE post_content LIKE '%<iframe%'
ORDER BY post_date DESC;

-- -------------------------------------------------------------------------
-- 3.3c — Injected eval/base64 in post content
-- -------------------------------------------------------------------------
SELECT ID, post_title, post_date, post_status
FROM wp_posts
WHERE post_content LIKE '%eval(%'
   OR post_content LIKE '%base64_decode(%'
   OR post_content LIKE '%document.write(%';

-- -------------------------------------------------------------------------
-- 3.3d — Verify siteurl and home options (must point to YOUR domain)
-- -------------------------------------------------------------------------
SELECT option_name, option_value
FROM wp_options
WHERE option_name IN ('siteurl', 'home');

-- -------------------------------------------------------------------------
-- 3.3e — Check for suspicious active plugins list
-- -------------------------------------------------------------------------
SELECT option_value
FROM wp_options
WHERE option_name = 'active_plugins';
-- Review the serialized array for any plugin you did not install.

-- -------------------------------------------------------------------------
-- 3.3f — Check widget_text for injected HTML/JS
-- -------------------------------------------------------------------------
SELECT option_value
FROM wp_options
WHERE option_name = 'widget_text';

-- -------------------------------------------------------------------------
-- 3.3g — Check for suspicious option names (common malware patterns)
-- -------------------------------------------------------------------------
SELECT option_name, SUBSTRING(option_value, 1, 200) AS value_preview
FROM wp_options
WHERE option_name LIKE '%widget%inject%'
   OR option_name LIKE '%base64%'
   OR option_name LIKE '%eval%'
   OR option_name LIKE '%backdoor%'
   OR option_name LIKE '%redirect%'
   OR option_name LIKE '%hack%'
   OR option_name LIKE 'wp_check_%'
   OR option_name LIKE '_site_transient_browser_%'
ORDER BY option_name;

-- -------------------------------------------------------------------------
-- 3.3h — Check for injected content in comments
-- -------------------------------------------------------------------------
SELECT comment_ID, comment_author, comment_author_email,
       SUBSTRING(comment_content, 1, 200) AS content_preview
FROM wp_comments
WHERE comment_content LIKE '%<script%'
   OR comment_content LIKE '%<iframe%'
   OR comment_content LIKE '%eval(%';

-- -------------------------------------------------------------------------
-- 3.3i — Check for unknown users created recently (last 30 days)
-- -------------------------------------------------------------------------
SELECT u.ID, u.user_login, u.user_email, u.user_registered,
       m.meta_value AS capabilities
FROM wp_users u
JOIN wp_usermeta m ON u.ID = m.user_id AND m.meta_key = 'wp_capabilities'
WHERE u.user_registered >= DATE_SUB(NOW(), INTERVAL 30 DAY)
ORDER BY u.user_registered DESC;

-- -------------------------------------------------------------------------
-- 3.3j — Check WP cron for suspicious scheduled tasks
-- -------------------------------------------------------------------------
SELECT option_value
FROM wp_options
WHERE option_name = 'cron';
-- Deserialize and review. Look for unfamiliar hook names pointing to
-- external URLs or unknown callback functions.
