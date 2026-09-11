"""Behavior contracts for the built utility bar and inventory service (Lua 5.1)."""
from pathlib import Path
import unittest
import zipfile
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]

class UtilityTests(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime()
        self.lua.execute((ROOT/'tests/settings_api.lua').read_text())
        self.lua.execute('''
          Geyser.Container=Geyser.Label
          local proto=getmetatable(Geyser.Label:new({name='probe'})).__index
          function proto:setToolTip(text) self.tooltip=text end
          handlers={}; data={}; calls={}; connected=false; width=1200; height=800
          cache={enabled=true,get=function(path)
            local value=data; for part in path:gmatch('[^.]+') do value=type(value)=='table' and value[part] or nil end
            return value
          end}
          function getConnectionInfo() return '',0,connected end
          function getMainWindowSize() return width,height end
          function send(value) calls[#calls+1]=value end
          function sendGMCP(value) calls[#calls+1]=value end
          function registerNamedEventHandler(owner,name,event,fn) handlers[owner..name]={event=event,fn=fn}; return true end
          function deleteNamedEventHandler(owner,name) handlers[owner..name]=nil end
          function raiseEvent(event,...)
            local snapshot={}; for _,h in pairs(handlers) do snapshot[#snapshot+1]=h end
            for _,h in ipairs(snapshot) do if h.event==event then h.fn(event,...) end end
          end
          function flush()
            local pending=timers; timers={}; for _,fn in pairs(pending) do fn() end
          end
          function tempRegexTrigger(pattern,fn) trigger=fn; return 1 end
          function killTrigger() trigger=nil end
          gags=0; function deleteLine() gags=gags+1 end
          function feed(text) line=text; if trigger then trigger() end end
          edges={Left=0,Right=300,Top=0,Bottom=32}
          for edge in pairs(edges) do
            _G['getBorder'..edge]=function() return edges[edge] end
            _G['setBorder'..edge]=function(n) edges[edge]=n end
          end
        ''')
        with zipfile.ZipFile(ROOT/'build/AardwolfToolbox.mpackage') as z:
            for name in ('incoming','borders','inventory','utility-bar'):
                self.lua.globals()[name.replace('-','_')]=self.lua.execute(z.read(name+'.lua').decode())
        self.lua.execute('''
          incoming=incoming.new(_G); borders=borders.new(_G)
          inventory=inventory.new(_G,cache,incoming)
          bar=utility_bar.new(_G,cache,inventory,borders,function() opened=true end)
          function snapshot()
            feed('{invdata}'); feed('42,,a bag, with commas,1,11,0,-1,-1')
            feed('43,,worn,1,7,0,2,-1'); feed('{/invdata}')
          end
        ''')

    def test_spellup_indicator_coverage_automation_and_lifecycle(self):
        self.lua.execute('''
          fresh=true; tracking=true; effects={}; auto={automatic=false,last='Off'}
          tracker={enabled=true,isFresh=function() return fresh end,
            get=function(id) return {spellup=true} end,
            snapshot=function() return {catalog={[1]={type=1,practice=100},[2]={type=1,practice=75},[3]={type=2,practice=100}},active=effects} end}
          controller={status=function()
            auto.coverage={known=true,active=#effects,total=2}
            if effects[1] and effects[1].awaiting then auto.coverage={known=false,reason='Buff expiry awaiting server confirmation'} end
            return auto
          end}
          bar.bindSpellups(tracker,controller,function() buffsOpened=true end)
          assert(bar.start()); local id='AardwolfToolbox.utilityBar.item.spellups'
          local widget=widgets[id]
          local function check(symbol,color,description)
            raiseEvent('AardwolfToolbox.spells.updated'); flush()
            assert(widget.text:find(symbol,1,true)); assert(widget.text:find(color,1,true))
            assert(widget.tooltip:find(description,1,true),widget.tooltip)
            assert(widgets[id]==widget)
          end
          check('○','#B0B0B0','0/2')
          effects={{id=1}}; check('◐','#FFCC66','1/2')
          effects={{id=1},{id=2}}; check('●','#66DD88','2/2')
          auto={automatic=true,last='Ready'}; check('✓','#66DD88','Auto refresh enabled')
          auto.pending=true; auto.last='Refresh queued'; check('…','#FFCC66','Refresh queued')
          auto.inflight=true; auto.last='Spellup running'; check('↻','#77CCFF','Spellup running')
          auto.paused='Uncertain'; auto.last='Paused: Uncertain'; check('!','#FF7777','Paused: Uncertain')
          auto.automatic=false; check('!','#FF7777','Auto refresh disabled')
          effects[1].awaiting=true; check('?','#B0B0B0','awaiting server confirmation')
          fresh=false; check('?','#B0B0B0','coverage unknown')
          tracker.enabled=false; check('?','#B0B0B0','tracking disabled')
          widget.callback(); assert(buffsOpened and #calls==0)
          bar.configure({enabled=true,font_size=10,show_spellups=false}); flush(); assert(widget.hidden)
          bar.stop(); assert(not widgets[id] and next(handlers)==nil)
          assert(bar.start()); assert(bar.start()); assert(widgets[id])
          assert(not pcall(bar.updateItem,'spellups',{color='red; html'}))
          bar.stop()
        ''')

    def test_readings_missing_zero_and_progression(self):
        self.lua.execute('''
          assert(bar.start()); assert(bar.start()); assert(edges.Top==28)
          local prefix='AardwolfToolbox.utilityBar.item.'
          assert(widgets[prefix..'level'].text=='Lv --')
          data={char={base={level=116,tier=0,redos=0,remorts=2},worth={gold=175956,bank=12723477}}}
          raiseEvent('AardwolfToolbox.gmcp.updated'); flush()
          assert(widgets[prefix..'total'].text=='Total 317')
          assert(widgets[prefix..'worth'].text=='Worth 12,899,433')
          assert(widgets[prefix..'tier'].text=='Tier 0')
          data.char.base={level=250,tier=1,redos=1,remorts=1}
          raiseEvent('AardwolfToolbox.gmcp.updated'); flush()
          assert(widgets[prefix..'total'].text=='Total 3,015')
          data={}; raiseEvent('AardwolfToolbox.gmcp.cleared'); flush()
          assert(widgets[prefix..'gold'].text=='Gold --')
          bar.stop(); bar.stop(); assert(edges.Top==0 and edges.Bottom==32 and edges.Right==300)
          assert(next(handlers)==nil and trigger==nil)
        ''')

    def test_registry_overflow_visibility_callbacks_and_restart(self):
        self.lua.execute('''
          bar.registerItem({id='future',label='<Quest>',order=8,overflowPriority=0,callback=function() clicked=true end})
          assert(not pcall(bar.registerItem,{id='future',label='x',order=9,overflowPriority=0}))
          bar.updateItem('future',{text='<ready>',tooltip='<literal>'})
          assert(bar.start())
          local label=widgets['AardwolfToolbox.utilityBar.item.future']
          assert(label.text=='&lt;Quest&gt; &lt;ready&gt;')
          bar.updateItem('future',{text='new'}); assert(widgets[label.name]==label)
          width=200; raiseEvent('sysWindowResizeEvent'); flush()
          assert(label.hidden and not widgets['AardwolfToolbox.utilityBar.overflow'].hidden)
          assert(not widgets['AardwolfToolbox.utilityBar.item.settings'].hidden)
          local row=widgets['AardwolfToolbox.utilityBar.menu.future']; row.callback()
          assert(clicked)
          assert(bar.unregisterItem('future')); assert(not widgets[label.name])
          assert(not pcall(bar.updateItem,'future',{text='bad'}))
          bar.stop(); assert(bar.start()); bar.stop()
        ''')

    def test_inventory_readiness_snapshots_and_interleaving(self):
        self.lua.execute('''
          assert(inventory.start()); assert(#calls==0)
          connected=true; data={char={status={state=7}}}; raiseEvent('AardwolfToolbox.gmcp.updated'); assert(#calls==0)
          data.char.status.state=3; raiseEvent('AardwolfToolbox.gmcp.updated')
          assert(calls[1]=='config invmon on' and calls[2]=='invdata')
          feed('{invdata}'); feed('42,,a bag, with commas,1,11,0,-1,-1')
          feed('{invmon}4,44,-1,-1'); feed('{invmon}4,44,-1,-1'); feed('{invmon}3,42,-1,-1')
          feed('{/invdata}'); assert(inventory.count==1)
          feed('{invdata 42}'); feed('55,,inside,1,11,0,-1,-1'); feed('{/invdata}')
          assert(inventory.count==1)
          inventory.stop(); assert(inventory.count==nil and trigger==nil)
        ''')

    def test_all_inventory_actions_duplicates_and_zero(self):
        self.lua.execute('''
          inventory.start(); snapshot(); assert(inventory.count==1)
          for _,action in ipairs({2,3,6,7,9,11}) do
            feed('{invmon}'..action..',42,-1,-1'); feed('{invmon}'..action..',42,-1,-1')
            assert(inventory.count==0); feed('{invmon}4,42,-1,-1')
          end
          for _,action in ipairs({1,4,5,10,12}) do
            feed('{invmon}3,42,-1,-1'); feed('{invmon}'..action..',42,-1,-1'); feed('{invmon}'..action..',42,-1,-1')
            assert(inventory.count==1)
          end
          feed('{invdata}'); feed('{/invdata}'); assert(inventory.count==0)
          raiseEvent('AardwolfToolbox.gmcp.cleared'); assert(inventory.count==nil)
          inventory.stop()
        ''')

    def test_bounded_retry_timeout_malformed_and_disable(self):
        self.lua.execute('''
          connected=true; data={char={status={state=3}}}; inventory.start()
          flush(); flush(); flush(); assert(#calls==3 and inventory.count==nil)
          for i=1,10 do raiseEvent('AardwolfToolbox.gmcp.updated'); flush() end
          assert(#calls==3)
          assert(inventory.request(true)); snapshot(); assert(inventory.count==1)
          feed('{invmon}99,42,-1,-1'); assert(inventory.count==nil)
          flush(); assert(#calls==5)
          feed('{invdata}'); feed('garbage'); assert(inventory.count==nil)
          flush(); assert(#calls==5)
          data.char.status.state=6; assert(not inventory.request(true)); assert(#calls==5)
          inventory.stop(); flush(); assert(#calls==5)
        ''')

    def test_dispatcher_forwarding_and_capture_ownership(self):
        self.lua.execute('''
          archived={}; formatted=0
          incoming.add('AardwolfToolbox.tags',20,function(s) archived[#archived+1]=s; return true,true end,error)
          incoming.add('consider',30,function() formatted=formatted+1 end,error)
          incoming.add('ascii',10,function(s) return s=='{invmon}4,99,-1,-1',true end,error)
          inventory.start(); snapshot(); assert(#archived==4 and gags==4 and inventory.count==1)
          feed('{invmon}4,99,-1,-1'); assert(#archived==4 and inventory.count==1)
          incoming.remove('AardwolfToolbox.tags'); feed('{invmon}4,44,-1,-1')
          assert(inventory.count==2 and formatted==0 and gags==6)
        ''')

    def test_sidebar_restore_and_top_ascii_reservations(self):
        self.lua.execute('''
          BaseUI={container={y='0%',height='100%'}}
          local r=BaseUI.container
          function r:reposition() placedY=self:get_y(); placedHeight=self:get_height() end
          function r:set_constraints()
            self.get_y=function() return 0 end
            self.get_height=function() return height end
            self:reposition()
          end
          local original=r.reposition; r:set_constraints()
          borders.reserve('ascii','top',100,1,function() end)
          assert(bar.start()); assert(placedY==28 and placedHeight==height-28)
          local x,y,w,h=borders.box('AardwolfToolbox.utilityBar')
          assert(x==0 and y==0 and w==width and h==28)
          x,y,w,h=borders.box('ascii'); assert(y==28 and w==width-300)
          assert(r.y=='0%' and r.height=='100%')
          height=600; r:set_constraints(); assert(placedHeight==572)
          local replacement=function() replaced=true end
          r.reposition=replacement; bar.stop()
          assert(r.reposition==replacement and replaced and r:get_y()==0)
          assert(edges.Top==100 and edges.Right==300 and edges.Bottom==32)
          borders.release('ascii'); assert(edges.Top==0)
        ''')

    def test_abbreviations_invalid_numbers_and_visible_settings(self):
        self.lua.execute('''
          data={char={base={level=0,tier=0,redos=0,remorts=1},worth={gold=1250000000,bank=0}}}
          assert(bar.start()); width=490; raiseEvent('sysWindowResizeEvent'); flush()
          local prefix='AardwolfToolbox.utilityBar.item.'
          assert(widgets[prefix..'gold'].text=='Gold 1.2B' or widgets[prefix..'gold'].text=='Gold 1.3B')
          assert(widgets[prefix..'gold'].tooltip=='Gold: 1,250,000,000')
          assert(widgets[prefix..'level'].text=='Lv 0')
          assert(widgets[prefix..'total'].text=='Tot 0')
          widgets[prefix..'settings'].callback(); assert(opened)
          data.char.base.level=0/0; data.char.worth.gold=math.huge
          raiseEvent('AardwolfToolbox.gmcp.updated'); flush()
          assert(widgets[prefix..'gold'].text=='Gold --')
          assert(widgets[prefix..'total'].text=='Tot --')
          assert(not pcall(bar.registerItem,{id='bad',label='x',order=0/0,overflowPriority=0}))
          assert(not pcall(bar.updateItem,'level',{visible='yes'}))
        ''')

    def test_failed_activation_releases_resources(self):
        self.lua.execute('''
          local old=registerNamedEventHandler
          registerNamedEventHandler=function() return false end
          local ok,message=bar.start(); assert(not ok and message:find('Cannot register',1,true))
          assert(not bar.enabled and edges.Top==0 and next(handlers)==nil)
          assert(widgets['AardwolfToolbox.utilityBar.root']==nil)
          registerNamedEventHandler=old; assert(bar.start()); bar.stop()
        ''')

    def test_capture_limits_never_publish_partial_counts(self):
        self.lua.execute('''
          inventory.start(); snapshot(); assert(inventory.count==1)
          feed('{invdata}')
          for i=1,4097 do feed(i..',,bag,1,11,0,-1,-1') end
          assert(inventory.count==nil)
          snapshot(); assert(inventory.count==1)
          feed('{invdata}')
          for i=1,4097 do feed('{invmon}4,'..i..',-1,-1') end
          assert(inventory.count==nil)
          snapshot(); feed('{invdata}'); feed(string.rep('x',1048577)); assert(inventory.count==nil)
          inventory.stop()
        ''')

    def test_settings_persist_and_control_existing_widgets(self):
        from lua_support import install_json
        install_json(self.lua)
        with zipfile.ZipFile(ROOT/'build/AardwolfToolbox.mpackage') as z:
            self.lua.globals().Config=self.lua.execute(z.read('configuration.lua').decode())
        self.lua.execute('''
          function getMudletHomeDir() return '/profile' end
          function echo() end
          definition={id='utility',label='Utility bar',settings={
            {key='enabled',label='Enabled',type='boolean',default=true},
            {key='font_size',label='Font',type='number',default=10,min=8,max=16,integer=true},
            {key='inventory_tracking',label='Tracking',type='boolean',default=true},
            {key='show_gold',label='Gold',type='boolean',default=true}
          },apply=bar.configure}
          config=Config.new(_G); config.registerFeature(definition); config.activate()
          local label=widgets['AardwolfToolbox.utilityBar.item.gold']
          assert(config.set('utility','show_gold',false)); flush(); assert(label.hidden)
          assert(config.set('utility','font_size',12)); flush()
          assert(widgets[label.name]==label and widgets['AardwolfToolbox.utilityBar.item.level'].style:find('12pt',1,true))
          fileFailures.rename=true
          assert(not config.set('utility','show_gold',true)); assert(label.hidden)
          fileFailures.rename=false
          local restored=Config.new(_G); restored.registerFeature(definition)
          assert(restored.get('utility','font_size')==12 and not restored.get('utility','show_gold'))
          assert(config.set('utility','inventory_tracking',false)); assert(not inventory.enabled)
          assert(config.set('utility','enabled',false)); assert(not bar.enabled and not widgets[label.name])
        ''')

    def test_near_match_headers_and_unbounded_identifiers(self):
        self.lua.execute('''
          inventory.start(); snapshot(); local before=gags
          feed('{invdatabase}'); feed('ordinary output'); assert(gags==before and inventory.count==1)
          feed('{invdata garbage}'); assert(inventory.count==nil)
          snapshot(); feed('{invmon}4,'..string.rep('9',1000)..',-1,-1'); assert(inventory.count==nil)
          snapshot(); feed('{invdata}'); feed(string.rep('9',1000)..',,bag,1,11,0,-1,-1'); assert(inventory.count==nil)
          inventory.stop()
        ''')
