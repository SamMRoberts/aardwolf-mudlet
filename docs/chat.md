# Chat and communications

Scroll the horizontal tab row with a mouse wheel or trackpad to reveal earlier
or later docked tabs. Scrolling does not switch conversations; click a tab to
select it. Small gestures accumulate, and the strip stops at either end.

An indicator shows where more tabs are available: **→** for later tabs, **←** for
earlier tabs, or **↔** for both. It disappears when all tabs fit. Scroll over the
indicator or tab row to reveal tabs; the indicator does not open a menu.
Use **Views** to reopen floating tabs.

Open **aardwolf-config → Chat and communications**. The workspace receives
Aardwolf's `comm.channel` messages and owns `gmcpchannels on` while a renderer is
available. Channel text is then delivered over GMCP only. Say and mobsay are
mirrored into the main game console by default. Disable chat to request normal
server text again. The GMCP data feature must also be enabled.

This follows the [Aardwolf GMCP guide](https://www.aardwolf.com/wiki/index.php/Clients/GMCP).
A subscription request or requested GMCP-only mode is not a server acknowledgement:
Diagnostics reports both requested mode and actual received-message counts.
The client does not change server channel membership, deaf/quiet flags or color
preferences. Choose ANSI or Raw to match the server's existing GMCP color format.

## Tabs and channel controls

| Initial tab | Channels |
| --- | --- |
| All | Every non-hidden message |
| Tells | `tell` |
| Clan | `clantalk` |
| Group | `gtell` |
| Newbie/Q&A | `newbie`, `newbietalk`, `question`, `answer` |
| Public | Channels outside those starter groups, including unknown channels |
| Trade | `auction`, `market`, `barter` |
| Local | `say`, `mobsay`, `yell` |

The internal IDs `channels`, `chat_group`, and `local_chat` correspond to Public,
Group, and Local. The dashboard's separate Group view remains unchanged.

Edit ordered **Tabs** to rename, reorder, enable, float, and filter views. Channel
lists accept comma-separated identifiers; `*` includes all, `@public` includes
channels outside the initial groups. Sender lists use exact case-insensitive
names. All remains enabled without exclusions. **Channels** controls visibility,
main-console mirroring, send verbs and alert/sound overrides. When adding a
channel, edit its Channel identifier to match the server's name. Receiving an
unknown identifier never grants permission to send an arbitrary command.

The view menu offers search and float/return. Closing a floating window hides
it while reception continues. Buffers stay attached to their original consoles
when moved. Deleting/disabling a custom tab releases its view and buffer.

Unread counts and mention badges exclude your outgoing messages. Select a tab,
or choose Latest / Mark read, to clear its count. **Unread →** opens the next
unread tab. Literal search scans up to 10,000 recent lines / 1 MiB and returns
at most 100 matches. Main-console and map layout remain dashboard-owned.

## Writing and private conversations

**Write** opens a local composer. Click its destination button to cycle through
writable channels. Aggregate tabs start without a destination; explicitly choose
one. Tells require a player name in the recipient field. Enter in that field
applies it locally; Enter in the message field or **Send** submits the message.

The initial send catalog contains say, yell, tell, gtell, clantalk, newbie,
question, answer, and gossip. Other channels start receive-only; a configured
single lowercase verb enables sending (see the [Aardwolf channel help](https://www.aardwolf.com/wiki/index.php/Help/Channels)). Informational channels should stay
receive-only. Message text is sent literally after the selected verb, without
alias expansion. Multiline/control-character input is rejected. The ordinary
manual-readiness checks block sends when disconnected, at login, in a pager or
editor, or without fresh state. Failed sends preserve the draft and are never
retried automatically. Server echoes create outgoing chat rows.

Drafts and the last 50 sent messages per destination stay in this session.
**Older sent / Newer sent** recalls messages. **People** opens the private
conversation list with unread counts; select a person to read the conversation,
then **Reply** to open a composer. Merely selecting someone never sends.

**Shift+Escape** closes an in-profile chat overlay and **Alt+J** opens the next
unread tab. External windows use mouse controls because native key-focus routing
is not inferred. Toolbox gameplay shortcuts pause while a chat overlay is open.
The main Mudlet command input is never edited by the chat workspace.

## Rules and alerts

Ordered rules match channel, sender, incoming/outgoing direction, mentions,
and literal text or regex. Empty match fields mean unrestricted. Actions are:

- Hide: terminal; exclude from views, mirrors, history and alerts.
- Route: add the selected tab without removing other destinations.
- Highlight: apply a readable message color; the last matching highlight wins.
- Mute: suppress alerts while retaining the message and unread counts.
- Alert: request a notification even outside the channel's default policy.

Mute overrides alert requests. Regex compilation is validated before Apply;
matching uses native PCRE work/recursion limits. A runtime matching failure is
reported without stopping reception. **Chat tools → Preview saved filter rules**
accepts a channel, sender and sample message and explains the result without
sending, recording, or notifying. Save a settings draft before this preview.

Incoming tells and mentions produce in-app notices by default. Desktop alerts
and sounds are off until enabled. When enabled, they default to unfocused Mudlet
only. Do not disturb and local quiet hours suppress all chat notices and sounds;
equal start/end quiet hours means the whole day. A shared cooldown (default ten
seconds) limits sound/desktop interruptions across tabs. In-app notices retain
each eligible message, subject to the notification center's own capacity.

Desktop previews are hidden by default. **Chat tools** offers explicit previews
of the original bell/chime/pop tones and the configured sound. Custom audio uses
absolute local paths; no audio is downloaded. OS notification support and audio
playback depend on the native environment; errors appear in chat status. Settings
Apply never plays a preview or sends a chat message.

## Data, migration and interfaces

Native buffers default to 10,000 lines per view (configurable 1,000–50,000).
The shared conversation store is additionally capped at 4 MiB. Neither it nor
drafts is written to disk. Optional **Local history → Record chat history**
retains its existing setting and includes accepted tells/outgoing messages.
Changing characters clears session conversation data, drafts and visible buffers.

The first upgrade copies existing shell chat settings and compatible placements
into the new registered chat settings. It saves the exact previous settings bytes
using the preference backup service before replacement and records that path in
`chatMigrationBackup` metadata. Format remains 3; unknown values survive. A backup
or write failure prevents migration. Legacy `config.get/set('shell', chatKey)`
and `config.get/set('views', oldChatID)` redirect to the new preferences.

`AardwolfToolbox.chat` exposes `status()`, `tabs()`, `channels()`, `list(peer)`,
`conversations()`, `readPeer(peer)`, `draft(key[, text])`, `recall(key, index)`,
`send(channel, recipient, text)`, `preview(raw[, settings])` and `previewSound()`.
Queries return defensive copies. `send` is an explicit user action, never a
notification callback. Retained messages have sequence ID, cache session, channel,
sender, peer, plain/colored text, direction, timestamp, mention and destinations.

`AardwolfToolbox.chat.message` fires once per accepted message after the shared
incoming dispatch boundary, retaining the historical `channel`, `text`, `peer`
and `outgoing` fields. Fanout does not duplicate history or alerts; identical
consecutive server messages remain distinct. Deferred events from an old session
or character are discarded. `chat.configured`, `chat.updated` and
`chat.characterChanged` describe preference, state and identity changes.

View placement references accept `{feature='chat', key='tabs', record=tabID}`.
The `placement` field of that record is edited through the same atomic config
transaction. Existing scalar placement references remain supported.

## Acceptance

Run the built-package suite first. In disconnected `AardwolfToolboxSettingsTest`,
run `tests/native_foundation.lua`, then `tests/native_communications.lua`. The
fixture intercepts all sends, exercises real bounded regex and injects synthetic
messages only into this disposable profile. Verify composer/drafts, conversation
reading/reply, filters, resizing, scrolling, float/return, sound previews,
desktop alerts and keyboard/input preservation. Restore `AardwolfToolboxChatQA`
before the foundation interceptors. See `tests/verification.md` for observed
results and remaining native/live gaps.
