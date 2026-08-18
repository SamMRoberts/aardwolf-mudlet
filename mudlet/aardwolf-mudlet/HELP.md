# Command Reference

```text
aard status|help
aard ui show|hide|status|theme|density|scale
aard map import|import cancel|status|palette|center|zoom
aard chat show|hide|status|clear|tab|filter|preserve|log|limit|copy|open
aard action add|edit|remove|move|list
aard inventory refresh|status
aard capture <command>|copy
aard tts on|off|say|clear|rate|voice|status
aard sound on|off|map|remove|status
aard data export|import|backup|status
```

Values containing multiple fields use `|`, for example:

```text
aard action add Heal|Skills|heal
aard chat tab add Auctions|auction,market
aard chat tab move Auctions|2
aard chat filter System|info,warfare
aard sound map tick|ticks/soft.ogg|40
```

Compatibility aliases include `groupon`, `groupoff`, `chats show`, `chats hide`, `resetaard`, `aard tick status`, and portable SAPI/TTS controls. They adapt to package-local behavior and do not restore raw telnet mutation, client-global lockout, auto-login, or unattended gameplay.

Equipment is refreshed only by explicit request. Chat capture remains in the main console by default. TTS and sounds are disabled by default; sounds require feature-detected `playSoundFile` support and files relative to the current profile's `media/` directory.
