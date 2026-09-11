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
          cache.values['char.base']={name='Tesobi',level=127,class='Warrior'}
          cache.values['char.base.level']=127
          queries=Queries.new(_G); incoming=Incoming.new(_G)
          abilities=Abilities.new(_G,{},cache,incoming,nil,store,queries,Capture,Model)
          assert(abilities.configure({enabled=true,automatic_refresh=true,corrections={}})); advance(0.2)
          function reply(command)
            local fixture=fixtures[command]
            if fixture then for _,text in ipairs(fixture) do feed(text) end
            else feed(command:match('^spells') and 'No spells found.' or 'No skills found.') end
            advance(0.2)
          end
          function syncAbilities()
            for _=1,80 do
              if abilities.status().fresh then return end
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
          assert(not abilities.status().fresh and not abilities.status().busy)
          assert(abilities.get(54).name=='heal')
          local n=#commands; advance(30); assert(#commands==n)
          assert(abilities.refresh()); advance(0.2); advance(11)
          assert(abilities.last:find('timed out') and abilities.get(54))
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
          for i=1,27 do reply(commands[#commands]) end
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
          assert(not abilities.status().busy and not abilities.status().fresh)
          assert(queries.owner()==nil)
          abilities.refresh(); advance(0.2)
          update('char.status.state',6,'char.status')
          assert(not abilities.status().busy and abilities.last:find('pager/editor'))
          local n=#commands; advance(30); assert(#commands==n)
        ''')
