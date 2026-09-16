"""Mob action contracts and retained-widget callbacks against the built package."""
import unittest
import check_mobs as baseline
import check_actions as action_baseline


class MobActionTests(unittest.TestCase):
    setUp = baseline.MobTests.setUp
    service = baseline.MobTests.service

    def test_templates_are_literal_bounded_and_require_target(self):
        self.lua.execute('''
          assert(MobActions.preview('cast 123 {target}','2.bat')=='cast 123 2.bat')
          assert(MobActions.preview('alias {target} with {target}','1.Élan%<red>')=='alias 1.Élan%<red> with 1.Élan%<red>')
          assert(MobActions.preview('{target} suffix','1.bat')=='1.bat suffix')
          for _,v in ipairs({'','kill','kill {name}','kill {target} {other}','kill {target} {','kill {target}\\nlook','kill {target}\\0'}) do
            assert(not MobActions.preview(v,'2.bat'),v)
          end
          assert(not MobActions.preview(string.rep('x',1017)..'{target}','2.bat')) -- input too long
          assert(not MobActions.preview(string.rep('x',1015)..'{target}',string.rep('x',11))) -- resolved too long
          assert(not MobActions.preview('kill {target}','bad\\nname'))
          assert(MobActions.preview('say {target}; punctuation','1.bat')=='say 1.bat; punctuation')
        ''')

    def test_double_click_modes_alias_and_explicit_attack_api(self):
        self.service()
        self.lua.execute('''
          aliases={};function expandAlias(cmd) aliases[#aliases+1]=cmd end
          room(12);scan({'a small bat','a large bat','Élan <red>'});pulse(.05)
          local s=m.snapshot();local row=s.rows[2];local n=#sent
          assert(m.doubleClick(row.id,s.revision));assert(sent[#sent]=='kill 2.bat' and #sent==n+1)
          assert(m.snapshot().rows[2].requested and not m.snapshot().rows[2].target)
          m.clearSelection();options.double_click='@disabled';m.configure(options)
          n=#sent;assert(m.doubleClick(row.id,s.revision));assert(#sent==n and not m.selected())
          options.double_click='@select';m.configure(options)
          assert(m.doubleClick(row.id,s.revision));assert(m.selected().id==row.id and #sent==n)
          options.mob_actions[2].mode='alias';options.mob_actions[2].command='myalias {target} extra'
          options.double_click='consider';m.configure(options)
          assert(m.doubleClick(row.id,s.revision));assert(#aliases==1 and aliases[1]=='myalias 2.bat extra' and #sent==n)
          options.double_click='@disabled';m.configure(options)
          assert(m.attack(row.id,s.revision) and sent[#sent]=='kill 2.bat')
          options.mob_actions[1].enabled=false;options.double_click='attack';m.configure(options)
          n=#sent;assert(not m.doubleClick(row.id,s.revision) and #sent==n)
          assert(not m.activateAction('missing',row.id,s.revision))
          m.stop()
        ''')

    def test_guards_queues_targets_and_transport_failures(self):
        self.service()
        self.lua.execute('''
          room(12);scan({'a small bat','a large bat'});pulse(.05)
          local s=m.snapshot();local row=s.rows[2]
          queries.acquire=function() return false end
          assert(m.refresh());spellup.status=function() return {inflight=true} end;local n=#sent
          assert(m.activateAction('consider',row.id,s.revision));assert(sent[#sent]=='consider 2.bat' and #sent==n+1)
          assert(not m.snapshot().rows[2].requested and not m.snapshot().rows[2].target)
          for _,state in ipairs({1,2,4,5,6,7,9,11,99}) do
            cache.values['char.status.state']=state;n=#sent
            assert(not m.activateAction('attack',row.id,s.revision) and #sent==n)
          end
          cache.values['char.status.state']=8;assert(m.activateAction('attack',row.id,s.revision))
          online=false;assert(not m.activateAction('attack',row.id,s.revision));online=true
          function send() return false end
          assert(not m.activateAction('attack',row.id,s.revision))
          function send() error('transport failure') end
          assert(not m.activateAction('attack',row.id,s.revision))
          room(13);assert(not m.activateAction('attack',row.id,s.revision));m.stop()
        ''')

    def test_tokens_reject_configuration_session_and_roster_changes(self):
        self.lua.execute('''
          state.observe({{name='a bat'}})
          local session,visit,configuration=1,1,1
          local values={double_click='attack',mob_actions=MobActions.settings()[3].default}
          local sent={};local a=MobActions.new({send=function(s) sent[#sent+1]=s end},{
            context=function() return {session=session,visit=visit,configuration=configuration,revision=state.revision} end,
            row=function(id) for _,r in ipairs(state.rows) do if r.id==id then return r end end end,
            options=function() return values end,ready=function() return true end,
            feedback=function() end,observed=state.command,select=state.select})
          local s=state.snapshot(12);local token=a.capture(s.rows[1].id,s.revision)
          state.enemy('a bat',true,90);assert(a.resolve(token))
          assert(not state.observe({{name='a bat'}}));assert(a.resolve(token))
          configuration=2;assert(not a.activate('attack',token));configuration=1
          visit=2;assert(not a.activate('attack',token));visit=1
          session=2;assert(not a.activate('attack',token));session=1
          state.kill('a bat');assert(not a.activate('attack',token) and #sent==0)
        ''')


class MobActionUITests(unittest.TestCase):
    def setUp(self):
        action_baseline.ActionTests.setUp(self)
        self.lua.execute('''
          mudlet.key.Escape=16777216;mudlet.key.Return=16777220;mudlet.key.Up=16777235;mudlet.key.Down=16777237
          t=AardwolfToolbox;m=t.mobs;gmcp={char={}}
          function flushPaint()
            -- Only the mob's pending UI callback; no background acquisition is run.
            fire('AardwolfToolbox.ui.changed')
          end
          function roster(names)
            gmcp.char.status={state=3,pos='Standing'};fire('gmcp.char','gmcp.char.status')
            gmcp.room={info={num=321}};fire('gmcp.room','gmcp.room.info')
            incoming('{scan}');incoming('Right here you see:')
            for _,name in ipairs(names) do incoming('     - '..name) end
            incoming('{/scan}')
            local s=m.snapshot();assert(s.fresh)
            m.select(s.rows[1].id,s.revision);m.clearSelection()
            return s
          end
          function mobCard(id) for _,w in pairs(widgets) do if w.entry and w.entry.id==id then return w end end end
          function right(id) mobCard(id).callback({button='RightButton'}) end
          function menuItem(text)
            for _,w in pairs(widgets) do if w.name:match('mobs.menuItem') and w.text==text then return w end end
          end
          function keyCode(code) for _,k in pairs(keys) do if k.key==mudlet.key[code] then return k end end end
          s=roster({'a small bat','a large bat','Élan <red> & friends'})
        ''')

    def test_defaults_menu_order_escape_clamping_and_literal_text(self):
        self.lua.execute('''
          function getMousePosition() return 1190,790 end
          assert(c.get('mobs','context_menu') and c.get('mobs','double_click')=='attack')
          local n=#sent;right(s.rows[2].id)
          assert(m.menuOpen and #sent==n and not m.selected())
          assert(widgets['AardwolfToolbox.mobs.menuTitle'].text=='a large bat · 2.bat')
          assert(widgets['AardwolfToolbox.mobs.menuItem1'].text=='Attack')
          assert(widgets['AardwolfToolbox.mobs.menuItem2'].text=='Consider')
          assert(menuItem('Attack').tooltip=='command: kill 2.bat')
          local menu=widgets['AardwolfToolbox.mobs.menu'];assert(menu.x>=0 and menu.y>=0 and menu.x+menu.width<=1200 and menu.y+menu.height<=800)
          assert(menuItem('Attack').height>=32 and menuItem('Attack').renderedFontSize==12)
          local escape=keyCode('Escape').fn;escape();assert(not m.menuOpen and not widgets['AardwolfToolbox.mobs.menu'] and count(keys)==0)
          escape();assert(#sent==n)
          right(s.rows[3].id);assert(widgets['AardwolfToolbox.mobs.menuTitle'].text:find('&lt;red&gt; &amp;'))
          menuItem('Close').callback();assert(#sent==n)
          right(s.rows[2].id);menuItem('Consider').callback();assert(sent[#sent]=='consider 2.bat' and #sent==n+1 and not m.menuOpen)
          assert(not m.snapshot().rows[2].requested)
        ''')

    def test_stale_menu_and_double_click_health_membership_configuration(self):
        self.lua.execute('''
          local card=mobCard(s.rows[2].id);local n=#sent
          card.callback({button='LeftButton'})
          gmcp.char.status={state=8,enemy='a large bat',enemypct=70};fire('gmcp.char','gmcp.char.status')
          card.doubleClickCallback({button='LeftButton'});assert(sent[#sent]=='kill 2.bat' and #sent==n+1)
          card.doubleClickCallback({button='LeftButton'});assert(#sent==n+1)
          right(s.rows[2].id);local old=menuItem('Attack').callback
          assert(c.set('mobs','double_click','@select'));assert(not m.menuOpen)
          n=#sent;old();assert(#sent==n)
          card.callback({button='LeftButton'});assert(c.set('mobs','double_click','consider'))
          card.doubleClickCallback({button='LeftButton'});assert(#sent==n)
          right(s.rows[2].id);old=menuItem('Attack').callback
          gmcp.char.status={state=8,enemy='a large bat',enemypct=1};fire('gmcp.char','gmcp.char.status');incoming('You receive 75 experience points.');assert(not m.menuOpen);old();assert(#sent==n)
          assert(not m.activateAction('attack',s.rows[2].id,s.revision))
          right(s.rows[1].id);old=menuItem('Attack').callback
          gmcp.room.info={num=322};fire('gmcp.room','gmcp.room.info');assert(not m.menuOpen);old();assert(#sent==n)
        ''')

    def test_shortcut_suspension_editors_and_independent_action_bar(self):
        self.lua.execute('''
          assert(c.set('actions','buttons',{action('heal','heal','F8')}));local k=keyCode('F8')
          right(s.rows[2].id);assert(k.disabled);local n=#sent;k.fn();assert(#sent==n)
          menuItem('Configure actions').callback();assert(t.settingsWindow.opened and k.disabled and not m.menuOpen)
          t.settingsWindow.close();assert(not k.disabled)
          right(s.rows[2].id);keyCode('Escape').fn();assert(not k.disabled)
          assert(c.set('actions','enabled',false));assert(count(keys)==0)
          right(s.rows[2].id);menuItem('Attack').callback();assert(sent[#sent]=='kill 2.bat')
          assert(c.set('mobs','context_menu',false));right(s.rows[1].id);assert(not m.menuOpen)
        ''')

    def test_keyboard_menu_and_teardown_failed_creation(self):
        self.lua.execute('''
          right(s.rows[2].id);local n=#sent;keyCode('Escape').fn();assert(#sent==n)
          right(s.rows[2].id);menuItem('Consider').callback()
          assert(#sent==n+1 and sent[#sent]=='consider 2.bat' and count(keys)==0)
          right(s.rows[2].id);local old=menuItem('Attack').callback
          m.stop();assert(not m.menuOpen and not widgets['AardwolfToolbox.mobs.menu'] and count(keys)==0)
          old();assert(#sent==n+1);m.start();roster({'a small bat','a large bat'})
          local current=m.snapshot();keyFailure=true;right(current.rows[2].id)
          assert(not m.menuOpen and count(keys)==0 and not widgets['AardwolfToolbox.mobs.menu'])
          keyFailure=false;right(current.rows[2].id);t.stop();assert(count(keys)==0 and count(widgets)==0)
        ''')

    def test_records_preview_reference_validation_persistence_and_drafts(self):
        self.lua.execute('''
          local list=c.get('mobs','mob_actions');list[1].command='bash {target}'
          assert(c.get('mobs','mob_actions')[1].command=='kill {target}')
          local invalid,ir=c.draft();invalid.mobs.mob_actions=42;assert(not c.apply(invalid,ir))
          local d,r=c.draft();table.remove(d.mobs.mob_actions,1);assert(not c.apply(d,r))
          d.mobs.double_click='consider';assert(c.apply(d,r));assert(c.get('mobs','double_click')=='consider')
          local stored=yajl.to_value(files[c.path]);assert(stored.version==3)
          d,r=c.draft();d.mobs.mob_actions[1].command='cast {unknown}';assert(not c.apply(d,r))
          d.mobs.mob_actions[1].command='cast 123 {target}';fileFailures.write=true;assert(not c.apply(d,r));fileFailures.write=nil
          assert(c.get('mobs','mob_actions')[1].command=='consider {target}')
          assert(c.apply(d,r));d.mobs.mob_actions[1].command='mutated'
          assert(c.get('mobs','mob_actions')[1].command=='cast 123 {target}')
          t.openSettings();local w=t.settingsWindow;w.editRecord('mobs','mob_actions','consider')
          assert(widgetContaining('Preview: cast 123 2.bat'))
          local editor=widgetContaining('cast 123 {target}');editor.text='myalias {target}'
          local n=#sent;widgetContaining('Update preview (does not execute)').callback()
          assert(widgetContaining('Preview: myalias 2.bat') and #sent==n)
          w.close();assert(c.get('mobs','mob_actions')[1].command=='cast 123 {target}')
          t.openSettings();w.editRecord('mobs','mob_actions','consider');widgetContaining('Duplicate').callback();assert(w.apply())
          assert(#c.get('mobs','mob_actions')==2)
          widgetContaining('Move up').callback();assert(w.apply())
          local draft=c.draft().mobs;local refs=c.recordOptions('mobs','double_click',draft)
          assert(refs[3].value==draft.mob_actions[1].id and refs[4].value=='consider')
          assert(c.set('mobs','context_menu',false));assert(not w.apply());w.close()
          t.openSettings();w.select('mobs');w.restoreDefaults();w.close();assert(not c.get('mobs','context_menu'))
        ''')

    def test_all_action_settings_limits_modes_disabled_reference_and_reinstall(self):
        self.lua.execute('''
          local defaults=c.get('mobs','mob_actions')
          local list={};for i=1,48 do list[i]={id='entry_'..i,label='Action '..i,enabled=true,command='test {target}',mode='command'} end
          local d,r=c.draft();d.mobs.mob_actions=list;d.mobs.double_click='entry_1';assert(c.apply(d,r))
          list[49]={id='entry_49',label='Overflow',enabled=true,command='test {target}',mode='command'}
          assert(not c.set('mobs','mob_actions',list));list[49]=nil
          list[2].id='entry_1';assert(not c.set('mobs','mob_actions',list));list[2].id='entry_2'
          list[1].label=' ';assert(not c.set('mobs','mob_actions',list));list[1].label='Action 1'
          list[1].command='test {wrong}';assert(not c.set('mobs','mob_actions',list));list[1].command='test {target}'
          list[1].mode='lua';assert(not c.set('mobs','mob_actions',list));list[1].mode='alias'
          list[1].enabled=false;assert(c.set('mobs','mob_actions',list))
          local n=#aliasSent;assert(not m.doubleClick(s.rows[1].id,s.revision) and #aliasSent==n)
          right(s.rows[1].id);assert(not menuItem('Action 1'));menuItem('Close').callback()
          local saved=yajl.to_value(files[c.path]).values.mobs;t.stop();t.start()
          assert(yajl.to_value(files[t.config.path]).values.mobs.double_click==saved.double_click)
          assert(t.config.get('mobs','double_click')=='entry_1' and not t.config.get('mobs','mob_actions')[1].enabled)
          assert(not t.config.runtimeErrors.mobs)
        ''')

    def test_reference_editor_follows_draft_and_preview_enter_stays_local(self):
        self.lua.execute('''
          t.openSettings();local w=t.settingsWindow;w.editRecord('mobs','mob_actions','consider')
          local n=#sent;local editor=widgetContaining('consider {target}')
          editor.text='cast 123 {target}';editor.action(editor.text);assert(#sent==n)
          widgetContaining('Duplicate').callback()
          local reference=widgetContaining('Attack  ▸');assert(reference)
          reference.callback();assert(reference.text=='Consider  ▸')
          reference.callback();assert(reference.text=='Consider  ▸') -- new duplicate in the same draft
          assert(w.apply());assert(c.get('mobs','double_click')=='button_1')
          widgetContaining('Delete').callback();assert(widgetContaining('Action deleted — choose another  ▸'))
          assert(not w.apply());widgetContaining('Action deleted — choose another  ▸').callback()
          assert(w.apply() and c.get('mobs','double_click')=='@disabled');w.close()
        ''')

    def test_session_reset_unrelated_configuration_and_disabled_rows_close_menu(self):
        self.lua.execute('''
          local n=#sent;right(s.rows[2].id);local old=menuItem('Attack').callback
          assert(c.set('mobs','show_missing',true));old();assert(#sent==n and not m.menuOpen)
          right(s.rows[2].id);old=menuItem('Attack').callback
          assert(c.set('actions','keys_enabled',false));assert(not m.menuOpen);old();assert(#sent==n)
          local oldCard=mobCard(s.rows[2].id);oldCard.callback({button='LeftButton'})
          fire('AardwolfToolbox.gmcp.cleared');oldCard.doubleClickCallback({button='LeftButton'});assert(#sent==n)
          s=roster({'a small bat','a large bat'});gmcp.char.status={state=8,enemy='a large bat',enemypct=1};fire('gmcp.char','gmcp.char.status');incoming('You receive 75 experience points.');m.clearSelection();n=#sent
          right(s.rows[1].id);assert(m.menuOpen)
          local dead=mobCard(s.rows[2].id)
          -- Dead cards keep their presentation but carry no actionable entry.
          if not dead then for _,card in pairs(widgets) do if card.text and card.name:match('mobs.row') and card.text:find('a large bat',1,true) then dead=card end end end
          assert(dead and not dead.entry);dead.callback({button='RightButton'});assert(not m.menuOpen and #sent==n)
          dead.callback({button='LeftButton'});dead.doubleClickCallback({button='LeftButton'});assert(#sent==n)
        ''')
