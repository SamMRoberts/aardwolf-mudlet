# Aardwolf.db v11 conversion contract

The converter supports one observed SQLite database contract only: `PRAGMA user_version = 11`. It opens a regular, non-symlink database read-only with SQLite immutable/query-only settings, then requires these tables and columns.

| Table | Required columns |
| --- | --- |
| `areas` | `uid`, `name`, `texture`, `color`, `flags` |
| `bookmarks` | `uid`, `notes` |
| `environments` | `uid`, `name`, `color` |
| `exits` | `dir`, `fromuid`, `touid`, `level` |
| `rooms` | `uid`, `name`, `area`, `building`, `terrain`, `info`, `notes`, `x`, `y`, `z`, `norecall`, `noportal`, `ignore_exits_mismatch` |
| `storage` | `name`, `data` |
| `terrain` | no required columns |

Room and exit IDs must be canonical base-10 integers. Every room area must resolve to `areas.uid`; every room terrain must resolve to an environment name; every exit source and destination must resolve to an imported room. Supported exit directions are `n`, `e`, `s`, `w`, `u`, and `d`. Invalid data is an error, never an opportunity to guess.

The canonical JSON resource is schema version 1. It has top-level `source`, `areas`, `environments`, `rooms`, `exits`, `layout`, and `counts`, in deterministic ordering. `source.sha256` is computed from the source bytes. JSON and Markdown inventories record table counts, reference checks, provisional layout details, and intentionally omitted source tables.

When all three source coordinates are valid integers, retain them area-locally where possible. Resolve collisions deterministically. Rooms lacking complete coordinates and disconnected components get deterministic collision-free positions; cross-area exits are retained in the resource but do not force a shared area layout.

Output paths must be distinct, must not overwrite the database, and must not traverse caller-controlled symlinks. Write each output atomically. The converter does not execute database content and does not modify the input.
