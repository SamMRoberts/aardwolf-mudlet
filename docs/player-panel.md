# Player sidebar panel

AardwolfToolbox 0.10.0 adds a compact panel immediately above docked chat and
below the graphical map in the existing Mudlet starter sidebar. It uses muted
text on a dark background, with no flashing indicators or duplicate Vitals bars.

The seven rows show name and level; race and class; STR/DEX/CON; INT/WIS/LCK;
hit roll/damage roll/saves; position and alignment; hunger and thirst. Values come
from the shared `char.base`, `char.stats`, and `char.status` GMCP cache snapshots.
Core stats show `stats/maxstats`, for example STR 165/*117*. The total from
`char.stats` uses regular type; the unbuffed/equipment-free value from
`char.maxstats` uses italic type. This applies to STR, DEX, CON, INT, WIS, and LCK.
Combat rolls remain single values because the schema has no matching maxima.
Missing readings show `--`. Status level takes precedence over base level.
Text from the server is escaped before display. No game commands are sent.

Open **aardwolf-config → Player panel** to toggle the panel or change its font
size (default 10 points, range 8–13). **GMCP data** must be enabled for readings.
Cache resets clear the displayed values. The cache emits
`AardwolfToolbox.gmcp.cleared` with the new session number for dependent features.

The panel reserves a compact fixed height from the top of chat's existing share;
the map's geometry is unchanged. It follows sidebar resizing. If chat is floating,
the sidebar is hidden, or there is insufficient height for the panel and at least
80 pixels of chat, the panel hides rather than covering another section. It
returns when the normal docked layout has enough room. Without the starter
sidebar, activation waits and reports that condition in settings status.

`AardwolfToolbox.player` exposes `start`, `configure`, `stop`, and `destroy`.
The integration wraps `BaseUI.layoutDock` reversibly without editing starter
package files, saving altered starter geometry, or adding global border space.
Disable/uninstall releases owned labels, handlers, and pending refreshes, restores
the original placement function when still owned, and relays out chat.
