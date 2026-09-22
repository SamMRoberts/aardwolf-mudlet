from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = (ROOT / "tests/spellups_api.lua").read_text()
SPELLS = (ROOT / "src/resources/spells.lua").read_text()
SPELLUP = (ROOT / "src/resources/spellup.lua").read_text()


class SpellupTests(unittest.TestCase):
    def runtime(self, automatic=False):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(FIXTURE)
        lua.globals().SpellsFactory = lua.execute(SPELLS)
        lua.globals().SpellupFactory = lua.execute(SPELLUP)
        lua.globals().initial_automatic = automatic
        lua.execute("""
          spells=SpellsFactory.new(_G,character,settings)
          controller=SpellupFactory.new(_G,character,spells,settings)
          assert(spells:start());advance(0)
          assert(controller:start(initial_automatic));advance(0)
        """)
        return lua

    def test_login_prompts_do_not_activate_spell_triggers(self):
        lua = self.runtime()
        lua.execute("""
          feed('What be thy name, adventurer?')
          feed('Existing profile loaded - please enter your password.')
          assert(triggerFires==0)
          assert(#visible==2)
        """)

    def test_sequential_sync_tags_defensive_copies_and_natural_expiry(self):
        lua = self.runtime()
        lua.execute("""
          assert(#commands==1 and commands[1].text=='slist noprompt')
          assert(#packets==1 and packets[1]==string.char(7,1))
          synchronize()
          assert(spells:isFresh() and #commands==5)
          assert(gags==14 and #visible==0 and #spells:snapshot().active==0)
          advance(60)
          assert(commandCount('slist affected noprompt')==1)
          feed('{affon}72,2');advance(0)
          assert(commandCount('slist affected noprompt')==2)
          deltaRows({'72,Shield,2,2,100,-1,1'}, {})
          local snapshot=spells:snapshot()
          assert(snapshot.active[1].name=='Shield' and snapshot.active[1].remaining==2)
          snapshot.catalog[72].name='changed'
          assert(spells:get(72).name=='Shield')
          advance(3)
          local snapshot=spells:snapshot()
          assert(#snapshot.active==0)
          assert(#snapshot.expired==1 and snapshot.expired[1].id==72
            and snapshot.expired[1].elapsed==1)
          assert(spells:isFresh() and commandCount('spellup learned')==0
            and commandCount('slist affected noprompt')==2 and #commands==7)
        """)

    def test_full_sync_hydrates_preexisting_buffs_and_recoveries(self):
        lua = self.runtime()
        lua.execute("""
          synchronize({
            '72,Shield,2,120,100,-1,1',
            '35,Detect magic,2,90,100,15,1',
          }, {'15,Detect magic recovery,20'})
          local snapshot=spells:snapshot()
          assert(snapshot.fresh and #snapshot.active==2)
          assert(snapshot.active[1].id==35 and snapshot.active[1].remaining==90)
          assert(snapshot.active[2].id==72 and snapshot.active[2].remaining==120)
          assert(#snapshot.recoveries==1 and snapshot.recoveries[1].id==15)
          assert(commandCount('slist affected noprompt')==1)
          assert(commandCount('slist recoveries noprompt')==1)
        """)

    def test_initial_automatic_batch_waits_for_existing_buff_hydration(self):
        lua = self.runtime(automatic=True)
        lua.execute("""
          spellRows('',{'72,Shield,2,0,100,-1,1'})
          spellRows('spellup',{'72,Shield,2,0,100,-1,1'})
          spellRows('bad',{})
          assert(commandCount('spellup learned')==0)
          spellRows('affected',{'72,Shield,2,120,100,-1,1'})
          assert(commandCount('spellup learned')==0)
          recoveryRows({'15,Detect magic recovery,20'})
          assert(spells:isFresh() and #spells:snapshot().active==1)
          assert(commandCount('spellup learned')==1)
          assert(controller:status().inflight)
        """)

    def test_manual_confirm_refreshes_active_state_without_full_catalog_sync(self):
        lua = self.runtime()
        lua.execute("""
          synchronize({'72,Shield,2,120,100,-1,1'}, {})
          local catalogRequests=commandCount('slist noprompt')
          assert(spells:confirm());advance(0)
          deltaRows({
            '72,Shield,2,119,100,-1,1',
            '35,Detect magic,2,90,100,15,1',
          }, {'15,Detect magic recovery,20'})
          local snapshot=spells:snapshot()
          assert(snapshot.fresh and #snapshot.active==2 and #snapshot.recoveries==1)
          assert(commandCount('slist noprompt')==catalogRequests)
        """)

    def test_confirmed_expirations_are_current_ordered_and_defensive(self):
        lua = self.runtime()
        lua.execute("""
          synchronize()
          feed('{affon}72,120');advance(0)
          deltaRows({'72,Shield,2,120,100,-1,1'}, {})
          advance(5)
          feed('{affon}35,90');advance(0)
          deltaRows({'72,Shield,2,115,100,-1,1','35,Detect magic,2,90,100,15,1'}, {})

          feed('{affoff}999');advance(0)
          assert(#spells:snapshot().expired==0)
          deltaRows({'72,Shield,2,115,100,-1,1','35,Detect magic,2,90,100,15,1'}, {})

          feed('{affoff}72');advance(0)
          local snapshot=spells:snapshot()
          assert(#snapshot.active==1 and snapshot.active[1].id==35)
          assert(#snapshot.expired==1 and snapshot.expired[1].id==72
            and snapshot.expired[1].name=='Shield' and snapshot.expired[1].elapsed==0)
          snapshot.expired[1].name='changed';snapshot.expired[1].expiredAt=-1
          assert(spells:snapshot().expired[1].name=='Shield'
            and spells:snapshot().expired[1].expiredAt==clock)
          deltaRows({'35,Detect magic,2,90,100,15,1'}, {})

          advance(5)
          feed('{affoff}999');advance(0)
          deltaRows({}, {})
          snapshot=spells:snapshot()
          assert(#snapshot.expired==2 and snapshot.expired[1].id==35
            and snapshot.expired[2].id==72 and snapshot.expired[2].elapsed==5)

          feed('{affon}72,60');advance(0)
          snapshot=spells:snapshot()
          assert(#snapshot.expired==1 and snapshot.expired[1].id==35)
          deltaRows({'72,Shield,2,60,100,-1,1'}, {})

          feed('{affoff}999');advance(0)
          deltaRows({'72,Shield,2,60,100,-1,1','35,Detect magic,2,40,100,15,1'}, {})
          assert(#spells:snapshot().expired==0)
        """)

    def test_bad_effects_are_not_expired_or_claimed_as_spellup_targets(self):
        lua = self.runtime()
        lua.execute("""
          local catalog={
            '72,Shield,2,0,100,-1,1',
            '237,Web,1,0,100,-1,1',
          }
          spellRows('',catalog)
          spellRows('spellup',{'72,Shield,2,0,100,-1,1'})
          spellRows('bad',{'237,Web,1,0,100,-1,1'})
          spellRows('affected',{});recoveryRows({})
          assert(spells:isFresh() and spells:isBadEffect(237))
          assert(spells:get(237).bad and not spells:isAutomaticSpellup(237))

          feed('{affon}237,30');advance(0)
          deltaRows({'237,Web,1,30,100,-1,1'}, {})
          feed('{affoff}237');advance(0)
          assert(#spells:snapshot().active==0 and #spells:snapshot().expired==0)
          deltaRows({}, {})
          assert(#spells:snapshot().expired==0)

          assert(controller:runOnce())
          feed('Queueing spell : unknown alias.')
          assert(controller:status().unresolvedQueued==1)
          feed('{affon}237,30');advance(0)
          assert(controller:status().unresolvedQueued==1)
          deltaRows({'237,Web,1,30,100,-1,1'}, {})
          assert(controller:status().inflight
            and controller:status().unresolvedQueued==1)

          feed('{affon}72,60');advance(0)
          assert(controller:status().unresolvedQueued==0)
          deltaRows({'237,Web,1,30,100,-1,1','72,Shield,2,60,100,-1,1'}, {})
          assert(not controller:status().inflight and not controller:status().paused)
        """)

    def test_naturally_expired_bad_effect_is_discarded_without_automatic_work(self):
        lua = self.runtime(automatic=True)
        lua.execute("""
          local rows={
            '72,Shield,2,0,100,-1,1',
            '237,Web,1,0,100,-1,1',
          }
          spellRows('',rows)
          spellRows('spellup',{'72,Shield,2,0,100,-1,1'})
          spellRows('bad',{'237,Web,1,0,100,-1,1'})
          spellRows('affected',{'237,Web,1,5,100,-1,1'})
          recoveryRows({})
          assert(commandCount('spellup learned')==1)
          feed('No spells or skills cast.')

          advance(5)
          local snapshot=spells:snapshot()
          assert(#snapshot.active==0 and #snapshot.expired==0)
          advance(30)
          assert(commandCount('spellup learned')==1)
        """)

    def test_interleaved_affoff_is_replayed_into_expired_state(self):
        lua = self.runtime()
        lua.execute("""
          synchronize()
          feed('{affon}72,120');advance(0)
          feed('{spellheaders affected noprompt}')
          feed('72,Shield,2,120,100,-1,1')
          feed('{affoff}72')
          feed('{/spellheaders}')
          local snapshot=spells:snapshot()
          assert(#snapshot.active==0 and #snapshot.expired==1
            and snapshot.expired[1].id==72)
          recoveryRows({})
          deltaRows({}, {})
          assert(#spells:snapshot().expired==1)
        """)

    def test_connection_and_gmcp_resets_clear_expired_state(self):
        resets = (
            "raiseEvent('sysConnectionEvent')",
            "raiseEvent('sysProtocolDisabled','GMCP')",
        )
        for reset in resets:
            with self.subTest(reset=reset):
                lua = self.runtime()
                lua.execute(f"""
                  synchronize()
                  feed('{{affon}}72,120');advance(0)
                  deltaRows({{'72,Shield,2,120,100,-1,1'}}, {{}})
                  feed('{{affoff}}72')
                  assert(#spells:snapshot().expired==1)
                  {reset}
                  assert(#spells:snapshot().expired==0)
                """)

    def test_malformed_snapshot_retains_prior_state_and_ordinary_output(self):
        lua = self.runtime()
        lua.execute("""
          synchronize()
          feed('{affon}72,120');advance(0)
          deltaRows({'72,Shield,2,120,100,-1,1'}, {})
          assert(spells:get(72).active.duration==120)
          assert(spells:sync());advance(0)
          feed('{spellheaders noprompt}')
          feed('72,Bad,2,nan,100,-1,1')
          assert(not spells:isFresh() and spells:get(72).active.duration==120)
          feed('Ordinary spell prose')
          assert(visible[#visible]=='Ordinary spell prose')
          feed('{affoff}oops')
          assert(visible[#visible]=='Ordinary spell prose')
        """)

    def test_duplicate_timeout_and_interrupted_frames_are_atomic(self):
        lua = self.runtime()
        lua.execute("""
          synchronize();local accepted=spells:status().accepted
          assert(spells:sync());advance(0)
          feed('{spellheaders noprompt}')
          feed('72,Shield,2,0,100,-1,1');feed('72,Shield,2,0,100,-1,1')
          assert(not spells:isFresh() and spells:get(72).name=='Shield')
          assert(spells:status().accepted==accepted)
          assert(spells:sync());advance(0);feed('{spellheaders noprompt}')
          advance(10)
          assert(not spells:isFresh() and spells:get(72).name=='Shield')
          assert(spells:status().lastError:find('timed out',1,true))
          assert(spells:sync());advance(0);feed('{spellheaders noprompt}')
          feed('{spellheaders noprompt}')
          assert(not spells:isFresh() and spells:get(72).name=='Shield')
        """)

    def test_deltas_recoveries_and_reconnect_reset(self):
        lua = self.runtime()
        lua.execute("""
          synchronize()
          assert(commandCount('slist affected noprompt')==1
            and commandCount('slist recoveries noprompt')==1)
          feed('{affon}35,50');assert(spells:get(35).active.duration==50);advance(0)
          assert(commandCount('slist affected noprompt')==2)
          deltaRows({'35,Detect magic,2,50,100,15,1'},
            {'15,Detect magic recovery,20'})
          assert(commandCount('slist recoveries noprompt')==2)
          feed('{affoff}35');assert(not spells:get(35).active);advance(0)
          assert(commandCount('slist affected noprompt')==3)
          deltaRows({}, {'15,Detect magic recovery,20'})
          assert(commandCount('slist recoveries noprompt')==3)
          feed('{recon}9,40');assert(#spells:snapshot().recoveries==2)
          feed('{recoff}9');assert(#spells:snapshot().recoveries==1)
          connected=false;raiseEvent('sysDisconnectionEvent');advance(0)
          local snapshot=spells:snapshot()
          assert(not snapshot.fresh and #snapshot.active==0 and #snapshot.expired==0
            and #snapshot.recoveries==0)
          assert(controller:status().inflight==false)
        """)

    def test_inactive_recovery_catalog_rows_are_not_tracked(self):
        lua = self.runtime()
        lua.execute("""
          spellRows('',{'72,Shield,2,0,100,-1,1'})
          spellRows('spellup',{'72,Shield,2,0,100,-1,1'})
          spellRows('bad',{})
          spellRows('affected',{'72,Shield,2,120,100,-1,1'})
          recoveryRows(
            {'0,Augmentation,0','15,Detect magic recovery,20',
              '99,Unknown recovery,0'})
          local snapshot=spells:snapshot()
          assert(snapshot.fresh and #snapshot.active==1 and snapshot.active[1].id==72)
          assert(#snapshot.recoveries==1)
          assert(snapshot.recoveries[1].id==15 and snapshot.recoveries[1].remaining==20)
          assert(snapshot.recoveries[1].name=='Detect magic recovery')
        """)

    def test_default_off_and_all_readiness_states_send_zero(self):
        lua = self.runtime()
        lua.execute("""
          synchronize();advance(60)
          assert(not controller:status().automatic and commandCount('spellup learned')==0)
          for _,row in ipairs({{4,'Standing'},{8,'Standing'},{9,'Sleeping'},{10,'Resting'},
            {11,'Standing'},{12,'Standing'},{5,'Standing'},{3,'Sleeping'},{3,'Resting'}}) do
            updateStatus(row[1],row[2]);assert(not controller:runOnce())
          end
          character.fresh.status=false;assert(not controller:runOnce())
          connected=false;assert(not controller:runOnce())
          assert(commandCount('spellup learned')==0)
        """)

    def test_opt_in_initial_batch_coalescing_throttle_and_outstanding_lock(self):
        lua = self.runtime()
        lua.execute("""
          synchronize()
          assert(controller:setAutomatic(true));advance(0)
          synchronize();advance(0)
          assert(commandCount('spellup learned')==1)
          assert(controller:status().inflight and not controller:runOnce())
          feed('{spellup-end}');advance(0)
          feed('{affoff}72');feed('{affoff}35');advance(2)
          deltaRows({}, {'15,Detect magic recovery,20'})
          deltaRows({}, {'15,Detect magic recovery,20'})
          assert(commandCount('spellup learned')==1)
          advance(28);assert(commandCount('spellup learned')==2)
        """)

    def test_automatic_batch_is_queued_when_tracked_effect_reaches_expiry(self):
        lua = self.runtime()
        lua.execute("""
          synchronize()
          feed('{affon}72,5');advance(0)
          deltaRows({'72,Shield,2,5,100,-1,1'}, {})
          assert(controller:setAutomatic(true));advance(0)
          synchronize({'72,Shield,2,5,100,-1,1'}, {});advance(0)
          assert(commandCount('spellup learned')==1)
          feed('{spellup-end}')

          advance(4)
          assert(not controller:status().pending)
          advance(1)
          assert(controller:status().pending)
          assert(#spells:snapshot().active==0
            and spells:snapshot().expired[1].id==72)
          assert(commandCount('spellup learned')==1)
          advance(25)
          assert(commandCount('spellup learned')==2)
        """)

    def test_late_affoff_after_local_expiry_does_not_queue_duplicate_batch(self):
        lua = self.runtime(automatic=True)
        lua.execute("""
          synchronize({'72,Shield,2,5,100,-1,1'}, {})
          assert(commandCount('spellup learned')==1)
          feed('No spells or skills cast.')

          advance(5)
          assert(controller:status().pending)
          advance(25)
          assert(commandCount('spellup learned')==2
            and controller:status().inflight)

          feed('{affoff}72');advance(0)
          deltaRows({}, {})
          feed('{spellup-end}')
          assert(not controller:status().pending)
          advance(30)
          assert(commandCount('spellup learned')==2)
        """)

    def test_expiry_timer_is_single_rescheduled_and_independent_of_automatic_mode(self):
        lua = self.runtime()
        lua.execute("""
          synchronize()
          feed('{affon}72,5');advance(0)
          deltaRows({'72,Shield,2,5,100,-1,1'}, {})
          assert(count(timers)==1)

          assert(controller:setAutomatic(true));advance(0)
          synchronize({'72,Shield,2,5,100,-1,1'}, {});advance(0)
          feed('{spellup-end}')
          assert(count(timers)==1)

          advance(4)
          feed('{affon}72,10');advance(0)
          deltaRows({'72,Shield,2,10,100,-1,1'}, {})
          assert(count(timers)==1)
          advance(1)
          assert(not controller:status().pending)

          assert(controller:setAutomatic(false))
          assert(count(timers)==1 and not controller:status().pending)
          advance(20)
          assert(commandCount('spellup learned')==1)
          assert(#spells:snapshot().active==0
            and spells:snapshot().expired[1].id==72)
        """)

    def test_non_spellup_effect_expiry_does_not_queue_automatic_batch(self):
        lua = self.runtime()
        lua.execute("""
          local rows={
            '72,Shield,2,0,100,-1,1',
            '104,Chameleon power,3,0,100,-1,2',
          }
          spellRows('',rows)
          spellRows('spellup',{'72,Shield,2,0,100,-1,1'})
          spellRows('bad',{})
          spellRows('affected',{});recoveryRows({})
          feed('{affon}104,5');advance(0)
          deltaRows({'104,Chameleon power,3,5,100,-1,2'}, {})

          assert(controller:setAutomatic(true));advance(0)
          spellRows('',rows)
          spellRows('spellup',{'72,Shield,2,0,100,-1,1'})
          spellRows('bad',{})
          spellRows('affected',{'104,Chameleon power,3,5,100,-1,2'})
          recoveryRows({})
          advance(0);feed('{spellup-end}')
          assert(count(timers)==1)
          advance(30)
          assert(commandCount('spellup learned')==1
            and not controller:status().pending)
          assert(#spells:snapshot().active==0
            and spells:snapshot().expired[1].id==104)
        """)

    def test_expiry_work_survives_uncertain_batch_until_late_confirmation(self):
        lua = self.runtime()
        lua.execute("""
          synchronize()
          feed('{affon}72,5');advance(0)
          deltaRows({'72,Shield,2,5,100,-1,1'}, {})
          assert(controller:setAutomatic(true));advance(0)
          synchronize({'72,Shield,2,5,100,-1,1'}, {});advance(0)
          assert(commandCount('spellup learned')==1)

          advance(5)
          assert(controller:status().pending and controller:status().inflight)
          advance(115)
          assert(controller:status().paused and controller:status().inflight
            and controller:status().pending)
          assert(commandCount('spellup learned')==1)

          feed('{spellup-end}');advance(0)
          assert(commandCount('spellup learned')==2)
        """)

    def test_failure_waits_manual_collision_and_uncertain_completion(self):
        lua = self.runtime()
        lua.execute("""
          synchronize();assert(controller:runOnce())
          feed('{sfail}35,0,3,15');feed('{spellup-end}')
          assert(controller:status().blocked.code==3)
          feed('{recoff}15');advance(30)
          assert(commandCount('spellup learned')==1)
          raiseEvent('sysDataSendRequest','spellup learned');advance(0)
          assert(controller:status().inflight and commandCount('spellup learned')==1)
          advance(119)
          assert(commandCount('slist affected noprompt')==1)
          advance(1)
          assert(controller:status().paused and controller:status().inflight)
          assert(not controller:runOnce())
          controller:resume();advance(0)
          assert(controller:status().inflight and commandCount('spellup learned')==1)
          connected=false;raiseEvent('sysDisconnectionEvent');advance(0)
          assert(not controller:status().inflight)
        """)

    def test_affon_refresh_can_confirm_batch_without_background_polling(self):
        lua = self.runtime()
        lua.execute("""
          synchronize();assert(controller:runOnce())
          feed('Queueing spell : Shield.')
          advance(20)
          assert(controller:status().inflight)
          assert(commandCount('slist affected noprompt')==1)
          feed('{affon}72,120');advance(0)
          assert(commandCount('slist affected noprompt')==2)
          deltaRows({'72,Shield,2,120,100,-1,1'}, {})
          assert(not controller:status().inflight)
          advance(120)
          assert(commandCount('slist affected noprompt')==2)
        """)

    def test_queue_alias_is_reconciled_by_affected_snapshot(self):
        lua = self.runtime()
        lua.execute("""
          synchronize()
          assert(spells:sync());advance(0)
          local rows={
            '72,Shield,2,0,100,-1,1',
            '35,Detect magic,2,0,100,15,1',
            '104,Chameleon power,3,0,100,-1,2',
          }
          spellRows('',rows);spellRows('spellup',rows);spellRows('bad',{})
          spellRows('affected',{});recoveryRows({})
          feed('{affon}72,120');advance(0)
          deltaRows({'72,Shield,2,120,100,-1,1'}, {})

          assert(controller:runOnce())
          feed('Queueing skill : chameleon.')
          assert(controller:status().unresolvedQueued==1)
          feed('{affoff}72');advance(0)
          deltaRows({'104,Chameleon power,3,300,100,-1,2'}, {})
          local status=controller:status()
          assert(not status.inflight and not status.paused
            and status.unresolvedQueued==0)
          advance(120)
          assert(not controller:status().paused)
        """)

    def test_queue_alias_is_reconciled_by_affon(self):
        lua = self.runtime()
        lua.execute("""
          synchronize()
          assert(spells:sync());advance(0)
          local rows={
            '72,Shield,2,0,100,-1,1',
            '35,Detect magic,2,0,100,15,1',
            '104,Chameleon power,3,0,100,-1,2',
          }
          spellRows('',rows);spellRows('spellup',rows);spellRows('bad',{})
          spellRows('affected',{});recoveryRows({})

          assert(controller:runOnce())
          feed('Queueing skill : chameleon.')
          assert(controller:status().unresolvedQueued==1)
          feed('{affon}104,300');advance(0)
          assert(controller:status().unresolvedQueued==0
            and controller:status().inflight)
          deltaRows({'104,Chameleon power,3,300,100,-1,2'}, {})
          assert(not controller:status().inflight and not controller:status().paused)
        """)

    def test_server_queued_zero_practice_spellup_can_confirm_batch(self):
        lua = self.runtime()
        lua.execute("""
          local rows={
            '72,Shield,2,0,100,-1,1',
            '606,Catalysis,3,0,0,-1,2',
          }
          spellRows('',rows);spellRows('spellup',rows);spellRows('bad',{})
          spellRows('affected',{});recoveryRows({})

          assert(controller:runOnce())
          feed('Queueing skill : catalysis.')
          feed('{affon}606,300');advance(0)
          deltaRows({'606,Catalysis,3,300,0,-1,2'}, {})
          local status=controller:status()
          assert(not status.inflight and not status.paused)
        """)

    def test_server_granted_zero_practice_spellup_is_refreshed_at_expiry(self):
        lua = self.runtime(automatic=True)
        lua.execute("""
          local rows={
            '72,Shield,2,0,100,-1,1',
            '606,Catalysis,3,0,0,-1,2',
          }
          spellRows('',rows);spellRows('spellup',rows);spellRows('bad',{})
          spellRows('affected',{});recoveryRows({})
          assert(commandCount('spellup learned')==1)
          feed('No spells or skills cast.')

          feed('{affon}606,60');advance(0)
          deltaRows({'606,Catalysis,3,60,0,-1,2'}, {})
          advance(59)
          assert(commandCount('spellup learned')==1)
          advance(3)
          assert(commandCount('spellup learned')==2)
        """)

    def test_server_queued_one_practice_spellup_completes_and_refreshes(self):
        lua = self.runtime(automatic=True)
        lua.execute("""
          local rows={
            '72,Shield,2,0,100,-1,1',
            '910,Sneak,3,0,1,-1,2',
          }
          spellRows('',rows);spellRows('spellup',rows);spellRows('bad',{})
          spellRows('affected',{});recoveryRows({})
          assert(commandCount('spellup learned')==1)

          feed('Queueing skill : Sneak.')
          feed('{affon}910,60');advance(0)
          deltaRows({'910,Sneak,3,60,1,-1,2'}, {})
          assert(not controller:status().inflight and not controller:status().paused)

          advance(60)
          local snapshot=spells:snapshot()
          assert(#snapshot.active==0 and #snapshot.expired==1
            and snapshot.expired[1].id==910)
          advance(2)
          assert(commandCount('spellup learned')==2)
        """)

    def test_preexisting_wearoff_does_not_hold_new_batch_open(self):
        lua = self.runtime()
        lua.execute("""
          synchronize()
          feed('{affon}72,120');advance(0)
          deltaRows({'72,Shield,2,120,100,-1,1'}, {})

          assert(controller:runOnce())
          feed('Queueing spell : Detect magic.')
          feed('{affon}35,90');advance(0)
          deltaRows({'35,Detect magic,2,90,100,15,1'}, {})
          local status=controller:status()
          assert(not status.inflight and not status.paused)
          assert(#spells:snapshot().expired==1
            and spells:snapshot().expired[1].id==72)
          advance(120)
          assert(not controller:status().paused)
        """)

    def test_wearoff_during_batch_runs_after_completion(self):
        lua = self.runtime()
        lua.execute("""
          synchronize()
          feed('{affon}72,120');advance(0)
          deltaRows({'72,Shield,2,120,100,-1,1'}, {})
          assert(controller:setAutomatic(true));advance(0)
          synchronize({'72,Shield,2,120,100,-1,1'}, {});advance(0)
          assert(commandCount('spellup learned')==1
            and controller:status().inflight)

          feed('{affoff}72');advance(0)
          deltaRows({}, {})
          assert(controller:status().pending and controller:status().inflight)
          feed('{spellup-end}')
          assert(controller:status().pending and not controller:status().inflight)
          advance(30)
          assert(commandCount('spellup learned')==2
            and controller:status().inflight)
        """)

    def test_resource_room_status_waits_and_manual_exclusions(self):
        lua = self.runtime()
        lua.execute("""
          synchronize()
          for _,command in ipairs({'spellup check','spellup learned check',
            'spellup OtherPlayer','say spellup','spellups'}) do
            raiseEvent('sysDataSendRequest',command);advance(0)
            assert(not controller:status().inflight)
          end
          assert(controller:setAutomatic(true));advance(0);synchronize();advance(0)
          assert(commandCount('spellup learned')==1)
          feed('{sfail}35,0,4,-1');feed('{spellup-end}');advance(0)
          advance(30);assert(commandCount('spellup learned')==1)
          updateVital('mana',101);advance(2)
          assert(commandCount('spellup learned')==2)
          feed('{sfail}35,0,5,-1');feed('{spellup-end}');advance(0)
          gmcp.room.info.num=101;raiseEvent('gmcp.room.info');advance(30)
          assert(commandCount('spellup learned')==3)
          feed('{sfail}35,0,10,-1');feed('{spellup-end}');advance(0)
          updateStatus(10,'Resting');advance(30)
          assert(commandCount('spellup learned')==3)
          updateStatus(3,'Standing');advance(2)
          assert(commandCount('spellup learned')==4)
        """)

    def test_terminal_failure_pauses_automation(self):
        lua = self.runtime()
        lua.execute("""
          synchronize();assert(controller:runOnce())
          feed('{sfail}35,0,8,-1')
          assert(controller:status().paused)
          feed('{spellup-end}');advance(0)
          controller:resume();advance(30)
          assert(controller:runOnce())
        """)

    def test_concentration_failure_queues_a_later_documented_batch(self):
        lua = self.runtime(automatic=True)
        lua.execute("""
          synchronize()
          assert(commandCount('spellup learned')==1)
          feed('Queueing spell : Shield.')
          feed('{sfail}72,0,1,-1')
          local status=controller:status()
          assert(status.inflight and status.pending and not status.paused)
          feed('{spellup-end}')
          advance(29)
          assert(commandCount('spellup learned')==1)
          advance(1)
          assert(commandCount('spellup learned')==2
            and controller:status().inflight)
        """)

    def test_spell_tag_visibility_is_persistent_and_does_not_disable_parsing(self):
        lua = self.runtime()
        lua.execute("""
          synchronize()
          assert(spells:status().hideTags and settings.spellupsHideTags)
          assert(spells:setHideTags(false))
          assert(not spells:status().hideTags and not settings.spellupsHideTags)
          local before=#visible
          feed('{affon}35,50');advance(0)
          assert(visible[before+1]=='{affon}35,50')
          assert(spells:get(35).active.duration==50)
          deltaRows({'35,Detect magic,2,50,100,15,1'},
            {'15,Detect magic recovery,20'})
          assert(visible[#visible]=='{/recoveries}')
          assert(#spells:snapshot().recoveries==1)
          assert(spells:setHideTags(true))
          before=#visible
          feed('{recoff}15')
          assert(#visible==before and #spells:snapshot().recoveries==0)
        """)

    def test_hidden_setting_suppresses_unclaimed_tagged_frames_safely(self):
        lua = self.runtime()
        lua.execute("""
          synchronize()
          local before=#visible;local gagged=gags
          feed('{spellheaders learned noprompt}')
          feed('72,Shield,2,0,100,-1,1')
          feed('{/spellheaders}')
          feed('{recoveries noprompt}')
          feed('15,Detect magic recovery,20')
          feed('{/recoveries}')
          assert(#visible==before and gags==gagged+6)

          feed('{spellheaders manual noprompt}')
          feed('Ordinary spell prose')
          assert(visible[#visible]=='Ordinary spell prose')
          feed('72,Shield,2,0,100,-1,1')
          assert(visible[#visible]=='72,Shield,2,0,100,-1,1')
          feed('{/spellheaders}')

          feed('{recoveries noprompt}')
          advance(10)
          feed('Prompt remains visible')
          assert(visible[#visible]=='Prompt remains visible')
        """)

    def test_duplicate_start_stop_and_failed_start_cleanup(self):
        lua = self.runtime()
        lua.execute("""
          local handlerCount=count(handlers);local triggerCount=count(triggers)
          assert(spells:start() and controller:start(false))
          assert(count(handlers)==handlerCount and count(triggers)==triggerCount)
          synchronize();feed('{affon}72,120');advance(0)
          deltaRows({'72,Shield,2,120,100,-1,1'}, {})
          feed('{affoff}72');assert(#spells:snapshot().expired==1)
          controller:stop();spells:stop();advance(0)
          assert(count(handlers)==0 and count(triggers)==0 and count(timers)==0
            and #spells:snapshot().expired==0)
          triggerFailure=true;assert(not spells:start())
          assert(count(handlers)==0 and count(triggers)==0)
        """)


if __name__ == "__main__":
    unittest.main()
