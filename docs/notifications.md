# Notification center

Open **Notices** in the top utility bar, **Tools → Open notifications**, or
**Views → Notifications**. Configure it through **aardwolf-config → Notifications**.
The utility item follows the existing overflow menu when the bar is narrow.

The inbox collects session-only observations from existing Toolbox services:

| Category | Initial sources |
|---|---|
| Info | Quest state/target changes; server spellup batch started/finished |
| Warning | Failed broker requests; changed feature activation errors; paused spellups |
| Chat | Incoming tell/mention or rule-requested chat notices |
| Combat | Entry into the fighting state reported by fresh character GMCP |

Combat entry does not identify every attacker, infer kills, or claim combat has
ended. Room mobs and target Vitals continue to own detailed combat tracking.
A spellup-finished notice does not mean every possible buff is active; inspect
Buffs for observed coverage. Cancelled or drained requests are not failures.
No new monitoring, polling, triggers, gameplay commands or subscriptions are
added. Notices do not invoke actions, casts, movement, quests or retries.

## Reading and presentation

- Filter by All, Unread, Info, Warning, Combat or Chat. Pages fit the available list height, with at most
  20 retained rows. The full selected notice appears in the scrollable reading
  area below the page controls; hover tooltips remain available.
- Click a row to mark it read, or choose **Mark all read**. Opening the view does
  not mark unseen pages read. **Clear** removes the session inbox.
- Labels and category colors remain separate: turning colors off keeps explicit
  Info/Warning/Combat text. Typography follows shared Appearance preferences.
- **View** offers an external window or return to the in-profile window.
  Use **Close** in the profile or the external window’s native close button.
  Use **Shift+Escape** to close while typing; Mudlet consumes plain Escape
  in command inputs.
  Closing hides the view while tracking and unread counts continue. Settings
  remain accessible through the shared settings window if the utility bar is off.
- The center retains 100 notices by default, configurable from 20–500. Matching
  source/key/category/title/message repeats within 30 seconds update one row,
  increment its count and mark it unread. The repeat count caps at 9,999.
- Disconnect, a new connection, GMCP reset, disable and uninstall clear notices.
  Only preferences persist; notification text is not written to disk.

**Pulsing and sound start disabled.** Enabling pulsing briefly alternates the
utility indicator color for a new warning/combat notice, lasting six seconds.
Reading all notices cancels it. It does not blink continuously while idle.

Sound requires an absolute local audio-file path supported by Mudlet's
`playSoundFile`. Files are not downloaded. Audio attempts are limited to once
per ten seconds, and coalesced repeats do not replay the sound. Unavailable
files/API or failed playback appear in notification status; actual audible
playback depends on native audio support. No sound is bundled. See Diagnostics
for service status. Audio must be tested separately with explicit preferences.

## Keyboard reading

In the in-profile inbox:

| Shortcut | Behavior |
|---|---|
| Alt+J / Alt+K | Highlight next / previous notice and read its complete text; cross pages as needed. |
| Alt+H / Alt+L | Previous / next page; clear selection. |
| Alt+Enter | Mark only the explicitly selected notice read. |
| Shift+Escape | Close the inbox and release its keys. |

New arrivals and resizing retain the selected notification by identity. Selection
clears when its filter excludes it or it is evicted/reset. A repeated notice
arriving before the queued redraw is displayed first; press Alt+Enter again to
mark that updated observation read. Marking a notice read in Unread removes its
row without automatically selecting the next unread notice.

These controls never send commands or edit the main command-input text. Toolbox
action/navigation shortcuts pause while the inbox is open. External windows
retain mouse controls until native window focus routing is available. Very short
windows scroll the whole inbox to keep controls and full text accessible.

Chat notices use their own sound/desktop policy in **Chat and communications**;
notification-center warning/combat audio is not replayed for chat. See [chat](chat.md).

## Consumer API

```lua
local toolbox = AardwolfToolbox
local accepted, reason = toolbox.notifications.post({
  category = 'info',
  source = 'example',
  key = 'observation', -- optional key for coalescing identical repeated notices
  title = 'Observation recorded',
  message = 'This is literal text, not markup or a command.',
  session = toolbox.gmcp.session, -- include the captured session for async work
})
```

`post()` returns true for accepted delivery, or `nil, reason`. Delivery occurs
through the incoming dispatcher's deferred boundary, after line suppression.
A reset or disable before delivery discards stale work. The post result is not a
record ID; consumers receive the actual retained ID in the update event.

- `notifications.list(category, unreadOnly)` returns defensive copies, newest
  first. Omit category to include every category.
- `notifications.get(id)` returns a defensive copy or nil after eviction/reset.
- `notifications.markRead(id)` marks one notice read; omit the ID for all.
- `notifications.clear()` empties the inbox.
- `notifications.status()` returns counts, session, revision and service status,
  without returning notice contents. `aardwolf-status`/Diagnostics include this.
- `AardwolfToolbox.notifications.updated` carries the changed record ID and a
  boolean indicating a new warning/combat alert. Read/clear/configuration events
  may have no record ID. Consumers should fetch current state, not retain it.

Records include numeric ID/session, source, category, optional key, title,
message, created/updated epoch times, repetition count and read state. Strings
are literal. Limits are 80 bytes for source, 160 for title, 1,024 for message and
120 for key; blank/control-character values and unsupported fields are rejected.
Use a captured session on delayed observations. Never use the inbox as a raw
output logger or substitute it for authoritative feature state.

## Verification and native checklist

Repository tests cover event delivery, limits, repeated notices, session resets,
filters, typography, retained rows, hidden-view rendering, read/clear, paging,
external reparenting, pulse/audio opt-in, storage preferences and lifecycle.
They do not establish native geometry, audible playback or actual mouse focus.

Partial offline native acceptance is recorded in [verification](../tests/verification.md):
filters, read counts, paging, scrolling, external close/reopen/reflow and cleanup
passed. External mouse targeting was blocked by the control tool; native audio,
the full size matrix and live sources remain unverified.

For another authorized session, back up the disconnected
`AardwolfToolboxSettingsTest` profile/package/settings/database/map before installing.
Run `tests/native_foundation.lua`, then `tests/native_notifications.lua` there only.

1. Verify 26 synthetic notices, literal Unicode/angle brackets, colors, tooltips,
   filters, paging, scroll position, read/clear and utility unread counts.
2. Resize at 1280×800, 1920×1080 and narrow widths; preserve readable fonts and
   minimum control heights. Check utility overflow and Settings access.
3. Float, resize, close/reopen and return to the profile; verify one content tree.
   Check keyboard focus and Close without changing the main command input.
4. Restore `AardwolfToolboxNotificationAcceptance` before foundation interceptors.
   Verify zero dispatch, unchanged native map and complete stop/start cleanup.
5. Check optional pulses separately; do not enable sound or replay fixtures in a
   player profile. Native audio and naturally arriving sources remain unverified.
