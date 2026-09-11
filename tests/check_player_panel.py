from pathlib import Path
import unittest
import zipfile
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]

class PlayerPanelTests(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime()
        self.lua.execute((ROOT/'tests/settings_api.lua').read_text())
        self.lua.execute('''
          Geyser.Container=Geyser.Label
          handlers={}; data={}; cache={enabled=true,get=function() return data end}
          function registerNamedEventHandler(owner,name,event,fn) handlers[name]={event=event,fn=fn}; return true end
          function deleteNamedEventHandler(owner,name) handlers[name]=nil end
          function fire(event,...)
            for _,h in pairs(handlers) do if h.event==event then h.fn(event,...) end end
          end
          function flush()
            local pending=timers; timers={}; for _,fn in pairs(pending) do fn() end
          end
          function starter()
            BaseUI={container={Inside=Geyser.Container:new({name='dock',x=0,y=0,height=700,width=300})},sections={}}
            BaseUI.sections.chat=Geyser.Container:new({name='chat',x=0,y=350,height=350,width=300},BaseUI.container.Inside)
            function BaseUI.sectionFloating() return floating end
            function BaseUI.placeSection(key,place) placed=place; BaseUI.sections.chat:move(0,place.y*BaseUI.container.Inside:get_height()); BaseUI.sections.chat:resize(300,place.height*BaseUI.container.Inside:get_height()) end
            function BaseUI.layoutDock() BaseUI.placeSection('chat',{y=0.5,height=0.5}) end
            originalPlace=BaseUI.placeSection
          end
          starter()
        ''')
        with zipfile.ZipFile(ROOT/'build/AardwolfToolbox.mpackage') as z:
            factory=self.lua.execute(z.read('player-panel.lua').decode())
        self.lua.globals().panel=factory.new(self.lua.globals(),self.lua.globals().cache)

    def test_layout_render_and_restoration(self):
        self.lua.execute('''
          data={base={name='<red>Tesobi',level=116,class='Warrior',race='Centaur'},
            stats={str=165,dex=132,con=132,int=65,wis=154,luck=61,hr=156,dr=224,saves=0},
            maxstats={maxstr=117,maxdex=90,maxcon=99,maxint=32,maxwis=135,maxluck=40},
            status={pos='Standing',align=1727,hunger=74,thirst=74}}
          assert(panel.start()); assert(panel.start())
          assert(BaseUI.placeSection==originalPlace)
          assert(placed.y>0.5 and placed.y+placed.height==1)
          assert(widgets['AardwolfToolbox.player.root'].y==350)
          assert(widgets['AardwolfToolbox.player.r1c1'].text:find('&lt;red&gt;Tesobi',1,true))
          assert(widgets['AardwolfToolbox.player.r5c3'].text=='SAV 0')
          assert(widgets['AardwolfToolbox.player.r3c1'].text=='STR 165/<i>117</i>')
          assert(widgets['AardwolfToolbox.player.r4c3'].text=='LCK 61/<i>40</i>')
          panel.stop(); panel.stop()
          assert(BaseUI.placeSection==originalPlace and placed.y==0.5)
          assert(widgets['AardwolfToolbox.player.root']==nil and next(handlers)==nil)
        ''')

    def test_updates_clear_float_and_resize(self):
        self.lua.execute('''
          assert(panel.start())
          data={status={level=120},stats={str=0}}
          fire('AardwolfToolbox.gmcp.updated','char.stats'); flush()
          assert(widgets['AardwolfToolbox.player.r3c1'].text=='STR 0/<i>--</i>')
          data.maxstats={maxstr=117}; fire('AardwolfToolbox.gmcp.updated','char.maxstats'); flush()
          assert(widgets['AardwolfToolbox.player.r3c1'].text=='STR 0/<i>117</i>')
          data={}; fire('AardwolfToolbox.gmcp.cleared'); flush()
          assert(widgets['AardwolfToolbox.player.r3c1'].text=='STR --/<i>--</i>')
          floating=true; BaseUI.layoutDock(); assert(widgets['AardwolfToolbox.player.root'].hidden)
          floating=false; BaseUI.layoutDock(); assert(not widgets['AardwolfToolbox.player.root'].hidden)
          BaseUI.container.Inside.height=250; BaseUI.layoutDock()
          assert(widgets['AardwolfToolbox.player.root'].hidden and placed.height==0.5)
          panel.configure({enabled=false,font_size=10}); assert(next(handlers)==nil)
        ''')

    def test_delayed_starter_and_pending_timer_cleanup(self):
        self.lua.execute('''
          BaseUI.container.Inside:delete(); BaseUI=nil
          assert(panel.start()); assert(panel.last:find('Waiting',1,true))
          starter(); fire('sysInstallPackage','mudlet-base-ui'); flush()
          assert(widgets['AardwolfToolbox.player.root'])
          fire('sysWindowResizeEvent'); panel.destroy(); flush()
          assert(widgets['AardwolfToolbox.player.root']==nil)
        ''')
