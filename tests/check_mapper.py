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

    def test_healthy_grid_refresh_uses_bounded_map_reads_and_one_redraw(self):
        self.check((ROOT / "tests/mapper_grid.lua").read_text() + '''
          local fresh=seedMapperGrid(10,1000)
          countMapperAPI()
          assert(mapper:receive(fresh))
          assert(mapper.reflowedRooms==0 and mapper.layoutConflicts==0)
          assert(apiCounts.getRooms==1)
          assert(apiCounts.getRoomCoordinates<=3200)
          assert(apiCounts.updateMap==1 and apiCounts.centerview==1)
        ''')

    def test_world_room_search_is_literal_sorted_complete_and_read_only(self):
        self.check('''
          mapper:stop()
          local alpha=addAreaName("Alpha Woods")
          local beta=addAreaName("Beta Keep")
          addRoom(10);setRoomArea(10,beta);setRoomName(10,"Gate")
          addRoom(11);setRoomArea(11,alpha);setRoomName(11,"Gatehouse")
          addRoom(12);setRoomArea(12,alpha);setRoomName(12,"North Gate")
          addRoom(13);setRoomArea(13,alpha);setRoomName(13,"G.te Annex")
          local before=writes
          local results,scope=mapper:searchRooms("g.te")
          assert(scope.world and scope.query=="g.te" and #results==1)
          assert(results[1].id==13 and results[1].name=="G.te Annex")
          results,scope=mapper:searchRooms("GATE")
          assert(#results==3 and results[1].id==10 and results[1].exact)
          assert(results[2].id==11 and results[2].areaName=="Alpha Woods")
          assert(results[3].id==12 and not results[3].exact)
          assert(writes==before and not mapper.enabled and next(handlers)==nil)
        ''')

    def test_named_area_search_resolves_exact_unique_ambiguous_and_missing(self):
        self.check('''
          mapper:stop()
          local woods=addAreaName("Alpha Woods")
          local warrens=addAreaName("Alpha Warrens")
          addRoom(20);setRoomArea(20,woods);setRoomName(20,"Silver Gate")
          addRoom(21);setRoomArea(21,warrens);setRoomName(21,"Golden Gate")
          local results,scope=mapper:searchRooms("gate","ALPHA WOODS")
          assert(#results==1 and results[1].id==20)
          assert(scope.areaID==woods and scope.areaName=="Alpha Woods" and not scope.world)
          results,scope=mapper:searchRooms("gate","warr")
          assert(#results==1 and results[1].id==21 and scope.areaName=="Alpha Warrens")
          local missing,message=mapper:searchRooms("gate","alpha")
          assert(not missing and message=="Area 'alpha' is ambiguous: Alpha Warrens, Alpha Woods")
          missing,message=mapper:searchRooms("gate","nowhere")
          assert(not missing and message=="No mapped area matches 'nowhere'")
        ''')

    def test_room_search_validates_input_map_data_and_foreign_strings(self):
        self.check('''
          mapper:stop()
          local area=addAreaName("Search Area")
          addRoom(30);setRoomArea(30,area);setRoomName(30,"Safe Room")
          addRoom(31);setRoomArea(31,area);setRoomName(31,"Unsafe\\nRoom")
          local results=assert(mapper:searchRooms("room"))
          assert(#results==1 and results[1].id==30)
          local invalid,message=mapper:searchRooms(" ")
          assert(not invalid and message:find("1-256",1,true))
          invalid,message=mapper:searchRooms("bad\\nquery")
          assert(not invalid and message:find("printable",1,true))
          invalid,message=mapper:searchRooms(string.rep("x",257))
          assert(not invalid and message:find("1-256",1,true))
          local original=getRooms
          getRooms=function() error("map closed") end
          invalid,message=mapper:searchRooms("room")
          assert(not invalid and message:find("map closed",1,true))
          getRooms=function() return nil end
          invalid,message=mapper:searchRooms("room")
          assert(not invalid and message=="Map room data is unavailable")
          getRooms=original
          local originalArea=getRoomArea
          getRoomArea=function() error("area failure") end
          invalid,message=mapper:searchRooms("room")
          assert(not invalid and message:find("area failure",1,true))
          getRoomArea=originalArea
        ''')

    def test_locate_opens_and_centers_without_changing_mapper_tracking(self):
        self.check('''
          assert(mapper:receive(packet(40,{})))
          local current=mapper.current
          addRoom(41);setRoomArea(41,areas.test);setRoomName(41,"Destination")
          local before=writes
          local ok,result=mapper:locateRoom("41")
          assert(ok and result.id==41 and result.name=="Destination")
          assert(result.areaName=="test" and mapOpens==1 and centers[#centers]==41)
          assert(mapper.current==current and writes==before)
          ok,result=mapper:locateRoom("0")
          assert(not ok and result:find("positive integer",1,true) and mapOpens==1)
          ok,result=mapper:locateRoom(999)
          assert(not ok and result:find("does not exist",1,true) and mapOpens==1)
          local original=openMapWidget
          openMapWidget=function() error("widget failure") end
          ok,result=mapper:locateRoom(41)
          assert(not ok and result:find("widget failure",1,true))
          openMapWidget=original
          local originalCenter=centerview
          centerview=function() return nil,"center failure" end
          ok,result=mapper:locateRoom(41)
          assert(not ok and result:find("center failure",1,true))
          centerview=originalCenter
        ''')

    def test_locate_reveals_embedded_workspace_map(self):
        self.check('''
          mapper:stop()
          local workspace={status=function() return {enabled=true} end}
          local shown=0
          local display={show=function() shown=shown+1;return true end}
          mapper=factory.new(_G,settings,workspace,display)
          assert(mapper:start())
          addRoom(41);setRoomArea(41,areas.test);setRoomName(41,"Destination")
          local ok,result=mapper:locateRoom(41)
          assert(ok and result.id==41 and shown==1 and mapOpens==0)
          assert(centers[#centers]==41)
        ''')

    def test_grid_refresh_detects_external_changes_between_identical_packets(self):
        self.check((ROOT / "tests/mapper_grid.lua").read_text() + '''
          local fresh=seedMapperGrid(5,0)
          assert(mapper:receive(fresh))
          assert(mapper.layoutConflicts==0)
          local x,y,z=getRoomCoordinates(fresh.num)
          addRoom(999);setRoomArea(999,areas.test);setRoomCoordinates(999,x+1,y,z)
          assert(mapper:receive(fresh))
          assert(mapper.layoutConflicts>0 and rooms[999].x==x+1)
          assert(rooms[fresh.num].exits.east==fresh.exits.e)
        ''')

    def sparse_check(self, direction, snippet):
        self.check('''
          assert(mapper:receive(packet(100,{n=201,e=202,w=203})))
          assert(mapper:receive(packet(100,{})))
          -- Anchor the source manually so these fixtures exercise insertion and
          -- displacement retry, rather than the separate sideways-column repair.
          setRoomUserData(100,"aardwolf-vibe:placement-x","999")
          local short="''' + direction + '''"
          local vectors={n={0,1,"s"},e={1,0,"w"},s={0,-1,"n"},w={-1,0,"e"}}
          local dx,dy,reverse=unpack(vectors[short])
          local function place(id,distance)
            setRoomCoordinates(id,dx*distance,dy*distance,0)
            for key,value in pairs({area=areas.test,x=dx*distance,y=dy*distance,
                z=0,authority="provisional"}) do
              setRoomUserData(id,"aardwolf-vibe:placement-"..key,tostring(value))
            end
          end
          local function link(from,direction,target)
            setExit(from,target,direction)
            setRoomUserData(from,"aardwolf-vibe:exit:"..direction,tostring(target))
          end
          local function distance(id) return rooms[id].x*dx+rooms[id].y*dy end
          place(201,20);place(202,22);place(203,24)
        ''' + snippet)

    def column_check(self, snippet, rotate=False):
        self.check('''
          assert(mapper:receive(packet(100,{n=101,e=102,s=103,w=104,u=105,d=201})))
          assert(mapper:receive(packet(100,{})))
          assert(mapper:receive(packet(202,{})))
          assert(mapper:receive(packet(203,{u=300})))
          assert(mapper:receive(packet(203,{})))
          assert(mapper:receive(packet(204,{})))
          local rotate=''' + str(rotate).lower() + '''
          local directions=rotate and {n="e",s="w",e="s",w="n"} or {n="n",s="s",e="e",w="w"}
          local function place(id,x,y)
            if rotate then x,y=y,-x end
            setRoomCoordinates(id,x,y,0)
            for key,value in pairs({area=areas.test,x=x,y=y,z=0,authority="gmcp-reciprocal"}) do
              setRoomUserData(id,"aardwolf-vibe:placement-"..key,tostring(value))
            end
          end
          local function link(a,d,b)
            d=directions[d]
            setExit(a,b,d);setRoomUserData(a,"aardwolf-vibe:exit:"..d,tostring(b))
          end
          local function at(id,x,y)
            if rotate then x,y=y,-x end
            return rooms[id].x==x and rooms[id].y==y and rooms[id].z==0
          end
          place(100,4,0);place(101,4,2);place(102,6,4)
          place(103,4,-6);place(104,4,-8);place(105,4,-10)
          place(201,4,-4);place(202,4,4);place(203,2,0);place(204,2,-10)
          place(300,20,20)
          link(100,"n",101);link(101,"s",100);link(101,"n",102)
          link(100,"s",103);link(103,"n",100)
          link(103,"s",104);link(104,"n",103)
          link(104,"s",105);link(105,"n",104)
          link(100,"w",203);link(203,"e",100)
          link(105,"w",204);link(204,"e",105)
          local fresh=packet(100,{[directions.n]=101,[directions.s]=103,[directions.w]=203})
        ''' + snippet)

    def test_sideways_column_repair_aligns_north_and_clears_south_connector(self):
        for rotate in (False, True):
            with self.subTest(rotate=rotate):
                self.column_check('''
                  assert(mapper:receive(fresh))
                  assert(at(100,6,0) and at(101,6,2))
                  assert(at(103,6,-6) and at(104,6,-8) and at(105,6,-10))
                  assert(at(102,6,4) and at(201,4,-4) and at(202,4,4))
                  assert(at(203,2,0) and at(204,2,-10))
                  assert(mapper.reflowedRooms==5 and mapper.layoutConflicts==0)
                  for _,id in ipairs({100,101,103,104,105}) do
                    assert(rooms[id].data["aardwolf-vibe:placement-authority"]=="gmcp-reciprocal")
                  end
                  assert(mapper:receive(fresh))
                  assert(mapper.reflowedRooms==5)
                ''', rotate)

    def test_sideways_column_repair_preserves_protected_member(self):
        for protection in ("manual", "continent", "foreign"):
            with self.subTest(protection=protection):
                self.column_check('''
                  local protection="''' + protection + '''"
                  if protection=="manual" then
                    setRoomUserData(104,"aardwolf-vibe:placement-x","999")
                  elseif protection=="continent" then
                    setRoomUserData(104,"aardwolf-vibe:placement-authority","gmcp-continent")
                  else
                    setRoomUserData(104,"aardwolf-vibe:owner","")
                  end
                  assert(mapper:receive(fresh))
                  assert(at(100,4,0) and at(101,4,2) and at(103,4,-6))
                  assert(at(104,4,-8) and at(105,4,-10))
                  assert(mapper.reflowedRooms==0 and mapper.layoutConflicts>0)
                ''')

    def test_sideways_column_carries_required_provisional_side_exit(self):
        self.column_check('''
          place(300,6,-8)
          setRoomUserData(300,"aardwolf-vibe:placement-authority","provisional")
          link(104,"e",300)
          assert(mapper:receive(fresh))
          assert(at(100,6,0) and at(101,6,2) and at(104,6,-8))
          assert(at(300,8,-8) and rooms[104].exits.east==300)
          assert(rooms[300].data["aardwolf-vibe:placement-authority"]=="provisional")
          assert(mapper.reflowedRooms==6 and mapper.layoutConflicts==0)
          assert(mapper:receive(fresh))
          assert(mapper.reflowedRooms==6)
        ''')

    def test_sideways_column_rejects_obstacle_in_new_connector_corridor(self):
        self.column_check('''
          addRoom(999);setRoomArea(999,areas.test);setRoomCoordinates(999,6,-2,0)
          assert(mapper:receive(fresh))
          assert(at(100,4,0) and at(101,4,2) and at(103,4,-6))
          assert(at(999,6,-2) and mapper.reflowedRooms==0)
          assert(mapper.layoutConflicts>0)
        ''')

    def test_sideways_column_does_not_place_room_on_unrelated_connector(self):
        self.column_check('''
          place(202,5,-6);place(300,7,-6)
          link(202,"e",300)
          assert(mapper:receive(fresh))
          assert(at(100,4,0) and at(103,4,-6) and at(105,4,-10))
          assert(at(202,5,-6) and at(300,7,-6))
          assert(mapper.reflowedRooms==0 and mapper.layoutConflicts>0)
        ''')

    def test_aligned_column_with_obstructed_exit_still_opens_a_gap(self):
        self.column_check('''
          place(102,4,4);place(202,2,4)
          assert(mapper:receive(fresh))
          assert(at(100,6,0) and at(102,6,4) and at(105,6,-10))
          assert(at(201,4,-4) and at(202,2,4))
          assert(mapper.reflowedRooms==6 and mapper.layoutConflicts==0)
        ''')

    def test_diagonal_north_exit_without_corridor_obstruction_aligns_column(self):
        self.column_check('''
          place(201,0,-4)
          assert(mapper:receive(fresh))
          assert(at(100,6,0) and at(101,6,2) and at(102,6,4))
          assert(at(103,6,-6) and at(201,0,-4))
          assert(mapper.reflowedRooms==5 and mapper.layoutConflicts==0)
        ''')

    def test_column_corridor_ignores_rooms_on_other_floors_or_areas(self):
        self.column_check('''
          addRoom(998);setRoomArea(998,areas.test);setRoomCoordinates(998,6,-2,1)
          local other=addAreaName("other")
          addRoom(999);setRoomArea(999,other);setRoomCoordinates(999,6,-2,0)
          assert(mapper:receive(fresh))
          assert(at(100,6,0) and at(103,6,-6))
          assert(rooms[998].z==1 and rooms[999].area==other)
          assert(mapper.reflowedRooms==5 and mapper.layoutConflicts==0)
        ''')

    def test_fixed_anchor_cannot_close_loop_through_foreign_room(self):
        self.check('''
          assert(mapper:receive(packet(100,{e=101,n=102})))
          addRoom(999);setRoomArea(999,areas.test);setRoomCoordinates(999,2,2,0)
          assert(mapper:receive(packet(101,{n=103})))
          local fixed=packet(102,{s=100,e=103},"test","inside",{cont=1,id=0,x=0,y=-2})
          assert(mapper:receive(fixed))
          assert(rooms[102].x==0 and rooms[102].y==2)
          assert(rooms[103].x==4 and rooms[103].y==4)
          assert(rooms[999].x==2 and rooms[999].y==2)
          assert(rooms[102].exits.east==103 and mapper.layoutConflicts==2)
          local moved=mapper.reflowedRooms
          assert(mapper:receive(fixed))
          assert(mapper.reflowedRooms==moved and mapper.layoutConflicts==2)
        ''')

    def test_sparse_insertion_leaves_fixed_neighbor_across_existing_gap(self):
        for direction in "nesw":
            with self.subTest(direction=direction):
                self.sparse_check(direction, '''
                  place(201,2);place(202,6)
                  setRoomUserData(202,"aardwolf-vibe:placement-x","999")
                  link(201,short,202)
                  assert(mapper:receive(packet(100,{[short]=300})))
                  assert(distance(300)==2 and distance(201)==4 and distance(202)==6)
                  assert(mapper.reflowedRooms==1 and mapper.layoutConflicts==0)
                  local moved=mapper.reflowedRooms
                  assert(mapper:receive(packet(100,{[short]=300})))
                  assert(mapper.reflowedRooms==moved)
                ''')

    def test_sparse_insertion_tries_larger_shift_past_fixed_obstacle(self):
        for direction in "nesw":
            with self.subTest(direction=direction):
                self.sparse_check(direction, '''
                  place(201,2)
                  addRoom(999);setRoomArea(999,areas.test)
                  setRoomCoordinates(999,dx*4,dy*4,0)
                  assert(mapper:receive(packet(100,{[short]=300})))
                  assert(distance(300)==2 and distance(201)==6 and distance(999)==4)
                  assert(mapper.reflowedRooms==1 and mapper.layoutConflicts==0)
                ''')

    def test_sparse_insertion_prefers_fewer_moved_rooms_over_shorter_shift(self):
        for direction in "nesw":
            with self.subTest(direction=direction):
                self.sparse_check(direction, '''
                  place(201,2);place(202,4)
                  assert(mapper:receive(packet(100,{[short]=300})))
                  assert(distance(300)==2 and distance(201)==6 and distance(202)==4)
                  assert(mapper.reflowedRooms==1)
                ''')

    def test_collision_displacement_survives_visits_and_reload_until_repaired(self):
        for direction in "nesw":
            with self.subTest(direction=direction):
                self.sparse_check(direction, '''
                  place(201,2)
                  setRoomUserData(201,"aardwolf-vibe:placement-x","999")
                  assert(mapper:receive(packet(100,{[short]=300})))
                  assert(distance(300)==4 and mapper.layoutConflicts==1)
                  assert(rooms[300].data["aardwolf-vibe:displaced-from"]=="100")
                  assert(rooms[300].data["aardwolf-vibe:displaced-direction"]==short)
                  assert(mapper:receive(packet(2000,{},"other")))
                  assert(mapper:receive(packet(100,{[short]=300})))
                  assert(mapper:receive(packet(300,{[reverse]=100})))
                  assert(rooms[300].data["aardwolf-vibe:placement-authority"]=="provisional")
                  assert(mapper.layoutConflicts==1 and distance(300)==4)
                  mapper:stop();mapper=factory.new(_G,settings);assert(mapper:start())
                  assert(mapper:receive(packet(300,{[reverse]=100})))
                  assert(distance(300)==4)
                  assert(rooms[300].data["aardwolf-vibe:placement-authority"]=="provisional")
                  setRoomCoordinates(201,dx*8,dy*8,0)
                  assert(mapper:receive(packet(300,{[reverse]=100})))
                  assert(distance(300)==2 and distance(201)==8)
                  assert(rooms[300].data["aardwolf-vibe:displaced-from"]=="")
                  assert(rooms[300].data["aardwolf-vibe:displaced-direction"]=="")
                  assert(mapper:receive(packet(100,{[short]=300})))
                  assert(mapper:receive(packet(300,{[reverse]=100})))
                  assert(rooms[300].data["aardwolf-vibe:placement-authority"]=="gmcp-reciprocal")
                ''')

    def test_source_refresh_repairs_recorded_displacement_without_blockers(self):
        self.sparse_check("e", '''
          place(201,2);setRoomUserData(201,"aardwolf-vibe:placement-x","999")
          assert(mapper:receive(packet(100,{e=300})))
          assert(distance(300)==4 and mapper.layoutConflicts==1)
          setRoomCoordinates(201,8,0,0)
          assert(mapper:receive(packet(100,{e=300})))
          assert(distance(300)==2 and distance(201)==8)
          assert(rooms[300].data["aardwolf-vibe:displaced-from"]=="")
          local moved=mapper.reflowedRooms
          assert(mapper:receive(packet(100,{e=300})))
          assert(mapper.reflowedRooms==moved and mapper.layoutConflicts==1)
        ''')

    def test_impossible_sparse_insertion_keeps_all_existing_coordinates(self):
        for direction in "nesw":
            with self.subTest(direction=direction):
                self.sparse_check(direction, '''
                  place(201,2);place(202,4)
                  setRoomUserData(202,"aardwolf-vibe:placement-x","999")
                  link(201,short,202)
                  assert(mapper:receive(packet(100,{[short]=300})))
                  assert(distance(201)==2 and distance(202)==4 and distance(300)==6)
                  assert(mapper.reflowedRooms==0 and mapper.layoutConflicts==1)
                  for attempt=1,3 do assert(mapper:receive(packet(100,{[short]=300}))) end
                  assert(distance(201)==2 and distance(202)==4 and distance(300)==6)
                  assert(mapper.reflowedRooms==0 and mapper.layoutConflicts==1)
                  assert(rooms[100].exits[({n="north",e="east",s="south",w="west"})[short]]==300)
                ''')

    def test_sparse_expansion_search_includes_sixty_four_unit_shift(self):
        self.sparse_check("e", '''
          place(201,2)
          for position=4,64,2 do
            local id=1000+position
            addRoom(id);setRoomArea(id,areas.test);setRoomCoordinates(id,position,0,0)
          end
          assert(mapper:receive(packet(100,{e=300})))
          assert(distance(201)==66 and distance(300)==2 and mapper.reflowedRooms==1)
          for position=4,64,2 do assert(distance(1000+position)==position) end
        ''')

    def test_recorded_displacement_repairs_on_arrival_before_reciprocal_promotion(self):
        self.sparse_check("e", '''
          place(201,2);setRoomUserData(201,"aardwolf-vibe:placement-x","999")
          assert(mapper:receive(packet(100,{e=300})))
          assert(mapper:receive(packet(2000,{},"other")))
          assert(mapper:receive(packet(100,{e=300})))
          place(201,2)
          assert(mapper:receive(packet(300,{w=100})))
          assert(distance(300)==2 and distance(201)==4)
          assert(rooms[300].data["aardwolf-vibe:displaced-from"]=="")
          assert(rooms[300].data["aardwolf-vibe:placement-authority"]=="gmcp-reciprocal")
        ''')

    def test_displacement_retry_respects_new_destination_topology(self):
        self.sparse_check("e", '''
          place(201,2);place(202,4)
          setRoomCoordinates(202,4,2,0)
          setRoomUserData(202,"aardwolf-vibe:placement-y","2")
          setRoomUserData(202,"aardwolf-vibe:placement-authority","gmcp-reciprocal")
          setRoomUserData(201,"aardwolf-vibe:placement-x","999")
          assert(mapper:receive(packet(100,{e=300})))
          setRoomCoordinates(201,8,0,0)
          assert(mapper:receive(packet(300,{w=100,n=202})))
          assert(rooms[300].x==4 and rooms[300].y==0)
          assert(rooms[202].x==4 and rooms[202].y==2)
          assert(rooms[300].exits.north==202 and rooms[300].exits.west==100)
          assert(rooms[300].data["aardwolf-vibe:displaced-from"]=="100")
          assert(mapper.reflowedRooms==0)
        ''')

    def test_displacement_retry_preserves_manual_and_established_destinations(self):
        self.sparse_check("e", '''
          place(201,2);setRoomUserData(201,"aardwolf-vibe:placement-x","999")
          assert(mapper:receive(packet(100,{e=300})))
          setRoomCoordinates(300,10,0,0)
          setRoomCoordinates(201,8,0,0)
          assert(mapper:receive(packet(100,{e=300})))
          assert(mapper:receive(packet(300,{w=100})))
          assert(distance(300)==10 and rooms[300].data["aardwolf-vibe:placement-x"]=="4")
          assert(mapper.reflowedRooms==0)
        ''')
        self.sparse_check("e", '''
          place(201,2);place(202,6)
          setRoomUserData(202,"aardwolf-vibe:placement-authority","gmcp-reciprocal")
          assert(mapper:receive(packet(100,{e=202})))
          assert(distance(201)==2 and distance(202)==6 and mapper.reflowedRooms==0)
          assert(getRoomUserData(202,"aardwolf-vibe:displaced-from")=="")
        ''')

    def test_displacement_retry_does_not_follow_a_replaced_owned_exit(self):
        self.sparse_check("e", '''
          place(201,2);setRoomUserData(201,"aardwolf-vibe:placement-x","999")
          assert(mapper:receive(packet(100,{e=300})))
          setRoomCoordinates(201,8,0,0)
          setExit(100,202,"e")
          assert(mapper:receive(packet(300,{w=100})))
          assert(distance(300)==4 and rooms[100].exits.east==202)
          assert(mapper.reflowedRooms==0)
        ''')

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

    def test_ansi_formatted_aardwolf_room_name_updates_player_room(self):
        self.check('''
          local escape=string.char(27)
          local info={
            coord={cont=0,id=0,x=30,y=20},
            details="safe",
            exits={d=6900,e=26672,n=32884,s=4473,u=5861,w=31561},
            mapterrain="",
            name=escape.."[1;32mThe Meadow of Portals"..escape.."[0;37m",
            num=31560,
            outside=1,
            racebonus=1,
            terrain="field",
            zone="tanelorn",
          }
          assert(getPlayerRoom()==3248)
          assert(mapper:receive(info))
          assert(mapper.current==31560 and getPlayerRoom()==31560)
          assert(centers[#centers]==31560)
          assert(rooms[31560].name=="The Meadow of Portals")
          assert(rooms[31560].data["aardwolf-vibe:gmcp"]:find("The Meadow of Portals",1,true))
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
          setRoomUserData(101,"aardwolf-vibe:placement-x","999")
          addRoom(999);setRoomArea(999,areas.test);setRoomCoordinates(999,2,0,0)
          assert(mapper:receive(packet(101,{e=102},"test")))
          assert(rooms[102].x==4 and rooms[102].y==0 and rooms[102].z==0)
          assert(rooms[101].exits.east==102)
          assert(mapper.reflowedRooms==0)
        ''')

    def test_sparse_expansion_respects_manual_and_continent_blockers(self):
        self.check('''
          assert(mapper:receive(packet(100,{e=201,w=202},"test")))
          assert(mapper:receive(packet(100,{},"test")))
          setRoomUserData(100,"aardwolf-vibe:placement-x","999")

          -- Keep room 201 at the eastern insertion point, but deliberately
          -- leave its recorded x coordinate stale to model a manual move.
          setRoomCoordinates(201,2,0,0)
          setRoomUserData(201,"aardwolf-vibe:placement-x","4")

          -- Room 202 is intact but continent-authoritative.
          setRoomCoordinates(202,-2,0,0)
          setRoomUserData(202,"aardwolf-vibe:placement-x","-2")
          setRoomUserData(202,"aardwolf-vibe:placement-y","0")
          setRoomUserData(202,"aardwolf-vibe:placement-z","0")
          setRoomUserData(202,"aardwolf-vibe:placement-authority","gmcp-continent")

          assert(mapper:receive(packet(100,{e=301,w=302},"test")))
          assert(rooms[201].x==2 and rooms[201].y==0)
          assert(rooms[202].x==-2 and rooms[202].y==0)
          assert(rooms[301].x==4 and rooms[301].y==0)
          assert(rooms[302].x==-4 and rooms[302].y==0)
          assert(mapper.reflowedRooms==0)
        ''')

    def test_new_interior_room_expands_owned_perimeter_instead_of_escaping_it(self):
        self.check('''
          assert(mapper:receive(packet(100,{n=201,e=202,w=203},"test")))
          assert(mapper:receive(packet(100,{},"test")))
          local function place(id,x,y,authority)
            setRoomCoordinates(id,x,y,0)
            setRoomUserData(id,"aardwolf-vibe:placement-area",tostring(areas.test))
            setRoomUserData(id,"aardwolf-vibe:placement-x",tostring(x))
            setRoomUserData(id,"aardwolf-vibe:placement-y",tostring(y))
            setRoomUserData(id,"aardwolf-vibe:placement-z","0")
            setRoomUserData(id,"aardwolf-vibe:placement-authority",authority)
          end
          place(201,-2,-2,"gmcp-reciprocal")
          place(202,0,-2,"gmcp-reciprocal")
          place(203,2,-2,"gmcp-reciprocal")
          rooms[201].exits.east=202
          rooms[202].exits.west=201;rooms[202].exits.east=203
          rooms[203].exits.west=202
          setRoomUserData(201,"aardwolf-vibe:exit:e","202")
          setRoomUserData(202,"aardwolf-vibe:exit:w","201")
          setRoomUserData(202,"aardwolf-vibe:exit:e","203")
          setRoomUserData(203,"aardwolf-vibe:exit:w","202")

          assert(mapper:receive(packet(100,{s=300},"test")))
          assert(rooms[300].x==0 and rooms[300].y==-2)
          assert(rooms[201].x==-2 and rooms[201].y==-4)
          assert(rooms[202].x==0 and rooms[202].y==-4)
          assert(rooms[203].x==2 and rooms[203].y==-4)
          assert(rooms[201].exits.east==202 and rooms[202].exits.east==203)
          assert(mapper.reflowedRooms==3 and mapper.layoutConflicts==0)
        ''')

    def test_existing_displaced_placeholder_is_pulled_inside_expanded_perimeter(self):
        self.check('''
          assert(mapper:receive(packet(100,{n=201,e=202,s=300,w=203},"test")))
          assert(mapper:receive(packet(100,{},"test")))
          local function place(id,x,y,authority)
            setRoomCoordinates(id,x,y,0)
            setRoomUserData(id,"aardwolf-vibe:placement-area",tostring(areas.test))
            setRoomUserData(id,"aardwolf-vibe:placement-x",tostring(x))
            setRoomUserData(id,"aardwolf-vibe:placement-y",tostring(y))
            setRoomUserData(id,"aardwolf-vibe:placement-z","0")
            setRoomUserData(id,"aardwolf-vibe:placement-authority",authority)
          end
          place(201,-2,-2,"gmcp-reciprocal")
          place(202,0,-2,"gmcp-reciprocal")
          place(203,2,-2,"gmcp-reciprocal")
          place(300,0,-4,"provisional")
          rooms[201].exits.east=202
          rooms[202].exits.west=201;rooms[202].exits.east=203
          rooms[203].exits.west=202
          setRoomUserData(201,"aardwolf-vibe:exit:e","202")
          setRoomUserData(202,"aardwolf-vibe:exit:w","201")
          setRoomUserData(202,"aardwolf-vibe:exit:e","203")
          setRoomUserData(203,"aardwolf-vibe:exit:w","202")

          assert(mapper:receive(packet(100,{s=300},"test")))
          assert(rooms[300].x==0 and rooms[300].y==-2 and rooms[300].char=="?")
          assert(rooms[300].data["aardwolf-vibe:placement-authority"]=="provisional")
          assert(rooms[201].y==-4 and rooms[202].y==-4 and rooms[203].y==-4)
          assert(mapper.reflowedRooms==4 and mapper.layoutConflicts==0)
          local reflowed=mapper.reflowedRooms
          assert(mapper:receive(packet(100,{s=300},"test")))
          assert(mapper.reflowedRooms==reflowed and rooms[300].y==-2)
        ''')

    def test_east_west_expansion_opens_overlapped_established_interior_rooms(self):
        for sign, short in ((-1, "w"), (1, "e")):
            self.check(f'''
              assert(mapper:receive(packet(100,{{n=201,e=202,s=203,w=300,u=204,d=205}},"test")))
              assert(mapper:receive(packet(100,{{}},"test")))
              local sign={sign}
              local short="{short}"
              local function place(id,x,y)
                setRoomCoordinates(id,x,y,0)
                setRoomUserData(id,"aardwolf-vibe:placement-area",tostring(areas.test))
                setRoomUserData(id,"aardwolf-vibe:placement-x",tostring(x))
                setRoomUserData(id,"aardwolf-vibe:placement-y",tostring(y))
                setRoomUserData(id,"aardwolf-vibe:placement-z","0")
                setRoomUserData(id,"aardwolf-vibe:placement-authority","gmcp-reciprocal")
              end

              -- The inner target overlaps the compact side column. The two
              -- connected top/bottom rooms share the source's x coordinate,
              -- so moving the whole half-perimeter creates the central gap
              -- shown by the reference layout instead of a gap at the corner.
              place(100,sign*2,0)
              place(201,sign*4,4);place(202,sign*4,0);place(203,sign*4,-4)
              place(204,sign*2,4);place(205,sign*2,-4);place(300,sign*4,0)
              rooms[201].exits.south=202;rooms[202].exits.north=201
              rooms[202].exits.south=203;rooms[203].exits.north=202
              setRoomUserData(201,"aardwolf-vibe:exit:s","202")
              setRoomUserData(202,"aardwolf-vibe:exit:n","201")
              setRoomUserData(202,"aardwolf-vibe:exit:s","203")
              setRoomUserData(203,"aardwolf-vibe:exit:n","202")
              if sign < 0 then
                rooms[201].exits.east=204;rooms[203].exits.east=205
                setRoomUserData(201,"aardwolf-vibe:exit:e","204")
                setRoomUserData(203,"aardwolf-vibe:exit:e","205")
              else
                rooms[201].exits.west=204;rooms[203].exits.west=205
                setRoomUserData(201,"aardwolf-vibe:exit:w","204")
                setRoomUserData(203,"aardwolf-vibe:exit:w","205")
              end

              local beforeReflow=mapper.reflowedRooms
              assert(mapper:receive(packet(100,{{[short]=300}},"test")))
              assert(rooms[300].x==sign*4 and rooms[300].y==0)
              assert(rooms[201].x==sign*6 and rooms[202].x==sign*6
                and rooms[203].x==sign*6)
              assert(rooms[204].x==sign*4 and rooms[205].x==sign*4)
              assert(mapper.reflowedRooms==beforeReflow+5 and mapper.layoutConflicts==0)

              local reflowed=mapper.reflowedRooms
              assert(mapper:receive(packet(100,{{[short]=300}},"test")))
              assert(mapper.reflowedRooms==reflowed)
            ''')

    def test_same_room_packet_does_not_count_as_successful_movement(self):
        self.check('''
          assert(mapper:receive(packet(101,{e=102},"test")))
          assert(mapper.current==101 and mapper.transitions==0 and mapper.stationary==0)
          assert(mapper.lastMovement=="none")

          -- A failed movement attempt can produce another fresh room.info for
          -- the room that the character still occupies.
          assert(mapper:receive(packet(101,{e=102},"test")))
          assert(mapper.current==101 and mapper.transitions==0 and mapper.stationary==1)
          assert(mapper.lastMovement=="none")

          assert(mapper:receive(packet(102,{w=101},"test")))
          assert(mapper.current==102 and mapper.transitions==1 and mapper.stationary==1)
          assert(mapper.lastMovement=="e")
          assert(mapper.reciprocalTransitions==1)
          assert(rooms[102].data["aardwolf-vibe:placement-authority"]=="gmcp-reciprocal")
          assert(rooms[102].x==2 and rooms[102].y==0 and rooms[102].z==0)
        ''')

    def test_reciprocal_gmcp_exits_confirm_bidirectional_topology(self):
        self.check('''
          assert(mapper:receive(packet(100,{s=101},"test")))
          assert(rooms[101].x==0 and rooms[101].y==-2 and rooms[101].z==0)
          assert(rooms[101].data["aardwolf-vibe:placement-authority"]=="provisional")

          assert(mapper:receive(packet(101,{n=100},"test")))
          assert(mapper.lastMovement=="s" and mapper.reciprocalTransitions==1)
          assert(rooms[101].x==0 and rooms[101].y==-2 and rooms[101].z==0)
          assert(rooms[101].data["aardwolf-vibe:placement-authority"]=="gmcp-reciprocal")
          assert(rooms[100].exits.south==101 and rooms[101].exits.north==100)
        ''')

    def test_reciprocal_transition_preserves_an_existing_sparse_gap(self):
        self.check('''
          assert(mapper:receive(packet(100,{e=101},"test")))
          setRoomCoordinates(101,6,0,0)
          setRoomUserData(101,"aardwolf-vibe:placement-x","6")
          assert(mapper:receive(packet(101,{w=100},"test")))
          assert(rooms[101].x==6 and rooms[101].y==0)
          assert(rooms[101].data["aardwolf-vibe:placement-authority"]=="gmcp-reciprocal")
          assert(rooms[100].exits.east==101 and rooms[101].exits.west==100)
        ''')

    def test_sparse_column_clears_blocker_before_loop_closure(self):
        self.check('''
          assert(mapper:receive(packet(100,{e=101,n=102},"test")))
          addRoom(999);setRoomArea(999,areas.test);setRoomCoordinates(999,2,2,0)

          -- Shift the column sideways instead of drawing through the blocker.
          assert(mapper:receive(packet(101,{n=103},"test")))
          assert(rooms[101].data["aardwolf-vibe:placement-authority"]=="provisional")
          assert(rooms[101].x==4 and rooms[101].y==0)
          assert(rooms[103].x==4 and rooms[103].y==4)
          assert(mapper:receive(packet(100,{e=101,n=102},"test")))

          -- The east edge can close at y=4 without crossing the blocker at y=2.
          local continent={cont=1,id=0,x=0,y=-4}
          assert(mapper:receive(packet(102,{s=100,e=103},"test","inside",continent)))
          assert(rooms[102].x==0 and rooms[102].y==4)
          assert(rooms[102].data["aardwolf-vibe:placement-authority"]=="gmcp-continent")
          assert(rooms[101].x==4 and rooms[101].y==0)
          assert(rooms[103].x==4 and rooms[103].y==4)
          assert(rooms[999].x==2 and rooms[999].y==2)
          -- The initial collision is now reported even though its later repair succeeds.
          assert(mapper.reflowedRooms==2 and mapper.layoutConflicts==1)
          assert(rooms[103].data["aardwolf-vibe:displaced-from"]=="101")
          assert(rooms[102].exits.east==103 and rooms[101].exits.north==103)

          local reflowed=mapper.reflowedRooms
          assert(mapper:receive(packet(102,{s=100,e=103},"test","inside",continent)))
          assert(mapper.reflowedRooms==reflowed)
          assert(rooms[101].x==4 and rooms[103].x==4)
        ''')

    def test_unsatisfied_established_layout_keeps_topology_and_mapper_running(self):
        self.check('''
          assert(mapper:receive(packet(100,{e=101},"test")))
          assert(mapper:receive(packet(101,{w=100},"test")))
          setRoomCoordinates(101,2,2,0)
          setRoomUserData(101,"aardwolf-vibe:placement-y","2")
          assert(mapper:receive(packet(100,{e=101},"test")))
          assert(mapper.enabled and rooms[101].x==2 and rooms[101].y==2)
          assert(rooms[100].exits.east==101)
          assert(mapper.layoutConflicts==1 and mapper.conflicts==1)
          assert(mapper:receive(packet(100,{e=101},"test")))
          assert(mapper.layoutConflicts==1)
          mapper:status()
          local found=false
          for _,message in ipairs(echoes) do
            if message:find("reflowed=0 layout-conflicts=1",1,true) then found=true end
          end
          assert(found)
        ''')

    def test_manual_coordinate_change_is_fixed_without_re_adoption(self):
        self.check('''
          assert(mapper:receive(packet(100,{e=101},"test")))
          setRoomCoordinates(101,4,2,0)
          assert(mapper:receive(packet(100,{e=101},"test")))
          assert(mapper.enabled and rooms[101].x==4 and rooms[101].y==2)
          assert(rooms[101].data["aardwolf-vibe:placement-x"]=="2")
          assert(rooms[101].data["aardwolf-vibe:placement-y"]=="0")
          assert(rooms[100].exits.east==101 and mapper.layoutConflicts==1)
          assert(mapper:receive(packet(101,{w=100},"test")))
          assert(mapper.enabled and rooms[101].x==4 and rooms[101].y==2)
          assert(rooms[101].data["aardwolf-vibe:placement-x"]=="2")
          assert(rooms[101].exits.west==100 and mapper.layoutConflicts==2)
        ''')

    def test_changed_room_not_in_prior_exit_table_is_not_given_a_direction(self):
        self.check('''
          assert(mapper:receive(packet(101,{e=102},"test")))
          assert(mapper:receive(packet(103,{},"test")))
          assert(mapper.current==103 and mapper.transitions==1)
          assert(mapper.lastMovement=="other")
          assert(not (rooms[103].x==2 and rooms[103].y==0))
        ''')

    def test_stationary_refresh_does_not_replace_movement_origin(self):
        self.check('''
          assert(mapper:receive(packet(101,{e=102},"test")))

          -- Simulate a placeholder removed outside the mapper, then a
          -- same-room failure refresh whose exit snapshot is transiently
          -- incomplete. The next real room must still be placed from the last
          -- confirmed movement origin, directly east rather than diagonally.
          rooms[101].exits.east=nil
          rooms[101].data["aardwolf-vibe:exit:e"]=""
          hashes[rooms[102].hash]=nil
          rooms[102]=nil
          assert(mapper:receive(packet(101,{},"test")))
          assert(mapper.transitions==0 and mapper.stationary==1)
          assert(mapper:receive(packet(102,{w=101},"test")))
          assert(rooms[102].x==2 and rooms[102].y==0 and rooms[102].z==0)
          assert(mapper.transitions==1 and mapper.reciprocalTransitions==1)
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

    def test_nonstandard_outgoing_command_learns_special_exit_on_transition(self):
        self.check('''
          assert(mapper:receive(packet(36703,{})))
          fire("sysDataSendRequest","enter fishtank")
          assert(mapper:receive(packet(36775,{})))
          assert(rooms[36703].special["enter fishtank"]==36775)
          assert(mapper.specialLearned==1 and clearedSpecial==0)
          local owned=yajl.to_value(rooms[36703].data["aardwolf-vibe:special-exits"])
          local learned=yajl.to_value(rooms[36703].data["aardwolf-vibe:learned-special-exits"])
          assert(owned["enter fishtank"]==36775 and learned["enter fishtank"]==36775)

          -- A normal GMCP refresh omits custom exits. That omission must not
          -- erase a transition that the mapper observed directly, even after
          -- the package-owned mapper object is recreated.
          mapper:stop()
          mapper=factory.new(_G,settings);assert(mapper:start())
          assert(mapper:receive(packet(36703,{})))
          assert(rooms[36703].special["enter fishtank"]==36775)
          assert(clearedSpecial==0)
        ''')

    def test_learned_special_exit_retargets_with_per_command_removal(self):
        self.check('''
          assert(mapper:receive(packet(100,{})))
          fire("sysDataSendRequest","open gate")
          assert(mapper:receive(packet(101,{})))
          assert(rooms[100].special["open gate"]==101)
          assert(mapper:receive(packet(100,{})))
          fire("sysDataSendRequest","open gate")
          assert(mapper:receive(packet(102,{})))
          assert(rooms[100].special["open gate"]==102)
          assert(#removedSpecial==1 and removedSpecial[1].from==100)
          assert(removedSpecial[1].command=="open gate")
          assert(mapper.specialLearned==2 and clearedSpecial==0)
        ''')

    def test_standard_and_stale_outgoing_commands_are_not_special_exits(self):
        self.check('''
          assert(mapper:receive(packet(100,{e=101})))
          fire("sysDataSendRequest","east")
          assert(mapper:receive(packet(101,{w=100})))
          assert(next(rooms[100].special)==nil)

          fire("sysDataSendRequest","look statue")
          assert(mapper:receive(packet(101,{w=100})))
          assert(mapper:receive(packet(100,{e=101})))
          assert(next(rooms[101].special)==nil)

          fire("sysDataSendRequest","north")
          assert(mapper:receive(packet(103,{})))
          assert(next(rooms[100].special)==nil and mapper.specialLearned==0)
          assert(clearedSpecial==0)
        ''')

    def test_learned_special_exit_preserves_foreign_command_and_resets_on_disconnect(self):
        self.check('''
          assert(mapper:receive(packet(100,{})))
          addRoom(101);addSpecialExit(100,101,"enter arch")
          fire("sysDataSendRequest","enter arch")
          assert(mapper:receive(packet(102,{})))
          assert(rooms[100].special["enter arch"]==101 and mapper.conflicts==1)

          fire("sysDataSendRequest","climb rope")
          fire("sysDisconnectionEvent")
          assert(mapper:receive(packet(103,{})))
          assert(rooms[102].special["climb rope"]==nil)
          assert(clearedSpecial==0)
        ''')

    def test_maze_destination_becomes_stub_and_no_reverse_exit_is_invented(self):
        self.check('''
          assert(mapper:receive(packet(101,{n="?",w=102})))
          assert(rooms[101].stubs.north and rooms[101].exits.west==102)
          assert(rooms[102].exits.east==nil)
        ''')

    def test_closed_doors_require_matching_room_display_and_valid_exits(self):
        self.check('''
          assert(mapper:receive(packet(101,{n=102,e=103,u=104})))
          incoming('[ Exits: (north) (east) (up) ]')
          incoming('Another Room')
          incoming('[ Exits: (north) (east) ]')
          assert(next(getDoors(101))==nil)
          incoming('Room 101')
          incoming('[ Exits: (north) (east) (up) ]')
          assert(getDoors(101).n==2 and getDoors(101).e==2)
          assert(getDoors(101).u==nil and next(getDoors(102))==nil)
          assert(rooms[101].data['aardwolf-vibe:door:n']=='2')
          assert(rooms[101].data['aardwolf-vibe:door:e']=='2')
          local before=writes
          assert(mapper:receive(packet(101,{n=102,e=103,u=104})))
          incoming('Room 101');incoming('[ Exits: north east up ]')
          assert(getDoors(101).n==2 and writes>=before)
          assert(mapper:receive(packet(101,{n=102,e=103,u=104})))
          before=writes
          incoming('Room 101');incoming('[ Exits: (north) mystery ]')
          assert(writes==before and getDoors(101).n==2)
        ''')

    def test_door_stub_manual_ownership_and_confirmed_exit_removal(self):
        self.check('''
          assert(mapper:receive(packet(101,{n='?',e=102})))
          setDoor(101,'e',3)
          incoming('Room 101');incoming('[ Exits: (north) (east) ]')
          assert(getDoors(101).n==2 and getDoors(101).e==3)
          assert(rooms[101].data['aardwolf-vibe:door:n']=='2')
          assert(rooms[101].data['aardwolf-vibe:door:e']==nil)
          setDoor(101,'n',1)
          assert(mapper:receive(packet(101,{n='?',e=102})))
          assert(rooms[101].data['aardwolf-vibe:door:n']=='manual')
          incoming('Room 101');incoming('[ Exits: (north) ]')
          assert(getDoors(101).n==1)
          assert(mapper:receive(packet(101,{s='?'})))
          incoming('Room 101');incoming('[ Exits: (south) ]')
          assert(getDoors(101).s==2)
          mapper:stop();mapper=factory.new(_G,settings);assert(mapper:start())
          assert(mapper:receive(packet(101,{})))
          assert(getDoors(101).s==nil and rooms[101].data['aardwolf-vibe:door:s']=='')
          assert(getDoors(101).n==1 and getDoors(101).e==3)
        ''')

    def test_door_observation_expiry_stale_lines_and_nonfatal_failure(self):
        self.check('''
          assert(mapper:receive(packet(101,{n=102})))
          incoming('Room 101');advance(5)
          incoming('[ Exits: (north) ]')
          assert(next(getDoors(101))==nil)
          assert(mapper:receive(packet(102,{n=103})))
          incoming('[ Exits: (north) ]')
          assert(next(getDoors(102))==nil)
          assert(mapper:receive(packet(101,{n=102})))
          incoming('Room 101');fire('sysDataSendRequest','north')
          incoming('[ Exits: (north) ]')
          assert(next(getDoors(101))==nil)
          assert(mapper:receive(packet(101,{n=102})))
          incoming('Room 101');fail.setDoor=true
          incoming('[ Exits: (north) ]')
          assert(mapper.enabled and mapper.failed==1 and getDoors(101).n==nil)
          assert(echoes[#echoes]:find('Door observation failed:',1,true))
          assert(rooms[101].data['aardwolf-vibe:door:n']==nil)
          assert(mapper:receive(packet(101,{n=102})))
          incoming('Room 101');fire('sysDisconnectionEvent')
          incoming('[ Exits: (north) ]')
          assert(next(getDoors(101))==nil)
          mapper:stop()
          assert(next(triggers)==nil and next(timers)==nil)
        ''')

    def test_manual_door_removal_is_not_reclaimed(self):
        self.check('''
          assert(mapper:receive(packet(101,{w=102})))
          incoming('Room 101');incoming('[ Exits: (west) ]')
          assert(getDoors(101).w==2)
          setDoor(101,'w',0)
          assert(mapper:receive(packet(101,{w=102})))
          assert(rooms[101].data['aardwolf-vibe:door:w']=='manual')
          incoming('Room 101');incoming('[ Exits: (west) ]')
          assert(getDoors(101).w==nil)
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
          local count=0;for _ in pairs(handlers) do count=count+1 end;assert(count==5)
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
