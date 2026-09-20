# Hacker Badge controllers for SuperTuxKart

This project turns one or two 2026 Hacker Badges into wired USB controllers for SuperTuxKart on a Mac. The badges never use radio, Wi-Fi, or internet.

For an IDE coding agent, start with `PLAN.md`; it records the verified baseline, next hardware checkpoint, and completion criteria.

## What you install

1. Install [SuperTuxKart 1.5 for macOS](https://github.com/supertuxkart/stk-code/releases/tag/1.5) (not needed for the one-badge serial proof).
2. Import `badge-controller/kart-controller.lua` into the Hacker Badge IDE and push it to each badge.
3. Close the Badge IDE so it releases the serial port.
4. Double-click `start.command`. It builds the bridge, installs **`~/Applications/BadgeKartBridge.app`** (bundle id `com.hiuyear.BadgeKartBridge`), and launches that `.app`.
5. Grant Accessibility to **that installed `.app`**, then run `start.command` again. Keep the Terminal window open while playing.

The IDE and bridge cannot use the same badge serial port simultaneously. After pushing the controller app, disconnect or close the IDE before starting the bridge.

Opening the serial port must **not** assert DTR/RTS. On this Espressif USB-Serial-JTAG badge, DTR is reset: the chip reboots, USB drops, and Kart Controller dies.

### Accessibility: why BadgeKartBridge may be missing from the list

macOS often shows the Accessibility prompt but **does not add BadgeKartBridge to the list**. A raw binary launched from Terminal is also the wrong identity (Terminal / Cursor / iTerm get the checkbox instead).

Add the app with **+**:

1. Open **System Settings → Privacy & Security → Accessibility**.
2. Click **+** (unlock first if needed).
3. Press **Command-Shift-G** and paste `~/Applications/BadgeKartBridge.app`.
4. Select **BadgeKartBridge.app** and turn the switch on.
5. Run `start.command` again.

Do not enable Terminal or Cursor in place of `BadgeKartBridge.app`. `start.command` only resigns the app when the binary actually changed, so TCC can remember it.

## Two-minute one-badge proof

1. Badge is on a **USB data** cable. Kart Controller is open. Badge IDE is **closed**.
2. Double-click `start.command`. Wait for `Player 1 controller ready`.
3. If the log says Accessibility is OFF, do the **+** steps above and rerun.
4. Press and release **A**, **LEFT**, **RIGHT**, **B**, **UP**, **DOWN**, **AUX1**, **START**. Each should print `DOWN` then `UP`.
5. Shake once. Expect one `BOOST` / `N DOWN` then `N UP`.
6. Hold **A**, unplug the badge. Expect `disconnected; released all keys`.

Keyboard fallback still works if the badge is unplugged: SuperTuxKart can be driven with the same keys listed below.

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

SuperTuxKart treats keyboard configurations as key sets rather than physical keyboards, so these non-conflicting layouts allow two badge players on one Mac. Never merge these layouts.

## Starting a race

1. Connect both badges with USB data cables and open **Kart Controller** on each.
2. Disconnect the Badge IDE.
3. Double-click `start.command`. Badge ports are assigned in sorted `/dev/cu.usbmodem*` order: first is Player 1, second is Player 2.
4. Open SuperTuxKart, select local multiplayer, choose the karts/map, and race.

If macOS blocks synthetic keys, add **`~/Applications/BadgeKartBridge.app`** under **System Settings → Privacy & Security → Accessibility**, then restart `start.command`. Windowed SuperTuxKart is the first fallback if full-screen input is blocked.

Logs are written to `~/Library/Logs/BadgeKartBridge.log` and tailed in the `start.command` window.

## Diagnostics

Build and run the input demonstration without badges:

```sh
swift run badge-kart-bridge --demo
```

`--demo` from `swift run` is a Terminal child process. Use `start.command` (the installed `.app`) for the real Accessibility identity.

Run automated parser tests:

```sh
swift test
swift build -c release
```

Pass explicit badge ports if automatic ordering is wrong:

```sh
open ~/Applications/BadgeKartBridge.app --args /dev/cu.usbmodem101 /dev/cu.usbmodem201
```
