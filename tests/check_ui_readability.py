"""UI contracts. Native rendering and mouse acceptance live in native_ui013.lua."""
from pathlib import Path
import unittest
from lupa.lua51 import LuaRuntime
from lua_support import install_json
import check_package
ROOT=Path(__file__).resolve().parents[1]

class ReadabilityTests(unittest.TestCase):
    def setUp(self):
        check_package.PackageTests.setUp(self)
        self.lua.execute('''
          AardwolfToolbox.start(); c=AardwolfToolbox.config; ui=AardwolfToolbox.ui; gmcp=gmcp or {}
          function questRequests() local n=0; for _,text in ipairs(gmcpRequests) do if text=='request quest' then n=n+1 end end; return n end
          local originalRaise=raiseEvent
          function raiseEvent(event,...) originalRaise(event,...); fire(event,...) end
          local originalCharacter=character
          function character(key,value) originalCharacter(key,value); fire('gmcp.char','gmcp.char.'..key) end
        ''')

    def test_effective_font_presets_measurement_and_unicode(self):
        self.lua.execute('''
          local label=Geyser.Label:new({name='font-test'})
          label:setStyleSheet('font-size: 30pt'); label:echo('Old'); assert(label.renderedFontSize==8)
          ui.apply(label); label:echo('Tesobi'); assert(label.renderedFontSize==12 and label.font=='Arial')
          assert(ui.measure('WWW')>ui.measure('iii'))
          assert(ui.fit('古竜 Éowyn',ui.measure('古…'))=='古…')
          assert(c.set('appearance','preset','large')); ui.apply(label); label:echo('Large')
          assert(label.renderedFontSize==14 and ui.metrics('reading').size==15)
          assert(c.set('appearance','preset','comfortable')); assert(ui.metrics().size==12)
          assert(mainSize==14) -- Never shrink the original profile's reading size.
          label:delete()
        ''')

    def test_appearance_persistence_and_external_font_changes(self):
        self.lua.execute('''
          assert(c.set('appearance','ui_size',16)); assert(c.set('appearance','reading_size',17))
          assert(mainSize==17)
          mainSize=20; assert(c.set('appearance','reading_size',18)); assert(mainSize==20)
          AardwolfToolbox.stop(); assert(mainSize==20 and count(widgets)==0)
          AardwolfToolbox.start(); assert(ui.metrics().size==16 and mainSize==20)
          assert(not c.set('appearance','ui_size',10))
          assert(c.set('appearance','enabled',false)); assert(mainSize==20)
        ''')

    def test_metadata_write_failure_and_stale_drafts(self):
        self.lua.execute('''
          local draft,revision=c.draft()
          assert(c.setMetadata('test',{value=7})); assert(c.apply(draft,revision))
          local old=files['/profile/AardwolfToolbox-settings.json']
          fileFailures.rename=true; assert(not c.setMetadata('test',{value=8}))
          assert(c.getMetadata('test').value==7); fileFailures.rename=nil
          draft,revision=c.draft(); assert(c.set('appearance','ui_size',15))
          draft.appearance.ui_size=13; assert(not c.apply(draft,revision)); assert(ui.metrics().size==15)
          assert(not c.set('dashboard','map_percent',60))
        ''')

    def test_quest_partial_transitions_and_single_ready_request(self):
        self.lua.execute('''
          local d=AardwolfToolbox.dashboardData
          local function packet(q)
            gmcp.comm=gmcp.comm or {}; gmcp.comm.quest=q
            fire('gmcp.comm','gmcp.comm.quest')
          end
          assert(d.quest.state=='Unknown' and not d.requestQuest())
          connected=true; character('status',{state=3}); local n=questRequests()
          assert(n==1)
          character('status',{state=3}); assert(questRequests()==n)
          packet({action='start',targ='Éowyn <red>',room='A room',area='Academy',timer=52})
          assert(d.quest.state=='Active' and d.quest.remaining==52)
          packet({action='warning',time=0}); assert(d.quest.target=='Éowyn <red>' and d.quest.remaining==0)
          packet({action='status',time=4}); assert(d.quest.room=='A room')
          packet({action='killed',time=3}); assert(d.quest.state=='Target defeated' and d.quest.area=='Academy')
          c.set('dashboard','tab','quest'); assert(d.quest.state=='Target defeated' and questRequests()==n)
          packet({action='start',targ='New target',timer=10}); assert(d.quest.room==nil)
          packet({action='comp',wait=30}); assert(d.quest.state=='Waiting' and d.quest.target==nil)
          packet({action='ready'}); assert(d.quest.state=='Ready' and d.quest.remaining==nil)
          fire('sysDisconnectionEvent'); assert(d.quest.state=='Unknown' and not d.requestQuest())
          fire('sysConnectionEvent'); character('status',{state=7}); assert(not d.requestQuest())
          character('status',{state=3}); assert(questRequests()==n+1)
        ''')

    def test_group_replacement_elapsed_and_reset(self):
        self.lua.execute('''
          local d=AardwolfToolbox.dashboardData
          gmcp.group={leader='A',members={{name='A'},{name='B'}}}; fire('gmcp.group')
          assert(#AardwolfToolbox.gmcp.get('group.members')==2)
          gmcp.group={leader='A',members={{name='A'}}}; fire('gmcp.group')
          assert(#AardwolfToolbox.gmcp.get('group.members')==1)
          local now=1000; getEpoch=function() return now end
          gmcp.comm={repop={zone='academy'}}; fire('gmcp.comm','gmcp.comm.repop')
          gmcp.room={info={zone='academy'}}; fire('gmcp.room','gmcp.room.info')
          now=1005; assert(d.elapsed('repop')==5 and d.elapsed('tick')==nil)
          gmcp.comm.tick={}; fire('gmcp.comm','gmcp.comm.tick'); now=1012
          assert(d.elapsed('tick')==7)
          gmcp.room.info={zone='other'}; fire('gmcp.room','gmcp.room.info'); assert(d.elapsed('repop')==nil)
          fire('sysDisconnectionEvent'); assert(d.elapsed('tick')==nil and AardwolfToolbox.gmcp.get('group')==nil)
        ''')

    def test_data_setup_disabled_and_cleanup(self):
        self.lua.execute('''
          c.set('dashboard','automatic_data',false); connected=true; local n=questRequests()
          character('status',{state=3}); assert(questRequests()==n)
          assert(AardwolfToolbox.dashboardData.requestQuest())
          AardwolfToolbox.stop(); assert(count(widgets)==0 and count(timers)==0 and count(handlers)==0)
        ''')

class BorderProvenanceTests(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(); install_json(self.lua)
        self.lua.execute('''
          sizes={left=0,right=100,top=0,bottom=0}; metadata={}
          for _,edge in ipairs({'left','right','top','bottom'}) do
            local key=edge:sub(1,1):upper()..edge:sub(2)
            _G['getBorder'..key]=function() return sizes[edge] end
            _G['setBorder'..key]=function(v) sizes[edge]=v end
          end
          config={getMetadata=function(k) return metadata[k] end,setMetadata=function(k,v) metadata[k]=v; return true end}
          function getMainWindowSize() return 1280,800 end
        ''')
        self.lua.globals().Borders=self.lua.execute((ROOT/'src/resources/borders.lua').read_text())

    def test_saved_reservations_reload_external_change_and_reset(self):
        self.lua.execute('''
          local a=Borders.new(_G,config); a.reserve('utility','top',32,0,nil,true); a.reserve('vitals','bottom',42,0)
          local b=Borders.new(_G,config); b.reserve('utility','top',32,0,nil,true); b.reserve('vitals','bottom',42,0)
          assert(sizes.top==32 and sizes.bottom==42)
          b.reserve('ascii','top',200,1); b.refresh(); assert(sizes.top==232 and b.fullWidthTop()==32)
          b.resetExternal({top=0,bottom=0}); assert(sizes.top==232 and sizes.right==100)
          b.release('ascii'); b.release('utility'); b.release('vitals'); assert(sizes.top==0 and sizes.bottom==0)
          b.reserve('utility','top',32,0); sizes.top=80; b.refresh(); assert(sizes.top==112)
          b.release('utility'); assert(sizes.top==80)
        ''')

    def test_failed_provenance_write_leaves_native_margins(self):
        self.lua.execute('''
          config.setMetadata=function() return false,'disk full' end
          local b=Borders.new(_G,config)
          assert(not pcall(b.reserve,'utility','top',32,0)); assert(sizes.top==0)
        ''')

class DashboardLayoutTests(unittest.TestCase):
    def setUp(self):
        check_package.PackageTests.setUp(self)
        self.lua.execute((ROOT/'tests/dashboard_api.lua').read_text())
        self.lua.execute('dashboardStarter(); originalLayout=BaseUI.layoutDock; originalPlace=BaseUI.placeSection; nativeMap=BaseUI.map; AardwolfToolbox.start(); c=AardwolfToolbox.config; flushEvents()')

    def test_resolutions_overflow_and_no_font_shrinking(self):
        self.lua.execute('''
          assert(AardwolfToolbox.dashboard.enabled,AardwolfToolbox.dashboard.last)
          for _,size in ipairs({{1280,800},{1920,1080},{900,700}}) do
            windowWidth,windowHeight=size[1],size[2]; fire('sysWindowResizeEvent'); flushEvents()
            assert(AardwolfToolbox.dashboard.enabled,AardwolfToolbox.dashboard.last)
            assert(gauge('hp').fontSize==12 and gauge('tnl').x>gauge('hp').x)
            assert(widgets['AardwolfToolbox.dashboard.player'].fontSize==12)
            if size[1]<1000 then
              assert(BaseUI.container.hidden and borderRight==0)
              assert(c.set('dashboard','collapsed',false)); flushEvents(); assert(not BaseUI.container.hidden)
            else assert(BaseUI.container:get_width()>=360) end
          end
        ''')

    def test_map_tabs_popout_and_restoration(self):
        self.lua.execute('''
          assert(c.set('dashboard','map_tab','ascii')); flushEvents()
          assert(nativeMap.hidden and mapClosed)
          local console=widgets['AardwolfToolbox.ascii.console']
          assert(console.parent==widgets['AardwolfToolbox.dashboard.mapHost'])
          assert(c.set('dashboard','ascii_popout',true)); flushEvents()
          assert(console==widgets['AardwolfToolbox.ascii.console'] and not nativeMap.hidden)
          assert(console.parent==widgets['AardwolfToolbox.ascii.window'].Inside)
          assert(c.set('dashboard','ascii_popout',false)); flushEvents(); assert(nativeMap.hidden)
          assert(c.set('dashboard','enabled',false)); flushEvents()
          assert(nativeMap.y==0 and nativeMap.height=='100%')
          assert(not widgets['AardwolfToolbox.dashboard.root'] and BaseUI.map==nativeMap)
          AardwolfToolbox.stop(); assert(BaseUI.layoutDock==originalLayout and BaseUI.placeSection==originalPlace)
          assert(not BaseUI.AardwolfToolboxDashboard)
        ''')

    def test_buffs_controls_remain_visible_during_timer_updates(self):
        self.lua.execute('''
          c.set('dashboard','tab','buffs'); flushEvents()
          local button=widgets['AardwolfToolbox.dashboard.buffAuto']
          local hidden=0; local original=button.hide
          function button:hide(...) hidden=hidden+1; return original(self,...) end
          fire('AardwolfToolbox.spells.updated'); flushEvents()
          assert(hidden==0 and not button.hidden, 'Redraw must not hide scrollable controls')
          assert(button.renderedFontSize==12)
          windowWidth=900; c.set('dashboard','collapsed',false); c.set('appearance','preset','large'); flushEvents()
          assert(widgets['AardwolfToolbox.dashboard.buffs'].renderedFontSize==14)
          assert(widgets['AardwolfToolbox.dashboard.tabStrip']:get_height()>=AardwolfToolbox.ui.metrics().height)
          c.set('appearance','ui_size',24); c.set('dashboard','width',360); flushEvents()
          assert(not widgets['AardwolfToolbox.dashboard.tabPrevious'].hidden)
          widgets['AardwolfToolbox.dashboard.tabPrevious'].callback()
          assert(c.get('dashboard','tab')=='buffs')
          assert(not widgets['AardwolfToolbox.dashboard.combat'].hidden)
          c.set('dashboard','tab','player'); flushEvents(); assert(button.hidden)
        ''')

    def test_divider_transaction_lock_and_stale_gesture(self):
        self.lua.execute('''
          local divider=widgets['AardwolfToolbox.dashboard.splitMap']
          divider.callback({button='LeftButton',globalX=0,globalY=0})
          divider.moveCallback({globalX=0,globalY=30}); divider.releaseCallback(); flushEvents()
          assert(c.get('dashboard','map_percent')>40)
          local saved=c.get('dashboard','map_percent')
          c.set('dashboard','locked',true); flushEvents()
          divider.callback({button='LeftButton',globalX=0,globalY=0})
          divider.moveCallback({globalX=0,globalY=40}); divider.releaseCallback(); assert(c.get('dashboard','map_percent')==saved)
          c.set('dashboard','locked',false); flushEvents()
          divider.callback({button='LeftButton',globalX=0,globalY=0})
          c.set('dashboard','map_tab','ascii'); divider.moveCallback({globalX=0,globalY=40}); divider.releaseCallback(); flushEvents()
          assert(c.get('dashboard','map_percent')==saved)
        ''')

    def test_combat_zero_missing_target_changes_and_no_auto_tab_switch(self):
        self.lua.execute('''
          gmcp={char={status={state=8,pos='Fighting',enemy='<dragon>',enemypct=0},vitals={hp=0,mana=12,moves=34},stats={hr=0,dr=221}}}
          fire('gmcp.char'); assert(c.set('dashboard','tab','combat')); flushEvents()
          assert(widgets['AardwolfToolbox.dashboard.row2'].text=='Target: &lt;dragon&gt;')
          assert(widgets['AardwolfToolbox.dashboard.row3'].text=='Target health: 0%')
          assert(widgets['AardwolfToolbox.dashboard.row4'].text=='HP 0  Mana 12  Moves 34')
          gmcp.char.status={state=8,pos='Fighting',enemy='New target'}; fire('gmcp.char','gmcp.char.status')
          fire('AardwolfToolbox.dashboardData.updated'); flushEvents()
          assert(widgets['AardwolfToolbox.dashboard.row2'].text=='Target: New target')
          assert(widgets['AardwolfToolbox.dashboard.row3'].text=='Target health: --%')
          assert(c.set('dashboard','tab','player')); flushEvents()
          gmcp.char.status={state=8,pos='Fighting',enemy='Third target',enemypct=99}; fire('gmcp.char','gmcp.char.status')
          fire('AardwolfToolbox.dashboardData.updated'); flushEvents(); assert(c.get('dashboard','tab')=='player')
        ''')
