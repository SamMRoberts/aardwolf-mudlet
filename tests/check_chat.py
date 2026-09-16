"""Communications behavior on the built Lua 5.1 package; real regex/native QA separate."""
import unittest
import check_package


class ChatTests(unittest.TestCase):
    def setUp(self):
        harness = check_package.PackageTests()
        harness.setUp()
        self.addCleanup(harness.doCleanups)
        self.lua = harness.lua
        self.lua.execute('''
          connected=true
          function raiseEvent(event,...) fire(event,...) end
          assert(AardwolfToolbox.start());t=AardwolfToolbox;c=t.config;chat=t.chat
          function settle() for i=1,4 do flushEvents() end end
          function observe(path,value)
            local root,leaf=path:match('^(%w+)%.(%w+)$')
            gmcp=gmcp or {};gmcp[root]=gmcp[root] or {};gmcp[root][leaf]=value
            fire('gmcp.'..root,'gmcp.'..path);settle()
          end
          observe('char.base',{name='Tester'});observe('char.status',{state=3})
          function message(channel,text,sender) observe('comm.channel',{chan=channel,msg=text,player=sender or 'Friend'}) end
          function fieldRecord(key,values)
            local record={id=values.id}
            for _,s in ipairs(c.features.chat.settings) do if s.key==key then
              for _,f in ipairs(s.fields) do record[f.key]=f.default end
            end end
            for k,v in pairs(values) do record[k]=v end;return record
          end
          settle();b=t.shell.getBase()
        ''')

    def test_groups_unknown_channels_repeated_messages_and_history_event_once(self):
        self.lua.execute('''
          local events=0
          registerNamedEventHandler('test','messages','AardwolfToolbox.chat.message',function() events=events+1 end)
          message('gtell','Group hello');assert(b.chats.chat_group.text=='Group hello\\n' and not b.chats.tells.text)
          message('question','Question');message('answer','Answer');assert(b.chats.newbie.text=='Question\\nAnswer\\n')
          message('future_channel','Same');message('future_channel','Same')
          assert(events==5 and b.chats.channels.text=='Same\\nSame\\n')
          assert(#chat.list()==5 and #chat.channels()<#chat.options().channels)
          assert(not chat.send('future_channel','','message'))
        ''')

    def test_hide_mute_route_highlight_and_preview_have_separate_effects(self):
        self.lua.execute('''
          local rules={
            fieldRecord('rules',{id='route',pattern='hello',action='route',destination='trade'}),
            fieldRecord('rules',{id='first',pattern='hello',color='cyan'}),
            fieldRecord('rules',{id='last',pattern='hello',color='magenta'}),
            fieldRecord('rules',{id='alert',pattern='hello',action='alert'}),
            fieldRecord('rules',{id='mute',pattern='hello',action='mute'})}
          assert(c.set('chat','rules',rules));settle()
          local before=#chat.list();local notices=#t.notifications.list('chat')
          local preview=assert(chat.preview({chan='gossip',msg='hello',player='Friend'}))
          assert(preview.muted and preview.alert and preview.highlight=='magenta' and preview.destinations.trade)
          assert(#chat.list()==before and #t.notifications.list('chat')==notices)
          message('gossip','hello');assert(b.chats.trade.text=='hello\\n')
          assert(b.chats.trade.runs[1].fg[1]==245)
          rules[1]=fieldRecord('rules',{id='hide',action='hide',pattern='hello'})
          assert(c.set('chat','rules',rules));settle();before=#chat.list()
          message('say','hello');assert(#chat.list()==before and not b.chats.local_chat.text)
        ''')

    def test_validation_protects_all_and_references_without_saving(self):
        self.lua.execute('''
          local draft,revision=c.draft();draft.chat.tabs[1].enabled=false
          assert(not c.apply(draft,revision));assert(c.get('chat','tabs')[1].enabled)
          local rules={fieldRecord('rules',{id='route',action='route',destination='missing'})}
          assert(not c.set('chat','rules',rules))
          rules={fieldRecord('rules',{id='regex',match='regex',pattern='('})}
          assert(not c.set('chat','rules',rules));assert(#c.get('chat','rules')==0)
          local channels=c.get('chat','channels');channels[1].command='say;quit';assert(not c.set('chat','channels',channels))
        ''')

    def test_dynamic_tabs_and_placements_keep_buffers_and_remove_hosts(self):
        self.lua.execute('''
          message('gossip','preserved');local all=b.chats.all
          local tabs=c.get('chat','tabs');tabs[#tabs+1]=fieldRecord('tabs',{id='custom',label='Custom',channels='gossip'})
          assert(c.set('chat','tabs',tabs));settle();assert(t.views.available('custom'))
          message('gossip','new');assert(b.chats.custom.text=='new\\n')
          assert(t.views.setMode('custom','floating'));settle()
          local host=widgets['AardwolfToolbox.dashboard.chatHost.custom']
          assert(host.parent==widgets['AardwolfToolbox.views.TestProfile.custom'])
          assert(all==b.chats.all and all.text=='preserved\\nnew\\n')
          tabs=c.get('chat','tabs');table.remove(tabs);assert(c.set('chat','tabs',tabs));settle()
          assert(not t.views.available('custom') and not widgets['AardwolfToolbox.dashboard.chatHost.custom'])
          t.stop();assert(count(widgets)==0 and count(handlers)==0 and count(timers)==0)
        ''')

    def test_composer_never_expands_aliases_preserves_failed_drafts_and_awaits_echo(self):
        self.lua.execute('''
          local sent={};send=function(command,echo) assert(echo==false);sent[#sent+1]=command;return true end
          expandAlias=function() error('Must never expand') end
          local ok=chat.send('tell','Friend','hello');assert(ok and sent[1]=='tell Friend hello')
          assert(chat.draft('tell:friend')=='' and chat.recall('tell:friend',1)=='hello')
          assert(not b.chats.tells.text)
          assert(not chat.send('tell','Friend;quit','hello'))
          assert(not chat.send('say','','hello\\nquit'))
          assert(not chat.send('auction','','sale'))
          observe('char.status',{state=7});assert(not chat.send('say','','keep this'))
          assert(chat.draft('say:')=='keep this' and #sent==1)
          observe('char.status',{state=3});message('tell',"You tell Friend 'hello'",'Tester')
          assert(chat.list()[1].peer=='Friend' and chat.list()[1].outgoing)
        ''')

    def test_workspace_drafts_conversations_rule_preview_and_cleanup(self):
        self.lua.execute('''
          message('tell','Friend tells you hello')
          assert(t.views.open('tells'));assert(t.chatWorkspace.compose('tells','tell','Friend'))
          assert(t.dashboard.isEditing())
          local input=widgets['AardwolfToolbox.chatWorkspace.message'];input:print('draft')
          t.chatWorkspace.close();assert(chat.draft('tell:friend')=='draft')
          assert(t.chatWorkspace.compose('tells','tell','Friend'));assert(widgets[input.name].text=='draft')
          t.chatWorkspace.people('tells');widgetContaining('Friend · 1 unread').callback()
          assert(widgets['AardwolfToolbox.chatWorkspace.thread'].text=='Friend tells you hello\\n')
          assert(chat.conversations()[1].unread==0)
          t.chatWorkspace.rules('tells');widgets['AardwolfToolbox.chatWorkspace.previewText'].action('sample')
          assert(widgets['AardwolfToolbox.chatWorkspace.status'].text:find('Routes:'))
          t.stop();assert(count(widgets)==0 and count(handlers)==0 and count(timers)==0)
        ''')

    def test_alerts_once_across_tabs_cooldown_mute_and_outgoing(self):
        self.lua.execute('''
          local alerts,sounds={},{};showNotification=function(...) alerts[#alerts+1]={...} end
          hasFocus=function() return false end;playSoundFile=function(p) sounds[#sounds+1]=p;return true end
          files[getMudletHomeDir()..'/AardwolfToolbox/chat-chime.wav']='sound'
          assert(c.set('chat','desktop',true));assert(c.set('chat','sound',true));settle()
          message('tell','private words');assert(#alerts==1 and #sounds==1)
          assert(alerts[1][2]=='New chat message in Mudlet')
          local notices=t.notifications.list('chat');assert(#notices==1)
          message('tell','second');assert(#alerts==1 and #t.notifications.list('chat')==2)
          message('tell',"You tell Friend 'outgoing'",'Tester');assert(#t.notifications.list('chat')==2)
          assert(c.set('chat','dnd',true));message('tell','silent');assert(#t.notifications.list('chat')==2)
        ''')

    def test_protocol_takeover_reconnect_and_teardown_order(self):
        self.lua.execute('''
          local calls={};sendGMCP=function(value) calls[#calls+1]=value;return true end
          assert(c.set('chat','enabled',false));settle();assert(c.set('chat','enabled',true));settle()
          assert(calls[#calls]=='gmcpchannels on' and chat.status().requested=='on')
          local disable=gmod.disableModule
          gmod.disableModule=function(owner,module)
            if owner=='AardwolfToolbox.chat' then assert(calls[#calls]=='gmcpchannels off') end
            return disable(owner,module)
          end
          assert(c.set('chat','enabled',false));assert(chat.status().requested=='off')
          gmod.disableModule=disable
          assert(c.set('chat','enabled',true));settle()
          fire('sysDisconnectionEvent');settle();assert(chat.status().requested=='off')
          fire('sysConnectionEvent');observe('char.base',{name='Tester'});settle();assert(chat.status().requested=='on')
        ''')

    def test_identity_switch_clears_private_state_and_stale_handlers(self):
        self.lua.execute('''
          message('tell','old private');chat.draft('tell:friend','private draft')
          local callback=handlers['AardwolfToolbox.chat:receive'].fn
          observe('char.base',{name='SomeoneElse'})
          assert(#chat.list()==0 and chat.draft('tell:friend')=='' and #chat.conversations()==0)
          t.stop();assert(t.start());settle()
          callback('AardwolfToolbox.gmcp.updated','comm.channel');assert(#chat.list()==0)
        ''')

    def test_malformed_packet_does_not_disable_receiving(self):
        self.lua.execute('''
          observe('comm.channel',{chan={},msg='invalid'});assert(#chat.list()==0)
          observe('comm.channel',{chan='say',msg=string.rep('x',65401)});assert(#chat.list()==0)
          observe('char.base',{name=3})
          message('gossip','valid');assert(#chat.list()==1)
          observe('comm.channel',{chan='say',msg='bad sender',player='Friend\\nquit'});assert(#chat.list()==1)
        ''')

    def test_migration_backs_up_exact_bytes_and_preserves_unrelated_preferences(self):
        self.lua.execute('''
          local Config=assert(loadstring(sources.configuration))()
          local Files=assert(loadstring(sources['preferences-files']))()
          local Model=assert(loadstring(sources['chat-model']))()
          local path=getMudletHomeDir()..'/AardwolfToolbox-settings.json'
          local old=yajl.to_string({version=3,values={shell={timestamps=true,chat_colors='raw',hidden_channels='auction',mentions=false,mention_words='raid'},views={clan='floating'},history={chat=true},absent={setting='preserve'}}})
          files[path]=old
          local config=Config.new(_G,Files.new(_G))
          local def=Model.definition(function() return true end,_G)
          assert(config.migrateChat(def));config.registerFeature(def)
          assert(config.get('chat','timestamps') and config.get('chat','chat_colors')=='raw')
          assert(config.get('chat','hidden_channels')=='auction' and not config.get('chat','mentions'))
          assert(config.get('chat','tabs')[3].placement=='floating')
          assert(files[config.getMetadata('chatMigrationBackup')]==old)
          local saved=yajl.to_value(files[path]);assert(saved.version==3 and saved.values.absent.setting=='preserve' and saved.values.history.chat)
          local backup=config.getMetadata('chatMigrationBackup');assert(config.migrateChat(def));assert(config.getMetadata('chatMigrationBackup')==backup)
        ''')

    def test_migration_write_failure_keeps_original_settings(self):
        self.lua.execute('''
          local Config=assert(loadstring(sources.configuration))()
          local Files=assert(loadstring(sources['preferences-files']))()
          local Model=assert(loadstring(sources['chat-model']))()
          local path=getMudletHomeDir()..'/AardwolfToolbox-settings.json'
          local old=yajl.to_string({version=3,values={shell={timestamps=true}}});files[path]=old
          local config=Config.new(_G,Files.new(_G));fileFailures.rename=true
          assert(not config.migrateChat(Model.definition(function() return true end,_G)))
          assert(files[path]==old and not config.getMetadata('chatSchema'));fileFailures.rename=nil
        ''')

    def test_hidden_views_keep_receiving_and_deferred_old_character_is_rejected(self):
        self.lua.execute('''
          assert(t.views.setMode('tells','floating'));settle()
          widgets['AardwolfToolbox.views.TestProfile.tells']:hide()
          message('tell','hidden arrival');assert(b.chats.tells.text=='hidden arrival\\n')
          local received=0;registerNamedEventHandler('test','events','AardwolfToolbox.chat.message',function() received=received+1 end)
          t.incoming.add('chat-test',1,function()
            gmcp.comm={channel={chan='tell',msg='old',player='Friend'}};fire('gmcp.comm','gmcp.comm.channel')
            gmcp.char.base={name='NewCharacter'};fire('gmcp.char','gmcp.char.base')
          end)
          incoming('fixture');settle();assert(received==0)
          t.incoming.remove('chat-test');deleteNamedEventHandler('test','events')
        ''')

    def test_legacy_settings_aliases_and_record_reference_editor(self):
        self.lua.execute('''
          assert(c.set('shell','timestamps',true) and c.get('chat','timestamps'))
          assert(c.set('views','clan','floating'));settle();assert(t.views.mode('clan')=='floating')
          assert(c.get('views','clan')=='floating')
          t.openSettings();t.settingsWindow.editRecord('chat','channels','gossip')
          assert(widgetContaining('Channel identifier (server name)'))
          t.settingsWindow.editRecord('chat','tabs','all')
          assert(widgetContaining('None / select explicitly  ▸'))
          t.settingsWindow.close()
        ''')

    def test_rules_match_direction_and_sender_and_hidden_channel_has_no_side_effects(self):
        self.lua.execute('''
          local rules={fieldRecord('rules',{id='outgoing',sender='Tester',direction='outgoing',channels='gossip',action='hide'})}
          assert(c.set('chat','rules',rules));settle()
          message('gossip',"You gossip 'hidden'",'Tester');assert(#chat.list()==0)
          message('gossip','Incoming','Friend');assert(#chat.list()==1)
          local channels=c.get('chat','channels')
          for _,row in ipairs(channels) do if row.id=='tell' then row.enabled=false end end
          assert(c.set('chat','channels',channels));settle()
          local before=#t.notifications.list('chat');message('tell','Do not keep');assert(#chat.list()==1 and #t.notifications.list('chat')==before)
        ''')

    def test_render_failure_restores_server_text_and_reports_failure(self):
        self.lua.execute('''
          local calls={};sendGMCP=function(v) calls[#calls+1]=v;return true end
          chat.attach(function() error('render failure') end);settle()
          message('gossip','recoverable')
          assert(chat.status().requested=='off' and calls[#calls]=='gmcpchannels off')
          assert(chat.status().last:find('render failure',1,true))
          assert(#chat.list()==1)
        ''')

    def test_server_echoes_never_count_as_receipt_acknowledgements(self):
        self.lua.execute('''
          assert(chat.status().requested=='on' and chat.status().received==0)
          message('say','Observed delivery');assert(chat.status().received==1)
          local mirrored=false
          for _,line in ipairs(output) do if line:find('Observed delivery',1,true) then mirrored=true end end
          assert(mirrored)
          assert(c.set('chat','enabled',false));settle();assert(chat.status().requested=='off')
        ''')
