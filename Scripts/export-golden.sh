#!/bin/bash
# Altın dosyaları Android (Flutter) uygulamasının gerçek kodundan üretir.
#
# `DolmusCore`'daki portların (düzeltme kuralları, arama, metin sadeleştirme)
# Flutter ile aynı sonucu verdiğini GoldenTests kanıtlar; beklenen çıktılar bu
# betikle yazılır. Betik `Scripts/golden_export_test.dart` dosyasını Flutter
# repo'sunun `test/` klasörüne GEÇİCİ olarak kopyalar, çalıştırır ve siler;
# Flutter repo'sunda kalıcı dosya bırakmaz.
#
# Ne zaman: Flutter tarafında veri ya da `lib/` altındaki veri/arama kodu
# değiştiğinde (önce `Scripts/sync-data.sh`), ya da dışa aktarıma yeni bir
# karşılaştırma eklendiğinde. Sonra `swift test` koştur, farkları incele.
#
# Kullanım: Scripts/export-golden.sh [flutter-repo-yolu]   (varsayılan: ../izmir_dolmus)
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
src="${1:-$root/../izmir_dolmus}"
resources="$root/DolmusCore/Sources/DolmusCore/Resources"
out="$root/DolmusCore/Tests/DolmusCoreTests/Golden"

if [ ! -f "$src/pubspec.yaml" ] || [ ! -d "$src/assets/data" ]; then
  echo "Flutter repo'su bulunamadı: $src" >&2
  echo "Yolunu argüman olarak ver." >&2
  exit 1
fi
src="$(cd "$src" && pwd)"

# İki taraf aynı veriyle çalışmalı; yoksa farkın sebebi kod değil veri olur.
for file in "$src"/assets/data/*.json; do
  if ! cmp -s "$file" "$resources/$(basename "$file")"; then
    echo "Veri eşit değil: $(basename "$file")" >&2
    echo "Önce Scripts/sync-data.sh çalıştır." >&2
    exit 1
  fi
done

tmp_test="$src/test/zz_ios_golden_export_test.dart"
trap 'rm -f "$tmp_test"' EXIT
cp "$root/Scripts/golden_export_test.dart" "$tmp_test"

mkdir -p "$out"
(cd "$src" && GOLDEN_OUT="$out" flutter test "test/$(basename "$tmp_test")")

# Çıktının hangi koddan geldiği.
commit="$(git -C "$src" log -1 --format=%h)"
if [ -n "$(git -C "$src" status --porcelain -- lib assets/data)" ]; then
  commit="$commit + commit edilmemiş değişiklik"
fi
echo "izmir_dolmus@$commit lib + assets/data" > "$out/SOURCE"

echo "Yazıldı: $(ls "$out" | tr '\n' ' ')"
echo "Kaynak: $(cat "$out/SOURCE")"
git -C "$root" status --short -- "$out"
