"""Observed quest names are hints, never mob identities or gameplay actions."""
import unittest
import check_mobs as baseline
import check_mob_actions as actions


class QuestHintTests(unittest.TestCase):
    setUp = baseline.MobTests.setUp
    service = baseline.MobTests.service

    def start_hint(self):
        self.service()
        self.lua.execute('''
          function quest(q)
            questData=q;handlers['AardwolfToolbox.dashboardData.updated']();pulse(.05)
          end
          room(12);scan({'(Hidden) a tiny bat','a tiny bat','a large bat','Élan <red> & friends'})
          pulse(2)
        ''')

    def test_exact_names_duplicates_literal_values_and_defensive_copies(self):
        self.start_hint()
        self.lua.execute('''
          local n=#sent
          quest({state='Active',target=' A  TINY BAT ',room='<Hall>',area='Academy'})
          local s=m.snapshot();assert(s.rows[1].objective and s.rows[2].objective)
          assert(s.rows[1].objective.matches==2 and not s.rows[3].objective)
          assert(s.rows[1].objective.candidate and not s.rows[1].target and not s.rows[1].selected)
          s.rows[1].objective.target='changed';s.rows[1].objective.matches=99
          assert(m.snapshot().rows[2].objective.matches==2 and questData.target==' A  TINY BAT ')
          quest({state='Active',target='Élan <red> & friends'})
          assert(m.snapshot().rows[4].objective and not m.snapshot().rows[1].objective)
          quest({state='Active',target='bat'});for _,r in ipairs(m.snapshot().rows) do assert(not r.objective) end
          assert(#sent==n)
        ''')

    def test_inactive_unknown_malformed_and_disabled_hints(self):
        self.start_hint()
        self.lua.execute('''
          for _,q in ipairs({{state='Ready',target='a tiny bat'}, {state='Target defeated',target='a tiny bat'},
            {state='Waiting',target='a tiny bat'}, {state='Active',targetKnown=false,target='a tiny bat'},
            {state='Active',target=55},{state='Active',target=string.rep('a',513)},
            {state='Active',target='a tiny bat'..string.char(10)}}) do
            quest(q);assert(not m.snapshot().rows[1].objective)
          end
          quest({state='Active',target='a tiny bat'})
          options.quest_hints=false;local n=#sent;m.configure(options);pulse(.05)
          assert(not m.snapshot().rows[1].objective and #sent==n)
          options.quest_hints=true;m.configure(options);pulse(.05)
          assert(m.snapshot().rows[1].objective and #sent==n)
          quest(nil);assert(not m.snapshot().rows[1].objective)
        ''')

    def test_death_missing_room_reset_and_nearby_do_not_gain_identity(self):
        self.start_hint()
        self.lua.execute('''
          quest({state='Active',target='a tiny bat'})
          receive('a tiny bat is DEAD!!');pulse(.05)
          local s=m.snapshot();assert(not s.rows[1].objective and s.rows[2].objective.matches==1)
          scan({'a large bat'});pulse(.05);assert(not m.snapshot().rows[2].objective)
          receive('{scan}');receive('North from here you see:');receive('     - a tiny bat');receive('{/scan}')
          assert(not m.snapshot().nearby.sections[1].entries[1].objective)
          room(13);assert(#m.snapshot().rows==0)
          handlers['AardwolfToolbox.gmcp.cleared']();assert(not m.snapshot().fresh)
          m.stop();assert(not handlers['AardwolfToolbox.dashboardData.updated'])
          questData=nil;assert(m.start());assert(m.start());assert(not m.snapshot().fresh)
        ''')

    def test_timing_only_events_are_quiet_and_location_updates_coalesce(self):
        self.start_hint()
        self.lua.execute('''
          quest({state='Active',target='a tiny bat',room='Hall'})
          local n=m.status().renders;local commands=#sent
          for i=1,10 do questData.remaining=i;handlers['AardwolfToolbox.dashboardData.updated']() end
          pulse(.1);assert(m.status().renders==n and #sent==commands)
          questData.room='New Hall';handlers['AardwolfToolbox.dashboardData.updated']()
          questData.area='New Area';handlers['AardwolfToolbox.dashboardData.updated']()
          pulse(.05);assert(m.status().renders==n+1)
          assert(m.snapshot().rows[1].objective.room=='New Hall')
        ''')


class QuestHintUITests(unittest.TestCase):
    setUp = actions.MobActionUITests.setUp

    def test_shared_quest_events_literal_tooltips_settings_and_combat_colors(self):
        self.lua.execute('''
          assert(c.set('dashboard','automatic_data',false))
          local n=#sent;local before=m.snapshot();local r=before.rows[3];local card=mobCard(r.id)
          local function quest(q)
            gmcp.comm={quest=q};fire('gmcp.comm','gmcp.comm.quest');m.clearSelection()
          end
          quest({action='start',targ='Élan <red> & friends',room='<Hall>',area='Academy'})
          assert(m.snapshot().revision==before.revision and mobCard(r.id)==card)
          assert(card.text:find('Quest?',1,true) and card.tip:find('&lt;Hall&gt;',1,true))
          assert(card.tip:find('identity is unverified',1,true))
          local copy=t.dashboardData.questSnapshot();copy.target='changed'
          assert(t.dashboardData.questSnapshot().target=='Élan <red> & friends')
          quest({action='status',timer=12});assert(card.text:find('Quest?',1,true))
          gmcp.char.status={state=8,enemy='Élan <red> & friends',enemypct=80};fire('gmcp.char','gmcp.char.status');m.clearSelection()
          assert(card.css:find(c.get('mobs','target_color'),1,true) and card.text:find('Fighting',1,true))
          assert(c.set('mobs','colors',false));m.clearSelection();assert(card.text:find('Quest?',1,true))
          local draft,rev=c.draft();draft.mobs.quest_hints=false;assert(c.apply(draft,rev));m.clearSelection()
          assert(not card.text:find('Quest?',1,true) and not card.tip:find('Quest candidate',1,true))
          assert(c.set('mobs','quest_hints',true));m.clearSelection();assert(card.text:find('Quest?',1,true))
          quest({action='killed'});assert(not card.text:find('Quest?',1,true))
          quest({action='start',targ='a small bat'});assert(m.snapshot().rows[1].objective)
          quest({action='status',targ='missing'});assert(not m.snapshot().rows[1].objective)
          assert(#sent==n)
        ''')

class CampaignHintUITests(unittest.TestCase):
    setUp = actions.MobActionUITests.setUp

    def test_individual_candidates_location_exclusions_and_reset(self):
        self.lua.execute('''
          local hints={{source='campaign',candidate=true,target='a small bat'},
            {source='globalQuest',candidate=true,target='a small bat'}}
          t.campaign.hints=function() return hints end
          fire('AardwolfToolbox.campaign.updated');m.clearSelection()
          local s=m.snapshot();local row=s.rows[1];local card=mobCard(row.id)
          assert(#row.objectives==2 and not row.objective)
          assert(card.text:find('CP?',1,true) and card.text:find('GQ?',1,true))
          assert(card.tip:find('identity is unverified',1,true))
          local before=#sent;local revision=s.revision
          hints[1].room='Not the current room';gmcp.room={info={num=321,name='Current room',zone='academy'}}
          fire('gmcp.room','gmcp.room.info');fire('AardwolfToolbox.campaign.updated');m.clearSelection()
          -- Location matching is presentation only; no commands or fighting evidence.
          assert(#sent==before and m.snapshot().revision==revision)
          assert(not card.text:find('CP?',1,true) and card.text:find('GQ?',1,true))
          hints={};fire('AardwolfToolbox.campaign.reset');m.clearSelection()
          assert(not card.text:find('CP?',1,true) and not card.text:find('GQ?',1,true))
        ''')
