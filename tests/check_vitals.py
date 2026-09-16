"""Behavior checks against the packaged Lua, with native UI verified separately."""
from pathlib import Path
import unittest
import zipfile
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]

class VitalsTests(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime()
        for name in ('mapper_api.lua','settings_api.lua','vitals_api.lua'):
            self.lua.execute((ROOT/'tests'/name).read_text())
        with zipfile.ZipFile(ROOT/'build/AardwolfToolbox.mpackage') as archive:
            self.lua.globals().source=archive.read('vitals.lua').decode()
        self.lua.execute('''
          v=assert(loadstring(source))().new(_G)
          options={enabled=true,show_tnl=true,show_target=false,bar_height=22,font_size=11}
          function start() assert(v.configure(options)) end
        ''')

    def test_readings_out_of_order_partial_and_zero(self):
        self.lua.execute('''
          start(); assert(gauge('hp').label=='HP --/--')
          character('status',{tnl=889}); assert(gauge('tnl').label=='TNL 889 · --%')
          character('base',{perlevel=1000}); assert(gauge('tnl').label=='TNL 889 · 11%')
          character('maxstats',{maxhp=3600,maxmana=2502,maxmoves=2928})
          character('vitals',{hp=3600,mana=2502,moves=2928})
          assert(gauge('hp').value==100 and gauge('mana').label=='Mana 2502/2502')
          character('vitals',{hp=0}); assert(gauge('hp').value==0 and gauge('moves').value==100)
          character('maxstats',{maxhp=0}); assert(gauge('hp').label=='HP 0/0')
          character('status',{tnl=0}); assert(gauge('tnl').value==100)
        ''')

    def test_invalid_debt_and_level_changes(self):
        self.lua.execute('''
          start(); character('base',{perlevel='1000'}); character('status',{tnl=1200})
          assert(gauge('tnl').value==0 and gauge('tnl').label=='TNL 1200 · 0%')
          character('status',{tnl=1000}); assert(gauge('tnl').value==0)
          character('base',{perlevel=2000}); assert(gauge('tnl').value==50)
          for _,bad in ipairs({0,-1,math.huge,'bad',false,0/0}) do
            character('base',{perlevel=bad}); assert(gauge('tnl').value==0)
            assert(gauge('tnl').label=='TNL 1000 · --%')
          end
          character('vitals',{hp=math.huge,mana=-2,moves='7'})
          assert(gauge('hp').label=='HP --/--' and gauge('moves').label=='Moves 7/--')
        ''')

    def test_freshness_and_requests(self):
        self.lua.execute('''
          character('vitals',{hp=42}); connected=true; start()
          assert(#gmcpRequests==1 and gmcpRequests[1]=='request char')
          fire('gmcp.char.vitals'); assert(gauge('hp').label=='HP --/--')
          character('vitals',{hp=43}); fire('sysDisconnectionEvent')
          character('vitals',{hp=99}); assert(gauge('hp').label=='HP --/--')
          fire('sysConnectionEvent'); character('vitals',{hp=44})
          assert(gauge('hp').label=='HP 44/--')
          fire('sysProtocolDisabled','GMCP'); assert(gauge('hp').label=='HP --/--')
          fire('sysProtocolEnabled','GMCP'); assert(#gmcpRequests==2)
          fire('gmcp.char.vitals'); assert(gauge('hp').label=='HP --/--')
        ''')

    def test_geometry_options_and_ownership(self):
        self.lua.execute('''
          borderBottom=10; start(); local original=gauge('hp')
          assert(borderBottom==42 and original.width==218 and original.height==22)
          start(); assert(original==gauge('hp') and count(handlers)==13)
          options.show_tnl=false; options.bar_height=30; start()
          assert(gauge('tnl').hidden and original.width>290 and borderBottom==50)
          windowWidth=600; fire('sysWindowResizeEvent'); assert(original.fontSize==11)
          assert(original.y==gauge('moves').y and original==gauge('hp'))
          v.stop(); v.stop(); assert(borderBottom==10 and count(widgets)==0 and count(handlers)==0)
          assert(count(modules)==0); start(); borderBottom=99; fire('sysWindowResizeEvent')
          assert(not v.enabled and borderBottom==99 and count(widgets)==0)
        ''')

    def test_adapter_delayed_reload_restore_and_failure(self):
        self.lua.execute('''
          start(); starter(); local floating,place=BaseUI.sectionFloating,BaseUI.placeSection
          fire('sysInstallPackage','mudlet-base-ui'); for id,fn in pairs(timers) do timers[id]=nil; fn() end
          assert(BaseUI.sections.vitals.hidden and not BaseUI.vitalsAllocated)
          v.stop(); assert(not BaseUI.sections.vitals.hidden and BaseUI.vitalsAllocated)
          assert(BaseUI.sectionFloating==floating and BaseUI.placeSection==place)
          start(); local base=BaseUI; BaseUI=nil; fire('sysUninstallPackage','mudlet-base-ui')
          for id,fn in pairs(timers) do timers[id]=nil; fn() end
          assert(v.enabled and base.sectionFloating==floating and base.placeSection==place)
          v.stop(); BaseUI={}; local ok,message=v.configure(options)
          assert(not ok and message:find('integration unavailable') and not v.enabled)
          assert(borderBottom==0 and count(handlers)==0)
        ''')

    def test_target_health_order_and_reset(self):
        self.lua.execute('''
          options.show_target=true; start()
          assert(gauge('tnl').x>gauge('target').x and gauge('target').x>gauge('moves').x)
          character('status',{enemy='an owl',enemypct=93,state=8})
          assert(gauge('target').value==93 and gauge('target').label:find('93%%'))
          character('status',{enemypct=0}); assert(gauge('target').value==0)
          character('status',{enemy='a dragon'}); assert(gauge('target').label:find('--%%'))
          character('status',{enemypct=math.huge}); assert(gauge('target').value==0)
          character('status',{enemy='<b>&',enemypct=80})
          assert(gauge('target').label:find('&lt;b&gt;&amp;',1,true))
          character('status',{enemy=''}); assert(gauge('target').label=='No target')
          character('status',{enemy='owl',enemypct=10,state=8})
          character('status',{state=3}); assert(gauge('target').label=='No target')
          fire('sysDisconnectionEvent'); assert(gauge('target').label=='Target --')
          options.show_tnl=false; start()
          assert(gauge('tnl').hidden and not gauge('target').hidden)
        ''')

    def test_partial_start_failure_cleans_up(self):
        self.lua.execute('''
          starter(); failNext('registerNamedEventHandler'); assert(not v.configure(options))
          assert(count(handlers)==0 and count(modules)==0 and borderBottom==0)
          assert(not BaseUI.sections.vitals.hidden and BaseUI.vitalsAllocated)
          start(); fire('sysInstallPackage','Other'); v.destroy()
          assert(count(timers)==0 and count(handlers)==0)
        ''')

if __name__=='__main__': unittest.main()
