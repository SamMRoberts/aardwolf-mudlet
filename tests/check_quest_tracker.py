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
          incoming('You still have to kill * Evil <orc> (Area & One)');prompt()
          advance(0.1)
          assert(#sent==2 and sent[2].command=='gq check')
          incoming('You still have to kill 2 * an ogre (The Great Hall)');prompt()
          assert(tracker:snapshot().cp.rows[1].location=='Area & One')
          assert(tracker:snapshot().gq.rows[1].remaining==2)
          widgets['aardwolf-vibe.quest-tracker.tab.cp'].callback()
          local shown=widgets['aardwolf-vibe.quest-tracker.content'].text
          assert(shown:find('Evil &lt;orc&gt;',1,true)
            and shown:find('Area &amp; One',1,true)
            and shown:find('Area or room:',1,true))
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
