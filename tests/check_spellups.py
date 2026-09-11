"""Spell state and automation against the built Lua 5.1 resources."""
from pathlib import Path
import unittest
import zipfile
from lupa.lua51 import LuaRuntime
import check_package

ROOT = Path(__file__).resolve().parents[1]

class SpellTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute((ROOT/'tests/spells_api.lua').read_text())
        with zipfile.ZipFile(ROOT/'build/AardwolfToolbox.mpackage') as archive:
            for name in ('incoming', 'spells', 'spellup', 'tags'):
                self.lua.globals()[name.title()] = self.lua.execute(archive.read(name+'.lua').decode())
        self.lua.execute('''
          incoming=Incoming.new(_G); spells=Spells.new(_G,cache,incoming); controller=Spellup.new(_G,cache,spells)
          prefs={enabled=true,automatic_setup=true,auto_refresh=false,min_interval=30}
          assert(spells.configure(prefs)); assert(controller.configure(prefs)); advance(0)
        ''')

    def test_sequential_sync_default_no_cast_and_defensive_copies(self):
        self.lua.execute('''
          assert(commands[1]=='slist noprompt' and #commands==1 and packets[1]==string.char(7,1))
          synchronize(); assert(spells.isFresh() and #commands==4 and casts()==0)
          local s=spells.snapshot(); assert(s.active[1].name=='Éowyn <red>' and s.active[1].remaining==120)
          s.active[1].name='changed'; assert(spells.get(72).name=='Éowyn <red>')
          local r=spells.get(72); r.active.duration=9; assert(spells.get(72).active.duration==120)
          advance(5); assert(spells.snapshot().active[1].remaining==115)
          assert(gags==14 and #visible==0)
        ''')

    def test_interleaved_deltas_unknown_spells_and_zero(self):
        self.lua.execute('''
          spellRows(''); spellRows('spellup')
          feed('{spellheaders affected noprompt}'); feed('72,Éowyn <red>,2,100,100,-1,1')
          feed('{affoff}72'); feed('{affon}999,60'); feed('{/spellheaders}')
          feed('{recoveries noprompt}'); feed('1,Recovery,40'); feed('{recoff}1'); feed('{/recoveries}')
          assert(spells.isFresh()); assert(not spells.get(72).active)
          assert(spells.get(999).name=='Spell #999' and not spells.snapshot().recoveries[1])
          feed('{affon}35,0'); assert(spells.get(35).active.duration==0)
          assert(spells.snapshot().active[1].awaiting)
        ''')

    def test_filtered_user_lists_never_remove_unlisted_effects(self):
        self.lua.execute('''
          synchronize(); feed('{affon}35,100')
          feed('{spellheaders affected spellup noprompt}'); feed('72,Name,2,30,100,-1,1'); feed('{/spellheaders}')
          assert(spells.get(35).active and spells.get(72).active.duration==120)
          feed('{spellheaders spellup learned noprompt}'); feed('72,Name,2,0,100,-1,1'); feed('{/spellheaders}')
          assert(spells.get(35).spellup)
          feed('{spellheadersUnexpected}'); assert(visible[#visible]=='{spellheadersUnexpected}')
        ''')

    def test_expiry_requests_confirmation_not_cast(self):
        self.lua.execute('''
          synchronize(2); advance(3)
          assert(not spells.isFresh() and casts()==0 and #commands==5)
          assert(spells.get(72).active and spells.snapshot().active[1].awaiting)
        ''')

    def test_malformed_timeout_retry_and_boundaries(self):
        self.lua.execute('''
          feed('{spellheaders noprompt}'); feed('72,Bad,2,nan,100,-1,1')
          assert(not spells.isFresh()); advance(10); advance(20)
          assert(#commands==2 and not spells.isFresh())
          local n=#commands; advance(60); assert(#commands==n)
          assert(spells.sync(true)); advance(0); synchronize(); assert(spells.isFresh())
          feed('{spellheaders affected noprompt}'); feed('72,Bad,2,30,101,-1,1')
          assert(spells.get(72).active.duration==120 and not spells.isFresh())
        ''')

    def test_limits_duplicates_and_orphan_ends(self):
        self.lua.execute('''
          feed('{spellheaders noprompt}')
          for i=1,4097 do feed(i..',Buff,2,1,100,-1,1') end
          assert(not spells.isFresh() and spells.snapshot().catalog[1]==nil)
          feed('{/recoveries}'); assert(not spells.isFresh())
          spells.sync(true); advance(0)
          feed('{spellheaders noprompt}'); feed('1,Buff,2,1,100,-1,1'); feed('1,Buff,2,1,100,-1,1')
          assert(not spells.isFresh())
        ''')

    def test_gate_initial_batch_exact_command_and_completion(self):
        self.lua.execute('''
          prefs.auto_refresh=true; controller.configure(prefs); synchronize()
          update('char.status.state',8,'char.status'); advance(5); assert(casts()==0)
          update('char.status.pos','Sleeping','char.status'); update('char.status.state',3,'char.status'); advance(5); assert(casts()==0)
          update('char.status.pos','Standing','char.status'); advance(2); assert(casts()==1)
          assert(controller.status().inflight); assert(not controller.runOnce())
          feed('{affoff}72'); advance(40); assert(casts()==1)
          feed('{spellup-end}'); assert(not controller.status().inflight and not spells.isFresh())
          synchronize(); advance(2); assert(casts()==2)
        ''')

    def test_coalescing_cooldown_and_pause(self):
        self.lua.execute('''
          prefs.auto_refresh=true; controller.configure(prefs); synchronize(); advance(2); assert(casts()==1)
          feed('{spellup-end}'); synchronize()
          feed('{affoff}72'); feed('{affoff}35'); advance(2); assert(casts()==1)
          advance(28); assert(casts()==2)
          prefs.auto_refresh=false; controller.configure(prefs)
          feed('{spellup-end}'); synchronize(); feed('{affoff}72'); advance(60); assert(casts()==2)
          assert(controller.status().last=='Off')
        ''')

    def test_timeout_does_not_assume_batch_finished(self):
        self.lua.execute('''
          synchronize(); assert(controller.runOnce()); advance(120)
          assert(controller.status().paused and controller.status().inflight)
          controller.resume(); advance(0); synchronize(); advance(300); assert(casts()==1)
          assert(not controller.runOnce())
          feed('{spellup-end}'); synchronize(); assert(not controller.status().inflight)
        ''')

    def test_failures_wait_for_relevant_state_and_repeated_pause(self):
        self.lua.execute('''
          prefs.auto_refresh=true; controller.configure(prefs); synchronize(); advance(2)
          feed('{sfail}72,0,1,-1'); assert(casts()==1)
          feed('{sfail}72,0,4,-1'); feed('{spellup-end}'); synchronize(); advance(30)
          assert(casts()==1)
          update('char.vitals.mana',101,'char.vitals'); advance(2); assert(casts()==2)
          feed('{sfail}72,0,4,-1'); feed('{spellup-end}'); synchronize(); advance(30)
          assert(controller.status().paused and casts()==2)
          feed('{sfail}72,1,8,-1'); assert(casts()==2)
        ''')

    def test_transport_failure_activation_cleanup_and_reconnect(self):
        self.lua.execute('''
          synchronize(); local n=count(handlers); spells.start(); controller.start(); assert(count(handlers)==n and #packets==1)
          connected=false; raiseEvent('AardwolfToolbox.gmcp.cleared'); advance(0)
          assert(not spells.isFresh() and #spells.snapshot().active==0 and not controller.runOnce())
          connected=true; transportFailure=true; update('char.status.state',3,'char.status')
          assert(not spells.isFresh()); local n=#commands; advance(20); assert(#commands==n)
          transportFailure=false; spells.sync(true); advance(0); synchronize(); assert(spells.isFresh())
          controller.stop(); spells.stop(); advance(0)
          assert(count(handlers)==0 and count(timers)==0 and count(triggers)==0 and count(gmod.users)==0)
          triggerFailure=true; assert(not spells.start()); assert(count(handlers)==0)
        ''')

    def test_gmcp_disable_keeps_outstanding_batch_locked(self):
        self.lua.execute('''
          synchronize(); controller.runOnce()
          cache.enabled=false; raiseEvent('AardwolfToolbox.gmcp.cleared'); advance(0)
          assert(controller.status().inflight and not controller.runOnce())
          cache.enabled=true; raiseEvent('AardwolfToolbox.gmcp.updated','char.status'); advance(0)
          synchronize(); assert(controller.status().inflight and casts()==1)
        ''')

    def test_broken_forwarded_block_releases_ordinary_output(self):
        self.lua.execute('''
          controller.stop(); spells.stop()
          tags=Tags.new(_G,incoming); tags.configure({enabled=true,suppress=true,block_timeout=10})
          spells=Spells.new(_G,cache,incoming,tags); spells.configure(prefs); advance(0)
          feed('{spellheaders noprompt}'); feed('bad record'); feed('ordinary output after failure')
          assert(visible[#visible]=='ordinary output after failure')
          feed('{spellheaders noprompt}'); spells.stop(); feed('ordinary output after disable')
          assert(visible[#visible]=='ordinary output after disable')
        ''')

    def test_capture_priority_generic_forwarding_and_post_gag_events(self):
        self.lua.execute('''
          tags=Tags.new(_G,incoming); tags.configure({enabled=true,suppress=true,block_timeout=10})
          synchronize()
          incoming.add('fixture-ascii',10,function(text) return text=='{affon}72,999',true end,function() end)
          feed('{affon}72,999'); assert(spells.get(72).active.duration==120)
          incoming.remove('fixture-ascii')
          registerNamedEventHandler('test','event','AardwolfToolbox.spells.updated',function() echo('consumer') end)
          local before=gags; feed('{affon}72,55'); assert(gags==before+1 and visible[#visible]=='consumer')
          assert(tags.latest('affon').payload=='72,55')
          tags.stop(); feed('{affon}72,44'); assert(spells.get(72).active.duration==44)
          feed('Ordinary spell prose'); assert(visible[#visible]=='Ordinary spell prose')
        ''')

class SpellIntegrationTests(unittest.TestCase):
    def setUp(self):
        check_package.PackageTests.setUp(self)

    def test_registry_alias_preferences_and_lifecycle(self):
        self.lua.execute('''
          AardwolfToolbox.start(); local c=AardwolfToolbox.config
          assert(c.get('spellups','enabled') and not c.get('spellups','auto_refresh'))
          assert(not c.set('spellups','min_interval',9)); assert(c.set('spellups','min_interval',45))
          local draft,revision=c.draft(); AardwolfToolbox.spellupCommand('on')
          assert(c.get('spellups','auto_refresh') and not c.apply(draft,revision))
          AardwolfToolbox.openBuffs(); assert(c.get('dashboard','tab')=='buffs')
          AardwolfToolboxLifecycle('sysUninstallPackage','AardwolfToolbox')
          assert(count(handlers)==0 and count(widgets)==0 and count(timers)==0)
        ''')
        self.lua.execute(self.script)
        self.lua.execute('''
          AardwolfToolbox.start(); assert(AardwolfToolbox.config.get('spellups','auto_refresh'))
          assert(AardwolfToolbox.config.get('spellups','min_interval')==45)
          assert(not AardwolfToolbox.spellup.runOnce())
          AardwolfToolbox.stop()
        ''')
