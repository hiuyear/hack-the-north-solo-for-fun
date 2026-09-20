--[==[badge-app
slug=badge_kart
name=Kart Controller
icon=KART
api=2
heap_kb=48
wake_lock=1
confirm_home=1
version=0.1.0
]==]

-- Controls:
-- Hold A: accelerate          LEFT / RIGHT: steer
-- Hold B: brake              UP: use item
-- Hold DOWN: drift           AUX1: rescue
-- START: menu select         Shake: nitro boost

local sequence = 0
local next_heartbeat_ms = 0
local next_boost_ms = 0
local boost_until_ms = 0
local status_label
local detail_label

local button_names = {
  [badge.input.BUTTON.A] = "A",
  [badge.input.BUTTON.B] = "B",
  [badge.input.BUTTON.LEFT] = "LEFT",
  [badge.input.BUTTON.RIGHT] = "RIGHT",
  [badge.input.BUTTON.UP] = "UP",
  [badge.input.BUTTON.DOWN] = "DOWN",
  [badge.input.BUTTON.AUX1] = "AUX1",
  [badge.input.BUTTON.START] = "START",
}

local function next_sequence()
  sequence = (sequence + 1) % 65536
  return sequence
end

local function held_mask()
  local value = 0
  if badge.input.is_down(badge.input.BUTTON.A) then value = value + 1 end
  if badge.input.is_down(badge.input.BUTTON.LEFT) then value = value + 2 end
  if badge.input.is_down(badge.input.BUTTON.RIGHT) then value = value + 4 end
  if badge.input.is_down(badge.input.BUTTON.B) then value = value + 8 end
  if badge.input.is_down(badge.input.BUTTON.UP) then value = value + 16 end
  if badge.input.is_down(badge.input.BUTTON.DOWN) then value = value + 32 end
  if badge.input.is_down(badge.input.BUTTON.AUX1) then value = value + 64 end
  if badge.input.is_down(badge.input.BUTTON.START) then value = value + 128 end
  return value
end

local function log_input(name, pressed)
  badge.sys.log("KART1|INPUT|" .. next_sequence() .. "|" .. name .. "|" .. pressed .. "|" .. held_mask())
end

local function show_idle_leds()
  badge.led.clear()
  badge.led.set(1, 0, 80, 255)
  badge.led.set(2, 0, 80, 255)
  badge.led.set(5, 0, 24, 80)
  badge.led.set(4, 0, 24, 80)
  badge.led.show()
end

local function show_boost_leds()
  badge.led.clear()
  badge.led.set(1, 255, 40, 0)
  badge.led.set(2, 255, 120, 0)
  badge.led.set(3, 255, 220, 0)
  badge.led.set(4, 255, 255, 255)
  badge.led.set(5, 255, 220, 0)
  badge.led.set(6, 255, 120, 0)
  badge.led.show()
end

function on_enter(root)
  local background = badge.ui.box(root, 300, 220)
  background:align("center", 0, 0)
  background:style({bg_color = 0x081426, border_color = 0x2488ff, border_width = 2, radius = 14})

  local title = badge.ui.label(background, "KART CONTROLLER")
  title:style({text_color = 0xffffff, text_font = 22})
  title:align("top_mid", 0, 18)

  status_label = badge.ui.label(background, "USB ready")
  status_label:style({text_color = 0x45d7ff, text_font = 20})
  status_label:align("top_mid", 0, 58)

  detail_label = badge.ui.label(background, "Hold A to drive\nLEFT / RIGHT to steer\nShake for nitro")
  detail_label:style({text_color = 0xd6e9ff, text_font = 16, text_align = "center"})
  detail_label:align("center", 0, 18)

  local footer = badge.ui.label(background, "UP item  B brake  DOWN drift")
  footer:style({text_color = 0x8196b2, text_font = 14})
  footer:align("bottom_mid", 0, -16)

  show_idle_leds()
  local now = badge.sys.ms()
  next_heartbeat_ms = now + 500
  badge.sys.log("KART1|READY|" .. next_sequence())
end

function on_tick()
  local now = badge.sys.ms()

  if badge.sensor.shake() and now >= next_boost_ms then
    next_boost_ms = now + 800
    boost_until_ms = now + 300
    badge.sys.log("KART1|BOOST|" .. next_sequence() .. "|" .. now)
    status_label:set_text("NITRO!")
    show_boost_leds()
  end

  if boost_until_ms > 0 and now >= boost_until_ms then
    boost_until_ms = 0
    status_label:set_text("USB ready")
    show_idle_leds()
  end

  if now >= next_heartbeat_ms then
    next_heartbeat_ms = now + 500
    badge.sys.log("KART1|HEARTBEAT|" .. next_sequence() .. "|" .. held_mask() .. "|" .. now)
  end
end

function on_button(button, kind)
  local name = button_names[button]
  if not name then return end

  if kind == badge.input.KIND.PRESSED then
    log_input(name, 1)
    status_label:set_text(name)
  elseif kind == badge.input.KIND.RELEASED then
    log_input(name, 0)
    if boost_until_ms == 0 then status_label:set_text("USB ready") end
  end
end

function on_exit()
  badge.sys.log("KART1|HEARTBEAT|" .. next_sequence() .. "|0|" .. badge.sys.ms())
  badge.led.clear()
  badge.led.show()
end

