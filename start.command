#!/bin/zsh
set -e

cd "${0:A:h}"
swift build -c release
cp .build/release/badge-kart-bridge BadgeKartBridge
chmod +x BadgeKartBridge
exec ./BadgeKartBridge "$@"
