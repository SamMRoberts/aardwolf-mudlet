# MUSHclient to Mudlet conversion report

## Summary

- Source: `simple_alias.xml`
- Inventoried items: 5
- converted: 3
- converted-with-review: 2

## Dispositions

| Item | Kind | Status | Targets | Reason |
| --- | --- | --- | --- | --- |
| `alias:greet_friend` | alias | converted | `src/aliases/aw_simple_alias/aliases.json`, `src/aliases/aw_simple_alias/greet_friend.lua` | The regular-expression alias maps to a Mudlet alias and namespaced Lua handler. |
| `callback:OnPluginInstall` | callback | converted-with-review | `src/scripts/aw_simple_alias/aw_simple_alias_lifecycle.lua` | Initialization maps to package lifecycle setup and needs final event selection. |
| `metadata:plugin` | metadata | converted | `package-metadata.json`, `mfile` | Plugin metadata maps to source-project metadata. |
| `notice:1` | notice | converted | `NOTICE` | The fixture attribution is preserved verbatim. |
| `script:1` | script | converted-with-review | `src/scripts/aw_simple_alias/aw_simple_alias_lifecycle.lua`, `src/aliases/aw_simple_alias/greet_friend.lua` | The Lua is split between lifecycle and alias modules for namespace safety. |

## License and attribution preservation

- `notice:1`: NOTICE
