"""Map speedwalk adapter contracts; command dispatch is intercepted."""
import unittest
import zipfile
import check_mapper


class MapTravelTests(unittest.TestCase):
    def setUp(self):
        check_mapper.MapperTests.setUp(self)
        with zipfile.ZipFile(check_mapper.ROOT / 'build/AardwolfToolbox.mpackage') as z:
            self.lua.globals().Travel=self.lua.execute(z.read('map-travel.lua').decode())
        self.lua.execute('''
          packet(101,{n=102});packet(102,{n=103});packet(103,{e=104});packet(104,{})
          values={['room.info.num']=101,['char.status.state']=3,['char.status.pos']='Standing'}
          cache={enabled=true,get=function(path) return values[path] end}
          connected=true;sent={};mudlet={};oldCalled=0
          function getConnectionInfo() return 'test',0,connected end
          function send(command) sent[#sent+1]=command;return true end
          function oldHook() oldCalled=oldCalled+1 end
          doSpeedWalk=oldHook
          function getPath(from,to)
            pathFrom,pathTo=from,to
            speedWalkDir={'n','n','e'};speedWalkPath={102,103,104};return true,3
          end
          travel=Travel.new(_G,cache);assert(travel.start())
          speedWalkFrom=999;speedWalkTo=104
        ''')

    def test_native_hook_compresses_path_from_fresh_room(self):
        self.lua.execute('''
          assert(mudlet.custom_speedwalk and mudlet.mapper_script)
          assert(doSpeedWalk())
          assert(#sent==1 and sent[1]=='run 2ne' and pathFrom==101 and pathTo==104)
          assert(oldCalled==0)
          local n=#sent;assert(travel.runTo(101));assert(#sent==n)
        ''')

    def test_native_up_down_and_string_room_ids(self):
        self.lua.execute('''
          rooms[101].exits={up=102};rooms[102].exits={down=103};rooms[103].exits={west=104}
          getPath=function()
            speedWalkDir={'up','down','w'};speedWalkPath={'102','103','104'};return true,3
          end
          assert(doSpeedWalk() and sent[1]=='run udw')
        ''')

    def test_readiness_identity_and_path_failures_send_nothing(self):
        self.lua.execute('''
          connected=false;assert(not doSpeedWalk());connected=true
          cache.enabled=false;assert(not doSpeedWalk());cache.enabled=true
          values['room.info.num']=nil;assert(not doSpeedWalk());values['room.info.num']=101
          for _,state in ipairs({1,2,4,5,6,7,8,9,11}) do
            values['char.status.state']=state;assert(not doSpeedWalk())
          end
          values['char.status.state']=3;values['char.status.pos']='Resting';assert(not doSpeedWalk())
          values['char.status.pos']='Standing'
          addRoom(999);assert(not travel.runTo(999));assert(not travel.runTo('104;kill'))
          getPath=function() return false,-1 end;assert(not doSpeedWalk())
          assert(#sent==0)
        ''')

    def test_custom_exits_mismatched_routes_and_room_changes_are_not_run(self):
        self.lua.execute('''
          local original=getPath
          getPath=function(a,b) original(a,b);speedWalkDir[2]='enter hole';return true end
          assert(not doSpeedWalk() and travel.last:find('custom exit'))
          getPath=function(a,b) original(a,b);speedWalkPath[2]=101;return true end
          assert(not doSpeedWalk())
          getPath=function(a,b) original(a,b);values['room.info.num']=102;return true end
          assert(not doSpeedWalk())
          assert(#sent==0)
        ''')

    def test_lifecycle_restores_owned_globals_and_preserves_later_replacement(self):
        self.lua.execute('''
          local hook=doSpeedWalk;travel.start();assert(doSpeedWalk==hook)
          travel.configure(false);assert(doSpeedWalk==oldHook)
          assert(mudlet.custom_speedwalk==nil and mudlet.mapper_script==nil)
          hook();assert(#sent==0)
          travel.start();local replacement=function() end;doSpeedWalk=replacement
          mudlet.custom_speedwalk=false;travel.stop()
          assert(doSpeedWalk==replacement and mudlet.custom_speedwalk==false)
        ''')

    def test_send_failure_and_activation_failure(self):
        self.lua.execute('''
          send=function() return nil,'transport failed' end
          assert(not doSpeedWalk() and travel.last:find('transport failed'))
          travel.stop();getPath=nil
          assert(not travel.start() and not travel.enabled and doSpeedWalk==oldHook)
        ''')
