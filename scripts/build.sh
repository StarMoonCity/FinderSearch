#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
if [[ "$(uname -s)" != Darwin ]]; then
    print -u2 'FinderSearch requires macOS 15 or newer.'
    exit 1
fi
for tool in cargo swift codesign; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        print -u2 "Missing $tool. Install Xcode development tools and Rust/Cargo; see README.md."
        exit 1
    fi
done
if (( ${$(sw_vers -productVersion)%%.*} < 15 )); then
    print -u2 'FinderSearch requires macOS 15 or newer.'
    exit 1
fi

# Pin dependency resolution and the output location, even when the caller has
# CARGO_TARGET_DIR configured for another project.
cargo build --release --locked --manifest-path vendor/fsearch/Cargo.toml --target-dir vendor/fsearch/target
swift build -c release
swift_bin="$(swift build -c release --show-bin-path)"
app="$PWD/dist/FinderSearch.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers" "$app/Contents/Resources"
./scripts/build-icon.sh "$app/Contents/Resources/AppIcon.icns"
cp "$swift_bin/FinderSearch" "$app/Contents/MacOS/"
cp vendor/fsearch/target/release/fsearch "$app/Contents/Helpers/"
# Localization: SwiftPM compiles Localizable.xcstrings into a resource bundle.
# Copy it, and hoist its .lproj folders to the top level so Bundle.main —
# what String(localized:) and SwiftUI's LocalizedStringKey read by default —
# and the system per-app language list both see them.
if [[ -d "$swift_bin/FinderSearch_FinderSearch.bundle" ]]; then
    cp -R "$swift_bin/FinderSearch_FinderSearch.bundle" "$app/Contents/Resources/"
    for lproj in "$swift_bin"/FinderSearch_FinderSearch.bundle/Contents/Resources/*.lproj(N); do
        cp -R "$lproj" "$app/Contents/Resources/"
    done
fi
cp vendor/fsearch/LICENSE "$app/Contents/Resources/fsearch-LICENSE"
if [[ -f LICENSE ]]; then
    cp LICENSE "$app/Contents/Resources/FinderSearch-LICENSE"
fi
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>FinderSearch</string>
<key>CFBundleIdentifier</key><string>local.findersearch.app</string>
<key>CFBundleName</key><string>FinderSearch</string>
<key>CFBundleIconFile</key><string>AppIcon.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.4.3</string>
<key>CFBundleVersion</key><string>0.4.3</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string></array>
</dict></plist>
PLIST
codesign --force --sign - "$app/Contents/Helpers/fsearch"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
printf 'Built %s\n' "$app"
