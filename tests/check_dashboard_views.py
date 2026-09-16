"""Placement, compact content and state contracts; native interaction has its own fixture."""
import unittest
from pathlib import Path
import check_package
ROOT=Path(__file__).resolve().parents[1]
class ViewTests(unittest.TestCase):
    def setUp(self):
        check_package.PackageTests.setUp(self)
        self.lua.execute((ROOT/'tests/dashboard_api.lua').read_text())
        self.lua.execute('function raiseEvent(event,...) fire(event,...) end; dashboardStarter(); AardwolfToolbox.start(); c=AardwolfToolbox.config; v=AardwolfToolbox.views; flushEvents()')

    def test_move_and_return_preserves_chat_console_and_closing(self):
        self.lua.execute('''
          local console=BaseUI.chats.tells; console:echo('Preserved <chat>')
          assert(v.setMode('tells','floating')); flushEvents()
          local host=widgets['AardwolfToolbox.dashboard.chatHost.tells']
          local window=widgets['AardwolfToolbox.views.TestProfile.tells']
          assert(host.parent==window and console.parent==host)
          window:hide(); assert(not v.visible('tells'))
          BaseUI.selectChatTab('all'); assert(window.hidden)
          BaseUI.noteChatActivity('tells'); assert(BaseUI.unread.tells==3)
          assert(v.open('tells')); assert(not window.hidden)
          assert(v.setMode('tells','tabbed')); flushEvents()
          assert(console==BaseUI.chats.tells and console.text=='Preserved <chat>')
          assert(host.parent==BaseUI.sections.chat.Inside)
          AardwolfToolbox.stop()
          assert(console.parent==BaseUI.sections.chat.Inside and not console.deleted)
          assert(not widgets['AardwolfToolbox.views.TestProfile.tells'])
        ''')

    def test_detaching_sections_reallocates_space_without_recreating_map(self):
        self.lua.execute('''
          local map=BaseUI.map; local initial=BaseUI.sections.map:get_height()
          for _,id in ipairs({'player','quest','campaign','globalQuest','group','buffs','all','tells','channels','clan','newbie','chat_group','trade','local_chat'}) do assert(v.setMode(id,'floating')) end
          flushEvents()
          assert(BaseUI.sections.chat.hidden and widgets['AardwolfToolbox.dashboard.root'].hidden)
          assert(BaseUI.sections.map:get_height()>initial and BaseUI.map==map)
          local before=count(widgets); AardwolfToolbox.start(); flushEvents(); assert(count(widgets)==before)
          assert(v.setMode('player','tabbed')); flushEvents(); assert(not widgets['AardwolfToolbox.dashboard.root'].hidden)
        ''')

    def test_compact_buff_rows_and_fixed_controls_preserve_identity(self):
        self.lua.execute('''
          local s=AardwolfToolbox.spells; local now=1000
          s.snapshot=function() return {fresh=true,last='Fresh',active={{id=2,name='Long α buff',remaining=50},{id=1,name='A buff',remaining=80},{id=3,name='Unknown',awaiting=true}},recoveries={}} end
          assert(c.set('dashboard','tab','buffs')); flushEvents()
          local row=widgets['AardwolfToolbox.dashboard.buffs.effect_2']; local timer=widgets['AardwolfToolbox.dashboard.buffs.effect_2_value']
          assert(row and timer.text=='0:50' and row.style:find('#ffcb70',1,true))
          assert(row.y<widgets['AardwolfToolbox.dashboard.buffs.effect_1'].y)
          assert(row:get_height()<AardwolfToolbox.ui.metrics().height)
          local writes=0; local echo=row.echo; row.echo=function(self,...) writes=writes+1; return echo(self,...) end
          fire('AardwolfToolbox.spells.updated'); flushEvents(); assert(writes==0)
          assert(widgets['AardwolfToolbox.dashboard.buffs.buffAuto'].parent~=row.parent)
          assert(c.set('views','expiry_warning',30)); flushEvents(); assert(not row.style:find('#ffcb70',1,true))
        ''')

    def test_paused_outstanding_spellup_is_not_rendered_as_running(self):
        self.lua.execute('''
          AardwolfToolbox.spellup.status=function() return {inflight=true,uncertain=true,
            paused='Batch completion unconfirmed',last='Paused: Batch completion unconfirmed',
            automatic=true,coverage={known=false}} end
          assert(c.set('dashboard','tab','buffs'));flushEvents()
          local status=widgets['AardwolfToolbox.dashboard.buffs.status']
          assert(status.text:find('Paused',1,true) and not status.text:find('Spellup running',1,true))
          assert(status.style:find('#ffcb70',1,true))
          AardwolfToolbox.spellup.status=function() return {inflight=true,last='Spellup running',
            automatic=false,coverage={known=false}} end
          fire('AardwolfToolbox.spellup.updated');flushEvents()
          assert(status.text:find('Spellup running',1,true) and not status.text:find('Paused',1,true))
        ''')

    def test_quest_countdown_zero_and_safe_map_lookup(self):
        self.lua.execute('''
          AardwolfToolbox.dashboardData.quest={state='Active',target='<dragon>',room='Hall',area='Academy',remaining=1,reported=940}
          c.set('dashboard','tab','quest'); flushEvents()
          local status=widgets['AardwolfToolbox.dashboard.quest.status']
          assert(status.text:find('Awaiting update',1,true))
          assert(AardwolfToolbox.dashboardData.quest.state=='Active')
          assert(widgets['AardwolfToolbox.dashboard.quest.target'].text=='Target: &lt;dragon&gt;')
          searchRoom=function() return {[7]='Hall',[8]='Hall'} end
          getRoomArea=function() return 1 end; getAreaTableSwap=function() return {[1]='Academy'} end
          widgets['AardwolfToolbox.dashboard.quest.find'].callback(); assert(widgets['AardwolfToolbox.dashboard.quest.match_7'])
          assert(widgets['AardwolfToolbox.dashboard.quest.match_8'])
        ''')

    def test_config_cancel_and_disabled_sidebar_cleanup(self):
        self.lua.execute('''
          local draft,revision=c.draft(); draft.views.player='floating'
          assert(v.mode('player')=='tabbed')
          assert(c.set('views','quest','floating')); assert(not c.apply(draft,revision))
          flushEvents(); assert(v.mode('player')=='tabbed')
          c.set('dashboard','enabled',false); flushEvents()
          for name in pairs(widgets) do assert(not name:find('AardwolfToolbox.views.TestProfile',1,true)) end
          c.set('dashboard','enabled',true); flushEvents(); assert(v.open('quest'))
        ''')

    def test_compass_reserved_above_input_and_sidebar(self):
        self.lua.execute('''
          for _,size in ipairs({{1280,800},{1920,1080},{900,700},{1280,550}}) do
            windowWidth,windowHeight=size[1],size[2]
            fire('sysWindowResizeEvent'); flushEvents()
            local x,y,w,h=AardwolfToolbox.borders.box('AardwolfToolbox.actionBar')
            local sidebar=BaseUI.container
            if not sidebar.hidden then assert(sidebar:get_y()+sidebar:get_height()<=y+1) end
            assert(h>0 and y+h<=windowHeight)
          end
        ''')

    def test_combat_preference_migration_and_group_resources(self):
        self.lua.execute('''
          local source=sources.configuration
          files['/profile/AardwolfToolbox-settings.json']=yajl.to_string({version=3,values={dashboard={tab='combat'}}})
          local cfg=assert(loadstring(source))().new(_G)
          cfg.registerFeature({id='dashboard',label='Dashboard',settings={{key='tab',label='Tab',type='choice',default='player',options={{value='player',label='Player'}}}},apply=function() end})
          assert(cfg.get('dashboard','tab')=='player' and not cfg.readError)
          gmcp=gmcp or {}; gmcp.group={groupname='Test',leader='A',members={{name='A',info={lvl=1,hp=0,mhp=100,mn=10,mmn=0,mv=12,here=1}}}}
          fire('gmcp.group'); c.set('dashboard','tab','group'); flushEvents()
          assert(widgets['AardwolfToolbox.dashboard.group.member_1_hp'].text=='HP 0%')
          assert(widgets['AardwolfToolbox.dashboard.group.member_1_mn'].text=='MP 10/0')
          assert(widgets['AardwolfToolbox.dashboard.group.member_1_mv'].text=='MV 12/--')
          gmcp.group={reason='no group'}; fire('gmcp.group'); flushEvents()
          assert(widgets['AardwolfToolbox.dashboard.group.member_1_hp'].hidden)
        ''')

    def test_owned_window_geometry_survives_restart(self):
        self.lua.execute('''
          function getWindowGeometry(name)
            local w=widgets[name]; if w then return w.x,w.y,w.width,w.height end
          end
          v.setMode('quest','floating'); flushEvents()
          local w=widgets['AardwolfToolbox.views.TestProfile.quest']; w:move(-200,120); w:resize(510,380)
          c.set('dashboard','enabled',false); flushEvents()
          assert(c.getMetadata('viewWindows').quest.width==510)
          c.set('dashboard','enabled',true); flushEvents()
          w=widgets['AardwolfToolbox.views.TestProfile.quest']
          assert(w.x==-200 and w.width==510 and w.height==380)
          v.resetPlacement('quest'); assert(w.x==40 and w.width==420)
        ''')
