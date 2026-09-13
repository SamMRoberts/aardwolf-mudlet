# Learned abilities and smart buttons (0.23.3)

Open `aardwolf-config → Action bar`, add or edit a button, and choose **Choose
learned ability**. Regular command and alias buttons remain available.

Filter by Role, Type, Spell/Skill, targeting behavior, and name or number. Select a
specific ability, or choose **Highest level of this type**. The latter requires a
role, type, and targeting behavior; it selects the highest required level you have
learned and can currently access, breaking ties by the lowest ability number.
Required level is a progression rule, not a claim about damage or effectiveness.
A single-target selection cannot turn into an area attack.

In **Highest level of this type** mode, the results are a read-only candidate
list; the preview identifies the automatic choice. Switch to **Specific ability**
to pick a fixed row. Clicking a candidate no longer changes automatic selection
to a fixed ability.

The picker shows the exact command preview. Optional target/arguments are sent as
one literal line. Buttons and shortcuts remain manual; refreshing, learning, or
editing never executes an ability. Passive abilities, forgotten abilities,
unpracticed abilities, unknown levels, and unsupported commands cannot be chosen
by automatic selection. A stale catalog does not block an otherwise eligible
saved ability for the current character. Its action button turns amber and its
tooltip explains that a refresh may select a newer ability. This applies to mouse
activation and shortcuts. The normal button color returns after synchronization;
disabled buttons retain their disabled styling. A failed refresh retains the last
committed catalog, so it may temporarily select an older learned ability.

## Dynamic command discovery

The Lua package contains no ability-name/number command list. Names, numbers,
learned status, levels, costs, targeting, and classifications come from game
responses. Supported spells use Aardwolf's generic `cast <number>` syntax.

After the normal catalog listings, collection requests `help <skill name>` for
each available, practiced, non-passive skill whose command metadata has not yet
been collected. It recognizes tagged help and the standard plain help header,
checks the help keywords against the requested skill, and reads its `Syntax:`
section. Each request ends with a unique informational `echo` marker so missing
or ambiguous help cannot be mistaken for the next response. Owned help stays
out of the help pane; ordinary player help keeps its existing behavior.

Simple command syntax with no arguments or one target/victim/opponent/character/
object/item argument is supported, including optional bracketed arguments.
Commands may differ from the displayed skill name. Multiple commands or complex
argument forms are marked unsupported, with a reason, rather than guessed.
Those skills remain searchable; regular command/alias buttons remain available.
Passive skills never gain executable buttons from help syntax.

SQLite stores the command, source help syntax, checked time, parser version, and
matching ability identity with the catalog row. Automatic refresh reuses this
metadata for unchanged skills and requests help for newly discovered skills.
**Refresh catalog** also rechecks previously saved syntax, including unsupported
results. No per-skill Lua edit is needed when the game adds an ability.

Older saved command strings remain usable while their replacement is collected,
preserving stale-catalog button behavior. The next successful refresh replaces
that legacy metadata with game-derived results. An unsupported response can
therefore make a previously assumed command unavailable; the picker explains why.
A missing completion marker, incomplete frame, or storage failure preserves the
previous complete catalog and reports a stale/error state. Refreshing only sends
informational queries, never ability executions.

## Catalog and corrections

**Ability catalog** settings control enablement and automatic refresh. **Refresh
catalog** requests information while standing, command-ready, and outside an
outstanding spellup batch. Collection pauses between requests during combat and
other non-ready states. A pager/editor interrupts collection; Toolbox never
advances it. There is no periodic catalog polling.

With automatic refresh enabled, a level change reported in either `char.status`
or `char.base` queues collection, including when the other packet still carries
the old level. Duplicate updates coalesce. Changes during collection finish the
owned response sequence before a replacement refresh; combat or other non-ready
states defer requests until ready. Class and other progression changes continue
to invalidate the catalog. Disabling automatic refresh preserves manual Refresh
and the amber stale-data warning.

The service joins `slist learned noprompt` identities with current `spells` and
`skills` listings. Aardwolf's live `slist learned` includes 1% entries and some
forgotten entries: eligibility additionally requires practice above 1% and
appearance in the ordinary current-level listing. Combat, resist, healing, stat,
passive, area, and spellup filters supply separate memberships. Damage → Fire is
separate from Protection → Fire. An ability can belong to several roles/types.

The observed spell listing reports mana cost. The skill listing and the inspected
`showskill` responses do not report skill cost, so it remains **unknown**, never
zero. Resistance listings identify protection abilities without naming their
individual resistance types; these are **Protection → unknown** until corrected.
Special damage types stay special. Nothing is inferred from an ability's name.

Use **Add local type correction** in the picker or edit **Ability catalog → Local
type corrections**. Corrections apply to one character and ability number. They
replace only that role's classifications and are visibly marked “local type.”
Multiple corrections support multiple types. They remain separate from server
facts and survive catalog refreshes. Edits use the normal Apply/Cancel and stale
draft checks.

The catalog is stored in `getMudletHomeDir()/AardwolfToolbox-abilities.sqlite3`,
separated by character. Settings use format **3**, reading formats 1 and 2 and
saving the original as `.v1.bak` or `.v2.bak` before upgrading. Older packages
cannot read format 3. Uninstall retains the database and preferences.

Refreshes commit atomically; malformed responses, timeouts, and storage errors
preserve the last disk catalog while marking it stale. Each response is limited
to 4,096 records, 1 MiB, and ten seconds. Only recognized replies to Toolbox-owned
queries are hidden. Other output remains visible. ASCII and help keep precedence,
and Game tags can still receive the tagged learned list. Spell tracking and
catalog collection share one query coordinator.

Version **0.23.2** fixes refreshes being cancelled when spell tracking sends its
own coordinated query between catalog responses. Level-up and manual refreshes
now keep their staged rows while yielding, then resume at the next request.
Uncoordinated spell/skill queries still interrupt collection to prevent mixing
responses. Version **0.23.3** replaces the former built-in skill command mappings with the
dynamic help collection described above.

Disconnect cancels requests and clears execution eligibility. Disk records remain
available for offline browsing. Static spell metadata also uses SQLite; normal
buff/utility rendering reads active-state snapshots without materializing the
complete catalog. Collection does not enable automatic spellups or change
practice/server spell-selection preferences.

## Feature API

```lua
local a = AardwolfToolbox.abilities
local heal = a.get(54) -- defensive copy, or nil
local choices = a.list({role="damage", type="bash", kind="skill", targeting="single"})
local types = a.types("protection")
local ok, message = a.refresh() -- informational, readiness gated
local state = a.status() -- fresh, busy, pending, character, count, updated, last

local command, selectedOrReason = a.resolve({
  ability_mode="highest", ability_role="damage", ability_type="bash",
  ability_kind="skill", ability_targeting="single", arguments="",
})
-- Resolving does not send. Use actionBar.activate(buttonId) for guarded manual use.
```

`get`, `list`, and `types` load rows on demand. `resolve` requires current character
identity and level, but permits eligible rows from a stale saved catalog;
`preview` can show saved data offline for editing. Profile-local
`AardwolfToolbox.abilities.updated` and `.reset` events carry no catalog payload.
Consumers fetch only what they need. Existing `spells.get()` and `spells.snapshot()`
remain available; `spells.snapshot(false)` returns active/recovery information
without loading the full static catalog.

## Protocol references

- [Skills/spells listings and filters](https://www.aardwolf.com/wiki/index.php/Help/Skills)
- [SLIST identities, targeting, and practice](https://www.aardwolf.com/wiki/index.php/Help/SLIST)
- [Damage-type listings](https://www.aardwolf.com/blog/2014/08/10/uprising-area-skills-spells/)
- [Cast syntax](https://aardwolf.com/wiki/index.php/Help/Cast)
- [Bodycheck command syntax](https://aardwolf.com/wiki/index.php/Help/Bodycheck)
- [In-game help lookup and ambiguous keywords](https://aardwolf.com/wiki/index.php/Help/Help)

Listing fixtures were captured with informational queries on September 11, 2026.

Help-parser and unfamiliar-skill tests are offline protocol fixtures. Native
help/echo delivery and player-profile execution have not been tested for 0.23.3.
After installation, run **Refresh catalog** and check its completion status and
command previews before using a button. No test casting is performed by refresh.
