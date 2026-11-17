# Touch controls and the menu's way back

Status: done (2026-11-17). Code: `scripts/ui/touch_layout.gd`, `scripts/ui/touch_controls.gd`, `scripts/ui/pause_menu.gd`,
`scripts/core/main.gd`. Setting: `touch/layout` in the settings file. Requested by the tester for Android.

## 1. Overview

On a phone or tablet the game draws on-screen controls (two sticks and buttons). Three changes make them the player's own:

| What | Where |
|---|---|
| A **Back to game** button that is always at the top of the menu, plus the Android back key | Pause menu |
| An **Edit touch controls** button that opens a layout editor | Pause menu (touchscreens only) |
| In the editor: **drag** a button to move it, **tap once** to select it (a small red x appears) and tap the x to remove it, **+ Add button** to put one on screen, Reset to default, Done | Touch controls |

The layout is saved with the settings and comes back after a restart.

## 2. Player Fantasy

"My thumbs, my buttons." A left-handed player puts FIRE under their right thumb; someone who never uses the radio
takes RADIO away; someone who drives a lot adds GAS and BRAKE. Nothing is ever lost: a removed button can be added back.

## 3. Detailed Rules

### The menu
- **Back to game** is outside the scrolling settings list, 64 px high, so it is never scrolled out of reach. It closes
  the menu and unpauses (the same as Esc).
- **Android back key** (`NOTIFICATION_WM_GO_BACK_REQUEST`; the project sets `quit_on_go_back=false`): finishes the
  editor if it is open, otherwise closes the menu, otherwise (while playing) opens the menu.
- **Edit touch controls** shows only when the touch controls are in use. Tapping it hides the menu (the game stays
  paused) and opens the editor.

### The editor
- The screen dims, every button is drawn, and a bar at the top shows the instructions and three buttons.
- **Drag:** press a button, move more than `DRAG_SLOP` (10 px) and it follows the finger; let go to drop it. It cannot
  leave the screen (its edge keeps `EDGE_MARGIN` from the screen's edge). Dragging does not press the button or select it.
- **Select:** a tap (a touch that moves less than `DRAG_SLOP`) highlights the button with a gold ring and shows a small
  red x at its top right. Tapping empty space unselects.
- **Remove:** tap the x. The MENU button can be selected but has no x: it is the way back here, so it can never be removed.
- **+ Add button:** opens a list of every button that is not on screen (removed defaults and three extras: SWAP
  `switch_weapon`, GAS `accelerate`, BRAKE `brake`). Tapping one adds it. A removed default goes back where it was; an
  extra appears near the top middle (`ADD_AT`), selected and ready to drag. While the list is open nothing else reacts.
- **Reset to default** restores all 13 default buttons in their places and drops the extras.
- **Done** saves the layout, leaves the editor and returns to the menu. Esc, B and the Android back key also finish it.
- The two sticks stay where they are (they are not part of this change).
- While editing, no button presses its action.

### The layout (`TouchLayout`)
- Positions are fractions of the screen, so a layout works on another phone and when the screen turns.
- Saved as `{"pos": {id: [x, y]}, "removed": [ids], "added": [ids]}` (positions to 4 decimals: a tenth of a pixel).
- A damaged or unknown saved layout is ignored piece by piece (unknown ids, wrong types, MENU in `removed`,
  positions outside 0..1 are clamped); the game never fails to start because of it.

## 4. Formulas

- Button centre in pixels: default `(size.x - at.x, size.y - at.y)` from the bottom right (`"br"`), `(size.x - at.x, at.y)`
  from the top right (`"tr"`) or `(at.x, size.y - at.y)` from the bottom left (`"bl"`); or, once moved, `position * size`.
- Kept on screen: `x` in `[r + EDGE_MARGIN, size.x - r - EDGE_MARGIN]`, the same for `y`.
  Example: FIRE (r 56) on a 1280 x 720 screen dragged to (-500, 5000) ends at (62, 658).
- Hit area: a touch counts as on a button within `1.15 * r` of its centre; the x within `1.7 * BADGE_RADIUS` (15 px) of
  its centre, which sits at `(+0.78 r, -0.78 r)` from the button's.

## 5. Edge Cases

- Removing the same button twice, adding one that is already there, removing MENU: no change.
- A drag from a finger that is not the one that started it is ignored; a second finger cannot start a drag mid-drag.
- Tapping the x of a button that was just moved: works (selection and position are independent).
- A phone's emulated mouse events are ignored in the editor (one tap would count twice); on a PC the left mouse button
  and its drag do the same job, for testing with `-- --touch`.
- The saved layout names a button that a later version removed from the catalog: that entry is dropped.
- A new screen size: positions are fractions, so buttons keep their relative places and stay on screen.

## 6. Dependencies

- Uses: `SettingsStore` (`touch/layout`), `PauseMenu`, `Player` (input switch), the input actions of each button.
- Used by: `Main` (wires the menu, the editor and the settings; Android back key), `InputHints` (prompts name the buttons;
  a removed button's prompt text still says its name, which is harmless).

## 7. Tuning Knobs

| Knob | Where | Default | Safe range | Affects |
|---|---|---|---|---|
| `TouchLayout.CATALOG` (radius, default place, label) | `touch_layout.gd` | 13 defaults + 3 extras | | Which buttons exist and their size |
| `DRAG_SLOP` | `TouchControls` | 10 px | 5 to 20 | How far a touch moves before it is a drag, not a tap |
| `BADGE_RADIUS` | `TouchControls` | 15 px | 12 to 24 | Size of the remove x |
| `EDGE_MARGIN` / `ADD_AT` | `TouchLayout` | 6 px / (0.5, 0.3) | | Edge clearance; where an added button appears |
| Back button height | `PauseMenu` | 64 px | 48 to 80 | How easy it is to hit |

## 8. Acceptance Criteria

Each has a check in `tests/run_tests.gd` (`_test_touch_layout_units`, `_test_touch_editor_in_game`).

1. A new layout has the 13 default buttons and 3 extras to add; defaults sit where they always did.
2. A button can be moved, stays on the screen, and keeps its relative place on a bigger screen.
3. A button can be removed and added back; MENU cannot be removed; extras appear near the top middle.
4. A layout survives saving and loading, damaged data is ignored, positions are clamped, and the settings file keeps it.
5. The menu has a big Back button outside the scrolling list that closes the menu and unpauses.
6. The Edit button is hidden on a PC and shown with touch controls; it opens the editor over the paused game.
7. Dragging moves a button without pressing or selecting it; a tap selects it; tapping the x removes it; tapping empty
   space unselects; MENU keeps itself.
8. Add button lists what is missing; the list is modal; adding puts the button near the top middle, selected.
9. Done returns to the menu and saves; the new layout is in use (moved, removed and added buttons work); it survives a restart.
10. Reset to default restores everything; the Android back key ends the editor, then closes the menu, then opens it.
