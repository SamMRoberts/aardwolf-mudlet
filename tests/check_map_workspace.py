"""Local map workspace contracts; never invokes native travel or map writers."""
import unittest
import check_package


class MapWorkspaceTests(unittest.TestCase):
    def setUp(self):
        harness = check_package.PackageTests()
        harness.setUp()
        self.addCleanup(harness.doCleanups)
        self.lua = harness.lua
        self.lua.execute('''
          assert(AardwolfToolbox.start());t=AardwolfToolbox;m=t.mapWorkspace;p=t.mapWorkspacePane
          assert(m.enabled,m.last);assert(p.enabled,p.last)
          packet(101,{n=102});packet(102,{e=103});packet(103,{})
          beforeWrites=writes
          function send() error('Unexpected gameplay dispatch') end
          function expandAlias() error('Unexpected alias dispatch') end
          function gotoRoom() error('Unexpected travel') end
          function W(name) return assert(widgets['AardwolfToolbox.mapWorkspacePane.'..name],name) end
          function choose(id) W('search'):print(tostring(id));W('search').action();W('row.1').callback() end
          function note(label,value) W('bookmarkLabel'):print(label);W('note'):print(value);W('save').callback() end
          a=m.get(101);b=m.get(103)
          function getPath()
            speedWalkPath={102,103};speedWalkDir={'n','e'};speedWalkWeight={1,1};return true,2
          end
        ''')

    def test_search_room_area_paging_unknown_and_defensive_copies(self):
        self.lua.execute('''
          rooms[101].name='Éowyn <fountain>';areas={academy=1};rooms[101].area=1
          local r=assert(m.search('Éowyn','rooms',1));assert(r.total==1 and r.rows[1].id==101)
          assert(m.search('academy','areas',1).total>=1)
          r.rows[1].exits.north=999;assert(m.get(101).exits.north==102)
          assert(m.get(999)==nil and m.search('x','bad')==nil)
          for i=200,230 do rooms[i]={name='Extra',area=1,data={},exits={},x=i,y=0,z=0} end
          r=m.search('Extra','rooms',1);assert(#r.rows==24 and r.total==31 and r.pages==2)
          assert(#m.search('Extra','rooms',2).rows==7)
          assert(writes==beforeWrites)
        ''')

    def test_bookmark_notes_apply_stale_failure_reload_and_identity(self):
        self.lua.execute('''
          local rev=t.config.revision
          assert(m.save(101,a.identity,'Home <safe>','A note',rev))
          assert(not m.save(103,b.identity,'Next','stale',rev))
          local list=m.bookmarks();list[1].note='mutated';assert(m.bookmarks()[1].note=='A note')
          fileFailures.rename=true
          assert(not m.save(101,a.identity,'Changed','new',t.config.revision))
          assert(m.bookmarks()[1].label=='Home <safe>');fileFailures.rename=nil
          assert(not m.save(101,a.identity,'','',t.config.revision))
          assert(not m.save(101,a.identity,'x','bad\\nline',t.config.revision))
          t.stop();assert(t.start());m=t.mapWorkspace
          assert(m.bookmarks()[1].available and m.bookmarks()[1].note=='A note')
          rooms[101].hash='replacement';assert(not m.bookmarks()[1].available)
          assert(not m.save(101,a.identity,'Home','',t.config.revision,true))
          assert(writes==beforeWrites)
        ''')

    def test_preview_restores_globals_special_and_provisional_steps(self):
        self.lua.execute('''
          local path,dirs,weight={42},{'w'},{7}
          speedWalkPath,speedWalkDir,speedWalkWeight=path,dirs,weight
          local r=assert(m.preview(101,103,a.identity,b.identity))
          assert(#r.steps==2 and r.cost==2 and r.steps[1].to==102)
          assert(speedWalkPath==path and speedWalkDir==dirs and speedWalkWeight==weight)
          r.steps[1].to=999;assert(m.preview(101,103,a.identity,b.identity).steps[1].to==102)
          rooms[101].exits={};rooms[101].special={['enter <hole>']=102}
          rooms[102].data['AardwolfToolbox:discovery']='unexplored'
          getPath=function() speedWalkPath={102,103};speedWalkDir={'enter <hole>','e'};return true,8 end
          r=assert(m.preview(101,103,a.identity,b.identity));assert(r.steps[1].special and r.steps[1].unexplored)
          assert(speedWalkPath==path and speedWalkDir==dirs and speedWalkWeight==weight)
          assert(writes==beforeWrites)
        ''')

    def test_preview_errors_no_route_changes_and_current_identity(self):
        self.lua.execute('''
          speedWalkDir={'original'};local original=speedWalkDir
          getPath=function() speedWalkDir={'changed'};error('Injected failure') end
          assert(not m.preview(101,103,a.identity,b.identity) and speedWalkDir==original)
          getPath=function() return false end;assert(not m.preview(101,103,a.identity,b.identity))
          getPath=function() speedWalkDir={'n','e'};speedWalkPath={102,103};rooms[101].exits={};return true end
          assert(not m.preview(101,103,a.identity,b.identity))
          assert(not m.preview(101,103,'old identity',b.identity))
          assert(#m.preview(101,101,a.identity,a.identity).steps==0)
          assert(not m.current())
          t.gmcp.enabled=true;t.gmcp.get=function(path) if path=='room.info.num' then return 101 end end
          getConnectionInfo=function() return 'fixture',0,true end
          assert(m.current().id==101)
          rooms[101].hash='foreign';assert(not m.current())
        ''')

    def test_health_read_only_categorized_bounded_and_missing_reverse_valid(self):
        self.lua.execute('''
          local report=assert(m.health());assert(report.issueCount==0 and report.rooms==3)
          rooms[101].exits.south=999
          rooms[102].hash='wrong'
          rooms[102].data['AardwolfToolbox:ready']='0'
          rooms[103].x=rooms[101].x;rooms[103].y=rooms[101].y
          report=m.health();assert(report.counts.dangling==1 and report.counts.identity==1 and report.counts.incomplete==1 and report.counts.overlap==1)
          for i=200,450 do rooms[i]={name='Extra',area=1,data={},exits={north=9999},x=i,y=0,z=0} end
          report=m.health();assert(#report.issues==200 and report.truncated and report.issueCount>200)
          assert(writes==beforeWrites)
        ''')

    def test_pane_local_edits_preview_lifecycle_and_stale_callbacks(self):
        self.lua.execute('''
          assert(p.open() and p.isEditing());choose(101)
          W('start').callback();choose(103);W('preview').callback()
          assert(W('detail').text:find('2 steps') and W('detail').text:find('Preview only'))
          note('Éowyn <safe>','Read-only note')
          assert(t.config.get('map_workspace','bookmarks')[1].note=='Read-only note')
          W('bookmarks').callback();W('search'):print('');W('search').action()
          assert(W('row.1').text:find('&lt;safe&gt;',1,true))
          local old=W('row.1').callback;p.close();old();assert(not p.isEditing())
          assert(p.open());assert(t.views.setMode('atlas','floating'))
          assert(W('content').parent~=W('home'))
          assert(t.views.setMode('atlas','tabbed'));assert(W('content').parent==W('home'))
          assert(p.isEditing() and not widgets['AardwolfToolbox.mapWorkspacePane'].hidden)
          assert(t.config.set('map_workspace','enabled',false));assert(not p.enabled and not m.enabled)
          assert(not widgets['AardwolfToolbox.mapWorkspacePane']);old()
          assert(t.config.set('map_workspace','enabled',true));assert(p.open())
          t.stop();assert(count(widgets)==0);assert(t.start());assert(t.mapWorkspace.bookmarks()[1].note=='Read-only note')
        ''')

    def test_editor_stale_draft_retained_failed_write_no_save_on_enter(self):
        self.lua.execute('''
          p.open();choose(101);W('note'):print('Keep draft');W('note').action()
          assert(#t.config.get('map_workspace','bookmarks')==0)
          assert(t.config.set('mapper','follow_room',false))
          W('save').callback();assert(W('feedback').text:find('Settings changed'))
          assert(W('note'):getText()=='Keep draft')
          choose(101);fileFailures.rename=true;note('Home','Draft on error')
          assert(W('feedback').text:find('Cannot replace settings'))
          assert(W('note'):getText()=='Draft on error')
        ''')

    def test_activation_failure_partial_cleanup_and_no_idle_map_reads(self):
        self.lua.execute('''
          assert(t.config.set('map_workspace','enabled',false))
          local create=Geyser.ScrollBox.new
          function Geyser.ScrollBox:new(def,parent)
            if def.name=='AardwolfToolbox.mapWorkspacePane.list' then error('Constructor failure') end
            return create(self,def,parent)
          end
          t.config.set('map_workspace','enabled',true)
          assert(not p.enabled and t.config.runtimeErrors.map_workspace:find('Constructor failure'))
          for name in pairs(widgets) do assert(not name:find('AardwolfToolbox.mapWorkspacePane',1,true)) end
          Geyser.ScrollBox.new=create;assert(t.config.set('map_workspace','enabled',true))
          local reads=0;getRooms=function() reads=reads+1;return {} end
          fire('sysWindowResizeEvent');fire('AardwolfToolbox.ui.changed');assert(reads==0)
          p.open();assert(reads>0)
        ''')

    def test_first_float_shows_new_host_and_scrolling_keeps_controls_accessible(self):
        self.lua.execute('''
          p.open();local create=Geyser.UserWindow.new
          local created
          function Geyser.UserWindow:new(def,parent)
            local w=create(self,def,parent)
            if not def.name:find('AardwolfToolbox.views.',1,true) then return w end
            w.hidden=true
            local show=w.show;w.shown=0
            function w:show() self.shown=self.shown+1;show(self) end
            created=w;return w
          end
          assert(t.views.setMode('atlas','floating'))
          assert(created and created.shown>0 and not created.hidden)
          created:resize(300,240);fire('sysUserWindowResizeEvent')
          assert(W('body'):get_height()==240)
          assert(W('save').parent==W('body') and W('save'):get_height()>=32)
          assert(W('rooms'):get_width()>=t.ui.measure('Rooms'))
          assert(t.views.setMode('atlas','tabbed'));assert(created.hidden)
          local count=created.shown;assert(t.views.setMode('atlas','floating'))
          assert(created.shown>count and not created.hidden)
          created:hide();assert(t.views.configure());assert(created.hidden)
        ''')
