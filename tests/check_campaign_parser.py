"""User-observed cp info/check; synthetic malformed/interleaved variants are marked in tests."""
import unittest
from pathlib import Path
import check_objectives as baseline

FIXTURES = Path(__file__).parent/'fixtures/objectives'


class CampaignParserTests(unittest.TestCase):
    def setUp(self):
        baseline.ObjectiveTests.setUp(self)
        for file, name in [('campaign-active-info.txt', 'infoText'), ('campaign-active-check.txt', 'checkText')]:
            self.lua.globals()[name] = (FIXTURES/file).read_text()
        self.lua.execute('''
          function parse(text,op)
            local parser=P.new('campaign',op)
            for line in text:gmatch('[^\\n]+') do parser.receive(line) end
            return parser.finish()
          end
          function replay(text)
            for line in text:gmatch('[^\\n]+') do feed(line) end
          end
        ''')

    def test_observed_info_and_check_fields(self):
        self.lua.execute('''
          local info=assert(parse(infoText,'info'))
          assert(info.state=='Active' and info.level==31 and info.remainingSeconds==604020)
          assert(info.completeBy=='07:22AM on 23 Sep 2026')
          assert(info.rewards.qp==29 and info.rewards.tp==1 and info.rewards.trains==1 and info.rewards.gold==23594)
          assert(not info.awards and #info.objectives==11 and info.objectiveScope=='assigned')
          assert(info.objectives[4].name=='a patient fisherman' and info.objectives[4].location=="Mudwog's Swamp")
          assert(info.objectives[1].quantity==1 and not info.objectives[1].remaining and not info.objectives[1].area)
          local check=assert(parse(checkText,'check'))
          assert(check.state=='Active' and check.remainingSeconds==604080 and check.nextCampaignAvailable==false)
          assert(#check.objectives==11 and check.objectiveScope=='remaining' and not check.objectives[1].quantity)
          local merged=S.apply(info,check,'check',100,'fixture')
          assert(merged.completeBy==info.completeBy and merged.rewards.gold==23594 and merged.level==31)
        ''')

    def test_active_refresh_serializes_info_then_remaining_without_polling(self):
        self.lua.execute('''
          make();assert(service.refresh());beginFrame();assert(sent[2]=='campaign info')
          replay(infoText);feed(last)
          assert(#service.hints()==0 and service.snapshot().objectiveScope=='assigned')
          beginFrame();assert(sent[5]=='campaign check')
          feed('a bat hits you.');replay(checkText);feed(last);advance(0)
          local s=service.snapshot();assert(s.fresh and s.objectiveScope=='remaining' and #service.hints()==11)
          assert(s.rewards.gold==23594 and s.completeBy=='07:22AM on 23 Sep 2026')
          assert(#visible==1 and visible[1]=='a bat hits you.')
          local n=#sent;advance(60);assert(#sent==n)
          service.stop();make();local restored=service.snapshot()
          assert(restored.completeBy==s.completeBy and not restored.fresh and #service.hints()==0)
        ''')

    def test_incomplete_or_malformed_responses_do_not_commit(self):
        self.lua.execute('''
          -- Synthetic truncation and malformed rows based on the observed responses.
          assert(not parse(infoText:gsub("Use 'cp check'[^\\n]+",''),'info'))
          assert(not parse(infoText:gsub('Gold Coins[^\\n]+','Gold Coins.........: [ nope ]'),'info'))
          assert(not parse(infoText:gsub('Find and kill 1 %* an old man[^\\n]+','Find and kill 1 * broken (location'),'info'))
          assert(not parse(infoText:gsub('Training Sessions[^\\n]+',''),'info'))
          assert(not parse(infoText:gsub('604020','-1'):gsub('6 days, 23 hours and 47 minutes','6 days and -1 minutes'),'info'))
          assert(not parse(checkText:gsub('You will have to level[^\\n]+',''),'check'))
          assert(not parse(checkText:gsub('You still have to kill %* an old man[^\\n]+','You still have to kill * missing location'),'check'))
          assert(not parse(checkText:gsub('6 days, 23 hours and 48 minutes','6 days and 1 day'),'check'))
          assert(not parse(infoText..infoText,'info'))
          assert(not parse(checkText..checkText,'check'))
        ''')

    def test_literal_names_nested_locations_duplicates_zero_and_short_durations(self):
        self.lua.execute('''
          -- Synthetic grammar edge cases, not additional observed server formats.
          local text=infoText:gsub('an old man %(Aardwolf Zoological Park%)','<Éowyn> (hidden) & friends (A hall (lower))')
          text=text:gsub('Find and kill 1 %* a worshipper %(Ancient Greece%)','Find and kill 1 * <Éowyn> (hidden) & friends (A hall (lower))')
          text=text:gsub('23594','0'):gsub('6 days, 23 hours and 47 minutes','1 minute')
          local s=assert(parse(text,'info'))
          assert(s.rewards.gold==0 and s.remainingSeconds==60)
          assert(s.objectives[1].name=='<Éowyn> (hidden) & friends' and s.objectives[1].location=='A hall (lower)')
          assert(s.objectives[2].name==s.objectives[1].name and #s.objectives==11)
          local empty=checkText:gsub('You still have to kill[^\\n]+\\n',''):gsub('6 days, 23 hours and 48 minutes','0 minutes')
          local q=assert(parse(empty,'check'));assert(#q.objectives==0 and q.state=='Active' and q.remainingSeconds==0)
        ''')

    def test_failed_check_keeps_campaign_metadata_without_fresh_hints(self):
        self.lua.execute('''
          make();assert(service.refresh());beginFrame();replay(infoText);feed(last)
          beginFrame();replay(checkText:gsub('You will have to level[^\\n]+',''));feed(last);advance(0)
          local s=service.snapshot();assert(s.level==31 and s.rewards.qp==29 and not s.fresh and #service.hints()==0)
          assert(not P.supported('globalQuest','check') and not P.automatic('campaign','info'))
        ''')
