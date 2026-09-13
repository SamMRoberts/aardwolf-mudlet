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

    def test_raw_colors_are_explicit_and_preserve_literals_and_unknown_codes(self):
        self.lua.execute('''
          local Text=assert(loadstring(sources['console-text']))()
          assert(Text.plain('email@gmail.com @@ @R literal','ansi')=='email@gmail.com @@ @R literal')
          assert(Text.plain('@RÉowyn @x196<red> @@ @- @x256 @z $C','raw')=='Éowyn <red> @ ~ @x256 @z $C')
          assert(Text.plain('@x0099 @x00Z @x255last','raw')=='9 Z last')
          local codes={b=4,B=12,c=6,C=14,r=1,R=9,m=5,M=13,g=2,G=10,w=7,W=15,y=3,Y=11,D=8}
          local colors={}; local console={name='test',echo=function(_,value) colors[#colors+1]={value=value,fg=fg} end}
          local api={setFgColor=function(_,...) fg={...} end,setBgColor=function() end}
          for code,n in pairs(codes) do
            colors={};Text.write(api,console,'@'..code..'word','raw');local raw=colors[1].fg
            colors={};Text.write(api,console,string.char(27)..'[38;5;'..n..'mword');local ansi=colors[1].fg
            assert(raw[1]==ansi[1] and raw[2]==ansi[2] and raw[3]==ansi[3])
          end
          colors={};Text.write(api,console,'@x196red'..string.char(27)..'[44mblue background','raw')
          assert(colors[1].fg[1]==255 and colors[1].fg[2]==0)
          assert(fg[1]==224 and fg[2]==230 and fg[3]==236)
        ''')

    def test_raw_chat_setting_persists_without_sending_configuration(self):
        self.lua.execute('''
          assert(AardwolfToolbox.start());local t=AardwolfToolbox
          assert(t.config.set('shell','chat_colors','raw'))
          t.stop();assert(t.start());local b=t.shell.getBase()
          gmcp=gmcp or {};gmcp.comm={channel={chan='gossip',msg='@GHello @@everyone'}}
          fire('gmcp.comm','gmcp.comm.channel');fire('AardwolfToolbox.gmcp.updated','comm.channel')
          assert(b.chats.all.text=='Hello @everyone\\n')
          assert(b.chats.all.runs[1].fg[2]==255)
          assert(t.config.set('shell','chat_colors','ansi'))
          gmcp.comm.channel={chan='gossip',msg='name@gmail.com'};fire('gmcp.comm','gmcp.comm.channel');fire('AardwolfToolbox.gmcp.updated','comm.channel')
          assert(b.chats.all.text:find('name@gmail.com',1,true))
        ''')

    def test_mentions_use_literal_words_and_clear_with_mark_read(self):
        self.lua.execute('''
          assert(AardwolfToolbox.start());local t=AardwolfToolbox;local b=t.shell.getBase()
          assert(t.config.set('shell','mention_words','raid, Éowyn'))
          gmcp={char={base={name='Tesobi'}}};fire('gmcp.char','gmcp.char.base')
          local function chat(text,player)
            gmcp.comm={channel={chan='gossip',msg=text,player=player or 'Friend'}}
            fire('gmcp.comm','gmcp.comm.channel');fire('AardwolfToolbox.gmcp.updated','comm.channel')
          end
          chat('Tesobi, hello');chat('a raider said Tesobius');chat('RAID now');chat('Éowyn joins')
          chat('Tesobi says hello','Tesobi')
          assert(b.mentions.channels==3 and b.unread.channels==5)
          assert(b.chatTabLabels.channels.tooltip:find('3 mentions'))
          t.views.menu();assert(widgetContaining('Channels · 5 unread · 3 mentions !'))
          t.views.closeMenu();b.selectChatTab('channels');assert(b.mentions.channels==0 and b.unread.channels==0)
          assert(t.config.set('shell','mentions',false));b.selectChatTab('all');chat('Tesobi RAID')
          assert(b.mentions.channels==0 and b.unread.channels==1)
        ''')
