# cocxace's Repo 📦

[![Sileo](https://img.shields.io/badge/Sileo-Compatible-blue.svg)](https://abulhketus-collab.github.io/repo/)
[![Zebra](https://img.shields.io/badge/Zebra-Compatible-black.svg)](https://abulhketus-collab.github.io/repo/)
[![Cydia](https://img.shields.io/badge/Cydia-Compatible-brown.svg)](https://abulhketus-collab.github.io/repo/)
[![Author](https://img.shields.io/badge/Author-@cocxace-orange.svg)](https://github.com/abulhketus-collab)

Официальный персональный репозиторий джейлбрейк-твиков от **@cocxace**.

🔗 **URL репозитория:**
```text
https://abulhketus-collab.github.io/repo/
```

---

## 🚀 Как добавить в пакетные менеджеры

- **Sileo:** Откройте Safari на устройстве и нажмите 👉 [Добавить в Sileo](sileo://source/https://abulhketus-collab.github.io/repo/)
- **Zebra:** 👉 [Добавить в Zebra](zbra://sources/add/https://abulhketus-collab.github.io/repo/)
- **Cydia:** 👉 [Добавить в Cydia](cydia://url/https://cydia.saurik.com/api/share#?source=https://abulhketus-collab.github.io/repo/)

Либо откройте ваш пакетный менеджер (Sileo / Zebra / Cydia), перейдите в **Источники** -> **Добавить** и вставьте URL:
`https://abulhketus-collab.github.io/repo/`

---

## 📱 Список твиков в репозитории

### 1. **ActionButton12** (v1.0.0)
- **Описание:** Имитация кнопки Action Button с iPhone 15 Pro для устройств на iOS 12 (iPhone 5s / A7).
- **Функции:**
  - Полупрозрачный HUD поверх SpringBoard (сетка 2x2).
  - 4 быстрых действия (фонарик, камера, диктофон, скриншот, Wi-Fi, Bluetooth).
  - Плавные ползунки громкости и яркости прямо в HUD.
  - Настройки в Settings.app (триггеры Power / Home).
- **Пакет:** `com.cocxace.actionbutton12`
- **Файл:** `debs/com.cocxace.actionbutton12_1.0.0_iphoneos-arm.deb`
- **Исходный код:** [github.com/abulhketus-collab/actionbutton12](https://github.com/abulhketus-collab/actionbutton12)

---

## 🛠 Как добавить новый твик в этот репозиторий

В репозитории есть готовый скрипт автоматизации:

1. Положите новый `.deb` файл в папку `debs/` (или передайте путь к нему).
2. Запустите:
   ```cmd
   py add_tweak.py путь_к_файлу.deb
   ```
   *Или просто запустите файл `update_repo.bat` двойным кликом.*
3. Скрипт сам пересчитает контрольные суммы MD5/SHA1/SHA256, обновит `Packages` и `Release`, сделает коммит и отправит изменения на GitHub!

---

## 👤 Создатель
- Разработчик: **@cocxace**
- GitHub: [abulhketus-collab](https://github.com/abulhketus-collab)
