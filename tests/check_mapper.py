"""Exercise mapping behavior from the packaged Lua resource under Lua 5.1."""
from pathlib import Path
import unittest
import zipfile

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


class MapperTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute((ROOT / "tests/mapper_api.lua").read_text())
        with zipfile.ZipFile(ROOT / "build/AardwolfToolbox.mpackage") as archive:
            self.source = archive.read("automapper.lua").decode()
        self.lua.globals().factory = self.lua.execute(self.source)
        self.lua.execute('mapper = factory.new(_G); mapper.start()')

    def check(self, code):
        self.lua.execute(code)

    def test_exploration_links_reported_directions_only(self):
        self.check('''
          packet(101, {n = 102}); assert(count(rooms) == 1)
          assert(rooms[localID(101)].exits.north == nil)
          packet(102, {}); assert(count(rooms) == 2)
          assert(rooms[localID(101)].exits.north == localID(102))
          assert(rooms[localID(102)].exits.south == nil)
          assert(rooms[localID(102)].y == 2 and centered == localID(102))
          assert(backupCount == 1 and backupWrites == 0)
          packet(101, {n = 102}); assert(count(rooms) == 2)
          assert(mapper.added == 2 and mapper.reused == 1)
        ''')

    def test_generic_mapper_blocks_start_without_map_mutation(self):
        self.check('''
          mapper.stop(); packages = {"generic_mapper", "AardwolfToolbox"}
          mapper.start()
          assert(not mapper.enabled and count(handlers) == 0 and count(modules) == 0)
          packet(101, {s = 102})
          assert(writes == 0 and centered == nil and mapper.conflicts == 1)
          assert(string.find(mapper.last, "generic_mapper", 1, true))
          packages = {"AardwolfToolbox"}; mapper.start()
          fire("gmcp.room.info"); assert(writes == 0)
          packet(101, {s = 102}); packet(102)
          assert(rooms[localID(102)].x == 0 and rooms[localID(102)].y == -2)
        ''')

    def test_generic_mapper_installed_later_stops_before_moving_marker(self):
        self.check('''
          packet(101, {s = 102})
          local before, marker = writes, centered
          packages = {"generic_mapper"}
          packet(102)
          assert(writes == before and centered == marker and not mapper.enabled)
          assert(count(handlers) == 0 and count(modules) == 0)
        ''')

    def test_standard_directions_are_not_transposed(self):
        self.check('''
          packet(101, {n = 102, e = 103, s = 104, w = 105})
          for _, direction in ipairs({{"n",102,0,2}, {"e",103,2,0},
              {"s",104,0,-2}, {"w",105,-2,0}}) do
            packet(101, {n = 102, e = 103, s = 104, w = 105})
            packet(direction[2])
            local room = rooms[localID(direction[2])]
            assert(room.x == direction[3] and room.y == direction[4] and room.z == 0)
          end
          assert(rooms[localID(101)].exits.south == localID(104))
          assert(rooms[localID(101)].exits.east == localID(103))
        ''')

    def test_area_names_are_server_zone_only(self):
        self.check(''' 
          packet(101, {}, "academy"); packet(102, {}, "boot")
          packet(103, {}, "mesolar", {cont = 1, id = 0, x = 3, y = 4})
          assert(areas.academy and areas.boot and areas.mesolar and count(areas) == 3)
          assert(rooms[localID(101)].area == areas.academy)
        ''')

    def test_legacy_area_renamed_on_revisit_without_changing_rooms(self):
        self.check('''
          packet(101, {s = 102}, "academy"); packet(102, {}, "academy")
          local area, room = areas.academy, rooms[localID(101)]
          setAreaName(area, "Aardwolf Toolbox / zone:academy")
          room.x, room.name = 77, "My room"
          mapper.stop(); mapper = factory.new(_G); mapper.start()
          local before = writes
          packet(101, {s = 102}, "academy")
          assert(areas.academy == area and count(areas) == 1)
          assert(not areas["Aardwolf Toolbox / zone:academy"])
          assert(room.area == area and room.x == 77 and room.name == "My room")
          assert(room.exits.south == localID(102) and count(rooms) == 2)
          assert(backupCount == 2 and backupWrites == before)
          packet(103, {}, "academy"); assert(rooms[localID(103)].area == area)
        ''')

    def test_legacy_area_reused_for_new_room_and_continent(self):
        self.check('''
          local area = addAreaName("Aardwolf Toolbox / continent:0")
          setAreaUserData(area, "AardwolfToolbox:owner", "AardwolfToolbox.mapper")
          packet(101, {}, "mesolar", {cont = 1, id = 0, x = 3, y = 4})
          assert(areas.mesolar == area and count(areas) == 1)
        ''')

    def test_area_rename_preserves_manual_names_and_stops_on_collision(self):
        self.check('''
          packet(101, {}, "academy")
          local area = areas.academy
          setAreaName(area, "My academy"); packet(101, {}, "academy")
          assert(areas["My academy"] == area and not areas.academy)
          setAreaName(area, "Aardwolf Toolbox / zone:academy")
          local foreign = addAreaName("academy")
          packet(101, {}, "academy")
          assert(not mapper.enabled and areas.academy == foreign)
          assert(areas["Aardwolf Toolbox / zone:academy"] == area)
          assert(rooms[localID(101)].area == area)
        ''')

    def test_foreign_numeric_room_is_untouched(self):
        self.check('''
          addRoom(101); rooms[101].name = "Existing"; rooms[101].x = 77
          local before = writes
          packet(101, {n = 102})
          assert(writes == before and count(rooms) == 1)
          assert(not mapper.enabled and rooms[101].x == 77)
          assert(rooms[101].hash == nil)
        ''')

    def test_hash_and_area_collisions_do_not_get_adopted(self):
        self.check('''
          addRoom(90); setRoomIDbyHash(90, "AardwolfToolbox:aardwolf:vnum:101")
          local before = writes
          packet(101); assert(writes == before and not mapper.enabled)
          assert(rooms[90].data["AardwolfToolbox:owner"] == nil)
          mapper.start()
          addAreaName("foreign")
          before = writes
          packet(102, {}, "foreign"); assert(writes == before and not mapper.enabled)
        ''')

    def test_private_partial_and_invalid_records_do_not_write(self):
        self.check('''
          packet(-1); packet(0); packet(1.5); packet(true); packet(0/0)
          gmcp = {room = {info = {num = 101}}}; fire("gmcp.room.info")
          gmcp = nil; fire("gmcp.room.info")
          packet(101, {}, "test", {cont = 1, id = -1, x = 1, y = 2})
          assert(writes == 0 and backupCount == 0 and mapper.skipped == 8)
          assert(mapper.enabled)
        ''')

    def test_reconnect_and_reenable_ignore_stale_data(self):
        self.check('''
          packet(101, {n = 102}); local before = writes
          fire("gmcp.room.info"); assert(writes == before)
          fire("sysDisconnectionEvent"); fire("sysConnectionEvent")
          fire("gmcp.room.info"); assert(writes == before)
          mapper.stop(); packet(102); assert(writes == before)
          mapper.start(); fire("gmcp.room.info"); assert(writes == before)
          packet(102); assert(count(rooms) == 2)
          local room=rooms[localID(102)]
          assert(room.z==0 and not (room.x==0 and room.y==2))
        ''')

    def test_continent_coordinates_and_manual_layout_preserved(self):
        self.check('''
          packet(101, {}, "a", {cont = 1, id = 0, x = 37, y = 19})
          local id = localID(101)
          assert(rooms[id].x == 37 and rooms[id].y == -19)
          rooms[id].x, rooms[id].name = 99, "My note"
          packet(101, {}, "a", {cont = 1, id = 0, x = 38, y = 20})
          assert(rooms[id].x == 99 and rooms[id].name == "My note")
          packet(102, {}, "inside", {cont = 0, id = 0, x = 37, y = 19})
          assert(rooms[localID(102)].x == 0)
          assert(rooms[localID(102)].area ~= rooms[id].area)
        ''')

    def test_duplicate_positions_stay_on_same_level(self):
        self.check('''
          packet(101); packet(102)
          local a,b = rooms[localID(101)],rooms[localID(102)]
          assert(a.z == 0 and b.z == 0)
          assert(a.x ~= b.x or a.y ~= b.y)
        ''')

    def test_collision_after_horizontal_movement_does_not_create_floor(self):
        self.check('''
          packet(101, {e=102}); packet(102, {n=103}); packet(103, {w=104})
          packet(104, {s=105}); packet(105, {e=106}); packet(106)
          for num=101,106 do assert(rooms[localID(num)].z==0) end
          local a,b=rooms[localID(101)],rooms[localID(105)]
          assert(a.x==0 and a.y==0 and (a.x~=b.x or a.y~=b.y))
          assert(rooms[localID(104)].exits.south==localID(105))
        ''')

    def test_vertical_collision_keeps_intended_up_and_down_levels(self):
        self.check('''
          packet(101, {u=102,d=103}); packet(102)
          packet(101, {u=104,d=103}); packet(104)
          assert(rooms[localID(102)].z==1 and rooms[localID(104)].z==1)
          packet(101, {u=104,d=103}); packet(103)
          packet(101, {d=105}); packet(105)
          assert(rooms[localID(103)].z==-1 and rooms[localID(105)].z==-1)
          local id=localID(104); rooms[id].z=17
          packet(104); assert(rooms[id].z==17)
        ''')

    def test_continent_collision_and_reconnect_do_not_invent_levels(self):
        self.check('''
          packet(101, {}, "world", {cont=1,id=0,x=3,y=4})
          packet(102, {}, "world", {cont=1,id=0,x=3,y=4})
          assert(rooms[localID(101)].z==0 and rooms[localID(102)].z==0)
          mapper.reset(); packet(103, {}, "world")
          mapper.reset(); packet(104, {}, "world")
          assert(rooms[localID(103)].z==0 and rooms[localID(104)].z==0)
        ''')

    def test_full_floor_stops_without_using_another_level(self):
        self.check('''
          packet(101)
          local countBefore=count(rooms)
          local checks=0
          getRoomsByPosition=function(area,x,y,z)
            assert(z==0); checks=checks+1; return {localID(101)}
          end
          packet(102)
          assert(not mapper.enabled and count(rooms)==countBefore)
          assert(checks<=1100 and mapper.last:find("same level",1,true))
        ''')

    def test_manual_exits_preserved_and_unknown_maze_exits_ignored(self):
        self.check('''
          packet(101, {n = 102, e = -1, u = "?", w = true})
          packet(103); rooms[localID(101)].exits.north = localID(103)
          packet(102)
          assert(count(rooms) == 3 and mapper.conflicts == 1)
          assert(rooms[localID(101)].exits.north == localID(103))
        ''')

    def test_owned_exit_changes_and_removals_follow_fresh_snapshots(self):
        self.check('''
          packet(101, {n = 102}); packet(102); packet(103)
          packet(101, {n = 103})
          assert(rooms[localID(101)].exits.north == localID(103))
          packet(101, {n = -1})
          assert(rooms[localID(101)].exits.north == localID(103))
          packet(101, {})
          assert(rooms[localID(101)].exits.north == nil)
        ''')

    def test_manual_deletion_is_not_recreated(self):
        self.check('''
          packet(101, {n = 102}); packet(102)
          rooms[localID(101)].exits.north = nil
          packet(101, {n = 102})
          assert(rooms[localID(101)].exits.north == nil and mapper.conflicts == 1)
        ''')

    def test_pending_exits_survive_instance_restart(self):
        self.check('''
          packet(101, {e = 102}); mapper.stop()
          mapper = factory.new(_G); mapper.start(); packet(102)
          assert(rooms[localID(101)].exits.east == localID(102))
        ''')

    def test_backup_failure_stops_before_mutation(self):
        self.check('''
          failNext("saveMap"); packet(101)
          assert(writes == 0 and not mapper.enabled and mapper.failed == 1)
          assert(count(handlers) == 0 and count(modules) == 0)
          mapper.start(); packet(101); assert(count(rooms) == 1)
        ''')

    def test_partial_mutation_is_visible_and_not_duplicated(self):
        self.check('''
          failNext("setRoomArea"); packet(101)
          assert(count(rooms) == 1 and not mapper.enabled)
          assert(rooms[localID(101)].data["AardwolfToolbox:ready"] == nil)
          mapper.start(); packet(101)
          assert(count(rooms) == 1 and mapper.failed == 2)
        ''')

    def test_start_stop_and_coexistence(self):
        self.check('''
          registerNamedEventHandler("other", "room", "gmcp.room.info", function() end)
          gmod.enableModule("other", "Room")
          mapper.start(); mapper.start(); assert(count(handlers) == 5)
          mapper.stop(); mapper.stop()
          assert(count(handlers) == 1 and modules["other:Room"])
          assert(count(modules) == 1)
          local before = writes; packet(101); assert(writes == before)
          mapper.start(); assert(count(handlers) == 5)
        ''')

    def test_registration_failure_cleans_owned_resources(self):
        self.check('''
          mapper.stop(); failNext("enableModule"); mapper.start()
          assert(not mapper.enabled and count(handlers) == 0 and count(modules) == 0)
          failNext("registerNamedEventHandler"); mapper.start()
          assert(not mapper.enabled and count(handlers) == 0)
        ''')

    def test_terrain_capture_colors_and_changes(self):
        self.check('''
          terrainPacket(101, " Forest ")
          local id = localID(101)
          local forest = getRoomEnv(id)
          assert(getRoomUserData(id, "AardwolfToolbox:terrain") == "forest")
          assert(environmentColors[forest][2] == 139)
          terrainPacket(102, "forest")
          assert(getRoomEnv(localID(102)) == forest)
          terrainPacket(101, "water")
          local water = getRoomEnv(id)
          assert(water ~= forest and environmentColors[water][3] == 220)
          assert(mapper.enabled and backupWrites == 0)
        ''')

    def test_missing_invalid_and_unknown_terrain(self):
        self.check('''
          terrainPacket(101, "forest"); local env = getRoomEnv(localID(101))
          terrainPacket(101, nil); terrainPacket(101, {}); terrainPacket(101, "")
          terrainPacket(101, string.char(27) .. "forest")
          terrainPacket(101, string.rep("x", 129))
          assert(getRoomEnv(localID(101)) == env)
          assert(getRoomUserData(localID(101), "AardwolfToolbox:terrain") == "forest")
          terrainPacket(102, "crystal palace")
          assert(environmentColors[getRoomEnv(localID(102))][1] == 145)
          assert(getRoomUserData(localID(102), "AardwolfToolbox:terrain") == "crystal palace")
          terrainPacket(103, nil, "desert")
          assert(environmentColors[getRoomEnv(localID(103))][1] == 225)
        ''')

    def test_terrain_preserves_manual_overrides_and_upgrades_old_rooms(self):
        self.check('''
          packet(101); terrainPacket(101, "forest")
          assert(getRoomEnv(localID(101)) >= 1000)
          setRoomEnv(localID(101), 77); terrainPacket(101, "water")
          assert(getRoomEnv(localID(101)) == 77)
          assert(getRoomUserData(localID(101), "AardwolfToolbox:terrain") == "water")
          packet(102); setRoomEnv(localID(102), 78); terrainPacket(102, "forest")
          assert(getRoomEnv(localID(102)) == 78)
        ''')

    def test_terrain_palette_survives_restart_and_preserves_shared_colors(self):
        self.check('''
          setCustomEnvColor(1000, 1, 2, 3, 255)
          addRoom(90); setRoomEnv(90, 1001)
          terrainPacket(101, "forest"); local env = getRoomEnv(localID(101))
          assert(env == 1002 and environmentColors[1000][1] == 1)
          setCustomEnvColor(env, 10, 20, 30, 255)
          mapper.stop(); mapper = factory.new(_G); mapper.start()
          terrainPacket(102, "forest")
          assert(getRoomEnv(localID(102)) == env and environmentColors[env][1] == 10)
          assert(count(environmentColors) == 2)
        ''')

    def test_terrain_color_failure_does_not_claim_success(self):
        self.check('''
          failNext("setCustomEnvColor"); terrainPacket(101, "forest")
          assert(not mapper.enabled and mapper.failed == 1)
          assert(getRoomEnv(localID(101)) == -1)
          mapper.start(); terrainPacket(101, "forest")
          assert(mapper.enabled and getRoomEnv(localID(101)) >= 1000)
        ''')

    def test_closed_mapper_does_not_lose_recorded_room(self):
        self.check('''
          failNext("centerview"); packet(101)
          assert(mapper.enabled and count(rooms) == 1 and centerCount == 0)
          assert(string.find(mapper.last, "open the Mudlet mapper", 1, true))
        ''')


if __name__ == "__main__":
    unittest.main()
