#!/bin/bash
# creates a custom JRE and self-contained launcher for application using AppImage
set -e

if [ ! -d strongbox ]; then
    echo "--- cloning strongbox ---"
    git clone https://github.com/ogri-la/strongbox
else
    (
        cd strongbox
        git reset --hard
        git pull
    )
fi

output_dir="$(realpath custom-jre)" # "/path/to/strongbox-appimage/custom-jre"

rm -rf "$output_dir"

echo "--- building custom JRE ---"

# compress=1 'constant string sharing' compresses better with AppImage than compress=2 'zip', 52MB -> 45MB
# - https://docs.oracle.com/en/java/javase/19/docs/specs/man/jlink.html#plugin-compress
jlink \
    --add-modules "java.sql,java.naming,java.desktop,jdk.unsupported,jdk.crypto.ec" \
    --output "$output_dir" \
    --strip-debug \
    --no-man-pages \
    --no-header-files \
    --compress=1

# needed when built using Ubuntu as libjvm.so is *huge*
# doesn't seem to hurt to strip the other .so files.
find -name "*.so" | xargs strip --preserve-dates --strip-unneeded

du -sh "$output_dir"

echo
echo "--- building app ---"
(
    cd strongbox
    lein clean
    rm -f resources/full-catalogue.json
    wget https://raw.githubusercontent.com/ogri-la/strongbox-catalogue/master/full-catalogue.json \
        --quiet \
        --directory-prefix resources
    lein uberjar
    cp ./target/*-standalone.jar "$output_dir/app.jar"
)

echo
echo "--- building AppImage ---"
if [ ! -e appimagetool ]; then
    wget "https://github.com/AppImage/AppImageKit/releases/download/13/appimagetool-x86_64.AppImage" \
        --output-file appimagetool
    mv appimagetool-x86_64.AppImage appimagetool
    chmod +x appimagetool
fi
rm -rf ./AppDir strongbox.AppImage strongbox-x86_64.AppImage
mkdir AppDir
mv "$output_dir" AppDir/usr
cp strongbox/AppImage/strongbox.desktop AppDir/
cp strongbox/resources/strongbox.svg strongbox/resources/strongbox.png AppDir/
cp strongbox/AppImage/AppRun AppDir/
du -sh AppDir/
rm -f strongbox.appimage # safer than 'rm -f strongbox'
ARCH=x86_64 ./appimagetool AppDir/ strongbox-x86_64.AppImage
du -sh strongbox-x86_64.AppImage

echo
echo "--- cleaning up ---"
rm -rf AppDir

echo
echo "done."
