"""Authoritative GMCP and native JSON ID migration contracts; no live Mudlet IO."""
import unittest
import zipfile
import check_mapper


class AuthorityTests(unittest.TestCase):
    setUp = check_mapper.MapperTests.setUp
    check = check_mapper.MapperTests.check

    def test_game_ids_and_reported_fields_replace_stale_map_values(self):
        self.check('''
          packet(1400,{e=1023}); assert(localID(1400)==1400 and localID(1023)==1023)
          assert(rooms[1400].exits.east==1023)
          rooms[1400].name='Old title'; rooms[1400].data.note='keep'; rooms[1400].symbol='!'
          rooms[1400].exits.east=1400; rooms[1400].exits.south=1023
          gmcp.room.info={num=1400,name='New café <room>',zone='newzone',terrain='shop',details='',
            outside=0,racebonus=1,mapterrain='city',exits={e=1024,n=-1},coord={cont=1,id=0,x=40,y=32,z=2}}
          fire('gmcp.room.info')
          assert(mapper.enabled and rooms[1400].name=='New café <room>')
          assert(rooms[1400].area==areas.newzone and rooms[1400].x==40 and rooms[1400].y==-32 and rooms[1400].z==2)
          assert(rooms[1400].exits.east==1024 and not rooms[1400].exits.south and rooms[1400].stubs.north)
          assert(environmentColors[getRoomEnv(1400)][1]==255)
          assert(rooms[1400].symbol=='!' and rooms[1400].data.note=='keep')
          local raw=yajl.to_value(rooms[1400].data['AardwolfToolbox:gmcp'])
          assert(raw.num==1400 and raw.exits.e==1024 and raw.coord.y==32 and raw.details=='')
          assert(rooms[1400].data['AardwolfToolbox:details']=='' and rooms[1400].data['AardwolfToolbox:gmcp:outside']=='0')
          assert(rooms[1400].data['AardwolfToolbox:coord:z']=='2')
        ''')

    def test_indoor_world_coordinates_are_recorded_without_collapsing_rooms(self):
        self.check('''
          packet(101,{e=102},'inside',{cont=0,id=2,x=40,y=30})
          packet(102,{},'inside',{cont=0,id=2,x=40,y=30})
          assert(rooms[101].x==0 and rooms[102].x==2 and rooms[102].z==0)
          assert(rooms[102].data['AardwolfToolbox:coord:x']=='40')
          gmcp.room.info={num=102,name='Room 102',zone='inside',exits={},details='New details'}; fire('gmcp.room.info')
          gmcp.room.info={num=102,name='Room 102',zone='inside',exits={},details=''}; fire('gmcp.room.info')
          assert(rooms[102].data['AardwolfToolbox:details']=='')
        ''')

    def test_invalid_packets_leave_map_unchanged_and_custom_exits_survive(self):
        self.check('''
          packet(101,{e=102}); rooms[101].exits.northeast=102
          packet(101,{}); assert(rooms[101].exits.northeast==102)
          local before=writes
          gmcp.room.info={num=101,name='Bad',zone='test',exits={},details=string.rep('x',65537)}
          fire('gmcp.room.info'); assert(writes==before)
          gmcp.room.info={num=101,name='Bad',zone='test',exits={},coord={cont=1,id=0,x=1,y=2,z=0/0}}
          fire('gmcp.room.info'); assert(writes==before)
        ''')


class MigrationTests(unittest.TestCase):
    def setUp(self):
        check_mapper.MapperTests.setUp(self)
        with zipfile.ZipFile(check_mapper.ROOT / 'build/AardwolfToolbox.mpackage') as archive:
            self.lua.globals().Identity = self.lua.execute(archive.read('mapper-identity.lua').decode())
        self.lua.execute('''
          K='AardwolfToolbox:'; O='AardwolfToolbox.mapper'; H=K..'aardwolf:vnum:'
          local a=addAreaName('test'); setAreaUserData(a,K..'owner',O)
          function legacy(id,num)
            addRoom(id);setRoomName(id,'Room '..num);setRoomArea(id,a)
            setRoomUserData(id,K..'owner',O);setRoomUserData(id,K..'vnum',tostring(num))
            setRoomUserData(id,K..'ready','1');setRoomIDbyHash(id,H..num)
          end
          function document()
            local result={formatVersion=1,areas={{id=a,name='test',rooms={},labels={{id=1,text='Keep label'}}}},
              roomCount=count(rooms),areaCount=1,labelCount=1,playersRoomId={test=1},userData={keep='metadata'},
              customEnvColors={{id=1000,colorRGBA={1,2,3,255}}}}
            for id,r in pairs(rooms) do
              local exits={}; for name,target in pairs(r.exits) do exits[#exits+1]={name=name,exitId=target,weight=2,door='closed'} end
              for name,target in pairs(r.specials or {}) do exits[#exits+1]={name=name,exitId=target,locked=true} end
              result.areas[1].rooms[#result.areas[1].rooms+1]={id=id,name=r.name,hash=r.hash,
                coordinates={r.x,r.y,r.z},userData=r.data,exits=exits,environment=getRoomEnv(id),
                symbol={text='!'},locked=true,hidden=true,weight=3}
            end
            return yajl.to_value(yajl.to_string(result))
          end
          function getSpecialExitsSwap(id) return rooms[id].specials or {} end
          files={}; nativeLoads=0; restored=0
          function applyDocument(doc)
            rooms={};hashes={}
            for _,area in ipairs(doc.areas) do for _,r in ipairs(area.rooms) do
              addRoom(r.id);setRoomName(r.id,r.name or '');setRoomArea(r.id,area.id)
              setRoomCoordinates(r.id,unpack(r.coordinates));rooms[r.id].data=r.userData or {}
              if r.hash then setRoomIDbyHash(r.id,r.hash) end
              for _,e in ipairs(r.exits or {}) do
                if e.name=='enter hole' then rooms[r.id].specials={['enter hole']=e.exitId}
                else rooms[r.id].exits[e.name]=e.exitId end
              end
            end end
          end
          io.open=function(path,mode)
            if mode=='rb' and not files[path] or mode=='wb' and writeFailure then return nil,'failed' end
            return {read=function(_,n) return files[path]:sub(1,n) end,
              write=function(_,s) if shortWrite then files[path]=s:sub(1,10) else files[path]=s end;return true end,
              flush=function() return not flushFailure end,close=function() return true end}
          end
          function saveJsonMap(path)
            if exportFailure then return nil,'export failed' end
            files[path]=yajl.to_string(document()); return true
          end
          function loadJsonMap(path)
            nativeLoads=nativeLoads+1
            if importFailure then return nil,'failed' end
            applyDocument(yajl.to_value(files[path]))
            if corruptImport then rooms[101].name='Corrupted' end
            return true
          end
          function loadMap() restored=restored+1;applyDocument(original); return true end
          function prepare()
            legacy(1,101);legacy(2,102)
            rooms[1].exits.east=2;rooms[2].specials={['enter hole']=1}
            rooms[1].data[K..'linked:e']='2';rooms[1].data.note='Do not modify 2'
            original=document()
          end
        ''')

    def test_migration_rewrites_links_and_preserves_native_fields(self):
        self.lua.execute('''
          prepare(); local doc=document(); local mapping=Identity.plan(_G)
          Identity.remap(doc,mapping)
          assert(doc.playersRoomId.test==101 and doc.areas[1].labels[1].text=='Keep label')
          assert(doc.userData.keep=='metadata' and doc.customEnvColors[1].id==1000)
          for _,r in ipairs(doc.areas[1].rooms) do
            assert(r.locked and r.hidden and r.weight==3 and r.symbol.text=='!')
            if r.id==101 then assert(r.exits[1].exitId==102 and r.userData[K..'linked:e']=='102')
              assert(r.userData.note=='Do not modify 2')
            else assert(r.id==102 and r.exits[1].exitId==101 and r.exits[1].locked) end
          end
          assert(Identity.run(_G,'/backup.dat')==2 and nativeLoads==1)
          assert(localID(101)==101 and localID(102)==102 and count(rooms)==2)
          assert(rooms[101].exits.east==102 and rooms[102].specials['enter hole']==101)
          assert(Identity.run(_G,'/backup.dat')==0 and nativeLoads==1)
        ''')

    def test_cycles_foreign_incoming_exits_and_collisions(self):
        self.lua.execute('''
          legacy(1,2);legacy(2,1);addRoom(3);setRoomName(3,'Foreign');setRoomArea(3,areas.test)
          rooms[3].exits.east=1; rooms[3].specials={['enter hole']=2}
          local doc=document();Identity.remap(doc,Identity.plan(_G))
          for _,r in ipairs(doc.areas[1].rooms) do if r.id==3 then
            assert(r.name=='Foreign' and not r.hash and not r.userData[K..'owner'])
            for _,e in ipairs(r.exits) do assert(e.exitId==(e.name=='east' and 2 or 1)) end
          end end
          rooms[1].data[K..'vnum']='3'
          assert(not pcall(Identity.plan,_G)) -- conflicting identity is never seized
        ''')

    def test_foreign_id_and_partial_identity_fail_before_import(self):
        self.lua.execute('''
          prepare();addRoom(101);rooms[101].name='Foreign'
          local ok,err=pcall(Identity.run,_G,'/backup.dat')
          assert(not ok and err:find('occupied') and nativeLoads==0 and rooms[101].name=='Foreign')
          rooms[101]=nil; rooms[1].data[K..'ready']='0'
          assert(not pcall(Identity.run,_G,'/backup.dat') and nativeLoads==0)
          rooms[1].data[K..'ready']='1'; rooms[1].exits.west=999
          assert(not pcall(Identity.run,_G,'/backup.dat') and nativeLoads==0)
        ''')

    def test_export_write_import_and_readback_failures(self):
        self.lua.execute('''
          prepare(); exportFailure=true
          assert(not pcall(Identity.run,_G,'/backup.dat') and nativeLoads==0);exportFailure=nil
          writeFailure=true; assert(not pcall(Identity.run,_G,'/backup.dat'));writeFailure=nil
          shortWrite=true; assert(not pcall(Identity.run,_G,'/backup.dat'));shortWrite=nil
          flushFailure=true; assert(not pcall(Identity.run,_G,'/backup.dat'));flushFailure=nil
          assert(nativeLoads==0 and localID(101)==1)
          importFailure=true; assert(not pcall(Identity.run,_G,'/backup.dat'))
          assert(restored==1 and localID(101)==1);importFailure=nil
          corruptImport=true;assert(not pcall(Identity.run,_G,'/backup.dat'))
          assert(restored==2 and localID(101)==1 and rooms[1].name=='Room 101')
        ''')

    def test_mapper_migrates_before_applying_fresh_room(self):
        self.lua.execute('''
          prepare();mapper.stop();mapper=factory.new(_G,nil,Identity);mapper.start()
          packet(101,{e=102})
          assert(mapper.enabled and mapper.migrated==2 and localID(101)==101)
          assert(centered==101 and backupCount==1 and rooms[101].exits.east==102)
          mapper.stop();mapper.start();packet(101,{e=102})
          assert(mapper.migrated==2 and nativeLoads==1)
        ''')
