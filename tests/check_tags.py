"""Exercise serialized tag capture; native trigger matching is checked separately."""
from pathlib import Path
import unittest
import zipfile
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]

class TagsTests(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime()
        for name in ('mapper_api.lua','settings_api.lua','tags_api.lua'):
            self.lua.execute((ROOT/'tests'/name).read_text())
        with zipfile.ZipFile(ROOT/'build/AardwolfToolbox.mpackage') as archive:
            self.lua.globals().source=archive.read('tags.lua').decode()
        self.lua.execute('''
          tags=assert(loadstring(source))().new(_G)
          prefs={enabled=true,suppress=true,block_timeout=10}
          assert(tags.configure(prefs))
        ''')

    def test_inventory_records_and_empty_fields(self):
        self.lua.execute('''
          incoming('{invdetails}')
          incoming('{invheader}156419934|9|Weapon|60|5|wield|v3||||||')
          incoming('{weapon}mace|12|pound|Bash|')
          incoming('{statmod}Damage roll|1'); incoming('{statmod}Strength|2')
          incoming('{skillmod}204|2'); incoming('{/invdetails}')
          assert(gagCount==7 and #visible==0)
          local b=lastBlock(); assert(b.status=='complete' and #b.contents==7)
          assert(b.contents[4].fields[1]=='Damage roll' and b.contents[5].fields[1]=='Strength')
          assert(#b.contents[2].fields==13 and b.contents[2].fields[13]=='')
          assert(tags.latest('weapon').fields[5]=='')
          assert(tags.latest('statmod').payload=='Strength|2')
          local r=tags.recent(2); assert(#r==2 and r[1].name=='skillmod' and r[2].kind=='close')
          b.contents[2].fields[1]='mutated'; assert(lastBlock().contents[2].fields[1]=='156419934')
        ''')

    def test_generic_nested_blocks_and_visible_prose(self):
        self.lua.execute('''
          incoming('chat says {example}'); incoming('{bad.name}x'); incoming('plain')
          incoming('  {Future-tag_2 12345}'); incoming('description'); incoming('')
          incoming('{child}'); incoming('{x}0||'); incoming('{/child}')
          local child=lastBlock(); assert(child.parentId and #child.contents==3)
          incoming('{/Future-tag_2}')
          local outer=lastBlock(); assert(outer.arguments=='12345' and #outer.contents==7)
          assert(outer.contents[2].kind=='text' and outer.contents[3].line=='')
          assert(child.parentId==outer.id)
          incoming('visible again'); assert(#visible==4 and visible[4]=='visible again')
          assert(count(timers)==0)
        ''')

    def test_malformed_and_mismatched_closing(self):
        self.lua.execute('''
          incoming('{/orphan}'); assert(tags.latest('orphan').blockId==nil)
          incoming('{open}'); incoming('{inner}'); incoming('{/open}')
          assert(lastBlock().status=='incomplete' and lastBlock().reason=='mismatched closing tag')
          assert(#output==1); incoming('after mismatch'); assert(visible[1]=='after mismatch')
          incoming('{/bad}payload'); incoming('{9bad}'); incoming('{broken')
          assert(#visible==4)
        ''')

    def test_timeout_settings_and_capture_without_suppression(self):
        self.lua.execute('''
          incoming('{slow}'); incoming('body'); expire()
          assert(lastBlock().reason=='timeout' and #output==1)
          incoming('after timeout'); assert(visible[1]=='after timeout')
          incoming('{changed}'); prefs.suppress=false; assert(tags.configure(prefs)); flushEvents()
          assert(lastBlock().reason=='settings changed' and count(timers)==0)
          incoming('{new}'); incoming('still visible'); incoming('{/new}')
          assert(lastBlock().status=='complete' and #visible==4)
        ''')

    def test_size_line_and_depth_limits(self):
        self.lua.execute('''
          for i=1,16 do incoming('{b'..i..'}') end
          incoming('{tooDeep}'); assert(lastBlock().reason=='nesting limit')
          incoming('visible'); assert(visible[2]=='visible')
          incoming('{large}'); incoming(string.rep('a',1048576))
          assert(lastBlock().reason=='size limit')
          incoming('{lines}'); for i=1,4095 do incoming('') end
          incoming('limit line'); assert(lastBlock().reason=='size limit')
          assert(#lastBlock().contents==4096)
        ''')

    def test_retention_limits_and_copy_isolation(self):
        self.lua.execute('''
          incoming('{first}x'); local first=tags.latest('first')
          for i=1,501 do incoming('{reading}'..i) end
          assert(tags.getRecord(first.id)==nil and #tags.recent()==500)
          assert(tags.latest('first')==nil and first.payload=='x')
          incoming('{block}'); incoming('{/block}'); local firstBlock=lastBlock().id
          for i=1,100 do incoming('{block}'); incoming('{/block}') end
          assert(tags.getBlock(firstBlock)==nil)
          local saved=tags.latest('reading'); if saved then saved.payload='changed' end
          incoming('{big}'..string.rep('x',600000)); local old=tags.latest('big').id
          for i=1,4 do incoming('{big}'..string.rep('x',600000)) end
          assert(tags.getRecord(old)==nil and #tags.latest('big').payload==600000)
        ''')

    def test_disconnect_stop_recompile_and_registration_failure(self):
        self.lua.execute('''
          incoming('{one}x'); local old=tags.latest('one'); incoming('{unfinished}')
          assert(tags.start()); assert(count(triggers)==1 and count(handlers)==2)
          fire('sysDisconnectionEvent'); assert(#tags.recent()==0 and count(timers)==0)
          incoming('visible'); assert(visible[1]=='visible')
          fire('sysConnectionEvent'); incoming('{new}x')
          assert(tags.latest('new').session~=old.session and tags.getRecord(old.id)==nil)
          tags.stop(); tags.destroy(); assert(count(triggers)==0 and count(handlers)==0 and count(timers)==0)
          triggerFailure=true; assert(not tags.start()); assert(not tags.enabled)
          triggerFailure=false; failNext('registerNamedEventHandler')
          assert(not tags.start() and count(triggers)==0 and count(handlers)==0)
        ''')

    def test_absolute_deadline_and_deferred_notification_cleanup(self):
        self.lua.execute('''
          incoming('{outer}'); local id,fn=next(timers)
          incoming('progress'); incoming('{inner}'); incoming('{/inner}')
          assert(timers[id]==fn and count(timers)==1)
          local flush=flushEvents; flushEvents=function() end
          incoming('{later}data'); local events=#tagEvents
          tags.stop(); flush(); assert(#tagEvents==events and count(timers)==0)
          assert(tags.start()); local delivered=0
          consumer=function(_,recordId) assert(tags.getRecord(recordId)); delivered=delivered+1 end
          for i=1,501 do incoming('{record}'..i) end
          assert(delivered==0 and #tags.recent()==500)
          flush(); assert(delivered==500)
        ''')

    def test_gag_precedes_consumers_and_consumer_can_stop(self):
        self.lua.execute('''
          consumer=function(name,id)
            if name=='AardwolfToolbox.tags.record' then
              assert(#visible==0); assert(tags.getRecord(id))
              visible[#visible+1]='consumer output'
            end
          end
          incoming('{record}payload'); assert(visible[1]=='consumer output')
          consumer=function() tags.stop() end
          incoming('{open}'); assert(not tags.enabled and count(timers)==0)
        ''')

if __name__=='__main__': unittest.main()
