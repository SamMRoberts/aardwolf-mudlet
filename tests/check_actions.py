"""Action, navigation and structured editor contracts against the built package."""
from pathlib import Path
import unittest
import check_package
ROOT=Path(__file__).resolve().parents[1]

class ActionTests(unittest.TestCase):
    def setUp(self):
        check_package.PackageTests.setUp(self)
        self.lua.execute('''
          sent={}; aliasSent={}; keys={}; keySequence=0; connected=true
          mudlet={key={},keymodifier={Control=1,Alt=2,Shift=4,Meta=8,Keypad=16}}
          for i=1,24 do mudlet.key['F'..i]=100+i end
          for i=65,90 do mudlet.key[string.char(i)]=i end
          for i=0,9 do mudlet.key[tostring(i)]=48+i end
          function tempKey(mod,key,fn)
            if keyFailure then return -1 end
            keySequence=keySequence+1; keys[keySequence]={mod=mod,key=key,fn=fn}; return keySequence
          end
          function killKey(id) keys[id]=nil end
          function disableKey(id) keys[id].disabled=true end
          function enableKey(id) keys[id].disabled=false end
          function getConnectionInfo() return 'test',0,connected end
          function send(s) sent[#sent+1]=s; return true end
          function expandAlias(s) aliasSent[#aliasSent+1]=s; return true end
          local originalRaise=raiseEvent
          function raiseEvent(event,...) originalRaise(event,...); fire(event,...) end
          AardwolfToolbox.start(); c=AardwolfToolbox.config; bar=AardwolfToolbox.actionBar
          function action(id,command,key)
            return {id=id,label='Éowyn <Heal>',tooltip='literal',enabled=true,command=command or 'heal',mode='command',key=key or '',ctrl=false,alt=false,shift=false,meta=false}
          end
          function ready(state)
            gmcp=gmcp or {}; gmcp.char={status={state=state or 3}}; fire('gmcp.char','gmcp.char.status')
          end
          function button(text) for _,w in pairs(widgets) do if w.text==text and not w.hidden then return w end end end
        ''')

    def test_dispatch_guards_alias_and_input_preservation(self):
        self.lua.execute('''
          local r=action('heal','say Héllo <red>; punctuation'); assert(c.set('actions','buttons',{r}))
          assert(not bar.activate('heal') and #sent==0)
          ready(); assert(bar.activate('heal')); assert(sent[#sent]==r.command)
          r.mode='alias'; assert(c.set('actions','buttons',{r})); assert(bar.activate('heal') and aliasSent[1]==r.command)
          for _,state in ipairs({3,4,8,9,11}) do ready(state); assert(bar.activate('heal')) end
          for _,state in ipairs({1,2,5,6,7,99}) do ready(state); assert(not bar.activate('heal')) end
          ready(); connected=false; assert(not bar.activate('heal')); connected=true
          r.enabled=false; assert(c.set('actions','buttons',{r})); assert(not bar.activate('heal'))
          r.enabled=true; r.command='say one\\nsay two'; assert(not c.set('actions','buttons',{r}))
          assert(not bar.activate('missing'))
          -- Dispatch APIs never touch the command input buffer.
          assert(not commandLineChanged)
        ''')

    def test_shortcuts_all_pages_suspend_duplicates_cleanup(self):
        self.lua.execute('''
          local list={}; for i=1,25 do list[i]=action('a_'..i,'command '..i,i==25 and 'F8' or '') end
          assert(c.set('actions','buttons',list)); ready(); assert(#bar.pages>1 and count(keys)==1)
          local key; for _,v in pairs(keys) do key=v end
          key.fn(); assert(sent[#sent]=='command 25')
          AardwolfToolbox.openSettings(); assert(key.disabled); local n=#sent; key.fn(); assert(#sent==n)
          AardwolfToolbox.settingsWindow.close(); assert(not key.disabled); key.fn(); assert(#sent==n+1)
          list[1].key='F8'; assert(not c.set('actions','buttons',list) and count(keys)==1)
          list[1].key='A'; assert(not c.set('actions','buttons',list))
          list[1].ctrl=true; assert(c.set('actions','buttons',list) and count(keys)==2)
          local draft,rev=c.draft(); draft.actions.bindings[1].key='F8'; assert(not c.apply(draft,rev))
          assert(c.set('actions','keys_enabled',false) and count(keys)==0)
          assert(c.set('actions','keys_enabled',true)); local callback=key.fn
          local n=#sent; bar.stop(); callback(); assert(#sent==n and count(keys)==0)
          bar.start(); assert(bar.enabled and count(keys)==2); AardwolfToolbox.stop(); assert(count(keys)==0 and count(widgets)==0)
        ''')

    def test_records_copy_persistence_validation_and_activation_failure(self):
        self.lua.execute('''
          assert(c.set('actions','buttons',{action('a','bash','F1')}))
          local get=c.get('actions','buttons'); get[1].command='wrong'; assert(c.get('actions','buttons')[1].command=='bash')
          local d,r=c.draft(); d.actions.buttons[1].command='draft'; assert(c.get('actions','buttons')[1].command=='bash')
          fileFailures.write=true; assert(not c.apply(d,r)); fileFailures.write=nil
          assert(c.get('actions','buttons')[1].command=='bash')
          assert(c.apply(d,r)); d.actions.buttons[1].command='mutated'; assert(c.get('actions','buttons')[1].command=='draft')
          local stored=yajl.to_value(files[c.path]); assert(stored.version==2 and stored.values.actions.buttons[1].id=='a')
          keyFailure=true; assert(c.set('actions','keys_enabled',false)); assert(c.set('actions','keys_enabled',true))
          assert(not bar.enabled and count(keys)==0 and c.runtimeErrors.actions)
          keyFailure=nil; bar.start(); assert(bar.enabled)
          local list={}; for i=1,49 do list[i]=action('a_'..i) end; assert(not c.set('actions','buttons',list))
          assert(not c.set('actions','buttons',{action('a'),action('a')}))
        ''')

    def test_record_editor_apply_cancel_duplicate_move_and_stale(self):
        self.lua.execute('''
          AardwolfToolbox.openSettings(); local w=AardwolfToolbox.settingsWindow
          w.editRecord('actions','buttons',nil,true)
          assert(not w.apply()) -- command is required; draft remains editable
          local input=widgetContaining('New button'); input.text='Heal'
          local empty; for _,v in pairs(widgets) do if v.action and v.text=='' then empty=v end end
          -- Target the command editor by its ordered neighbor: use the final empty input (tooltip precedes command).
          local max=0; for _,v in pairs(widgets) do if v.action and v.text=='' then local n=tonumber(v.name:match('input(%d+)$')); if n>max then empty=v; max=n end end end
          empty.text='heal'; empty.action('heal'); assert(w.apply())
          assert(c.get('actions','buttons')[1].label=='Heal')
          widgetContaining('Duplicate').callback(); assert(w.apply() and #c.get('actions','buttons')==2)
          widgetContaining('Move up').callback(); assert(w.apply()); assert(c.get('actions','buttons')[1].id=='button_2')
          widgetContaining('Delete').callback(); w.close(); assert(#c.get('actions','buttons')==2)
          w.open(); w.select('actions'); w.restoreDefaults(); w.close(); assert(#c.get('actions','buttons')==2)
          w.open(); w.select('actions'); assert(c.set('actions','keys_enabled',false)); assert(not w.apply()); w.close()
        ''')

    def test_navigation_identity_and_map_readonly(self):
        self.lua.execute('''
          ready(); assert(bar.navigation.move('south') and sent[#sent]=='south')
          assert(#bar.navigation.otherExits()==0)
          packet(123,{n=124}); fire('gmcp.room','gmcp.room.info')
          local id=localID(123); assert(id>0)
          function getSpecialExitsSwap(room) return {['enter hole']=125,['climb ladder']=126,['bad\\ncommand']=127} end
          function getDoors(room) return {north=2} end
          local original=getRoomExits; function getRoomExits(room) local exits=original(room); exits.northeast=128; return exits end
          local identity=bar.navigation.identity(); assert(#bar.navigation.otherExits()==3)
          assert(bar.navigation.special('enter hole',identity) and sent[#sent]=='enter hole')
          assert(bar.navigation.door('unlock','iron gate',identity) and sent[#sent]=='unlock iron gate')
          assert(not bar.navigation.special('invented',identity))
          local writesBefore=writes
          assert(c.set('mapper','enabled',false)); assert(#bar.navigation.otherExits()==3)
          bar.openMenu('doors'); assert(widgets['AardwolfToolbox.actionBar.menu'])
          gmcp.room={info={num=999,exits={}}}; fire('gmcp.room','gmcp.room.info')
          assert(not widgets['AardwolfToolbox.actionBar.menu'])
          assert(not bar.navigation.door('open','north',identity)); assert(writes==writesBefore)
          assert(#bar.navigation.otherExits()==0)
        ''')

    def test_layout_retains_widgets_and_border_cleanup(self):
        self.lua.execute('''
          assert(bar.enabled); local root=widgets['AardwolfToolbox.actionBar.root']
          local vh=AardwolfToolbox.ui.metrics().height+10; local bh=AardwolfToolbox.ui.metrics().height*3+16
          assert(root.x==0 and root.width==1200 and root.y==800-vh-bh)
          assert(AardwolfToolbox.borders.fullWidthBottom()==vh+bh)
          local north=widgets['AardwolfToolbox.actionBar.north']; local n=count(widgets)
          bar.start(); assert(widgets['AardwolfToolbox.actionBar.north']==north and count(widgets)==n)
          windowWidth=600; windowHeight=500; fire('sysWindowResizeEvent')
          assert(widgets['AardwolfToolbox.actionBar.navigate'] and north.hidden)
          assert(c.set('actions','enabled',false)); assert(borderBottom==vh)
          assert(c.set('actions','enabled',true)); assert(borderBottom==vh+AardwolfToolbox.ui.metrics().height+8)
        ''')
