"""Documented inventory formats and broker-driven item observations, not live acceptance."""
import unittest
import zipfile
from pathlib import Path
from lupa.lua51 import LuaRuntime
import check_utility

ROOT = Path(__file__).resolve().parents[1]


class ItemModelTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        with zipfile.ZipFile(ROOT / 'build/AardwolfToolbox.mpackage') as archive:
            self.lua.globals().Items = self.lua.execute(archive.read('item-state.lua').decode())
        self.lua.execute('''
          model=Items.new()
          function row(id,name,wear)
            return assert(Items.parse(id..',MG,'..(name or 'a bag, with commas')..',60,11,0,'..(wear or -1)..',-1'))
          end
        ''')

    def test_fields_unknowns_precise_ids_and_defensive_copies(self):
        self.lua.execute('''
          local value=row('18446744073709551615','@Ra 真红 bag, with commas')
          assert(value.name=='@Ra 真红 bag, with commas' and value.timer==-1 and value.unique==false)
          assert(model.replace('carried',{[value.id]=value}))
          value.name='changed'; local result=model.get('18446744073709551615')
          assert(result.fresh and result.name~='changed')
          result.name='changed'; assert(model.list()[1].name~='changed')
          assert(Items.id('00042')=='42' and not Items.id('0'))
          assert(not Items.parse('1,,x,0,1,3,-1,-1'))
          assert(not Items.parse('1,,x,0,1,0,-2,-1'))
          assert(not Items.parse('1,,x,inf,1,0,-1,-1'))
          assert(not Items.parse(string.rep('9',21)..',,x,0,1,0,-1,-1'))
          local fields=Items.fields('a||b|'); assert(#fields==4 and fields[2]=='' and fields[4]=='')
          assert(model.update(assert(Items.event('4,27,-1,-1'))))
          local missing=model.get('27'); assert(missing.name==nil and missing.level==nil and missing.timer==nil)
        ''')

    def test_independent_snapshots_metadata_and_ordered_deltas(self):
        self.lua.execute('''
          assert(model.replace('carried',{['1']=row('1'),['2']=row('2')}))
          assert(model.replace('equipped',{['3']=row('3','helm',4)}))
          assert(model.replace('container:1',{['4']=row('4','potion')}))
          assert(model.count()==2 and #model.list('container:1')==1)
          local events={assert(Items.event('3,2,-1,-1')),assert(Items.event('6,4,1,-1')),
            {kind='metadata',row=row('5','new item')},assert(Items.event('4,5,-1,-1'))}
          assert(model.replace('carried',{['1']=row('1'),['2']=row('2')},events))
          assert(model.count()==2 and model.get('2')==nil and model.get('5').location=='carried')
          assert(model.get('3').location=='equipped' and model.get('4').container=='1')
          model.invalidate('equipped'); assert(not model.get('3').fresh and model.count()==2)
          assert(model.update(assert(Items.event('3,1,-1,-1'))))
          assert(model.get('1')==nil and model.get('4')==nil and model.count()==1)
          model.clear(); assert(#model.list()==0 and model.count()==nil)
        ''')

    def test_missing_container_invalidates_its_observed_contents(self):
        self.lua.execute('''
          assert(model.replace('carried',{['1']=row('1')}))
          assert(model.replace('container:1',{['2']=row('2')}))
          assert(model.replace('container:2',{['3']=row('3')}))
          assert(model.replace('carried',{}))
          assert(#model.list()==0)
          for i=1,4200 do assert(model.replace('container:'..i,{})) end
          local n=0;for key in pairs(model.status().fresh) do n=n+1 end
          assert(n<=4098)
        ''')

    def test_failed_commit_retains_last_snapshot(self):
        self.lua.execute('''
          assert(model.replace('carried',{['1']=row('1')}))
          local huge={}; for i=1,4097 do huge[tostring(i)]=row(tostring(i)) end
          local ok,reason=model.replace('carried',huge)
          assert(not ok and reason:find('limit') and model.count()==1 and #model.list()==1)
          local texts={};for i=1,300 do texts[tostring(i)]=row(tostring(i),string.rep('x',4096)) end
          assert(not model.replace('carried',texts)); assert(model.count()==1)
        ''')


class ItemServiceTests(unittest.TestCase):
    def setUp(self):
        harness=check_utility.UtilityTests()
        harness.setUp()
        self.lua=harness.lua
        with zipfile.ZipFile(ROOT / 'build/AardwolfToolbox.mpackage') as archive:
            self.lua.globals().Queries=self.lua.execute(archive.read('query-coordinator.lua').decode())
            self.lua.globals().Inventory=self.lua.execute(archive.read('inventory.lua').decode())
        self.lua.execute('''
          clock=0; function getEpoch() return clock end
          scheduled={}; serial=0
          function tempTimer(seconds,fn) serial=serial+1; scheduled[serial]={at=clock+seconds,fn=fn}; return serial end
          function killTimer(id) scheduled[id]=nil end
          function advance(seconds)
            local target=clock+seconds
            for _=1,1000 do
              local id,entry
              for k,v in pairs(scheduled) do if v.at<=target and (not entry or v.at<entry.at or v.at==entry.at and k<id) then id,entry=k,v end end
              if not id then clock=target; return end
              scheduled[id]=nil;clock=entry.at;entry.fn()
            end
            error('Timer loop')
          end
          broker=Queries.new(_G)
          inventory=Inventory.new(_G,cache,incoming,broker,nil,item_state)
          connected=true; data={char={status={state=3}}}
          function initial()
            assert(inventory.start());advance(0);snapshot();advance(0)
            assert(inventory.count==1)
          end
        ''')

    def test_manual_priority_coalescing_and_passive_output(self):
        self.lua.execute('''
          initial();assert(broker.acquire('background',40))
          assert(inventory.refresh('equipped'));assert(inventory.refresh('equipped'))
          assert(inventory.request(true));advance(0)
          local state=broker.snapshot();assert(#state.requests==2)
          for _,r in ipairs(state.waiting) do assert(r.priority==10) end
          assert(#calls==2)
          broker.release('background');advance(0);assert(calls[3]=='eqdata')
          feed('{eqdata}');feed('8,,a helm,4,7,0,3,-1');feed('{/eqdata}');advance(0)
          assert(calls[4]=='invdata' and inventory.get('8').location=='equipped')
          snapshot();advance(0)
          local before=gags;feed('{invdata}');feed('9,,a coin,0,6,0,-1,0');feed('{/invdata}')
          assert(gags==before and inventory.count==1 and inventory.get('9').timer==0)
          assert(inventory.get('8').location=='equipped')
          inventory.stop();broker.destroy();advance(20);assert(#calls==4 and trigger==nil)
        ''')

    def test_container_details_and_interleaved_updates(self):
        self.lua.execute('''
          initial();assert(inventory.refresh('container','42'));advance(0)
          assert(calls[3]=='invdata 42')
          feed('{invdata 42}');feed('55,,a potion,1,8,0,-1,-1')
          feed('{invmon}5,55,42,-1');feed('{invitem}55,M,a better potion,2,8,0,-1,-1');feed('{/invdata}')
          assert(inventory.get('55').location=='carried' and inventory.count==2)
          assert(inventory.get('55').name=='a better potion')
          assert(inventory.refresh('details','55'));advance(0);assert(calls[4]=='invdetails 55')
          feed('{invdetails}');feed('{invheader}55|2|Potion|0|1|none||||-1|||')
          feed('{statmod}Damage roll|0');feed('{statmod}Damage roll|2');feed('{/invdetails}')
          local item=inventory.get('55');assert(#item.details==3 and item.details[3].fields[2]=='2')
          item.details[1].fields[1]='evil';assert(inventory.get('55').details[1].fields[1]=='55')
          assert(inventory.refresh('container','55')==false)
          inventory.stop();broker.destroy()
        ''')

    def test_transport_failure_draining_limits_and_session_reset(self):
        self.lua.execute('''
          initial();local old=send;send=function() return nil,'connection lost' end
          assert(inventory.refresh('equipped'));advance(0)
          assert(inventory.status().last:find('connection lost') and inventory.get('42'))
          send=old;assert(inventory.request(true));advance(0)
          feed('{invdata}');feed('not an item');assert(inventory.count==nil)
          assert(broker.owner()=='AardwolfToolbox.inventory:carried')
          assert(not broker.acquire('competitor',40))
          feed('{/invdata}');assert(broker.owner()==nil)
          -- No partial snapshot replaced the observed inventory.
          assert(inventory.get('42') and not inventory.get('42').fresh)
          raiseEvent('AardwolfToolbox.gmcp.cleared');assert(#inventory.list()==0)
          inventory.stop();broker.destroy();advance(20);assert(trigger==nil)
        ''')

    def test_disable_restart_drains_old_response_before_new_request(self):
        self.lua.execute('''
          assert(broker.start(cache,incoming));initial()
          assert(inventory.request(true));advance(0);feed('{invdata}')
          inventory.stop();assert(broker.owner()=='AardwolfToolbox.inventory:carried')
          inventory.start();advance(0);local before=#calls
          feed('99,,an old item,1,11,0,-1,-1');advance(0);assert(#calls==before)
          feed('{/invdata}');advance(0)
          assert(#calls==before+2 and calls[before+1]=='config invmon on' and calls[#calls]=='invdata' and not inventory.get('99'))
          snapshot();advance(0);assert(inventory.count==1)
          inventory.stop();broker.destroy();advance(0);assert(trigger==nil and next(scheduled)==nil)
        ''')

    def test_detail_failure_keeps_location_and_replays_monitoring(self):
        self.lua.execute('''
          initial();assert(inventory.refresh('details','42'));advance(0)
          feed('{invdetails}');feed('{invheader}42|broken')
          feed('{invmon}4,44,-1,-1');feed('{/invdetails}')
          assert(inventory.count==2 and inventory.get('44').location=='carried')
          assert(not inventory.status().fresh['details:42'] and inventory.get('42').fresh)
          local before=#calls;advance(20);assert(#calls==before)
          assert(inventory.request(true));advance(0);feed('{invdata}')
          assert(inventory.refresh('equipped'));assert(#calls==before+1)
          feed('{/invdata}');advance(0);assert(calls[#calls]=='eqdata')
          inventory.stop();broker.destroy()
        ''')

    def test_timeout_retry_is_bounded_and_monitoring_requires_evidence(self):
        self.lua.execute('''
          inventory.start();advance(0)
          assert(inventory.status().monitoring=='requested')
          advance(10);advance(10);advance(30)
          assert(#calls==3 and inventory.count==nil and inventory.status().diagnostics.failed==2)
          for i=1,10 do raiseEvent('AardwolfToolbox.gmcp.updated');advance(0) end
          assert(#calls==3)
          feed('{invmon}4,44,-1,-1');assert(inventory.status().monitoring=='confirmed')
          inventory.stop();broker.destroy()
        ''')

    def test_interleaved_metadata_bytes_are_bounded(self):
        self.lua.execute('''
          initial();inventory.request(true);advance(0);feed('{invdata}')
          for i=1,270 do feed('{invitem}'..i..',,'..string.rep('x',4096)..',1,11,0,-1,-1') end
          assert(inventory.count==nil and inventory.status().last:find('limit'))
          assert(inventory.get('42'))
          inventory.stop();broker.destroy()
        ''')
