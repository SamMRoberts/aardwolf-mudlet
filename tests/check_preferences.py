"""Preference transfer uses JSON data, draft validation and checked local backups."""
import unittest
import check_package


class PreferencesTests(unittest.TestCase):
    def setUp(self):
        harness = check_package.PackageTests()
        harness.setUp()
        self.addCleanup(harness.doCleanups)
        self.lua = harness.lua
        self.lua.execute('''
          assert(AardwolfToolbox.start());t=AardwolfToolbox;c=t.config
          function send() error('Unexpected gameplay dispatch') end
          function expandAlias() error('Unexpected alias dispatch') end
          function imported(values)
            local path='/fixture/preferences.json'
            files[path]=yajl.to_string({format='AardwolfToolbox-preferences',version=1,settingsVersion=3,values=values})
            return path
          end
          function prepare(values)
            local draft,rev=c.draft()
            return c.prepareImport(imported(values),draft,rev)
          end
          function contains(text)
            for _,w in pairs(widgets) do if type(w.text)=='string' and w.text:find(text,1,true) then return w end end
          end
        ''')

    def test_export_saved_defaults_unknowns_without_metadata_or_draft(self):
        self.lua.execute('''
          assert(c.setMetadata('borderOwnership',{private='keep local'}))
          local draft,review=prepare({future={value='unknown'},appearance={ui_size=15}})
          assert(c.applyImport(draft,review.revision,review.token))
          local path=assert(c.exportPreferences());local doc=yajl.to_value(files[path])
          assert(doc.format=='AardwolfToolbox-preferences' and doc.version==1 and doc.settingsVersion==3)
          assert(doc.values.future.value=='unknown' and doc.values.appearance.ui_size==15 and not doc.metadata)
          t.openSettings();t.settingsWindow.select('appearance')
          local sizeInput
          for name,w in pairs(widgets) do if name:find('AardwolfToolbox.settings.input',1,true) and w:getText()=='15' then sizeInput=w end end
          assert(sizeInput,'Missing font size editor');sizeInput:print('19')
          local second=assert(c.exportPreferences());assert(path~=second)
          assert(yajl.to_value(files[second]).values.appearance.ui_size==15)
          assert(files[path..'.tmp']==nil and c.getMetadata('borderOwnership').private=='keep local')
        ''')

    def test_preview_merge_validation_backups_and_unknown_retention(self):
        self.lua.execute('''
          assert(c.set('mapper','follow_room',false))
          local original=files[c.path];local rev=c.revision
          local draft,review=prepare({appearance={ui_size=15},future={switch=false},mapper={future_setting={a='b'}}})
          assert(#review.changes==1 and #review.unavailable==2 and c.revision==rev)
          assert(c.get('appearance','ui_size')==12 and files[c.path]==original)
          assert(draft.mapper.follow_room==false)
          review.changes[1].after=99
          assert(c.applyImport(draft,rev,review.token))
          assert(files[c.lastImportBackup]==original and c.get('appearance','ui_size')==15)
          local stored=yajl.to_value(files[c.path]);assert(stored.values.future.switch==false and stored.values.mapper.future_setting.a=='b')
          assert(c.set('appearance','ui_size',14));assert(yajl.to_value(files[c.path]).values.future.switch==false)
          assert(not c.applyImport(draft,c.revision,review.token))
        ''')

    def test_bad_versions_shapes_values_references_and_limits(self):
        self.lua.execute('''
          local draft,rev=c.draft();local original=files[c.path]
          for _,bytes in ipairs({'oops','{}',yajl.to_string({format='AardwolfToolbox-preferences',version=2,settingsVersion=3,values={}}),string.rep('x',1048577)}) do
            files['bad']=bytes;assert(not c.prepareImport('bad',draft,rev));assert(files['bad']==bytes)
          end
          assert(not prepare({appearance={ui_size=100}}))
          assert(not prepare({mobs={double_click='missing_action'}}))
          assert(not prepare({appearance={ui_font='bad\\nfont'}}))
          assert(not prepare({[string.rep('x',81)]={a=1}}))
          files['bad']=yajl.to_string({format='AardwolfToolbox-preferences',version=1,settingsVersion=3,values={},metadata={}})
          assert(not c.prepareImport('bad',draft,rev))
          assert(c.revision==rev and files[c.path]==original)
        ''')

    def test_backup_export_read_write_and_primary_failure_preserve_active(self):
        self.lua.execute('''
          assert(c.set('appearance','ui_size',13));local original=files[c.path]
          local draft,review=prepare({appearance={ui_size=15}})
          fileFailures.write=true;assert(not c.applyImport(draft,review.revision,review.token));assert(not c.exportPreferences());fileFailures.write=nil
          assert(files[c.path]==original and c.get('appearance','ui_size')==13)
          fileFailures.rename=true;assert(not c.applyImport(draft,review.revision,review.token));fileFailures.rename=nil
          local rename=os.rename
          os.rename=function(from,to) if to==c.path then return nil,'primary failure' end;return rename(from,to) end
          assert(not c.applyImport(draft,review.revision,review.token));assert(c.get('appearance','ui_size')==13)
          local backups=0;for path in pairs(files) do if path:find('before-import',1,true) and not path:find('.tmp',1,true) then backups=backups+1;assert(files[path]==original) end end
          assert(backups==1 and files[c.path]==original)
          os.rename=rename;assert(c.applyImport(draft,review.revision,review.token))
          for path in pairs(files) do assert(not path:match('%.tmp$')) end
        ''')

    def test_missing_preferences_backup_stale_preview_and_deactivate(self):
        self.lua.execute('''
          files[c.path]=nil
          local draft,review=prepare({appearance={ui_size=16}})
          assert(c.applyImport(draft,review.revision,review.token))
          assert(yajl.to_value(files[c.lastImportBackup]).version==3)
          assert(yajl.to_value(files[c.lastImportBackup]).values.appearance.ui_size==12)
          draft,review=prepare({appearance={ui_size=17}})
          assert(c.set('mapper','follow_room',false))
          assert(not c.applyImport(draft,review.revision,review.token) and c.get('appearance','ui_size')==16)
          draft,review=prepare({appearance={ui_size=18}});c.cancelImport(review.token)
          assert(not c.applyImport(draft,review.revision,review.token))
          draft,review=prepare({appearance={ui_size=18}});c.deactivate()
          assert(not c.applyImport(draft,review.revision,review.token))
        ''')

    def test_unknown_preferences_retained_across_second_import_and_metadata_changes(self):
        self.lua.execute('''
          local draft,review=prepare({future={one='one',two='two'}})
          assert(c.applyImport(draft,review.revision,review.token))
          draft,review=prepare({future={one='changed'}})
          assert(c.setMetadata('later',{value=true}))
          assert(c.applyImport(draft,review.revision,review.token))
          local saved=yajl.to_value(files[c.path])
          assert(saved.values.future.one=='changed' and saved.values.future.two=='two' and saved.metadata.later.value)
          assert(yajl.to_value(files[c.lastImportBackup]).metadata.later.value)
        ''')

    def test_ui_preview_cancel_apply_and_dialog_cancellation(self):
        self.lua.execute('''
          t.openSettings();local w=t.settingsWindow;w.select('preferences')
          local path=imported({appearance={ui_size=15},future={label='<literal>'}})
          assert(w.importFile(path));assert(c.get('appearance','ui_size')==12)
          assert(contains('Before: 12') and contains('After: 15') and contains('future.label'))
          w.close();assert(c.get('appearance','ui_size')==12 and not c.lastImportBackup)
          t.openSettings();w.select('preferences')
          invokeFileDialog=function() return '' end
          contains('Choose file to import').callback();assert(c.get('appearance','ui_size')==12)
          assert(w.importFile(path));assert(w.apply());assert(c.get('appearance','ui_size')==15 and c.lastImportBackup)
          assert(contains('Backup: '))
        ''')

    def test_ui_failed_or_stale_import_retains_pending_draft(self):
        self.lua.execute('''
          t.openSettings();local w=t.settingsWindow;w.select('preferences')
          assert(w.importFile(imported({appearance={ui_size=15}})))
          fileFailures.rename=true;assert(not w.apply());fileFailures.rename=nil
          assert(c.get('appearance','ui_size')==12);assert(w.apply());assert(c.get('appearance','ui_size')==15)
          assert(w.importFile(imported({appearance={ui_size=17}})))
          assert(c.set('appearance','ui_size',16));assert(not w.apply());assert(c.get('appearance','ui_size')==16)
          w.close();t.stop();assert(t.start());assert(c.get('appearance','ui_size')==16)
        ''')

    def test_disable_file_operations_and_post_save_activation_failure(self):
        self.lua.execute('''
          assert(c.set('preferences','enabled',false));assert(not c.exportPreferences());assert(not prepare({}))
          assert(c.set('preferences','enabled',true))
          local original=c.features.appearance.apply
          c.features.appearance.apply=function() return false,'Injected activation failure' end
          local draft,review=prepare({appearance={ui_size=15}})
          local ok,message=c.applyImport(draft,review.revision,review.token)
          assert(ok and message:find('activation needs attention') and c.get('appearance','ui_size')==15)
          assert(c.runtimeErrors.appearance=='Injected activation failure' and c.lastImportBackup)
          c.features.appearance.apply=original
        ''')

    def test_import_preview_updates_edits_limits_rows_and_failed_dialog_retains_plan(self):
        self.lua.execute('''
          t.openSettings();local w=t.settingsWindow;w.select('preferences')
          local fields={};for i=1,150 do fields['setting_'..i]=i end
          assert(w.importFile(imported({future=fields,appearance={ui_size=15}})))
          assert(contains('150 unavailable settings') and contains('first 100 entries'))
          local n=0;for name in pairs(widgets) do if name:find('importUnavailable',1,true) then n=n+1 end end;assert(n==100)
          invokeFileDialog=function() error('dialog error') end
          contains('Choose file to import').callback();assert(contains('Cannot open file chooser'))
          assert(w.apply());assert(c.get('appearance','ui_size')==15)
          local saved=yajl.to_value(files[c.path]);assert(saved.values.future.setting_150==150)
        ''')

    def test_read_close_flush_and_rename_exceptions_release_files(self):
        self.lua.execute('''
          local originalOpen=io.open
          local closed=0
          io.open=function(path,mode)
            if mode=='rb' and path=='/throw' then return {read=function() error('read failed') end,close=function() closed=closed+1;return true end} end
            return originalOpen(path,mode)
          end
          assert(not t.preferencesFiles.read('/throw') and closed==1)
          io.open=function(path,mode)
            local f=originalOpen(path,mode)
            if f and mode=='wb' then f.flush=function() return nil,'flush failed' end end
            return f
          end
          assert(not c.exportPreferences());io.open=originalOpen
          for path in pairs(files) do assert(not path:match('%.tmp$')) end
          local originalRename=os.rename
          os.rename=function() error('rename failed') end
          assert(not c.exportPreferences());os.rename=originalRename
          for path in pairs(files) do assert(not path:match('%.tmp$')) end
        ''')
