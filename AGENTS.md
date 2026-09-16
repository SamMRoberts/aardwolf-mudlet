# AardwolfToolbox development

Target Mudlet 5.0.1 and Lua 5.1. Build with Muddler 1.1.0; tests exercise the
built `build/AardwolfToolbox.mpackage`, so rebuild before running them.

## Settings contract for future features

Every new user-configurable feature must register its settings through
`AardwolfToolbox.config.registerFeature`. Use stable feature/setting IDs and the
shared typed controls; do not add a separate settings window, preference file,
or command-only preference. Route any shortcut commands through `config.set`.
See `docs/settings-framework.md` for the complete registration contract.

Register once during initialization, before `config.activate()` where possible.
Keep apply callbacks repeatable, bounded, and free of gameplay commands. Read
preferences through `config.get`; do not mutate registry tables. Unregister or
stop feature-owned handlers, timers, and widgets during package shutdown.

Use ordered record settings for editable collections such as channels, tabs,
and rules. Preserve stable record IDs and validate references between records.
Use the shared draft/Apply/Cancel workflow, including stale-draft rejection.
Keep settings format 3 and unknown settings intact; back up original preferences
before migrations and preserve supported compatibility aliases.

## Verification and preservation

Run `python -m unittest discover -s tests -p 'check_*.py'` with the pinned Lupa
dependency after building. Add behavioral tests for preferences and lifecycle.
Use a disposable offline profile for synthetic GMCP or example-feature replay.
Never run test fixtures in a player profile. Back up native maps before map
mutations and preserve room identity, topology, coordinates, and manual edits.
Distinguish contract tests from native interaction and live server acceptance.

For runtime or package changes, `python3 tools/check.py` runs the pinned build
and package checks. Keep source, metadata, documentation, assets, and the built
package synchronized. Documentation-only instruction changes do not require a
package rebuild. Record acceptance evidence and gaps in `tests/verification.md`.

Run communications fixtures only in disconnected `AardwolfToolboxSettingsTest`;
follow the setup and restoration order in `docs/chat.md`. Stubbed tests do not
establish native regex behavior, focus, scroll preservation, sound playback, or
desktop notification delivery. After offline acceptance, an authorized player
upgrade must back up profile/package/map state, install the same tested artifact,
and verify map preservation. Observe live chat passively; do not send live test
messages without explicit authorization.

## Communications ownership and safety

Keep protocol reception and routing in `chat.lua`, normalization and rule logic
in `chat-model.lua`, and interaction controls in `chat-workspace.lua`. Reception
must continue while views are closed. Use owned `gmod` subscriptions and the
shared GMCP cache/session lifecycle; never replace another consumer's ownership
or replay stale cached chat as fresh delivery. Do not restore competing Toolbox
text captures. Starter-UI adaptations must restore borrowed functions and
consoles on teardown. See `docs/chat.md` for protocol and service contracts.

Request `gmcpchannels on` only after reception and rendering destinations are
ready. Request `gmcpchannels off` before releasing reception on disable, startup
failure, or uninstall; re-establish ownership after reconnect. Report requested
mode separately from observed delivery, without inventing acknowledgements.
Preserve default say/mobsay main-console mirroring and do not implicitly change
server channel membership, quiet mode, or color preferences.

Emit `AardwolfToolbox.chat.message` once per accepted message, preserving its
compatibility fields regardless of destination count. Identical GMCP packets
received separately remain distinct messages. Hiding is terminal and excludes
mirroring, history, unread counts, and alerts; muting suppresses alerts only.
Keep rule previews side-effect-free and native regex execution bounded; invalid
or failed rules must not interrupt reception.

Route composer sends through the chat service's validated manual-readiness and
direct-command path. Require explicit destinations, reject controls/multiline
input, and never execute aliases or incoming text. Preserve main command input
and destination drafts on failure. Do not queue retries or render optimistic
outgoing copies; use server echoes. Pause gameplay shortcuts while editing.

Keep drafts in memory and disk history opt-in. Respect character/session fences
for private data. Reuse the notification center's Chat category while keeping
chat sound/desktop policy in the communications service, with at most one alert
per incoming message. Preserve disabled-by-default sound, desktop notifications,
and message previews. Settings application must never play preview sounds.

## Shared capture and layout ownership

Incoming text consumers use `incoming.lua`; the dispatcher snapshots each line,
prioritizes ASCII frames, and gags at most once without stopping other triggers.
Use `borders.lua` for Toolbox console reservations, including bottom space shared
with Vitals. Do not use Adjustable's independent layout persistence or native
border attachment for Toolbox panes. Persist completed geometry changes with
one configuration draft/apply transaction and reject stale drafts.

## Shared appearance and dashboard

Use `AardwolfToolbox.ui.apply` before rendering labels and `ui.measure` for text
width. Reflow on `AardwolfToolbox.ui.changed`; do not shrink fonts to fit or add
isolated font preferences. The dashboard owns starter sidebar geometry while
active; do not stack independent wrappers around `BaseUI.layoutDock` or its
player/Vitals placement hooks. See `docs/ui-dashboard.md`.

Discover chat tabs dynamically from configured records; do not add fixed tab
inventories to dashboard or view management. Use record placement references
through `view-hosts.lua` while preserving existing scalar placement APIs. Floating
or docking a view must preserve its console, scrollback, and drafts; closing a
view must not stop communications reception. Preserve native selectable colored
scrollback and the reader's scroll position when messages arrive.
