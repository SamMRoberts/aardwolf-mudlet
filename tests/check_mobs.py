"""Room-local evidence, bounded scan capture, and owned feature lifecycle."""
from pathlib import Path
import unittest
import zipfile
from lupa.lua51 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]

class MobTests(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        with zipfile.ZipFile(ROOT/'build/AardwolfToolbox.mpackage') as z:
            for name,var in [('mob-state','State'),('mob-protocol','Protocol'),('mobs','Mobs')]:
                self.lua.globals()[var]=self.lua.execute(z.read(name+'.lua').decode())
        self.lua.execute('now=100; function clock() return now end; state=State.new(clock); state.clear("12")')

    def test_individual_duplicates_flags_players_and_literal_names(self):
        self.lua.execute('''          state.observe({{name='(Hidden) a rat'},{name='a rat'},{name='(Player) Sam'}, {name='Éowyn <red> & friends'}})
          local s=state.snapshot(12); assert(#s.rows==3)
          assert(s.rows[1].id~=s.rows[2].id and s.rows[1].ordinal==1 and s.rows[2].ordinal==2)
          assert(s.rows[1].flags=='(Hidden)' and s.rows[2].flags=='')
          s.rows[1].name='mutated'; assert(state.snapshot(12).rows[1].name=='a rat')
          state.enemy('a rat',true,50); s=state.snapshot(12)
          assert(not s.rows[1].target and s.rows[1].possibleTarget and s.rows[2].possibleTarget)
          assert(state.kill('a rat')); s=state.snapshot(12)
          assert(s.rows[1].killed==1 and s.rows[1].uncertainDeath and s.rows[2].alive==1)
        ''')

    def test_disappearance_does_not_prove_death_and_repopulation(self):
        self.lua.execute('''          state.observe({{name='a rat',count=2}}); state.observe({})
          local s=state.snapshot(12); assert(#s.rows==2 and s.rows[1].killed==0 and s.rows[2].missing==1)
          state.observe({{name='a rat'}}); assert(state.kill('a rat')); assert(not state.kill('a rat'))
          state.observe({{name='a rat'}}); s=state.snapshot(12)
          local alive,killed=0,0; for _,r in ipairs(s.rows) do alive=alive+r.alive; killed=killed+r.killed end
          assert(alive==1 and killed==1)
          state.clear('13'); assert(#state.snapshot(12).rows==0 and not state.fresh)
        ''')

    def test_target_is_not_automatically_attacker_and_evidence_expires(self):
        self.lua.execute('''          state.observe({{name='a rat'},{name='a bat'}}); state.enemy('a rat',true,0)
          assert(state.snapshot(12).rows[1].health==0 and not state.snapshot(12).rows[1].attacking)
          assert(state.attack('a rat') and state.attack('a bat')); assert(not state.attack('chat text'))
          local s=state.snapshot(12); assert(s.rows[1].attacking and s.rows[2].attacking)
          now=113; assert(not state.snapshot(12).rows[1].attacking)
          state.enemy('',false); assert(not state.snapshot(12).rows[1].target)
          assert(not state.attack('a rat'))
        ''')

    def test_selection_scan_order_and_stale_ids(self):
        self.lua.execute('''          state.observe({{name='a frog'},{name='a frog'},{name='a bat'}})
          local s=state.snapshot(12); local id,revision=s.rows[2].id,s.revision
          assert(state.select(id,revision)); assert(state.snapshot(12).rows[2].selected)
          state.enemy('a bat',true,70); assert(state.snapshot(12).rows[2].id==id)
          assert(state.attack('a frog')); s=state.snapshot(12)
          assert(s.rows[1].possibleAttacker and s.rows[2].possibleAttacker and not s.rows[1].attacking)
          state.observe({{name='a frog'},{name='a frog'}})
          assert(not state.select(id,revision) and not state.snapshot(12).rows[2].selected)
          s=state.snapshot(12); assert(state.select(s.rows[2].id,s.revision))
          assert(state.kill('a frog')); assert(not state.snapshot(12).rows[2].selected)
          assert(not state.select(s.rows[1].id,s.revision))
        ''')

    def test_scan_sections_bounds_and_unknown_output(self):
        self.lua.execute('''
          local s=Protocol.scan(); assert(s.line('Right here you see:'))
          assert(s.line('     - (Hidden) a rat')); assert(s.line('     - a rat'))
          assert(s.line('North from here you see:')); assert(s.line('     - a bat'))
          assert(not s.line("A player says 'a dragon'")); assert(#s.entries==2)
          state.observe(s.entries); assert(#state.snapshot(12).rows==2 and state.snapshot(12).rows[2].alive==1)
          s=Protocol.scan(); assert(s.line('You see nothing here.')); assert(s.seen and #s.entries==0)
          s=Protocol.scan(); assert(not pcall(s.line,string.rep('a',262145)))
          s=Protocol.scan(); s.line('Right here you see:')
          for i=1,512 do s.line('     - a rat') end
          assert(not pcall(s.line,'     - a rat'))
        ''')

    def test_only_known_name_bearing_combat_messages(self):
        self.lua.execute('''
          state.observe({{name='a rat'}}); local rows=state.snapshot(12).rows
          assert(Protocol.combat("A rat's bite hits you.",rows)=='attack')
          assert(Protocol.combat("A rat's bite <-=-> SUNDERS <-=-> you! [123]",rows)=='attack')
          assert(Protocol.combat('A rat is DEAD!!',rows)=='kill')
          assert(not Protocol.combat("Sam says 'A rat is DEAD!!'",rows))
          assert(not Protocol.combat("A rat's greeting welcomes you.",rows))
          assert(not Protocol.combat("A rat's bite hits someone else.",rows))
          assert(not Protocol.combat('A bat is DEAD!!',rows))
        ''')

    def test_failed_snapshot_is_atomic_and_history_is_bounded(self):
        self.lua.execute('''
          state.observe({{name='a rat'}})
          assert(not pcall(state.observe,{{name='a bat'},{name='bad',count=513}}))
          assert(#state.rows==1 and state.rows[1].name=='a rat')
          local many={}; for i=1,256 do many[i]={name='mob '..i} end
          state.observe(many); local s=state.snapshot(12); assert(#s.rows==257)
          for i=1,256 do assert(s.rows[i].alive==1) end
          state.kill('mob 1'); state.enemy('mob 1',true,0)
          assert(state.snapshot(12).rows[1].alive==0 and not state.snapshot(12).rows[1].target)
          for batch=1,5 do state.observe(many) end; assert(#state.snapshot(12).rows<=1024)
        ''')

    def test_live_scan_fixture(self):
        import json
        lines=json.loads((ROOT/'tests/fixtures/room-scan.json').read_text())
        self.lua.execute('scan=Protocol.scan()')
        for line in lines[1:-1]:
            self.assertTrue(self.lua.globals().scan.line(line))
        self.lua.execute('''state.observe(scan.entries); assert(#state.snapshot(12).rows==6); assert(state.snapshot(12).rows[6].ordinal==3)''')

    def service(self):
        self.lua.execute('''
          timers={}; handlers={}; sent={}; nextID=0; online=true; calls=0; removed=0
          function tempTimer(_,fn) nextID=nextID+1; timers[nextID]=fn; return nextID end
          function killTimer(id) timers[id]=nil end
          function registerNamedEventHandler(_,name,_,fn) handlers[name]=fn; return true end
          function deleteNamedEventHandler(_,name) handlers[name]=nil end
          function raiseEvent() end
          function getConnectionInfo() return '',0,online end
          function getEpoch() return now end
          function send(cmd) sent[#sent+1]=cmd; return true end
          function sendGMCP() end
          function echo() end
          gmod={enableModule=function() end,disableModule=function() end}
          function pulse() local old=timers; timers={}; for _,fn in pairs(old) do fn() end end
          cache={enabled=true,values={['char.status.state']=3,['char.status.pos']='Standing'}}
          function cache.get(path) return cache.values[path] end
          incoming={add=function(_,_,fn) receive=fn; calls=calls+1 end,remove=function() receive=nil; removed=removed+1 end}
          tags={isCapturing=function() return false end}
          queries={acquire=function() return true end,release=function() end}
          spellup={status=function() return {inflight=false} end}
          Pane={new=function() return {configure=function() end,destroy=function() end,layout=function() end,update=function(s,m) displayed=s; message=m end} end}
          options={}; for _,s in ipairs(Mobs.definition(function() end).settings) do options[s.key]=s.default end
          m=Mobs.new(_G,cache,incoming,tags,queries,spellup,State,Protocol,Pane,{}, {},function() end)
          assert(m.configure(options))
          function room(id) cache.values['room.info']={num=id}; handlers['AardwolfToolbox.gmcp.updated']('', 'room.info') end
          function status(data) cache.values['char.status']=data; handlers['AardwolfToolbox.gmcp.updated']('', 'char.status') end
          function scan(names)
            receive('{scan}'); receive('Right here you see:')
            for _,name in ipairs(names) do receive('     - '..name) end
            receive('{/scan}')
          end
        ''')

    def test_owned_scan_refresh_and_disconnect_cleanup(self):
        self.service()
        self.lua.execute('''
          room(12); pulse(); assert(sent[1]=='tags scan on' and sent[2]=='scan here')
          scan({'a rat','a rat'}); assert(m.snapshot().fresh and m.snapshot().rows[1].alive==1 and #m.snapshot().rows==2)
          status({state=8,enemy='a rat',enemypct=30}); status({enemypct=0})
          assert(m.snapshot().rows[1].possibleTarget and m.snapshot().rows[1].health==nil)
          receive("A rat's bite hits you."); assert(m.snapshot().rows[1].possibleAttacker)
          receive('A rat is DEAD!!'); assert(m.snapshot().rows[1].killed==1)
          m.start(); assert(calls==1)
          handlers['sysDisconnectionEvent'](); assert(#m.snapshot().rows==0)
          m.stop(); m.stop(); assert(next(handlers)==nil and next(timers)==nil)
        ''')

    def test_guarded_local_selection_never_sends_commands(self):
        self.service()
        self.lua.execute('''          room(12); pulse(); scan({'a frog','a frog'})
          local s=m.snapshot(); local count=#sent
          assert(m.select(s.rows[2].id,s.revision)); assert(m.selected().ordinal==2 and #sent==count)
          local selected=m.selected(); selected.name='mutation'; assert(m.selected().name=='a frog')
          cache.values['char.status.state']=5; assert(not m.select(s.rows[1].id,s.revision))
          cache.values['char.status.state']=3; m.clearSelection(); assert(not m.selected())
          room(13); assert(not m.select(s.rows[2].id,s.revision))
          online=false; assert(not m.select(s.rows[1].id,s.revision)); assert(#sent==count)
        ''')

    def test_readiness_room_change_and_timeout(self):
        self.service()
        self.lua.execute('''
          online=false; room(12); pulse(); assert(#sent==0 and not m.refresh())
          online=true; cache.values['char.status.state']=8; pulse(); assert(#sent==0)
          cache.values['char.status.state']=3; pulse(); assert(#sent==2)
          receive('{scan}'); receive('Right here you see:'); receive('     - a rat')
          room(13); receive('{/scan}'); assert(#m.snapshot().rows==0)
          now=110; pulse(); pulse(); assert(not m.snapshot().fresh and m.last:find('timed out'))
          local count=#sent; now=140; pulse(); assert(#sent==count)
          assert(m.refresh()); pulse(); scan({}); assert(m.snapshot().fresh)
          m.stop()
        ''')

    def test_independence_from_generic_tags_and_settings_validation(self):
        self.service()
        self.lua.execute('''
          room(12); pulse(); receive('{scan}'); receive('Right here you see:')
          local claimed,gag,forward=receive('     - a rat')
          assert(claimed and gag and forward=='AardwolfToolbox.tags')
          receive('{/scan}'); assert(m.snapshot().rows[1].name=='a rat')
          options.interval=1; assert(not Mobs.definition(function() end).validate(options))
          options.interval=10; assert(Mobs.definition(function() end).validate(options))
          options.target_color='red'; assert(not Mobs.definition(function() end).validate(options))
          m.stop()
        ''')

class MobUITests(unittest.TestCase):
    def setUp(self):
        from check_package import PackageTests
        self.package=PackageTests(); self.package.setUp()
        self.addCleanup(self.package.doCleanups)
        self.lua=self.package.lua
        self.lua.execute('AardwolfToolbox.start()')

    def test_fonts_layout_preferences_and_cleanup(self):
        self.lua.execute('''
          local t=AardwolfToolbox; local c=t.config
          assert(t.mobs.enabled and not c.runtimeErrors.mobs)
          local pane=widgets['AardwolfToolbox.mobs.pane']; assert(pane and not pane.hidden)
          local row=widgets['AardwolfToolbox.mobs.row1']; assert(row.renderedFontSize==12)
          assert(c.set('appearance','preset','large')); fire('AardwolfToolbox.ui.changed'); assert(row.renderedFontSize>=14)
          assert(c.set('mobs','width',300)); assert(borderLeft==300)
          assert(not c.set('mobs','attacker_color','red'))
          assert(c.set('mobs','blink',true)); assert(c.get('mobs','blink'))
          assert(c.set('mobs','enabled',false)); assert(borderLeft==0 and not widgets['AardwolfToolbox.mobs.pane'])
          assert(c.set('mobs','enabled',true)); assert(borderLeft==300)
          t.stop(); assert(borderLeft==0 and count(widgets)==0)
        ''')

    def test_card_callbacks_escape_text_and_reject_changed_rows(self):
        with zipfile.ZipFile(ROOT/'build/AardwolfToolbox.mpackage') as z:
            self.lua.globals().MobPane=self.lua.execute(z.read('mob-pane.lua').decode())
        self.lua.execute('''          local t=AardwolfToolbox; local c=t.config
          assert(c.set('mobs','enabled',false))
          local values=c.draft().mobs; local selected={}
          local pane=MobPane.new(_G,t.ui,t.borders,function() end,function() end,
            function(id,revision) selected[#selected+1]={id=id,revision=revision} end,function() end)
          pane.configure(values)
          local snapshot={fresh=true,updated=0,revision=4,rows={
            {id=10,name='a frog',flags='(Hidden)',alive=1,killed=0,missing=0,ordinal=1,duplicates=2},
            {id=11,name='Élan <red> & friends',flags='',alive=1,killed=0,missing=0}}}
          pane.update(snapshot,'Visible mobs · current visit')
          local first=widgets['AardwolfToolbox.mobs.row1']; local second=widgets['AardwolfToolbox.mobs.row2']
          assert(second.text:find('&lt;red&gt;') and second.text:find('&amp;'))
          assert(first.text:find('#1') and first.renderedFontSize==12)
          first.callback({button='LeftButton'}); assert(#selected==0)
          first.doubleClickCallback({button='LeftButton'}); assert(#selected==1 and selected[1].id==10)
          first.callback({button='LeftButton'}); snapshot.revision=5; snapshot.rows[1].id=20
          pane.update(snapshot,'Visible mobs · current visit')
          first.doubleClickCallback({button='LeftButton'}); assert(#selected==1)
          second.callback({button='LeftButton'}); second.doubleClickCallback({button='RightButton'}); assert(#selected==1)
          snapshot.rows[2].alive=0; snapshot.rows[2].killed=1; pane.update(snapshot,'Visible mobs · current visit')
          second.callback({button='LeftButton'}); second.doubleClickCallback({button='LeftButton'}); assert(#selected==1)
          local old=first.doubleClickCallback; first.callback({button='LeftButton'}); pane.destroy(); old({button='LeftButton'})
          assert(#selected==1 and not widgets['AardwolfToolbox.mobs.pane'])
        ''')

    def test_ascii_help_precedence_and_one_dispatcher(self):
        self.lua.execute('''
          assert(count(triggers)==1)
          local t=AardwolfToolbox
          incoming('<MAPSTART>'); incoming('{scan}'); incoming('Right here you see:'); incoming('     - a dragon'); incoming('{/scan}'); incoming('<MAPEND>')
          assert(#t.mobs.snapshot().rows==0)
          incoming('{help}'); incoming('{helpbody}'); incoming('A rat is DEAD!!'); incoming('{/helpbody}'); incoming('{/help}')
          assert(#t.mobs.snapshot().rows==0 and count(triggers)==1)
          t.stop()
        ''')

if __name__=='__main__': unittest.main()
