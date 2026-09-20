# Hacker Badge controllers for SuperTuxKart

This project turns one or two 2026 Hacker Badges into wired USB controllers for SuperTuxKart on a Mac. The badges never use radio, Wi-Fi, or internet.

For an IDE coding agent, start with `PLAN.md`; it records the verified baseline, next hardware checkpoint, and completion criteria.

## What you install

1. Install [SuperTuxKart 1.5 for macOS](https://github.com/supertuxkart/stk-code/releases/tag/1.5).
2. Import `badge-controller/kart-controller.lua` into the Hacker Badge IDE and push it to each badge.
3. Run `start.command` on the Mac. On the first run, grant `BadgeKartBridge` the requested Accessibility permission and run `start.command` again. Keep its window open while playing.
4. Start SuperTuxKart and configure the controls below.

The IDE and bridge cannot use the same badge serial port simultaneously. After pushing the controller app, disconnect or close the IDE before starting the bridge.

## Badge controls

| Badge | Action |
|---|---|
| Hold A | Accelerate |
| LEFT / RIGHT | Steer |
| Hold B | Brake / reverse |
| UP | Use item |
| Hold DOWN | Drift |
| AUX1 | Rescue |
| START | Menu select |
| Shake | Nitro boost |
| HOME | Exit the badge app |

## SuperTuxKart control mappings

Player 1 uses SuperTuxKart's usual keyboard-style controls:

| Action | Key emitted |
|---|---|
| Steer | Left / Right arrows |
| Accelerate / brake | Up / Down arrows |
| Fire item | Space |
| Nitro | N |
| Drift | V |
| Rescue | Delete |
| Menu select | Return |

For Player 2, open **Options → Controls → Add a keyboard configuration** and assign:

| Action | Key emitted |
|---|---|
| Steer left / right | A / D |
| Accelerate / brake | W / S |
| Fire item | F |
| Nitro | E |
| Drift | G |
| Rescue | R |
| Menu select | Y |

SuperTuxKart treats keyboard configurations as key sets rather than physical keyboards, so these non-conflicting layouts allow two badge players on one Mac.

## Starting a race

1. Connect both badges with USB data cables and open **Kart Controller** on each.
2. Disconnect the Badge IDE.
3. Double-click `start.command`. Badge ports are assigned in sorted order: first is Player 1, second is Player 2.
4. Open SuperTuxKart, select local multiplayer, choose the karts/map, and race.

If macOS blocks synthetic keys, add the generated `BadgeKartBridge` file under **System Settings → Privacy & Security → Accessibility**, then restart `start.command`. Windowed SuperTuxKart is the first fallback if full-screen input is blocked.

## Diagnostics

Build and run the input demonstration without badges:

```sh
swift run badge-kart-bridge --demo
```

Run automated parser tests:

```sh
swift test
```

Pass explicit badge ports if automatic ordering is wrong:

```sh
.build/release/badge-kart-bridge /dev/cu.usbmodem101 /dev/cu.usbmodem201
```
