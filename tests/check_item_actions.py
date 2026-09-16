"""Manual item commands and literal observed comparisons; dispatch is intercepted."""
import unittest
import zipfile
from pathlib import Path
from lupa.lua51 import LuaRuntime


class ItemActionsTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        with zipfile.ZipFile(Path(__file__).resolve().parents[1] / 'build/AardwolfToolbox.mpackage') as archive:
            for key, name in [('Items', 'item-state'), ('Actions', 'item-actions')]:
                self.lua.globals()[key] = self.lua.execute(archive.read(name + '.lua').decode())
        self.lua.execute('''
          items=Items.new(); ready=true; sent={}; checking={}
          local readiness={check=function(policy) checking[#checking+1]=policy;return ready,'Not ready' end,
            send=function(transport,command) sent[#sent+1]={transport,command};return true end}
          a=Actions.new(items,readiness,Items);a.start()
          function row(id,kind,wear)
            return assert(Items.parse(id..',,Éowyn <bag>; kill all,50,'..kind..',0,'..(wear or -1)..',-1'))
          end
          assert(items.replace('carried',{['10']=row('10',7),['20']=row('20',11),
            ['18446744073709551615']=row('18446744073709551615',5)}))
          assert(items.replace('equipped',{['30']=row('30',7,4)}))
          assert(items.replace('container:20',{['40']=row('40',7)}))
        ''')

    def test_exact_single_commands_and_no_optimistic_item_mutation(self):
        self.lua.execute('''
          local rev=items.status().revision
          for _,case in ipairs({{'10','wear',nil,'wear 10'},{'30','remove',nil,'remove 30'},
            {'10','put','20','put 10 20'},{'40','get',nil,'get 40 20'},
            {'18446744073709551615','wear',nil,'wear 18446744073709551615'}}) do
            local c=a.context(case[1]);assert(a.preview(c,case[2],case[3])==case[4])
            assert(a.activate(c,case[2],case[3]));assert(sent[#sent][1]=='command' and sent[#sent][2]==case[4])
          end
          assert(#sent==5 and #checking==5 and checking[1]=='manual')
          assert(items.status().revision==rev and items.get('10').location=='carried')
        ''')

    def test_readiness_invalid_ids_locations_and_container_safety(self):
        self.lua.execute('''
          local c=a.context('10');ready=false;assert(not a.activate(c,'wear'));ready=true
          assert(not a.preview(c,'remove'));assert(not a.preview(c,'drop'))
          assert(not a.preview(c,'put','20;kill all'))
          assert(not a.preview(a.context('20'),'put','20'))
          assert(not a.preview(c,'put','30'))
          assert(not a.context('10'..string.char(10)..'kill'))
          items.invalidate('carried');assert(not a.activate(a.context('10'),'wear'))
          assert(#sent==0)
        ''')

    def test_stale_context_disconnect_removal_and_reconfigure(self):
        self.lua.execute('''
          local c=a.context('10');items.update(assert(Items.event('2,10,-1,4')))
          assert(not a.activate(c,'wear'));assert(a.preview(a.context('10'),'remove')=='remove 10')
          local child=a.context('40');items.update(assert(Items.event('3,20,-1,-1')))
          assert(not a.activate(child,'get') and items.get('40')==nil)
          c=a.context('30');a.stop();a.start();assert(not a.activate(c,'remove'))
          c=a.context('30');a.configure({enabled=false});assert(not a.activate(c,'remove'))
          a.start();c=a.context('30');items.clear();assert(not a.activate(c,'remove'));assert(#sent==0)
        ''')

    def test_snapshot_capture_blocks_commands_without_queueing(self):
        self.lua.execute('''
          local status=items.status
          items.status=function() local s=status();s.capturing=true;return s end
          assert(not a.activate(a.context('10'),'wear'));assert(#sent==0)
          items.status=status;assert(#sent==0)
        ''')

    def test_comparison_preserves_zero_unknowns_and_ambiguous_records(self):
        self.lua.execute('''
          local function stat(name,value) return {tag='statmod',fields={name,value},line='{statmod}'..name..'|'..value} end
          items.details('10',{stat('Strength','0'),stat('Damage roll','5'),stat('Wisdom','1'),stat('Wisdom','2'),stat('Invalid','nan')})
          items.details('30',{stat('Strength','3'),stat('Damage roll','2'),stat('Wisdom','7'),stat('Missing on left','9')})
          local report=assert(a.compare(a.context('10'),'30'));local fields={}
          for _,r in ipairs(report.rows) do fields[r.label]=r end
          assert(fields['Stat: Strength'].left==0 and fields['Stat: Strength'].delta==-3)
          assert(fields['Stat: Damage roll'].delta==3)
          assert(fields['Stat: Wisdom'].left==nil and fields['Stat: Wisdom'].delta==nil)
          assert(fields['Stat: Missing on left'].left==nil and fields['Stat: Missing on left'].delta==nil)
          report.left.name='edited';assert(items.get('10').name~='edited')
          items.invalidate('details:10');report=assert(a.compare(a.context('10'),'30'))
          assert(not report.detailsFresh)
          for _,r in ipairs(report.rows) do if r.label=='Stat: Strength' then assert(r.left==nil and r.delta==nil) end end
          assert(#sent==0)
        ''')
