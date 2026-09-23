from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
API = (ROOT / "tests/navigation_api.lua").read_text()
SOURCE = (ROOT / "src/resources/map-navigation.lua").read_text()


class MapNavigationTests(unittest.TestCase):
    def runtime(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(API)
        lua.globals().MapNavigation = lua.execute(SOURCE)
        lua.execute("navigation=MapNavigation.new(_G);assert(navigation:start())")
        return lua

    def test_run_uses_fresh_gmcp_origin_and_compresses_directions(self):
        lua = self.runtime()
        lua.execute('''
          pathDirections={"north","n","east"};pathRooms={101,102,103}
          room(100)
          playerMarker=999 -- map centering may change this independently
          gotoRoom(103)
          assert(pathCalls[1].from==100 and pathCalls[1].to==103)
          assert(commands[1]=="run 2ne" and #commands==1)
          assert(timers[1].delay==36)
          room(101);assert(navigation:status().running)
          room(102);assert(navigation:status().running)
          room(103);assert(not navigation:status().running)
          assert(next(timers)==nil)
        ''')

    def test_long_run_splits_at_command_bound_and_waits_between_parts(self):
        lua = self.runtime()
        lua.execute('''
          for index=1,240 do
            pathDirections[index]=index%2==1 and "n" or "e"
            pathRooms[index]=100+index
          end
          room(100);gotoRoom(340)
          assert(#commands==1 and #commands[1]<=200)
          -- The first bounded run contains 196 single-step directions.
          assert(commands[1]=="run "..string.rep("ne",98))
          assert(timers[1].delay==30+2*196)
          room(296)
          assert(#commands==2 and #commands[2]<=200)
          assert(timers[2].delay==30+2*44)
          room(340)
          assert(not navigation:status().running)
        ''')

    def test_special_exit_is_sent_between_confirmed_run_segments(self):
        lua = self.runtime()
        lua.execute('''
          pathDirections={"n","north","enter portal","east"}
          pathRooms={101,102,200,201}
          specialExits[102]={['enter portal']=200}
          room(100);gotoRoom(201)
          assert(commands[1]=="run 2n" and #commands==1)
          fire("sysDataSendRequest","look")
          room(101);assert(#commands==1)
          room(102);assert(commands[2]=="enter portal" and #commands==2)
          room(200);assert(commands[3]=="run e" and #commands==3)
          room(201);assert(not navigation:status().running)
        ''')

    def test_unexpected_room_stops_remaining_segments(self):
        lua = self.runtime()
        lua.execute('''
          pathDirections={"n","enter portal","e"};pathRooms={101,200,201}
          specialExits[101]={['enter portal']=200}
          room(100);gotoRoom(201)
          room(999)
          assert(#commands==1 and not navigation:status().running)
          assert(navigation:status().current==999)
          assert(navigation:status().lastError:find("left the planned route",1,true))
          room(101);assert(#commands==1)
        ''')

    def test_busy_request_is_ignored_and_timer_stops_route(self):
        lua = self.runtime()
        lua.execute('''
          pathDirections={"n"};pathRooms={101}
          room(100);gotoRoom(101)
          gotoRoom(101)
          assert(#commands==1 and #pathCalls==1)
          fireTimer(1)
          assert(not navigation:status().running)
          assert(navigation:status().lastError:find("timed out",1,true))
        ''')

    def test_unreachable_and_invalid_routes_send_nothing(self):
        lua = self.runtime()
        lua.execute('''
          room(100)
          pathFound=false;gotoRoom(101);assert(#commands==0)
          pathFound=true
          pathDirections={"n","enter\\nportal"};pathRooms={101,200}
          gotoRoom(200);assert(#commands==0)
          pathDirections={"n","ne"};pathRooms={101,200}
          gotoRoom(200);assert(#commands==0)
          assert(navigation:status().lastError:find("unverified special exit",1,true))
          pathDirections={"n"};pathRooms={101}
          gotoRoom(200);assert(#commands==0)
          gotoRoom(100);assert(#commands==0)
        ''')

    def test_disconnect_reconnect_and_protocol_loss_require_fresh_room(self):
        lua = self.runtime()
        lua.execute('''
          pathDirections={"n","enter portal"};pathRooms={101,200}
          specialExits[101]={['enter portal']=200}
          gotoRoom(200);assert(#commands==0)
          room(100);gotoRoom(200);assert(#commands==1)
          fire("sysDisconnectionEvent")
          assert(navigation:status().current==nil and not navigation:status().running)
          fire("sysConnectionEvent")
          gotoRoom(200);assert(#commands==1)
          room(100);gotoRoom(200);assert(#commands==2)
          fire("sysProtocolDisabled","GMCP")
          assert(navigation:status().current==nil and not navigation:status().running)
          gotoRoom(200);assert(#commands==2)
        ''')

    def test_send_failure_and_invalid_room_abort_route(self):
        lua = self.runtime()
        lua.execute('''
          pathDirections={"n","e"};pathRooms={101,102}
          room(100);failSend=true;gotoRoom(102)
          assert(not navigation:status().running and next(timers)==nil)
          failSend=false;gotoRoom(102)
          room("invalid")
          assert(navigation:status().current==nil and not navigation:status().running)
        ''')

    def test_callback_lifecycle_and_foreign_owner(self):
        lua = self.runtime()
        lua.execute('''
          local callback=doSpeedWalk
          assert(mudlet.custom_speedwalk==true and modules["aardwolf-vibe.map-navigation:Room"])
          assert(navigation:start() and doSpeedWalk==callback)
          assert(navigation:stop() and doSpeedWalk==nil and mudlet.custom_speedwalk==nil)
          assert(next(handlers)==nil and next(modules)==nil)
          foreign=function() end
          doSpeedWalk=foreign
          assert(not navigation:start() and doSpeedWalk==foreign)
          doSpeedWalk=nil
          assert(navigation:start())
          doSpeedWalk=foreign
          assert(navigation:stop() and doSpeedWalk==foreign)
        ''')

    def test_subscription_packet_is_fresh_and_partial_start_rolls_back(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(API)
        lua.globals().MapNavigation = lua.execute(SOURCE)
        lua.execute('''
          announceRoom=100
          navigation=MapNavigation.new(_G)
          assert(navigation:start() and navigation:status().current==100)
          assert(navigation:stop())
          failRegistration="disconnect"
          assert(not navigation:start())
          assert(next(handlers)==nil and next(modules)==nil)
          assert(doSpeedWalk==nil and mudlet.custom_speedwalk==nil)
        ''')


if __name__ == "__main__":
    unittest.main()
