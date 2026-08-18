#!/usr/bin/env python3
"""Compatibility entry point for the plugin-owned Aardwolf map converter."""

from __future__ import annotations

import sys
from pathlib import Path


PLUGIN_SCRIPTS = Path(__file__).resolve().parents[1] / "plugin" / "aardwolf-mudlet-dev" / "scripts"
if str(PLUGIN_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(PLUGIN_SCRIPTS))

from convert_aardwolf_map_database import (  # noqa: E402
    DATABASE_USER_VERSION,
    DIRECTION_INDEX,
    ExportError,
    build_export,
    main,
)


if __name__ == "__main__":
    raise SystemExit(main())
