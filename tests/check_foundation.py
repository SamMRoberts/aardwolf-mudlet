"""Reliability contracts; no connection to a Mudlet profile or server."""
import unittest
import zipfile
from pathlib import Path
from lupa.lua51 import LuaRuntime
import check_package
ROOT=Path(__file__).resolve().parents[1]

class FoundationTests(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        with zipfile.ZipFile(ROOT/'build/AardwolfToolbox.mpackage') as archive:
            for name,key in [('components','Components'),('query-coordinator','Queries'),('readiness','Readiness')]:
                self.lua.globals()[key]=self.lua.execute(archive.read(name+'.lua').decode())
        self.lua.execute('''
          timers={}; nextTimer=0; clock=0
          function getEpoch() return clock end
          function tempTimer(delay,fn) nextTimer=nextTimer+1;timers[nextTimer]={at=clock+delay,fn=fn};return nextTimer end
          function killTimer(id) timers[id]=nil end
          function raiseEvent() end
          function advance(t)
            local limit=clock+t
            while true do
              local id,at
              for k,v in pairs(timers) do if v.at<=limit and (not at or v.at<at or v.at==at and k<id) then id,at=k,v.at end end
              if not id then break end
              clock=at;local fn=timers[id].fn;timers[id]=nil;fn()
            end
            clock=limit
          end
        ''')

    def test_cleanup_is_reverse_order_and_continues_after_failure(self):
        self.lua.execute('''
          local c=Components.new();local stopped={}
          c.register('cache',{stop=function() stopped[#stopped+1]='cache' end})
          c.register('producer',{stop=function() stopped[#stopped+1]='producer';error('failure') end},{'cache'})
          c.register('view',{stop=function() stopped[#stopped+1]='view' end},{'producer'})
          assert(not pcall(c.register,'cache',{}))
          assert(not pcall(c.register,'missing',{}, {'other'}))
          local ok,report=c.stop();assert(not ok and table.concat(stopped,',')=='view,producer,cache')
          assert(report[2].error:find('failure'));report[2].error='changed';assert(c.snapshot()[2].error~='changed')
        ''')

    def test_broker_priority_coalescing_drain_and_deadline(self):
        self.lua.execute('''
          local q=Queries.new(_G);local sent={};local valid=true
          local low=q.request('catalog',{timeout=10,priority=40,start=function() sent[#sent+1]='catalog' end})
          local high=q.request('manual',{timeout=10,priority=10,current=function() return valid end,start=function() sent[#sent+1]='manual' end})
          assert(q.request('manual',{timeout=10,start=function() error('duplicate') end})==high)
          advance(0);assert(q.owner()=='manual' and #sent==1)
          valid=false;q.poke();advance(0);assert(high.status().state=='draining' and q.owner()=='manual')
          q.release('manual');q.release('manual');assert(q.owner()=='manual')
          high.finish(true);advance(0);assert(q.owner()=='catalog' and #sent==2)
          local copy=q.snapshot();copy.requests[1].state='changed';assert(low.status().state=='active')
          advance(10);assert(q.owner()==nil and low.status().state=='failed')
          q.destroy();assert(next(timers)==nil)
        ''')

    def test_broker_readiness_wakeup_and_queued_cancel(self):
        self.lua.execute('''
          local q=Queries.new(_G);local ready=false;local count=0
          local request=q.request('inventory',{timeout=10,ready=function() return ready end,start=function() count=count+1 end})
          advance(0);assert(count==0 and next(timers))
          ready=true;q.poke();advance(0);assert(count==1)
          local other=q.request('other',{timeout=10,start=function() error('cancelled request ran') end})
          other.cancel();request.finish(true);advance(0);assert(q.owner()==nil)
          q.destroy();assert(next(timers)==nil)
        ''')

    def test_broker_response_deadline_is_opt_in_and_cancellable(self):
        self.lua.execute('''
          local q=Queries.new(_G);local sends=0
          assert(q.acquire('busy',40))
          local legacy=q.request('legacy',{timeout=10,start=function() error('Unexpected send') end})
          local waiting=q.request('room',{timeout=10,timeoutFromStart=true,start=function() sends=sends+1 end})
          advance(15)
          assert(legacy.status().state=='failed' and waiting.status().state=='queued')
          assert(sends==0 and next(timers)==nil,'Queued response deadline must not poll')
          q.release('busy');advance(0);assert(sends==1)
          advance(9);assert(waiting.status().state=='active')
          waiting.cancel();assert(waiting.status().state=='draining')
          advance(1);assert(waiting.status().state=='cancelled' and q.owner()==nil)
          local pending=q.request('room',{timeout=10,timeoutFromStart=true,start=function() error('Cancelled send') end})
          pending.cancel();advance(0);assert(#q.snapshot().requests==0 and next(timers)==nil)
          q.destroy()
        ''')

    def test_broker_priority_promotion_and_bounded_failure_history(self):
        self.lua.execute('''
          local q=Queries.new(_G);local sent={}
          assert(q.acquire('busy',40))
          local background=q.request('background',{timeout=10,priority=40,start=function() sent[#sent+1]='background' end})
          local manual=q.request('inventory',{timeout=10,priority=40,start=function() sent[#sent+1]='inventory' end,
            finish=function() error('callback failure') end})
          q.request('inventory',{timeout=10,priority=10,start=function() error('Duplicate send') end})
          advance(0);q.release('busy');advance(0);assert(sent[1]=='inventory')
          manual.finish(true);advance(0);assert(sent[2]=='background')
          assert(q.snapshot().recent[1].reason:find('callback failure'))
          background.finish(true);advance(0)
          for i=1,40 do
            local h=q.request('job',{timeout=1,start=function() end});advance(0);h.finish(true);advance(0)
          end
          local report=q.snapshot();assert(#report.recent==32);report.recent[1].state='changed'
          assert(q.snapshot().recent[1].state~='changed');q.destroy()
        ''')

    def test_readiness_and_transport_failures(self):
        self.lua.execute('''
          local state,pos,connected=3,'Standing',true
          function getConnectionInfo() return '',0,connected end
          local cache={enabled=true,get=function(path) if path=='char.status.state' then return state else return pos end end}
          local r=Readiness.new(_G,cache)
          assert(r.check('spellup'));state=8;assert(r.check('manual') and not r.check('information'))
          state=7;assert(not r.check('manual'));state=nil;assert(not r.check('manual'))
          state=3;pos='Resting';assert(not r.check('spellup'))
          function send() return nil,'failed' end;assert(not r.send('command','look'))
          function send() return nil end;assert(r.send('command','look'))
          assert(not r.send('command','look\\nkill'))
        ''')

class StartupTests(unittest.TestCase):
    def setUp(self):
        harness=check_package.PackageTests();harness.setUp();self.lua=harness.lua;self.script=harness.script;self.addCleanup(harness.doCleanups)

    def test_package_version_replacement_releases_old_instances(self):
        self.lua.execute('''
          assert(AardwolfToolbox.start());oldCache=AardwolfToolbox.gmcp
          local c=AardwolfToolbox.config;assert(c.set('mapper','enabled',false))
          AardwolfToolbox.loadedVersion='previous-version'
        ''')
        self.lua.execute(self.script)
        self.lua.execute('''
          assert(not AardwolfToolbox.active and count(handlers)==0 and count(widgets)==0)
          assert(AardwolfToolbox.start());assert(AardwolfToolbox.gmcp~=oldCache)
          assert(not AardwolfToolbox.config.get('mapper','enabled'))
          AardwolfToolbox.stop();assert(count(handlers)==0 and count(widgets)==0 and count(timers)==0)
        ''')

    def test_partial_initialization_can_retry_without_leaks(self):
        self.lua.execute('''
          local real=dofile;local fail=true
          dofile=function(path) if fail and path:find('/spells.lua',1,true) then error('Missing resource fixture') end;return real(path) end
          local ok= AardwolfToolbox.start();assert(not ok and not AardwolfToolbox.config)
          assert(count(handlers)==0 and count(widgets)==0 and count(timers)==0)
          fail=false;assert(AardwolfToolbox.start());assert(AardwolfToolbox.spells)
          AardwolfToolbox.stop();assert(count(handlers)==0 and count(widgets)==0 and count(timers)==0)
        ''')

    def test_initial_install_preserves_external_margins(self):
        self.lua.execute('''
          borderTop=51;borderBottom=73
          assert(AardwolfToolbox.start());AardwolfToolbox.stop()
          assert(borderTop==51 and borderBottom==73)
        ''')

    def test_diagnostics_are_defensive_and_contain_no_catalog_rows(self):
        self.lua.execute('''
          assert(AardwolfToolbox.start())
          local h=AardwolfToolbox.health();h.features[1].id='changed'
          assert(AardwolfToolbox.health().features[1].id~='changed')
          assert(not h.catalog.character and not h.catalog.rows)
          AardwolfToolbox.stop()
        ''')

    def test_settings_search_does_not_send_or_change_preferences(self):
        self.lua.execute('''
          AardwolfToolbox.openSettings()
          local window=AardwolfToolbox.settingsWindow
          local before=AardwolfToolbox.config.get('mapper','enabled')
          local search=widgets['AardwolfToolbox.settings.search']
          assert(search and search.action)
          search.action('terrain')
          local visible=0
          for name,widget in pairs(widgets) do
            if name:match('AardwolfToolbox.settings.feature') then
              visible=visible+1;assert(widget.text=='Auto-mapper')
            end
          end
          assert(visible==1)
          search.action('');window.close()
          assert(AardwolfToolbox.config.get('mapper','enabled')==before)
          AardwolfToolbox.stop()
        ''')
