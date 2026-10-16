# itlwm QUIC mbuf-leak workaround (macOS Sonoma)

A small LaunchDaemon that blocks outgoing **UDP port 443 (QUIC / HTTP/3)** at boot,
as a workaround for an **mbuf leak that ends in an `mbuf_watchdog` kernel panic**
on a Hackintosh using **AirportItlwm 2.3.0** with an **Intel AC 8265** Wi-Fi card.

> This is a workaround, **not a driver fix**. It was tested by one user on one
> machine (see "Tested on"). If you have a different card or kext version, please
> measure first (see "Check that this is your problem").

## Symptom

Kernel panic after some minutes of normal browsing, with a log like:

```
panic(...): mbuf_watchdog: 1 waiters stuck for 79 secs
26598/26688 mbufs in use:
        26512 mbufs allocated to data
14026/14029 mbuf 4KB clusters in use
64416 KB allocated to network (approx. 97% in use)
Panicked task ...: symptomsd
```

The 4KB mbuf clusters fill up and are never released, not even after closing the
app or turning Wi-Fi off. Only a reboot frees them.

## What was measured

`netstat -m`, "4KB clusters in use" (one machine, one session each):

| Situation | Result |
|---|---|
| Idle after boot | ~900, stable for 5 min |
| 100 MB TCP download with `curl` | +45 |
| UDP 443 **blocked**, ~663 MB received / 38 MB sent in 10m42s (several speedtests) | 2149 → 2189 |
| UDP 443 **not** blocked: open claude.ai in Safari | ~2200 → ~4500, not released when Safari is closed |
| UDP 443 **not** blocked: reopen Safari and claude.ai | +~400 |
| UDP 443 **blocked**: hard reload of claude.ai in Safari | no increase |
| UDP 443 blocked at boot via this daemon | clusters stay flat |

`netstat -an` showed no socket with a large receive/send queue and the panic log
showed almost no mbuf space held by any process or interface queue, so the buffers
look orphaned rather than queued.

I did not find the cause by reading the itlwm RX/TX code, so the root cause is
unknown. Blocking QUIC only avoids the traffic that triggers it.

## Install

```
sudo bash blockquic.sh install
```

Verify (also after a reboot):

```
sudo bash blockquic.sh status
```

You should see `Status: Enabled` and a rule `block drop quick proto udp ... port 443`.

Remove:

```
sudo bash blockquic.sh uninstall
```

On macOS 13+ you may get a "Background items added" notification. Keep the item
enabled in System Settings > General > Login Items, otherwise it will not start.

## Limitations

- Only UDP 443 is blocked. Other UDP traffic (calls, VPNs) is not covered.
- Apps will try QUIC first and then fall back to TCP, so some pages may start
  slightly slower.
- Keep **iCloud Private Relay off**: it relies on QUIC.
- It is a firewall rule, not a kext change. When a fixed AirportItlwm is released,
  run `uninstall` and test again.

## Check that this is your problem

Watch the 4KB clusters while you browse:

```
while true; do echo "$(date +%T) $(netstat -m | grep '4KB')"; sleep 10; done
```

If the first number keeps growing and does not come back down after closing the
app, and stays flat after you install the block, you are probably hitting the
same thing. Please report the numbers (and your card and kext version) in the
itlwm issues:

- https://github.com/OpenIntelWireless/itlwm/issues/1010
- https://github.com/OpenIntelWireless/itlwm/issues/975

## Tested on

- Intel Dual Band Wireless-AC 8265 (PCI device-id 0x24FD)
- AirportItlwm 2.3.0 (Sonoma 14.4+ build)
- macOS 14.x (build 23J520), OpenCore

No guarantee for other cards, kext versions or macOS versions.

## Italiano (breve)

Blocca UDP 443 (QUIC) a ogni avvio per evitare il leak di mbuf (panic
`mbuf_watchdog`) con AirportItlwm 2.3.0 e scheda Intel AC 8265 su Sonoma.
Installa con `sudo bash blockquic.sh install`, controlla con
`sudo bash blockquic.sh status`, rimuovi con `uninstall`. È un workaround, non una
correzione del driver.

## License

MIT, see `LICENSE`.
