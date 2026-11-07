#!/usr/bin/env bash
set -e
echo "=========================================================="
echo " [AURA CI/CD] Сборка и глубокая валидация .deb архива"
echo "=========================================================="
make clean
make package FINALPACKAGE=1 THEOS_PACKAGE_COMPRESSION=gzip THEOS_PACKAGE_FORMAT=gnu
DEB_FILE=$(ls -t packages/*.deb 2>/dev/null | head -n 1)
if [ -z "$DEB_FILE" ]; then echo "❌ Ошибка: .deb файл не найден"; exit 1; fi
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
ar x "$DEB_FILE" --output="$TEMP_DIR"
for TAR_GZ in "$TEMP_DIR"/data.tar.gz "$TEMP_DIR"/control.tar.gz; do
    PAX_CHECK=$(tar -tvf "$TAR_GZ" 2>&1 | grep -E "^x|PaxHeaders" || true)
    if [ -n "$PAX_CHECK" ]; then
        echo "❌ КРИТИЧЕСКАЯ ОШИБКА: Обнаружен PAX tar header type 'x' в $(basename $TAR_GZ)!"
        exit 1
    fi
done
echo "✅ УСПЕХ: Пакет на 100% соответствует формату GNU."
