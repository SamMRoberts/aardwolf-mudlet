# Campaign and Global Quest tracking — development gate

The sidebar has separate **Campaign** and **Global Quest** tabs. Use **Views** or
**Tools → Open campaign / Open globalQuest** to open them. Each supports floating
outside the main Mudlet window and returning to its tab. Settings live under
**aardwolf-config → Campaign / Global Quest**, including placement, capture,
event-driven refresh, suppression, and candidate mob hints.

## What is usable in dev.23

The user supplied this Aardwolf response on 2026-09-14:

```text
You are not currently on a campaign.
You have completed 0 campaigns today.
You may take a campaign at this level.
```

The complete inactive/available response is supported. The command was not included
in the sample; its classification as `campaign info` follows the documented command
behavior and still needs native confirmation. **Refresh** can issue that informational
request when connected and command-ready. Unique begin/end `echo` markers surround
it; only a complete recognized response commits state. A successful manual response
verifies boundaries for that operation in that session.

The active `cp info` and `cp check` samples supplied on 2026-09-16 are now
supported. Refresh sends `campaign info`, then, for an active campaign, yields the
broker and requests `campaign check`. Info contains the assigned list, which does
not prove remaining progress; candidate hints wait for the check response. The
check replaces the remaining list while retaining level, advertised rewards and
the original **Complete By** text. Days/hours/minutes become approximate remaining
seconds; the displayed deadline is not converted using an assumed server timezone.

Locations are retained literally, including nested parentheses. The output does
not label a location as room versus area, so the parser preserves that uncertainty.
Map lookup searches both existing room names and exact area names. Truncated,
malformed and unsupported variants retain the last observation as stale. Zero
remaining rows or zero time do not mean completion.

**Global Quest wire formats and campaign terminal events remain unverified.**
No current examples for them have been supplied. Automatic collection still has no
accepted native boundary evidence and does not send on startup. A manual successful
response verifies its operation's boundaries for the current session. Unknown
responses stay visible and cannot overwrite the last valid observation.

Contract tests cover the shared collectors, objective model, SQLite storage, views,
and hints with an explicitly synthetic adapter. These tests are not live protocol
acceptance. No Mudlet profile has been controlled or upgraded for this candidate.

## Display and storage

Views provide Refresh, Copy, and Find on map. Select an objective before Find; an
ambiguous match list lets you center the map without walking or editing rooms.
Event details are separate from personal GQ participation and progress. The
**My progress / Event details** switch does not issue a request. GQ event inspection
uses a verified numeric event ID; inspecting another event cannot overwrite your
personal progress.

Readings distinguish missing values from zero. Reported countdowns are approximate;
zero displays **Awaiting update**, not completion. Advertised rewards and observed
awards stay separate. Duplicate objectives remain separate; an unavailable target
is not a credited kill. Room mobs can display **CP? / GQ?** name-based candidates
from fresh verified observations without changing target identity or combat state.

Latest observations live in `getMudletHomeDir()/AardwolfToolbox-objectives.sqlite3`,
keyed by character and tracker. This is independent of opt-in Local history. It
stores bounded normalized observations, not raw output. Writes are transactional;
failed writes retain the previous disk record and report unsaved state. Disconnect,
disable and reload mark observations stale; restored GQ participation is always
unconfirmed. Databases and preferences survive uninstall.

## APIs and extension contract

```lua
local cp = AardwolfToolbox.campaign.snapshot() -- defensive copy
local ok, why = AardwolfToolbox.campaign.refresh() -- guarded informational request
local status = AardwolfToolbox.globalQuest.status()
-- Only an ID from fresh availability/current participation may be inspected:
local ok, why = AardwolfToolbox.globalQuest.inspect(123)
```

Both services provide `start`, `configure`, `stop`, `destroy`, `snapshot`, `refresh`,
`status`, and `hints`. GQ also provides `inspect`. Update/reset events use
`AardwolfToolbox.campaign.updated/reset` and
`AardwolfToolbox.globalQuest.updated/reset`, after incoming-line suppression.
No whole catalog is broadcast. `mobs.snapshot().rows[].objectives` is additive;
the existing regular-quest `objective` field remains compatible.

The broker's optional `contextKeys` list chooses captured contexts. Defaults remain
`session`, `progression`, and `visit`; campaign/GQ use `session` plus an explicit
character guard. Active obsolete responses drain to their boundary/deadline.

The protocol adapter exposes `supported(kind, operation)`, `new(kind, operation)`
with `receive(line)` / `finish()`, `followUp(kind, operation, patch)`, and `automatic(kind, operation)`. Only checked
formats return supported. A future verified event adapter may return normalized
`patch`, `replace`, `reconcile`, and/or `refresh` evidence. Reconcile marks progress
stale and queues a check; it never guesses which duplicate mob received credit.

All requests use the shared broker and incoming dispatcher. Bounds are 10 seconds,
4,096 lines, 1 MiB response text, 512 normalized objectives/events, and at most three
pending operations per tracker. No periodic polling, automatic retry loop, pager
advancement, joins, campaign requests, quits, completion actions, or travel occurs.

## Required acceptance before enabling further formats

Supply full headings, body, ending lines, command and capture date for:

- Further campaign variants: identified room/area locations, unavailable mobs,
  credited kills, completion/rewards, cancellation, expiry, alternate availability
  footers and unavailable CP. Active info/check samples are recorded already.
- GQ zero/one/multiple event listings, numbered info, joined/not-joined checks,
  participation changes, credited kills, winners, extended/end/cancelled events.
- Long/Unicode names, punctuation and nested parentheses, quantities, and colors.

Add versioned provenance beside `tests/fixtures/objectives/`. Implement only those
observed variants. Exercise unknown/truncated/interleaved output before marking a
format supported. Native `echo` boundaries must be observed before marking automatic
requests accepted; a parser test cannot establish transport acceptance.

Later authorized native checks use **AardwolfToolboxSettingsTest disconnected** and
`tests/native_objectives.lua` after `native_foundation.lua`. Check both views at
1280×800, 1920×1080, narrow and Retina layouts; move/close/reopen external windows,
scroll long objectives, copy literal names, and verify local map lookup. Never run
synthetic fixtures in the player profile. Any later player-profile install needs
package/profile/settings/database/native-map backups first.

Official command references: [Campaigns](https://www.aardwolf.com/wiki/index.php/Help/Campaigns)
and [Global Quests](https://www.aardwolf.com/wiki/index.php/Help/Gquest).
