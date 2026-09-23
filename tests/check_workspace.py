from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
API = (ROOT / "tests/workspace_api.lua").read_text()
SOURCE = (ROOT / "src/resources/workspace.lua").read_text()


class WorkspaceTests(unittest.TestCase):
    def runtime(self, legacy=False):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(API)
        factory = lua.execute(SOURCE)
        lua.globals().Factory = factory
        if legacy:
            lua.execute('''
              Factory.defaultState=function()
                return {schemaVersion=1,enabled=false,visible=true,hidden={},tree={
                  type="split",orientation="vertical",ratio=0.45,
                  first={type="stack",tabs={"aardwolf-vibe.ascii-map"},
                    active="aardwolf-vibe.ascii-map"},
                  second={type="stack",tabs={"aardwolf-vibe.character-window",
                    "aardwolf-vibe.chat","aardwolf-vibe.buffs-window"},
                    active="aardwolf-vibe.chat"}}}
              end
            ''')
        return lua

    def test_default_tree_validation_moves_ratios_visibility_and_bounds(self):
        lua = self.runtime()
        lua.execute(r'''
          local state=Factory.defaultState()
          local valid,message=Factory.validateState(state)
          assert(valid and not message and valid.enabled==true and valid.visible==true)
          assert(valid.tree.type=="split" and valid.tree.orientation=="vertical")
          assert(valid.tree.ratio==0.30 and valid.tree.first.orientation=="horizontal")
          assert(valid.tree.first.ratio==0.53)
          assert(valid.tree.first.first.active=="aardwolf-vibe.buffs-window")
          assert(valid.tree.first.second.active=="aardwolf-vibe.ascii-map")
          assert(valid.tree.second.ratio==0.57)
          assert(valid.tree.second.first.active=="aardwolf-vibe.mapper-display")
          assert(valid.tree.second.second.active=="aardwolf-vibe.chat")
          local moved=assert(Factory.movePanel(valid,"aardwolf-vibe.chat","root.first.second","center",1))
          assert(moved.tree.first.second.tabs[1]=="aardwolf-vibe.chat"
            and moved.tree.first.second.active=="aardwolf-vibe.chat")
          assert(countPanel(moved.tree,"aardwolf-vibe.chat")==1)
          local clamped=assert(Factory.setRatio(moved,"root.first",99))
          assert(clamped.tree.first.ratio==0.9)
          clamped=assert(Factory.setRatio(clamped,"root.first",-1))
          assert(clamped.tree.first.ratio==0.1)
          local hidden=assert(Factory.setPanelHidden(clamped,"aardwolf-vibe.chat",true))
          assert(hidden.hidden["aardwolf-vibe.chat"])
          hidden=assert(Factory.setPanelHidden(hidden,"aardwolf-vibe.chat",false))
          assert(hidden.hidden["aardwolf-vibe.chat"]==nil)

          local duplicate=Factory.defaultState()
          duplicate.tree.second.second.tabs[#duplicate.tree.second.second.tabs+1]="aardwolf-vibe.ascii-map"
          assert(not Factory.validateState(duplicate))
          local cyclic=Factory.defaultState();cyclic.tree.first=cyclic.tree
          assert(not Factory.validateState(cyclic))
          local invalid=Factory.defaultState();invalid.tree.ratio=0/0
          assert(not Factory.validateState(invalid))
          local deep={type="stack",tabs={"deep"},active="deep"}
          for index=1,17 do deep={type="split",orientation="vertical",ratio=0.5,
            first={type="stack",tabs={"side"..index},active="side"..index},second=deep} end
          local excessive=Factory.defaultState();excessive.tree=deep
          assert(not Factory.validateState(excessive))
        ''')

    def test_fresh_default_and_existing_profile_layout_are_distinct(self):
        lua = self.runtime()
        lua.execute('''
          local fresh=Factory.new(_G,settings)
          assert(fresh:start() and fresh:status().enabled)
          assert(widgets["aardwolf-vibe.workspace.window"])
          local panel=makePanel("aardwolf-vibe.buffs-window","Spellups")
          assert(fresh:registerPanel(panel:spec()))
          local saved=files["/profile/aardwolf-vibe-data/workspace.json"]
          assert(saved and encoded[saved].enabled)
          assert(fresh:stop())
          AardwolfVibeSpellupsWindowLayout=1
          local restored=Factory.new(_G,settings)
          assert(restored:start() and restored:status().enabled)
          assert(restored:stop())
        ''')
        lua = self.runtime()
        lua.execute('''
          AardwolfVibeSpellupsWindowLayout=1
          local existing=Factory.new(_G,settings)
          assert(existing:start() and existing:status().mode=="off")
          assert(not widgets["aardwolf-vibe.workspace.window"])
          assert(existing:stop())
        ''')
        lua = self.runtime()
        lua.execute('''
          settings.path="/profile/aardwolf-vibe-data/settings.json"
          files[settings.path]="prior settings"
          local existing=Factory.new(_G,settings)
          assert(existing:start() and existing:status().mode=="off")
          assert(existing:stop())
        ''')

    def test_reset_preserves_external_panel_in_nested_default(self):
        lua = self.runtime()
        lua.execute('''
          local workspace=Factory.new(_G,settings)
          assert(workspace:start())
          local external=makePanel("external.panel","External")
          assert(workspace:registerPanel(external:spec()))
          assert(workspace:reset())
          assert(countPanel(workspace:status().tree,"external.panel")==1)
          assert(workspace:stop())
        ''')

    def test_opt_in_rehosts_without_replacing_roots_and_restores_standalone(self):
        lua = self.runtime(legacy=True)
        lua.execute(r'''
          workspace=Factory.new(_G,settings);assert(workspace:start());assert(tableCount(handlers)==1)
          local map=makePanel("aardwolf-vibe.ascii-map","ASCII Map")
          local character=makePanel("aardwolf-vibe.character-window","Character")
          local chat=makePanel("aardwolf-vibe.chat","Chat")
          local spellups=makePanel("aardwolf-vibe.buffs-window","Spellups")
          local handles={assert(workspace:registerPanel(map:spec())),
            assert(workspace:registerPanel(character:spec())),
            assert(workspace:registerPanel(chat:spec())),
            assert(workspace:registerPanel(spellups:spec()))}
          assert(workspace:status().mode=="off" and not widgets["aardwolf-vibe.workspace.window"])
          local roots={map.root,character.root,chat.root,spellups.root}
          chat.state.value=77
          assert(workspace:setEnabled(true))
          local status=workspace:status()
          assert(status.mode=="on" and status.visible and status.registered==4 and status.placeholders==0)
          local native=widgets["aardwolf-vibe.workspace.window"]
          assert(native and native.cons.dockPosition=="right" and native.cons.docked)
          assert(map.host.hidden and character.host.hidden and chat.host.hidden and spellups.host.hidden)
          assert(map.root==roots[1] and character.root==roots[2] and chat.root==roots[3]
            and spellups.root==roots[4] and chat.state.value==77)
          assert(map.root.parent.name:find("workspace.slot",1,true))
          assert(chat.root.parent.name:find("workspace.slot",1,true))
          assert(not map.root.hidden and not chat.root.hidden)
          assert(character.root.hidden and spellups.root.hidden)
          assert(workspace:hide() and native.hidden and not workspace:status().visible)
          assert(workspace:show() and not native.hidden)
          assert(handles[2]:show() and not character.root.hidden and chat.root.hidden)
          assert(handles[2]:hide() and character.root.hidden)
          assert(workspace:setEnabled(false))
          assert(map.root.parent==map.host and character.root.parent==character.host
            and chat.root.parent==chat.host and spellups.root.parent==spellups.host)
          assert(not map.host.hidden and not chat.host.hidden and spellups.host.hidden==false)
          assert(character.host.hidden)
          assert(chat.state.value==77 and map.root==roots[1] and chat.root==roots[3])
        ''')

    def test_partial_mount_rollback_late_registration_and_placeholders(self):
        lua = self.runtime(legacy=True)
        lua.execute(r'''
          workspace=Factory.new(_G,settings);assert(workspace:start())
          local map=makePanel("aardwolf-vibe.ascii-map","ASCII Map")
          local chat=makePanel("aardwolf-vibe.chat","Chat")
          assert(workspace:registerPanel(map:spec()));assert(workspace:registerPanel(chat:spec()))
          fail.mountID="aardwolf-vibe.chat"
          local ok,message=workspace:setEnabled(true)
          assert(not ok and message:find("mount failure",1,true))
          assert(workspace:status().mode=="off" and map.root.parent==map.host and chat.root.parent==chat.host)
          assert(files["/profile/aardwolf-vibe-data/workspace.json"]==nil)
          fail.mountID=nil;assert(workspace:setEnabled(true))
          assert(workspace:unregisterPanel("aardwolf-vibe.chat"))
          assert(workspace:status().placeholders>=3)
          local oldPath
          local tree=workspace:status().tree
          assert(countPanel(tree,"aardwolf-vibe.chat")==1)
          local replacement=makePanel("aardwolf-vibe.chat","Chat again")
          assert(workspace:registerPanel(replacement:spec()))
          assert(replacement.root.parent.name:find("workspace.slot",1,true))
          assert(workspace:status().placeholders==2)
        ''')

    def test_drag_drop_targets_menu_actions_and_splitter_release_persist(self):
        lua = self.runtime(legacy=True)
        lua.execute(r'''
          workspace=Factory.new(_G,settings);assert(workspace:start())
          for _,entry in ipairs({
            {"aardwolf-vibe.ascii-map","ASCII Map"},
            {"aardwolf-vibe.character-window","Character"},
            {"aardwolf-vibe.chat","Chat"},
            {"aardwolf-vibe.buffs-window","Spellups"},
          }) do local panel=makePanel(entry[1],entry[2]);assert(workspace:registerPanel(panel:spec())) end
          assert(workspace:setEnabled(true))
          assert(widgets["aardwolf-vibe.workspace.tabs.root.second"].width=="100%-28")
          assert(widgets["aardwolf-vibe.workspace.tab.root-second.aardwolf-vibe.chat"].width:match("%%$"))
          for _,zone in ipairs({"center","left","right","top","bottom"}) do
            assert(widgets["aardwolf-vibe.workspace.drop.root-first."..zone])
          end
          local before=encodeCount
          local tab=widgets["aardwolf-vibe.workspace.tab.root-second.aardwolf-vibe.chat"]
          assert(tab and tab.moveCallback);tab.moveCallback({})
          assert(not widgets["aardwolf-vibe.workspace.drop.root-first.center"].hidden)
          click("aardwolf-vibe.workspace.drop.root-first.center")
          local tree=workspace:status().tree
          assert(tree.first.type=="stack" and tree.first.active=="aardwolf-vibe.chat")
          assert(countPanel(tree,"aardwolf-vibe.chat")==1 and encodeCount==before+1)
          assert(widgets["aardwolf-vibe.workspace.tab.root-first.aardwolf-vibe.chat"].width=="50%")

          local menu=widgets["aardwolf-vibe.workspace.menu.root-first"]
          assert(menu and menu.clickCallback);menu.clickCallback({})
          local splitBelow=widgets["aardwolf-vibe.workspace.menu.root-first.6"]
          assert(splitBelow and not splitBelow.hidden);splitBelow.clickCallback({})
          tree=workspace:status().tree
          assert(tree.first.type=="split" and tree.first.orientation=="vertical")
          local splitter=widgets["aardwolf-vibe.workspace.splitter.root.first"]
          assert(splitter and splitter.clickCallback and splitter.moveCallback and splitter.releaseCallback)
          before=encodeCount
          splitter.clickCallback({globalY=100})
          splitter.moveCallback({globalY=180})
          assert(encodeCount==before)
          assert(splitter.releaseCallback() and encodeCount==before+1)
          assert(workspace:status().tree.first.ratio>=0.1
            and workspace:status().tree.first.ratio<=0.9)
        ''')

    def test_persistence_malformed_preservation_and_explicit_reset(self):
        lua = self.runtime(legacy=True)
        lua.execute(r'''
          workspace=Factory.new(_G,settings);assert(workspace:start())
          local map=makePanel("aardwolf-vibe.ascii-map","ASCII Map")
          assert(workspace:registerPanel(map:spec()))
          assert(workspace:setEnabled(true))
          local saved=files["/profile/aardwolf-vibe-data/workspace.json"]
          assert(saved and encoded[saved].enabled==true)
          assert(workspace:stop() and tableCount(handlers)==0)
          workspace=Factory.new(_G,settings);assert(workspace:start())
          assert(workspace:status().enabled and workspace:status().source=="saved")
          assert(workspace:stop())

          files["/profile/aardwolf-vibe-data/workspace.json"]="broken"
          workspace=Factory.new(_G,settings)
          local ok,message=workspace:start()
          assert(not ok and message:find("preserved",1,true))
          assert(workspace:status().locked and workspace:status().mode=="off")
          assert(not workspace:setEnabled(true))
          assert(files["/profile/aardwolf-vibe-data/workspace.json"]=="broken")
          assert(workspace:reset())
          assert(files["/profile/aardwolf-vibe-data/workspace.json.corrupt-20260921-120000"]=="broken")
          assert(not workspace:status().locked and workspace:status().mode=="off")
        ''')

    def test_duplicate_registration_rejected_and_reset_only_changes_inner_layout(self):
        lua = self.runtime(legacy=True)
        lua.execute(r'''
          workspace=Factory.new(_G,settings);assert(workspace:start())
          local external=makePanel("external.panel","A <Panel>")
          local handle=assert(workspace:registerPanel(external:spec()))
          assert(not workspace:registerPanel(external:spec()))
          local invalid=external:spec();invalid.id="another.panel";invalid.minimumWidth=-1
          assert(not workspace:registerPanel(invalid))
          assert(workspace:setEnabled(true))
          local native=widgets["aardwolf-vibe.workspace.window"]
          assert(widgets["aardwolf-vibe.workspace.tab.root-first.external.panel"].text
            =="A &lt;Panel&gt;")
          assert(native and workspace:reset())
          assert(workspace:status().enabled and widgets["aardwolf-vibe.workspace.window"]==native)
          assert(countPanel(workspace:status().tree,"external.panel")==1)
          assert(handle:status().registered and handle:status().visible)
        ''')

    def test_workspace_only_external_panel_is_non_rendered_while_mode_is_off(self):
        lua = self.runtime(legacy=True)
        lua.execute(r'''
          workspace=Factory.new(_G,settings);assert(workspace:start())
          local externalRoot
          local spec={id="external.workspace-only",title="Workspace only",
            mount=function(parent)
              if not externalRoot then
                externalRoot=Geyser.Container:new({name="external.workspace-only.root",
                  x=0,y=0,width="100%",height="100%"},parent)
              else externalRoot:changeContainer(parent) end
              externalRoot:show();return externalRoot
            end,
            unmount=function(root) root:hide();return true end}
          local handle=assert(workspace:registerPanel(spec))
          assert(not externalRoot and handle:status().host=="unavailable"
            and not handle:status().visible)
          assert(workspace:setEnabled(true))
          assert(externalRoot and externalRoot.parent.name:find("workspace.slot",1,true))
          assert(workspace:setEnabled(false))
          assert(externalRoot.hidden and not handle:status().visible)
        ''')


if __name__ == "__main__":
    unittest.main()
