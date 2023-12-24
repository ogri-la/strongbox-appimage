#!/bin/bash
# builds an AppImage of strongbox with a custom JRE
set -eu

# strongbox is required
path_to_strongbox="$1"
test -d "$path_to_strongbox"

custom_jre_dir="$(realpath custom-jre)" # "/path/to/strongbox-appimage/custom-jre"
rm -rf "$custom_jre_dir"

echo "--- building custom JRE ---"

# compress=1 'constant string sharing' compresses better with AppImage than compress=2 'zip', 52MB -> 45MB
# - https://docs.oracle.com/en/java/javase/19/docs/specs/man/jlink.html#plugin-compress
jlink \
    --add-modules "java.sql,java.naming,java.desktop,jdk.unsupported,jdk.crypto.ec" \
    --output "$custom_jre_dir" \
    --strip-debug \
    --no-man-pages \
    --no-header-files \
    --compress=1

# needed when built using Ubuntu as libjvm.so is *huge*
# doesn't seem to hurt to strip the other .so files.
find "$custom_jre_dir" -name "*.so" -print0 | xargs -0 strip --preserve-dates --strip-unneeded

du -sh "$custom_jre_dir"

echo
echo "--- building app ---"
(
    cd "$path_to_strongbox"
    lein clean
    rm -f resources/full-catalogue.json
    wget https://raw.githubusercontent.com/ogri-la/strongbox-catalogue/master/full-catalogue.json \
        --quiet \
        --directory-prefix resources
    lein uberjar
    cp ./target/*-standalone.jar "$custom_jre_dir/app.jar"
)

echo
echo "--- building AppImage ---"
if [ ! -e appimagetool ]; then
    wget \
        -c "https://github.com/AppImage/AppImageKit/releases/download/13/appimagetool-x86_64.AppImage" \
        -o appimagetool
    mv appimagetool-x86_64.AppImage appimagetool
    chmod +x appimagetool
fi
rm -rf ./AppDir
mkdir AppDir
mv "$custom_jre_dir" AppDir/usr
cp ./AppImage/strongbox.desktop ./AppImage/AppRun AppDir/
cp "$path_to_strongbox/resources/strongbox.svg" "$path_to_strongbox/resources/strongbox.png" AppDir/
du -sh AppDir/
rm -f strongbox.appimage # safer than 'rm -f strongbox'
ARCH=x86_64 ./appimagetool AppDir/ strongbox.appimage
du -sh strongbox.appimage

echo
echo "--- cleaning up ---"
rm -rf AppDir

echo
echo "done."
