# Hunt guidance

`AardwolfVibe.plugins.hunt` adds a direction cue to successful Aardwolf `hunt`
output in the main console. It recognizes the six standard directions in the
server line `You are confident that ... passed through here, heading north.`
and inserts a bold arrow banner on the next line. Manual `hunt` commands receive
the same cue even when automatic hunting is off. Other responses stay unchanged.

```text
aardwolf-vibe hunt target <mob name>
aardwolf-vibe hunt on|off|clear|status
aardwolf-vibe hunt
```

The target accepts the mob name or keyword passed to Aardwolf's `hunt` command.
It cannot be empty, exceed 120 bytes, or contain control characters, a
semicolon, or the profile's command separator. `on` requires a target.
Changing the target while automatic hunting is on affects the next hunt.
`off` retains the target; `clear` removes it.

Automatic hunting uses the `gmcp.room.info.num` stream separately from the
mapper. The current cached room or first valid update is a baseline. Each later
change to a valid room number sends one `hunt <target>` with local command echo
disabled. Repeated updates for the same room do not send another command. A
failed send is reported in the main console; the next move attempts another
hunt. The feature never
sends movement commands.

Target and automatic state are in memory only and clear on disconnect, reload,
or uninstall. The room event handler, output trigger, and GMCP Room subscription
are removed when the package stops. The direction is Aardwolf's report, not a
guarantee that similarly named mobs refer to the intended target; see
[Aardwolf's Hunt Trick help](https://aardwolf.com/wiki/index.php/Help/HuntTrick).
