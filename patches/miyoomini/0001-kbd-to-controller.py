#!/usr/bin/env python3
"""
Miyoo Mini: translate keyboard events to controller events.

The Mini has no /dev/input/js0 — physical buttons are keyboard events on
/dev/input/event0 via the gpio_keys driver. Without this translation,
SDL_GameController sees no controller and vTree gets zero input.

Mapping follows PyUI's miyoo_mini_common.py, converted from physical-label
names to SDL's Xbox-normalized button names (physical A on Nintendo layout
= east = SDL_CONTROLLER_BUTTON_B, etc).

Applied by build-miyoomini.sh (/patches/*.py loop).
"""
import re
import sys

PATH = "main.c"

HELPER = '''\
// ---------------------------------------------------------------------------
// Miyoo Mini: keyboard -> controller translation. gpio_keys on Mini emits
// keyboard events (no js0), so we rewrite SDL_KEYDOWN/UP into
// SDL_CONTROLLERBUTTONDOWN/UP before the main dispatcher sees them.
// ---------------------------------------------------------------------------
static SDL_GameControllerButton key_to_button(SDL_Scancode sc) {
    switch (sc) {
        case SDL_SCANCODE_SPACE:  return SDL_CONTROLLER_BUTTON_B;              // A (east)
        case SDL_SCANCODE_LCTRL:  return SDL_CONTROLLER_BUTTON_A;              // B (south)
        case SDL_SCANCODE_LSHIFT: return SDL_CONTROLLER_BUTTON_Y;              // X (north)
        case SDL_SCANCODE_LALT:   return SDL_CONTROLLER_BUTTON_X;              // Y (west)
        case SDL_SCANCODE_RETURN: return SDL_CONTROLLER_BUTTON_START;
        case SDL_SCANCODE_RCTRL:  return SDL_CONTROLLER_BUTTON_BACK;           // Select
        case SDL_SCANCODE_ESCAPE: return SDL_CONTROLLER_BUTTON_GUIDE;          // Menu
        case SDL_SCANCODE_E:      return SDL_CONTROLLER_BUTTON_LEFTSHOULDER;   // L1
        case SDL_SCANCODE_T:      return SDL_CONTROLLER_BUTTON_RIGHTSHOULDER;  // R1
        case SDL_SCANCODE_UP:     return SDL_CONTROLLER_BUTTON_DPAD_UP;
        case SDL_SCANCODE_DOWN:   return SDL_CONTROLLER_BUTTON_DPAD_DOWN;
        case SDL_SCANCODE_LEFT:   return SDL_CONTROLLER_BUTTON_DPAD_LEFT;
        case SDL_SCANCODE_RIGHT:  return SDL_CONTROLLER_BUTTON_DPAD_RIGHT;
        default:                  return SDL_CONTROLLER_BUTTON_INVALID;
    }
}

'''

DISPATCH = '''\
            // Translate Mini kbd events to controller events before dispatch.
            if (ev.type == SDL_KEYDOWN || ev.type == SDL_KEYUP) {
                SDL_GameControllerButton btn =
                    key_to_button(ev.key.keysym.scancode);
                if (btn != SDL_CONTROLLER_BUTTON_INVALID) {
                    Uint32 new_type = (ev.type == SDL_KEYDOWN) ?
                        SDL_CONTROLLERBUTTONDOWN : SDL_CONTROLLERBUTTONUP;
                    ev.type = new_type;
                    ev.cbutton.button = (Uint8)btn;
                }
            }
'''

with open(PATH, "r") as f:
    src = f.read()

# 1. Insert helper immediately before "int main(int argc, char *argv[]) {"
needle = "int main(int argc, char *argv[]) {"
if needle not in src:
    sys.exit("patch failed: can't find main() definition")
if "key_to_button(" in src:
    sys.exit("patch failed: key_to_button already present (double-apply?)")
src = src.replace(needle, HELPER + needle, 1)

# 2. Insert dispatch at the start of the inner `while (SDL_PollEvent(&ev)) {`
# Match the exact line (with whitespace) so we preserve indentation.
pat = re.compile(
    r"(^[ \t]*while \(SDL_PollEvent\(&ev\)\) \{\n)", re.MULTILINE
)
m = pat.search(src)
if not m:
    sys.exit("patch failed: can't find SDL_PollEvent loop")
src = src[: m.end()] + DISPATCH + src[m.end() :]

with open(PATH, "w") as f:
    f.write(src)

print("Mini kbd-to-controller patch applied OK.")
