#!/bin/bash
# Makes the zips from package/ (rebuild package/AlternatePoses/AlternatePoses.pck first with pack.gd, see the README):
#   out/AlternatePoses-mod.zip         the AlternatePoses folder to drop into GDWeave/mods
#   out/AlternatePoses-<version>.zip   the Thunderstore upload
set -e
cd "$(dirname "$0")"
mkdir -p out
V=$(python3 -c "import json;print(json.load(open('thunderstore/manifest.json'))['version_number'])")
rm -f out/AlternatePoses-mod.zip out/AlternatePoses-$V.zip
(cd package && zip -qr ../out/AlternatePoses-mod.zip AlternatePoses)
T=$(mktemp -d)
cp thunderstore/manifest.json thunderstore/README.md thunderstore/CHANGELOG.md thunderstore/icon.png $T/
cp LICENSE $T/
mkdir -p $T/GDWeave/mods/AlternatePoses
cp package/AlternatePoses/manifest.json package/AlternatePoses/AlternatePoses.pck $T/GDWeave/mods/AlternatePoses/
(cd $T && zip -qr - .) > out/AlternatePoses-$V.zip
rm -rf $T
echo "out/AlternatePoses-mod.zip"
echo "out/AlternatePoses-$V.zip"
