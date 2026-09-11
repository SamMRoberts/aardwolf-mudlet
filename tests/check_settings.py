"""Behavior tests against the packaged settings resources, under Lua 5.1."""
from pathlib import Path
import unittest
import zipfile
from lupa.lua51 import LuaRuntime
from lua_support import install_json

ROOT = Path(__file__).resolve().parents[1]


class SettingsTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        for name in ('mapper_api.lua', 'settings_api.lua'):
            self.lua.execute((ROOT / 'tests' / name).read_text())
        install_json(self.lua)
        with zipfile.ZipFile(ROOT / 'build/AardwolfToolbox.mpackage') as package:
            for name, var in [('configuration.lua','Config'), ('settings-window.lua','Window'), ('automapper.lua','Mapper')]:
                self.lua.globals()[var] = self.lua.execute(package.read(name).decode())
        self.lua.execute('''
          function definition()
            return {id="demo",label="Demo",description="Example",settings={
              {key="enabled",type="boolean",default=true,label="Enabled"},
              {key="title",type="text",default="Hello",maxLength=20,label="Title"},
              {key="size",type="number",default=5,min=1,max=10,integer=true,label="Size"},
              {key="mode",type="choice",default="a",options={{value="a",label="Mode A"},{value="b",label="Mode B"}},label="Mode"}
            },apply=function(values) applied=values; calls=(calls or 0)+1; return true end}
          end
          config=Config.new(_G); config.registerFeature(definition()); config.activate()
          window=Window.new(_G,config,function() return "Mapper: running" end)
        ''')

    def check(self, source):
        self.lua.execute(source)

    def test_types_defaults_and_invalid_definitions(self):
        self.check('''
          assert(config.get("demo","enabled") and config.get("demo","size")==5)
          assert(not pcall(config.registerFeature,definition()))
          local d=definition(); d.id="bad"; d.settings[3].default=99
          assert(not pcall(config.registerFeature,d) and not config.features.bad)
          d=definition(); d.id="bad"; d.settings[4].options[2].value="a"
          assert(not pcall(config.registerFeature,d))
          for _,pair in ipairs({{"enabled","true"},{"title",string.rep("x",21)},{"size",0},{"size",1.5},{"size",0/0},{"mode","c"}}) do
            local ok=config.set("demo",pair[1],pair[2]); assert(not ok)
          end
          assert(calls==1 and files[config.path]==nil)
        ''')

    def test_atomic_persistence_reload_and_unknown_feature_retention(self):
        self.check('''
          files[config.path]=yajl.to_string({version=1,values={later={custom="keep"},demo={enabled=false}}})
          config=Config.new(_G); config.registerFeature(definition()); config.activate()
          assert(applied.enabled==false)
          assert(config.set("demo","size",7))
          local stored=yajl.to_value(files[config.path]); assert(stored.values.later.custom=="keep")
          local nextConfig=Config.new(_G); nextConfig.registerFeature(definition())
          assert(nextConfig.get("demo","size")==7 and not nextConfig.get("demo","enabled"))
          assert(files[config.path..".tmp"]==nil)
        ''')

    def test_corrupt_unsupported_and_invalid_saved_values_preserved(self):
        self.check('''
          for _,bytes in ipairs({"broken", '{"version":2,"values":{}}', '{"version":1,"values":{"demo":{"size":999}}}'}) do
            files[config.path]=bytes
            local c=Config.new(_G); c.registerFeature(definition())
            assert(c.readError and not c.set("demo","size",6))
            assert(files[config.path]==bytes)
          end
        ''')

    def test_write_failures_do_not_change_active_values(self):
        self.check('''
          assert(config.set("demo","size",6))
          local before,oldCalls=files[config.path],calls
          for _,failure in ipairs({"open","write","close","rename"}) do
            fileFailures[failure]=true
            assert(not config.set("demo","size",7))
            assert(config.get("demo","size")==6 and calls==oldCalls and files[config.path]==before)
            fileFailures[failure]=nil
          end
        ''')

    def test_activation_failure_is_separate_from_saved_preference(self):
        self.check('''
          local d=definition(); d.id="failure"; d.apply=function() return false,"blocked" end
          config.registerFeature(d)
          local ok,message=config.set("failure","enabled",false)
          assert(ok and message:find("activation needs attention",1,true))
          assert(not config.get("failure","enabled") and config.runtimeErrors.failure=="blocked")
        ''')

    def test_window_apply_cancel_defaults_and_stale_drafts(self):
        self.check('''
          window.open(); local root=widgets["AardwolfToolbox.settings.root"]
          local n=count(widgets); window.open(); assert(count(widgets)==n and count(timers)==1)
          widgetContaining("Enabled").callback()
          assert(config.get("demo","enabled"))
          window.apply(); assert(not config.get("demo","enabled"))
          window.restoreDefaults(); window.close(); assert(not config.get("demo","enabled"))
          assert(count(widgets)==0 and count(timers)==0)
          window.open(); window.restoreDefaults(); window.apply(); assert(config.get("demo","enabled"))
          assert(config.set("demo","size",8))
          local ok,message=window.apply(); assert(not ok and message:find("changed elsewhere",1,true))
          assert(config.get("demo","size")==8)
          local callback=widgetContaining("Cancel").callback
          window.destroy(); window.destroy(); window.open(); callback(); assert(window.opened)
          window.close()
        ''')

    def test_text_number_choice_input_is_local_and_validated(self):
        self.check('''
          window.open()
          local title=widgetContaining("Hello"); title.text="Updated"; title.action("Updated")
          local size=widgetContaining("5"); size.text="11"
          widgetContaining("Mode A  ▸").callback()
          assert(not window.apply() and config.get("demo","title")=="Hello")
          size.text="9"; assert(window.apply())
          assert(config.get("demo","title")=="Updated" and config.get("demo","size")==9)
          assert(config.get("demo","mode")=="b")
          window.close()
        ''')

    def test_drag_resize_and_minimum_size(self):
        self.check('''
          window.open(); local r=widgets["AardwolfToolbox.settings.root"]
          r.adjLabel.callback({button="LeftButton",x=100,y=15,globalX=-500,globalY=50})
          r.adjLabel.moveCallback({globalX=-350,globalY=100})
          assert(r.x==220 and r.y==130)
          r.adjLabel.releaseCallback()
          r.adjLabel.callback({button="LeftButton",x=r.width-1,y=r.height-1,globalX=0,globalY=0})
          r.adjLabel.moveCallback({globalX=-600,globalY=-500})
          assert(r.width==520 and r.height==380)
          assert(widgets["AardwolfToolbox.settings.body"]:get_width() <= r.width-179)
          r.adjLabel.releaseCallback(); window.close()
        ''')

    def test_dynamic_features_and_escaped_labels(self):
        self.check('''
          local d=definition(); d.id="next"; d.label="<New & Feature>"; config.registerFeature(d)
          window.open(); assert(widgetContaining("&lt;New &amp; Feature&gt;"))
          window.select("next"); assert(widgetContaining("Mode A  ▸")); window.close()
        ''')

    def test_following_and_terrain_toggles_leave_mapping_intact(self):
        self.check('''
          local follow,color=false,false
          local mapper=Mapper.new(_G,function(key) if key=="follow_room" then return follow else return color end end)
          mapper.start(); terrainPacket(101,"forest")
          local id=localID(101)
          assert(id>0 and centered==nil and getRoomEnv(id)==-1)
          assert(getRoomUserData(id,"AardwolfToolbox:terrain")=="forest")
          follow,color=true,true; terrainPacket(101,"forest")
          local env=getRoomEnv(id); assert(centered==id and env>=1000)
          color=false; terrainPacket(101,"water"); assert(getRoomEnv(id)==env)
          color=true; setRoomEnv(id,99); terrainPacket(101,"water"); assert(getRoomEnv(id)==99)
          mapper.stop()
        ''')
