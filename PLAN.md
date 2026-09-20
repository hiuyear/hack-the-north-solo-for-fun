# Implementation Plan — Hacker Badge Controllers for SuperTuxKart

## Session mode

Build Mode. Continue the existing implementation; do not restart or replace it.

## Objective

Make one or two 2026 Hacker Badges work as wired USB controllers for local SuperTuxKart 1.5 on macOS.

- SuperTuxKart owns the game UI, maps, physics, items, CPU racers, and split-screen.
- Both badges remain connected by USB data cables while playing.
- Badge radio, Wi-Fi, BLE gameplay, and internet are prohibited.
- Hold **A** to accelerate, **LEFT/RIGHT** to steer, **B** to brake, and shake to activate nitro.

## Current state

Already implemented:

- complete IDE-importable Lua controller: `badge-controller/kart-controller.lua`;
- native Swift USB-serial-to-keyboard bridge for up to two badges;
- distinct Player 1 and Player 2 keyboard mappings;
- shake-to-nitro event with a cooldown and short Mac key pulse;
- held-button heartbeat to repair stuck inputs;
- automatic `/dev/cu.usbmodem*` discovery;
- macOS Accessibility permission prompt;
- `start.command` launcher;
- parser tests and a two-player simulation mode;
- setup instructions in `README.md`.

Verified on the Mac:

- `swift test`: 3 tests pass with 0 failures;
- `swift build -c release`: succeeds;
- `BadgeKartBridge --demo`: both player mappings produce the expected presses and releases, including nitro release;
- a badge serial device currently appears as `/dev/cu.usbmodem101`;
- SuperTuxKart is not installed yet.

## Architecture

```text
Badge buttons/shake
        ↓
Lua app emits KART1-prefixed lines with badge.sys.log()
        ↓ USB serial
BadgeKartBridge parses and validates messages
        ↓ macOS synthesized key events
SuperTuxKart keyboard configurations
        ↓
One-player or local split-screen race
```

## Control mappings

| Badge input | Game action |
|---|---|
| Hold A | Accelerate |
| LEFT / RIGHT | Steer |
| Hold B | Brake/reverse |
| UP | Use item |
| Hold DOWN | Drift |
| AUX1 | Rescue |
| START | Menu select |
| Shake | Nitro |
| HOME | Exit badge controller app |

Player 1 emits the arrow-key layout plus Space/N/V/Delete/Return. Player 2 emits W/A/S/D plus F/E/G/R/Y. Do not merge these layouts: SuperTuxKart distinguishes the two players by their non-conflicting keys.

## Next increment: physical one-badge proof

1. Read `README.md` and the supplied badge IDE guide before editing.
2. Import the entire `badge-controller/kart-controller.lua` through **Import app**.
3. Connect the badge in the IDE and use **Push**.
4. Open **Kart Controller** on the badge.
5. Disconnect/close the Badge IDE so it releases the serial port.
6. Run `start.command`.
7. Grant the generated `BadgeKartBridge` Accessibility permission, then restart it.
8. Confirm the bridge prints `Player 1 controller ready`.
9. Verify A press/release, steering, brake, item, drift, rescue, START, and one nitro event per shake.
10. Unplug while holding A and prove all synthesized keys release.

Stop after this increment. Report the exact observed evidence, any firmware/serial error, and a suggested commit message. Do not claim hardware success without seeing it.

## Following increment: SuperTuxKart integration

Only after the one-badge proof:

1. Install the official signed SuperTuxKart 1.5 macOS build.
2. Configure Player 1 with the mapping documented in `README.md`.
3. Finish a complete race using one badge and CPU racers.
4. Test windowed mode first if full-screen ignores synthesized input.
5. Record any mapping changes in both `README.md` and the Swift key map.

## Final increment: two-player proof

1. Push the same Lua app to the second badge.
2. Connect both USB data cables before starting the bridge.
3. Confirm sorted-port assignment and LED/controller identity are understandable.
4. Add SuperTuxKart's second keyboard configuration using the README mapping.
5. Join two players and complete a local split-screen race.
6. Unplug either badge during a race and verify its keys release without affecting the other player.

## Guardrails

- Never enable `badge.radio` or add any wireless fallback.
- Do not fork, rebuild, or patch SuperTuxKart for the MVP.
- Do not overwrite working code merely to change style.
- Preserve the `KART1|` protocol prefix and validate untrusted serial lines.
- The IDE and bridge cannot own the same serial port simultaneously.
- Keep keyboard fallback available.
- Do not commit or push unless repository instructions explicitly permit it; suggest commit messages instead.
- Treat the physical badge and SuperTuxKart race as required evidence, not optional polish.

## Verification commands

```sh
swift test
swift build -c release
.build/release/badge-kart-bridge --demo
```

Expected baseline: 3 parser tests pass, the release build succeeds, and the demo shows both BOOST keys returning to `UP`.

## Definition of done

- One badge completes a SuperTuxKart race against CPU racers.
- Two badges independently control two local split-screen players.
- Shake triggers nitro once per physical shake.
- Disconnecting or exiting never leaves acceleration/steering keys stuck.
- No badge radio, Wi-Fi, BLE gameplay, or runtime internet is used.

