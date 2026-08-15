# Aardwolf.db v11 export inventory

Source SHA-256: `d1dd86e532eb9903dc96fe64ae73c179e51894cd3060bccce786559c5645c4a4`

The source database was opened read-only with SQLite `query_only` enabled and validated as schema v11.

## Validated source schema

Required tables: `areas`, `bookmarks`, `environments`, `exits`, `rooms`, `storage`, `terrain`.

| Exported resource | Count |
| --- | ---: |
| Rooms | 14257 |
| Standard exits | 53662 |
| Populated areas | 21 |
| Source area records | 236 |
| Referenced terrain records | 80 |

## Source table inventory

| Table | Rows |
| --- | ---: |
| `areas` | 236 |
| `bookmarks` | 0 |
| `environments` | 112 |
| `exits` | 53662 |
| `rooms` | 14257 |
| `rooms_lookup` | 14257 |
| `rooms_lookup_content` | 14257 |
| `rooms_lookup_segdir` | 5 |
| `rooms_lookup_segments` | 289 |
| `storage` | 1 |
| `terrain` | 0 |

## Reference checks

{
  "all_exit_room_references_resolve": true,
  "all_room_area_references_resolve": true,
  "all_room_environment_references_resolve": true,
  "all_room_uids_numeric": true,
  "supported_standard_exit_directions_only": true
}

## Provisional layout

{
  "component_roots": 191,
  "cross_area_edges_retained": 1142,
  "direction_constraint_conflicts": 4665,
  "rooms_with_layout": 14257,
  "source_coordinate_collisions": 2,
  "source_coordinate_rooms": 4,
  "spiral_collision_resolutions": 1258,
  "traversed_room_assignments": 14062
}

## Omitted source tables

- `bookmarks`: empty; no map import equivalent
- `terrain`: empty; the source uses environments for populated terrain values
- `storage`: excluded from map data; contains application backup metadata
- `rooms_lookup*`: SQLite FTS implementation tables; derived from rooms
