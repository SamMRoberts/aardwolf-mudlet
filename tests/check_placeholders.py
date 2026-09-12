"""Unexplored rooms against the built mapper and its native API contract."""
import unittest
import check_mapper


class PlaceholderTests(unittest.TestCase):
    setUp = check_mapper.MapperTests.setUp
    check = check_mapper.MapperTests.check

    def test_six_neighbors_are_identity_bound_and_only_one_hop(self):
        self.check('''
          packet(101,{n=102,e=103,s=104,w=105,u=106,d=107})
          assert(mapper.enabled and count(rooms)==7 and mapper.placeholders==6)
          for _,v in ipairs({{102,0,2,0},{103,2,0,0},{104,0,-2,0},
              {105,-2,0,0},{106,0,0,1},{107,0,0,-1}}) do
            local id=localID(v[1]); local r=rooms[id]
            assert(r.x==v[2] and r.y==v[3] and r.z==v[4])
            assert(r.name=='' and r.symbol=='?' and next(r.exits)==nil)
            assert(r.data['AardwolfToolbox:discovery']=='unexplored')
            assert(r.data['AardwolfToolbox:ready']=='1')
            assert(r.data['AardwolfToolbox:zone']==nil and r.data['AardwolfToolbox:terrain']==nil)
            assert(environmentColors[getRoomEnv(id)][1]==145)
          end
          packet(101,{n=102,e=103,s=104,w=105,u=106,d=107})
          assert(count(rooms)==7 and mapper.placeholders==6 and centered==localID(101))
        ''')

    def test_mixed_shared_destinations_self_loop_and_promotion(self):
        self.check('''
          packet(101,{n=102}); packet(102,{s=101,e=103})
          local id=localID(103)
          packet(101,{n=102,e=103,w=101})
          assert(count(rooms)==3 and rooms[localID(101)].exits.west==localID(101))
          assert(rooms[localID(101)].exits.east==id and rooms[localID(102)].exits.east==id)
          packet(103,{})
          assert(localID(103)==id and rooms[id].name~='' and rooms[id].symbol=='')
          assert(next(rooms[id].exits)==nil and mapper.promoted==2)
          assert(getRoomEnv(id)==-1)
        ''')

    def test_unknown_and_collision_stubs_preserve_z(self):
        self.check('''
          packet(101,{n=102,u=103}); packet(101,{n=104,u=105,w=-1,d='?'})
          assert(localID(104)==-1 and localID(105)==-1 and count(rooms)==3)
          local r=rooms[localID(101)]
          assert(r.stubs.north and r.stubs.up and r.stubs.west and r.stubs.down)
          assert(not r.exits.north and not r.exits.up)
          assert(rooms[localID(102)].z==0 and rooms[localID(103)].z==1)
          assert(mapper.stubs==4 and mapper.deferred==2)
          packet(101,{})
          assert(next(r.stubs)==nil and count(rooms)==3)
        ''')

    def test_owned_stubs_resolve_and_manual_stubs_are_preserved(self):
        self.check('''
          packet(101,{n=-1}); packet(101,{n=102})
          local r=rooms[localID(101)]
          assert(not r.stubs.north and r.exits.north==localID(102))
          setExitStub(localID(101),'e',true)
          packet(101,{n=102,e=103})
          assert(r.stubs.east and not r.exits.east and localID(103)==-1)
          packet(101,{n=102,w=-1}); setExitStub(localID(101),'w',false)
          packet(101,{n=102,w=104})
          assert(not r.stubs.west and not r.exits.west and localID(104)==-1)
          assert(mapper.conflicts>=2)
        ''')

    def test_unknown_destination_clears_old_owned_link_without_recreating_it(self):
        self.check('''
          packet(101,{e=102}); local from=localID(101); local to=localID(102)
          packet(101,{e=-1})
          assert(not rooms[from].exits.east and rooms[from].stubs.east)
          assert(rooms[from].data['AardwolfToolbox:linked:e']=='')
          mapper.stop(); mapper=factory.new(_G); mapper.start(); packet(102,{})
          assert(not rooms[from].exits.east and rooms[from].stubs.east)
          packet(101,{e=102}); assert(rooms[from].exits.east==to)
          mapper.stop(); mapper=factory.new(_G,function(key) return key~='unexplored_rooms' end); mapper.start()
          packet(101,{e='?'})
          assert(not rooms[from].exits.east and not rooms[from].stubs.east)
          packet(101,{e=102}); rooms[from].exits.east=from
          packet(101,{e=-1}); assert(rooms[from].exits.east==from and mapper.conflicts>0)
        ''')

    def test_reported_exit_uses_identity_even_when_destination_is_offset(self):
        self.check('''
          packet(15490,{})
          local hut=localID(15490); setRoomCoordinates(hut,0,2,0)
          packet(15516,{e=15490})
          local shore=localID(15516); setRoomCoordinates(shore,-2,4,0)
          packet(15516,{e=15490})
          assert(rooms[shore].exits.east==hut and not rooms[shore].exits.south)
          assert(rooms[hut].x==0 and rooms[hut].y==2 and count(rooms)==2)
        ''')

    def test_incoming_link_resolves_owned_stub_after_restart(self):
        self.check('''
          packet(101,{n=102}); packet(101,{n=103})
          local origin=localID(101); assert(rooms[origin].stubs.north)
          mapper.stop(); mapper=factory.new(_G); mapper.start()
          packet(103)
          assert(rooms[origin].exits.north==localID(103) and not rooms[origin].stubs.north)
        ''')

    def test_foreign_identity_skipped_without_blocking_other_exits(self):
        self.check('''
          addRoom(102); rooms[102].name='foreign'
          addRoom(500); setRoomIDbyHash(500,'AardwolfToolbox:aardwolf:vnum:103')
          packet(101,{n=102,e=103,s=104})
          assert(mapper.enabled and mapper.conflicts==2 and mapper.placeholders==1)
          assert(rooms[102].name=='foreign' and rooms[500].data['AardwolfToolbox:owner']==nil)
          assert(rooms[localID(101)].exits.south==localID(104))
        ''')

    def test_cross_area_and_continent_promotion(self):
        self.check('''
          packet(101,{e=102},'inside'); local id=localID(102)
          packet(102,{},'world',{cont=1,id=0,x=37,y=19})
          assert(localID(102)==id and rooms[id].area==areas.world)
          assert(rooms[id].x==37 and rooms[id].y==-19 and rooms[id].z==0)
          packet(102,{n=103},'world',{cont=1,id=0,x=37,y=19})
          assert(rooms[localID(103)].y==-18)
          packet(103,{},'cave')
          assert(rooms[localID(103)].area==areas.cave and rooms[localID(103)].z==0)
          assert(rooms[localID(101)].exits.east==id)
        ''')

    def test_confirmed_position_collision_retains_provisional_position(self):
        self.check('''
          packet(101,{e=102},'world',{cont=1,id=0,x=37,y=19})
          packet(103,{},'world',{cont=1,id=0,x=50,y=50})
          local id=localID(102)
          packet(102,{},'world',{cont=1,id=0,x=50,y=50})
          assert(rooms[id].x==38 and rooms[id].y==-19 and rooms[id].name~='')
          assert(mapper.conflicts==1)
        ''')

    def test_manual_placeholder_fields_and_zero_color_are_preserved(self):
        self.check('''
          packet(101,{e=102}); local id=localID(102)
          local r=rooms[id]; r.name='My note'; r.symbol='!'; r.x=77
          setRoomEnv(id,0); r.data.note='keep'
          terrainPacket(102,'forest')
          assert(r.name=='My note' and r.symbol=='!' and r.x==77 and getRoomEnv(id)==0)
          assert(r.data.note=='keep' and r.data['AardwolfToolbox:terrain']=='forest')
          assert(mapper.promoted==1 and mapper.conflicts==1)
          terrainPacket(102,'water'); assert(getRoomEnv(id)==0)
        ''')

    def test_manual_area_retained(self):
        self.check('''
          packet(101,{e=102}); local id=localID(102)
          local area=addAreaName('my area'); setRoomArea(id,area)
          packet(102,{},'world',{cont=1,id=0,x=50,y=50})
          assert(rooms[id].area==area and rooms[id].x==2 and rooms[id].y==0)
          assert(mapper.promoted==1 and mapper.conflicts>=1)
        ''')

    def test_settings_off_retains_and_promotes_without_new_objects(self):
        self.check('''
          packet(101,{n=102,e=-1}); local id=localID(102)
          mapper.stop(); mapper=factory.new(_G,function(key)
            return key~='unexplored_rooms' and key~='terrain_colors' and key~='follow_room'
          end); mapper.start()
          local before=writes; fire('gmcp.room.info'); assert(writes==before)
          packet(101,{n=102,e=-1,w=103})
          assert(count(rooms)==2 and rooms[localID(101)].stubs.east)
          terrainPacket(102,'forest'); assert(getRoomEnv(id)==-1)
          assert(rooms[id].symbol=='' and mapper.promoted==1)
          assert(rooms[id].data['AardwolfToolbox:terrain']=='forest')
        ''')

    def test_promotion_uses_terrain_when_enabled(self):
        self.check('''
          packet(101,{n=102}); local id=localID(102); local gray=getRoomEnv(id)
          terrainPacket(102,'forest')
          assert(getRoomEnv(id)~=gray and environmentColors[getRoomEnv(id)][2]==139)
        ''')

    def test_failures_do_not_duplicate_partial_rooms_or_claim_stub_success(self):
        self.check('''
          packet(101); failNext('setRoomChar'); packet(101,{n=102})
          assert(not mapper.enabled and count(rooms)==2 and mapper.placeholders==0)
          local id=localID(102); assert(rooms[id].data['AardwolfToolbox:ready']~='1')
          mapper.start(); packet(101,{n=102,e=103})
          assert(mapper.enabled and count(rooms)==3 and mapper.conflicts==1)
          packet(102); assert(not mapper.enabled and count(rooms)==3)
          mapper.start(); failNext('setExitStub'); packet(101,{w=-1})
          assert(not mapper.enabled and mapper.stubs==0)
        ''')

    def test_failed_promotion_remains_incomplete(self):
        self.check('''
          packet(101,{n=102}); local id=localID(102)
          failNext('setRoomName'); packet(102)
          assert(not mapper.enabled and mapper.promoted==0)
          assert(rooms[id].data['AardwolfToolbox:ready']=='0')
          mapper.start(); packet(102)
          assert(not mapper.enabled and localID(102)==id and mapper.promoted==0)
        ''')

    def test_legacy_rooms_remain_visited_and_edits_survive(self):
        self.check('''
          packet(101); local r=rooms[localID(101)]
          r.data['AardwolfToolbox:discovery']=nil; r.name='Legacy note'; r.symbol='!'
          mapper.stop(); mapper=factory.new(_G); mapper.start(); packet(101,{n=102})
          assert(r.name=='Legacy note' and r.symbol=='!' and mapper.promoted==0)
          assert(mapper.placeholders==1)
        ''')

    def test_manually_renamed_area_is_not_replaced_during_promotion(self):
        self.check('''
          packet(101,{e=102},'academy'); local id=localID(102)
          local area=rooms[id].area; setAreaName(area,'My academy')
          packet(102,{},'academy')
          assert(rooms[id].area==area and areas['My academy']==area and not areas.academy)
          assert(mapper.promoted==1 and mapper.conflicts==1)
        ''')
