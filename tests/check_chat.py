from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
API = (ROOT / "tests/chat_api.lua").read_text()
MODEL = (ROOT / "src/resources/chat-model.lua").read_text()
SOURCE = (ROOT / "src/resources/chat.lua").read_text()


class ChatTests(unittest.TestCase):
    def runtime(self, start=True):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(API)
        model = lua.execute(MODEL)
        factory = lua.execute(SOURCE)
        lua.globals().model = model
        lua.globals().factory = factory
        lua.execute("chat=factory.new(_G,model,settings)")
        if start:
            lua.execute("assert(chat:start())")
        return lua

    def test_model_defaults_validation_routing_and_defensive_copies(self):
        lua = self.runtime(False)
        lua.execute(r'''
          local value=model.defaultConfig()
          assert(value.schemaVersion==1 and value.colorMode=="ansi" and #value.tabs==6)
          assert(value.font=="Menlo" and value.fontSize==11)
          assert(value.tabs[1].label=="All" and value.tabs[4].label=="Clan")
          local expected="answer auction barter cant chant claninfo clantalk commune curse debate ftalk gametalk gclan gossip grapevine gratz gsocial gtell helper immtalk inform ltalk market mobsay music newbie nobletalk pokerinfo question quote racetalk restores rp say spouse tech telepathy tell tiertalk wangrp wardrums yell"
          local known={};for _,channel in ipairs(model.knownChannels()) do known[channel]=true end
          local expectedCount=0
          for channel in expected:gmatch("%S+") do
            expectedCount=expectedCount+1;assert(known[channel])
            local routed=model.destinations(assert(model.normalize({chan=channel,msg="x"})),value)
            assert(routed[1]=="all")
          end
          assert(expectedCount==#model.knownChannels())
          local message=assert(model.normalize({chan="GOSSIP",msg="hello",player="Abel"}))
          assert(message.channel=="gossip" and message.text=="hello")
          local destinations=model.destinations(message,value)
          assert(#destinations==2 and destinations[1]=="all" and destinations[2]=="gossip")
          local clan=model.destinations(assert(model.normalize({chan="gclan",msg="x"})),value)
          assert(#clan==2 and clan[2]=="clan")
          local newbie=model.destinations(assert(model.normalize({chan="answer",msg="x"})),value)
          assert(#newbie==2 and newbie[2]=="newbie")
          assert(not model.normalize({chan={},msg="bad"}))
          assert(not model.normalize({chan="tell",msg="bad\nline"}))
          local copy=model.defaultConfig();copy.tabs[1].label="Changed"
          assert(model.defaultConfig().tabs[1].label=="All")
          local valid=assert(model.validateConfig(value));valid.tabs[1].label="Other"
          assert(value.tabs[1].label=="All")
          local old=model.copy(value);old.font=nil;old.fontSize=nil
          local upgraded=assert(model.validateConfig(old))
          assert(upgraded.font=="Menlo" and upgraded.fontSize==11)
          assert(old.font==nil and old.fontSize==nil)
          value.font="DejaVu Sans Mono";value.fontSize=14
          assert(model.validateConfig(value))
          value.font="bad\nfont";assert(not model.validateConfig(value))
          value.font="DejaVu Sans Mono";value.fontSize=5
          assert(not model.validateConfig(value))
          value.fontSize=33;assert(not model.validateConfig(value))
          value.fontSize=12.5;assert(not model.validateConfig(value))
          value.fontSize=14
          value.tabs={};assert(not model.validateConfig(value))
        ''')

    def test_color_parser_handles_ansi_raw_xterm_and_literal_markup(self):
        lua = self.runtime(False)
        lua.execute(r'''
          local runs=assert(model.colorRuns("plain <tag> \27[31mred\27[0m", "ansi"))
          local text="";local red=false
          for _,run in ipairs(runs) do
            text=text..run.text
            if run.text=="red" then red=run.fg[1]==170 and run.fg[2]==0 end
          end
          assert(text=="plain <tag> red" and red)
          runs=assert(model.colorRuns("@Rbright @x123x@@", "raw"))
          text="";local xterm=false
          for _,run in ipairs(runs) do
            text=text..run.text
            if run.text=="x@" then xterm=true end
          end
          assert(text=="bright x@" and xterm)
          assert(not model.colorRuns("text", "invalid"))
        ''')

    def test_window_defaults_lifecycle_takeover_show_hide_and_status(self):
        lua = self.runtime()
        lua.execute(r'''
          local supports='core.supports.set ["char 1","comm 1","debug 0","room 1"]'
          local window=chatWindow()
          assert(window and window.cons.restoreLayout and window.cons.autoDock)
          assert(window.cons.docked and window.cons.dockPosition=="top")
          assert(#calls>=3 and calls[1]=="enable:aardwolf-vibe.chat:Comm")
          assert(calls[2]==supports and calls[3]=="gmcpchannels on")
          assert(chat:status().supportsSetRequested and chat:status().takeoverRequested)
          assert(chat:status().tabCount==6)
          assert(chat:start() and chatWindow()==window)
          assert(chat:hide() and window.hidden and not chat:status().visible)
          receive("gossip","while hidden","Friend")
          assert(chat:status().retained==1 and pane("gossip").output=="while hidden\n")
          assert(chat:show() and not window.hidden and chat:status().visible)
          assert(chat:stop() and calls[#calls-1]=="gmcpchannels off")
          assert(calls[#calls]=="disable:aardwolf-vibe.chat:Comm")
          assert(tableCount(handlers)==0 and tableCount(widgets)==0)
          assert(chat:stop())
        ''')

    def test_routing_duplicates_unknown_channels_and_say_mirroring(self):
        lua = self.runtime()
        lua.execute(r'''
          local before=#mainRuns
          receive("gossip","hello <literal>","Friend")
          assert(pane("all").output=="hello <literal>\n")
          assert(pane("gossip").output=="hello <literal>\n")
          assert(pane("tell").output=="")
          assert(#mainRuns==before)
          receive("gossip","hello <literal>","Friend")
          assert(pane("gossip").output=="hello <literal>\nhello <literal>\n")
          receive("futurechan","unknown","")
          assert(pane("all").output:find("unknown",1,true))
          receive("say","local words","Friend")
          assert(mainRuns[#mainRuns].text=="\n")
          local found=false
          for _,run in ipairs(mainRuns) do if run.text=="local words" then found=true end end
          assert(found)
          local count=#mainRuns;receive("tell","private","Friend");assert(#mainRuns==count)
          assert(chat:status().received==5 and chat:status().retained==5)
        ''')

    def test_config_persistence_custom_routing_replay_and_copies(self):
        lua = self.runtime()
        lua.execute(r'''
          receive("gossip","before","Friend")
          local original=chat:getConfig();original.tabs[1].label="Corrupt caller"
          assert(chat:getConfig().tabs[1].label=="All")
          local value=chat:getConfig()
          value.tabs[#value.tabs+1]={id="social",label="Social",channels={"gossip","futurechan"}}
          assert(chat:applyConfig(value))
          assert(chat:status().tabCount==7 and pane("social").output=="before\n")
          receive("futurechan","new","Friend")
          assert(pane("social").output=="before\nnew\n")
          assert(files["/profile/aardwolf-vibe-data/chat.json"])
          local saved=encoded[files["/profile/aardwolf-vibe-data/chat.json"]]
          assert(saved.tabs[7].id=="social")
          value.tabs[7].label="Changed after save"
          assert(chat:getConfig().tabs[7].label=="Social")
        ''')

    def test_font_settings_apply_to_existing_and_new_tabs_and_reload(self):
        lua = self.runtime()
        lua.execute(r'''
          receive("gossip","retained","Friend")
          local existing=pane("gossip")
          assert(existing.font=="Menlo" and existing.fontSize==11)
          local value=chat:getConfig()
          value.font="DejaVu Sans Mono";value.fontSize=16
          value.tabs[#value.tabs+1]={id="social",label="Social",channels={"gossip"}}
          assert(chat:applyConfig(value))
          assert(pane("gossip")==existing and existing.output=="retained\n")
          assert(existing.font=="DejaVu Sans Mono" and existing.fontSize==16)
          assert(pane("social").font=="DejaVu Sans Mono")
          assert(pane("social").fontSize==16 and pane("social").output=="retained\n")
          local saved=encoded[files["/profile/aardwolf-vibe-data/chat.json"]]
          assert(saved.font=="DejaVu Sans Mono" and saved.fontSize==16)
          value.font="Changed by caller"
          assert(chat:getConfig().font=="DejaVu Sans Mono")
          assert(chat:stop() and chat:start())
          assert(chat:getConfig().font=="DejaVu Sans Mono")
          assert(pane("gossip").fontSize==16 and pane("social").fontSize==16)
        ''')

    def test_font_editor_validates_before_saving_and_preserves_legacy_config(self):
        lua = self.runtime(False)
        lua.execute(r'''
          local old=model.defaultConfig();old.font=nil;old.fontSize=nil
          local key=yajl.to_string(old)
          files["/profile/aardwolf-vibe-data/chat.json"]=key
          assert(chat:start())
          assert(chat:getConfig().font=="Menlo" and chat:getConfig().fontSize==11)
          click("aardwolf-vibe.chat.configure")
          widgets["aardwolf-vibe.chat.editor.font"].action("Fira Code")
          widgets["aardwolf-vibe.chat.editor.size"].action("15")
          click("aardwolf-vibe.chat.editor.apply")
          assert(chat:getConfig().font=="Fira Code" and chat:getConfig().fontSize==15)
          assert(pane("all").font=="Fira Code" and pane("all").fontSize==15)
          local saved=files["/profile/aardwolf-vibe-data/chat.json"]
          click("aardwolf-vibe.chat.configure")
          widgets["aardwolf-vibe.chat.editor.font"]:print("No Such Font")
          click("aardwolf-vibe.chat.editor.apply")
          assert(chat:getConfig().font=="Fira Code" and files["/profile/aardwolf-vibe-data/chat.json"]==saved)
          assert(widgets["aardwolf-vibe.chat.editor.status"].text:find("not installed",1,true))
          widgets["aardwolf-vibe.chat.editor.font"]:print("Fira Code")
          widgets["aardwolf-vibe.chat.editor.size"]:print("0")
          click("aardwolf-vibe.chat.editor.apply")
          assert(chat:getConfig().fontSize==15 and files["/profile/aardwolf-vibe-data/chat.json"]==saved)
          assert(widgets["aardwolf-vibe.chat.editor.status"].text:find("6-32",1,true))
          click("aardwolf-vibe.chat.editor.cancel")
          assert(chat:resetConfig())
          assert(pane("all").font=="Menlo" and pane("all").fontSize==11)
        ''')

    def test_shared_session_store_is_bounded_by_messages_and_bytes(self):
        lua = self.runtime()
        lua.execute(r'''
          for index=1,10002 do receive("futurechan",tostring(index),"") end
          assert(chat:status().retained==10000 and chat:status().sequence==10002)
          fire("sysDisconnectionEvent")
          local large=string.rep("x",65000)
          for index=1,70 do receive("futurechan",large,"") end
          assert(chat:status().bytes<=4*1024*1024 and chat:status().retained<70)
        ''')

    def test_malformed_config_runs_defaults_and_requires_explicit_reset(self):
        lua = self.runtime(False)
        lua.execute(r'''
          files["/profile/aardwolf-vibe-data/chat.json"]="broken"
          assert(chat:start())
          local status=chat:status()
          assert(status.configLocked and status.configSource=="malformed" and status.tabCount==6)
          assert(files["/profile/aardwolf-vibe-data/chat.json"]=="broken")
          assert(not chat:applyConfig(chat:getConfig()))
          assert(chat:resetConfig())
          assert(not chat:status().configLocked)
          assert(files["/profile/aardwolf-vibe-data/chat.json"]:match("^encoded:"))
          assert(files["/profile/aardwolf-vibe-data/chat.json.corrupt-20260917-120000"]=="broken")
        ''')

    def test_editor_adds_tab_and_overflow_indicator_scrolls_without_click(self):
        lua = self.runtime()
        lua.execute(r'''
          chatWindow():resize(300,260);fire("sysWindowResizeEvent")
          local indicator=widgets["aardwolf-vibe.chat.more"]
          assert(not indicator.hidden and indicator.text=="→" and indicator.clickCallback==nil)
          wheel(indicator.name,-120);assert(indicator.text=="↔" or indicator.text=="←")
          click("aardwolf-vibe.chat.configure")
          assert(widgets["aardwolf-vibe.chat.editor"] and widgets["aardwolf-vibe.chat.editor.name"])
          click("aardwolf-vibe.chat.editor.add")
          widgets["aardwolf-vibe.chat.editor.name"]:print("Extra")
          click("aardwolf-vibe.chat.editor.apply")
          assert(chat:status().tabCount==7 and pane("tab1"))
          assert(not widgets["aardwolf-vibe.chat.editor"])
        ''')

    def test_unread_reset_reconnect_and_stale_generation_fencing(self):
        lua = self.runtime()
        lua.execute(r'''
          local supports='core.supports.set ["char 1","comm 1","debug 0","room 1"]'
          local old=handlers["aardwolf-vibe.chat:message"].callback
          receive("tell","one","Friend")
          assert(widgets["aardwolf-vibe.chat.tab.tell"].text:find("1",1,true))
          click("aardwolf-vibe.chat.tab.tell")
          assert(not widgets["aardwolf-vibe.chat.tab.tell"].text:find("·",1,true))
          fire("sysDisconnectionEvent")
          assert(chat:status().retained==0 and not chat:status().supportsSetRequested)
          assert(not chat:status().takeoverRequested)
          connected=true;fire("sysConnectionEvent")
          fire("sysProtocolEnabled","GMCP")
          local sets,ons=0,0
          for _,call in ipairs(calls) do
            if call==supports then sets=sets+1 elseif call=="gmcpchannels on" then ons=ons+1 end
          end
          assert(sets==2 and ons==2)
          fire("sysProtocolEnabled","GMCP")
          local setsAgain,onsAgain=0,0
          for _,call in ipairs(calls) do
            if call==supports then setsAgain=setsAgain+1
            elseif call=="gmcpchannels on" then onsAgain=onsAgain+1 end
          end
          assert(setsAgain==2 and onsAgain==2)
          assert(chat:stop());assert(chat:start())
          gmcp.comm.channel={chan="gossip",msg="stale",player="Friend"}
          old("gmcp.comm.channel")
          assert(chat:status().retained==0)
        ''')

    def test_supports_set_failure_blocks_takeover_and_retries(self):
        lua = self.runtime(False)
        lua.execute(r'''
          local supports='core.supports.set ["char 1","comm 1","debug 0","room 1"]'
          fail.sendGMCP=supports
          assert(chat:start())
          local status=chat:status()
          assert(not status.supportsSetRequested and not status.takeoverRequested)
          assert(status.lastError:find("Cannot advertise Aardwolf GMCP modules",1,true))
          for _,call in ipairs(calls) do assert(call~="gmcpchannels on") end
          fail.sendGMCP=nil
          fire("sysProtocolEnabled","GMCP")
          status=chat:status()
          assert(status.supportsSetRequested and status.takeoverRequested and status.lastError==nil)
          assert(calls[#calls-1]==supports and calls[#calls]=="gmcpchannels on")
        ''')

    def test_render_failure_relinquishes_takeover_and_partial_start_cleans_up(self):
        lua = self.runtime()
        lua.execute(r'''
          fail.render=true
          receive("gossip","cannot draw","Friend")
          assert(chat:status().lifecycle=="degraded")
          assert(not chat:status().takeoverRequested)
          assert(calls[#calls]=="gmcpchannels off")
          fail.render=nil
        ''')
        lua = self.runtime(False)
        lua.execute(r'''
          fail.registrationAt=3
          assert(not chat:start())
          assert(tableCount(handlers)==0 and tableCount(widgets)==0)
          local disabled=false
          for _,call in ipairs(calls) do if call=="disable:aardwolf-vibe.chat:Comm" then disabled=true end end
          assert(not disabled)
          fail.registrationAt=nil
          assert(chat:start())
        ''')
        lua = self.runtime(False)
        lua.execute(r'''
          fail.gmod=true
          assert(not chat:start())
          assert(tableCount(handlers)==0 and tableCount(widgets)==0)
          assert(calls[#calls]=="disable:aardwolf-vibe.chat:Comm")
        ''')


if __name__ == "__main__":
    unittest.main()
