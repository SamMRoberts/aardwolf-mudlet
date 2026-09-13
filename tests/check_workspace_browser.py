"""On-demand workspace views and explicit item actions, with intercepted dispatch."""
import unittest
import check_package


class WorkspaceBrowserTests(unittest.TestCase):
    def setUp(self):
        harness = check_package.PackageTests()
        harness.setUp()
        self.addCleanup(harness.doCleanups)
        self.lua = harness.lua
        self.lua.execute('''
          assert(AardwolfToolbox.start());t=AardwolfToolbox;b=t.browser
          keys={};mudlet.key={Escape=16777216};local serial=0
          function tempKey(key,callback) serial=serial+1;keys[serial]=callback;return serial end
          function killKey(key) keys[key]=nil end
          assert(b.enabled,b.last)
          function send() error('Unexpected gameplay dispatch') end
          function expandAlias() error('Unexpected alias dispatch') end
          t.abilityStore.select('Fixture')
          function ability(id,name)
            return {id=id,name=name or ('Ability '..id),kind='spell',level=50,learned=true,practice=100,
              cost=0,resource='mana',targeting='single',memberships={{role='damage',type='fire'}}}
          end
          t.abilityStore.replace({abilities={[10]=ability(10,'Éowyn <blue>'),[20]=ability(20,'Unknown cost')},ability_metadata={[0]={level=100}}})
          local r=t.abilityStore.get('abilities',20);r.cost=nil;t.abilityStore.put('abilities',20,r)
          Items=assert(loadstring(sources['item-state']))();items=Items.new()
          local bag=assert(Items.parse('42,MG,@Ra <bag>,60,11,0,-1,-1'))
          assert(items.replace('carried',{['42']=bag}))
          t.inventory.get=items.get;t.inventory.list=items.list
          t.inventory.status=function() local s=items.status();s.enabled=true;return s end
        ''')

    def test_reentrant_widget_creation_cannot_read_unregistered_placement(self):
        self.lua.execute('''
          assert(t.config.set('browser','enabled',false))
          local create=Geyser.Container.new;local observed=false
          function Geyser.Container:new(def,parent)
            if def.name=='AardwolfToolbox.browser.inventory.home' then
              observed=true;assert(not b.isEditing());fire('sysWindowResizeEvent')
            end
            return create(self,def,parent)
          end
          assert(t.config.set('browser','enabled',true))
          assert(observed and b.enabled and not t.config.runtimeErrors.browser,b.last)
          assert(b.open('inventory'))
        ''')

    def test_partial_construction_failure_cleans_up_and_retries(self):
        self.lua.execute('''
          assert(t.config.set('browser','enabled',false))
          local create=Geyser.ScrollBox.new
          function Geyser.ScrollBox:new(def,parent)
            if def.name=='AardwolfToolbox.browser.inventory.list' then error('Injected native constructor failure') end
            return create(self,def,parent)
          end
          t.config.set('browser','enabled',true)
          assert(not b.enabled and not b.isEditing())
          assert(t.config.runtimeErrors.browser:find('Injected native constructor failure',1,true))
          for name in pairs(widgets) do assert(not name:find('AardwolfToolbox.browser',1,true)) end
          assert(not t.views.available('inventory') and t.views.mode('inventory')==nil)
          Geyser.ScrollBox.new=create;assert(t.config.set('browser','enabled',true))
          assert(b.enabled and not t.config.runtimeErrors.browser and b.open('inventory'))
        ''')

    def test_external_resize_reflows_footer_and_menu_uses_external_host(self):
        self.lua.execute('''
          assert(t.views.setMode('abilities','floating'));assert(b.open('abilities'))
          local root=widgets['AardwolfToolbox.browser.abilities'];local window=root.parent
          window:resize(700,640);fire('sysUserWindowResizeEvent',700,640,window.name)
          local footer=widgets['AardwolfToolbox.browser.abilities.next']
          assert(footer.y==640-t.ui.metrics().height)
          t.views.menu('abilities');assert(widgets['AardwolfToolbox.views.menu'].parent==window)
        ''')

    def test_stored_abilities_details_zero_unknown_and_search(self):
        self.lua.execute('''
          assert(b.open('abilities'));assert(b.isEditing())
          local input=widgets['AardwolfToolbox.browser.abilities.search'];input.action('Éowyn')
          local row=widgets['AardwolfToolbox.browser.abilities.row.1']
          assert(row.text:find('&lt;blue&gt;',1,true) and row.text:find('0 mana',1,true))
          row.callback();local detail=widgets['AardwolfToolbox.browser.abilities.detail'].text
          assert(detail:find('cast 10',1,true) and detail:find('damage / fire',1,true))
          input.action('Unknown cost');widgets['AardwolfToolbox.browser.abilities.row.1'].callback()
          assert(widgets['AardwolfToolbox.browser.abilities.detail'].text:find('Cost -- mana',1,true))
          input.action('fire');assert(widgets['AardwolfToolbox.browser.abilities.row.2'])
          assert(widgets['AardwolfToolbox.browser.abilities.feedback'].text:find('stale'))
        ''')

    def test_items_literal_details_freshness_and_guarded_inspection(self):
        self.lua.execute('''
          assert(b.open('inventory'));widgets['AardwolfToolbox.browser.inventory.row.1'].callback()
          assert(widgets['AardwolfToolbox.browser.inventory.detail'].text:find('a &lt;bag&gt;',1,true))
          widgets['AardwolfToolbox.browser.inventory.inspect'].callback()
          assert(widgets['AardwolfToolbox.browser.inventory.feedback'].text:find('Disconnected'))
          t.readiness.check=function() return true end
          local calls=0;t.inventory.refresh=function(kind,id) calls=calls+1;assert(kind=='details' and id=='42');return true end
          widgets['AardwolfToolbox.browser.inventory.inspect'].callback();assert(calls==1)
          items.invalidate('carried');widgets['AardwolfToolbox.browser.inventory.inspect'].callback();assert(calls==1)
          assert(items.replace('carried',{}));widgets['AardwolfToolbox.browser.inventory.inspect'].callback();assert(calls==1)
        ''')

    def test_paging_bounded_widgets_stale_clicks_and_hidden_loading(self):
        self.lua.execute('''
          local rows={};for i=1,100 do rows[i]=ability(i) end;t.abilityStore.replace({abilities=rows})
          local list=t.abilities.list;local reads=0;t.abilities.list=function(...) reads=reads+1;return list(...) end
          fire('AardwolfToolbox.abilities.updated');assert(reads==0)
          assert(b.open('abilities'));assert(reads==1)
          assert(widgets['AardwolfToolbox.browser.abilities.row.24'] and not widgets['AardwolfToolbox.browser.abilities.row.25'])
          local click=widgets['AardwolfToolbox.browser.abilities.row.1'].callback
          widgets['AardwolfToolbox.browser.abilities.next'].callback();click()
          assert(widgets['AardwolfToolbox.browser.abilities.detail'].text=='Select a row for details.')
          b.close();assert(not widgets['AardwolfToolbox.browser.abilities.row.1'])
          reads=0;fire('AardwolfToolbox.abilities.updated');assert(reads==0)
        ''')

    def test_views_float_return_settings_and_cleanup(self):
        self.lua.execute('''
          assert(b.open('inventory'));local content=widgets['AardwolfToolbox.browser.inventory']
          assert(t.views.setMode('inventory','floating'));assert(content.parent~=widgets['AardwolfToolbox.browser.inventory.home'])
          t.views.menu('inventory');assert(widgetContaining('Return to workspace'))
          assert(t.views.setMode('inventory','tabbed'));assert(content.parent==widgets['AardwolfToolbox.browser.inventory.home'])
          assert(b.isEditing() and not widgets['AardwolfToolbox.browser'].hidden)
          t.views.menu('inventory');local settings
          for name,w in pairs(widgets) do if name:find('AardwolfToolbox.views.menu.',1,true) and w.text=='Settings' then settings=w end end
          assert(settings,'Missing view settings action');settings.callback();assert(t.settingsWindow.opened)
          assert(t.config.set('browser','enabled',false));assert(not b.enabled and not t.views.available('inventory'))
          assert(t.config.set('browser','enabled',true));assert(b.open('equipment'))
          t.stop();assert(count(widgets)==0);assert(t.start());assert(b.open('inventory'));t.stop();assert(count(widgets)==0)
        ''')

    def test_dashboard_toggle_preserves_workspace_and_failed_reads_recover(self):
        self.lua.execute('''
          assert(b.open('inventory'));assert(t.views.setMode('inventory','floating'))
          local content=widgets['AardwolfToolbox.browser.inventory'];local parent=content.parent
          assert(t.config.set('dashboard','enabled',false));assert(t.views.available('inventory'))
          assert(content.parent==parent and not parent.deleted)
          assert(t.config.set('dashboard','enabled',true));assert(content.parent==parent)
          local list=t.abilities.list;t.abilities.list=function() error('Database unavailable') end
          assert(b.open('abilities'))
          assert(widgets['AardwolfToolbox.browser.abilities.feedback'].text:find('Database unavailable'))
          t.abilities.list=list;widgets['AardwolfToolbox.browser.abilities.search'].action('')
          assert(widgets['AardwolfToolbox.browser.abilities.row.1'])
        ''')

    def test_smart_button_resolution_is_visible_without_dispatch(self):
        self.lua.execute('''
          local button={}
          for _,setting in ipairs(t.config.features.actions.settings) do
            if setting.key=='buttons' then for _,field in ipairs(setting.fields) do button[field.key]=field.default end end
          end
          button.id='fixture';button.label='Fire button';button.ability_mode='highest'
          button.ability_role='damage';button.ability_type='fire';button.ability_kind='both';button.ability_targeting='single'
          assert(t.config.set('actions','buttons',{button}))
          assert(b.open('abilities'));widgets['AardwolfToolbox.browser.abilities.search'].action('Éowyn')
          widgets['AardwolfToolbox.browser.abilities.row.1'].callback()
          assert(widgets['AardwolfToolbox.browser.abilities.detail'].text:find('Selected by button: Fire button',1,true))
        ''')

    def test_unchanged_inventory_events_and_geometry_do_not_render_rows(self):
        self.lua.execute('''
          assert(b.open('inventory'));local row=widgets['AardwolfToolbox.browser.inventory.row.1']
          local calls=0;row.echo=function() calls=calls+1 end
          fire('AardwolfToolbox.inventory.updated');fire('sysWindowResizeEvent')
          assert(calls==0 and widgets[row.name]==row)
          items.invalidate('carried');fire('AardwolfToolbox.inventory.updated')
          assert(widgets[row.name]~=row and widgets[row.name].text:find('Stale'))
        ''')

    def test_manual_item_menu_previews_once_and_invalidates_callbacks(self):
        self.lua.execute('''
          sent={};function send(command) sent[#sent+1]=command end
          t.readiness.check=function(policy) assert(policy=='manual');return true end
          assert(b.open('inventory'));widgets['AardwolfToolbox.browser.inventory.row.1'].callback()
          widgets['AardwolfToolbox.browser.inventory.actions'].callback()
          local action=widgets['AardwolfToolbox.browser.menu.row.1'];local callback=action.callback
          assert(action.text:find('wear 42',1,true) and #sent==0)
          callback();assert(#sent==1 and sent[1]=='wear 42');callback();assert(#sent==1)
          assert(items.get('42').location=='carried')
          widgets['AardwolfToolbox.browser.inventory.actions'].callback()
          callback=widgets['AardwolfToolbox.browser.menu.row.1'].callback
          items.clear();callback();assert(#sent==1)
          assert(widgets['AardwolfToolbox.browser.inventory.feedback'].text:find('changed'))
        ''')

    def test_manual_actions_setting_and_lifecycle_are_shared(self):
        self.lua.execute('''
          assert(b.open('inventory'));widgets['AardwolfToolbox.browser.inventory.row.1'].callback()
          widgets['AardwolfToolbox.browser.inventory.actions'].callback()
          local stale=widgets['AardwolfToolbox.browser.menu.row.1'].callback
          local draft,revision=t.config.draft();draft.browser.item_actions=false
          assert(t.config.apply(draft,revision));assert(not t.itemActions.enabled)
          assert(not widgets['AardwolfToolbox.browser.menu']);stale()
          widgets['AardwolfToolbox.browser.inventory.actions'].callback()
          assert(not widgets['AardwolfToolbox.browser.menu'])
          assert(t.config.set('browser','item_actions',true))
          widgets['AardwolfToolbox.browser.inventory.actions'].callback();assert(widgets['AardwolfToolbox.browser.menu'])
          t.stop();assert(count(widgets)==0 and not t.itemActions.enabled)
        ''')

    def test_comparison_is_local_and_float_menu_is_parented(self):
        self.lua.execute('''
          assert(items.replace('equipped',{['43']=assert(Items.parse('43,,helmet,55,7,0,4,-1'))}))
          assert(b.open('inventory'));widgets['AardwolfToolbox.browser.inventory.row.1'].callback()
          assert(t.views.setMode('inventory','floating'));assert(b.open('inventory'))
          widgets['AardwolfToolbox.browser.inventory.compare'].callback()
          local menu=widgets['AardwolfToolbox.browser.menu']
          assert(menu.parent==widgets['AardwolfToolbox.browser.inventory'])
          widgets['AardwolfToolbox.browser.menu.row.1'].callback()
          local text=widgets['AardwolfToolbox.browser.inventory.detail'].text
          assert(text:find('Level: 60 / 55 / +5',1,true))
          assert(text:find('Inspect both',1,true))
          assert(text:find('&lt;bag&gt;',1,true))
        ''')

    def test_many_container_choices_are_paged_and_escape_closes_only_menu(self):
        self.lua.execute('''
          local rows={}
          for id=1,60 do rows[tostring(id)]=assert(Items.parse(id..',,bag '..id..',1,11,0,-1,-1')) end
          assert(items.replace('carried',rows));assert(b.open('inventory'))
          widgets['AardwolfToolbox.browser.inventory.row.1'].callback()
          widgets['AardwolfToolbox.browser.inventory.actions'].callback()
          assert(widgets['AardwolfToolbox.browser.menu.row.24'] and not widgets['AardwolfToolbox.browser.menu.row.25'])
          widgets['AardwolfToolbox.browser.menu.page.3'].callback()
          assert(widgets['AardwolfToolbox.browser.menu.row.25'] and not widgets['AardwolfToolbox.browser.menu.row.1'])
          assert(count(keys)==1);for _,callback in pairs(keys) do callback() end
          assert(b.isEditing() and not widgets['AardwolfToolbox.browser.menu'])
        ''')
