<div align="center">

# ⚡ @cocxace Jailbreak Repository
### Premium 60 FPS Tweaks for iOS 12.0 — 12.5.8 (iPhone 5s / Apple A7)

[![Developer](https://img.shields.io/badge/Developer-@cocxace-007AFF.svg?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/abulhketus-collab)
[![iOS](https://img.shields.io/badge/iOS-12.0%20--%2012.5.8-34C759.svg?style=for-the-badge)](https://apple.com)
[![Architecture](https://img.shields.io/badge/Arch-arm64%20(A7)-FF9500.svg?style=for-the-badge)](https://apple.com)
[![Sileo](https://img.shields.io/badge/Sileo-Ready-5856D6.svg?style=for-the-badge&logo=sileo&logoColor=white)](https://abulhketus-collab.github.io/repo/)
[![Zebra](https://img.shields.io/badge/Zebra-Supported-000000.svg?style=for-the-badge)](https://abulhketus-collab.github.io/repo/)

<br>

<p align="center">
  <a href="sileo://source/https://abulhketus-collab.github.io/repo/">
    <img src="https://img.shields.io/badge/👉%20ADD%20TO%20SILEO-007AFF?style=for-the-badge&logo=apple&logoColor=white" height="46">
  </a>
</p>

**Official APT Repository URL:**
```text
https://abulhketus-collab.github.io/repo/
```

**Live Showcase & Interactive Simulator:**
```text
https://abulhketus-collab.github.io/repo/
```

</div>

---

## 📱 Verified Suite (@cocxace v1.2.3 Ecosystem)

| Tweak | Version | Description & Capabilities | Safe Mode Status |
| :--- | :---: | :--- | :---: |
| **🏝️ Glint** | `1.2.3` | **Dynamic Island for iOS 12**: Countdown timer MM:SS beside the status clock, Safari audio visualizer with 5-band equalizer & beat pulse, customizable edge lighting (solid, rainbow cycle, 1s breathing blink), fast charging indicator. | `🟢 100% Safe` |
| **📷 Camera60Enabler5s** | `1.2.3` | **1080p 60 FPS Camera Unlock**: Enables silky smooth 60 FPS video recording on iPhone 5s stock Camera app. Adds configuration menu in iOS Settings with quality presets. | `🟢 100% Safe` |
| **✨ Aura** | `1.2.3` | **Spring Physics Action Button HUD**: Apple-style floating action menu with fluid spring damping (0.7), dark glass blur, 2x2 shortcut grid, and direct app workspace launch via SBUIController. | `🟢 100% Safe` |
| **🔘 ActionButton12** | `1.2.3` | **Action Button HUD + Sliders**: Triggers on long-press Power (0.6s) or Home. Interactive volume & brightness sliders, flashlight, camera, voice memos, screenshot. | `🟢 100% Safe` |
| **🌙 Lumina** | `1.2.3` | **Always-On Display**: Ambient lockscreen clock with UltraLight typography and smooth alpha cross-dissolve transition. Sub-0.1% CPU consumption. | `🟢 100% Safe` |
| **📡 Echo** | `1.2.3` | **Custom Status Bar Carrier**: Replaces the operator label in the iOS 12 status bar with custom text or emoji. Instant apply without respring. | `🟢 100% Safe` |
| **🔋 Volt** | `1.2.3` | **Color-Graded Battery Percentage**: Clean numerical percent readout in status bar with dynamic color tinting (Green > Yellow > Red). | `🟢 100% Safe` |

---

## 🛠️ Architecture & Packaging Safeguards

1. **Pure GNU Tar Format (0 PAX Headers):**
   - Packages are compiled with strict `tarfile.GNU_FORMAT` (`--format=gnu`).
   - Completely prevents the legacy iOS 12 dpkg error: `"corrupted filesystem tarfile in package archive: unsupported PAX tar header type 'x'"`.
2. **Zero Safe-Mode UI Architecture:**
   - All UI instantiations (`UIWindow`, `UIView`, animations) are 100% lazy and bound to `dispatch_async(dispatch_get_main_queue(), ...)`.
   - Zero UI work inside dyld constructors (`__attribute__((constructor))`), preventing SpringBoard watchdog panics.
   - All Substrate hooks are shielded inside `@try { ... } @catch (...)` blocks.

---

## 📥 How to Add to Package Managers

### Sileo
Tap the **"Add to Sileo"** button on the website, or in Sileo go to **Sources → + → paste `https://abulhketus-collab.github.io/repo/`**.

### Zebra
Go to **Sources → Edit → Add → paste `https://abulhketus-collab.github.io/repo/`**.

### Cydia
Go to **Sources → Edit → Add → paste `https://abulhketus-collab.github.io/repo/`**.

### Manual Installation (Filza)
Download any `.deb` file from the `debs/` directory, open in **Filza File Manager**, tap **Install**, and tap **Respring**.

---

<div align="center">
  <sub>Handcrafted with care for classic iOS devices. Developed by @cocxace.</sub>
</div>
