"""Progression and quest observations, real SQLite transactions, and bounded view contracts."""
import unittest
import json
from pathlib import Path
import check_package


class HistoryTests(unittest.TestCase):
    def setUp(self):
        harness=check_package.PackageTests();harness.setUp()
        self.addCleanup(harness.doCleanups);self.lua=harness.lua
        self.lua.execute('''
          clock=1000000;function getEpoch() return clock end
          assert(AardwolfToolbox.start());t=AardwolfToolbox;h=t.history;s=t.historyStore;p=t.historyPane
          function observe(path,value)
            gmcp=gmcp or {};gmcp.char=gmcp.char or {}
            if path=='char' then gmcp.char=value else gmcp.char[path:match('%.(.+)')]=value end
            fire('gmcp.char','gmcp.'..path);fire('AardwolfToolbox.gmcp.updated',path)
          end
          function quest(value)
            gmcp=gmcp or {};gmcp.comm=gmcp.comm or {};gmcp.comm.quest=value
            fire('gmcp.comm','gmcp.comm.quest');fire('AardwolfToolbox.gmcp.updated','comm.quest')
          end
          function death(id,visit)
            local event={session=1,visit=visit or 1,rowId=id or 1,name='<Éowyn> the bat',flags='(Hidden)',
              uncertain=true,source='room-mobs',room={num=12,name='A room',area='academy'}}
            fire('AardwolfToolbox.mobs.death',event);return event
          end
          function chat(message)
            gmcp=gmcp or {};gmcp.comm=gmcp.comm or {};gmcp.comm.channel=message
            fire('gmcp.comm','gmcp.comm.channel');if not consumer then fire('AardwolfToolbox.gmcp.updated','comm.channel') end
          end
          function enableChat()
            assert(t.config.set('history','chat',true))
            consumer=function(event,value) fire(event,value) end
          end
          function enableKills() assert(t.config.set('history','kills',true)) end
          function enableQuests() assert(t.config.set('history','quests',true)) end
          function enable() assert(t.config.set('history','progression',true)) end
          function W(id) return assert(widgets['AardwolfToolbox.historyPane.'..id],id) end
          local open=io.open;io.open=function(...) local f,err,code=open(...);if f then f.flush=function() return true end end;return f,err,code end
          function send() error('History dispatched gameplay') end
          function expandAlias() error('History dispatched alias') end
        ''')

    def test_default_off_no_database_or_cached_replay(self):
        self.lua.execute('''
          local opens=0;local old=luasql.sqlite3
          luasql.sqlite3=function()
            local env=old();local connect=env.connect
            env.connect=function(self,path)
              if path==s.path then opens=opens+1 end
              return connect(self,path)
            end
            return env
          end
          observe('char.base',{name='Tesobi',level=120});assert(not h.enabled and opens==0)
          enable();assert(opens==0)
          observe('char.status',{level=121});assert(opens==0)
          observe('char.base',{name='Tesobi',level=120});assert(opens==1)
          local r=h.list('tesobi');assert(r.total==1 and r.rows[1].values.level==121)
        ''')

    def test_partial_zero_invalid_and_duplicate_updates(self):
        self.lua.execute('''
          enable();observe('char.base',{name='Tesobi',level=120,tier=0,remorts=2,redos=0,pups=0,totpups=6,password='never saved'})
          local first=h.list('TESOBI');assert(first.total==1 and first.rows[1].kind=='snapshot')
          assert(first.rows[1].values.tier==0 and first.rows[1].values.password==nil)
          observe('char.status',{level=120});observe('char.base',{name='Tesobi',remorts=2})
          assert(h.list('tesobi').total==1)
          observe('char.status',{level=121});observe('char.base',{level=120,totpups=7})
          local r=h.list('tesobi');assert(r.total==3 and r.rows[1].values.level==121)
          assert(r.rows[1].changes[1].field=='totpups' and r.rows[1].changes[1].before==6)
          observe('char.base',{tier=-1,remorts=math.huge,redos=0/0,pups='99'})
          assert(h.list('tesobi').total==3)
          r.rows[1].values.level=9;assert(h.list('tesobi').rows[1].values.level==121)
        ''')

    def test_character_switch_reset_and_reenable_only_fresh_state(self):
        self.lua.execute('''
          -- Isolate history UTF-8 handling from the older ability identity validator.
          assert(t.config.set('abilities','enabled',false));enable();observe('char',{base={name="O'Brien",level=2,tier=1},status={level=3}})
          observe('char.base',{name='Éowyn',level=4})
          assert(h.list("o'brien").rows[1].values.level==3)
          assert(h.list('Éowyn').rows[1].values.tier==nil)
          fire('AardwolfToolbox.gmcp.cleared');observe('char.status',{level=5})
          assert(h.list('Éowyn').total==1)
          observe('char.base',{name='Éowyn',level=4});assert(h.list('Éowyn').rows[1].values.level==5)
          assert(t.config.set('history','progression',false));observe('char.status',{level=6})
          assert(h.list('Éowyn').total==2);enable();assert(h.list('Éowyn').total==2)
          observe('char.base',{name='Éowyn',level=6});assert(h.list('Éowyn').total==3)
        ''')

    def test_retention_age_count_bytes_and_character_clear(self):
        self.lua.execute('''
          s.configure({days=1,max_entries=100,max_kib=64})
          for i=1,105 do assert(s.append('A',{observed=clock,kind='change',values={level=i},changes={}})) end
          assert(s.read('A').total==100 and s.read('A').pages==4)
          assert(s.append('B',{observed=clock,kind='snapshot',values={level=1},changes={}}))
          assert(s.read('A').total==99)
          for i=1,15 do assert(s.append('B',{observed=clock,kind='change',values={},changes={},padding=string.rep('x',7900)})) end
          assert(s.read('B').total<=8 and s.read('A').total==0)
          clock=clock+86401;assert(s.read('B').total==0)
          enable();observe('char.base',{name='A',level=1});observe('char.base',{name='B',level=2})
          local rev=h.revision;assert(not h.clear('A',rev-1));assert(h.clear('A',rev))
          assert(h.list('A').total==0 and h.list('B').total==1)
        ''')

    def test_write_and_commit_failure_preserve_saved_rows_pause_until_apply(self):
        self.lua.execute('''
          enable();observe('char.base',{name='A',level=1})
          local original=luasql.sqlite3;local fail='COMMIT'
          luasql.sqlite3=function()
            local env=original();local connect=env.connect
            env.connect=function(...)
              local db=connect(...);local execute=db.execute
              db.execute=function(self,sql) if fail and sql==fail then fail=nil;return nil,'Injected commit failure' end;return execute(self,sql) end
              return db
            end
            return env
          end
          observe('char.status',{level=2});assert(h.status().paused)
          assert(h.list('A').total==1)
          fire('AardwolfToolbox.gmcp.cleared');assert(h.last:find('paused'))
          observe('char.base',{name='A',level=3});assert(h.list('A').total==1)
          assert(t.config.set('history','progression',false));enable();observe('char.base',{name='A',level=3});assert(h.list('A').total==2)
        ''')

    def test_unsupported_database_is_not_modified_and_operations_close_connections(self):
        self.lua.execute('''
          local original=luasql.sqlite3;local env=original();local db=env:connect(s.path)
          db:execute('PRAGMA user_version=99');db:close();env:close()
          local opened,closed=0,0
          luasql.sqlite3=function()
            local e=original();local connect=e.connect
            e.connect=function(...)
              local c=connect(...);opened=opened+1;local close=c.close
              c.close=function(...) closed=closed+1;return close(...) end;return c
            end;return e
          end
          local result,err=h.list('A');assert(not result and err:find('Unsupported'))
          assert(opened==closed)
          env=original();db=env:connect(s.path)
          local cursor=db:execute('PRAGMA user_version');assert(cursor:fetch({},'a').user_version==99);cursor:close();db:close();env:close()
        ''')

    def test_export_unique_readback_and_failure_cleanup(self):
        self.lua.execute('''
          enable();observe('char.base',{name="O'Brien",level=0})
          local path,err=h.export("O'Brien");assert(path,err)
          local decoded=yajl.to_value(files[path]);assert(decoded.character=="o'brien" and decoded.observations[1].values.level==0)
          local nextPath=h.export("O'Brien");assert(nextPath~=path and files[path])
          local rename=os.rename;os.rename=function() return nil,'Injected rename error' end
          local failed=h.export("O'Brien");assert(not failed)
          for name in pairs(files) do assert(not name:find('progression%-export.*%.tmp$')) end
          os.rename=rename;assert(h.list("O'Brien").total==1)
        ''')

    def test_pane_hidden_queries_paging_clear_confirmation_and_lifecycle(self):
        self.lua.execute('''
          local reads=0;local read=s.read;s.read=function(...) reads=reads+1;return read(...) end
          enable();observe('char.base',{name='<Tester>',level=1})
          for i=2,28 do observe('char.status',{level=i}) end
          assert(reads==0);assert(p.open());assert(W('page').text=='1 / 2')
          assert(W('title').text:find('&lt;tester&gt;'))
          local row=W('row.28');assert(row.renderedFontSize>=12)
          local writes=0;local echo=row.echo;row.echo=function(...) writes=writes+1;return echo(...) end
          fire('sysWindowResizeEvent');assert(reads==1 and writes==0)
          W('next').callback();assert(W('page').text=='2 / 2')
          W('clear').callback();assert(h.list('<Tester>').total==28)
          observe('char.status',{level=29});W('clear').callback();assert(h.list('<Tester>').total==29)
          W('clear').callback();assert(h.list('<Tester>').total==0)
          p.close();local before=reads;fire('AardwolfToolbox.history.updated');assert(reads==before)
          assert(t.views.setMode('history','floating'));assert(p.open())
          assert(W('content').parent~=W('home'))
          t.stop();assert(count(widgets)==0)
          assert(t.start() and t.views.available('history') and t.config.get('history','progression'))
        ''')

    def test_stale_callbacks_and_default_diagnostics_do_not_export_history(self):
        self.lua.execute('''
          enable();local handler
          for name,v in pairs(handlers) do if name=='AardwolfToolbox.history:update' then handler=v.fn end end
          assert(handler);t.stop();assert(t.start())
          gmcp={char={base={name='PrivateName',level=5}}};fire('gmcp.char','gmcp.char.base')
          handler('AardwolfToolbox.gmcp.updated','char.base');assert(h.list('PrivateName').total==0)
          fire('AardwolfToolbox.gmcp.updated','char.base');assert(h.list('PrivateName').total==1)
          local report=yajl.to_string(t.health());assert(not report:find('PrivateName') and not report:find('observations'))
        ''')

    def test_malformed_identity_drops_attribution_and_saved_errors_remain_visible(self):
        self.lua.execute('''
          enable();observe('char.base',{name='A',level=1})
          observe('char.base',{name='',level=99});observe('char.status',{level=100})
          assert(h.list('A').total==1)
          assert(s.append('Broken',{observed=clock,kind='unsupported'}))
          local result,err=h.list('Broken');assert(not result and err:find('Invalid saved history'))
          assert(h.list('A').total==1)
        ''')

    def test_narrow_short_layout_scrolls_controls_without_covering_footer(self):
        self.lua.execute('''
          windowWidth=320;windowHeight=280
          assert(p.open());fire('sysWindowResizeEvent')
          assert(W('toolbar'):get_height()>=32 and W('list'):get_height()>=32)
          assert(W('next'):get_y()+W('next'):get_height()<=W('content'):get_height())
          assert(W('list'):get_y()+W('list'):get_height()<=W('next'):get_y())
          assert(W('clear').parent==W('toolbar') and W('clear'):get_height()>=32)
        ''')

    def test_quests_opt_in_identity_and_completion_only(self):
        self.lua.execute('''
          assert(not t.config.get('history','quests'))
          quest({action='comp',totqp=50,gold=4831,completed=111})
          enableQuests()
          quest({action='comp',totqp=50,gold=4831,completed=111})
          observe('char.base',{name='A',level=1})
          assert(h.list('A',1,'quests').total==0 and h.list('A').total==0)
          quest({action='status',status='ready',gold=999999})
          quest({action='start',targ='a swamp ape',room='Enclosure',area='Zoo'})
          quest({action='killed'});quest({action='warning',time=5})
          assert(h.list('A',1,'quests').total==0)
          quest({action='comp',qp=16,tierqp=9,totqp=50,gold=4831,pracs=0,completed=111,password='never saved'})
          local result=h.list('A',1,'quests');assert(result.total==1)
          local r=result.rows[1]
          assert(r.quest.target=='a swamp ape' and r.quest.room=='Enclosure')
          assert(r.rewards.totqp==50 and r.rewards.qp==16 and r.rewards.pracs==0 and r.rewards.tp==nil)
          assert(r.rewards.password==nil and r.completed==111 and r.observed==clock)
          r.rewards.gold=1;assert(h.list('A',1,'quests').rows[1].rewards.gold==4831)
          quest({action='comp',totqp=50,completed=111});assert(h.list('A',1,'quests').total==1)
          enable();observe('char.base',{name='A',level=1});assert(h.list('A').total==1)
          assert(t.config.set('history','quests',false));observe('char.base',{name='A',level=2})
          quest({action='comp',completed=112});assert(h.list('A',1,'quests').total==1)
          assert(h.status().progression and not h.status().quests)
        ''')

    def test_quest_details_resets_duplicates_and_missing_rewards(self):
        self.lua.execute('''
          enableQuests();observe('char.base',{name='A'})
          quest({action='start',targ='old',room='Old room',area='Old area'})
          quest({action='status',targ='new',room='New room'})
          quest({action='status',area='New area'})
          quest({action='comp',gold=-1,totqp='50',qp=0,pracs='invalid'})
          local r=h.list('A',1,'quests').rows[1]
          assert(r.quest.target=='new' and r.quest.area=='New area')
          assert(r.rewards.qp==0 and r.rewards.gold==nil and r.rewards.totqp==nil and r.rewards.pracs==nil)
          quest({action='comp'});assert(h.list('A',1,'quests').total==1)
          quest({action='ready'});quest({action='comp'})
          r=h.list('A',1,'quests').rows[1];assert(next(r.quest)==nil and next(r.rewards)==nil)
          for _,action in ipairs({'fail','timeout','reset'}) do
            quest({action='start',targ='must clear'});quest({action=action});quest({action='comp'})
            assert(next(h.list('A',1,'quests').rows[1].quest)==nil)
          end
          quest({action='start',targ='must clear'});fire('AardwolfToolbox.gmcp.cleared')
          quest({action='comp',completed=10});assert(h.list('A',1,'quests').total==5)
          observe('char.base',{name='B'});quest({action='comp',completed=10})
          assert(next(h.list('B',1,'quests').rows[1].quest)==nil)
          quest({action='start',targ='B target'});observe('char.base',{name='C'})
          quest({action='comp',completed=10});assert(next(h.list('C',1,'quests').rows[1].quest)==nil)
        ''')

    def test_quest_storage_retention_clear_and_export_are_category_scoped(self):
        self.lua.execute('''
          enable();enableQuests();observe('char.base',{name='A',level=1})
          quest({action='comp',completed=1,totqp=0,gold=0})
          local path,err=h.export('A','quests');assert(path,err)
          local data=yajl.to_value(files[path]);assert(data.category=='quests' and data.observations[1].rewards.gold==0)
          assert(path:find('quests%-export'))
          assert(h.clear('A',h.revision,'quests'));assert(h.list('A').total==1 and h.list('A',1,'quests').total==0)
          s.configure({days=1,max_entries=100,max_kib=64})
          for i=1,101 do assert(s.append('A',{kind='quest_reward',observed=clock,quest={},rewards={gold=i}},'quests')) end
          assert(h.list('A',1,'quests').total==100 and h.list('A').total==0)
          clock=clock+86401;assert(h.list('A',1,'quests').total==0)
          assert(not pcall(h.list,'A',1,"quests'; DROP TABLE observations; --"))
        ''')

    def test_history_v1_migration_preserves_progression_ids_and_data(self):
        self.lua.execute('''
          local env=luasql.sqlite3();local db=env:connect(s.path)
          assert(db:execute('CREATE TABLE progression (id INTEGER PRIMARY KEY AUTOINCREMENT, character TEXT NOT NULL, observed INTEGER NOT NULL, data TEXT NOT NULL, bytes INTEGER NOT NULL)'))
          local entry=yajl.to_string({kind='snapshot',observed=clock,values={level=22},changes={}})
          assert(db:execute("INSERT INTO progression VALUES(37,'a',"..clock..",'"..entry.."',"..#entry..")"))
          assert(db:execute('PRAGMA user_version=1'));db:close();env:close()
          local r=h.list('A');assert(r.total==1 and r.rows[1].id==37 and r.rows[1].values.level==22)
          assert(h.list('A',1,'quests').total==0)
          assert(s.append('A',{kind='quest_reward',observed=clock,quest={},rewards={}},'quests'))
          assert(h.list('A',1,'quests').rows[1].id==38)
          env=luasql.sqlite3();db=env:connect(s.path)
          local c=db:execute('PRAGMA user_version');assert(c:fetch({},'a').user_version==2);c:close();db:close();env:close()
        ''')

    def test_history_migration_failure_rolls_back_schema_and_rows(self):
        self.lua.execute('''
          local original=luasql.sqlite3;local env=original();local db=env:connect(s.path)
          assert(db:execute('CREATE TABLE progression (id INTEGER PRIMARY KEY AUTOINCREMENT, character TEXT NOT NULL, observed INTEGER NOT NULL, data TEXT NOT NULL, bytes INTEGER NOT NULL)'))
          assert(db:execute("INSERT INTO progression VALUES(1,'a',"..clock..",'{}',2)"))
          assert(db:execute('PRAGMA user_version=1'));db:close();env:close()
          luasql.sqlite3=function()
            local e=original();local connect=e.connect
            e.connect=function(...)
              local c=connect(...);local execute=c.execute
              c.execute=function(self,sql)
                if sql:find('ADD COLUMN',1,true) then return nil,'Injected migration failure' end
                return execute(self,sql)
              end;return c
            end;return e
          end
          local result,err=h.list('A');assert(not result and err:find('Injected migration failure'))
          env=original();db=env:connect(s.path)
          local c=db:execute('PRAGMA user_version');assert(c:fetch({},'a').user_version==1);c:close()
          c=db:execute('SELECT id,data FROM progression');local r=c:fetch({},'a');assert(r.id==1 and r.data=='{}');c:close()
          c=db:execute("SELECT name FROM sqlite_master WHERE name='observations'");assert(c:fetch({},'a')==nil);c:close();db:close();env:close()
        ''')

    def test_quest_history_pane_categories_literal_render_and_clear(self):
        self.lua.execute('''
          enable();enableQuests();observe('char.base',{name='A',level=1})
          quest({action='start',targ='<Éowyn>',room='A room',area='An area'})
          quest({action='comp',totqp=50,gold=0,completed=1})
          assert(p.open('quests'));assert(W('title').text:find('Quest rewards'))
          assert(W('row.2').text:find('&lt;Éowyn&gt;') and W('row.2').text:find('Gold 0'))
          W('clear').callback();W('progression').callback();W('clear').callback()
          assert(h.list('A').total==1 and h.list('A',1,'quests').total==1)
          W('quests').callback();W('clear').callback();W('clear').callback()
          assert(h.list('A',1,'quests').total==0 and h.list('A').total==1)
          assert(not p.open('unsupported'))
          t.stop();assert(count(widgets)==0);assert(t.start() and t.config.get('history','quests'))
        ''')

    def test_documented_quest_completion_fields(self):
        fixture=json.loads((Path(__file__).parent / 'fixtures/quest-history.json').read_text())
        self.lua.globals().questStart=self.lua.table_from(fixture['start'])
        self.lua.globals().questCompletion=self.lua.table_from(fixture['completion'])
        self.lua.execute('''
          enableQuests();observe('char.base',{name='Example'})
          quest(questStart);quest(questCompletion)
          local r=h.list('Example',1,'quests').rows[1]
          for key,value in pairs(questCompletion) do
            if key~='action' and key~='wait' and key~='completed' then assert(r.rewards[key]==value,key) end
          end
          assert(r.completed==111 and r.quest.room=='Swamp Ape Enclosure')
          assert(r.rewards.wait==nil and r.rewards.action==nil)
        ''')

    def test_enable_kills_uses_current_session_identity_without_backfill(self):
        self.lua.execute('''
          connected=true;observe('char.base',{name='A',level=120})
          death();enableKills()
          assert(h.list('A',1,'kills').total==0)
          death(2);assert(h.list('A',1,'kills').total==1)
          assert(h.list('A',1,'progression').total==0)
          -- Changing another recording category must not strand kill recording.
          enable();assert(h.list('A',1,'progression').total==0)
          death(3);assert(h.list('A',1,'kills').total==2)
        ''')

    def test_enable_kills_does_not_adopt_old_or_invalid_identity(self):
        self.lua.execute('''
          connected=true;observe('char.base',{name='A'})
          fire('sysDisconnectionEvent');fire('sysConnectionEvent')
          -- Mudlet still retains raw gmcp.char.base, but the session cache is empty.
          assert(gmcp.char.base.name=='A' and t.gmcp.get('char.base')==nil)
          enableKills();death();assert(h.list('A',1,'kills').total==0)
          observe('char.base',{name='B'});death(2)
          assert(h.list('B',1,'kills').total==1)
          assert(t.config.set('history','kills',false))
          observe('char.base',{name=''});enableKills();death(3)
          assert(h.list('B',1,'kills').total==1)
        ''')

    def test_kills_opt_in_identity_duplicates_and_defensive_copies(self):
        self.lua.execute("""
          assert(not t.config.get('history','kills'));observe('char.base',{name='A'});death()
          assert(h.list('A',1,'kills').total==0)
          enableKills();death();assert(h.list('A',1,'kills').total==0)
          observe('char.base',{name='A'});local event=death();death()
          assert(h.list('A',1,'kills').total==1 and h.list('A').total==0)
          death(2);local r=h.list('A',1,'kills');assert(r.total==2)
          assert(r.rows[1].name=='<Éowyn> the bat' and r.rows[1].uncertain and r.rows[1].room.num==12)
          assert(r.rows[1].session==nil and r.rows[1].rowId==nil)
          event.name='changed';r.rows[1].room.num=99;assert(h.list('A',1,'kills').rows[1].room.num==12)
          death(1,2);assert(h.list('A',1,'kills').total==3)
        """)

    def test_kills_resets_toggle_character_and_stale_callback(self):
        self.lua.execute("""
          enableKills();observe('char.base',{name='A'});death()
          local old=handlers['AardwolfToolbox.history:death'].fn
          fire('AardwolfToolbox.gmcp.cleared');death(2);assert(h.list('A',1,'kills').total==1)
          observe('char.base',{name='B'});death(2);assert(h.list('B',1,'kills').total==1)
          observe('char.base',{name=''});death(3);assert(h.list('B',1,'kills').total==1)
          assert(t.config.set('history','kills',false));observe('char.base',{name='B'});local value=death(3)
          old('',value);assert(h.list('B',1,'kills').total==1)
          enableKills();old('',value);assert(h.list('B',1,'kills').total==1)
          observe('char.base',{name='B'});death(3);assert(h.list('B',1,'kills').total==2)
          t.stop();assert(not handlers['AardwolfToolbox.history:death']);assert(t.start())
          assert(t.config.get('history','kills') and h.list('B',1,'kills').total==2)
        """)

    def test_kills_invalid_events_unknown_location_and_storage_failure(self):
        self.lua.execute("""
          enableKills();observe('char.base',{name='A'});local e=death()
          e.rowId=2;e.room={num=13};e.uncertain=false
          fire('AardwolfToolbox.mobs.death',e);assert(h.list('A',1,'kills').rows[1].room.name==nil)
          for _,field in ipairs({'name','flags','rowId','visit','session','room','uncertain','source'}) do
            local keep=e[field];e[field]=nil;fire('AardwolfToolbox.mobs.death',e);e[field]=keep
          end
          e.rowId=3;e.name=string.rep('x',513);fire('AardwolfToolbox.mobs.death',e)
          e.name='valid';e.room.num=0;fire('AardwolfToolbox.mobs.death',e)
          assert(h.list('A',1,'kills').total==2)
          local append=s.append;s.append=function() return nil,'Disk full' end
          death(3);assert(h.status().paused and h.last:find('Disk full'))
          s.append=append;death(4);assert(h.list('A',1,'kills').total==2)
        """)

    def test_kills_category_export_clear_retention_and_persistence(self):
        self.lua.execute("""
          enable();enableQuests();enableKills();observe('char.base',{name='A',level=0})
          quest({action='comp',gold=0});death()
          local path=assert(h.export('A','kills'));local data=yajl.to_value(files[path])
          assert(data.category=='kills' and data.observations[1].kind=='mob_death')
          assert(h.clear('A',h.revision,'kills'))
          assert(h.list('A',1,'kills').total==0 and h.list('A').total==1 and h.list('A',1,'quests').total==1)
          for i=2,105 do death(i) end
          s.configure({days=1,max_entries=100,max_kib=64})
          assert(h.list('A',1,'kills').total==100 and h.list('A').total==0 and h.list('A',1,'quests').total==0)
          clock=clock+86401;assert(h.list('A',1,'kills').total==0)
        """)

    def test_kills_view_literal_names_unknown_credit_and_category_clear(self):
        self.lua.execute("""
          enable();enableKills();observe('char.base',{name='A',level=0});death()
          assert(p.open('kills'));local row=W('row.2')
          assert(row.text:find('Death observed') and row.text:find('&lt;Éowyn&gt;'))
          assert(row.tooltip:find('Kill credit unknown') and row.tooltip:find('Duplicate identity uncertain'))
          W('clear').callback();W('progression').callback();W('kills').callback()
          assert(h.list('A',1,'kills').total==1)
          W('clear').callback();W('clear').callback()
          assert(h.list('A',1,'kills').total==0 and h.list('A').total==1)
        """)

    def test_corrupt_kill_record_preserved_and_reported(self):
        self.lua.execute("""
          assert(s.append('A',{kind='mob_death',source='room-mobs',observed=clock,
            name='bat',flags='',uncertain=false,room={num=-1}},'kills'))
          local result,why=h.list('A',1,'kills');assert(not result and why:find('Invalid saved kill room'))
          local env=luasql.sqlite3();local db=env:connect(s.path)
          local c=db:execute('SELECT COUNT(*) AS n FROM observations');assert(c:fetch({},'a').n==1)
          c:close();db:close();env:close()
        """)

    def test_gmcp_kill_history_ignores_variable_combat_messages(self):
        fixture=json.loads((Path(__file__).parent/'fixtures/mob-fire-death.json').read_text())
        self.lua.execute('''
          connected=true;observe('char.base',{name='A'});enableKills()
          for _,key in ipairs({'on_entry','automatic_setup','automatic_consider','after_combat'}) do
            assert(t.config.set('mobs',key,false))
          end
          consumer=function(event,value) fire(event,value) end
          gmcp.room={info={num=12,name='Room',zone='test'}};fire('gmcp.room','gmcp.room.info')
          incoming('{scan}');incoming('Right here you see:');incoming('     - A worshipper');incoming('{/scan}')
          observe('char.status',{state=8,enemy='a worshipper',enemypct=1})
        ''')
        for i,line in enumerate(fixture['lines']):
            self.lua.globals().sample=line
            self.lua.execute('incoming(sample)')
            if i<4:
                self.lua.execute("assert(h.list('A',1,'kills').total==0)")
        self.lua.execute('''
          assert(h.list('A',1,'kills').total==0)
          observe('char.status',{enemypct=0})
          observe('char.status',{enemypct=0})
          local r=h.list('A',1,'kills');assert(r.total==1 and r.rows[1].name=='A worshipper')
          assert(t.mobs.snapshot().rows[1].killed==1)
          assert(not r.rows[1].xp and r.rows[1].evidence=='gmcp-target-zero')
        ''')

    def test_kills_shared_dispatcher_and_capture_ownership(self):
        self.lua.execute("""
          connected=true;observe('char.base',{name='A'});enableKills()
          assert(t.config.set('mobs','on_entry',false));assert(t.config.set('mobs','automatic_setup',false))
          assert(t.config.set('mobs','automatic_consider',false));assert(t.config.set('mobs','after_combat',false))
          local get=t.gmcp.get
          t.gmcp.get=function(path) if path=='room.info' then return {num=12,name='Room',zone='test'} end;return get(path) end
          consumer=function(event,value) fire(event,value) end
          fire('AardwolfToolbox.gmcp.updated','room.info')
          incoming('{scan}');incoming('Right here you see:');incoming('     - A bat');incoming('{/scan}')
          assert(t.mobs.snapshot().rows[1].alive==1)
          local before=gagCount
          incoming('{unfamiliar}');incoming('A bat is DEAD!!');incoming('{/unfamiliar}')
          assert(h.list('A',1,'kills').total==0)
          incoming('<MAPSTART>');incoming('A bat is DEAD!!');incoming('<MAPEND>')
          assert(h.list('A',1,'kills').total==0)
          incoming('A bat is DEAD!!');assert(h.list('A',1,'kills').total==0)
          incoming('{unfamiliar}')
          observe('char.status',{state=8,enemy='a bat',enemypct=0})
          incoming('{/unfamiliar}')
          assert(h.list('A',1,'kills').total==1 and t.mobs.snapshot().rows[1].killed==1)
          incoming('A bat is DEAD!!');assert(h.list('A',1,'kills').total==1)
          assert(count(triggers)==1)
        """)


    def test_chat_opt_in_router_fanout_literal_colors_and_own_messages(self):
        self.lua.execute("""
          observe('char.base',{name='A'});chat({chan='clantalk',msg='before'})
          enableChat();chat({chan='clantalk',msg='waiting for identity'});assert(h.list('A',1,'chat').total==0)
          observe('char.base',{name='A'});local b=t.shell.getBase();local unread=b.unread.clan or 0
          chat({chan='clantalk',player='Friend',msg=string.char(27)..'[31mFriend: <Éowyn> & hi'})
          local rows=h.list('A',1,'chat');assert(rows.total==1 and rows.rows[1].text=='Friend: <Éowyn> & hi')
          assert(rows.rows[1].peer=='Friend' and not rows.rows[1].outgoing and b.unread.clan==unread+1)
          local counts={};for k,v in pairs(b.unread) do counts[k]=v end
          chat({chan='tell',player='Friend',msg='You tell Friend: hi'})
          assert(h.list('A',1,'chat').total==2 and h.list('A',1,'chat').rows[1].outgoing)
          for k,v in pairs(b.unread) do assert(v==(counts[k] or 0),k) end
          assert(t.config.set('shell','hidden_channels','clantalk'))
          chat({chan='clantalk',msg='hidden'});assert(h.list('A',1,'chat').total==2)
        """)

    def test_chat_equal_messages_are_distinct_and_ansi_raw_settings(self):
        self.lua.execute("""
          enableChat();observe('char.base',{name='A'})
          chat({chan='newbie',msg='same'});chat({chan='newbie',msg='same'})
          assert(h.list('A',1,'chat').total==2)
          chat({chan='gossip',msg='me@gmail.com'});assert(h.list('A',1,'chat').rows[1].text=='me@gmail.com')
          assert(t.config.set('shell','chat_colors','raw'))
          chat({chan='gossip',msg='@RRed @@literal@w'})
          assert(h.list('A',1,'chat').rows[1].text=='Red @literal')
          assert(t.config.set('shell','timestamps',true));chat({chan='gossip',msg='no added time'})
          assert(h.list('A',1,'chat').rows[1].text=='no added time')
        """)

    def test_chat_reset_character_reenable_and_stale_callbacks(self):
        self.lua.execute("""
          enableChat();observe('char.base',{name='A'});chat({chan='tell',msg='first'})
          local old=handlers['AardwolfToolbox.history:chat'].fn
          fire('AardwolfToolbox.gmcp.cleared');chat({chan='tell',msg='no identity'})
          assert(h.list('A',1,'chat').total==1)
          observe('char.base',{name='B'});chat({chan='tell',msg='second'})
          assert(h.list('B',1,'chat').total==1)
          assert(t.config.set('history','chat',false));chat({chan='tell',msg='disabled'})
          old('',{text='stale',channel='tell',outgoing=false});assert(h.list('B',1,'chat').total==1)
          enableChat();old('',{text='stale',channel='tell',outgoing=false});chat({chan='tell',msg='waiting'})
          assert(h.list('B',1,'chat').total==1)
          observe('char.base',{name='B'});chat({chan='tell',msg='fresh'});assert(h.list('B',1,'chat').total==2)
          t.stop();assert(not handlers['AardwolfToolbox.history:chat']);assert(t.start() and t.config.get('history','chat'))
        """)

    def test_chat_bounds_control_removal_utf8_and_json_expansion(self):
        self.lua.execute("""
          enableChat();observe('char.base',{name='A'})
          chat({chan='tell',msg=string.rep('x',4095)..'Éowyn'})
          local row=h.list('A',1,'chat').rows[1];assert(#row.text==4095 and row.truncated)
          chat({chan='tell',msg=string.rep('x',4094)..'Éowyn'})
          row=h.list('A',1,'chat').rows[1];assert(#row.text==4096 and row.text:sub(-2)=='É')
          chat({chan='tell',msg=string.rep(string.char(10),4096)})
          assert(not h.status().paused and h.list('A',1,'chat').rows[1].truncated)
          chat({chan='tell',msg='hello'..string.char(0,7)..'world'})
          assert(h.list('A',1,'chat').rows[1].text=='helloworld')
          local count=h.list('A',1,'chat').total
          chat({chan='tell',msg=string.char(0,7)});chat({chan='tell',msg=string.rep('a',65401)})
          fire('AardwolfToolbox.chat.message',{text='bad',channel='tell',outgoing='false'})
          assert(h.list('A',1,'chat').total==count)
        """)

    def test_chat_export_category_retention_corruption_and_write_failure(self):
        self.lua.execute("""
          enable();enableChat();observe('char.base',{name='A',level=1})
          chat({chan='tell',msg='secret'});local path=assert(h.export('A','chat'))
          local data=yajl.to_value(files[path]);assert(data.category=='chat' and data.observations[1].text=='secret')
          local append=s.append;s.append=function() return nil,'Disk full' end
          chat({chan='tell',msg='failure'});assert(h.status().paused)
          s.append=append;chat({chan='tell',msg='not retried'});assert(h.list('A',1,'chat').total==1)
          assert(h.clear('A',h.revision,'chat'));assert(h.list('A').total==1)
          assert(s.append('A',{observed=clock,kind='chat_message',channel='tell',text=string.char(27),outgoing=false,truncated=false},'chat'))
          local result,why=h.list('A',1,'chat');assert(not result and why:find('Invalid saved chat'))
        """)

    def test_chat_view_literal_paging_clear_and_no_diagnostic_content(self):
        self.lua.execute("""
          enableChat();observe('char.base',{name='A'})
          for i=1,26 do chat({chan='tell',player='Friend',msg='<PRIVATE> & '..i}) end
          assert(p.open('chat'));assert(W('page').text=='1 / 2')
          assert(W('row.26').text:find('&lt;PRIVATE&gt;') and W('row.26').text:find('Received'))
          W('next').callback();assert(W('page').text=='2 / 2')
          assert(not yajl.to_string(t.health()):find('PRIVATE'))
          W('clear').callback();W('refresh').callback();assert(h.list('A',1,'chat').total==26)
          W('clear').callback();W('clear').callback();assert(h.list('A',1,'chat').total==0)
          p.close();local read=s.read;s.read=function() error('Hidden history read') end
          chat({chan='gossip',msg='new'});s.read=read
        """)

    def test_chat_notification_after_capture_rejects_reset_and_character_switch(self):
        self.lua.execute("""
          enableChat();observe('char.base',{name='A'});local stage=1;local before=gagCount
          t.incoming.add('chat-test',1,function(text)
            if text~='fixture' then return false end
            chat({chan='tell',msg='deferred'})
            if stage==1 then fire('AardwolfToolbox.gmcp.cleared')
            elseif stage==2 then observe('char.base',{name='B'}) end
            return true,true
          end,error)
          incoming('fixture');assert(h.list('A',1,'chat').total==0)
          stage=2;observe('char.base',{name='A'});incoming('fixture')
          assert(h.list('A',1,'chat').total==0 and h.list('B',1,'chat').total==0)
          stage=3;local append=s.append;s.append=function(...) assert(gagCount==before+3);return append(...) end
          incoming('fixture');assert(h.list('B',1,'chat').total==1)
          s.append=append;t.incoming.remove('chat-test')
        """)

    def test_chat_starter_reconciled_message_records_once(self):
        self.lua.execute("""
          enableChat();observe('char.base',{name='A'});local b=t.shell.getBase()
          b.chats.all:echo('previous text copy');b.recentCaptures={{text='same message',time=clock}}
          local before=b.chats.all.text
          chat({chan='gossip',player='Friend',msg='same message'})
          assert(b.chats.all.text==before and h.list('A',1,'chat').total==1)
          chat({chan='gossip',player='Friend',msg='same message'})
          assert(h.list('A',1,'chat').total==2)
          assert(h.clear('A',h.revision,'chat'));assert(b.chats.all.text:find('previous text copy'))
        """)
