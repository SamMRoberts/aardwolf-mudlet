from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]


class MobDeathsTests(unittest.TestCase):
    def runtime(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute((ROOT / "tests/buffs_window_api.lua").read_text())
        lua.execute((ROOT / "tests/quest_tracker_api.lua").read_text())
        lua.execute(r'''
          local function copy(row)
            local result={};for key,value in pairs(row) do result[key]=value end;return result
          end
          dbRows={};writes=0;rollbacks=0;deletedLines=0;dbOperation=0
          local originalSend=send
          function send(command,echoCommand)
            local result=originalSend(command,echoCommand)
            raiseEvent('sysDataSendRequest',command)
            return result
          end
          db={}
          function db:create(name,schema)
            assert(name=='aardwolfvibemobdeaths' and schema.mobs._unique[1]=='identity')
            local database={mobs={identity={}}}
            function database:_begin()
              self.backup={};for key,row in pairs(dbRows) do self.backup[key]=copy(row) end
            end
            function database:_commit() self.backup=nil;writes=writes+1 end
            function database:_rollback()
              dbRows=self.backup or dbRows;self.backup=nil;rollbacks=rollbacks+1
            end
            function database:_end() end
            return database
          end
          function db:close(name) assert(name=='aardwolfvibemobdeaths') end
          function db:eq(field,value) return value end
          function db:fetch(sheet,identity)
            local result={}
            for key,row in pairs(dbRows) do
              if not identity or key==identity then result[#result+1]=copy(row) end
            end
            return result
          end
          function db:add(sheet,row)
            dbOperation=dbOperation+1
            if failWrite or failOnWrite==dbOperation then
              return nil,'simulated database failure'
            end
            assert(not dbRows[row.identity]);dbRows[row.identity]=copy(row);return true
          end
          function db:update(sheet,row)
            dbOperation=dbOperation+1
            if failWrite or failOnWrite==dbOperation then
              return nil,'simulated database failure'
            end
            assert(dbRows[row.identity]);dbRows[row.identity]=copy(row);return true
          end
          function deleteLine() deletedLines=deletedLines+1 end
          Geyser.CommandLine={new=function(_,values,parent)
            local item={name=values.name,parent=parent,text=''};widgets[item.name]=item
            function item:print(value) self.text=value end
            function item:getText() return self.text end
            function item:setAction(callback) self.action=callback end
            function item:setStyleSheet(value) self.style=value end
            function item:delete() widgets[self.name]=nil end
            return item
          end}
          function linesFor(area,count,includeFish)
            local rows={
              '     [ Most popular kills for levels 1 to 999 (Current Area) ]',
              'No.   Mob name                                Level  Area Name            Killed',
              '---   --------------------------------------- -----  -------------------- ------',
              string.format('  1 - %-39s %5d  %-20s %6d', 'A duck',4,area,count),
            }
            if includeFish then
              rows[#rows+1]=string.format('  2 - %-39s %5d  %-20s %6d',
                'A large fish',10,area,224)
              rows[#rows+1]=string.format('  3 - %-39s %5d  %-20s %6d',
                'A large fish',11,area,178)
              rows[#rows+1]=string.format('  4 - %-39s %5d  %-20s %6d',
                "Gale's pet rabbit",1,area,128)
            end
            rows[#rows+1]='-------------------------------------[ THE END ]--------------------------------'
            return rows
          end
          function response(area,count,includeFish)
            for _,text in ipairs(linesFor(area,count,includeFish)) do incoming(text) end
          end
        ''')
        lua.globals().StoreFactory = lua.execute(
            (ROOT / "src/resources/mob-deaths-store.lua").read_text())
        lua.globals().Factory = lua.execute(
            (ROOT / "src/resources/mob-deaths.lua").read_text())
        lua.execute("tracker=Factory.new(_G,character,nil,StoreFactory)")
        return lua

    def test_parser_complete_rows_and_invalid_frames(self):
        lua = self.runtime()
        lua.execute(r'''
          local parsed=assert(Factory.parseResponse(linesFor("Sen'narre Lake",377,true)))
          assert(#parsed==4 and parsed[1].name=='A duck')
          assert(parsed[1].level==4 and parsed[1].area=="Sen'narre Lake")
          assert(parsed[2].name==parsed[3].name and parsed[2].level==10
            and parsed[3].level==11)
          assert(parsed[4].name=="Gale's pet rabbit" and parsed[4].killed==128)
          parsed=assert(Factory.parseResponse({
            '     [ Most popular kills for levels 1 to 999 (Current Area) ]',
            'No.   Mob name                                Level  Area Name            Killed',
            '---   --------------------------------------- -----  -------------------- ------',
            " 20 - One of the female tritons                  18  Sen'narre Lake          182",
            " 21 - A large fish                               11  Sen'narre Lake          178",
            " 36 - A traveller to Sen'narre                   11  Sen'narre Lake           95",
            " 46 - The triton elder                           20  Sen'narre Lake           61",
            '-------------------------------------[ THE END ]--------------------------------',
          }))
          assert(#parsed==4 and parsed[1].name=='One of the female tritons')
          assert(parsed[3].name=="A traveller to Sen'narre" and parsed[3].killed==95)
          local lines=linesFor('Area',5)
          table.remove(lines)
          assert(not Factory.parseResponse(lines))
          lines=linesFor('Area',5)
          lines[4]='  1 - malformed row'
          assert(not Factory.parseResponse(lines))
        ''')

    def test_area_scans_manual_visibility_persistence_and_search(self):
        lua = self.runtime()
        lua.execute(r'''
          assert(tracker:start() and tracker:start())
          assert(moduleCalls[1]=='on:aardwolf-vibe.mob-deaths:Room')
          gmcp.room={info={zone='lake'}};raiseEvent('gmcp.room.info')
          assert(#sent==1 and sent[1].command=='mobdeaths here'
            and sent[1].echoCommand==false)
          response("Sen'narre Lake",377,true)
          assert(deletedLines==8 and tracker:status().scans==1)
          local rows=assert(tracker:search({name='FISH',minimum=11,maximum=11}))
          assert(#rows==1 and rows[1].level==11)
          gmcp.room.info.zone='lake';raiseEvent('gmcp.room.info')
          assert(#sent==1)
          gmcp.room.info.zone='woods';raiseEvent('gmcp.room.info')
          advance(0.1)
          assert(#sent==2)
          response("Sen'narre Lake",400,false)
          rows=assert(tracker:search({area="sen'NARRE",minimum=1,maximum=20}))
          assert(#rows==4)
          assert(assert(tracker:search({name='duck'}))[1].killed==400)
          advance(0.1)
          raiseEvent('sysDataSendRequest','mobdeaths here')
          local hiddenBefore=deletedLines
          response('Other Area',12,false)
          assert(deletedLines==hiddenBefore)
          assert(#assert(tracker:search({area='Other'}))==1)
          assert(#assert(tracker:search({}))==5)
          assert(tracker:stop() and tracker:start())
          assert(#assert(tracker:search({}))==5)
          assert(tracker:stop())
        ''')

    def test_coalescing_failure_timeout_disconnect_and_overlap(self):
        lua = self.runtime()
        lua.execute(r'''
          assert(tracker:start())
          gmcp.room={info={zone='one'}};raiseEvent('gmcp.room.info')
          gmcp.room.info.zone='two';raiseEvent('gmcp.room.info')
          gmcp.room.info.zone='three';raiseEvent('gmcp.room.info')
          assert(#sent==1)
          response('First Area',8,false)
          advance(0.1)
          assert(#sent==2 and tracker:status().lastZone=='three')
          local before=deletedLines
          raiseEvent('sysDataSendRequest','mobdeaths here')
          response('Second Area',9,false)
          assert(deletedLines==before)
          response('Manual Area',10,false)
          assert(#assert(tracker:search({}))==3)
          raiseEvent('sysDataSendRequest','mobdeaths here')
          incoming('     [ Most popular kills for levels 1 to 999 (Current Area) ]')
          incoming('  1 - broken')
          assert(#assert(tracker:search({}))==3)
          raiseEvent('sysDataSendRequest','mobdeaths here')
          advance(20)
          assert(tracker:status().lastError)
          assert(#assert(tracker:search({}))==3)
          raiseEvent('sysDisconnectionEvent')
          assert(not tracker:status().capture)
          connection=true;raiseEvent('sysConnectionEvent')
          raiseEvent('aardwolf-vibe.character.updated.status')
          gmcp.room.info.zone='three';raiseEvent('gmcp.room.info')
          assert(#sent==3)
          failOnWrite=dbOperation+2
          response('Failed Area',1,true)
          assert(rollbacks==1 and #assert(tracker:search({}))==3)
          assert(tracker:stop())
        ''')

    def test_panel_filters_and_workspace_rehosting(self):
        lua = self.runtime()
        lua.execute(r'''
          workspace={}
          function workspace:registerPanel(spec)
            self.spec=spec
            local host=Geyser.Container:new({name='mob-deaths-test-host'})
            spec.mount(host)
            return {
              show=function() spec.onVisibilityChanged(true);return true end,
              hide=function() spec.onVisibilityChanged(false);return true end,
            }
          end
          function workspace:unregisterPanel(id) self.removed=id;return true end
          tracker=Factory.new(_G,character,workspace,StoreFactory)
          assert(tracker:start())
          assert(workspace.spec.preferredStackWith=='aardwolf-vibe.chat')
          local root=widgets['aardwolf-vibe.mob-deaths.root']
          assert(root.width=='100%' and root.height=='100%')
          gmcp.room={info={zone='lake'}};raiseEvent('gmcp.room.info')
          response('A & B',7,false)
          assert(#assert(tracker:search({area='A & B',minimum=4}))==1)
          assert(widgets['aardwolf-vibe.mob-deaths.area'].text=='A & B')
          assert(widgets['aardwolf-vibe.mob-deaths.minimum'].text=='4')
          widgets['aardwolf-vibe.mob-deaths.area']:print('a & b')
          widgets['aardwolf-vibe.mob-deaths.minimum']:print('4')
          widgets['aardwolf-vibe.mob-deaths.maximum']:print('4')
          widgets['aardwolf-vibe.mob-deaths.search'].callback()
          assert(widgets['aardwolf-vibe.mob-deaths.results'].text=='1 mob found')
          local row=widgets['aardwolf-vibe.mob-deaths.row.1']
          assert(row and row.height>=46)
          assert(widgets[row.name..'.name'].text=='A duck')
          assert(widgets[row.name..'.area'].text=='A &amp; B')
          assert(widgets[row.name..'.stats'].text=='L4 · K7')
          assert(widgets[row.name..'.stats'].toolTip:find('Level 4',1,true))
          assert(widgets['aardwolf-vibe.mob-deaths.name'].style:find('QPlainTextEdit',1,true))
          assert(widgets['aardwolf-vibe.mob-deaths.search'].style:find('QLabel:hover',1,true))
          dbRows['long']={identity='long',name=string.rep('Long mob name ',10),
            area=string.rep('Faraway area ',6),level=17,killed=12,observed=10}
          local body=widgets['aardwolf-vibe.mob-deaths.body']
          body.get_width=function() return 430 end
          assert(#assert(tracker:search({name='Long mob name'}))==1)
          local wideHeight=row.height
          body.get_width=function() return 250 end
          workspace.spec.onResize()
          assert(row.height>wideHeight)
          assert(widgets[row.name..'.area'].height>14)
          assert(#assert(tracker:search({name='absent'}))==0)
          assert(not widgets[row.name])
          assert(widgets['aardwolf-vibe.mob-deaths.results'].text:find('No mobs found',1,true))
          widgets['aardwolf-vibe.mob-deaths.minimum']:print('20')
          widgets['aardwolf-vibe.mob-deaths.maximum']:print('4')
          widgets['aardwolf-vibe.mob-deaths.search'].callback()
          workspace.spec.onResize()
          assert(widgets['aardwolf-vibe.mob-deaths.results'].text
            :find('Minimum level exceeds maximum level',1,true))
          assert(widgets['aardwolf-vibe.mob-deaths.results'].style:find('#f0b3a9',1,true))
          widgets['aardwolf-vibe.mob-deaths.clear'].callback()
          assert(widgets['aardwolf-vibe.mob-deaths.results'].text=='2 mobs found')
          assert(tracker:hide() and not tracker:status().visible)
          assert(tracker:show() and tracker:status().visible)
          local smaller=Geyser.Container:new({name='mob-deaths-smaller-host'})
          workspace.spec.mount(smaller)
          assert(root.parent==smaller and root.width=='100%' and root.height=='100%')
          workspace.spec.unmount(root)
          assert(root.parent==widgets['aardwolf-vibe.mob-deaths.window'])
          assert(tracker:stop() and workspace.removed=='aardwolf-vibe.mob-deaths')
        ''')

    def test_waits_for_authenticated_fresh_room_and_resets_on_character_change(self):
        lua = self.runtime()
        lua.execute(r'''
          statusFresh=false
          assert(tracker:start())
          gmcp.room={info={zone='one'}};raiseEvent('gmcp.room.info')
          assert(#sent==0)
          statusFresh=true;raiseEvent('aardwolf-vibe.character.updated.status')
          assert(#sent==0)
          raiseEvent('gmcp.room.info')
          assert(#sent==1)
          response('Area One',10,false)
          advance(0.1)
          raiseEvent('aardwolf-vibe.character.updated.base',{name='First'})
          raiseEvent('aardwolf-vibe.character.updated.base',{name='Second'})
          assert(not tracker:status().lastZone)
          raiseEvent('gmcp.room.info')
          assert(#sent==2)
          assert(tracker:stop())
        ''')


if __name__ == "__main__":
    unittest.main()
