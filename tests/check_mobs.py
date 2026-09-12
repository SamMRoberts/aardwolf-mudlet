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
          assert(s.rows[1].target and not s.rows[2].target and not s.rows[2].possibleTarget)
          assert(state.kill('a rat')); s=state.snapshot(12)
          assert(s.rows[1].killed==1 and not s.rows[1].uncertainDeath and s.rows[2].alive==1)
        ''')

    def test_numbered_target_intent_and_death_follow_the_selected_row(self):
        self.lua.execute("""
          state.observe({{name='a snake',count=4}})
          state.command('kill 4.snake'); state.enemy('a snake',true,90)
          local s=state.snapshot(12); assert(s.rows[4].target and not s.rows[1].target)
          state.enemy('a snake',true,80); assert(state.snapshot(12).rows[4].target)
          state.kill('a snake'); s=state.snapshot(12)
          assert(s.rows[4].killed==1 and s.rows[1].alive==1 and not s.rows[4].uncertainDeath)
          state.enemy('',false); state.command('k 2.snake'); state.enemy('a snake',true,60)
          assert(state.snapshot(12).rows[2].target)
          state.enemy('',false); state.command('kill snake'); state.enemy('a snake',true,50)
          assert(state.snapshot(12).rows[1].target)
          state.enemy('',false); state.command('kill 3.snake'); now=111
          state.enemy('a snake',true,40); assert(state.snapshot(12).rows[1].target)
          state.enemy('',false); state.command('get 3.snake'); state.enemy('a snake',true,30)
          assert(state.snapshot(12).rows[1].target)
          state.clear('13'); state.observe({{name='a snake',count=4}})
          state.enemy('a snake',true,10); assert(state.snapshot(12).rows[1].target)
        """)

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

    def test_duplicate_attackers_prefer_target_then_first_living_match(self):
        self.lua.execute("""
          state.observe({{name='a snake',count=3},{name='a bat',count=2}})
          state.command('kill 2.snake'); state.enemy('a snake',true,70)
          assert(not state.snapshot(12).rows[2].attacking)
          assert(state.attack('a snake') and state.attack('a bat'))
          local s=state.snapshot(12)
          assert(not s.rows[1].attacking and s.rows[2].attacking and not s.rows[3].attacking)
          assert(s.rows[4].attacking and not s.rows[5].attacking)
          for _,r in ipairs(s.rows) do assert(not r.possibleAttacker) end
          state.kill('a snake'); s=state.snapshot(12)
          assert(s.rows[2].killed==1 and not s.rows[2].attacking and not s.rows[1].attacking)
          state.enemy('a snake',true,60); state.attack('a snake')
          assert(state.snapshot(12).rows[1].attacking)
          now=113; for _,r in ipairs(state.snapshot(12).rows) do assert(not r.attacking) end
          state.attack('a snake'); state.enemy('',false)
          for _,r in ipairs(state.snapshot(12).rows) do assert(not r.attacking) end
          state.clear('13'); assert(#state.snapshot(12).rows==0)
        """)

    def test_selection_scan_order_and_stale_ids(self):
        self.lua.execute('''          state.observe({{name='a frog'},{name='a frog'},{name='a bat'}})
          local s=state.snapshot(12); local id,revision=s.rows[2].id,s.revision
          assert(state.select(id,revision)); assert(state.snapshot(12).rows[2].selected)
          state.enemy('a bat',true,70); assert(state.snapshot(12).rows[2].id==id)
          assert(state.attack('a frog')); s=state.snapshot(12)
          assert(s.rows[1].attacking and not s.rows[2].attacking and not s.rows[1].possibleAttacker)
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

    def test_nearby_scan_sections_duplicates_empty_and_bounds(self):
        self.lua.execute("""
          local s=Protocol.scan()
          s.line('Right here you see:'); s.line('     - a rat')
          s.line('North from here you see:'); s.line('     - a snake'); s.line('     - a snake')
          s.line('2 East from here you see:'); s.line('     - (Hidden) Élan <red> & friends')
          s.line('Up from here you see:')
          assert(#s.entries==1 and #s.sections==3 and #s.sections[1].entries==2)
          assert(s.sections[1].direction=='North' and s.sections[1].distance==nil)
          assert(s.sections[2].distance==2 and s.sections[2].entries[1].name=='(Hidden) Élan <red> & friends')
          assert(#s.sections[3].entries==0 and s.valid and s.seen)
          s=Protocol.scan(); assert(not pcall(s.line,'     - orphan'))
          s=Protocol.scan(); s.line('North from here you see:')
          assert(not pcall(s.line,'     - '..string.rep('x',513)))
          s=Protocol.scan(); s.line('North from here you see:')
          for i=1,512 do s.line('     - a rat') end
          assert(not pcall(s.line,'     - overflow'))
          s=Protocol.scan(); s.line('Right here you see:')
          assert(not pcall(s.line,'Somewhere from here you see:'))
        """)

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
          room(12); pulse(); assert(sent[1]=='tags scan on' and sent[2]=='scan')
          scan({'a rat','a rat'}); assert(m.snapshot().fresh and m.snapshot().rows[1].alive==1 and #m.snapshot().rows==2)
          status({state=8,enemy='a rat',enemypct=30}); status({enemypct=0})
          assert(m.snapshot().rows[1].target and m.snapshot().rows[1].health==0)
          receive("A rat's bite hits you."); assert(m.snapshot().rows[1].attacking and not m.snapshot().rows[2].attacking)
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

    def test_double_click_attack_command_and_outgoing_numbered_target(self):
        self.service()
        self.lua.execute("""
          room(12); pulse(); scan({'Élan <red> & friends','Élan <red> & friends'})
          local s=m.snapshot(); local count=#sent
          assert(m.attack(s.rows[2].id,s.revision))
          assert(#sent==count+1 and sent[#sent]=='kill 2.friends')
          status({state=8,enemy='Élan <red> & friends',enemypct=70})
          assert(m.snapshot().rows[2].target and not m.snapshot().rows[1].target)
          status({state=3,enemy=''})
          handlers.sysDataSendRequest('', 'kill 1.Élan <red> & friends')
          status({state=8,enemy='Élan <red> & friends'})
          assert(m.snapshot().rows[1].target)
          count=#sent; cache.values['char.status.state']=6
          assert(not m.attack(s.rows[2].id,s.revision) and #sent==count)
          cache.values['char.status.state']=3; online=false
          assert(not m.attack(s.rows[2].id,s.revision) and #sent==count)
          online=true; room(13)
          assert(not m.attack(s.rows[2].id,s.revision) and #sent==count)
        """)

    def test_attack_uses_last_word_and_preserves_number_and_display_name(self):
        self.service()
        self.lua.execute("""
          room(12); pulse()
          scan({'a tiny bat','a tiny bat','the caretaker','The Élan <red> & friends','A giant bat',
            'theatre guard','aardvark','Keeper of the gate','an owl','the warrior Élan','a <red>','a guard!'})
          local s=m.snapshot()
          local expected={'kill 1.bat','kill 2.bat','kill 1.caretaker','kill 1.friends',
            'kill 1.bat','kill 1.guard','kill 1.aardvark','kill 1.gate','kill 1.owl','kill 1.Élan','kill 1.<red>','kill 1.guard!'}
          for i,command in ipairs(expected) do
            local count=#sent
            assert(m.attack(s.rows[i].id,s.revision))
            assert(sent[#sent]==command and #sent==count+1)
            assert(m.snapshot().rows[i].name==s.rows[i].name)
          end
          assert(m.attack(s.rows[2].id,s.revision))
          status({state=8,enemy='a tiny bat',enemypct=50})
          assert(m.snapshot().rows[2].target and not m.snapshot().rows[1].target)
        """)

    def test_nearby_snapshot_is_separate_atomic_and_cleared_on_room_change(self):
        self.service()
        self.lua.execute("""
          room(12); pulse()
          receive('{scan}'); receive('Right here you see:'); receive('     - a rat')
          receive('North from here you see:'); receive('     - a snake'); receive('     - a snake'); receive('{/scan}')
          local s=m.snapshot(); assert(#s.rows==1 and s.nearby.fresh and #s.nearby.sections[1].entries==2)
          s.nearby.sections[1].entries[1].name='mutation'
          assert(m.snapshot().nearby.sections[1].entries[1].name=='a snake')
          assert(not receive('A snake is DEAD!!')); assert(m.snapshot().rows[1].alive==1)
          now=110; assert(m.refresh()); pulse(); receive('{scan}'); receive('North from here you see:')
          assert(m.snapshot().nearby.sections[1].entries[1].name=='a snake')
          pulse(); assert(not m.snapshot().nearby.fresh and #m.snapshot().nearby.sections==1)
          now=120; assert(m.refresh()); pulse(); receive('{scan}'); receive('East from here you see:'); receive('     - a bat'); receive('{/scan}')
          s=m.snapshot(); assert(s.nearby.fresh and not s.fresh and s.nearby.sections[1].direction=='East')
          assert(not m.attack(s.rows[1].id,s.revision))
          room(13); assert(#m.snapshot().nearby.sections==0 and not m.snapshot().nearby.fresh)
          options.nearby=false; assert(m.configure(options)); assert(m.refresh()); now=130; pulse()
          assert(sent[#sent]=='scan here'); scan({'a frog'})
          assert(m.snapshot().fresh and not m.snapshot().nearby.fresh)
          m.stop(); assert(#m.snapshot().nearby.sections==0)
        """)

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
          values.blink=true; pane.configure(values); snapshot.rows[2].attacking=true
          pane.update(snapshot,'Visible mobs · current visit',true)
          assert(second.text:find('Attacking you') and not second.text:find('Possible attacker'))
          assert(second.style:find(values.attacker_color,1,true) and second.style:find('#463322',1,true))
          assert(not first.style:find('#463322',1,true))
          pane.update(snapshot,'Visible mobs · current visit',true)
          assert(not second.style:find('#463322',1,true))
          values.blink=false; pane.configure(values); pane.update(snapshot,'Visible mobs · current visit',true)
          assert(not second.style:find('#463322',1,true))

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

    def test_compact_scan_inset_collapse_escape_and_cleanup(self):
        with zipfile.ZipFile(ROOT/'build/AardwolfToolbox.mpackage') as z:
            self.lua.globals().MobPane=self.lua.execute(z.read('mob-pane.lua').decode())
        self.lua.execute("""
          local t=AardwolfToolbox; assert(t.config.set('mobs','enabled',false))
          local values=t.config.draft().mobs
          local pane=MobPane.new(_G,t.ui,t.borders,function() end,function() end,function() error('Nearby attack') end,function() end)
          pane.configure(values)
          local s={rows={},nearby={fresh=true,updated=100,sections={{direction='North',distance=2,heading='2 North from here',entries={{name='Élan <red> & friends'},{name='Élan <red> & friends'}}}}}}
          s.nearby.sections[2]={direction='South',heading='South from here',entries={{name='a snake'}}}
          pane.update(s,'Visible mobs · current visit')
          local scan=widgets['AardwolfToolbox.mobs.scanBody']; local header=widgets['AardwolfToolbox.mobs.scanHeading']
          local first=widgets['AardwolfToolbox.mobs.scanRow2']; local second=widgets['AardwolfToolbox.mobs.scanRow3']
          assert(not scan.hidden and scan.height>160 and header.height>=32)
          assert(first.text:find('&lt;red&gt;') and first.text:find('&amp;') and second.text==first.text)
          assert(first.renderedFontSize>=11 and not first.doubleClickCallback and not first.callback)
          local north=widgets['AardwolfToolbox.mobs.scanRow1']; local south=widgets['AardwolfToolbox.mobs.scanRow4']
          assert(north.text:find('#80dfff') and south.text:find('#9fe3a8'))
          assert(north.style:find('border%-top: 1px') and south.y>=second.y+second.height+6)
          values.colors=false; pane.configure(values)
          assert(not north.text:find('#80dfff') and north.style:find('border%-top: 1px'))
          local body=widgets['AardwolfToolbox.mobs.body']; local oldHeight=body.height
          header.callback(); assert(scan.hidden and body.height>=oldHeight)
          header.callback(); assert(not scan.hidden)
          local n=count(widgets); pane.update(s,'Visible mobs · current visit',true); assert(count(widgets)==n)
          values.nearby=false; pane.configure(values); assert(scan.hidden and header.hidden)
          local old=header.callback; pane.destroy(); old(); assert(not widgets['AardwolfToolbox.mobs.scanBody'])
        """)

    def test_idle_refresh_is_cached_and_scan_follows_short_roster(self):
        with zipfile.ZipFile(ROOT/'build/AardwolfToolbox.mpackage') as z:
            self.lua.globals().MobPane=self.lua.execute(z.read('mob-pane.lua').decode())
        self.lua.execute("""
          local t=AardwolfToolbox; assert(t.config.set('mobs','enabled',false))
          local values=t.config.draft().mobs
          local pane=MobPane.new(_G,t.ui,t.borders,function() end,function() end,function() end,function() end)
          pane.configure(values)
          local s={fresh=true,updated=0,revision=1,rows={{id=1,name='Claire',flags='',alive=1,killed=0,missing=0}},
            nearby={fresh=true,updated=0,sections={{direction='East',heading='East from here',entries={{name='The receptionist'}}}}}}
          pane.update(s,'Visible mobs · current visit')
          local row=widgets['AardwolfToolbox.mobs.row1']; local body=widgets['AardwolfToolbox.mobs.body']
          local scan=widgets['AardwolfToolbox.mobs.scanBody']; local header=widgets['AardwolfToolbox.mobs.scanHeading']
          assert(not row.text:find('In room') and row.height>=32)
          assert(body.height<=row.height+16 and header.y==body.y+body.height+4)
          assert(scan.height>200 and widgets['AardwolfToolbox.mobs.status'].hidden)
          local scanY=header.y
          header.callback(); assert(scan.hidden and header.y==scanY,'Collapsing a short roster moved the scan heading')
          header.callback(); assert(not scan.hidden and header.y==scanY)
          local measures,mutations=0,0; local old=t.ui.measure
          t.ui.measure=function(...) measures=measures+1; return old(...) end
          for name,w in pairs(widgets) do
            if name:find('AardwolfToolbox.mobs.',1,true)==1 then
              for _,method in ipairs({'echo','setStyleSheet','move','resize','show','hide','setToolTip'}) do
                local original=w[method]; w[method]=function(self,...) mutations=mutations+1; return original(self,...) end
              end
            end
          end
          pane.update(s,'Visible mobs · current visit',true)
          assert(measures==0 and mutations==0,'Unchanged refresh touched native widgets')
          s.rows[1].attacking=true; values.blink=true; pane.configure(values)
          measures=0; pane.update(s,'Visible mobs · current visit',true)
          assert(measures==0,'Flashing recomputed row measurements')
          s.rows={}; s.nearby.sections={}; pane.update(s,'Visible mobs · current visit')
          assert(not widgets['AardwolfToolbox.mobs.scanRow2'])
          t.ui.measure=old; pane.destroy()
        """)

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
