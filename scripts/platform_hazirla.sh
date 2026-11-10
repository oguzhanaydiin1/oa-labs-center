#!/usr/bin/env bash
# Windows ve Android klasörlerini üretir ve OA Labs Center ayarlarını uygular.
# Kullanım (proje kökünde): bash scripts/platform_hazirla.sh windows,android
set -euo pipefail

PLATFORMS="${1:-windows,android}"

flutter create --platforms="$PLATFORMS" --org dev.oalabs --project-name oa_center .
# flutter create varsayılan bir test dosyası ekler; bizim uygulamamıza uymuyor.
rm -f test/widget_test.dart

MAIN=windows/runner/main.cpp
if [[ -f "$MAIN" ]]; then
  # Pencere başlığı ve açılış boyutu
  sed -i 's/window.Create(L"oa_center"/window.Create(L"OA Labs Center"/' "$MAIN"
  sed -i 's/Win32Window::Size size(1280, 720);/Win32Window::Size size(1180, 780);/' "$MAIN"
  grep -q 'OA Labs Center' "$MAIN" || { echo "::error::main.cpp pencere başlığı değiştirilemedi"; exit 1; }
fi

if [[ -f windows/runner/Runner.rc ]]; then
  sed -i 's/VALUE "CompanyName", "dev.oalabs"/VALUE "CompanyName", "OA Labs"/' windows/runner/Runner.rc
  sed -i 's/VALUE "FileDescription", "oa_center"/VALUE "FileDescription", "OA Labs Center"/' windows/runner/Runner.rc
  sed -i 's/VALUE "ProductName", "oa_center"/VALUE "ProductName", "OA Labs Center"/' windows/runner/Runner.rc
fi

if [[ -f android/app/src/main/AndroidManifest.xml ]]; then
  python3 scripts/android_ayarla.py
fi

echo "Platform ayarları uygulandı: $PLATFORMS"
