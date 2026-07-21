#!/bin/sh
set -eu

# GitHub Desktop Native FreeBSD Build Script
# Based on opencode's approach: Electron 42 from ports + native modules
#
# Prerequisites (pkg install):
#   electron42 node npm git gnome-keyring libsecret libnotify
#
# Usage:
#   ./freebsd.sh         # build
#   ./freebsd.sh run     # build + run

ELECTRON_HEADERS="/usr/local/share/electron42/node_headers"
ELECTRON_BIN="/usr/local/share/electron42/electron"
PYTHON="/usr/local/bin/python3"
NODE="/usr/local/bin/node"
NPM="/usr/local/bin/npm"
NODE_GYP="/usr/local/lib/node_modules/npm/bin/node-gyp-bin/node-gyp"
PROJECT_ROOT="/home/bizkit/Downloads/github-desktop"

export npm_config_target=42.0.0
export npm_config_runtime=electron
export npm_config_disturl=https://electronjs.org/headers
export npm_config_target_arch=x64
export npm_config_target_platform=freebsd
export npm_config_build_from_source=true

cd "${PROJECT_ROOT}"

echo "==> Installing dependencies..."
"${NPM}" install --ignore-scripts 2>&1 | grep -v "audit\|fund\|vulnerabilit\|ERESOLVE\|peer"
cd app
"${NPM}" install --ignore-scripts 2>&1 | grep -v "audit\|fund\|vulnerabilit\|conflicting\|peer"
cd "${PROJECT_ROOT}/vendor/desktop-notifications"
"${NPM}" install --ignore-scripts 2>&1 | grep -v "audit\|fund\|vulnerabilit"
cd "${PROJECT_ROOT}/vendor/desktop-trampoline"
"${NPM}" install --ignore-scripts 2>&1 | grep -v "audit\|fund\|vulnerabilit"

# Setup yarn for build step
mkdir -p bin && ln -sf ../vendor/yarn-1.21.1.js bin/yarn
export PATH="${PROJECT_ROOT}/bin:${PATH}"

echo "==> Building native modules..."

# Upgrade node-addon-api to v7 in keytar (fixes enum issue on FreeBSD Clang)
cd "${PROJECT_ROOT}/app/node_modules/keytar"
"${NPM}" install node-addon-api@^7.0.0 --ignore-scripts 2>&1 | tail -1
"${NODE_GYP}" rebuild --nodedir="${ELECTRON_HEADERS}" --python="${PYTHON}" 2>&1 | grep -E "ok|error"
cd "${PROJECT_ROOT}/app"

# Build fs-admin (adds FreeBSD support using Linux source)
cd node_modules/fs-admin
"${NPM}" install node-addon-api@^7.0.0 --ignore-scripts 2>&1 | tail -1
sed -i '' "s/\['OS==\"linux\"', {/\['OS==\"linux\"', {], ['OS==\"freebsd\"', { 'sources': \[ 'src\/fs-admin-linux.cc' \] } ], ['OS==\"freebsd\"', {/" binding.gyp 2>/dev/null || true
"${NODE_GYP}" rebuild --nodedir="${ELECTRON_HEADERS}" --python="${PYTHON}" 2>&1 | grep -E "ok|error"
cd "${PROJECT_ROOT}/app"

# Build desktop-notifications (libnotify)
cd "${PROJECT_ROOT}/vendor/desktop-notifications"
"${NODE_GYP}" rebuild --nodedir="${ELECTRON_HEADERS}" --python="${PYTHON}" 2>&1 | grep -E "ok|error"

# Build desktop-trampoline (SSH askpass, credential helper)
cd "${PROJECT_ROOT}/vendor/desktop-trampoline"
# Patch -pie flag for FreeBSD
if ! grep -q "freebsd" binding.gyp; then
    sed -i '' "s/['\"']OS==\"win\"['\"'], { 'defines': \[ 'WINDOWS' \] }/&],\n          ['OS==\"freebsd\"', { 'cflags!': [ '-pie' ], 'ldflags': [ '-pie', '-z relro', '-z now' ] }/" binding.gyp
fi
"${NODE_GYP}" rebuild --nodedir="${ELECTRON_HEADERS}" --python="${PYTHON}" 2>&1 | grep -E "ok|error"

# Build printenvz
cd "${PROJECT_ROOT}/vendor/printenvz"
if ! grep -q "freebsd" binding.gyp; then
    sed -i '' "s/\].*\$/{'cflags!': [ '-pie' ], 'ldflags': [ '-pie', '-z relro', '-z now' ] }], [\"OS=='freebsd'\",/" binding.gyp
fi
"${NODE_GYP}" rebuild --nodedir="${ELECTRON_HEADERS}" --python="${PYTHON}" 2>&1 | grep -E "ok|error"

# Build process-proxy (simple C binary)
cd "${PROJECT_ROOT}/node_modules/process-proxy"
if [ ! -f "bin/process-proxy-freebsd-x64" ]; then
    if ! grep -q "netinet/in.h" native/main.c; then
        sed -i '' "/#include <sys\/socket.h>/a\\
#include <netinet/in.h>" native/main.c
    fi
    cc -O2 -o bin/process-proxy-freebsd-x64 native/main.c
fi

echo "==> Patching dugite for FreeBSD platform..."
cd "${PROJECT_ROOT}"
sed -i '' 's/process.platform === .linux../process.platform === "linux" || process.platform === "freebsd"/g' app/node_modules/dugite/build/lib/git-environment.js
sed -i '' 's/process.platform === .linux/process.platform === "linux" || process.platform === "freebsd"/g' app/node_modules/dugite/build/lib/git-environment.js
# Ensure FreeBSD is in the allowed platforms list
sed -i '' 's/process.platform === .android/process.platform === "freebsd" || process.platform === "android"/g' app/node_modules/dugite/build/lib/git-environment.js

echo "==> Compiling scripts..."
cd "${PROJECT_ROOT}"
"${NPM}" run compile:script 2>&1 | tail -1

echo "==> Building webpack bundles..."
cd app
NODE_OPTIONS='--max-old-space-size=8192' "${NPM}" run compile:prod 2>&1 | grep -E "compiled successfully|ERROR"

echo "==> Building app distribution..."
cd "${PROJECT_ROOT}"
export DESKTOP_SKIP_PACKAGE=1
NODE_OPTIONS='--max-old-space-size=8192' npx --no-install ts-node -P script/tsconfig.json script/build.ts 2>&1 | grep -v "audit\|fund\|vulnerabilit\|skip"

echo "==> Setting up git directory..."
echo "==> Copying app icon..."
cp app/static/linux/icon-logo.png out/static/icon-logo.png 2>/dev/null || true

cd "${PROJECT_ROOT}/out/git"
mkdir -p bin
ln -sf ../git bin/git 2>/dev/null || true
mkdir -p etc
cat > etc/gitconfig << 'GITCONF'
[core]
	autocrlf = false
	fsmonitor = false
GITCONF
mkdir -p share/git-core
cp -r /usr/local/share/git-core/templates share/git-core/ 2>/dev/null || true

echo ""
echo "=========================================="
echo "  Build complete!"
echo ""
echo "  To run:"
echo "    LOCAL_GIT_DIRECTORY=${PROJECT_ROOT}/out/git"
echo "    ${ELECTRON_BIN} ${PROJECT_ROOT}/out/main.js"
echo ""
echo "  Or add to .profile:"
echo "    export LOCAL_GIT_DIRECTORY=${PROJECT_ROOT}/out/git"
echo "    alias github-desktop='${ELECTRON_BIN} ${PROJECT_ROOT}/out/main.js'"
echo "=========================================="

if [ "${1:-}" = "run" ]; then
    echo "==> Launching GitHub Desktop..."
    export LOCAL_GIT_DIRECTORY="${PROJECT_ROOT}/out/git"
    "${ELECTRON_BIN}" "${PROJECT_ROOT}/out/main.js"
fi