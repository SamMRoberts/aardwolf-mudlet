"""Utility discovery uses local callbacks; native focus acceptance is separate."""
import unittest
import check_package


class LauncherTests(unittest.TestCase):
    def setUp(self):
        harness = check_package.PackageTests()
        harness.setUp()
        self.addCleanup(harness.doCleanups)
        self.lua = harness.lua
        self.lua.execute('''
          assert(AardwolfToolbox.start());t=AardwolfToolbox;l=t.launcher
          keys={};mudlet.key={Escape=16777216,J=74,K=75,Return=16777220};mudlet.keymodifier={Shift=4,Alt=2}
          local serial=0
          function tempKey(mod,key,callback) serial=serial+1;keys[serial]=callback;return serial end
          function killKey(id) keys[id]=nil end
          function send() error('Unexpected gameplay dispatch') end
          function expandAlias() error('Unexpected alias dispatch') end
        ''')

    def test_registry_search_literal_names_and_explicit_activation(self):
        self.lua.execute('''
          local calls=0
          l.register({id='example',label='Éowyn <red> 100%',callback=function() calls=calls+1 end})
          assert(not pcall(l.register,{id='example',label='duplicate',callback=function() end}))
          assert(not pcall(l.register,{id='bad id',label='Invalid',callback=function() end}))
          assert(not pcall(l.register,{id='bad',label='Valid',callback='send something'}))
          assert(l.open());assert(l.isEditing())
          local input=widgets['AardwolfToolbox.launcher.search'];input.action('Éowyn')
          local row=widgets['AardwolfToolbox.launcher.action.1']
          assert(row.text:find('&lt;red&gt;',1,true) and row.renderedFontSize>=12)
          assert(calls==0);assert(l.open());assert(widgets[input.name]==input)
          row.callback();assert(calls==1 and not l.isEditing())
          row.callback();assert(calls==1)
        ''')

    def test_stale_callbacks_filters_and_offline_refresh_guard(self):
        self.lua.execute('''
          local calls=0
          l.register({id='fixture',label='Fixture',callback=function() calls=calls+1 end})
          assert(l.open());local input=widgets['AardwolfToolbox.launcher.search']
          input.action('Fixture');local click=widgets['AardwolfToolbox.launcher.action.1'].callback
          input.action('unmatched');click();assert(calls==0)
          local ok,why=l.activate('refresh.mobs');assert(not ok and why and l.isEditing())
          assert(widgets['AardwolfToolbox.launcher.feedback'].text==t.ui.escape(why))
          l.close();input.action('Fixture');assert(not l.isEditing())
          assert(l.open());l.unregister('fixture');assert(not l.activate('fixture'))
        ''')

    def test_settings_walkthrough_resume_and_checked_completion(self):
        self.lua.execute('''
          assert(l.activate('settings.mapper'));assert(t.settingsWindow.opened)
          t.settingsWindow.destroy()
          assert(l.open('setup'))
          widgets['AardwolfToolbox.launcher.next'].callback()
          assert(widgets['AardwolfToolbox.launcher.title'].text:find('2 / 5'))
          widgets['AardwolfToolbox.launcher.settings'].callback()
          assert(t.settingsWindow.opened and not l.isEditing());t.settingsWindow.destroy()
          assert(l.open('setup'));assert(widgets['AardwolfToolbox.launcher.title'].text:find('2 / 5'))
          for i=1,3 do widgets['AardwolfToolbox.launcher.next'].callback() end
          fileFailures.rename=true;widgets['AardwolfToolbox.launcher.next'].callback()
          assert(l.isEditing() and not t.config.getMetadata('setupWalkthroughCompleted'))
          fileFailures.rename=nil;widgets['AardwolfToolbox.launcher.next'].callback()
          assert(not l.isEditing() and t.config.getMetadata('setupWalkthroughCompleted'))
          assert(not t.config.get('spellups','auto_refresh'))
        ''')

    def test_failure_disable_restart_and_native_resource_cleanup(self):
        self.lua.execute('''
          l.register({id='failure',label='Failure',callback=function() return nil,'Unavailable' end})
          assert(not l.activate('failure'));assert(l.last:find('Unavailable'))
          assert(l.open());assert(count(keys)==5)
          assert(t.config.set('launcher','enabled',false));assert(not l.isEditing() and count(keys)==0)
          assert(not l.open());assert(t.config.set('launcher','enabled',true))
          assert(t.start());assert(l.open())
          local first;for id in pairs(keys) do first=math.min(first or id,id) end;keys[first]();assert(not l.isEditing())
          local createKey=tempKey;tempKey=function() return nil end
          assert(not l.open() and not l.isEditing());tempKey=createKey
          assert(l.open());t.stop();assert(count(keys)==0 and count(widgets)==0)
          assert(t.start());assert(l.open());t.stop();assert(count(widgets)==0)
        ''')
