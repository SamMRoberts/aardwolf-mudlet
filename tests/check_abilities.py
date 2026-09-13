"""Ability selection and actual SQLite transaction contracts (Lua 5.1)."""
from pathlib import Path
import unittest
import zipfile
from lupa.lua51 import LuaRuntime
from lua_support import install_json, install_sqlite

ROOT = Path(__file__).resolve().parents[1]


class AbilityTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        install_json(self.lua)
        self.addCleanup(install_sqlite(self.lua))
        with zipfile.ZipFile(ROOT / 'build/AardwolfToolbox.mpackage') as archive:
            for name, var in [('ability-store', 'Store'), ('ability-model', 'Model'),
                              ('ability-fields', 'Fields'), ('ability-picker', 'Picker'),
                              ('query-coordinator', 'Queries'), ('abilities', 'Abilities'), ('ability-capture', 'Capture')]:
                self.lua.globals()[var] = self.lua.execute(archive.read(name + '.lua').decode())
        self.lua.execute('''
          function getMudletHomeDir() return '/profile' end
          store=Store.new(_G); assert(store.open('test')); store.select('Tesobi')
          function row(id,level)
            return {id=id,name='Ability '..id,kind='spell',level=level,cost=0,resource='mana',learned=true,
              practice=100,targeting='single',command='cast '..id,memberships={{role='damage',type='fire'}}}
          end
          button={ability_mode='highest',ability_role='damage',ability_type='fire',ability_kind='both',
            ability_targeting='single',arguments=''}
        ''')

    def test_sqlite_character_isolation_reload_and_defensive_rows(self):
        self.lua.execute('''
          store.replace({abilities={[10]=row(10,20)}})
          local r=store.get('abilities',10); r.name='Changed'
          assert(store.get('abilities',10).name=='Ability 10')
          store.select('Other'); assert(#store.rows('abilities')==0)
          store.replace({abilities={[11]=row(11,30)}})
          store.select('TESOBI'); assert(store.get('abilities',10).cost==0)
          store.close('test'); assert(store.open('test'))
          assert(store.character()=='tesobi' and #store.rows('abilities')==1)
          store.select("O'Brien"); store.replace({abilities={[12]=row(12,30)}})
          assert(store.get('abilities',12).name=='Ability 12')
          store.destroy()
        ''')

    def test_failed_snapshot_rolls_back_all_buckets(self):
        self.lua.execute('''
          store.replace({abilities={[1]=row(1,10)},spells={[2]=row(2,20)}})
          local ok=pcall(store.replace,{abilities={[3]=row(3,30)},spells={bad=row(4,40)}})
          assert(not ok)
          assert(store.get('abilities',1) and not store.get('abilities',3))
          assert(store.get('spells',2))
          local huge=row(4,40); huge.name=string.rep('a',1048577)
          assert(not pcall(store.replace,{abilities={[4]=huge}}))
          assert(store.get('abilities',1))
        ''')

    def test_missing_cost_is_not_zero(self):
        self.lua.execute('''
          local r=row(1,10); r.cost=nil; r.resource=nil
          store.replace({abilities={[1]=r,[2]=row(2,20)}})
          assert(store.get('abilities',1).cost==nil)
          assert(store.get('abilities',2).cost==0)
        ''')

    def test_selection_ties_targeting_and_eligibility(self):
        self.lua.execute('''
          local rows={row(9,100),row(7,100),row(2,105)}
          assert(Model.resolve(rows,button,100)=='cast 7')
          rows[2].passive=true; assert(Model.resolve(rows,button,100)=='cast 9')
          rows[1].targeting='area'; assert(not Model.resolve(rows,button,100))
          rows[1].targeting='single'; rows[1].command=nil
          assert(not Model.resolve(rows,button,100))
          rows[1].command='cast 9'; rows[1].level=nil
          assert(not Model.resolve(rows,button,100))
          rows[1].level=100; rows[1].learned=false
          assert(not Model.resolve(rows,button,100))
          rows[1].learned=true; button.arguments='Möb <blue> & ; target'
          assert(Model.resolve(rows,button,100)=='cast 9 Möb <blue> & ; target')
          button.arguments='mob\\nkill'; assert(not Model.resolve(rows,button,100))
        ''')

    def test_role_separation_multiple_corrections_and_literal_search(self):
        self.lua.execute('''
          local original=row(1,10)
          local fixed=Model.correct(original,{
            {character='Tesobi',ability_id=1,role='protection',ability_type='Fire'},
            {character='Tesobi',ability_id=1,role='damage',ability_type='Light'},
            {character='Tesobi',ability_id=1,role='damage',ability_type='Bash'},
          },'tesobi')
          assert(Model.matches(fixed,{role='protection',type='fire'}))
          assert(not Model.matches(fixed,{role='damage',type='fire'}))
          assert(Model.matches(fixed,{role='damage',type='bash'}))
          assert(Model.matches(fixed,{role='damage',type='light'}))
          assert(Model.matches(original,{role='damage',type='fire'}))
          fixed.name='Élan [%]'; assert(Model.matches(fixed,{search='[%]'}))
          assert(not Model.matches(fixed,{search='.*'}))
        ''')

    def test_picker_results_preview_and_local_draft(self):
        self.lua.execute('''
          local buttons,texts={},{}
          local a={last='Saved catalog',list=function() return {row(1,10)} end,
            types=function() return {'fire'} end,preview=function() return 'cast 1' end,
            status=function() return {character='tesobi'} end}
          local record={ability_mode='specific',ability_id=1,label='New button',ability_role='damage',
            ability_kind='both',ability_targeting='single',ability_type='fire',arguments=''}
          local corrections={}
          Picker.render(a,record,corrections,{}, {capture=function() end,redraw=function() end,
            feedback=function() end,field=function() end,selectCorrections=function() end,
            button=function(text,fn) buttons[text]=fn end,text=function(text) texts[#texts+1]=text end})
          assert(texts[#texts]=='Command preview: cast 1')
          buttons['Ability 1 (#1) · Lv 10 · 0 mana']()
          assert(record.label=='Ability 1' and record.ability_id==1)
          buttons['Add local type correction for #1']()
          assert(#corrections==1 and corrections[1].ability_type=='fire')
          buttons['Use regular command / alias'](); assert(record.ability_mode=='manual')
        ''')

    def test_query_ownership_releases_after_callback_and_teardown(self):
        self.lua.execute('''
          local callbacks={}; local n=0; events={}
          function tempTimer(_,fn) n=n+1; callbacks[n]=fn; return n end
          function killTimer(id) callbacks[id]=nil end
          function raiseEvent(event) events[#events+1]=event end
          local q=Queries.new(_G)
          assert(q.acquire('spells')); assert(not q.acquire('abilities'))
          q.release('abilities'); assert(q.owner()=='spells')
          q.release('spells'); assert(q.owner()==nil and #events==0)
          callbacks[1](); assert(events[1]=='AardwolfToolbox.queries.available')
          assert(q.acquire('abilities')); q.release('abilities'); q.destroy()
          assert(not callbacks[2])
        ''')

    def test_v1_v2_record_migration_backups_and_cancel(self):
        self.lua.execute((ROOT / 'tests/settings_api.lua').read_text())
        with zipfile.ZipFile(ROOT / 'build/AardwolfToolbox.mpackage') as archive:
            self.lua.globals().Config = self.lua.execute(archive.read('configuration.lua').decode())
        self.lua.execute('''
          local fields={{key='label',label='Label',type='text',default='New'},
            {key='command',label='Command',type='text',default=''}}
          for _,f in ipairs(Fields.buttons()) do fields[#fields+1]=f end
          local definition={id='actions',label='Actions',settings={{key='buttons',label='Buttons',type='records',
            maxItems=48,default={},fields=fields}},apply=function() end}
          for _,version in ipairs({1,2}) do
            local old=yajl.to_string({version=version,values={actions={buttons={{id='heal',label='Heal',command='heal'}}},future={x='keep'}}})
            local path='/profile/AardwolfToolbox-settings.json'; files[path]=old
            local c=Config.new(_G); c.registerFeature(definition)
            local rows=c.get('actions','buttons'); assert(rows[1].ability_mode=='manual' and rows[1].command=='heal')
            local draft,rev=c.draft(); draft.actions.buttons[1].ability_mode='specific'
            assert(c.get('actions','buttons')[1].ability_mode=='manual')
            fileFailures.rename=true; assert(not c.apply(draft,rev)); fileFailures.rename=nil
            assert(files[path]==old and c.get('actions','buttons')[1].ability_mode=='manual')
            assert(c.apply(draft,rev)); assert(files[path..'.v'..version..'.bak']==old)
            local saved=yajl.to_value(files[path]); assert(saved.version==3 and saved.values.future.x=='keep')
            assert(not c.apply(draft,rev))
            local reread=Config.new(_G); reread.registerFeature(definition)
            assert(reread.get('actions','buttons')[1].ability_mode=='specific')
          end
        ''')

    def test_disk_backed_spell_apis_and_query_coordination(self):
        self.lua.execute((ROOT / 'tests/spells_api.lua').read_text())
        with zipfile.ZipFile(ROOT / 'build/AardwolfToolbox.mpackage') as archive:
            for name in ('incoming', 'spells'):
                self.lua.globals()[name.title()] = self.lua.execute(archive.read(name + '.lua').decode())
        self.lua.execute('''
          local originalGet=cache.get
          cache.get=function(path) if path=='char.base' then return {name='Tesobi'} end; return originalGet(path) end
          queries=Queries.new(_G); incoming=Incoming.new(_G)
          spells=Spells.new(_G,cache,incoming,nil,store,queries)
          assert(queries.acquire('abilities'))
          assert(spells.configure({enabled=true,automatic_setup=true})); advance(0)
          assert(#commands==0)
          queries.release('abilities'); advance(0); assert(commands[1]=='slist noprompt')
          synchronize(); assert(spells.isFresh())
          assert(spells.get(72).name=='Éowyn <red>')
          assert(next(spells.snapshot(false).catalog)==nil)
          assert(spells.snapshot().catalog[72].name=='Éowyn <red>')
          assert(spells.findByName('Éowyn <red>')[1].id==72)
          spells.stop(); queries.destroy()
          assert(not spells.get(72)); assert(store.get('spells',72))
        ''')

    def service(self):
        import json
        self.lua.execute((ROOT / 'tests/spells_api.lua').read_text())
        with zipfile.ZipFile(ROOT / 'build/AardwolfToolbox.mpackage') as archive:
            self.lua.globals().Incoming = self.lua.execute(archive.read('incoming.lua').decode())
        fixtures = json.loads((ROOT / 'tests/fixtures/ability-listings.json').read_text())
        self.lua.globals().fixtures = self.lua.table_from({k: self.lua.table_from(v) for k, v in fixtures.items()})
        self.lua.execute('''
          local originalSend=send
          send=function(command,...)
            raiseEvent('sysDataSendRequest',command)
            return originalSend(command,...)
          end
          cache.values['char.base']={name='Tesobi',level=127,class='Warrior'}
          cache.values['char.base.level']=127
          queries=Queries.new(_G); incoming=Incoming.new(_G)
          abilities=Abilities.new(_G,{},cache,incoming,nil,store,queries,Capture,Model)
          assert(abilities.configure({enabled=true,automatic_refresh=true,corrections={}})); advance(0.2)
          -- Protocol fixtures, not a live execution test. Unknown help is a
          -- completed unsupported response, never a guessed command.
          helpSyntax={bash='bash <target>',headbutt='headbutt <target>',uppercut='uppercut <target>',
            stomp='stomp <target>',bodycheck='bodycheck <target>'}
          function reply(command)
            if command:match('^echo AWTB_ABILITY_') then
              local name=commands[#commands-1]:match('^help (.*)$')
              assert(name)
              local syntax=helpSyntax[name]
              if syntax then
                feed('{help}'); feed('{helpkeywords}'..name); feed('{helpbody}')
                feed('Syntax: '..syntax); feed('{/helpbody}'); feed('{/help}')
              else feed('No help fixture for '..name) end
              feed(command:sub(6)); advance(0.2); return
            end
            local fixture=fixtures[command]
            if fixture then for _,text in ipairs(fixture) do feed(text) end
            else feed(command:match('^spells') and 'No spells found.' or 'No skills found.') end
            advance(0.2)
          end
          function nextGeneration()
            local before=#commands
            for _=1,200 do
              reply(commands[#commands])
              if #commands>before and commands[#commands]=='slist learned noprompt' then return end
            end
            error('A replacement refresh was not started')
          end
          function syncAbilities()
            for _=1,200 do
              if abilities.status().fresh and not abilities.status().busy then return end
              assert(abilities.status().busy,abilities.last)
              reply(commands[#commands])
            end
            error('Refresh did not finish')
          end
        ''')

    def test_verified_native_formats(self):
        import json
        fixtures = json.loads((ROOT / 'tests/fixtures/ability-listings.json').read_text())
        for command, lines in fixtures.items():
            with self.subTest(command=command):
                if command.startswith('slist'):
                    query = {'kind': 'learned'}
                elif command.startswith('showskill'):
                    query = {'kind': 'detail', 'id': int(command.split()[1])}
                else:
                    parts = command.split()
                    query = {'kind': parts[0][:-1], 'filter': parts[1] if len(parts) > 1 else ''}
                parser = self.lua.globals().Capture.new(self.lua.table_from(query))
                done = False
                for line in lines:
                    result = parser.receive(line)
                    claimed, done = result if isinstance(result, tuple) else (result, False)
                    self.assertTrue(claimed, line)
                self.assertTrue(done)

    def test_service_refresh_disk_resolution_and_disconnect(self):
        self.service()
        self.lua.execute('''
          syncAbilities(); assert(abilities.status().count>50 and queries.owner()==nil)
          local heal=abilities.get(54); assert(heal.cost==35 and heal.resource=='mana')
          assert(abilities.get(447).command=='uppercut')
          assert(abilities.get(447).cost==nil and not abilities.get(447).cost_known)
          assert(abilities.resolve(button)==nil) -- all available fire spells are unpracticed
          button.ability_type='bash'; button.ability_kind='skill'
          assert(abilities.resolve(button)=='headbutt')
          local rows=abilities.list({role='damage',type='bash'}); assert(#rows>1)
          rows[1].name='mutated'; assert(abilities.list({role='damage',type='bash'})[1].name~='mutated')
          local n=#commands; connected=false; raiseEvent('sysDisconnectionEvent'); advance(1)
          assert(not abilities.resolve(button) and #commands==n)
          assert(#abilities.list()>50 and abilities.get(54).cost==35)
          abilities.stop(); queries.destroy(); assert(next(timers)==nil and next(handlers)==nil and next(triggers)==nil)
        ''')

    def test_failed_refresh_keeps_previous_rows_and_unrelated_text_visible(self):
        self.service()
        self.lua.execute('''
          syncAbilities(); assert(abilities.refresh()); advance(0.2)
          feed('{spellheaders learned noprompt}'); feed('A friend says hello.')
          assert(visible[#visible]=='A friend says hello.')
          feed('28,malformed'); advance(0.2)
          assert(abilities.status().busy and queries.owner()=='AardwolfToolbox.abilities')
          feed('{/spellheaders}'); advance(0.2)
          assert(not abilities.status().fresh and not abilities.status().busy)
          assert(abilities.get(54).name=='heal')
          local n=#commands; advance(30); assert(#commands==n)
          assert(abilities.refresh()); advance(0.2); advance(11)
          assert(abilities.last:find('timed out') and abilities.get(54))
        ''')

    def test_status_level_refresh_uses_current_level_and_coalesces_base_catchup(self):
        self.service()
        self.lua.execute('''
          cache.values['char.status.level']=127
          syncAbilities()
          button.ability_type='bash'; button.ability_kind='skill'
          local old=abilities.resolve(button); assert(old)
          local n=#commands
          cache.values['char.status.state']=8
          update('char.status.level',128,'char.status'); advance(0.2)
          assert(not abilities.status().fresh and abilities.status().pending)
          assert(abilities.resolve(button)==old and #commands==n)
          -- The base producer still reports 127; repeated packets must not
          -- undo the status update or restart the pending collection.
          raiseEvent('AardwolfToolbox.gmcp.updated','char.base')
          update('char.status.state',3,'char.status'); advance(0.2)
          assert(commands[#commands]=='slist learned noprompt' and #commands==n+1)
          cache.values['char.base'].level=128; cache.values['char.base.level']=128
          raiseEvent('AardwolfToolbox.gmcp.updated','char.base'); advance(0.2)
          syncAbilities()
          assert(#commands==n+27 and store.get('ability_metadata',0).level==128)
          assert(abilities.status().fresh)
          raiseEvent('AardwolfToolbox.gmcp.updated','char.status'); advance(1)
          assert(#commands==n+27)
          abilities.stop(); queries.destroy(); assert(next(timers)==nil)
        ''')

    def test_level_changes_during_capture_drain_then_refresh_once(self):
        self.service()
        self.lua.execute('''
          feed('{spellheaders learned noprompt}')
          update('char.status.level',128,'char.status')
          update('char.status.level',129,'char.status')
          assert(#commands==1 and abilities.status().busy)
          -- Drain the current boundary, cancelling all unsent old queries.
          local lines=fixtures['slist learned noprompt']
          for i=2,#lines do feed(lines[i]) end
          advance(0.2)
          local second=#commands; assert(second==2 and commands[second]=='slist learned noprompt')
          assert(not abilities.status().fresh)
          syncAbilities(); assert(abilities.status().fresh)
          local learned=0;for _,cmd in ipairs(commands) do if cmd=='slist learned noprompt' then learned=learned+1 end end
          assert(learned==2)
          assert(store.get('ability_metadata',0).level==129)
        ''')

    def test_stale_failed_catalog_remains_usable_but_identity_and_level_are_required(self):
        self.service()
        self.lua.execute('''
          syncAbilities(); button.ability_type='bash'; button.ability_kind='skill'
          local expected=abilities.resolve(button); assert(expected)
          abilities.refresh(); advance(0.2)
          assert(abilities.resolve(button)==expected)
          advance(11); assert(not abilities.status().fresh)
          assert(abilities.resolve(button)==expected)
          connected=false; raiseEvent('sysDisconnectionEvent')
          assert(not abilities.resolve(button))
          cache.values['char.base']=nil; cache.values['char.base.level']=nil
          cache.values['char.status.level']=nil; connected=true
          assert(not abilities.resolve(button))
          cache.values['char.base']={name='Other',level=127}
          cache.values['char.base.level']=127
          assert(not abilities.resolve(button),'Never execute another character catalog')
          raiseEvent('AardwolfToolbox.gmcp.updated','char.base')
          assert(store.character()=='other' and not abilities.resolve(button))
        ''')

    def test_automatic_refresh_preference_and_invalid_level_packets(self):
        self.service()
        self.lua.execute('''
          syncAbilities(); local n=#commands
          abilities.configure({enabled=true,automatic_refresh=false,corrections={}})
          update('char.status.level',128,'char.status'); advance(1)
          assert(#commands==n and not abilities.status().fresh)
          abilities.configure({enabled=true,automatic_refresh=true,corrections={}})
          advance(0.2); syncAbilities(); n=#commands
          for _,value in ipairs({0,-1,1.5,'invalid',math.huge}) do
            update('char.status.level',value,'char.status'); advance(0.2)
          end
          assert(#commands==n and abilities.status().fresh)
        ''')

    def test_readiness_pause_progression_corrections_and_no_casts(self):
        self.service()
        self.lua.execute('''
          cache.values['char.status.state']=8
          reply(commands[#commands]); local n=#commands; advance(1); assert(#commands==n)
          update('char.status.state',3,'char.status'); advance(0.2); syncAbilities()
          local correction={id='c',label='Protection',character='Tesobi',ability_id=253,role='protection',ability_type='cold'}
          abilities.configure({enabled=true,automatic_refresh=true,corrections={correction}}); advance(0.2)
          assert(#abilities.list({role='protection',type='cold'})==1)
          assert(#abilities.list({role='damage',type='cold'})==0)
          cache.values['char.base'].level=128; cache.values['char.base.level']=128
          raiseEvent('AardwolfToolbox.gmcp.updated','char.base'); advance(0.2)
          assert(not abilities.status().fresh and commands[#commands]=='slist learned noprompt')
          for _,command in ipairs(commands) do assert(not command:match('^cast ') and command~='spellup learned retry') end
          abilities.configure({enabled=false,automatic_refresh=true,corrections={}})
          queries.destroy(); assert(not abilities.status().fresh and next(triggers)==nil)
        ''')

    def test_learning_during_refresh_is_coalesced_and_never_fresh_early(self):
        self.service()
        self.lua.execute('''
          feed('Your new skill level in fire blast is 32%.')
          nextGeneration()
          assert(not abilities.status().fresh and commands[#commands]=='slist learned noprompt')
          syncAbilities(); assert(abilities.status().fresh)
          local countBefore=#commands
          feed('You have become better at uppercut! (99%)'); advance(1)
          assert(#commands==countBefore)
        ''')

    def test_competing_query_and_pager_release_capture(self):
        self.service()
        self.lua.execute('''
          raiseEvent('sysDataSendRequest','spells combat')
          assert(abilities.status().busy and queries.owner()=='AardwolfToolbox.abilities')
          reply('slist learned noprompt')
          assert(not abilities.status().busy and not abilities.status().fresh)
          assert(queries.owner()==nil)
          abilities.refresh(); advance(0.2)
          update('char.status.state',6,'char.status')
          assert(abilities.status().busy and abilities.last:find('pager/editor'))
          reply('slist learned noprompt')
          assert(not abilities.status().busy)
          local n=#commands; advance(30); assert(#commands==n)
        ''')

    def test_coordinated_spell_queries_do_not_cancel_a_yielded_catalog_refresh(self):
        self.service()
        self.lua.execute('''
          local owner='AardwolfToolbox.spells'
          assert(not queries.acquire(owner))
          for _,text in ipairs(fixtures['slist learned noprompt']) do feed(text) end
          assert(queries.acquire(owner))
          send('slist noprompt',false)
          assert(abilities.status().busy,abilities.last)
          spellRows('')
          queries.release(owner); advance(0.2)
          syncAbilities(); assert(abilities.status().fresh)
          -- An uncoordinated request still invalidates the collected sequence,
          -- even between its individual responses.
          abilities.refresh(); advance(0.2)
          for _,text in ipairs(fixtures['slist learned noprompt']) do feed(text) end
          assert(queries.owner()==nil)
          send('skills combat',false)
          assert(not abilities.status().busy and abilities.last:find('interrupted'))
        ''')

    def test_levelup_and_manual_refresh_with_spell_tracker_discover_bodycheck(self):
        self.service()
        with zipfile.ZipFile(ROOT / 'build/AardwolfToolbox.mpackage') as archive:
            self.lua.globals().Spells = self.lua.execute(archive.read('spells.lua').decode())
        self.lua.execute('''
          syncAbilities()
          spells=Spells.new(_G,cache,incoming,nil,store,queries)
          assert(spells.configure({enabled=true,automatic_setup=true}))
          raiseEvent('AardwolfToolbox.gmcp.updated','char.base')
          function syncTogether()
            for _=1,100 do
              advance(0.2)
              if abilities.status().fresh and not abilities.status().busy and spells.isFresh() then return end
              local owner=queries.owner()
              assert(owner,abilities.last..' / '..spells.last)
              local command=commands[#commands]
              if owner=='AardwolfToolbox.spells' then
                if command=='slist noprompt' then
                  spellRows('',{'451,bodycheck,1,0,85,-1,2'})
                elseif command=='slist spellup noprompt' then spellRows('spellup',{})
                elseif command=='slist affected noprompt' then spellRows('affected',{})
                else
                  assert(command=='slist recoveries noprompt',command)
                  feed('{recoveries noprompt}'); feed('{/recoveries}')
                end
              else
                assert(owner=='AardwolfToolbox.abilities',owner)
                reply(command)
              end
            end
            error('Coordinated refresh did not finish: '..abilities.last)
          end
          syncTogether()
          assert(not abilities.get(451))
          -- Synthetic additions use the captured listing grammar. The learned
          -- identity/practice matches the saved server spell row; level/type
          -- here are fixtures, not newly observed player-profile listings.
          table.insert(fixtures['slist learned noprompt'],#fixtures['slist learned noprompt'],
            '451,bodycheck,1,0,85,-1,2')
          table.insert(fixtures['skills'],#fixtures['skills'],'Level 150: bodycheck                      85%')
          table.insert(fixtures['skills combat'],#fixtures['skills combat'],
            'Level 150: bodycheck                      85%  Bash')
          update('char.status.level',150,'char.status')
          cache.values['char.base'].level=150; cache.values['char.base.level']=150
          raiseEvent('AardwolfToolbox.gmcp.updated','char.base')
          assert(abilities.status().pending and not abilities.status().fresh)
          syncTogether()
          local bodycheck=abilities.get(451)
          assert(bodycheck and bodycheck.learned and bodycheck.available)
          assert(bodycheck.command=='bodycheck' and bodycheck.level==150)
          assert(bodycheck.cost==nil and not bodycheck.cost_known)
          assert(store.get('ability_metadata',0).level==150)
          button.ability_type='bash'; button.ability_kind='skill'; button.arguments='2.bat'
          local command,selected=abilities.resolve(button)
          assert(command=='bodycheck 2.bat' and selected.id==451)
          assert(abilities.refresh()); advance(0.2)
          assert(spells.sync(true)); advance(0)
          syncTogether()
          assert(abilities.resolve(button)=='bodycheck 2.bat')
          local saved=store.get('abilities',451)
          assert(saved.command_source=='help' and saved.command_syntax[1]=='bodycheck <target>')
          store.replace({abilities={[451]=saved}})
          assert(abilities.get(451).command=='bodycheck','Use persisted server syntax on reads')
          saved.id=999; store.replace({abilities={[999]=saved}})
          assert(not abilities.get(999).command,'Do not verify another skill identity')
          for _,sent in ipairs(commands) do
            assert(not sent:match('^bodycheck') and not sent:match('^cast '))
          end
          abilities.stop(); spells.stop(); queries.destroy()
          assert(next(handlers)==nil and next(triggers)==nil and next(timers)==nil)
        ''')

    def test_stomp_saved_catalog_command_specific_highest_and_guards(self):
        self.service()
        self.lua.execute('''
          syncAbilities()
          -- Persisted server verification survives reload and remains tied to
          -- this exact learned identity; reads cannot invent missing commands.
          local stomp={id=452,name='stomp',kind='skill',level=137,learned=true,
            command='stomp',command_source='help',command_name='stomp',command_id=452,
            practice=85,available=true,target=1,targeting='single',resource='unknown',
            cost_known=false,recovery=-1,memberships={{role='damage',type='bash'}}}
          local uppercut={id=447,name='uppercut',kind='skill',level=101,learned=true,
            available=true,targeting='single',command='uppercut',memberships={{role='damage',type='bash'}}}
          store.replace({abilities={[452]=stomp,[447]=uppercut},ability_metadata={[0]={level=146}}})
          cache.values['char.base.level']=146;cache.values['char.base'].level=146
          local original=store.get('abilities',452);assert(original.command=='stomp')
          assert(abilities.get(452).command=='stomp' and abilities.get(452).cost==nil)
          assert(abilities.get(452).targeting=='single')
          local list=abilities.list({role='damage',type='bash',kind='skill'})
          local found;for _,r in ipairs(list) do if r.id==452 then found=r end end
          assert(found and found.command=='stomp');found.command='bad'
          assert(abilities.get(452).command=='stomp' and store.get('abilities',452).command=='stomp')
          local b={ability_mode='highest',ability_role='damage',ability_type='bash',ability_kind='skill',ability_targeting='single',arguments='2.bat'}
          local before=#commands;local command,selected=abilities.preview(b)
          assert(command=='stomp 2.bat' and selected.id==452 and #commands==before)
          b.ability_mode='specific';b.ability_id=452;assert(abilities.preview(b)=='stomp 2.bat')
          assert(abilities.resolve(b)=='stomp 2.bat','Stale progression must allow a saved eligible ability')
          cache.values['char.base.level']=127;assert(not abilities.preview(b))
          b.ability_mode='highest';assert(abilities.preview(b)=='uppercut 2.bat')
          cache.values['char.base.level']=146
          stomp.passive=true;store.replace({abilities={[452]=stomp,[447]=uppercut}})
          assert(abilities.preview(b)=='uppercut 2.bat');stomp.passive=nil
          stomp.available=false;store.replace({abilities={[452]=stomp,[447]=uppercut}})
          assert(abilities.preview(b)=='uppercut 2.bat');stomp.available=true
          stomp.name='unverified skill';store.replace({abilities={[452]=stomp}})
          assert(not abilities.get(452).command and not abilities.preview(b))
          stomp.name='stomp';stomp.id=999;store.replace({abilities={[999]=stomp}})
          assert(not abilities.get(999).command and not abilities.preview(b))
          assert(#commands==before)
        ''')

    def test_stomp_refresh_persists_verified_command_and_resolves_fresh(self):
        self.service()
        self.lua.execute('''
          -- Synthetic additions use the previously verified listing grammar;
          -- these are not a new live capture.
          table.insert(fixtures['slist learned noprompt'],#fixtures['slist learned noprompt'],'452,stomp,1,0,85,-1,2')
          local function listing(key,text)
            local rows=fixtures[key];table.insert(rows,#rows,text)
          end
          listing('skills','Level 137: stomp                          85%')
          listing('skills combat','Level 137: stomp                          85%  Bash')
          cache.values['char.base.level']=146;cache.values['char.base'].level=146
          raiseEvent('AardwolfToolbox.gmcp.updated','char.base');advance(0.2)
          syncAbilities();assert(store.get('abilities',452).command=='stomp')
          local b={ability_mode='highest',ability_role='damage',ability_type='bash',ability_kind='skill',ability_targeting='single',arguments=''}
          local n=#commands;local command,selected=abilities.resolve(b)
          assert(command=='stomp' and selected.id==452 and #commands==n)
        ''')

    def test_dynamic_unlisted_skill_persistence_reuse_and_manual_reverification(self):
        self.service()
        self.lua.execute('''
          syncAbilities()
          local before=#commands
          -- Previously unknown name AND command: neither exists in package code.
          table.insert(fixtures['slist learned noprompt'],#fixtures['slist learned noprompt'],
            '70001,meteor jab,1,0,90,-1,2')
          table.insert(fixtures.skills,#fixtures.skills,'Level 128: meteor jab                     90%')
          table.insert(fixtures['skills combat'],#fixtures['skills combat'],
            'Level 128: meteor jab                     90%  Bash')
          helpSyntax['meteor jab']='meteorjab <target>'
          update('char.status.level',128,'char.status'); advance(0.2); syncAbilities()
          assert(#commands==before+29,'Only the new skill needs a help query and marker')
          local r=store.get('abilities',70001)
          assert(r.command=='meteorjab' and r.command_source=='help' and r.command_checked)
          assert(r.command_syntax[1]=='meteorjab <target>' and r.command_id==70001)
          button.ability_kind='skill'; button.ability_type='bash'; button.arguments='2.bat'
          assert(abilities.resolve(button)=='meteorjab 2.bat')
          -- Reopen the database, then reconnect. Static syntax survives; no
          -- complete help list is held in memory or collected on each login.
          abilities.stop(); store.close('test'); store.open('test')
          assert(abilities.configure({enabled=true,automatic_refresh=true,corrections={}}))
          before=#commands; advance(0.2); syncAbilities()
          assert(#commands==before+27 and abilities.resolve(button)=='meteorjab 2.bat')
          helpSyntax['meteor jab']='mj <target>'
          assert(abilities.refresh()); advance(0.2); syncAbilities()
          assert(abilities.resolve(button)=='mj 2.bat')
          helpSyntax['meteor jab']='mj <target> <weapon>'
          assert(abilities.refresh()); advance(0.2); syncAbilities()
          r=abilities.get(70001)
          assert(r and r.learned and not r.command and r.command_reason:find('custom arguments'))
          assert(#abilities.list({search='meteor jab'})==1,'Unsupported skills remain searchable')
          assert(abilities.resolve(button)=='headbutt 2.bat')
          local unknown={id=70002,name='invented',kind='skill',level=1,learned=true,available=true,
            targeting='single',memberships={}}
          store.replace({abilities={[70002]=unknown}})
          assert(not abilities.get(70002).command,'Never infer commands from names or IDs')
        ''')

    def test_help_parser_tagged_plain_multiline_and_unknown_syntax(self):
        self.lua.execute('''
          function parseHelp(lines,name)
            local c=Capture.new({kind='syntax',name=name or 'meteor jab',marker='END_fixture'})
            assert(not c.receive('A friend says hello.'))
            for _,line in ipairs(lines) do c.receive(line) end
            local claimed,done=c.receive('END_fixture'); assert(claimed and done)
            return c
          end
          local c=parseHelp({'{help}','{helpkeywords}',"'METEOR JAB'",'{/helpkeywords}',
            '{helpbody}','Syntax:','    meteorjab <target>','Description of the skill.',
            '{/helpbody}','{/help}'})
          assert(c.command=='meteorjab' and #c.syntax==1)
          c=parseHelp({'Help Keywords : Meteor Jab.','Help Category : Attack Skill.',
            'Last Updated : fixture','--------','Syntax: meteorjab [target]',
            'Description of the skill.','--------'})
          assert(c.command=='meteorjab')
          for _,syntax in ipairs({'mj <target> <weapon>','mj <foo>','mj;kill <target>','mj % target'}) do
            c=parseHelp({'{help}','{helpkeywords}meteor jab','{helpbody}','Syntax: '..syntax,'{/helpbody}','{/help}'})
            assert(not c.command and c.reason)
          end
          c=parseHelp({'{help}','{helpkeywords}meteor jab','{helpbody}',
            'Syntax: mj <target>','    other <target>','{/helpbody}','{/help}'})
          assert(not c.command and c.reason:find('multiple commands'))
          c=parseHelp({'{help}','{helpkeywords}unrelated','{helpbody}',
            'Syntax: unrelated <target>','{/helpbody}','{/help}'})
          assert(not c.command)
          c=parseHelp({'No help found.'}); assert(not c.command)
          c=Capture.new({kind='syntax',name='meteor jab',marker='END_fixture'})
          c.receive('{help}'); c.receive('{helpkeywords}meteor jab'); c.receive('{helpbody}')
          assert(not pcall(c.receive,'END_fixture'),'An incomplete response must not commit')
          c=Capture.new({kind='syntax',name='meteor jab',marker='END_fixture'})
          c.receive('{help}')
          assert(not pcall(c.receive,string.rep('x',1048577)))
        ''')

    def test_owned_help_precedes_pane_but_not_ascii_and_timeout_keeps_catalog(self):
        self.service()
        self.lua.execute('''
          syncAbilities()
          local old=store.get('abilities',447).command
          local paneLines={}; local ascii=false
          incoming.add('fixture.ascii',10,function(line)
            if line=='<MAPSTART>' then ascii=true end
            if ascii then if line=='<MAPEND>' then ascii=false end; return true,true end
          end,error)
          incoming.add('fixture.help',15,function(line)
            if line:match('^{/?help') then paneLines[#paneLines+1]=line; return true,true end
          end,error)
          abilities.refresh(); advance(0.2)
          for _=1,27 do reply(commands[#commands]) end
          assert(commands[#commands]:match('^echo AWTB_ABILITY_'))
          local marker=commands[#commands]:sub(6)
          local name=commands[#commands-1]:sub(6)
          feed('<MAPSTART>'); feed('{help}'); feed('Syntax: wrong <target>'); feed('<MAPEND>')
          feed('{help}'); feed('{helpkeywords}'..name); feed('{helpbody}')
          feed('Syntax: example <target>'); feed('{/helpbody}'); feed('{/help}')
          assert(#paneLines==0 and abilities.status().busy)
          local sent=#commands; advance(11)
          assert(not abilities.status().busy and abilities.status().fresh)
          assert(abilities.last:find('command verification incomplete'))
          assert(store.get('abilities',447).command==old and #commands==sent)
          feed(marker) -- A late completion cannot revive a failed transaction.
          assert(not abilities.status().busy)
          feed('{help}'); feed('{helpkeywords}USER'); feed('{helpbody}')
          assert(#paneLines==3,'Normal player help still belongs to the pane')
          abilities.stop(); incoming.remove('fixture.help'); incoming.remove('fixture.ascii')
          queries.destroy(); assert(next(timers)==nil and next(triggers)==nil)
        ''')

    def test_highest_picker_candidates_do_not_change_selection_mode(self):
        self.lua.execute('''
          local buttons,texts={},{}
          local stomp={id=452,name='stomp',kind='skill',level=137,command='stomp',targeting='single'}
          local a={last='Saved catalog',list=function() return {stomp} end,
            types=function() return {'bash'} end,preview=function() return 'stomp',stomp end}
          local record={ability_mode='highest',ability_id=0,label='Best Bash',ability_role='damage',
            ability_kind='skill',ability_targeting='single',ability_type='bash',arguments=''}
          local control={capture=function() end,redraw=function() end,feedback=function(message) error(message) end,
            field=function() end,selectCorrections=function() end,
            button=function(text,fn) buttons[text]=fn end,text=function(text) texts[text]=true end}
          Picker.render(a,record,{}, {},control)
          assert(not buttons['stomp (#452) · Lv 137 · cost unknown'])
          assert(texts['stomp (#452) · Lv 137 · cost unknown'])
          assert(texts['Automatic choice: stomp (#452) · Lv 137'] and texts['Command preview: stomp'])
          assert(record.ability_mode=='highest' and record.ability_id==0 and record.label=='Best Bash')
          record.ability_mode='specific';Picker.render(a,record,{}, {},control)
          buttons['stomp (#452) · Lv 137 · cost unknown']()
          assert(record.ability_id==452 and record.ability_mode=='specific')
        ''')
