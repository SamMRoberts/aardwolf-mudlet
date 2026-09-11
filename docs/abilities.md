# Learned abilities and smart buttons (0.17.0)

Open `aardwolf-config → Action bar`, add or edit a button, and choose **Choose
learned ability**. Regular command and alias buttons remain available.

Filter by Role, Type, Spell/Skill, targeting behavior, and name or number. Select a
specific ability, or choose **Highest level of this type**. The latter requires a
role, type, and targeting behavior; it selects the highest required level you have
learned and can currently access, breaking ties by the lowest ability number.
Required level is a progression rule, not a claim about damage or effectiveness.
A single-target selection cannot turn into an area attack.

The picker shows the exact command preview. Optional target/arguments are sent as
one literal line. Buttons and shortcuts remain manual; refreshing, learning, or
editing never executes an ability. Passive abilities, forgotten abilities,
unpracticed abilities, unknown levels, and unsupported commands cannot be chosen
by automatic selection. Stale data blocks activation until refreshed.

Spells with supported targeting use `cast <number> [arguments]`. Verified skill
commands currently cover Bash, Kick, Trip, Stun, Sap, Scalp, Assault, Uppercut,
Headbutt, Gouge, and Hammerswing. Hammerswing remains an area action. Other skills
and spells with special/extended syntax remain searchable; use a regular command
or alias button for their commands. No spell commands are inferred from skill
names.

## Catalog and corrections

**Ability catalog** settings control enablement and automatic refresh. **Refresh
catalog** requests information while standing, command-ready, and outside an
outstanding spellup batch. Collection pauses between requests during combat and
other non-ready states. A pager/editor interrupts collection; Toolbox never
advances it. There is no periodic catalog polling.

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

`get`, `list`, and `types` load rows on demand. `resolve` requires fresh eligibility;
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
- Verified skill syntax: official help pages for
  [Bash](https://www.aardwolf.com/wiki/index.php/Help/Bash),
  [Kick](https://www.aardwolf.com/wiki/index.php/Help/Kick),
  [Trip](https://www.aardwolf.com/wiki/index.php/Help/Trip),
  [Stun](https://www.aardwolf.com/wiki/index.php/Help/Stun),
  [Sap](https://www.aardwolf.com/wiki/index.php/Help/Sap),
  [Scalp](https://www.aardwolf.com/wiki/index.php/Help/Scalp),
  [Assault](https://www.aardwolf.com/wiki/index.php/Help/Assault),
  [Uppercut](https://aardwolf.com/wiki/index.php/Help/Uppercut),
  [Headbutt](https://aardwolf.com/wiki/index.php/Help/Headbutt),
  [Gouge](https://www.aardwolf.com/wiki/index.php/Help/Gouge), and
  [Hammerswing](https://www.aardwolf.com/wiki/index.php/Help/Hammerswing).

Listing fixtures were captured with informational queries on September 11, 2026.
