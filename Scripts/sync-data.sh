#!/bin/bash
# Android (Flutter) repo'sundaki veri dosyalarını bu repo'ya kopyalar.
#
# Veri iki uygulamada ortak, ama repo'lar ayrı. Tek kaynak Flutter repo'sundaki
# `assets/data/` klasörüdür; buradaki kopya elle DÜZENLENMEZ. Orada veri
# değiştiğinde bu betiği çalıştır, testleri koştur, sonucu commit et.
# Verinin hangi commit'ten geldiği `DATA_SOURCE` dosyasına yazılır.
#
# Kullanım: Scripts/sync-data.sh [flutter-repo-yolu]   (varsayılan: ../izmir_dolmus)
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
src="${1:-$root/../izmir_dolmus}"
dest="$root/DolmusCore/Sources/DolmusCore/Resources"

if [ ! -d "$src/assets/data" ]; then
  echo "Bulunamadı: $src/assets/data" >&2
  echo "Flutter repo'sunun yolunu argüman olarak ver." >&2
  exit 1
fi

mkdir -p "$dest"
cp "$src"/assets/data/*.json "$dest"/

# Veriye en son dokunan commit: veri değişmediği sürece bu satır da değişmez.
commit="$(git -C "$src" log -1 --format=%h -- assets/data)"
if [ -n "$(git -C "$src" status --porcelain -- assets/data)" ]; then
  commit="$commit + commit edilmemiş değişiklik"
fi
echo "izmir_dolmus@$commit assets/data" > "$root/DATA_SOURCE"

echo "Kopyalandı: $(ls "$dest" | tr '\n' ' ')"
echo "Kaynak: $(cat "$root/DATA_SOURCE")"
git -C "$root" status --short -- DolmusCore/Sources/DolmusCore/Resources DATA_SOURCE
