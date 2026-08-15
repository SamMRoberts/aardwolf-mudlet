# Aardwolf Mudlet Suite

`aardwolf-mudlet-suite.mpackage` is a deterministic all-in-one Mudlet 4.14+
installation archive. It merges the native Mudlet objects from the collection,
GMCP diagnostics, tick, console, communication, character, help, interface,
profile-data, accessibility, and map packages. It also contains the declared
map JSON resource.

Install either this suite or individual package archives in a profile, not
both. The adjacent XML is a raw object export for inspection and does not
contain resources, so it is not a functional replacement for the suite when
using the map importer.

The current suite version is 1.1.3. It includes Mudlet's required `config.lua`
Package Manager metadata and the responsive right-sidebar dashboard. If an
older `Aardwolf Mudlet Suite` entry is already installed, remove it in Mudlet's
Package Manager before installing this archive.

Regenerate the XML and `.mpackage` with:

```sh
python3 tools/build_mudlet_release.py
```

The builder first validates every component release, merges the source-derived
native exports in a fixed order, and verifies the combined object order,
resource list, archive ordering, and XML payload before publishing the suite.
