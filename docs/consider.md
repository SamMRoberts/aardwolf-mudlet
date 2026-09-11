# Consider ratings

AardwolfToolbox 0.8.2 replaces Aardwolf's 13 consider messages with a compact line:

`(Hidden) (Golden Aura) | Some singing mice | Hard | +5–9 lvls`

Fields are tags, mob name, danger, and relative level range. Leading parenthesized
tags are grouped separately; mobs without tags begin directly with their name.

These are relative level ranges, not actual mob levels. The formatter uses the
server's consider sentence and does not require character-level or GMCP data.

| Relative level | Difficulty | Foreground |
| --- | --- | --- |
| −20 and below | Trivial | Gray `#B0B0B0` |
| −19 to −10 | Very easy | Green `#66DD88` |
| −9 to −5 | Easy | Green `#99DD66` |
| −4 to −2 | Favorable | Teal `#66DDCC` |
| −1 to +1 | Fair fight | White `#EEEEEE` |
| +2 to +4 | Tough | Yellow `#FFDD66` |
| +5 to +9 | Hard | Amber `#FFBB55` |
| +10 to +15 | Dangerous | Orange `#FF9955` |
| +16 to +20 | Very dangerous | Orange-red `#FF7755` |
| +21 to +30 | Crushing | Red `#FF6666` |
| +31 to +40 | Deadly | Pink-red `#FF6688` |
| +41 to +50 | Overwhelming | Magenta `#EE77DD` |
| +51 and above | Annihilating | Purple `#CC99FF` |

Negative ranges indicate levels below you (`−9…−5 lvls`); positive ranges indicate
levels above you (`+5–9 lvls`). A fair fight reads `±1 lvl`. Open ends read
`≤−20 lvls` and `≥+51 lvls`. Difficulty is always written out as well as colored.

Open **aardwolf-config → Consider**:

- **Enable consider formatting** starts enabled. Disable it to retain subsequent
  original messages.
- **Use difficulty colors** starts enabled. Disable it to keep the rewritten
  rating in the original sentence's starting foreground/background colors.

Both preferences use the existing profile-local settings file and survive package
replacement. The feature has no separate alias, history, or data file.

## Behavior and lifecycle

Only complete lines matching the fixed Aardwolf sentences are formatted, allowing
surrounding whitespace. Help-table rows with a trailing range and other unmatched
lines remain unchanged. Mob names are literal text, including punctuation and
Unicode; they are never interpreted as HTML, color markup, links, or Lua.
Mob placeholders use wildcard captures, not the literal word `MOB`. The Hard
rating accepts the live pronouns `him`, `her`, `it`, and `them`; status prefixes
such as `(Hidden) (Golden Aura)` are retained in the separate tags field.

The line is replaced in place without adding or deleting newlines. Normal console
wrapping still applies to long names. Difficulty colors preserve the sentence's
starting background. Subsequent server text retains its server colors.

`AardwolfToolbox.consider` provides repeatable `start`, `configure`, `stop`, and
`destroy` operations. It consumes the existing shared input dispatcher after
ASCII maps and game tags. Lines claimed by those features are not rewritten,
even when tag suppression is disabled. The formatter works independently when
those features are disabled. Other packages' triggers are not stopped; later
triggers may observe the rewritten display text.

Stopping or uninstalling removes its subscription. No new trigger, timer, GMCP
subscription, or gameplay command is created. Activation failures appear in
settings status and leave original consider output visible. Selection/replacement
failures stop formatting, release selection/formatting state, and report a
local diagnostic.

## Verification

`tests/check_consider.py` checks the packaged Lua 5.1 implementation through the
shared dispatcher. `tests/native_consider.lua` requires the disconnected
`AardwolfToolboxSettingsTest` profile and verifies native input, replacement,
foreground/background colors, surrounding output, literal names, and capture
priority. Never replay fixtures in a player profile. Live acceptance uses naturally
arriving consider messages only.
