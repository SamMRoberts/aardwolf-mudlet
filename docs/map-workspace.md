# Local map workspace

Available in **0.24.0-dev.7**. Open **Tools → Open map workspace**, or
**Views → Atlas**. Shared preferences are in **aardwolf-config → Map workspace**.
The native map is read only: this feature never moves the player, creates rooms,
repairs links, changes the mapper's center, or sends gameplay commands.

## Find rooms and save notes

Enter a literal search and press Enter. **Rooms** searches room names and native
room IDs; **Areas** lists rooms whose saved area name/ID matches. **Bookmarks**
searches saved labels, notes and IDs. Matching ignores ASCII case; Unicode text
is retained literally. Results are sorted by native ID. Pages fit the list height without reducing fonts
(up to 24 rows).
Click a row to inspect its area, coordinates, identity and saved exits.

In the tabbed workspace, **Alt+J/K** highlights the next/previous row, crossing
pages when needed. **Alt+H/L** changes pages and clears highlighting.
**Alt+Enter** inspects the highlighted room after checking its identity. Merely
highlighting leaves unfinished bookmark labels and notes unchanged; inspection
loads the selected room into those editors. **Shift+Escape** closes the workspace.
These keys never preview a route, save a bookmark, or travel. Detached windows
retain mouse interaction until native window focus routing is supported.

Edit the bookmark label and the note beneath the details, then click
**Save bookmark**. Enter in either editor does not save or send text. Notes are
single-line, up to 1,024 bytes; labels up to 160 bytes. There are at most 48 saved
rooms. **Remove bookmark** removes only that local entry. Shared settings also
provide the ordered editor for rename/delete and normal Apply/Cancel/defaults.
Create entries from a selected map room to record their identity correctly.

Entries bind to the room's verified game identity, or to its local ID/hash,
area and name when unverified. Missing/replaced rooms are labeled unavailable
rather than silently attaching the note elsewhere. Native ID migration may
require explicitly recreating the bookmark at the new ID. Bookmarks are stored
in the profile's version-3 Toolbox settings, outside the package. They survive
uninstall. Changed settings revisions and write failures leave the editor text
intact and do not overwrite saved values; reselect the room after reviewing a
stale-draft warning.

## Preview a route

Select a source room and click **Set route start**, then select a destination
and click **Preview route**. This works disconnected. **Use current room** clears
the local source and instead requires a fresh GMCP identity verified against the
saved map; it does not use the room selected or centered in the mapper.

The preview shows native path cost and each reported direction/destination.
Special exits, unexplored rooms and unverified identities are labeled. It cannot
prove that a door is open, that a portal command is currently usable, or that the
map is complete. No route produces a command or starts speedwalking. Existing
map double-click travel remains a separate explicitly activated feature.

Path queries use Mudlet's native `getPath`, revalidate each saved edge and restore
`speedWalkPath`, `speedWalkDir` and `speedWalkWeight`, including on failure.
See [Mudlet's mapper APIs](https://wiki.mudlet.org/w/Manual%3AMapper_Functions#getPath).

## Read-only map health

Click **Map health** for an on-demand snapshot:

- Toolbox identity/hash disagreement and native IDs differing from game IDs.
- Incomplete construction and placeholders whose saved provisional placement
  differs from current coordinates/area (possibly a manual edit).
- Shared coordinates, unknown areas, and exits referencing missing rooms.

One-way exits and non-adjacent connections are not automatically errors. Shared
coordinates may be intentional. The report does not offer automatic repairs.
Search/health inspection is bounded to 100,000 rooms; health retains the first
200 observations and category totals. Routes are limited to 4,096 steps.
No map indexes, snapshots, polling timers or raw logs are retained while closed.

## Placement and lifecycle

**View / Settings** provides Float outside Mudlet, Return to workspace, Reset
window placement and Settings. The same content moves between hosts. The body
scrolls at small sizes, and controls retain shared fonts and minimum heights.
Closing hides the view. Disabling removes its widgets and event handlers but
preserves bookmarks. Toolbox shortcuts pause while the editor is visible.

## Public APIs

`AardwolfToolbox.mapWorkspace` provides defensive-copy `get(id)`,
`search(text, "rooms" | "areas", page, pageSize)`, `bookmarks()`, `current()`,
`preview(fromId, toId, fromIdentity, toIdentity)` and `health()` observations.
The optional `pageSize` is an integer from 1–24, defaulting to 24 for existing
callers. Calls return a result or `nil, reason`. `save(id, identity, label, note, revision,
remove)` validates the selected identity and shared configuration revision.

```lua
local map = AardwolfToolbox.mapWorkspace
local source, destination = map.get(101), map.get(202)
if source and destination then
  local preview, reason = map.preview(source.id, destination.id,
    source.identity, destination.identity)
  -- Inspect preview.steps locally; this call cannot execute them.
end
```

`views.open("atlas")` opens the registered view; `views.setMode("atlas",
"floating")` persists its placement. Feature registration uses the existing
configuration and lifecycle contracts.

## Acceptance

Contract tests cover map preservation, errors, bounded results, stale identities,
atomic notes, lifecycle, placement and no dispatch. `tests/native_map_workspace.lua`
uses the disconnected disposable profile's existing map after the foundation
fixture. Mouse checks cover search, literal notes, source/destination selection,
route preview, health, scrolling and placement. Never run fixtures in Aardwolf.
Current native evidence and gaps are recorded in [verification](../tests/verification.md).
