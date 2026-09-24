from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]


class QuestTrackerTests(unittest.TestCase):
    def runtime(self, workspace=False):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute((ROOT / "tests/buffs_window_api.lua").read_text())
        lua.execute((ROOT / "tests/quest_tracker_api.lua").read_text())
        lua.globals().Factory = lua.execute(
            (ROOT / "src/resources/quest-tracker.lua").read_text())
        if workspace:
            lua.execute('''
              workspace = {registration=nil,visible=false}
              function workspace:registerPanel(spec)
                self.registration=spec
                local host=widgets['aardwolf-vibe.quest-tracker.workspace-host']
                  or Geyser.Container:new({name='aardwolf-vibe.quest-tracker.workspace-host'})
                spec.mount(host)
                return {
                  show=function() workspace.visible=true;spec.onVisibilityChanged(true);return true end,
                  hide=function() workspace.visible=false;spec.onVisibilityChanged(false);return true end,
                  status=function() return {visible=workspace.visible} end,
                }
              end
              function workspace:unregisterPanel(id) self.unregistered=id;return true end
              tracker=Factory.new(_G,character,workspace)
            ''')
        else:
            lua.execute("tracker=Factory.new(_G,character)")
        return lua

    def test_parsing_and_quest_gmcp(self):
        lua = self.runtime()
        lua.execute(r'''
          local parsed=assert(Factory.parseCheck('cp', {
            'You still have to kill * the (Masked) Guard (Hall (East) - Dead)',
          }))
          assert(parsed.active and #parsed.rows==1)
          assert(parsed.rows[1].mob=='the (Masked) Guard')
          assert(parsed.rows[1].location=='Hall (East)' and parsed.rows[1].dead)
          assert(parsed.rows[1].remaining==1)
          parsed=assert(Factory.parseCheck('gq', {
            'You still have to kill 3 * <dragon> (The Hollow)',
          }))
          assert(parsed.rows[1].remaining==3 and parsed.rows[1].location=='The Hollow')
          assert(Factory.parseCheck('cp',{'You are not currently on a campaign.'}).active==false)
          assert(Factory.parseCheck('gq',{'You are not in a global quest.'}).active==false)
          assert(Factory.parseCheck('gq',{'Global quest # 42 has not yet started.'}).state=='pending')
          assert(not Factory.parseCheck('cp',{'unrelated line'}))
          assert(not Factory.parseCheck('cp',{'You still have to kill * bad target'}))
          assert(tracker:start())
          gmcp.comm.quest={action='start',targ='<dragon>',area='Caves & Ruins',room='Outer @rSpace'}
          raiseEvent('gmcp.comm.quest')
          local snap=tracker:snapshot()
          assert(snap.quest.state=='active' and snap.quest.mob=='<dragon>')
          assert(snap.quest.area=='Caves & Ruins' and snap.quest.room=='Outer Space')
          widgets['aardwolf-vibe.quest-tracker.tab.quest'].callback()
          local shown=widgets['aardwolf-vibe.quest-tracker.content'].text
          assert(shown:find('&lt;dragon&gt;',1,true) and shown:find('Caves &amp; Ruins',1,true))
          assert(shown:find('Remaining: 1',1,true))
          snap.quest.mob='modified'
          assert(tracker:snapshot().quest.mob=='<dragon>')
          gmcp.comm.quest={action='killed'};raiseEvent('gmcp.comm.quest')
          assert(tracker:snapshot().quest.state=='target killed')
          gmcp.comm.quest={action='comp'};raiseEvent('gmcp.comm.quest')
          assert(tracker:snapshot().quest.state=='inactive')
          gmcp.comm.quest={action='status',status='ready'};raiseEvent('gmcp.comm.quest')
          assert(tracker:snapshot().quest.state=='ready')
          assert(tracker:stop() and not widgets['aardwolf-vibe.quest-tracker.window'])
          assert(not handlers['aardwolf-vibe.quest-tracker:quest'])
        ''')

    def test_refresh_capture_failure_rate_limit_and_reset(self):
        lua = self.runtime()
        lua.execute(r'''
          assert(tracker:start())
          assert(#gmcpSent==1 and gmcpSent[1]=='request quest')
          assert(#sent==1 and sent[1].command=='cp check' and sent[1].echoCommand==false)
          incoming('You still have to kill * Evil <orc> (Area & One)')
          incoming('You have 2 days left to finish this campaign.')
          advance(0.1)
          assert(#sent==2 and sent[2].command=='gq check')
          incoming('You still have to kill 2 * an ogre (The Great Hall)');prompt()
          assert(tracker:snapshot().cp.rows[1].location=='Area & One')
          assert(tracker:snapshot().gq.rows[1].remaining==2)
          widgets['aardwolf-vibe.quest-tracker.tab.cp'].callback()
          local row=tracker:snapshot().cp.rows[1]
          local shown=widgets['aardwolf-vibe.quest-tracker.row.'..row.id..'.text'].text
          assert(shown:find('Evil &lt;orc&gt;',1,true)
            and shown:find('Area &amp; One',1,true)
            and shown:find('Area or room:',1,true))
          local card=widgets['aardwolf-vibe.quest-tracker.row.'..row.id]
          local background=widgets[card.name..'.background']
          assert(widgets[card.name..'.text'].style:find(
            'background-color: transparent',1,true))
          assert(card.height<=80 and background.style:find('border-radius: 7px',1,true))
          incoming('Congratulations, that was one of your CAMPAIGN mobs!')
          assert(#sent==2)
          advance(8)
          assert(#sent==3 and sent[3].command=='cp check')
          incoming('unrelated output');prompt()
          assert(tracker:status().campaignStale)
          assert(tracker:snapshot().cp.rows[1].mob=='Evil <orc>')
          assert(tracker:refresh())
          assert(#gmcpSent==2 and #sent==4 and sent[4].command=='cp check')
          incoming('You are not currently on a campaign.');prompt()
          advance(0.1)
          assert(#sent==5 and sent[5].command=='gq check')
          advance(20)
          assert(tracker:status().globalQuestStale)
          assert(tracker:snapshot().gq.rows[1].mob=='an ogre')
          assert(tracker:snapshot().cp.state=='inactive')
          raiseEvent('sysDisconnectionEvent')
          assert(tracker:snapshot().gq.state=='unknown' and not tracker:status().capture)
          assert(not tracker:refresh())
          connection=true;raiseEvent('sysConnectionEvent')
          raiseEvent('aardwolf-vibe.character.updated.status')
          assert(#gmcpSent==3)
          assert(tracker:stop())
        ''')

    def test_campaign_finishes_without_ga_and_accepts_manual_check(self):
        lua = self.runtime()
        lua.execute(r'''
          assert(tracker:start())
          incoming('You still have to kill * a singing bat (Art of Melody)')
          incoming('You still have to kill * a wild turkey (Gallows Hill)')
          incoming('You have 6 days, 23 hours and 56 minutes left to finish this campaign.')
          assert(tracker:snapshot().cp.state=='active')
          assert(#tracker:snapshot().cp.rows==2)
          assert(not tracker:status().capture)
          advance(0.1)
          incoming('You are not in a global quest.')
          assert(tracker:snapshot().gq.state=='inactive')
          assert(not tracker:status().capture)
          raiseEvent('sysDataSendRequest', 'cp ch')
          assert(tracker:status().capture=='cp')
          incoming('You still have to kill * a deer tick (Gallows Hill)')
          incoming('You have 6 days, 23 hours and 55 minutes left to finish this campaign.')
          assert(tracker:snapshot().cp.state=='active')
          assert(#tracker:snapshot().cp.rows==3)
          assert(tracker:snapshot().cp.rows[1].completed)
          assert(tracker:snapshot().cp.rows[2].completed)
          assert(tracker:snapshot().cp.rows[3].mob=='a deer tick')
          raiseEvent('sysDataSendRequest', 'campaign check')
          incoming('You are not currently on a campaign.')
          assert(tracker:snapshot().cp.state=='inactive')
          assert(not tracker:status().campaignStale)
          assert(not tracker:status().capture)
          assert(tracker:stop())
        ''')

    def test_where_button_rooms_no_match_and_capture_queue(self):
        lua = self.runtime()
        lua.execute(r'''
          assert(Factory.parseWhereLine(
            'a wild turkey                  At the South-West corner of the rye field',
            'a wild turkey')=='At the South-West corner of the rye field')
          assert(not Factory.parseWhereLine('a wild turkey chick    Wrong Room', 'a wild turkey'))
          assert(tracker:start())
          incoming('You still have to kill * a wild turkey (Gallows Hill)')
          incoming('You have 6 days left to finish this campaign.')
          advance(0.1)
          widgets['aardwolf-vibe.quest-tracker.tab.cp'].callback()
          local row=tracker:snapshot().cp.rows[1]
          local button=widgets['aardwolf-vibe.quest-tracker.row.'..row.id..'.where']
          assert(button and button.callback)
          button.callback()
          assert(#sent==2 and tracker:snapshot().cp.rows[1].whereStatus=='queued')
          incoming('You are not in a global quest.')
          advance(0.1)
          assert(#sent==3 and sent[3].command=='where a wild turkey')
          assert(tracker:status().capture=='where')
          incoming('a wild turkey                  At the South-West corner of the rye field')
          advance(1)
          row=tracker:snapshot().cp.rows[1]
          assert(row.whereStatus=='found' and #row.whereRooms==1)
          assert(row.whereRooms[1]=='At the South-West corner of the rye field')
          assert(row.location=='Gallows Hill')
          button.callback()
          incoming('a wild turkey                 The East Field')
          incoming('a wild turkey                 The West Field')
          incoming('a wild turkey                 The West Field')
          advance(1)
          row=tracker:snapshot().cp.rows[1]
          assert(#row.whereRooms==2 and row.whereRooms[1]=='The East Field')
          assert(row.whereRooms[2]=='The West Field')
          local shown=widgets['aardwolf-vibe.quest-tracker.row.'..row.id..'.text'].text
          assert(shown:find('Possible rooms',1,true)
            and shown:find('Area or room: Gallows Hill',1,true))
          assert(widgets['aardwolf-vibe.quest-tracker.row.'..row.id].height>70)
          button.callback()
          incoming('There is no wild turkey around here.')
          row=tracker:snapshot().cp.rows[1]
          assert(row.whereStatus=='not-found' and #row.whereRooms==2)
          assert(tracker:stop())
          assert(not widgets['aardwolf-vibe.quest-tracker.row.'..row.id])
          assert(not tracker:status().capture)
        ''')

    def test_kill_reconciliation_gq_progress_and_new_activity(self):
        lua = self.runtime()
        lua.execute(r'''
          assert(tracker:start())
          incoming('You are not currently on a campaign.')
          advance(0.1)
          incoming('You still have to kill 3 * an ogre (The Great Hall)')
          incoming('You still have to kill 1 * a wyvern (Cliff)')
          advance(1)
          local rows=tracker:snapshot().gq.rows
          assert(#rows==2 and rows[1].initialRemaining==3)
          incoming('Congratulations, that was one of the GLOBAL QUEST mobs!')
          advance(8)
          assert(tracker:status().capture=='gq')
          incoming('You still have to kill 2 * an ogre (The Great Hall)')
          incoming('You still have to kill 1 * a wyvern (Cliff)')
          advance(1)
          rows=tracker:snapshot().gq.rows
          assert(rows[1].remaining==2 and rows[1].initialRemaining==3
            and not rows[1].completed)
          incoming('Congratulations, that was one of the GLOBAL QUEST mobs!')
          advance(8)
          incoming('You still have to kill 1 * a wyvern (Cliff)')
          advance(1)
          rows=tracker:snapshot().gq.rows
          assert(rows[1].completed and rows[1].remaining==0 and not rows[2].completed)
          local oldID=rows[1].id
          widgets['aardwolf-vibe.quest-tracker.tab.gq'].callback()
          assert(widgets['aardwolf-vibe.quest-tracker.row.'..oldID..'.text'].style:find(
            'background-color: transparent',1,true))
          assert(widgets['aardwolf-vibe.quest-tracker.row.'..oldID..'.where'].hidden)
          incoming('You have now joined Global Quest # 99')
          assert(#tracker:snapshot().gq.rows==0)
          assert(not widgets['aardwolf-vibe.quest-tracker.row.'..oldID])
          assert(tracker:stop())
        ''')

    def test_duplicate_names_and_failed_refresh_do_not_invent_kills(self):
        lua = self.runtime()
        lua.execute(r'''
          assert(tracker:start())
          incoming('You still have to kill * a guard (North Hall)')
          incoming('You still have to kill * a guard (South Hall)')
          incoming('You have 2 days left to finish this campaign.')
          advance(0.1)
          incoming('You are not in a global quest.')
          assert(tracker:refresh())
          incoming('unrelated output');prompt()
          local rows=tracker:snapshot().cp.rows
          assert(#rows==2 and not rows[1].completed and not rows[2].completed)
          assert(tracker:refresh())
          incoming('You still have to kill * a guard (South Hall)');prompt()
          rows=tracker:snapshot().cp.rows
          assert(tracker:status().campaignStale and not rows[1].completed)
          assert(tracker:refresh())
          incoming('You still have to kill * a guard (South Hall)')
          incoming('You have 2 days left to finish this campaign.')
          rows=tracker:snapshot().cp.rows
          assert(rows[1].completed and not rows[2].completed)
          incoming("Questor tells you 'I have selected 2 targets for you to hunt'")
          assert(#tracker:snapshot().cp.rows==0)
          assert(tracker:stop())
        ''')

    def test_new_activity_cancels_where_and_completion_retains_cards(self):
        lua = self.runtime()
        lua.execute(r'''
          assert(tracker:start())
          incoming('You still have to kill * a wild turkey (Gallows Hill)')
          incoming('You have 2 days left to finish this campaign.')
          advance(0.1)
          incoming('You are not in a global quest.')
          widgets['aardwolf-vibe.quest-tracker.tab.cp'].callback()
          local old=tracker:snapshot().cp.rows[1]
          local oldButton=widgets['aardwolf-vibe.quest-tracker.row.'..old.id..'.where']
          oldButton.callback()
          assert(tracker:status().capture=='where')
          incoming("Questor tells you 'I have selected 1 targets for you to hunt'")
          assert(not tracker:status().capture and #tracker:snapshot().cp.rows==0)
          incoming('a wild turkey           Stale Room');prompt()
          assert(#tracker:snapshot().cp.rows==0)
          assert(not widgets['aardwolf-vibe.quest-tracker.row.'..old.id])
          advance(8)
          assert(tracker:status().capture=='cp')
          incoming('You still have to kill * a new target (New Area)')
          incoming('You have 2 days left to finish this campaign.')
          local row=tracker:snapshot().cp.rows[1]
          assert(row.mob=='a new target' and not row.completed)
          incoming('CONGRATULATIONS! You have completed your campaign.')
          row=tracker:snapshot().cp.rows[1]
          assert(row.completed and row.remaining==0)
          assert(widgets['aardwolf-vibe.quest-tracker.row.'..row.id..'.where'].hidden)
          incoming('Campaign cleared.')
          assert(#tracker:snapshot().cp.rows==1)
          raiseEvent('sysDisconnectionEvent')
          assert(#tracker:snapshot().cp.rows==0)
          assert(not widgets['aardwolf-vibe.quest-tracker.row.'..row.id])
          assert(tracker:stop())
        ''')

    def test_where_timeout_and_command_validation(self):
        lua = self.runtime()
        lua.execute(r'''
          assert(tracker:start())
          incoming('You still have to kill * a mob;quit (Unsafe Area)')
          incoming('You have 2 days left to finish this campaign.')
          advance(0.1)
          incoming('You are not in a global quest.')
          widgets['aardwolf-vibe.quest-tracker.tab.cp'].callback()
          local bad=tracker:snapshot().cp.rows[1]
          local count=#sent
          widgets['aardwolf-vibe.quest-tracker.row.'..bad.id..'.where'].callback()
          assert(#sent==count and tracker:status().lastError=='Cannot search this mob name safely')
          incoming("Questor tells you 'I have selected 1 targets for you to hunt'")
          advance(8)
          incoming('You still have to kill * a safe mob (Safe Area)')
          incoming('You have 2 days left to finish this campaign.')
          local safe=tracker:snapshot().cp.rows[1]
          widgets['aardwolf-vibe.quest-tracker.row.'..safe.id..'.where'].callback()
          assert(tracker:status().capture=='where')
          advance(20)
          safe=tracker:snapshot().cp.rows[1]
          assert(safe.whereStatus=='failed' and #safe.whereRooms==0)
          assert(not tracker:status().capture)
          assert(tracker:stop())
        ''')

    def test_workspace_rehost_and_standalone_visibility(self):
        lua = self.runtime(workspace=True)
        lua.execute(r'''
          assert(tracker:start())
          assert(workspace.registration.preferredStackWith=='aardwolf-vibe.chat')
          local root=widgets['aardwolf-vibe.quest-tracker.root']
          local host=widgets['aardwolf-vibe.quest-tracker.workspace-host']
          assert(root.parent==host and root.width=='100%' and root.height=='100%')
          assert(tracker:show() and tracker:status().visible)
          workspace.registration.unmount(root)
          assert(root.parent==widgets['aardwolf-vibe.quest-tracker.window'])
          local small=Geyser.Container:new({name='small',width=250,height=180})
          workspace.registration.mount(small)
          assert(root.parent==small and root.width=='100%' and root.height=='100%')
          assert(tracker:hide() and not tracker:status().visible)
          assert(tracker:stop())
          assert(workspace.unregistered=='aardwolf-vibe.quest-tracker')
        ''')

    def test_character_change_cancels_capture_until_fresh_status(self):
        lua = self.runtime()
        lua.execute(r'''
          assert(tracker:start())
          raiseEvent('aardwolf-vibe.character.updated.base',{name='First'})
          assert(tracker:status().capture=='cp')
          incoming('You still have to kill * a guard (Old Area)')
          raiseEvent('aardwolf-vibe.character.updated.base',{name='Second'})
          assert(not tracker:status().capture)
          assert(tracker:snapshot().cp.state=='unknown')
          local before=#sent
          prompt()
          assert(#sent==before and tracker:snapshot().cp.state=='unknown')
          statusFresh=false
          raiseEvent('aardwolf-vibe.character.updated.status')
          assert(#sent==before)
          statusFresh=true
          raiseEvent('aardwolf-vibe.character.updated.status')
          assert(#sent==before+1 and sent[#sent].command=='cp check')
          assert(tracker:stop())
        ''')


if __name__ == "__main__":
    unittest.main()
