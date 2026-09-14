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
          mudlet.key={Escape=16777216,Return=16777220,J=74,K=75}
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
          assert(count(keys)==5);press(4,'Escape');assert(cb==1 and ca==0)
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
