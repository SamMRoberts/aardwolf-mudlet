import unittest
import check_package

class ASCIITests(unittest.TestCase):
    def setUp(self):
        check_package.PackageTests.setUp(self)
        self.lua.execute('AardwolfToolbox.start(); c=AardwolfToolbox.config; a=AardwolfToolbox.ascii; pane=widgets["AardwolfToolbox.ascii.console"]; root=widgets["AardwolfToolbox.ascii.window"]')

    def test_frames_literal_colors_and_shared_capture(self):
        self.lua.execute('''
          assert(a.enabled and pane.text=='Waiting for map\\n' and count(triggers)==1)
          incoming('outside <MAPSTART>'); incoming('  <MAPSTART> ')
          incoming('Academy'); incoming(''); incoming('  |< .|   '); incoming('{not-a-tag}')
          assert(pane.text=='Waiting for map\\n')
          incoming(' <MAPEND> ')
          assert(pane.text=='Academy\\n\\n  |< .|   \\n{not-a-tag}\\n')
          assert(#visible==1 and gagCount==6 and #AardwolfToolbox.tags.recent()==0)
          assert(pane.runs[1].fg[1]==255 and pane.runs[2].fg[1]==40 and pane.runs[1].bg[1]==10)
          local old=pane.text
          incoming('<MAPSTART>'); incoming('unfinished'); assert(pane.text==old)
          incoming('<MAPSTART>'); incoming('new'); incoming('<MAPEND>'); assert(pane.text=='new\\n')
          incoming('<MAPEND>'); assert(pane.text=='new\\n')
          incoming('{record}data'); assert(AardwolfToolbox.tags.latest('record'))
          c.set('tags','enabled',false); incoming('<MAPSTART>'); incoming('independent'); incoming('<MAPEND>')
          assert(pane.text=='independent\\n' and count(triggers)==1)
        ''')

    def test_abort_disable_reconnect(self):
        self.lua.execute('''
          incoming('<MAPSTART>'); incoming('complete'); incoming('<MAPEND>')
          incoming('<MAPSTART>'); incoming('partial'); expire()
          incoming('visible'); assert(visible[#visible]=='visible' and pane.text=='complete\\n')
          incoming('<MAPSTART>'); incoming(string.rep('x',262145)); incoming('after limit')
          assert(visible[#visible]=='after limit' and pane.text=='complete\\n')
          incoming('<MAPSTART>'); for i=1,257 do incoming('row') end
          incoming('after rows'); assert(visible[#visible]=='after rows')
          fire('sysDisconnectionEvent'); assert(pane.text=='Waiting for map\\n')
          incoming('<MAPSTART>'); incoming('partial'); fire('sysConnectionEvent')
          incoming('visible again'); assert(visible[#visible]=='visible again')
          assert(c.set('ascii','enabled',false)); incoming('<MAPSTART>'); incoming('normal'); incoming('<MAPEND>')
          assert(visible[#visible]=='<MAPEND>' and not a.enabled)
          assert(a.open() and a.enabled)
        ''')

    def test_docking_vitals_and_external_reservations(self):
        self.lua.execute('''
          local vh=AardwolfToolbox.ui.metrics().height+10; assert(borderBottom==vh)
          for _,edge in ipairs({'bottom','left','right','top','floating'}) do
            assert(c.set('ascii','dock',edge)); assert(a.enabled and AardwolfToolbox.vitals.enabled)
          end
          assert(borderBottom==vh and borderLeft==0 and borderRight==300 and borderTop==AardwolfToolbox.ui.metrics().height)
          assert(c.set('ascii','dock','bottom')); assert(borderBottom==vh+c.get("ascii","height"))
          assert(widgets['AardwolfToolbox.vitals.root'].y==800-vh)
          assert(c.set('ascii','enabled',false)); assert(borderBottom==vh)
          a.open(); c.set('ascii','dock','right'); borderRight=75
          c.set('ascii','enabled',false); assert(borderRight==75 and borderBottom==vh)
          AardwolfToolbox.stop(); assert(borderBottom==0 and borderRight==75 and count(widgets)==0)
        ''')

    def test_drag_atomic_stale_lock_and_failure(self):
        self.lua.execute('''
          root.adjLabel.callback({button='LeftButton',x=50,y=10,globalX=100,globalY=100})
          root.adjLabel.moveCallback({globalX=130,globalY=140}); root.adjLabel.releaseCallback()
          assert(c.get('ascii','x')==70 and c.get('ascii','y')==180)
          c.set('ascii','locked',true)
          root.adjLabel.callback({button='LeftButton',x=50,y=10,globalX=0,globalY=0})
          root.adjLabel.moveCallback({globalX=500,globalY=500}); root.adjLabel.releaseCallback()
          assert(root.x==70 and root.y==180)
          c.set('ascii','locked',false)
          root.adjLabel.callback({button='LeftButton',x=50,y=10,globalX=0,globalY=0})
          c.set('vitals','show_tnl',false)
          root.adjLabel.moveCallback({globalX=50,globalY=50}); root.adjLabel.releaseCallback()
          assert(c.get('ascii','x')==70 and root.x==70)
          fileFailures.rename=true
          root.exitLabel.callback(); assert(a.enabled and c.get('ascii','enabled'))
          fileFailures.rename=nil; root.exitLabel.callback(); assert(not a.enabled)
        ''')

    def test_saved_geometry_reload_and_window_clamp(self):
        self.lua.execute('''
          local d,r=c.draft(); d.ascii.x=9999; d.ascii.y=9999; d.ascii.width=500; d.ascii.height=400
          assert(c.apply(d,r)); assert(root.x==700 and root.y==400)
          AardwolfToolboxLifecycle('sysUninstallPackage','AardwolfToolbox')
        ''')
        self.lua.execute(self.script)
        self.lua.execute('''
          AardwolfToolbox.start(); local r=widgets['AardwolfToolbox.ascii.window']
          assert(r.x==700 and r.y==400 and r.width==500)
          windowWidth=600; windowHeight=500; fire('sysWindowResizeEvent')
          assert(r.x==100 and r.y==100)
          assert(AardwolfToolbox.vitals.enabled)
        ''')

    def test_failed_activation_and_snapshot_leave_output_visible(self):
        self.lua.execute('''
          c.set('ascii','enabled',false)
          local original=Geyser.MiniConsole.new
          Geyser.MiniConsole.new=function() error('native console failed') end
          assert(c.set('ascii','enabled',true))
          assert(not a.enabled and a.last:find('native console failed',1,true))
          incoming('<MAPSTART>'); incoming('visible'); incoming('<MAPEND>')
          assert(visible[#visible]=='<MAPEND>')
          Geyser.MiniConsole.new=original; assert(a.open())
          selectSection=function() error('selection failed') end
          incoming('<MAPSTART>'); incoming('visible failure'); incoming('after failure')
          assert(not a.enabled and visible[#visible]=='after failure')
          assert(visible[#visible-1]=='visible failure')
          assert(AardwolfToolbox.tags.enabled and AardwolfToolbox.vitals.enabled)
        ''')

    def test_settings_abort_partial_without_replacing_map(self):
        self.lua.execute('''
          incoming('<MAPSTART>'); incoming('old'); incoming('<MAPEND>')
          incoming('<MAPSTART>'); incoming('partial')
          assert(c.set('ascii','capture_timeout',2))
          incoming('visible now'); assert(visible[#visible]=='visible now' and pane.text=='old\\n')
          incoming('<MAPSTART>'); incoming('new'); incoming('<MAPEND>')
          assert(pane.text=='new\\n')
          assert(not c.set('appearance','reading_size',25) and not c.set('ascii','capture_timeout',0))
          local draft,revision=c.draft(); a.open()
          assert(c.set('ascii','locked',true)); draft.appearance.reading_size=18
          assert(not c.apply(draft,revision)); assert(c.get('appearance','reading_size')==13)
        ''')

    def test_context_menu_opens_ascii_settings(self):
        self.lua.execute("""
          root.adjLabel.actions['Capture timeout...']()
          assert(AardwolfToolbox.settingsWindow.opened)
          assert(widgetContaining('Capture timeout (seconds)'))
          root.adjLabel.actions['Position / size...']()
          assert(widgetContaining('Floating X (pixels)'))
          AardwolfToolbox.stop(); assert(count(widgets)==0)
        """)
