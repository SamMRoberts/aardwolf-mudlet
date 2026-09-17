from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime

from lua_support import install_json


ROOT = Path(__file__).resolve().parents[1]
API = (ROOT / "tests/mapper_api.lua").read_text()
SOURCE = (ROOT / "src/resources/mapper.lua").read_text()


class MapperTests(unittest.TestCase):
    def check(self, snippet):
        lua = LuaRuntime(unpack_returned_tuples=True)
        install_json(lua)
        lua.execute(API)
        factory = lua.execute(SOURCE)
        lua.globals().factory = factory
        lua.execute('settings={backupDir="/profile/aardwolf-vibe-data/backups",ensureDirectory=function() return true end}')
        lua.execute("mapper=factory.new(_G,settings);assert(mapper:start())")
        lua.execute(snippet)

    def test_room_ids_areas_hashes_and_placeholders_use_gmcp_ids(self):
        self.check('''
          assert(mapper:receive(packet("101",{e="102"},"academy","city")))
          assert(rooms[101] and rooms[102] and not rooms[1])
          assert(areas.academy and areaData[areas.academy].name=="academy")
          assert(areaData[areas.academy].data["aardwolf-vibe:owner"]=="aardwolf-vibe.mapper")
          assert(rooms[101].hash=="aardwolf-vibe:aardwolf:room:101")
          assert(rooms[102].data["aardwolf-vibe:placeholder"]=="1" and rooms[102].char=="?")
          assert(rooms[102].data["aardwolf-vibe:ready"]=="1")
          assert(rooms[102].data["aardwolf-vibe:zone"]=="academy")
          assert(rooms[102].data["aardwolf-vibe:terrain-key"]=="unknown")
          assert(rooms[102].data["aardwolf-vibe:exit-metadata-version"]=="placeholder")
          assert(rooms[101].data["aardwolf-vibe:exit-metadata-version"]=="1")
          assert(rooms[101].exits.east==102 and next(backups)~=nil)
        ''')

    def test_private_partial_and_nonintegral_packets_do_not_write(self):
        self.check('''
          local before=writes
          assert(not mapper:receive(packet(-1)))
          assert(not mapper:receive(packet(1.5)))
          assert(not mapper:receive({num=3,name="Bad",zone="test"}))
          assert(writes==before and next(backups)==nil and mapper.skipped==3 and mapper.enabled)
        ''')

    def test_foreign_room_and_area_collisions_stop_without_adoption(self):
        self.check('''
          addRoom(101);rooms[101].name="Foreign";local before=writes
          assert(not mapper:receive(packet(101)))
          assert(rooms[101].name=="Foreign" and rooms[101].hash==nil and not mapper.enabled)
        ''')
        self.check('''
          local id=addAreaName("academy");local before=writes
          assert(not mapper:receive(packet(101,{},"academy")))
          assert(areas.academy==id and areaData[id].data["aardwolf-vibe:owner"]==nil)
          assert(not rooms[101] and not mapper.enabled)
        ''')

    def test_horizontal_collision_stays_on_directional_axis(self):
        self.check('''
          assert(mapper:receive(packet(101,{},"test")))
          addRoom(999);setRoomArea(999,areas.test);setRoomCoordinates(999,2,0,0)
          assert(mapper:receive(packet(101,{e=102},"test")))
          assert(rooms[102].x==4 and rooms[102].y==0 and rooms[102].z==0)
          assert(rooms[101].exits.east==102)
        ''')

    def test_up_and_down_change_only_required_floor(self):
        self.check('''
          assert(mapper:receive(packet(101,{u=102,d=103})))
          assert(rooms[102].z==1 and rooms[103].z==-1)
          assert(rooms[102].x==rooms[101].x and rooms[102].y==rooms[101].y)
          assert(rooms[103].x==rooms[101].x and rooms[103].y==rooms[101].y)
        ''')

    def test_continent_coordinates_are_authoritative_and_y_is_inverted(self):
        self.check('''
          assert(mapper:receive(packet(5922,{},"zoo","city",{cont=1,id=0,x=37,y=19})))
          assert(rooms[5922].x==37 and rooms[5922].y==-19 and rooms[5922].z==0)
          assert(mapper:receive(packet(5922,{},"zoo","city",{cont=1,id=0,x=40,y=22,z=3})))
          assert(rooms[5922].x==40 and rooms[5922].y==-22 and rooms[5922].z==3)
        ''')

    def test_placeholder_moves_to_exact_destination_zone_on_promotion(self):
        self.check('''
          assert(mapper:receive(packet(101,{e=102},"first")))
          assert(rooms[102].area==areas.first)
          assert(mapper:receive(packet(102,{},"second","forest")))
          assert(rooms[102].area==areas.second and areaData[areas.second].name=="second")
          assert(rooms[102].data["aardwolf-vibe:placeholder"]=="0" and rooms[102].char=="")
        ''')

    def test_manual_standard_exit_change_is_preserved_and_relinquished(self):
        self.check('''
          assert(mapper:receive(packet(101,{e=102})))
          addRoom(103);rooms[101].exits.east=103
          assert(mapper:receive(packet(101,{})))
          assert(rooms[101].exits.east==103)
          assert(rooms[101].data["aardwolf-vibe:exit:e"]=="")
          assert(mapper.conflicts==1 and mapper.enabled)
        ''')

    def test_special_exits_create_update_remove_and_preserve_manual_edits(self):
        self.check('''
          assert(mapper:receive(packet(101,{["enter gate"]=102})))
          assert(rooms[102] and rooms[101].special["enter gate"]==102)
          assert(mapper:receive(packet(101,{["enter gate"]=103})))
          assert(rooms[103] and rooms[101].special["enter gate"]==103)
          assert(mapper:receive(packet(101,{})))
          assert(rooms[101].special["enter gate"]==nil)
          addSpecialExit(101,102,"manual");assert(mapper:receive(packet(101,{["manual"]=103})))
          assert(rooms[101].special.manual==102 and mapper.conflicts>=1)
        ''')

    def test_maze_destination_becomes_stub_and_no_reverse_exit_is_invented(self):
        self.check('''
          assert(mapper:receive(packet(101,{n="?",w=102})))
          assert(rooms[101].stubs.north and rooms[101].exits.west==102)
          assert(rooms[102].exits.east==nil)
        ''')

    def test_self_loop_does_not_conflict_with_current_room_construction(self):
        self.check('''
          assert(mapper:receive(packet(101,{u=101})))
          assert(rooms[101].exits.up==101)
          assert(rooms[101].data["aardwolf-vibe:ready"]=="1")
        ''')

    def test_complete_terrain_catalog_uses_supplied_color_codes(self):
        self.check('''
          local names={
            "inside","city","desert","ruins","tornado","dustdevil","wind1","wind2","lightning","rain","sun","cloud1","cloud2","ocean","cloud3","rainbow","quicksand","underwater","ice","underground","road_eastwest","road","river","volcano","field","cave","dungeon","road_crossroads","mudschool","areaexit","hellinside","hellfountain","hell1","hell2","hell3","forest","insideice","hellhall","hell4","smallroad","smallroad_ew","trail_ew","beach","shore","jungle","swamp","hills","bridge","plain","ocean2","ocean3","ocean4","field3","field2","field4","rocks","snow","mountain","icemount","icehills","space1","space2","space3","space4","castle","pillar","dark","crossroad_nw","waterswim","crossroad_se","crossroad_ews","mountain_cyan","moon","temple","shop","clanexit","chessblack","chesswhite","lottery","waternoswim","alley","fountain","archive","bookshelves","bookshelves_ns","office","electric","well","bloodyhall","bloodyroom","unused","dead_forest","dead_field","graveyard","palace_room","crypt","dead_jungle","ship","chaos_sea","hut"
          }
          assert(#names==100)
          for _,name in ipairs(names) do assert(mapper.terrainColorCodes[name],name) end
          assert(mapper.terrainIDs.inside==0 and mapper.terrainIDs.hut==88)
          assert(mapper.terrainIDs.ruins==100 and mapper.terrainIDs.rainbow==111)
          local ids={};for _,value in pairs(mapper.terrainIDs) do assert(not ids[value]);ids[value]=true end
          assert(ids[9]==nil)
          assert(mapper.terrainColorCodes.mudschool==7 and mapper.terrainColorCodes.forest==10)
          assert(mapper.terrainColorCodes.waterswim==12 and mapper.terrainColorCodes.waternoswim==12)
          assert(mapper:receive(packet(101,{},"test","Mudschool")))
          local env=rooms[101].env
          assert(environmentColors[env][1]==192 and environmentColors[env][2]==192 and environmentColors[env][3]==192)
          assert(mapper:receive(packet(102,{},"test","rainbow")))
          env=rooms[102].env
          assert(environmentColors[env][1]==0 and environmentColors[env][2]==255 and environmentColors[env][3]==255)
        ''')

    def test_reconnect_stale_packet_and_lifecycle_ownership(self):
        self.check('''
          gmcp={room={info=packet(101)}};fire("gmcp.room.info");local before=writes
          fire("gmcp.room.info");assert(writes==before)
          fire("sysDisconnectionEvent");fire("gmcp.room.info");assert(writes==before)
          mapper:stop();assert(next(handlers)==nil and next(modules)==nil)
          assert(mapper:start());assert(mapper:start())
          local count=0;for _ in pairs(handlers) do count=count+1 end;assert(count==4)
        ''')

    def test_backup_and_registration_failures_stop_cleanly(self):
        self.check('''
          fail.saveMap=true;assert(not mapper:receive(packet(101)))
          assert(not rooms[101] and not mapper.enabled and mapper.failed==1)
          mapper:start();fail.register=true;mapper:stop();assert(not mapper:start())
          assert(next(handlers)==nil and next(modules)==nil)
        ''')

    def test_interrupted_room_construction_stays_incomplete_and_is_refused(self):
        self.check('''
          fail.setRoomEnv=true;assert(not mapper:receive(packet(101)))
          assert(rooms[101] and rooms[101].data["aardwolf-vibe:ready"]=="0")
          assert(not mapper.enabled)
          assert(mapper:start())
          assert(not mapper:receive(packet(101)))
          assert(rooms[101].data["aardwolf-vibe:ready"]=="0" and not mapper.enabled)
        ''')

    def test_known_competing_mapper_prevents_start(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        install_json(lua)
        lua.execute(API)
        factory = lua.execute(SOURCE)
        lua.globals().factory = factory
        lua.execute('settings={backupDir="/tmp/backups",ensureDirectory=function() return true end};packages={"generic_mapper"};mapper=factory.new(_G,settings);assert(not mapper:start());assert(next(handlers)==nil)')


if __name__ == "__main__":
    unittest.main()
