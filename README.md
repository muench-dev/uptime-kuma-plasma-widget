# Uptime Kuma Widget for KDE Plasma 6 🐻⚡

[![KDE Plasma 6](https://img.shields.io/badge/KDE%20Plasma-6.0%2B-blue?logo=kde&logoColor=white)](https://kde.org/plasma-desktop/)
[![Uptime Kuma](https://img.shields.io/badge/Uptime%20Kuma-1.x%20%7C%202.x-brightgreen?logo=uptime-kuma)](https://github.com/louislam/uptime-kuma)
[![Qt](https://img.shields.io/badge/Qt-6.6%2B-green?logo=qt&logoColor=white)](https://www.qt.io/)
[![KDE Store](https://img.shields.io/badge/KDE%20Store-2375420-blue?logo=kde&logoColor=white)](https://store.kde.org/p/2375420/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A beautiful, native **KDE Plasma 6** widget to monitor the status, response times, and health of your servers and services tracked by **[Uptime Kuma](https://github.com/louislam/uptime-kuma)** (compatible with **Uptime Kuma 1.x** and **2.x**).

Designed following the **KDE Human Interface Guidelines (HIG)** with smooth Breeze styling, responsive panel layouts, desktop widget support, and interactive heartbeat history bars.

---

## ✨ Features

- 🟢 **Live System Health Overview**:
  - Soft emerald header when all systems are operational.
  - High-visibility crimson alert banner with subtle pulsing indicator whenever an outage or degraded service is detected.
  - Quick summary metric cards: **Up count**, **Down count**, **Average Ping (ms)**, and **24h Uptime (%)**.
- 📊 **Signature Uptime Kuma Heartbeat Bars**:
  - Interactive mini history pills for each monitor showing the last 15–50 health checks.
  - Hover over any individual heartbeat bar to view exact latency, check timestamp, and response message.
- 🖥️ **Desktop & Panel Flexibility**:
  - **Panel / System Tray**: Compact status pill fitting into horizontal or vertical taskbars.
  - **Desktop Placement**:
    - **Grouped by Category**: Visual group section cards with group health badges (`27/27 Up` or `🔴 1 Down`), group latency, and collapsible monitor cards!
    - **Full Dashboard**: Expanded flat monitor list with real-time search, status filters, and heartbeat history.
    - **Compact Widget**: Small, sleek desktop pill (clicking it pops open the full dashboard!).
- 🏷️ **Multi-Group Selection**:
  - Filter any widget instance to monitor one or multiple groups (e.g. check both `Apps` and `Network`).
  - Convenient "Select All" and "Clear" actions, with automatic discovery from Uptime Kuma API.
  - Add multiple widgets to your desktop or panel, each dedicated to different group combinations!
- 🎛️ **Configurable Display Modes**:
  - **Icon with Status Text** (e.g. `66/66 Up` or `🔴 1 Down`)
  - **Badge Only** (Uptime Kuma icon with colored corner status dot)
  - **24h Uptime %** (e.g. `99.8%`)
  - **Count Ratio** (e.g. `66/66`)
- 🔔 **Native Desktop Notifications**:
  - Automatically sends system notifications via KDE Plasma notification center when any service goes down or recovers back up.
- 🔍 **Real-Time Search & Filtering**:
  - Instant filter bar to search monitors by name, group, hostname, or port.
  - Quick tabs: **All**, **Issues** (highlighted if any failing), and **Up**.
- 🛠️ **Expandable Monitor Cards**:
  - Click any monitor to inspect failure error messages (`502 Bad Gateway`, `Connection refused`, etc.), last check timestamp, and direct "Open in Browser" button.
- 🚨 **Incident Announcements**:
  - Displays active status page incidents and maintenance announcements directly at the top of the dashboard.
- 🔒 **Flexible Authentication & Dual-Mode Backend**:
  - Supports public and password-protected status pages.
  - Native support for Uptime Kuma API keys (`uk2_...`, `uk3_...`), HTTP Basic Auth, and Bearer tokens.
  - Automatic fallback to Prometheus `/metrics` endpoint when querying protected instances directly.
- 🎨 **Built-In Demo Mode**:
  - Preview all widget states and UI interactions with one click even without a live server connected.

---

## 🚀 Installation

### Via KDE Plasma (Recommended)

You can install the widget directly inside KDE Plasma without using the terminal:

1. Right-click your desktop or panel and select **"Add Widgets..."** (or press <kbd>Meta</kbd> + <kbd>W</kbd>).
2. Click **"Get New Widgets..."** &rarr; **"Download New Plasma Widgets"**.
3. Search for **"Uptime Kuma"** and click **Install**.

You can also find it in the extension stores:
- **KDE Store**: [https://store.kde.org/p/2375420/](https://store.kde.org/p/2375420/)
- **OpenDesktop**: [https://www.opendesktop.org/p/2375420/](https://www.opendesktop.org/p/2375420/)

### Automated Install (From Git)

Clone this repository and run the installation script:

```bash
git clone https://github.com/muench-dev/uptime-kuma-plasma-widget.git
cd uptime-kuma-plasma-widget
./install.sh
```

The script symlinks the applet into `~/.local/share/plasma/plasmoids/dev.muench.uptime-kuma`.

### Manual Install

Simply symlink or copy the repository directory to your local Plasma plasmoids folder:

```bash
mkdir -p ~/.local/share/plasma/plasmoids
ln -s "$(pwd)" ~/.local/share/plasma/plasmoids/dev.muench.uptime-kuma
```

---

## 🖥️ How to Add to Your Desktop or Panel

1. Right-click your KDE Plasma panel or desktop wallpaper.
2. Select **"Add Widgets..."** (or press <kbd>Meta</kbd> + <kbd>W</kbd>).
3. Search for **"Uptime Kuma"**.
4. Drag and drop the widget onto your panel or desktop!

### Testing in a Standalone Window

You can launch and test the widget anytime without adding it to your desktop using KDE's `plasmawindowed` utility:

```bash
plasmawindowed dev.muench.uptime-kuma
```

---

## ⚙️ Configuration

Right-click the widget and select **"Configure Uptime Kuma..."** to customize your setup:

### General Tab

| Setting | Description | Default |
|---|---|---|
| **Server URL** | The base URL of your Uptime Kuma instance (e.g. `https://status.example.com` or `http://localhost:3001`). Also accepts full status page URLs like `https://status.example.com/status/my-slug`. | *(Empty)* |
| **Status Page Slug** | The slug identifier configured in Uptime Kuma (e.g. `default` or `muench-lan`). | `default` |
| **API Key / Auth Token** | Uptime Kuma API key (e.g. `uk2_...` / `uk3_...`), or reverse proxy authorization (`Basic <base64>` / `Bearer <token>`). | *(Empty)* |
| **Update Interval** | Polling frequency in seconds (15s to 600s). | `60s` |
| **Notifications** | Toggle desktop notifications on service outage or recovery. | `Enabled` |

### Appearance Tab

| Setting | Description | Default |
|---|---|---|
| **Desktop Appearance** | Choose between **Full Dashboard** (flat monitor list), **Grouped by Category** (group cards with health badges and collapsible monitors), or **Compact Widget** (sleek status pill on the desktop). | `Full Dashboard` |
| **Filter by Group(s)** | Limit the widget to monitors belonging to one or multiple groups (e.g. `Apps`, `Websites`). Leave cleared to show all monitors. | `All Groups` |
| **Compact / Panel Style** | Select between `Icon with Status Text`, `Badge Only`, `24h Uptime %`, or `Count Ratio`. (Used in panels or when *Compact Widget* is chosen on the desktop). | `Icon with Status Text` |
| **Heartbeat History Count** | Number of heartbeat pills to show per monitor card (10 to 50). | `25` |
| **Show Ping Latency** | Display real-time ping latency badge (e.g. `24 ms`). | `Enabled` |
| **Show 24h Uptime %** | Display 24-hour uptime percentage badge. | `Enabled` |
| **Show Monitor Tags** | Show colored category and environment tags. | `Enabled` |

---

## 🧩 Compatibility & Requirements

| Software / Component | Supported Versions | Details & Notes |
|---|---|---|
| **KDE Plasma** | **6.0+** (6.0, 6.1, 6.2+) | Built natively for **KDE Plasma 6** using Qt 6 & Kirigami 3. *(Note: KDE Plasma 5 is not supported)* |
| **Qt** | **6.6+** | Required by KDE Plasma 6 runtime |
| **Uptime Kuma** | **1.x** (v1.12+) & **2.x** (v2.0+) | Full support for status page endpoints (`/api/status-page/:slug`), incidents, and `/metrics` fallback (API keys supported since v1.21+) |
| **KDE Frameworks** | **6.0+** | Kirigami, PlasmaCore, PlasmaExtras, PlasmaComponents3, KCMUtils |

---

## 🧰 Development with Just

This project includes a [`justfile`](justfile) with handy automation recipes:

```bash
just package             # Build .plasmoid package archive
just lint                # Check all QML files with qmllint
just validate            # Validate metadata.json and config XML schemas
just validate-docker     # Run complete CI validation and linting inside Docker container
just test-unit           # Run Node.js service unit test suite
just test-docker v1      # Run E2E integration tests against real Uptime Kuma v1 container
just test-docker v2      # Run E2E integration tests against real Uptime Kuma v2 container
just test-all            # Run all test suites (unit + real v1 & v2 integration)
just test                # Launch widget in a standalone window (plasmawindowed)
just install             # Link widget into ~/.local/share/plasma/plasmoids/
just uninstall           # Remove widget from ~/.local/share/plasma/plasmoids/
just clean               # Remove built .plasmoid packages
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

