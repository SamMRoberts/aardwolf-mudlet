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
          local status=widgets['aardwolf-vibe.buffs-window.status']
          assert(status.values.fgColor=='nocolor')
          assert(status.values.x==5 and status.values.y==5
            and status.values.width=='100%-38' and status.values.height==28)
          assert(status.text=='<b>Off</b>')
          assert(not status.text:find('Automatic:',1,true)
            and not status.text:find('Synchronized',1,true)
            and not status.text:find('<br>',1,true))
          local menu=widgets['aardwolf-vibe.buffs-window.menu']
          assert(menu and menu.values.fgColor=='nocolor'
            and menu.text=='<div align="center">&#8942;</div>'
            and menu.toolTip=='Spellup actions')
          assert(menu.values.x=='100%-33' and menu.values.y==5
            and menu.values.width==28 and menu.values.height==28)
          assert(menu.style:find('padding: 2px',1,true)
            and menu.style:find('font-size: 14px',1,true))
          assert(widgets['aardwolf-vibe.buffs-window.sync']==nil
            and widgets['aardwolf-vibe.buffs-window.now']==nil
            and widgets['aardwolf-vibe.buffs-window.automatic']==nil
            and widgets['aardwolf-vibe.buffs-window.tags']==nil)
          assert(AardwolfVibeSpellupsWindowLayout==1
            and remembered.AardwolfVibeSpellupsWindowLayout==1)
          assert(native.showCalls==1 and native.raiseCalls==1 and not native.hidden)
          local body=widgets['aardwolf-vibe.buffs-window.body']
          local content=widgets['aardwolf-vibe.buffs-window.content']
          assert(body and content and content.parent==body)
          assert(body.values.x==5 and body.values.y==38
            and body.values.width=='100%-10' and body.values.height=='100%-43')
          local activeHeading=widgets['aardwolf-vibe.buffs-window.heading.active']
          local expiredHeading=widgets['aardwolf-vibe.buffs-window.heading.expired']
          local recoveryHeading=widgets['aardwolf-vibe.buffs-window.heading.recoveries']
          local activeRow=widgets['aardwolf-vibe.buffs-window.row.active.72']
          local expiredRow=widgets['aardwolf-vibe.buffs-window.row.expired.35']
          local recoveryRow=widgets['aardwolf-vibe.buffs-window.row.recoveries.15']
          assert(activeHeading.text:find('Active Effects',1,true)
            and expiredHeading.text:find('Expired Effects',1,true)
            and recoveryHeading.text:find('Recoveries',1,true))
          assert(activeRow.text:find('Shield',1,true)
            and activeRow.text:find('1:01',1,true))
          assert(expiredRow.text:find('Detect magic',1,true)
            and expiredRow.text:find('0:05 ago',1,true))
          assert(recoveryRow.text:find('Awaiting server confirmation',1,true))
          assert(body.scrollTo==nil and body.getScroll==nil and body.clear==nil)
          local bodyIdentity,contentIdentity=body,content
          assert(content.resizeCalls==1)
          raiseEvent('aardwolf-vibe.spells.updated')
          assert(widgets['aardwolf-vibe.buffs-window.body']==bodyIdentity
            and widgets['aardwolf-vibe.buffs-window.content']==contentIdentity
            and widgets['aardwolf-vibe.buffs-window.row.expired.35']==expiredRow
            and content.resizeCalls==1)
          local sync=widgets['aardwolf-vibe.buffs-window.menu.sync']
          local now=widgets['aardwolf-vibe.buffs-window.menu.now']
          local automatic=widgets['aardwolf-vibe.buffs-window.menu.automatic']
          local tags=widgets['aardwolf-vibe.buffs-window.menu.tags']
          assert(sync.values.x=='100%-205' and sync.values.y==33
            and sync.values.width==200 and sync.values.height==28)
          assert(now.x=='100%-205' and now.y==61
            and automatic.x=='100%-205' and automatic.y==89
            and tags.x=='100%-205' and tags.y==117)
          assert(sync.hidden and now.hidden and automatic.hidden and tags.hidden)
          menu.callback()
          assert(not sync.hidden and not now.hidden and not automatic.hidden and not tags.hidden)
          assert(sync.raiseCalls==1 and tags.raiseCalls==1 and menu.raiseCalls==1)
          raiseEvent('aardwolf-vibe.spells.updated')
          assert(not sync.hidden and not now.hidden and not automatic.hidden and not tags.hidden)
          menu.callback()
          assert(sync.hidden and now.hidden and automatic.hidden and tags.hidden)
          menu.callback()
          sync.callback();assert(spells.syncs==1)
          assert(sync.hidden and now.hidden and automatic.hidden and tags.hidden)
          local timerId
          for id in pairs(timers) do timerId=id end
          local callback=timers[timerId].callback;timers[timerId]=nil;callback()
          assert(widgets['aardwolf-vibe.buffs-window.body']==bodyIdentity
            and widgets['aardwolf-vibe.buffs-window.content']==contentIdentity
            and content.resizeCalls==1)
          assert(type(content.height)=='number')
          menu.callback();now.callback();assert(spellup.runs==1 and now.hidden)
          menu.callback();automatic.callback()
          assert(spellup.automatic and spellup.sets==1)
          assert(status.text=='<b>Ready</b>')
          assert(automatic.text:find('Pause automatic',1,true))
          assert(tags.text:find('Show spell tags',1,true))
          menu.callback();tags.callback()
          assert(not spells.hideTags and spells.tagSets==1)
          assert(tags.text:find('Hide spell tags',1,true))
          menu.callback();assert(not tags.hidden)
          local renderCalls=status.rawEchoCalls
          assert(window:hide() and native.hideCalls==1 and not window:status().visible)
          assert(count(timers)==0)
          assert(sync.hidden and now.hidden and automatic.hidden and tags.hidden)
          raiseEvent('aardwolf-vibe.spells.updated')
          assert(status.rawEchoCalls==renderCalls)
          assert(window:show() and native.showCalls==2 and native.raiseCalls==2
            and window:status().visible)
          assert(status.rawEchoCalls==renderCalls+1 and count(timers)==1)
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

    def test_click_dismisses_only_current_expiry_from_display(self):
        lua = self.runtime()
        lua.execute("""
          spells.snapshotValue.expired={
            {id=35,name='Detect magic',elapsed=5,expiredAt=100},
            {id=36,name='Detect magic',elapsed=9,expiredAt=110},
          }
          assert(window:start())
          local first=widgets['aardwolf-vibe.buffs-window.row.expired.35']
          local second=widgets['aardwolf-vibe.buffs-window.row.expired.36']
          assert(first and second and first.callback)
          assert(first.toolTip=='Click to dismiss expired effect')
          assert(first.style:find('QLabel:hover',1,true))
          assert(not widgets['aardwolf-vibe.buffs-window.row.active.72'].callback)
          first.callback()
          assert(widgets[first.name]==nil and widgets[second.name]==second)
          assert(#spells.snapshotValue.expired==2 and spells.syncs==0 and spellup.runs==0)
          raiseEvent('aardwolf-vibe.spells.updated')
          assert(widgets[first.name]==nil and widgets[second.name]==second)
          assert(window:hide() and window:show())
          assert(widgets[first.name]==nil and widgets[second.name]==second)
          spells.snapshotValue.expired[1].expiredAt=120
          raiseEvent('aardwolf-vibe.spells.updated')
          assert(widgets[first.name] and widgets[first.name]~=first)
          assert(window:stop())
          assert(count(widgets)==0)
          first.callback()
          assert(count(widgets)==0)
          spells.snapshotValue.expired[1].expiredAt=100
          assert(window:start())
          assert(widgets[first.name])
          assert(window:stop())
        """)

    def test_dismissal_compacts_scroll_content_without_rebuilding_other_rows(self):
        lua = self.runtime()
        lua.execute("""
          spells.snapshotValue.active={}
          spells.snapshotValue.recoveries={}
          spells.snapshotValue.expired={}
          for id=1,10 do
            spells.snapshotValue.expired[id]={id=id,name='Buff '..id,
              elapsed=id,expiredAt=100+id}
          end
          assert(window:start())
          local body=widgets['aardwolf-vibe.buffs-window.body']
          local content=widgets['aardwolf-vibe.buffs-window.content']
          local retained=widgets['aardwolf-vibe.buffs-window.row.expired.10']
          local removed=widgets['aardwolf-vibe.buffs-window.row.expired.1']
          local before=content.height
          removed.callback()
          assert(widgets[removed.name]==nil)
          assert(widgets[retained.name]==retained)
          assert(widgets['aardwolf-vibe.buffs-window.body']==body)
          assert(content.height==before-26)
          assert(window:stop())
        """)

    def test_compact_header_statuses_and_exact_blocking_reasons(self):
        lua = self.runtime()
        lua.execute("""
          assert(window:start())
          local status=widgets['aardwolf-vibe.buffs-window.status']
          local function expect(value)
            raiseEvent('aardwolf-vibe.spellup.updated')
            assert(status.text=='<b>'..value..'</b>',status.text)
            assert(not status.text:find('Automatic:',1,true)
              and not status.text:find('Synchronized',1,true)
              and not status.text:find('<br>',1,true))
          end
          expect('Off')
          spellup.automatic=true;expect('Ready')
          spellup.pending=true;expect('Work queued')
          spellup.blockingReason='Spell sync failed; use Sync to retry: timed out'
          expect('Spell sync failed; use Sync to retry: timed out')
          spellup.blockingReason=nil
          spellup.pending=false;spellup.inflight=true;expect('Batch outstanding')
          spellup.inflight=false;spellup.blockingReason='Character is not standing'
          expect('Character is not standing')
          spellup.paused='Server did not accept retry'
          spellup.blockingReason='Paused: Server did not accept retry'
          expect('Paused: Server did not accept retry')
          spellup.blockingReason=nil;expect('Paused')
          assert(window:stop())
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
          local function row(kind,id)
            return widgets['aardwolf-vibe.buffs-window.row.'..kind..'.'..id].text
          end
          local text=table.concat({row('active',1),row('active',2),row('active',3),
            row('active',4),row('active',5),row('expired',6),row('recoveries','empty')})
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
          assert(widgets['aardwolf-vibe.buffs-window.status'].text=='<b>Off</b>')
          assert(widgets['aardwolf-vibe.buffs-window.menu.automatic'].text:find('Enable automatic',1,true))
          assert(window:stop())
        """)


    def test_workspace_remount_preserves_widgets_and_spell_state(self):
        lua = self.runtime()
        lua.execute(r'''
          workspace={visible=true}
          function workspace:registerPanel(spec)
            self.spec=spec
            local handle={}
            function handle:show() workspace.visible=true;spec.onVisibilityChanged(true);return true end
            function handle:hide() workspace.visible=false;spec.onVisibilityChanged(false);return true end
            function handle:status() return {visible=workspace.visible,host="workspace"} end
            return handle
          end
          function workspace:unregisterPanel() self.spec=nil;return true end
          window=Factory.new(_G,spells,spellup,workspace)
          assert(window:start() and workspace.spec)
          local root=widgets["aardwolf-vibe.buffs-window.root"]
          local content=widgets["aardwolf-vibe.buffs-window.content"]
          local expired=widgets["aardwolf-vibe.buffs-window.row.expired.35"]
          expired.callback()
          assert(widgets[expired.name]==nil)
          spellup.automatic=true
          local target=Geyser.Container:new({name="workspace.slot",x=0,y=0,width=400,height=400})
          assert(workspace.spec.unmount(root))
          assert(workspace.spec.mount(target)==root and root.parent==target)
          assert(widgets["aardwolf-vibe.buffs-window.content"]==content)
          assert(widgets["aardwolf-vibe.buffs-window.row.active.72"].text:find("Shield",1,true)
            and spellup.automatic)
          assert(widgets[expired.name]==nil)
          assert(count(handlers)==2)
          assert(window:hide() and not window:status().visible and count(timers)==0)
          assert(window:show() and window:status().visible and count(timers)==1)
        ''')


if __name__ == "__main__":
    unittest.main()
