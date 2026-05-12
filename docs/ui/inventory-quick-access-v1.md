# Inventory Quick-Access v1 (Gamepad-Focused)

## Design Goals

- 1–2 button presses to reach core tools: fiber wire, lockpick, silenced pistol, coin.
- Do not replace the full inventory wheel; instead, layer a "favorites band" on top.
- Keep mappings consistent across titles for muscle memory.

## Default Layout (Xbox-style)

- D-pad Up: Contextual lethal tool
  - Default: Fiber wire
  - Override: Last-used lethal melee (knife, screwdriver) if marked as favorite.

- D-pad Right: Precision firearm
  - Default: Suppressed pistol (Silverballer).
  - Long-press: Cycle between favorited pistols/snubs.

- D-pad Left: Access / utility
  - Tap: Lockpick (or keycard scraper).
  - Hold: Cycle access tools (crowbar, breaching charge, EMP key).

- D-pad Down: Social / distraction
  - Tap: Coin.
  - Double-tap: Last-used nonlethal distraction gadget (noise maker, micro taser, accident bait).
  - Hold: Radial mini-menu limited to 4 distraction favorites.

## Interaction Rules

- Quick-access never shows items that the current disguise cannot legally hold if this would immediately break stealth.
- If a quick-access item would be illegal, the HUD flashes a small "illegal" icon and requires a confirmation hold to equip.
- When inventory changes (new gadget, weapon dropped), the system proposes smart re-slotting but never overwrites player-defined favorites.
