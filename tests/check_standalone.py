"""Standalone ownership and literal chat rendering; native acceptance is separate."""
import unittest
import check_package

class StandaloneTests(unittest.TestCase):
    def setUp(self):
        harness=check_package.PackageTests();harness.setUp();self.lua=harness.lua;self.addCleanup(harness.doCleanups)

    def test_fresh_profile_has_dashboard_chat_and_one_owned_mapper(self):
        self.lua.execute('''
          assert(BaseUI==nil);assert(AardwolfToolbox.start())
          local t=AardwolfToolbox;assert(t.dashboard.enabled,t.dashboard.last)
          assert(t.shell.enabled and t.views.available('player') and t.views.available('all'))
          local base=t.shell.getBase();local mapper=base.map
          t.start();assert(t.shell.getBase().map==mapper)
          t.stop();assert(count(widgets)==0 and count(handlers)==0 and count(timers)==0)
        ''')

    def test_channel_capture_is_literal_and_uses_native_colors_once(self):
        self.lua.execute('''
          AardwolfToolbox.start();local t=AardwolfToolbox;local b=t.shell.getBase()
          gmcp=gmcp or {};gmcp.comm={channel={chan='tell',msg=string.char(27)..'[31mÉowyn <255,0,0> says hi'}}
          fire('gmcp.comm','gmcp.comm.channel');fire('AardwolfToolbox.gmcp.updated','comm.channel')
          assert(b.chats.all.text=='Éowyn <255,0,0> says hi\\n')
          assert(b.chats.tells.text==b.chats.all.text and not b.chats.channels.text)
          assert(b.chats.all.runs[1].fg[1]==170 and b.chats.all.runs[1].fg[2]==0)
          local old=b.chats.all.text;fire('gmcp.comm','gmcp.comm.channel');assert(b.chats.all.text==old)
          t.stop()
        ''')

    def test_starter_migration_moves_and_restores_borrowed_consoles(self):
        self.lua.execute('''
          dashboardStarter()
          function BaseUI.routeChatLine() end;function BaseUI.routeTaggedChatLine() end;function BaseUI.addChatMessage() end
          local old=BaseUI;local route=old.routeChatLine;local map=old.map;local chat=old.chats.all
          chat:echo('Existing scrollback\\n')
          AardwolfToolbox.start();local t=AardwolfToolbox;assert(not t.shell.enabled)
          assert(t.config.set('shell','mode','toolbox'))
          assert(t.shell.enabled and t.shell.getBase().map==map and t.shell.getBase().chats.all==chat)
          assert(chat.text=='Existing scrollback\\n' and old.routeChatLine~=route)
          assert(t.config.getMetadata('sidebarMigrationBackup'))
          assert(t.config.set('shell','mode','legacy'))
          assert(old.routeChatLine==route and old.chats.all==chat and chat.text=='Existing scrollback\\n')
          t.stop();assert(not widgets['AardwolfToolbox.shell.root'])
        ''')
