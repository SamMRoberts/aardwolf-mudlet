# Console cleanup — 0.18.2

`aardwolf-config → Console cleanup` provides three enabled-by-default switches:
Enable console cleanup, Hide blank and whitespace-only lines, and Hide repeated
identical standard prompts. Preferences use the shared configuration service.

Blank means empty or entirely whitespace in Mudlet's plain-text incoming line.
ANSI colors do not prevent matching. The repeated-prompt filter recognizes the
standard `[current/maxhp current/maxmn current/maxmv Nqt Ntnl] >` format shown in
the reported flood. It keeps the first prompt, then hides identical prompts until
another visible nonblank incoming line or a changed prompt arrives. Surrounding
whitespace is ignored. Custom prompts and messages containing prompt-like text
remain visible. It does not suppress every prompt or change server settings.

The shared incoming dispatcher gives ASCII, help, and tag consumers first access.
Their content and spacing are preserved, including blank map rows. Hidden records
do not break a prompt run; visible records and formatted consider output do.
Gagging occurs once through the existing trigger without stopping other packages'
triggers. The filter affects new incoming output, not old scrollback or locally
printed text. Output changes made by unrelated packages are not tracked.

`AardwolfToolbox.consoleCleanup` owns its subscription and connection handlers.
Startup, reconnect, configuration changes, and teardown clear remembered prompt
state. Disable/uninstall restores subsequent original output. No timers, commands,
GMCP subscriptions, widgets, or additional preference files are introduced.

The dispatcher's optional fifth `add` argument is a processed-line callback:
`processed(text, hidden, claimingOwner)`. It receives the original snapshot after
the claiming consumer and gag decision, before any archive forwarding. It can
observe earlier visible claims without competing for ownership. It must not gag
or rewrite the line. Callback failures remove that consumer and invoke its failure
handler.

## Verification

The complete 199-test package suite and archive inspection passed. Native offline
ANSI replay removed 16 blank lines and seven repeated prompts in the reported
sequence, preserved distinct output and map-frame spacing, and confirmed another
trigger still received every line. Version 0.18.2 was installed in Aardwolf after
a full profile/package/settings/map backup; all 1,034 native rooms, prior feature
preferences, map/chat widgets, and border reservations were preserved. The final
passive live-observation window was interrupted by macOS locking, so live prompt
suppression remains unobserved rather than being claimed from offline tests.
