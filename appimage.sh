#!/bin/bash
set -e

APP_NAME=no_reload_mod_manager
ROOT="$(pwd)"
BUNDLE="$ROOT/build/linux/x64/release/bundle"
WORK="$ROOT/build/appimage"

mkdir -p "$WORK"
cd "$WORK"

# 1. Packaging tool (downloaded once)
wget -nc -O linuxdeploy https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
chmod +x linuxdeploy

# 2. App folder
rm -rf AppDir
mkdir -p AppDir/usr/bin
cp -r "$BUNDLE"/* AppDir/usr/bin/

# 3. Launcher script
cat > AppRun <<EOF
#!/bin/bash
HERE="\$(dirname "\$(readlink -f "\$0")")"
export LD_LIBRARY_PATH="\$HERE/usr/lib:\$HERE/usr/bin/lib:\$LD_LIBRARY_PATH"
exec "\$HERE/usr/bin/$APP_NAME" "\$@"
EOF
chmod +x AppRun

# 4. App info and icon
cat > $APP_NAME.desktop <<EOF
[Desktop Entry]
Type=Application
Name=No Reload Mod Manager
Exec=$APP_NAME
Icon=$APP_NAME
Categories=Utility;
EOF
cp "$ROOT/assets/images/app_icon.png" $APP_NAME.png

# 5. Build the AppImage
./linuxdeploy \
  --appdir AppDir \
  --executable AppDir/usr/bin/$APP_NAME \
  --library AppDir/usr/bin/lib/libtray_manager_plugin.so \
  --library AppDir/usr/bin/lib/libhotkey_manager_linux_plugin.so \
  --desktop-file $APP_NAME.desktop \
  --icon-file $APP_NAME.png \
  --custom-apprun AppRun \
  --output appimage

echo "Done: $WORK"/*.AppImage