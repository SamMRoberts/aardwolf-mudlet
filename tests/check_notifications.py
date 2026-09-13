"""Notification data, event ordering and retained UI against the built package."""
import unittest
import check_package


class NotificationTests(unittest.TestCase):
    def setUp(self):
        harness = check_package.PackageTests()
        harness.setUp()
        self.addCleanup(harness.doCleanups)
        self.lua = harness.lua
        self.lua.execute('''
          clock=1000;timers={};nextTimer=0
          function getEpoch() return clock end
          function tempTimer(delay,fn) nextTimer=nextTimer+1;timers[nextTimer]={at=clock+delay,fn=fn};return nextTimer end
          function advance(seconds)
            local target=clock+seconds;local steps=0
            while true do
              local id,at
              for k,v in pairs(timers) do if v.at<=target and (not at or v.at<at or v.at==at and k<id) then id,at=k,v.at end end
              if not id then break end
              steps=steps+1;assert(steps<1000,"Timer loop: "..debug.getinfo(timers[id].fn).short_src..":"..debug.getinfo(timers[id].fn).linedefined)
              clock=at;local f=timers[id].fn;timers[id]=nil;f()
            end
            clock=target
          end
          function flushEvents() advance(0) end
          function raiseEvent(event,...)
            local pending={}
            for name,h in pairs(handlers) do
              if h.event==event and (name:find('AardwolfToolbox.notifications:',1,true) or name:find('AardwolfToolbox.notificationPane:',1,true) or name:find('fixture:',1,true)) then pending[#pending+1]=h.fn end
            end
            for _,fn in ipairs(pending) do fn(event,...) end
          end
          assert(AardwolfToolbox.start());t=AardwolfToolbox;n=t.notifications;p=t.notificationPane
          assert(n.enabled,n.last);assert(p.enabled,p.last)
          function send() error('Unexpected gameplay command') end
          function expandAlias() error('Unexpected alias') end
          function W(name) return assert(widgets['AardwolfToolbox.notificationPane.'..name],name) end
          function post(kind,title,key)
            return n.post({category=kind or 'info',source='fixture',title=title or 'Title',message='A literal <message> & detail',key=key})
          end
          function ownedTimers() local c=0;for _ in pairs(timers) do c=c+1 end;return c end
          function noticeHandlers() local c=0;for name in pairs(handlers) do if name:find('AardwolfToolbox.notifications:',1,true) then c=c+1 end end;return c end
          advance(0);n.clear()
        ''')

    def test_defaults_bounds_copies_and_category_preferences(self):
        self.lua.execute('''
          assert(not t.config.get('notifications','blink') and not t.config.get('notifications','sound'))
          local def={category='info',source='fixture',title='Éowyn <safe>',message='Literal & "quoted"'}
          assert(n.post(def));def.title='Changed'
          local a=n.list()[1];assert(a.title=='Éowyn <safe>' and a.session==t.gmcp.session)
          a.title='Mutated';assert(n.get(a.id).title=='Éowyn <safe>')
          assert(n.status().unread==1 and n.markRead(a.id));assert(n.status().unread==0)
          assert(not n.markRead(a.id) and not n.get(9999))
          assert(t.config.set('notifications','info',false));assert(not post());assert(#n.list()==1)
          assert(post('warning'));assert(t.config.set('notifications','limit',20))
          for i=1,35 do assert(post('warning','Notice '..i)) end
          assert(#n.list()==20 and not n.get(a.id));assert(n.list()[1].title=='Notice 35')
          assert(not t.config.set('notifications','limit',501));assert(n.status().count==20)
          n.clear();assert(n.status().unread==0)
        ''')

    def test_invalid_and_stale_notices_rejected(self):
        self.lua.execute('''
          assert(not n.post({category='bad'}))
          for _,field in ipairs({'source','title','message','key'}) do
            local v={category='info',source='source',title='Title',message='Message'};v[field]='bad\\nline';assert(not n.post(v))
          end
          assert(not n.post({category='info',source='s',title=string.rep('x',161),message='m'}))
          assert(not n.post({category='info',source='s',title='t',message=string.rep('x',1025)}))
          assert(not n.post({category='info',source='s',title='t',message='m',callback=function() end}))
          assert(not n.post({category='info',source='s',title='t',message='m',session=-1}))
          assert(#n.list()==0)
        ''')

    def test_duplicates_update_one_row_without_replaying_sound(self):
        self.lua.execute('''
          files['/local.wav']='audio';sounds=0;playSoundFile=function() sounds=sounds+1;return true end
          local d,r=t.config.draft();d.notifications.sound=true;d.notifications.sound_file='/local.wav';assert(t.config.apply(d,r))
          assert(post('warning','Same','failure'));local id=n.list()[1].id;n.markRead(id)
          advance(1);assert(post('warning','Same','failure'))
          assert(#n.list()==1 and n.get(id).count==2 and not n.get(id).read and sounds==1)
          advance(31);assert(post('warning','Same','failure'));assert(#n.list()==2 and sounds==2)
        ''')

    def test_capture_suppression_precedes_events_and_reset_discards_deferred(self):
        self.lua.execute('''
          registerNamedEventHandler('fixture','observe','AardwolfToolbox.notifications.updated',function(_,id)
            if id then visible[#visible+1]='notification observer' end
          end)
          t.incoming.add('fixture-notices',-100,function(text)
            post('warning');return true,true
          end,function(err) error(err) end)
          local before=gagCount;incoming('machine record')
          assert(gagCount==before+1 and visible[#visible]=='notification observer' and #n.list()==1)
          t.incoming.add('fixture-notices',-100,function()
            post('warning');n.stop();return true,true
          end,function(err) error(err) end)
          incoming('old session');assert(#n.list()==0)
          t.incoming.remove('fixture-notices')
        ''')

    def test_sources_combat_quest_spellup_and_no_inferred_combat_end(self):
        self.lua.execute('''
          local state,enemy=3,'a tiny bat';local original=t.gmcp.get
          t.gmcp.get=function(path)
            if path=='char.status.state' then return state end
            if path=='char.status.enemy' then return enemy end
            return original(path)
          end
          raiseEvent('AardwolfToolbox.gmcp.updated','char.status');assert(#n.list()==0)
          state=8;raiseEvent('AardwolfToolbox.gmcp.updated','char.status');assert(n.list()[1].category=='combat')
          raiseEvent('AardwolfToolbox.gmcp.updated','char.status');assert(#n.list()==1)
          state=nil;raiseEvent('AardwolfToolbox.gmcp.updated','char.status');state=8;raiseEvent('AardwolfToolbox.gmcp.updated','char.status');assert(#n.list()==1)
          t.dashboardData.quest={state='Active',target='Éowyn <orc>'};raiseEvent('AardwolfToolbox.dashboardData.updated')
          assert(n.list()[1].message=='Target: Éowyn <orc>');raiseEvent('AardwolfToolbox.dashboardData.updated');assert(#n.list()==2)
          t.dashboardData.quest.state='Target defeated';raiseEvent('AardwolfToolbox.dashboardData.updated');assert(#n.list()==3)
          local status={enabled=true,inflight=true};t.spellup.status=function() return status end
          raiseEvent('AardwolfToolbox.spellup.updated');assert(n.list()[1].title=='Spellup running')
          status.inflight=false;raiseEvent('AardwolfToolbox.spellup.updated');assert(n.list()[1].title=='Spellup finished')
          status.paused='Batch completion unconfirmed';raiseEvent('AardwolfToolbox.spellup.updated');assert(n.list()[1].category=='warning')
          local count=#n.list();raiseEvent('AardwolfToolbox.spellup.updated');assert(#n.list()==count)
        ''')

    def test_query_failures_and_health_error_transitions(self):
        self.lua.execute('''
          local h=t.queries.request('fixture',{timeout=10,start=function() end});advance(0);h.finish(false,'Unsupported reply');advance(0)
          assert(n.list()[1].source=='queries' and n.list()[1].message:find('Unsupported reply'))
          local count=#n.list();raiseEvent('AardwolfToolbox.queries.available');assert(#n.list()==count)
          local cancelled=t.queries.request('fixture',{timeout=10,start=function() end});cancelled.cancel();advance(0);assert(#n.list()==count)
          t.config.runtimeErrors.mapper='Injected mapper failure';n.observeHealth();assert(n.list()[1].source=='settings')
          count=#n.list();n.observeHealth();assert(#n.list()==count)
          t.config.runtimeErrors.mapper=nil;n.observeHealth();t.config.runtimeErrors.mapper='New failure';n.observeHealth();assert(#n.list()==count+1)
          assert(t.health().notifications.count==#n.list())
        ''')

    def test_quiet_defaults_optin_pulse_finishes_and_read_cancels(self):
        self.lua.execute('''
          sounds=0;playSoundFile=function() sounds=sounds+1 end
          assert(post('combat'));advance(0)
          local text=widgets['AardwolfToolbox.utilityBar.item.notifications'].text
          assert(text:find('Notices 1') and sounds==0)
          assert(t.config.set('notifications','blink',true));post('warning')
          assert(widgets['AardwolfToolbox.utilityBar.item.notifications'].text:find('#FFFFFF',1,true))
          n.markRead();advance(0);assert(not widgets['AardwolfToolbox.utilityBar.item.notifications'].text:find('#FFFFFF',1,true))
          post('combat','New');advance(7)
          assert(not widgets['AardwolfToolbox.utilityBar.item.notifications'].text:find('#FFFFFF',1,true))
          assert(sounds==0)
        ''')

    def test_sound_validation_throttle_and_failure_status(self):
        self.lua.execute('''
          assert(not t.config.set('notifications','sound',true))
          local d,r=t.config.draft();d.notifications.sound=true;d.notifications.sound_file='https://example/sound.wav';assert(not t.config.apply(d,r))
          playSoundFile=function() return true end
          d.notifications.sound_file='/missing.wav';assert(t.config.apply(d,r));post('warning');assert(n.last:find('Cannot open'))
          files['/missing.wav']='audio';sounds=0;playSoundFile=function() sounds=sounds+1;return true end
          advance(10);post('warning','Next');post('combat','Fight');assert(sounds==1)
          advance(10);playSoundFile=function() error('Injected audio failure') end;post('warning','Fail');assert(n.last=='Notification sound failed')
          assert(#n.list()==4)
        ''')

    def test_pane_literal_text_stable_rows_filters_read_clear(self):
        self.lua.execute('''
          assert(post('warning','Éowyn <safe>'));local id=n.list()[1].id;assert(p.open())
          local row=W('row.'..id);assert(row.text:find('&lt;safe&gt;',1,true) and row.text:find('&lt;message&gt;',1,true))
          assert(row.renderedFontSize>=12)
          local writes=0;local echo=row.echo;row.echo=function(...) writes=writes+1;return echo(...) end
          raiseEvent('AardwolfToolbox.notifications.updated');advance(0.05);assert(W('row.'..id)==row and writes==0)
          W('unread').callback();row.callback();advance(0.05);assert(n.status().unread==0 and not widgets[row.name])
          W('all').callback();assert(W('row.'..id));W('clear').callback();advance(0.05);assert(#n.list()==0 and not W('empty').hidden)
        ''')

    def test_close_does_not_bind_reserved_escape_or_discard_notices(self):
        self.lua.execute('''
          tempKey=function() error('Notification inbox must not bind reserved Escape') end
          post();assert(p.open());W('close').callback()
          assert(not t.views.visible('notifications') and #n.list()==1)
          assert(p.open());assert(t.views.visible('notifications') and #n.list()==1)
        ''')

    def test_hidden_no_render_bursts_coalesce_and_paged_rows_bounded(self):
        self.lua.execute('''
          local renders=p.renderCount
          for i=1,40 do post('info','Notice '..i) end
          advance(0.1);assert(p.renderCount==renders)
          p.open();renders=p.renderCount;assert(W('page').text=='1 / 2')
          local rows=0;for name in pairs(widgets) do if name:find('AardwolfToolbox.notificationPane.row.',1,true) then rows=rows+1 end end;assert(rows==20)
          W('next').callback();assert(W('page').text=='2 / 2')
          for i=41,48 do post('info','Notice '..i) end;local before=p.renderCount
          advance(0.05);assert(p.renderCount==before+1)
          p.close();before=p.renderCount;post('warning');advance(1);assert(p.renderCount==before)
        ''')

    def test_reset_persistence_lifecycle_and_stale_callbacks(self):
        self.lua.execute('''
          post('combat');p.open();local id=n.list()[1].id;local old=W('row.'..id).callback
          local handlersBefore=noticeHandlers();assert(n.start());assert(noticeHandlers()==handlersBefore)
          raiseEvent('AardwolfToolbox.gmcp.cleared');advance(0.1);assert(#n.list()==0);old();assert(#n.list()==0)
          post();raiseEvent('sysConnectionEvent');assert(#n.list()==0)
          post();assert(t.config.set('notifications','colors',false));assert(#n.list()==1)
          assert(t.config.set('notifications','enabled',false));assert(not n.enabled and not p.enabled and not t.views.available('notifications'))
          assert(not widgets['AardwolfToolbox.notificationPane']);assert(not post());old()
          assert(t.config.set('notifications','enabled',true));post();t.stop();assert(count(widgets)==0 and count(timers)==0)
          assert(t.start());assert(#n.list()==0 and not t.config.get('notifications','colors'))
        ''')

    def test_external_placement_resize_and_actionbar_independence(self):
        self.lua.execute('''
          assert(t.config.set('actions','enabled',false));assert(p.open());post();advance(0.05)
          assert(t.views.setMode('notifications','floating'));assert(W('content').parent~=W('home'))
          local external=W('content').parent;external:resize(380,500);fire('sysUserWindowResizeEvent',external.name)
          assert(W('list'):get_height()>0 and W('clear'):get_height()>=32)
          assert(t.views.setMode('notifications','tabbed'));assert(W('content').parent==W('home') and not widgets['AardwolfToolbox.notificationPane'].hidden)
          assert(t.config.set('utility','enabled',false));post('warning');assert(p.open())
          p.close();local nBefore=#n.list();post();assert(#n.list()==nBefore+1)
        ''')

    def test_partial_activation_failure_cleanup_retry(self):
        self.lua.execute('''
          assert(t.config.set('notifications','enabled',false))
          local original=Geyser.Label.new
          Geyser.Label.new=function(self,cons,parent)
            if cons.name=='AardwolfToolbox.notificationPane.clear' then error('Injected constructor failure') end
            return original(self,cons,parent)
          end
          assert(t.config.set('notifications','enabled',true))
          assert(t.config.runtimeErrors.notifications and not p.enabled and not t.views.available('notifications'))
          assert(not widgets['AardwolfToolbox.notificationPane'])
          Geyser.Label.new=original;assert(t.config.set('notifications','enabled',true));assert(p.enabled and not t.config.runtimeErrors.notifications)
          assert(p.open());t.stop();assert(count(widgets)==0)
        ''')

    def test_full_package_event_delivery_quiesces_without_idle_feedback_loop(self):
        self.lua.execute('''
          t.stop()
          function raiseEvent(event,...) fire(event,...) end
          assert(t.start());advance(0)
          local before=t.notificationPane.renderCount
          t.queries.poke();advance(0);advance(2)
          assert(t.notificationPane.renderCount==before and #t.notifications.list()==0)
          t.stop();assert(count(timers)==0 and count(widgets)==0)
        ''')

    def test_handler_failure_releases_partial_service_and_retries(self):
        self.lua.execute('''
          assert(t.config.set('notifications','enabled',false))
          local original=registerNamedEventHandler
          registerNamedEventHandler=function(owner,name,event,fn)
            if owner=='AardwolfToolbox.notifications' and event=='sysDisconnectionEvent' then return false end
            return original(owner,name,event,fn)
          end
          assert(t.config.set('notifications','enabled',true))
          assert(not n.enabled and not p.enabled and noticeHandlers()==0 and t.config.runtimeErrors.notifications)
          registerNamedEventHandler=original
          assert(t.config.set('notifications','enabled',true));assert(n.enabled and p.enabled)
          assert(not t.config.runtimeErrors.notifications)
        ''')

    def test_room_query_resumes_after_spellup_transition_with_full_events(self):
        self.lua.execute('''
          function raiseEvent(event,...) fire(event,...) end
          local busy=true
          t.spellup.status=function() return {enabled=true,inflight=busy} end
          t.gmcp.enabled=true
          t.gmcp.checkReadiness=function() return true end
          t.gmcp.get=function(path)
            if path=='room.info' then return {num=999,name='Fixture',exits={}} end
            if path=='char.status.state' then return 3 end
            if path=='char.status.pos' then return 'Standing' end
          end
          raiseEvent('AardwolfToolbox.gmcp.updated','room.info');advance(0.3)
          local queries=t.queries.snapshot();assert(#queries.requests==0)
          local sent={};send=function(cmd) sent[#sent+1]=cmd;return true end
          busy=false;raiseEvent('AardwolfToolbox.spellup.updated');advance(0)
          local scan=false;for _,cmd in ipairs(sent) do if cmd=='scan here' then scan=true end end
          assert(scan,'Room scan did not resume at spellup completion')
          t.stop();assert(count(timers)==0)
        ''')
