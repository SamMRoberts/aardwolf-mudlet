"""Behavioral regressions for event-driven room acquisition and stable interaction."""
import unittest
import zipfile
import check_mobs as baseline
ROOT = baseline.ROOT


class ResponsiveMobsTests(unittest.TestCase):
    setUp = baseline.MobTests.setUp
    service = baseline.MobTests.service

    def test_stable_roster_retains_clicks_ratings_and_target(self):
        self.lua.execute('''
          local entries={{name='a bat'},{name='a bat'},{name='a snake'}}
          state.observe(entries); local s=state.snapshot(12)
          state.select(s.rows[2].id,s.revision);state.command('kill 2.bat');state.enemy('a bat',true,70)
          state.consider(Consider.parse('a bat snickers nervously.'))
          assert(not state.observe(entries));local after=state.snapshot(12)
          assert(after.revision==s.revision and after.rows[2].id==s.rows[2].id)
          assert(after.rows[2].selected and after.rows[2].target and after.rows[1].consider)
          assert(state.select(s.rows[2].id,s.revision))
          state.observe({entries[3],entries[1],entries[2]})
          assert(not state.select(s.rows[2].id,s.revision),'Order changes must invalidate old clicks')
        ''')

    def test_early_attack_evidence_and_mixed_keywords(self):
        self.lua.execute('''
          state.observe({{name='a small bat'},{name='a large bat'}})
          local s=state.snapshot(12);assert(s.rows[1].ordinal==1 and s.rows[2].ordinal==2)
          state.command('kill 2.bat');assert(state.snapshot(12).rows[2].requested)
          state.attack('a large bat');assert(not state.snapshot(12).rows[2].attacking)
          now=101;state.enemy('a large bat',true,100)
          assert(state.snapshot(12).rows[2].target and state.snapshot(12).rows[2].attacking)
          state.clear('13');state.observe({{name='a large bat'}})
          state.attack('a large bat');now=104;state.enemy('a large bat',true,90)
          assert(not state.snapshot(12).rows[1].attacking)
        ''')

    def test_settle_coalesces_movement_without_polling(self):
        self.service()
        self.lua.execute('''
          room(12);pulse(0.1);room(13);pulse(0.1);room(14);pulse(0.249)
          assert(#sent==0);pulse(0.001);assert(sent[2]=='scan here' and #sent==2)
          scan({'a bat'});pulse(0.05);local before=#sent;pulse(30)
          assert(#sent==before and next(timers)==nil)
        ''')

    def test_old_response_drains_before_new_room_request(self):
        self.service()
        self.lua.execute('''
          room(12);pulse();receive('{scan}');receive('Right here you see:');receive('     - old rat')
          room(13);pulse(2);assert(#sent==2)
          receive('{/scan}');assert(#m.snapshot().rows==0 and m.status().stale==1)
          pulse();assert(#sent==3 and sent[3]=='scan here');scan({'new bat'})
          assert(m.snapshot().rows[1].name=='new bat' and m.snapshot().room=='13')
        ''')

    def test_player_scan_is_visible_reused_and_does_not_send_duplicate(self):
        self.service()
        self.lua.execute('''
          room(12);local claimed,hidden=receive('{scan}');assert(claimed and not hidden)
          receive('Right here you see:');receive('     - a bat')
          claimed,hidden=receive('{/scan}');assert(claimed and not hidden)
          pulse(2);assert(#sent==0 and m.snapshot().fresh)
          assert(m.snapshot().rows[1].name=='a bat')
        ''')

    def test_manual_rating_verifies_then_auto_once_per_visit(self):
        self.service()
        self.lua.execute('''
          room(12);pulse();scan({'a bat'});pulse(2)
          assert(#sent==2 and not m.snapshot().ratings.verified)
          assert(m.rateRoom());pulse();assert(sent[#sent-1]=='consider all')
          local marker=sent[#sent]:match('^echo (.+)$');assert(marker)
          local s=m.snapshot();assert(m.attack(s.rows[1].id,s.revision))
          local claimed,hidden=receive('a bat snickers nervously.');assert(claimed and hidden)
          assert(not m.snapshot().rows[1].consider)
          receive(marker);assert(m.snapshot().ratings.verified and m.snapshot().rows[1].consider.label=='Tough')
          pulse(2);local count=#sent;assert(m.refresh());pulse();scan({'a bat'});pulse(2)
          assert(#sent==count+1,'Refresh repeated automatic consider in same visit')
          room(13);pulse();scan({'a snake'});pulse(1)
          local nextMarker=sent[#sent]:match('^echo (.+)$');assert(nextMarker and marker~=nextMarker)
          receive('a snake should be a fair fight!');receive(nextMarker)
          assert(m.snapshot().rows[1].consider.label=='Fair fight')
          local count=#sent;pulse(20);assert(#sent==count)
          m.stop();assert(next(timers)==nil)
        ''')

    def test_rating_discard_on_membership_change_and_timeout_no_retry(self):
        self.service()
        self.lua.execute('''
          room(12);pulse();scan({'a bat','a bat'});pulse(1);m.rateRoom();pulse()
          local marker=sent[#sent]:sub(6)
          receive('a bat snickers nervously.');status({state=8,enemy='a bat',enemypct=1});receive('You receive 75 experience points.');receive(marker)
          assert(not m.snapshot().ratings.fresh and not m.snapshot().rows[2].consider)
          pulse(1);m.rateRoom();pulse();local count=#sent;pulse(11)
          assert(m.snapshot().fresh and not m.snapshot().ratings.fresh)
          pulse(30);assert(#sent==count)
        ''')

    def test_rating_waits_for_readiness_and_unknown_output_stays_visible(self):
        self.service()
        self.lua.execute('''
          room(12);pulse();scan({'a bat'});pulse(1);m.rateRoom();pulse()
          local marker=sent[#sent]:sub(6);receive(marker);pulse(1)
          room(13);pulse();scan({'a bat'});status({state=8,enemy='a bat'})
          local count=#sent;pulse(5);assert(#sent==count)
          options.after_combat=false;m.configure(options)
          status({state=3,enemy=''});m.rateRoom();pulse()
          assert(sent[#sent-1]=='consider all')
          assert(not receive('Strange forces prevent violence here.'))
          local marker=sent[#sent]:sub(6);receive(marker)
          assert(m.snapshot().rows[1].alive==1 and not m.snapshot().rows[1].consider)
        ''')

    def test_unrelated_lines_take_no_snapshots_and_updates_coalesce(self):
        self.lua.execute('''
          snapshotCalls=0;local old=State.new
          State.new=function(...)
            local model=old(...);local snapshot=model.snapshot
            model.snapshot=function(...) snapshotCalls=snapshotCalls+1;return snapshot(...) end
            return model
          end
        ''')
        self.service()
        self.lua.execute('''
          room(12);pulse();scan({'a bat'});pulse(0.1)
          local before=snapshotCalls
          for i=1,2000 do receive('[4404/4404hp 3047/3047mn] >') end
          assert(snapshotCalls==before)
          local renders=m.status().renders
          for i=1,20 do status({state=8,enemy='a bat',enemypct=100-i}) end
          assert(m.status().renders==renders);pulse(0.05)
          assert(m.status().renders==renders+1)
        ''')

    def test_consider_shared_parse_is_cached_per_line(self):
        self.lua.execute('''
          local original=Consider.parse;local calls=0
          Consider.parse=function(text) calls=calls+1;return original(text) end
          local context={};assert(Consider.parseLine('a bat snickers nervously.',context))
          assert(Consider.parseLine('a bat snickers nervously.',context));assert(calls==1)
          context={};assert(not Consider.parseLine('ordinary line',context))
          assert(not Consider.parseLine('ordinary line',context));assert(calls==2)
        ''')

    def test_coordinator_priority_cancellation_and_inflight_preservation(self):
        with zipfile.ZipFile(ROOT/'build/AardwolfToolbox.mpackage') as archive:
            self.lua.globals().Coordinator=self.lua.execute(archive.read('query-coordinator.lua').decode())
        self.lua.execute('''
          local c=Coordinator.new({tempTimer=function(_,fn) return 1 end,killTimer=function() end,raiseEvent=function() end})
          assert(c.acquire('catalog',40));assert(not c.acquire('nearby',40))
          assert(not c.acquire('room',20));assert(not c.acquire('manual',10))
          assert(c.owner()=='catalog');c.release('catalog')
          assert(not c.acquire('catalog',40));assert(not c.acquire('room',20));assert(c.acquire('manual',10))
          c.release('manual');c.cancel('room');assert(c.acquire('nearby',40))
          c.release('nearby');assert(c.acquire('catalog',40));c.release('catalog')
          assert(c.acquire('manual',10,function() return false end)==false)
          assert(c.acquire('catalog',40));c.destroy();assert(not c.owner())
        ''')

    def test_rate_level_change_and_generic_capture_protection(self):
        self.service()
        self.lua.execute('''
          cache.values['char.status.level']=100
          room(12);pulse();scan({'a bat'});pulse(1);m.rateRoom();pulse()
          local marker=sent[#sent]:sub(6)
          tags.isCapturing=function() return true end
          assert(not receive('a bat snickers nervously.'))
          assert(not receive(marker))
          tags.isCapturing=function() return false end
          receive('a bat snickers nervously.');status({level=101});receive(marker)
          assert(not m.snapshot().ratings.fresh and not m.snapshot().rows[1].consider)
          assert(m.snapshot().fresh)
        ''')

    def test_query_setup_failure_and_capture_cleanup_retain_working_roster(self):
        self.service()
        self.lua.execute('''
          room(12);pulse();scan({'a bat'});pulse(1)
          local aborted=0;tags.abortCapture=function(name) assert(name=='scan');aborted=aborted+1 end
          m.refreshNearby();pulse();receive('{scan}');receive('North from here you see:');pulse(11)
          assert(aborted==1 and m.snapshot().fresh and m.snapshot().rows[1].name=='a bat')
          m.stop();assert(next(timers)==nil)
        ''')

    def test_broker_contended_room_change_cancels_old_unsent_work(self):
        self.service()
        self.lua.execute('''
          assert(queries.acquire('catalog',40))
          room(12);pulse();assert(#sent==0 and #queries.snapshot().requests==1)
          room(13);pulse();assert(#sent==0 and #queries.snapshot().requests==1)
          assert(m.refresh());pulse(0)
          for _,r in ipairs(queries.snapshot().waiting) do if r.owner=='AardwolfToolbox.mobs' then assert(r.priority==10) end end
          queries.release('catalog');pulse(0)
          assert(#sent==2 and sent[2]=='scan here')
          scan({'a new bat'});assert(m.snapshot().room=='13' and m.snapshot().rows[1].name=='a new bat')
          m.stop();queries.destroy();assert(next(timers)==nil)
        ''')
