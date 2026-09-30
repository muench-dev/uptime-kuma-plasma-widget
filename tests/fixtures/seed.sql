-- Uptime Kuma Test Database Seed
-- Seeds a minimal test environment with admin user, status page, monitor, heartbeat, and API key.

-- Admin user
INSERT OR IGNORE INTO user (id, username, password, active) 
VALUES (1, 'admin', '$2a$10$6MvK7ugMTK.TUgpoAQpnEeUr1ydkXgYr0Z1nG2eyXydccO6cNfru.', 1);

-- Public Status Page (slug: 'default')
INSERT OR REPLACE INTO status_page (id, slug, title, description, icon, theme, published) 
VALUES (1, 'default', 'Production Services', 'Live status of our services', '/icon.svg', 'auto', 1);

-- Status page group
INSERT OR REPLACE INTO "group" (id, name, public, active, weight, status_page_id)
VALUES (1, 'Core Services', 1, 1, 1000, 1);

-- Monitor
INSERT OR REPLACE INTO monitor (id, name, active, interval, url, type, weight)
VALUES (1, 'Web Frontend', 1, 60, 'https://example.com', 'http', 1000);

-- Map monitor to group
INSERT OR REPLACE INTO monitor_group (id, monitor_id, group_id, weight)
VALUES (1, 1, 1, 1000);

-- Heartbeat entry
INSERT OR REPLACE INTO heartbeat (id, important, monitor_id, status, msg, time, ping, duration)
VALUES (1, 1, 1, 1, 'OK (200)', datetime('now'), 35, 35);

-- API key: uk1_mysecretkey
-- Prefix uk + ID (1) + _ + clear key (mysecretkey)
-- The stored hash is bcrypt of 'mysecretkey'
INSERT OR REPLACE INTO api_key (id, key, name, user_id, active) 
VALUES (1, '$2a$10$6MvK7ugMTK.TUgpoAQpnEeUr1ydkXgYr0Z1nG2eyXydccO6cNfru.', 'CI Test Key', 1, 1);

-- Enable API keys
INSERT OR REPLACE INTO setting (key, value) VALUES ('apiKeysEnabled', 'true');
