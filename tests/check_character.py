from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
API = (ROOT / "tests/character_api.lua").read_text()
SOURCE = (ROOT / "src/resources/character.lua").read_text()


class CharacterTests(unittest.TestCase):
    def runtime(self, start=True):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(API)
        factory = lua.execute(SOURCE)
        lua.globals().factory = factory
        lua.execute("character=factory.new(_G)")
        if start:
            lua.execute("assert(character:start())")
        return lua

    def test_all_groups_and_schema_fields_are_captured(self):
        lua = self.runtime()
        lua.execute('''
          gmcp.char.base={name="Lasher",class="Warrior",subclass="Soldier",race="Elf",
            clan="wolf",pretitle="Testing ",perlevel=1000,tier=1,remorts=7,redos=0,
            classes="0123456",level=210,pups=12345,totpups=23456}
          gmcp.char.vitals={hp=-10,mana=90000,moves=41599}
          gmcp.char.stats={str=251,int=250,wis=250,dex=250,con=250,luck=250,
            hr=-2298,dr=-207,saves=-13}
          gmcp.char.maxstats={maxhp=50099,maxmana=50029,maxmoves=41629,maxstr=51,
            maxint=134,maxwis=50,maxdex=183,maxcon=99,maxluck=200}
          gmcp.char.status={level=210,tnl=1000,hunger=70,thirst=70,align=-1867,
            state=3,pos="Standing",enemy="",enemypct=93}
          gmcp.char.worth={gold=23128310661,bank=750000,qp=5052186,tp=10930,
            trains=6,pracs=14,qpearned=12345678}
          for _,group in ipairs({"base","vitals","stats","maxstats","status","worth"}) do
            fire("gmcp.char."..group,{spoofed=true})
            assert(character:isFresh(group))
          end
          local snapshot=character:snapshot()
          assert(snapshot.groups.base.name=="Lasher" and snapshot.groups.base["class"]=="Warrior")
          assert(snapshot.groups.vitals.hp==-10 and snapshot.groups.stats.saves==-13)
          assert(snapshot.groups.maxstats.maxdex==183 and snapshot.groups.status.align==-1867)
          assert(snapshot.groups.worth.gold==23128310661 and snapshot.sequence==6)
          assert(character:className(0)=="Mage" and character:className(6)=="Psionicist")
          assert(character:className("0")==nil)
          assert(character:stateName(3)=="Player fully active and able to receive MUD commands")
          assert(character:stateName(10)==nil)
          local status=character:status()
          assert(status.enabled and status.lifecycle=="active")
          assert(status.accepted==6 and status.rejected==0)
          assert(#events==12)
        ''')

    def test_event_names_argument_order_and_payload_isolation(self):
        lua = self.runtime()
        lua.execute('''
          eventHooks["aardwolf-vibe.character.updated"]=function(group,normalized,raw)
            assert(group=="vitals");normalized.hp=999;raw.extra.value=999
          end
          gmcp.char.vitals={hp=100,mana=90,moves=80,extra={value=7}}
          fire("gmcp.char.vitals",{hp=1})
          assert(events[1].name=="aardwolf-vibe.character.updated")
          assert(events[1].values[1]=="vitals" and events[1].values[4]==1 and events[1].values[5]==1)
          assert(events[2].name=="aardwolf-vibe.character.updated.vitals")
          assert(events[2].values[1].hp==100 and events[2].values[2].extra.value==7)
          assert(events[2].values[3]==1 and events[2].values[4]==1)
          local normalized,raw,fresh=character:getGroup("vitals")
          assert(fresh and normalized.hp==100 and raw.extra.value==7)
          normalized.hp=500;raw.extra.value=500
          normalized,raw=character:getGroup("vitals")
          assert(normalized.hp==100 and raw.extra.value==7)
          local snapshot=character:snapshot();snapshot.groups.vitals.hp=600
          assert(select(1,character:getGroup("vitals")).hp==100)
        ''')

    def test_missing_fields_replace_group_and_freshness_is_independent(self):
        lua = self.runtime()
        lua.execute('''
          gmcp.char.vitals={hp=100,mana=90,moves=80};fire("gmcp.char.vitals")
          gmcp.char.vitals={hp=50};fire("gmcp.char.vitals")
          local value=select(1,character:getGroup("vitals"))
          assert(value.hp==50 and value.mana==nil and value.moves==nil)
          assert(character:isFresh("vitals") and not character:isFresh("base"))
          assert(character:getGroup("unknown")==nil and not character:isFresh("unknown"))
        ''')

    def test_unknown_fields_are_raw_only_and_same_status_table_updates(self):
        lua = self.runtime()
        lua.execute('''
          local current={level=210,state=8,pos="Standing",extension={flags={true,false}}}
          gmcp.char.status=current;fire("gmcp.char.status")
          current.state=11;current.enemy="an owl";fire("gmcp.char.status")
          local normalized,raw=character:getGroup("status")
          assert(normalized.state==11 and normalized.enemy=="an owl")
          assert(normalized.extension==nil and raw.extension.flags[1]==true)
          assert(character:status().accepted==2 and character:snapshot().sequence==2)
        ''')

    def test_malformed_known_fields_reject_atomically_without_events(self):
        lua = self.runtime()
        lua.execute('''
          gmcp.char.vitals={hp=100,mana=90};fire("gmcp.char.vitals")
          local before=#events
          gmcp.char.vitals={hp="50",mana=80};fire("gmcp.char.vitals")
          gmcp.char.base={classes="07"};fire("gmcp.char.base")
          gmcp.char.stats={str=1.5};fire("gmcp.char.stats")
          gmcp.char.worth={gold=math.huge};fire("gmcp.char.worth")
          local value=select(1,character:getGroup("vitals"))
          assert(value.hp==100 and value.mana==90 and #events==before)
          local status=character:status()
          assert(status.accepted==1 and status.rejected==4 and status.lastError)
        ''')

    def test_unsafe_raw_data_rejects_group(self):
        lua = self.runtime()
        lua.execute('''
          local huge={hp=1};for index=1,513 do huge["x"..index]=index end
          gmcp.char.vitals=huge;fire("gmcp.char.vitals")
          assert(not character:isFresh("vitals") and character:status().rejected==1)
          gmcp.char.base={name=string.rep("x",4097)};fire("gmcp.char.base")
          assert(character:status().rejected==2 and #events==0)
        ''')

    def test_session_resets_and_stale_generation_callbacks_are_fenced(self):
        lua = self.runtime()
        lua.execute('''
          gmcp.char.base={name="First"};fire("gmcp.char.base")
          local session=character:status().session
          fire("sysDisconnectionEvent")
          assert(not character:isFresh("base") and character:status().session==session)
          assert(character:snapshot().sequence==0 and character:snapshot().groups.base==nil)
          assert(events[#events].name=="aardwolf-vibe.character.reset")
          assert(events[#events].values[1]=="disconnect")
          fire("sysConnectionEvent")
          assert(character:status().session==session+1)
          fire("sysProtocolDisabled","MSDP")
          local eventCount=#events
          fire("sysProtocolDisabled","GMCP")
          assert(#events==eventCount+1 and events[#events].values[1]=="gmcp-disabled")

          local old=handlers["aardwolf-vibe.character:base"].callback
          character:stop();assert(character:start())
          gmcp.char.base={name="Stale"};old("gmcp.char.base")
          assert(not character:isFresh("base"))
          fire("gmcp.char.base");assert(select(1,character:getGroup("base")).name=="Stale")
        ''')

    def test_start_stop_are_idempotent_and_release_only_owned_resources(self):
        lua = self.runtime(False)
        lua.execute('''
          modules["another.consumer:Room"]=true
          assert(character:start());assert(character:start())
          local count=0;for _ in pairs(handlers) do count=count+1 end
          assert(count==9 and modules["aardwolf-vibe.character:Char"])
          character:stop();character:stop()
          assert(character:status().lifecycle=="stopped")
          assert(next(handlers)==nil and not modules["aardwolf-vibe.character:Char"])
          assert(modules["another.consumer:Room"])
        ''')

    def test_registration_and_gmod_failures_cleanup_partial_start(self):
        lua = self.runtime(False)
        lua.execute('''
          fail.registrationAt=4;assert(not character:start())
          assert(next(handlers)==nil and next(modules)==nil and not character:status().enabled)
          registrationCount=0;fail.registrationAt=nil;fail.gmod=true
          assert(not character:start())
          assert(next(handlers)==nil and next(modules)==nil and not character:status().enabled)
          assert(character:status().failedStarts==2 and character:status().session==0)
        ''')


if __name__ == "__main__":
    unittest.main()
