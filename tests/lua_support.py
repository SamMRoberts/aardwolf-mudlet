"""JSON bridge shared by the Lua contract tests."""
import json


def install_json(lua):
    def plain(value):
        if hasattr(value, 'items'):
            items = dict(value.items())
            if items and set(items) == set(range(1, len(items) + 1)):
                return [plain(items[i]) for i in range(1, len(items) + 1)]
            return {key: plain(item) for key, item in items.items()}
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


def install_sqlite(lua):
    """LuaSQL-shaped bridge over real SQLite, isolated to this Lua runtime."""
    import sqlite3

    connections = {}

    def environment():
        def connect(_env, path):
            # Keep the in-memory database across API close/reopen cycles.
            if path not in connections:
                connections[path] = sqlite3.connect(":memory:", isolation_level=None)
            connection = connections[path]

            def execute(_connection, sql):
                try:
                    cursor = connection.execute(sql)
                    if cursor.description is None:
                        return cursor.rowcount
                    names = [column[0] for column in cursor.description]

                    def fetch(_cursor, table, _mode):
                        row = cursor.fetchone()
                        if row is None:
                            return None
                        for name, value in zip(names, row):
                            table[name] = value
                        return table

                    return lua.table_from({"fetch": fetch, "close": lambda _cursor: cursor.close() or True})
                except sqlite3.Error as error:
                    return None, str(error)

            return lua.table_from({"execute": execute, "close": lambda _connection: True})

        return lua.table_from({"connect": connect, "close": lambda _env: True})

    lua.globals().luasql = lua.table_from({"sqlite3": environment})

    def cleanup():
        for connection in connections.values():
            connection.close()
        connections.clear()

    return cleanup
