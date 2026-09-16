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
          assert(old.chats.all==chat and chat.text=='Existing scrollback\\n')
          t.stop();assert(old.routeChatLine==route and not widgets['AardwolfToolbox.shell.root'])
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
          assert(t.config.set('chat','chat_colors','raw'))
          t.stop();assert(t.start());local b=t.shell.getBase()
          gmcp=gmcp or {};gmcp.comm={channel={chan='gossip',msg='@GHello @@everyone'}}
          fire('gmcp.comm','gmcp.comm.channel');fire('AardwolfToolbox.gmcp.updated','comm.channel')
          assert(b.chats.all.text=='Hello @everyone\\n')
          assert(b.chats.all.runs[1].fg[2]==255)
          assert(t.config.set('chat','chat_colors','ansi'))
          gmcp.comm.channel={chan='gossip',msg='name@gmail.com'};fire('gmcp.comm','gmcp.comm.channel');fire('AardwolfToolbox.gmcp.updated','comm.channel')
          assert(b.chats.all.text:find('name@gmail.com',1,true))
        ''')

    def test_mentions_use_literal_words_and_clear_with_mark_read(self):
        self.lua.execute('''
          assert(AardwolfToolbox.start());local t=AardwolfToolbox;local b=t.shell.getBase()
          assert(t.config.set('chat','mention_words','raid, Éowyn'))
          gmcp={char={base={name='Tesobi'}}};fire('gmcp.char','gmcp.char.base')
          local function chat(text,player)
            gmcp.comm={channel={chan='gossip',msg=text,player=player or 'Friend'}}
            fire('gmcp.comm','gmcp.comm.channel');fire('AardwolfToolbox.gmcp.updated','comm.channel')
          end
          chat('Tesobi, hello');chat('a raider said Tesobius');chat('RAID now');chat('Éowyn joins')
          chat('Tesobi says hello','Tesobi')
          assert(b.mentions.channels==3 and b.unread.channels==4)
          assert(b.chatTabLabels.channels.tooltip:find('3 mentions'))
          t.views.menu();assert(widgetContaining('Public · 4 unread · 3 mentions !'))
          t.views.closeMenu();b.selectChatTab('channels');assert(b.mentions.channels==0 and b.unread.channels==0)
          assert(t.config.set('chat','mentions',false));b.selectChatTab('all');chat('Tesobi RAID')
          assert(b.mentions.channels==0 and b.unread.channels==1)
        ''')

    def test_dedicated_channels_and_own_messages_preserve_unread(self):
        self.lua.execute('''
          assert(AardwolfToolbox.start());local t=AardwolfToolbox;local b=t.shell.getBase()
          gmcp={char={base={name='Tesobi'}}};fire('gmcp.char','gmcp.char.base')
          function chat(channel,player,text)
            gmcp.comm={channel={chan=channel,player=player,msg=text}}
            fire('gmcp.comm','gmcp.comm.channel');fire('AardwolfToolbox.gmcp.updated','comm.channel')
          end
          b.selectChatTab('tells')
          chat('clantalk','Friend','Friend clantalks: hello Tesobi')
          chat('newbie','Newcomer','Newcomer: hello')
          assert(b.unread.clan==1 and b.unread.newbie==1 and b.unread.all==2 and (b.unread.channels or 0)==0)
          assert(b.chats.clan.text=='Friend clantalks: hello Tesobi\\n')
          assert(b.chats.newbie.text=='Newcomer: hello\\n')
          chat('clantalk','tEsObI','Tesobi: my reply')
          chat('newbie','Tesobi','You newbie: hello')
          chat('tell','Friend',string.char(27)..'[32mYou tell Friend: hello')
          assert(b.unread.clan==1 and b.unread.newbie==1 and b.unread.all==2 and (b.unread.channels or 0)==0)
          assert(b.chats.clan.text:find('my reply') and b.chats.tells.text:find('You tell Friend'))
          assert(t.views.setMode('clan','floating'))
          chat('clantalk','Tesobi','You clantalk: reply while floating')
          assert(b.unread.clan==1)
          chat('clantalk','Friend',[[Friend says 'You clantalk: quoted text']])
          assert(b.unread.clan==2)
          assert(t.config.set('chat','hidden_channels','clantalk,newbie'))
          local before=b.chats.clan.text;chat('clantalk','Friend','hidden');assert(b.chats.clan.text==before)
          t.stop();assert(count(widgets)==0 and count(handlers)==0)
          assert(t.start());assert(t.views.mode('clan')=='floating' and t.views.available('newbie'))
        ''')

    def test_compatibility_chat_routes_once_and_restores_starter(self):
        self.lua.execute('''
          dashboardStarter();local old=BaseUI
          function old.routeChatLine(family)
            if old.lastChatLine==lineNumber then return end
            old.lastChatLine=lineNumber
            old.chats.all:echo(line..'\\n');old.noteChatActivity('all')
            old.chats[family]:echo(line..'\\n');old.noteChatActivity(family)
            old.recentCaptures=old.recentCaptures or {}
            table.insert(old.recentCaptures,{text=line,time=getEpoch()})
          end
          function old.routeTaggedChatLine(tag) old.routeChatLine('channels') end
          function old.addChatMessage()
            old.noteChatActivity('all');old.noteChatActivity('tells')
          end
          local route,tagged,add=old.routeChatLine,old.routeTaggedChatLine,old.addChatMessage
          assert(AardwolfToolbox.start());local t=AardwolfToolbox;local b=t.shell.getBase()
          assert(b==old and t.views.available('clan') and t.views.available('newbie'))
          assert(t.views.open('tells'))
          function b.chats.clan:appendBuffer() self:echo(line..'\\n') end
          lineNumber=1;line='Friend clantalks: hello';b.routeTaggedChatLine('clantalk')
          assert((b.unread.clan or 0)==0)
          b.routeTaggedChatLine('clantalk');assert((b.unread.clan or 0)==0)
          gmcp={comm={channel={chan='clantalk',player='Friend',msg=line}}}
          fire('gmcp.comm','gmcp.comm.channel');fire('AardwolfToolbox.gmcp.updated','comm.channel')
          assert(b.unread.clan==1 and b.unread.all==1)
          lineNumber=2;line='Friend clantalks: second';b.routeTaggedChatLine('clantalk')
          gmcp.comm.channel={chan='clantalk',player='Friend',msg=line};fire('gmcp.comm','gmcp.comm.channel');fire('AardwolfToolbox.gmcp.updated','comm.channel')
          assert(b.unread.clan==2 and b.unread.all==2)
          fire('AardwolfToolbox.gmcp.cleared')
          lineNumber=3;line='You clantalk: reply';b.routeTaggedChatLine('clantalk')
          assert(b.unread.clan==2 and b.unread.all==2)
          gmcp.Comm={Channel={Text={text='You tell Friend: hi',player='Friend'}}};b.addChatMessage()
          assert(b.unread.all==2)
          local all=b.chats.all;t.stop()
          assert(b.routeChatLine==route and b.routeTaggedChatLine==tagged and b.addChatMessage==add)
          assert(b.chats.all==all and not all.deleted and not b.chats.clan and not b.chats.newbie)
          assert(t.start());assert(t.views.available('clan'))
        ''')

    def test_missing_identity_and_colored_outgoing_tells(self):
        self.lua.execute('''
          assert(AardwolfToolbox.start());local t=AardwolfToolbox;local b=t.shell.getBase()
          assert(t.config.set('chat','chat_colors','raw'))
          local function chat(msg)
            gmcp={comm={channel={chan='tell',msg=msg}}}
            fire('gmcp.comm','gmcp.comm.channel');fire('AardwolfToolbox.gmcp.updated','comm.channel')
          end
          chat('@GYou tell Friend: hello');assert((b.unread.tells or 0)==0)
          chat([[Friend tells you: 'You tell somebody']]);assert(b.unread.tells==1)
          chat('@GYou tell Friend: response');assert(b.unread.tells==1)
        ''')

    def test_legacy_extra_view_cleanup_restores_selection_and_rejects_old_events(self):
        self.lua.execute('''
          dashboardStarter();assert(AardwolfToolbox.start());local t=AardwolfToolbox;local b=BaseUI
          local callback
          for name,h in pairs(handlers) do if name=='AardwolfToolbox.chat:receive' then callback=h.fn end end
          assert(callback);assert(t.views.open('newbie'));assert(b.activeChatTab=='newbie')
          t.stop();assert(b.activeChatTab=='all' and not b.chats.newbie)
          assert(t.start());local text=b.chats.newbie.text
          gmcp={comm={channel={chan='newbie',player='Friend',msg='fresh'}}}
          fire('gmcp.comm','gmcp.comm.channel')
          local fresh=b.chats.newbie.text
          callback('AardwolfToolbox.gmcp.updated','comm.channel')
          assert(b.chats.newbie.text==fresh)
        ''')

    def test_failed_added_chat_constructor_preserves_borrowed_buffers(self):
        self.lua.execute('''
          dashboardStarter();local original=Geyser.MiniConsole.new;local all=BaseUI.chats.all
          function Geyser.MiniConsole:new(cons,parent)
            if cons.name=='AardwolfToolbox.shell.chat.newbie' then error('Injected chat creation failure') end
            return original(self,cons,parent)
          end
          assert(AardwolfToolbox.start());local t=AardwolfToolbox
          assert(t.config.runtimeErrors.dashboard and BaseUI.chats.all==all and not all.deleted)
          assert(not BaseUI.chats.clan and not BaseUI.chats.newbie)
          Geyser.MiniConsole.new=original
          assert(t.config.set('dashboard','enabled',true));assert(t.views.available('clan') and t.views.available('newbie'))
        ''')
