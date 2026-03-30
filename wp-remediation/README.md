# WordPress Hack Remediation Toolkit

Scripts and SQL queries to systematically clean up and harden a compromised WordPress installation.

## Prerequisites

- SSH or SFTP access to the WordPress server
- phpMyAdmin or MySQL CLI access to the WordPress database
- [WP-CLI](https://wp-cli.org) installed on the server (optional but strongly recommended)

## Execution Order

Upload the entire wp-remediation/ folder to your WordPress server via SFTP/SCP
Execute in order following the table in the README
All shell scripts support DRY_RUN=1 to preview actions before making changes
SQL files should be run in phpMyAdmin or via mysql CLI

| Step | File | How to run |
|------|------|------------|
| 1 | `phase1-maintenance-htaccess.txt` | Paste contents at the top of `.htaccess` via SFTP |
| 2 | `phase2-credential-reset.sql` | Run in phpMyAdmin or MySQL CLI |
| 3 | `phase2-scan-backdoors.sh` | `cd /path/to/wp && bash phase2-scan-backdoors.sh` |
| 4 | `phase3-db-audit.sql` | Run in phpMyAdmin or MySQL CLI |
| 5 | `phase3-verify-and-reinstall.sh` | `cd /path/to/wp && bash phase3-verify-and-reinstall.sh` |
| 6 | `phase3-harden.sh` | `cd /path/to/wp && bash phase3-harden.sh` |
| 7 | `phase4-go-live.sh` | `cd /path/to/wp && bash phase4-go-live.sh` |

All shell scripts support a `DRY_RUN=1` environment variable to preview actions without making changes:

```bash
DRY_RUN=1 bash phase3-verify-and-reinstall.sh
DRY_RUN=1 bash phase3-harden.sh
```

## What Each Script Does

- **phase1-maintenance-htaccess.txt** — `.htaccess` rules that return 503 to all visitors except your IP, taking the site offline immediately.
- **phase2-credential-reset.sql** — Resets admin password, lists all administrator accounts for review.
- **phase2-scan-backdoors.sh** — Scans for PHP files in uploads, fake core files, obfuscated code patterns, recently modified files, world-writable files, and hidden files.
- **phase3-db-audit.sql** — Checks posts, options, comments, and users for injected scripts, iframes, eval calls, and suspicious entries.
- **phase3-verify-and-reinstall.sh** — Runs WP-CLI checksum verification on core and plugins, audits `.htaccess` and `wp-config.php`, and reinstalls clean copies.
- **phase3-harden.sh** — Updates everything, fixes file permissions, disables dashboard file editing, installs Wordfence, and prints additional hardening recommendations.
- **phase4-go-live.sh** — Removes maintenance mode, tests site connectivity, prints a manual verification checklist, and provides monitoring guidance.
