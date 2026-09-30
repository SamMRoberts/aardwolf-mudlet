# Hunt guidance

`AardwolfVibe.plugins.hunt` adds a direction cue to successful Aardwolf `hunt`
output in the main console. It recognizes the six standard directions in the
server line `You are confident that ... passed through here, heading north.`
and inserts a bold arrow banner on the next line. Manual `hunt` commands receive
the same cue even when automatic hunting is off. Other responses stay unchanged.

```text
aardwolf-vibe hunt target <mob name>
aardwolf-vibe hunt on|off|clear|status|config
aardwolf-vibe hunt
```

The target accepts the mob name or keyword passed to Aardwolf's `hunt` command.
It cannot be empty, exceed 120 bytes, or contain control characters, a
semicolon, or the profile's command separator. `on` requires a target.
Changing the target while automatic hunting is on affects the next hunt.
`off` retains the target; `clear` removes it.

`config` opens a small Geyser window docked on the right with a target field,
Save, Clear, an On/Off toggle, and Close. Turning on uses the text in the field;
Save changes the target without changing the toggle. Clear removes the target
and turns auto-hunt off. Closing and reopening the window retains the current
session state. Errors appear below the field.

Automatic hunting uses the `gmcp.room.info.num` stream separately from the
mapper. The current cached room or first valid update is a baseline. Each later
change to a valid room number sends one `hunt <target>` with local command echo
disabled. Repeated updates for the same room do not send another command. A
failed send is reported in the main console; the next move attempts another
hunt. Auto-hunt waits while a Mudlet speedwalk, a manual `run` or `runto`, or an
Aardwolf Vibe map route is in progress. It also skips the final travel room
update, including one received just after a speedwalk completion event. A
five-second quiet period follows `run`, `runto`, and Mudlet speedwalk activity;
the next ordinary room change then resumes auto-hunt. Aardwolf's GMCP running
state and the quiet period cover travel that has no reliable completion event.
Manual hunt results still receive direction cues. The feature never sends
movement commands.

Target and automatic state are in memory only and clear on disconnect, reload,
or uninstall. The room and travel handlers, output trigger, GMCP Room
subscription, and travel timers are removed when the package stops. The
direction is Aardwolf's report, not a guarantee that similarly named mobs
refer to the intended target; see
[Aardwolf's Hunt Trick help](https://aardwolf.com/wiki/index.php/Help/HuntTrick).
