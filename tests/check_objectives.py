"""Observed inactive campaign format plus synthetic service/state contracts.
No live campaign/GQ or native boundary acceptance is implied by these tests.
"""
import unittest
import zipfile
from pathlib import Path
from lupa.lua51 import LuaRuntime
from lua_support import install_json, install_sqlite
import check_foundation
import check_dashboard_views

ROOT = Path(__file__).resolve().parents[1]


class ObjectiveTests(unittest.TestCase):
    def setUp(self):
        check_foundation.FoundationTests.setUp(self)
        install_json(self.lua)
        self.addCleanup(install_sqlite(self.lua))
        with zipfile.ZipFile(ROOT/'build/AardwolfToolbox.mpackage') as archive:
            for name, key in [('objective-state', 'S'), ('objective-store', 'Store'),
                              ('objective-protocol', 'P'), ('objective-tracker', 'Tracker'), ('incoming', 'Incoming')]:
                self.lua.globals()[key] = self.lua.execute(archive.read(name+'.lua').decode())
        self.lua.execute('''
          handlers={};sent={};visible={};events={};characters={};clock=1000
          function getMudletHomeDir() return '/objectives' end
          function registerNamedEventHandler(owner,name,event,fn) handlers[owner..name]={event=event,fn=fn};return true end
          function deleteNamedEventHandler(owner,name) handlers[owner..name]=nil end
          function raiseEvent(event,...)
            events[#events+1]={event,last=visible[#visible]}
            local callbacks={};for _,h in pairs(handlers) do if h.event==event then callbacks[#callbacks+1]=h.fn end end
            for _,fn in ipairs(callbacks) do fn(...) end
          end
          function tempRegexTrigger(pattern,fn) trigger=fn;return 1 end
          function killTrigger() trigger=nil end
          function deleteLine() table.remove(visible) end
          function echo(s) visible[#visible+1]=s end
          function feed(s) line=s;visible[#visible+1]=s;trigger() end
          local values={['char.base.name']='Tesobi',['char.status.state']=3}
          cache={enabled=true,session=1,get=function(path) return values[path] end}
          ready=true
          readiness={check=function() return ready,'Not ready' end,send=function(kind,line) sent[#sent+1]=line;return true end}
          store=Store.new(_G,S);incomingService=Incoming.new(_G);broker=Queries.new(_G)
          function make(kind,protocol)
            service=Tracker.new(_G,kind or 'campaign',cache,incomingService,broker,readiness,store,S,protocol or P)
            opts={enabled=true,automatic=true,suppress=true,hints=true,placement='tabbed'}
            assert(service.configure(opts));return service
          end
          function identity(name)
            values['char.base.name']=name;raiseEvent('AardwolfToolbox.gmcp.updated','char.base');advance(0)
          end
          function beginFrame()
            advance(0);first=sent[#sent-2]:sub(6);last=sent[#sent]:sub(6);feed(first)
          end
          function observed()
            feed('You are not currently on a campaign.')
            feed('You have completed 0 campaigns today.')
            feed('You may take a campaign at this level.')
          end
          -- Synthetic adapter to test transport/model contracts, NOT a server grammar.
          patch={state='Active',objectives={{name='a bat',room='Hall',remaining=1}}}
          synthetic={supported=function() return true end,event=function() return nil end,
            new=function(kind,op)
              local seen=false
              return {receive=function(line) if line=='SYNTHETIC OBJECTIVES' then seen=true;return true end;return false end,
                finish=function() if seen then return S.copy(patch) end;return nil,'Synthetic incomplete response' end}
            end}
          function capture()
            assert(service.refresh());beginFrame();feed('SYNTHETIC OBJECTIVES');feed(last);advance(0)
          end
        ''')

    def test_observed_inactive_campaign_and_format_gate(self):
        self.lua.execute('''
          make();identity('Tesobi');assert(#sent==0 and service.last:find('boundaries'))
          assert(service.refresh());beginFrame();observed();feed(last);advance(0)
          local s=service.snapshot();assert(s.state=='Available' and s.today==0 and s.fresh and #s.objectives==0)
          assert(#visible==0 and service.status().boundaries.info)
          assert(store.read('tesobi','campaign').state=='Available' and not store.read('tesobi','campaign').fresh)
          local n=#sent;identity('Tesobi');advance(5);assert(#sent==n)
          assert(service.refresh());beginFrame();feed('The targets for this campaign are:');feed(last);advance(0)
          assert(service.snapshot().state=='Available' and not service.snapshot().fresh)
          assert(visible[1]=='The targets for this campaign are:')
          service.stop();make('globalQuest');local count=#sent
          assert(not service.refresh() and #sent==count and service.status().blocked)
        ''')

    def test_boundaries_unrelated_lines_and_disabled_suppression(self):
        self.lua.execute('''
          make();opts.suppress=false;service.configure(opts)
          assert(service.refresh());beginFrame();observed();feed('a bat hits you.');feed(last);advance(0)
          assert(#visible==4 and visible[4]=='a bat hits you.')
          for _,e in ipairs(events) do assert(not e.last or not e.last:find('_END',1,true)) end
          service.stop();assert(not trigger and next(handlers)==nil)
        ''')

    def test_movement_scope_partial_updates_and_identity_reset(self):
        self.lua.execute('''
          make('campaign',synthetic);broker.setContext({session=1,visit=1,progression='a'})
          assert(service.refresh());beginFrame();broker.setContext({visit=20,progression='b'});advance(0)
          feed('SYNTHETIC OBJECTIVES');feed(last);advance(0)
          assert(service.snapshot().fresh and service.snapshot().objectives[1].name=='a bat')
          local copy=service.snapshot();copy.objectives[1].name='changed';assert(service.hints()[1].target=='a bat')
          identity("O'Brien");assert(service.snapshot().state=='Unknown')
          identity('Tesobi');assert(service.snapshot().state=='Active' and not service.snapshot().fresh and #service.hints()==0)
          service.stop();broker.destroy();assert(next(timers)==nil)
        ''')

    def test_timeout_interruption_cancel_and_response_limit(self):
        self.lua.execute('''
          make('campaign',synthetic);capture();local before=store.read('Tesobi','campaign')
          assert(service.refresh());beginFrame();feed('SYNTHETIC OBJECTIVES');advance(10)
          assert(not service.snapshot().fresh and store.read('Tesobi','campaign').objectives[1].name=='a bat')
          assert(service.refresh());beginFrame();raiseEvent('sysDataSendRequest','event','look')
          feed('SYNTHETIC OBJECTIVES');feed(last);advance(0);assert(not service.snapshot().fresh and visible[#visible]:find('response'))
          assert(service.refresh());beginFrame();feed(string.rep('x',1048577));feed(last);advance(0)
          assert(not service.snapshot().fresh)
          assert(service.refresh());beginFrame();service.stop();assert(broker.owner()~=nil)
          advance(10);assert(not broker.owner());broker.destroy();assert(next(timers)==nil)
        ''')

    def test_state_partial_metadata_and_unknowns_and_gq_participation(self):
        self.lua.execute('''
          local a=S.apply(S.empty(),{state='Active',level=40,remainingSeconds=0,rewards={gold=0},objectives={{name='x',quantity=2}}},'info',100,'fixture')
          local b=S.apply(a,{state='Active',objectives={{name='x',remaining=1}}},'check',110,'fixture')
          assert(b.level==40 and b.rewards.gold==0 and b.objectives[1].quantity==nil)
          local c=S.apply(b,{state='Available',objectives={}},'info',120,'fixture');assert(not c.level and not c.rewards and #c.objectives==0)
          assert(not pcall(S.validate,{state='Active',objectives={{name='x',quantity=-1}}}))
          assert(not pcall(S.validate,{state='Active',remainingSeconds=0/0}))
          assert(not pcall(S.validate,{state='Active',objectives={[2]={name='x'}}}))
          make('globalQuest',synthetic)
          patch={state='Joined',participating=true,eventId=123,objectives={{name='a bat'}}}
          -- Directly test state/store contracts; API refresh first performs availability.
          local joined=S.apply(S.empty(),patch,'info',100,'fixture');assert(#S.hints(joined,'globalQuest',true)==1)
          assert(store.save('Tesobi','globalQuest',joined))
          local restored=store.read('tesobi','globalQuest');assert(not restored.participating and not restored.fresh and #S.hints(restored,'globalQuest',true)==0)
          local listed=S.apply(joined,{state='Unknown',events={{id=42,state='Announced'}}},'list',120,'fixture')
          assert(listed.eventId==123 and listed.participating and listed.events[1].id==42)
          local replaced=S.apply(listed,{state='Active',eventId=42,objectives={{name='new'}}},'info',130,'fixture')
          assert(not replaced.participating and #S.hints(replaced,'globalQuest',true)==0)
        ''')

    def test_store_transaction_failure_unknown_schema_character_and_copy(self):
        self.lua.execute('''
          local v={state='Active',objectives={{name="O'Brien <red>",room='(Hall)'}},fresh=true}
          assert(store.save("O'Brien",'campaign',v));v.objectives[1].name='changed'
          assert(store.read("o'brien",'campaign').objectives[1].name=="O'Brien <red>")
          assert(store.read('another','campaign').state=='Unknown')
          local original=luasql.sqlite3
          luasql.sqlite3=function()
            local env=original();local connect=env.connect
            env.connect=function(self,...)
              local connection=connect(self,...);local execute=connection.execute
              connection.execute=function(self,sql)
                if sql=='COMMIT' then return nil,'injected commit failure' end
                return execute(self,sql)
              end;return connection
            end;return env
          end
          local ok,why=store.save("O'Brien",'campaign',{state='Available'})
          assert(not ok and why:find('injected'));luasql.sqlite3=original
          assert(store.read("O'Brien",'campaign').state=='Active')
          store.close();store.close()
        ''')

    def test_settings_and_repeated_lifecycle_never_send(self):
        self.lua.execute('''
          make();local handlersBefore=0;for _ in pairs(handlers) do handlersBefore=handlersBefore+1 end
          assert(service.start());service.configure(opts);service.configure(opts)
          local handlersAfter=0;for _ in pairs(handlers) do handlersAfter=handlersAfter+1 end
          assert(handlersAfter==handlersBefore and #sent==0)
          opts.enabled=false;assert(service.configure(opts));service.stop();assert(next(handlers)==nil and not trigger)
          opts.enabled=true;assert(service.configure(opts));assert(#sent==0)
          service.stop();broker.destroy();assert(next(timers)==nil)
        ''')


class ObjectiveViews(unittest.TestCase):
    setUp = check_dashboard_views.ViewTests.setUp

    def test_independent_tabs_placement_copy_lookup_and_gate(self):
        self.lua.execute('''
          local t=AardwolfToolbox
          for _,id in ipairs({'campaign','globalQuest'}) do
            assert(v.available(id));assert(v.open(id));flushEvents()
            assert(widgets['AardwolfToolbox.dashboard.'..id..'.status'])
            assert(v.setMode(id,'floating'));flushEvents()
            local w=widgets['AardwolfToolbox.views.TestProfile.'..id];assert(w)
            w:hide();assert(v.open(id));assert(not w.hidden)
            assert(v.setMode(id,'tabbed'));flushEvents()
          end
          t.campaign.snapshot=function() return {state='Active',fresh=true,objectives={{name='<Éowyn>',room='Hall',area='Academy',remaining=0}},events={},remainingSeconds=0,reported=0} end
          assert(v.open('campaign'));flushEvents()
          local name=widgets['AardwolfToolbox.dashboard.campaign.objective_1']
          assert(name.text:find('&lt;Éowyn&gt;',1,true))
          assert(widgets['AardwolfToolbox.dashboard.campaign.status'].text:find('Awaiting update',1,true))
          name.callback();searchRoom=function() return {[7]='Hall',[8]='Hall'} end
          getRoomArea=function() return 1 end;getAreaTableSwap=function() return {[1]='Academy'} end
          widgets['AardwolfToolbox.dashboard.campaign.find'].callback()
          assert(widgets['AardwolfToolbox.dashboard.campaign.match_7'] and widgets['AardwolfToolbox.dashboard.campaign.match_8'])
          local writes=0;local echo=name.echo;name.echo=function(self,...) writes=writes+1;return echo(self,...) end
          fire('AardwolfToolbox.campaign.updated');flushEvents();assert(writes==0)
          t.stop();assert(not widgets['AardwolfToolbox.dashboard.campaign.status'])
        ''')

class BrokerContextTests(unittest.TestCase):
    setUp = check_foundation.FoundationTests.setUp

    def test_room_independent_opt_in_legacy_defaults_and_invalid_context(self):
        self.lua.execute('''
          local q=Queries.new(_G);q.setContext({session=1,visit=1,progression='level1'})
          local all=q.request('legacy',{timeout=10,start=function() end})
          local session=q.request('independent',{timeout=10,contextKeys={'session'},start=function() end})
          advance(0);q.setContext({visit=2,progression='level2'});advance(0)
          assert(not all.current() and session.current());all.finish(false);advance(0)
          assert(q.owner()=='independent');q.setContext({session=2});advance(0);assert(not session.current())
          session.finish(false)
          assert(not pcall(q.request,'bad',{timeout=10,contextKeys={'unknown'},start=function() end}))
          assert(not pcall(q.request,'bad',{timeout=10,contextKeys={'session','session'},start=function() end}))
          q.destroy();assert(next(timers)==nil)
        ''')

class ExtendedObjectiveTests(unittest.TestCase):
    setUp = ObjectiveTests.setUp
    def test_inspected_event_never_overwrites_personal_progress(self):
        self.lua.execute('''
          local mine=S.apply(S.empty(),{state='Joined',eventId=42,participating=true,objectives={{name='mine',remaining=1}}},'info',10,'fixture')
          local inspected=S.apply(mine,{state='Active',eventId=55,objectives={{name='another',quantity=2}}},'inspect',20,'fixture')
          assert(inspected.eventId==42 and inspected.participating and inspected.objectives[1].name=='mine')
          assert(inspected.selected.eventId==55 and not inspected.selected.participating)
          assert(S.hints(inspected,'globalQuest',true)[1].target=='mine')
          assert(store.save('Tesobi','globalQuest',inspected))
          local restored=store.read('Tesobi','globalQuest');assert(not restored.selected.fresh and not restored.participating)
        ''')

    def test_stale_outgoing_player_command_and_session_change_preserve_disk(self):
        self.lua.execute('''
          make('campaign',synthetic);capture()
          assert(service.refresh());beginFrame();identity('Other')
          feed('SYNTHETIC OBJECTIVES');feed(last);advance(10)
          assert(service.snapshot().state=='Unknown' and not service.snapshot().fresh)
          assert(store.read('Tesobi','campaign').objectives[1].name=='a bat')
          assert(#service.hints()==0)
          service.stop();broker.destroy()
        ''')

    def test_interleaved_ascii_ownership_and_generic_forward_once(self):
        self.lua.execute('''
          local frame=false;local tags=0
          incomingService.add('ascii',1,function(line)
            if line=='<MAPSTART>' then frame=true end
            if frame then if line=='<MAPEND>' then frame=false end;return true,true end
            return false
          end,function() error('ASCII failed') end)
          incomingService.add('AardwolfToolbox.tags',90,function(line) tags=tags+1;return false end,function() error('tags failed') end)
          make();assert(service.refresh());beginFrame()
          feed('<MAPSTART>');observed();feed('<MAPEND>');feed(last);advance(0)
          assert(not service.snapshot().fresh)
          assert(service.refresh());beginFrame();local before=tags;observed();feed(last);advance(0)
          assert(service.snapshot().fresh and tags-before==3)
          service.stop();incomingService.destroy();broker.destroy()
        ''')

    def test_gq_inspection_failure_does_not_invalidate_personal_progress(self):
        self.lua.execute(''' 
          make('globalQuest',synthetic)
          patch={state='Unknown',events={{id=42,state='Active'},{id=55,state='Announced'}}}
          assert(service.refresh());beginFrame();feed('SYNTHETIC OBJECTIVES');feed(last);advance(0)
          patch={state='Joined',participating=true,eventId=42,objectives={{name='mine',remaining=1}}}
          beginFrame();feed('SYNTHETIC OBJECTIVES');feed(last);advance(0)
          assert(service.snapshot().fresh and service.snapshot().participating)
          assert(service.inspect(55));beginFrame()
          patch={state='Active',eventId=55,objectives={{name='other',quantity=2}}}
          feed('SYNTHETIC OBJECTIVES');feed(last);advance(0)
          assert(service.snapshot().eventId==42 and service.snapshot().selected.eventId==55)
          assert(service.hints()[1].target=='mine')
          assert(service.inspect(55));beginFrame();advance(10)
          assert(service.snapshot().fresh and service.snapshot().participating and not service.snapshot().selected.fresh)
          raiseEvent('AardwolfToolbox.gmcp.cleared');assert(not service.inspect(42))
          service.stop();broker.destroy()
        ''')

    def test_failed_persistence_keeps_active_observation_and_old_disk(self):
        self.lua.execute('''
          make('campaign',synthetic);capture()
          local save=store.save;store.save=function() return nil,'Injected write failure' end
          patch={state='Active',objectives={{name='new target'}}};capture()
          assert(service.snapshot().fresh and service.snapshot().objectives[1].name=='new target')
          assert(service.last:find('not saved',1,true))
          assert(store.read('Tesobi','campaign').objectives[1].name=='a bat')
          store.save=save;service.stop();broker.destroy()
        ''')

    def test_progress_countdown_does_not_restart_and_zero_does_not_complete(self):
        self.lua.execute('''
          local v=S.apply(S.empty(),{state='Active',remainingSeconds=60,objectives={{name='target',remaining=2}}},'info',100,'fixture')
          v=S.apply(v,{state='Active',objectives={{name='target',remaining=1}}},'check',130,'fixture')
          assert(v.remainingSeconds==30 and v.reported==130)
          v=S.apply(v,{state='Active',objectives={}},'check',200,'fixture')
          assert(v.remainingSeconds==0 and v.state=='Active' and v.fresh)
        ''')
