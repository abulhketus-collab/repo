<div align="center">

# ⚡ cocxace's Jailbreak Suite
### Элитные 60 FPS твики для iOS 12.0 — 12.5.8 (iPhone 5s / A7 chip) & Официальный APT Репозиторий

[![Author](https://img.shields.io/badge/Developer-@cocxace-blue.svg?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/abulhketus-collab)
[![iOS](https://img.shields.io/badge/iOS-12.0%20--%2012.5.8-34C759.svg?style=for-the-badge)](https://apple.com)
[![Architecture](https://img.shields.io/badge/Arch-arm64%20(A7)-FF9500.svg?style=for-the-badge)](https://apple.com)
[![Sileo](https://img.shields.io/badge/Sileo-Ready-5856D6.svg?style=for-the-badge&logo=sileo&logoColor=white)](https://abulhketus-collab.github.io/repo/)
[![Zebra](https://img.shields.io/badge/Zebra-Supported-black.svg?style=for-the-badge)](https://abulhketus-collab.github.io/repo/)

<br>

<p align="center">
  <a href="sileo://source/https://abulhketus-collab.github.io/repo/">
    <img src="https://img.shields.io/badge/👉%20ДОБАВИТЬ%20В%20SILEO-007AFF?style=for-the-badge&logo=apple&logoColor=white" height="46">
  </a>
</p>

**Официальный APT-адрес репозитория:**
```text
https://abulhketus-collab.github.io/repo/
```

</div>

---

## 📱 Коллекция проверенных твиков (@cocxace Suite)

| Твик | Версия | Описание и возможности | Статус |
| :--- | :---: | :--- | :---: |
| **🔘 ActionButton12** | `1.0.0` | **Action Button HUD с iPhone 15 Pro**: сетка 2x2, фонарик, камера, диктофон, скриншот и плавные ползунки громкости/яркости. 100% безопасная ленивая инициализация. | `🟢 Stable` |
| **🏝️ Glint** | `1.0.0` | **Fake Dynamic Island**: стильная овальная плашка по центру вверху. Пружинная анимация расширения при уведомлениях с таймером сжатия. | `🟢 Stable` |
| **🌙 Lumina** | `1.0.0` | **Always-On Display**: мягкое затемнение экрана блокировки с пульсирующими часами сверхтонкого начертания UltraLight. | `🟢 Stable` |
| **📶 Echo** | `1.0.0` | **Custom Carrier**: кастомизация имени оператора сотовой связи в статус-баре в реальном времени. | `🟢 Stable` |
| **🔋 Volt** | `1.0.0` | **Battery Tint**: цветной процент заряда батареи (зелёный/жёлтый/красный) без мерцания и перегрузки. | `🟢 Stable` |

---

## 🌟 Особенности архитектуры

- ⚡ **Ленивая инициализация (Zero Boot Impact):** Никаких `UIWindow` и обращений к `[UIScreen mainScreen]` до старта SpringBoard. Телефон загружается мгновенно, без зависаний.
- 🛡️ **Формат архива GNU (No PAX):** Архивы `.deb` собраны со строгим форматом `tar --format=gnu` без заголовков PAX, что гарантирует 100% совместимость со старым `dpkg` на iOS 12.5.8.
- 📳 **Тактильный отклик:** Использование системного звукового отклика `AudioServicesPlaySystemSound(1519)` для iPhone 5s.

---

## 🚀 Как добавить репозиторий на устройстве

1. Откройте эту страницу в Safari на вашем iPhone:  
   👉 **[https://abulhketus-collab.github.io/repo/](https://abulhketus-collab.github.io/repo/)**
2. Нажмите большую светящуюся кнопку **«ДОБАВИТЬ В SILEO»**.
3. Либо перейдите в Sileo ➔ **«Источники»** ➔ **«+»** ➔ добавьте адрес:
   ```text
   https://abulhketus-collab.github.io/repo/
   ```

---

<div align="center">
  <sub>Разработано специально для классических устройств Apple. Made with ❤️ by <b>@cocxace</b></sub>
</div>
