from pathlib import Path
import unittest
import zipfile
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]

class HelpPaneTests(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime()
        self.lua.execute((ROOT/'tests/settings_api.lua').read_text())
        self.lua.execute('Geyser.Container=Geyser.Label')
        self.lua.execute((ROOT/'tests/ascii_api.lua').read_text())
        self.lua.execute('''
          function Geyser.Label:setColor() end
          function Geyser.Label:setTitle(text,color) assert(color==nil or type(color)=='string'); self.title=text end
          handlers={}; gagged=0; diagnostics={}; sequence=0
          function tempTimer(delay,fn) sequence=sequence+1; timers[sequence]={delay=delay,fn=fn}; return sequence end
          function flush()
            local pending={}; for id,t in pairs(timers) do if t.delay==0 then pending[id]=t; timers[id]=nil end end
            for _,t in pairs(pending) do t.fn() end
          end
          function registerNamedEventHandler(owner,name,event,fn) handlers[name]=fn; return true end
          function deleteNamedEventHandler(owner,name) handlers[name]=nil end
          function tempRegexTrigger(pattern,fn) trigger=fn; return 1 end
          function killTrigger() trigger=nil end
          function deleteLine() gagged=gagged+1 end
          function echo(text) diagnostics[#diagnostics+1]=text end
          function input(text) line=text; if trigger then trigger() end end
        ''')
        with zipfile.ZipFile(ROOT/'build/AardwolfToolbox.mpackage') as z:
            dispatcher=self.lua.execute(z.read('incoming.lua').decode()).new(self.lua.globals())
            self.lua.globals().incoming=dispatcher
            self.lua.globals().help=self.lua.execute(z.read('help-pane.lua').decode()).new(self.lua.globals(),dispatcher)
        self.lua.execute('assert(help.start())')

    def test_help_title_body_and_literal_content(self):
        self.lua.execute('''
          input('ordinary text'); assert(gagged==0)
          input('{help}'); input('{helpkeywords}TEST <red>')
          input('{helpbody}'); input('  spaced <angle> & text'); input(''); input('{literal}')
          input('{/helpbody}'); input('{/help}'); flush()
          assert(gagged==8)
          assert(widgets['AardwolfToolbox.help.window'].title=='TEST &lt;red&gt;')
          assert(widgets['AardwolfToolbox.help.console'].text=='  spaced <angle> & text\\n\\n{literal}\\n')
          assert(widgets['AardwolfToolbox.help.window'].raised)
          widgets['AardwolfToolbox.help.windowexitLabel'].callback()
          assert(widgets['AardwolfToolbox.help.window'].hidden)
        ''')

    def test_priority_disabled_and_lifecycle(self):
        self.lua.execute('''
          generic=0
          incoming.add('generic',20,function() generic=generic+1 end,function() end)
          help.start(); input('{help}'); input('{helpbody}'); input('content'); input('{/helpbody}'); input('{/help}'); flush()
          assert(generic==0)
          help.configure({enabled=false,font_size=11}); input('{help}')
          assert(generic==1 and widgets['AardwolfToolbox.help.window']==nil)
          help.configure({enabled=true,font_size=12}); input('{help}')
          handlers.sysDisconnectionEvent(); input('ordinary'); assert(generic==2)
          help.stop(); help.destroy(); assert(next(handlers)==nil and next(timers)==nil)
        ''')

    def test_incomplete_timeout_and_repeated_start(self):
        self.lua.execute('''
          input('{help}'); input('{helpbody}'); input('old')
          input('{help}'); input('{helpkeywords}NEW'); input('{helpbody}'); input('new'); input('{/helpbody}'); input('{/help}'); flush()
          assert(widgets['AardwolfToolbox.help.console'].text=='new\\n')
          input('{help}'); input('{helpbody}'); input('partial'); input('{/help}'); flush()
          assert(widgets['AardwolfToolbox.help.console'].text=='new\\n' and #diagnostics==1)
          input('{help}')
          for id,t in pairs(timers) do if t.delay==10 then timers[id]=nil; t.fn() end end
          local count=gagged; input('outside'); assert(gagged==count and #diagnostics==2)
          help.stop(); assert(next(timers)==nil)
        ''')
