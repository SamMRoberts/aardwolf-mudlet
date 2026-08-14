# Aardwolf MUSHclient Collection

This is a source-controlled Mudlet 4.14+ migration project for the MUSHclient
plugins in `.resources/worlds/plugins`. It intentionally enables only two
reviewable behaviors:

- The `Time` plugin's one-second local-clock display, rendered as a named
  Geyser label at the upper-left of the main window.
- `Omit_Blank_Lines`' exact blank-line trigger, implemented with `deleteLine()`.

All other discovered behavior is traceable in `reports/conversion-report.md`.
Items marked `manual-action-required` or `unsupported-blocker` are not present
in the running package and prevent release packaging.

## Preview import artifacts

The generated [XML export](dist/aardwolf-mushclient-collection.xml) and [Mudlet package](dist/aardwolf-mushclient-collection.mpackage) contain only the two safe behaviors listed above. They are importable preview artifacts, not a complete conversion or a release; the conversion report remains the authority for unresolved behavior.

## Install and lifecycle

For a complete release, import this project's generated package only after the
conversion report has no release blockers. The preview artifacts above may be
imported to exercise only the two listed safe behaviors. On script load, the
clock starts through a named Mudlet timer.
Before disabling or reloading the package, run
`aardwolf_mushclient_collection.lifecycle.shutdown()` to remove that timer and
the label. Re-run `aardwolf_mushclient_collection.lifecycle.start()` to restore
them.

The package uses no GMCP module and sends no game commands. It keeps no
persistent settings or copied source assets.

## Provenance and limits

Source metadata is recorded in `reports/source-manifest.md`. No license or
copyright notice was discovered by the static inspection, so this project does
not assert redistribution rights for the original MUSHclient sources.
