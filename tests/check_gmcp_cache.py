"""Isolated cache contracts; no native GUI or player-profile fixtures."""
from pathlib import Path
import unittest
import zipfile
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]

class CacheTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute('''
          handlers={}; updates={}; gmcp={}
          function registerNamedEventHandler(owner,name,event,fn)
            handlers[name]={event=event,fn=fn}; return true
          end
          function deleteNamedEventHandler(owner,name) handlers[name]=nil end
          function raiseEvent(event,...) if event=="AardwolfToolbox.gmcp.updated" then updates[#updates+1]={event,...} end end
          function fire(event,...)
            for _,h in pairs(handlers) do if h.event==event then h.fn(event,...) end end
          end
          function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
        ''')
        with zipfile.ZipFile(ROOT/'build/AardwolfToolbox.mpackage') as z:
            factory=self.lua.execute(z.read('gmcp-cache.lua').decode())
        self.lua.globals().cache=factory.new(self.lua.globals())
        self.lua.execute('assert(cache.start())')

    def test_values_paths_and_defensive_copy(self):
        self.lua.execute('''
          gmcp.char={base={name='Tesobi',clan='',level=116},vitals={hp=0,mana=1255}}
          fire('gmcp.char','char.base'); fire('gmcp.char','gmcp.char.vitals')
          gmcp.comm={quest={status='ready'}}; fire('gmcp.comm','comm.quest')
          gmcp.group={reason='no group'}; fire('gmcp.group','group')
          gmcp.room={wrongdir='n'}; fire('gmcp.room','room.wrongdir')
          assert(cache.data.char.base.name=='Tesobi' and cache.get('char.base.clan')=='')
          assert(cache.get('gmcp.char.vitals.hp')==0 and cache.get('comm.quest.status')=='ready')
          assert(cache.get('group.reason')=='no group' and cache.get('room.wrongdir')=='n')
          local snapshot=cache.get(); snapshot.char.base.level=999
          gmcp.char.base.level=777
          assert(cache.get('char.base.level')==116 and #updates==5)
          assert(cache.get('char..base')==nil and cache.get('missing')==nil)
        ''')

    def test_replace_snapshot_and_reject_invalid(self):
        self.lua.execute('''
          gmcp.room={info={exits={n=1,s=2},future={flag=false}}}
          fire('gmcp.room','room.info'); assert(cache.get('room.info.future.flag')==false)
          gmcp.room.info={exits={n=1}}; fire('gmcp.room','room.info')
          assert(cache.get('room.info.exits.s')==nil)
          gmcp.room.info={num=0/0}; fire('gmcp.room','room.info')
          assert(cache.get('room.info.exits.n')==1)
          gmcp.room.info={}; gmcp.room.info.cycle=gmcp.room.info
          fire('gmcp.room','room.info'); assert(cache.get('room.info.exits.n')==1)
        ''')

    def test_reconnect_and_repeat_lifecycle(self):
        self.lua.execute('''
          assert(cache.start() and count(handlers)==8)
          gmcp.char={vitals={hp=12}}; fire('gmcp.char','char.vitals')
          fire('gmcp.char','char.vitals'); assert(#updates==1)
          local session=cache.session
          fire('sysDisconnectionEvent'); assert(cache.get('char')==nil and cache.session>session)
          fire('gmcp.char','char.vitals'); assert(cache.get('char')==nil)
          fire('sysConnectionEvent'); fire('gmcp.char','char.vitals'); assert(cache.get('char')==nil)
          gmcp.char.vitals={hp=13}; fire('gmcp.char','char.vitals'); assert(cache.get('char.vitals.hp')==13)
          fire('sysProtocolDisabled','GMCP'); assert(cache.get('char')==nil)
          fire('sysProtocolEnabled','GMCP')
          gmcp.char.vitals={hp=14}; fire('gmcp.char','char.vitals'); assert(cache.get('char.vitals.hp')==14)
          cache.configure({enabled=false}); cache.destroy(); assert(count(handlers)==0 and next(cache.data)==nil)
          cache.configure({enabled=true}); assert(count(handlers)==8 and next(cache.data)==nil)
        ''')

    def test_registration_failure_cleanup(self):
        self.lua.execute('''
          cache.stop()
          registerNamedEventHandler=function() error('registration failed') end
          local ok=cache.start()
          assert(not ok and not cache.enabled and count(handlers)==0)
          assert(cache.last:find('registration failed',1,true))
        ''')
