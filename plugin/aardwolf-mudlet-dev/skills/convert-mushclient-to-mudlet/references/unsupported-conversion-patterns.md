# Unsupported conversion patterns

Classify these patterns explicitly. A conversion may create a partial
source-controlled project and report, but it must not produce a release package
until each item is resolved.

| Pattern | Required disposition | Why |
| --- | --- | --- |
| Unknown XML element, unsupported trigger/alias attribute, or missing companion file | `manual-action-required` | Inventory it with source location; do not invent a default. |
| Lua loaded dynamically through `load`, `loadstring`, `dofile`, unknown `require`, generated code, or encrypted/encoded source | `unsupported-blocker` unless the user supplies a static, reviewable replacement | Static inspection cannot establish behavior safely. |
| DLL loading, foreign-function interfaces, registry access, COM automation, Windows messages, or executable launch | `unsupported-blocker` | These cross trust and portability boundaries; do not substitute shell access. |
| Absolute paths, traversal, symlink escape, drive-specific paths, or environment-specific user directories | `manual-action-required` | Resolve only to declared package resources or a user-approved portable location. |
| Filesystem writes, database files, sockets, HTTP clients, clipboard, or process control | `manual-action-required` | Define consent, failure handling, portability, and data ownership before implementation. |
| Raw telnet negotiation, packet mutation, compression-sensitive handling, or custom protocol framing | `unsupported-blocker` unless a documented Mudlet API proves equivalence | A wrong translation can corrupt the session. |
| Arbitrary MUSHclient plugin broadcast, plugin ID trust check, or undisclosed package dependency | `manual-action-required` | Identify an installed Mudlet provider and a namespaced contract, or remove the feature by explicit decision. |
| Miniwindow custom painting, hit testing, drag/window management, embedded browser, or platform-specific font behavior | `converted-with-review` or `manual-action-required` | It needs visual, input, accessibility, and portability acceptance. |
| Command/line/packet callback that suppresses or rewrites client data | `manual-action-required` | Preserve return and ordering semantics only with a documented equivalent. |
| Network, chat, sound, or screen-reader callbacks | `manual-action-required` | Review privacy, consent, and accessibility effects separately. |

## Release rule

`not-applicable` is valid only for a feature that was definitively absent.
`converted-with-review` requires recorded review and tests before release.
`manual-action-required` and `unsupported-blocker` prevent release validation
and package building until replaced by a resolved conversion decision. Preserve
all discovered notices and attribution in the partial project and conversion
report even when the conversion stops.
