"""Contextual menu keys preserve typing and isolate the topmost owned scope."""
import unittest
import check_package


class MenuKeysTests(unittest.TestCase):
    def setUp(self):
        h = check_package.PackageTests()
        h.setUp()
        self.addCleanup(h.doCleanups)
        self.lua = h.lua
        self.lua.execute('''
          assert(AardwolfToolbox.start());t=AardwolfToolbox
          keys={};local serial=0
          mudlet.key={Escape=16777216,Return=16777220,J=74,K=75,H=72,L=76}
          mudlet.keymodifier={Alt=2,Shift=4}
          function tempKey(mod,key,fn)
            serial=serial+1;if serial==failKey then return -1 end
            keys[serial]={mod=mod,key=key,fn=fn};return serial
          end
          function killKey(id) keys[id]=nil end
          function press(mod,key)
            for _,k in pairs(keys) do if k.mod==mod and k.key==mudlet.key[key] then k.fn();return end end
            error('Missing key '..key)
          end
          function send() error('Unexpected gameplay') end
          function expandAlias() error('Unexpected alias') end
        ''')

    def test_only_top_scope_dismisses_and_old_callbacks_are_inert(self):
        self.lua.execute('''
          local a,b;local ca,cb=0,0
          a=assert(t.menuKeys.push('a',{close=function() ca=ca+1;a.release() end}))
          b=assert(t.menuKeys.push('b',{close=function() cb=cb+1;b.release() end}))
          assert(count(keys)==7);press(4,'Escape');assert(cb==1 and ca==0)
          local old;for _,k in pairs(keys) do if k.mod==4 then old=k.fn end end
          press(4,'Escape');assert(ca==1 and count(keys)==0)
          local c=assert(t.menuKeys.push('c',{close=function() error('stale key') end}))
          old();assert(t.menuKeys.active());c.release();assert(count(keys)==0)
        ''')

    def test_no_typing_keys_and_atomic_key_failure_cleanup(self):
        self.lua.execute('''
          failKey=3;local scope,why=t.menuKeys.push('failed',{close=function() end})
          assert(not scope and why:find('Cannot register') and count(keys)==0 and not t.menuKeys.active())
          failKey=nil;scope=assert(t.menuKeys.push('ready',{close=function() end}))
          for _,key in pairs(keys) do assert(key.mod~=0 or key.key==mudlet.key.Escape) end
          scope.release();assert(count(keys)==0)
        ''')

    def test_nested_tools_and_workspace_and_settings_block(self):
        self.lua.execute('''
          assert(t.browser.open('inventory'));assert(t.launcher.open())
          press(4,'Escape');assert(not t.launcher.isEditing() and t.browser.isEditing())
          assert(t.launcher.open());t.openSettings()
          press(4,'Escape');assert(t.launcher.isEditing() and t.settingsWindow.opened)
          t.settingsWindow.close();press(4,'Escape');assert(not t.launcher.isEditing())
          press(4,'Escape');assert(not t.browser.isEditing() and count(keys)==0)
        ''')

    def test_keyboard_tools_selection_filter_invalidates_and_activation_once(self):
        self.lua.execute('''
          local calls=0
          t.launcher.register({id='keyboard.fixture',label='Keyboard Éowyn <literal>',callback=function() calls=calls+1 end})
          assert(t.launcher.open());local input=widgets['AardwolfToolbox.launcher.search']
          input.action('Keyboard Éowyn');press(2,'Return');assert(calls==0)
          press(2,'J');assert(widgets['AardwolfToolbox.launcher.feedback'].text:find('&lt;literal&gt;',1,true))
          input.action('no matching item');press(2,'Return');assert(calls==0)
          input.action('Keyboard Éowyn');press(2,'K');press(2,'Return')
          assert(calls==1 and not t.launcher.isEditing() and count(keys)==0)
        ''')

    def test_keyboard_item_action_uses_guard_and_menu_closes_first(self):
        self.lua.execute('''
          local Items=assert(loadstring(sources['item-state']))();local items=Items.new()
          assert(items.replace('carried',{['42']=assert(Items.parse('42,,a bag,1,11,0,-1,-1'))}))
          t.inventory.get=items.get;t.inventory.list=items.list;t.inventory.status=items.status
          assert(t.browser.open('inventory'));widgets['AardwolfToolbox.browser.inventory.row.1'].callback()
          widgets['AardwolfToolbox.browser.inventory.actions'].callback()
          press(2,'Return');assert(widgets['AardwolfToolbox.browser.menu'])
          press(2,'J');press(2,'Return')
          assert(not widgets['AardwolfToolbox.browser.menu'] and t.browser.isEditing())
          assert(widgets['AardwolfToolbox.browser.inventory.feedback'].text:find('Disconnected'))
          widgets['AardwolfToolbox.browser.inventory.actions'].callback();press(2,'J')
          local old=widgets['AardwolfToolbox.browser.menu.row.1'].callback
          press(4,'Escape');assert(t.browser.isEditing());old()
          press(4,'Escape');assert(not t.browser.isEditing() and count(keys)==0)
        ''')

    def test_stop_removes_only_owned_keys(self):
        self.lua.execute('''
          keys[999]={fn=function() end}
          assert(t.launcher.open());assert(t.browser.open('inventory'))
          t.stop();assert(count(keys)==1 and keys[999] and not t.menuKeys.active())
          assert(t.start());assert(t.launcher.open());t.stop();assert(count(keys)==1)
        ''')

    def test_tools_page_boundaries_follow_selection_and_reject_old_rows(self):
        self.lua.execute('''
          local calls=0
          for i=1,60 do t.launcher.register({id='page'..i,label=string.format('Paging %02d',i),callback=function() calls=calls+1 end}) end
          assert(t.launcher.open());widgets['AardwolfToolbox.launcher.search'].action('Paging')
          local body=widgets['AardwolfToolbox.launcher.body'];local n=0
          for i=1,60 do
            local row=widgets['AardwolfToolbox.launcher.action.'..i]
            if row then n=n+1;assert(row.y+row:get_height()<=body:get_height()) end
          end
          assert(n>0 and n<=24 and n<60)
          local old=widgets['AardwolfToolbox.launcher.action.1'].callback
          for i=1,n+1 do press(2,'J') end
          assert(widgets['AardwolfToolbox.launcher.action.1'].text==string.format('Paging %02d',n+1))
          assert(widgets['AardwolfToolbox.launcher.feedback'].text:find(string.format('Paging %02d',n+1),1,true))
          old();assert(calls==0)
          press(2,'K');assert(widgets['AardwolfToolbox.launcher.action.1'].text=='Paging 01')
          press(2,'Return');assert(calls==1 and not t.launcher.isEditing())
        ''')

    def test_explicit_paging_clears_selection_and_uses_current_page(self):
        self.lua.execute('''
          local calls=0
          for i=1,40 do t.launcher.register({id='page'..i,label=string.format('Paging %02d',i),callback=function() calls=calls+1 end}) end
          assert(t.launcher.open());widgets['AardwolfToolbox.launcher.search'].action('Paging')
          press(2,'J');press(2,'L');press(2,'Return');assert(calls==0)
          local first=widgets['AardwolfToolbox.launcher.action.1'].text
          assert(first~='Paging 01');press(2,'J')
          assert(widgets['AardwolfToolbox.launcher.feedback'].text:find(first,1,true))
          press(2,'H');assert(widgets['AardwolfToolbox.launcher.action.1'].text=='Paging 01')
          press(2,'Return');assert(calls==0)
          widgets['AardwolfToolbox.launcher.search'].action('nothing matches')
          assert(not widgets['AardwolfToolbox.launcher.action.1'])
          press(2,'L');press(2,'J');press(2,'Return');assert(calls==0)
          assert(widgets['AardwolfToolbox.launcher.title'].text:find('1 / 1',1,true))
        ''')

    def test_selected_utility_survives_font_and_window_reflow(self):
        self.lua.execute('''
          local chosen
          for i=1,40 do local id=i;t.launcher.register({id='page'..i,label=string.format('Paging %02d',i),callback=function() chosen=id end}) end
          assert(t.launcher.open());widgets['AardwolfToolbox.launcher.search'].action('Paging')
          for i=1,12 do press(2,'J') end
          windowHeight=650;windowWidth=900;fire('sysWindowResizeEvent')
          assert(t.config.set('appearance','preset','large'));fire('AardwolfToolbox.ui.changed')
          local found=false;local body=widgets['AardwolfToolbox.launcher.body']
          for i=1,24 do
            local row=widgets['AardwolfToolbox.launcher.action.'..i]
            if row then assert(row.y+row:get_height()<=body:get_height());if row.text=='Paging 12' then found=true end end
          end
          assert(found);press(2,'Return');assert(chosen==12)
        ''')

    def test_tools_unchanged_geometry_and_boundary_keys_do_not_write_widgets(self):
        self.lua.execute('''
          assert(t.launcher.open());widgets['AardwolfToolbox.launcher.search'].action('Open inventory')
          press(2,'J');local row=widgets['AardwolfToolbox.launcher.action.1'];local writes=0
          row.echo=function() writes=writes+1 end;row.setStyleSheet=function() writes=writes+1 end
          fire('sysWindowResizeEvent');press(2,'K');press(2,'J');press(2,'H');press(2,'L')
          assert(widgets[row.name]==row and writes==0)
        ''')

    def test_item_menu_keyboard_crosses_pages_and_revalidates_target(self):
        self.lua.execute('''
          local Items=assert(loadstring(sources['item-state']))();local items=Items.new();local rows={}
          for i=1,60 do rows[tostring(i)]=assert(Items.parse(i..',,bag '..i..',1,11,0,-1,-1')) end
          assert(items.replace('carried',rows))
          t.inventory.get=items.get;t.inventory.list=items.list;t.inventory.status=items.status
          assert(t.browser.open('inventory'));widgets['AardwolfToolbox.browser.inventory.row.1'].callback()
          widgets['AardwolfToolbox.browser.inventory.actions'].callback()
          local n=0;for i=1,60 do if widgets['AardwolfToolbox.browser.menu.row.'..i] then n=n+1 end end
          for i=1,n+1 do press(2,'J') end
          local target=widgets['AardwolfToolbox.browser.menu.row.'..(n+1)];assert(target)
          local old=target.callback
          press(2,'H');old();assert(widgets['AardwolfToolbox.browser.menu'])
          press(2,'L');press(2,'Return');assert(widgets['AardwolfToolbox.browser.menu'])
          press(2,'J');items.clear();press(2,'Return')
          assert(not widgets['AardwolfToolbox.browser.menu'])
          assert(widgets['AardwolfToolbox.browser.inventory.feedback'].text:find('changed'))
        ''')
