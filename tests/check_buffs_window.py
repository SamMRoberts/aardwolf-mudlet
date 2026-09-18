from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]


class BuffsWindowTests(unittest.TestCase):
    def runtime(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute((ROOT / "tests/buffs_window_api.lua").read_text())
        lua.globals().Factory = lua.execute(
            (ROOT / "src/resources/buffs-window.lua").read_text())
        lua.execute("window=Factory.new(_G,spells,spellup)")
        return lua

    def test_layout_render_controls_visibility_and_cleanup(self):
        lua = self.runtime()
        lua.execute("""
          assert(window:start())
          local native=widgets['aardwolf-vibe.buffs-window.window']
          assert(native.values.restoreLayout==false and native.values.docked==true
            and native.values.dockPosition=='right')
          assert(native.values.titleText=='Aardwolf Spellups')
          assert(type(native.values.color)=='table' and native.values.color.r==11
            and type(native.values.fgColor)=='table' and native.values.fgColor.r==238)
          assert(widgets['aardwolf-vibe.buffs-window.status'].values.fgColor=='nocolor')
          assert(widgets['aardwolf-vibe.buffs-window.sync'].values.fgColor=='nocolor')
          assert(widgets['aardwolf-vibe.buffs-window.tags'].values.fgColor=='nocolor')
          assert(AardwolfVibeSpellupsWindowLayout==1
            and remembered.AardwolfVibeSpellupsWindowLayout==1)
          assert(native.showCalls==1 and native.raiseCalls==1 and not native.hidden)
          local body=widgets['aardwolf-vibe.buffs-window.body']
          local content=widgets['aardwolf-vibe.buffs-window.content']
          assert(body and content and content.parent==body)
          assert(content.text:find('Active Effects',1,true)
            and content.text:find('Expired Effects',1,true)
            and content.text:find('Recoveries',1,true))
          assert(content.text:find('Shield',1,true) and content.text:find('1:01',1,true))
          assert(content.text:find('Detect magic',1,true)
            and content.text:find('0:05 ago',1,true))
          assert(content.text:find('Awaiting server confirmation',1,true))
          assert(body.scrollTo==nil and body.getScroll==nil and body.clear==nil)
          local bodyIdentity,contentIdentity=body,content
          assert(content.resizeCalls==1)
          raiseEvent('aardwolf-vibe.spells.updated')
          assert(widgets['aardwolf-vibe.buffs-window.body']==bodyIdentity
            and widgets['aardwolf-vibe.buffs-window.content']==contentIdentity
            and content.resizeCalls==1)
          widgets['aardwolf-vibe.buffs-window.sync'].callback();assert(spells.syncs==1)
          local timerId
          for id in pairs(timers) do timerId=id end
          local callback=timers[timerId].callback;timers[timerId]=nil;callback()
          assert(widgets['aardwolf-vibe.buffs-window.body']==bodyIdentity
            and widgets['aardwolf-vibe.buffs-window.content']==contentIdentity
            and content.resizeCalls==1)
          assert(content.rawEchoCalls>=4 and type(content.height)=='number')
          widgets['aardwolf-vibe.buffs-window.now'].callback();assert(spellup.runs==1)
          widgets['aardwolf-vibe.buffs-window.automatic'].callback()
          assert(spellup.automatic and spellup.sets==1)
          local tags=widgets['aardwolf-vibe.buffs-window.tags']
          assert(tags.text:find('Show spell tags',1,true))
          tags.callback()
          assert(not spells.hideTags and spells.tagSets==1)
          assert(tags.text:find('Hide spell tags',1,true))
          assert(window:hide() and native.hideCalls==1 and not window:status().visible)
          assert(window:show() and native.showCalls==2 and native.raiseCalls==2
            and window:status().visible)
          assert(window:start() and count(handlers)==2)
          assert(window:stop() and count(handlers)==0 and count(timers)==0 and count(widgets)==0)

          window=Factory.new(_G,spells,spellup)
          assert(window:start())
          native=widgets['aardwolf-vibe.buffs-window.window']
          assert(native.values.restoreLayout==true and native.values.docked==true
            and native.values.dockPosition=='right')
          assert(window:stop())
        """)

    def test_partial_widget_failure_cleans_up(self):
        lua = self.runtime()
        lua.execute("""
          Geyser.ScrollBox=nil
          assert(not window:start())
          assert(not window:status().enabled and count(handlers)==0 and count(timers)==0)
        """)

    def test_table_colors_boundaries_empty_states_and_escaping(self):
        lua = self.runtime()
        lua.execute("""
          spells.snapshotValue={fresh=true,busy=false,
            active={
              {id=1,name='Green & safe',remaining=121,awaiting=false},
              {id=2,name='Yellow <120>',remaining=120,awaiting=false},
              {id=3,name='Yellow "31"',remaining=31,awaiting=false},
              {id=4,name="Red '30'",remaining=30,awaiting=false},
              {id=5,name='Waiting',remaining=0,awaiting=true},
            },
            expired={{id=6,name='<Expired & gone>',elapsed=65,expiredAt=0}},
            recoveries={}}
          assert(window:start())
          local text=widgets['aardwolf-vibe.buffs-window.content'].text
          assert(text:find('#55c878',1,true) and text:find('#b89b22',1,true)
            and text:find('#e06161',1,true))
          assert(text:find('Green &amp; safe',1,true))
          assert(text:find('Yellow &lt;120&gt;',1,true))
          assert(text:find('Yellow &quot;31&quot;',1,true))
          assert(text:find('Red &#39;30&#39;',1,true))
          assert(text:find('&lt;Expired &amp; gone&gt;',1,true))
          assert(text:find('1:05 ago',1,true))
          assert(text:find('Green &amp; safe</font></td><td align="right"><font color="#55c878">2:01',1,true))
          assert(text:find('Yellow &lt;120&gt;</font></td><td align="right"><font color="#b89b22">2:00',1,true))
          assert(text:find('Yellow &quot;31&quot;</font></td><td align="right"><font color="#b89b22">0:31',1,true))
          assert(text:find('Red &#39;30&#39;</font></td><td align="right"><font color="#e06161">0:30',1,true))
          assert(text:find('Waiting</font></td><td align="right"><font color="#e06161">Awaiting server confirmation',1,true))
          assert(text:find('None confirmed',1,true))
          assert(window:stop())
        """)

    def test_constructor_failure_identifies_stage(self):
        lua = self.runtime()
        lua.execute("""
          Geyser.Label.new=function() error('native color failure') end
          local ok,message=window:start()
          assert(not ok and message:find('create status label',1,true))
          assert(message:find('native color failure',1,true))
          assert(not window:status().enabled and count(handlers)==0 and count(timers)==0)
        """)

    def test_labels_do_not_use_geyser_color_echo_path(self):
        lua = self.runtime()
        lua.execute("""
          local original=Geyser.Label.new
          Geyser.Label.new=function(class,values,parent)
            local item=original(class,values,parent)
            item.echo=function() error('Geyser label color parser invoked') end
            return item
          end
          assert(window:start())
          assert(widgets['aardwolf-vibe.buffs-window.status'].text:find('Synchronized',1,true))
          assert(widgets['aardwolf-vibe.buffs-window.automatic'].text:find('Enable automatic',1,true))
          assert(window:stop())
        """)


if __name__ == "__main__":
    unittest.main()
