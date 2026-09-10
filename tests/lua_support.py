"""JSON bridge shared by the Lua contract tests."""
import json


def install_json(lua):
    def plain(value):
        if hasattr(value, 'items'):
            return {key: plain(item) for key, item in value.items()}
        return value

    def table(value):
        if isinstance(value, dict):
            return lua.table_from({key: table(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([table(item) for item in value])
        return value

    lua.globals().yajl = lua.table_from({
        'to_string': lambda value: json.dumps(plain(value), allow_nan=False),
        'to_value': lambda text: table(json.loads(text)),
    })
