# Floating help

AardwolfToolbox 0.11.0 displays tagged help in a movable, resizable floating pane:

```
{help}
{helpkeywords}CONSIDER
{helpbody}
The help text goes here.
{/helpbody}
{/help}
```

`helpkeywords` supplies the title. Lines between `helpbody` markers supply the
body, preserving blank lines and indentation. An empty keyword marker can also
be followed by keyword lines, ending at `{/helpkeywords}` or `{helpbody}`.
Missing keywords use the title “Help.” Text is literal: body content is not
interpreted as HTML, links, Lua, or consider messages. Server colors are replaced
with readable light text on black. The monospaced body wraps with the window.

A complete page replaces the previous page and raises the pane. Close hides it;
the next complete help page opens it again. Drag the title to move and the edges
to resize. The initial size is 620×440 pixels, clamped to the current window.
Placement is session-only, and Adjustable's separate layout persistence is off.

Use **aardwolf-config → Help pane** to enable/disable the feature or adjust the
font (11 points by default, range 8–18). While enabled, the entire help block is
hidden from the main console. It uses the shared incoming dispatcher after ASCII
maps and before Game tags/consider, independently of the Game tags enable switch.
Help-owned lines are not also recorded by generic tag capture. Disabling Help
returns ownership to the ordinary dispatcher, including Game tags if enabled.

Incomplete pages do not replace a completed page. Capture times out after ten
seconds, or aborts at 4,096 lines / 1 MiB, with a diagnostic and ordinary output
restored. Repeated help openings restart the partial page. Disconnect/reconnect
clears help data and hides the pane. Stop/uninstall releases the window, menu,
handlers, and timers. The component sends no help requests or other gameplay
commands and does not change server tag preferences.
