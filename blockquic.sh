#!/bin/bash
# blockquic.sh - blocca UDP 443 (QUIC) a ogni avvio di macOS.
# Workaround per il leak di mbuf di AirportItlwm 2.3.0 con Intel AC 8265
# (il traffico QUIC fa salire i cluster da 4KB fino al panic mbuf_watchdog).
#
# Uso:  sudo bash blockquic.sh install | uninstall | status

PLIST=/Library/LaunchDaemons/local.blockquic.plist
ANCHOR='com.apple/quic_block'

if [ "$(id -u)" -ne 0 ]; then
    echo "Esegui con sudo: sudo bash $0 install|uninstall|status"
    exit 1
fi

case "${1:-install}" in
install)
    cat > "$PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>local.blockquic</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/sh</string>
    <string>-c</string>
    <string>/sbin/pfctl -e; echo 'block drop quick proto udp from any to any port 443' | /sbin/pfctl -a 'com.apple/quic_block' -f -</string>
  </array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF
    chown root:wheel "$PLIST"
    chmod 644 "$PLIST"
    plutil -lint "$PLIST" || exit 1
    launchctl bootout system "$PLIST" 2>/dev/null
    launchctl bootstrap system "$PLIST" || exit 1
    echo "Installato. Controllo:"
    pfctl -s info 2>/dev/null | head -1
    pfctl -a "$ANCHOR" -sr 2>/dev/null
    ;;
uninstall)
    launchctl bootout system "$PLIST" 2>/dev/null
    rm -f "$PLIST"
    pfctl -a "$ANCHOR" -F rules 2>/dev/null
    echo "Rimosso."
    ;;
status)
    pfctl -s info 2>/dev/null | head -1
    pfctl -a "$ANCHOR" -sr 2>/dev/null
    ;;
*)
    echo "Uso: sudo bash $0 install|uninstall|status"
    exit 1
    ;;
esac
