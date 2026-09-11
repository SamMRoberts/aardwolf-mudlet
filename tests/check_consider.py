"""Consider behavior exercised through the packaged shared input dispatcher."""
import unittest
import check_package

CASES = [
    ('You would stomp {mob} into the ground.', 'Trivial', '≤−20 lvls', (176,176,176)),
    ('{mob} would be easy, but is it even worth the work out?', 'Very easy', '−19…−10 lvls', (102,221,136)),
    ('No Problem! {mob} is weak compared to you.', 'Easy', '−9…−5 lvls', (153,221,102)),
    ('{mob} looks a little worried about the idea.', 'Favorable', '−4…−2 lvls', (102,221,204)),
    ('{mob} should be a fair fight!', 'Fair fight', '±1 lvl', (238,238,238)),
    ('{mob} snickers nervously.', 'Tough', '+2–4 lvls', (255,221,102)),
    ('{mob} chuckles at the thought of you fighting them.', 'Hard', '+5–9 lvls', (255,187,85)),
    ('Best run away from {mob} while you can!', 'Dangerous', '+10–15 lvls', (255,153,85)),
    ('Challenging {mob} would be either very brave or very stupid.', 'Very dangerous', '+16–20 lvls', (255,119,85)),
    ('{mob} would crush you like a bug!', 'Crushing', '+21–30 lvls', (255,102,102)),
    ('{mob} would dance on your grave!', 'Deadly', '+31–40 lvls', (255,102,136)),
    ("{mob} says 'BEGONE FROM MY SIGHT unworthy!'", 'Overwhelming', '+41–50 lvls', (238,119,221)),
    ('You would be completely annihilated by {mob}!', 'Annihilating', '≥+51 lvls', (204,153,255)),
]

class ConsiderTests(unittest.TestCase):
    def setUp(self):
        check_package.PackageTests.setUp(self)
        self.lua.execute('AardwolfToolbox.start(); c=AardwolfToolbox.config; consider=AardwolfToolbox.consider')

    def test_all_ratings_and_literal_names(self):
        for mob in ('a goblin', "Éowyn's 古竜 (elite) [2]", '<red><a href="x"> & %1 | enemy'):
            for template, label, relative, rgb in CASES:
                with self.subTest(mob=mob, rating=label):
                    self.lua.globals().incoming(' \t'+template.format(mob=mob)+'  ')
                    last=self.lua.eval('replacements[#replacements]')
                    self.assertEqual(last['text'], f'{mob} | {label} | {relative}')
                    self.assertEqual(tuple(last['fg'].values()),rgb)
                    self.assertEqual(tuple(last['bg'].values()),(10,20,30))
        self.lua.execute('assert(gagCount==0 and #visible==39 and #replacements==39 and not selectedLine and formatResets==39)')

    def test_unmatched_and_help_rows(self):
        messages=['ordinary output','a goblin snickers nervously!', 'a goblin would crush you like a bug! trailing',
                  ' should be a fair fight!', 'You would stomp  into the ground.',
                  "Someone says 'a goblin should be a fair fight!'", 'a goblin | Hard | +5–9 lvls']
        messages += [template.format(mob='<mob>')+'     +5 to +9' for template,*_ in CASES]
        for message in messages:
            self.lua.globals().incoming(message)
            self.assertEqual(self.lua.eval('visible[#visible]'),message)
        self.lua.execute('assert(#replacements==0 and gagCount==0)')

    def test_live_pronouns_and_status_prefixes(self):
        for mob, pronoun, display in [("(Golden Aura) Cinderella", "her", "(Golden Aura) | Cinderella"),
                             ("(Hidden) (Golden Aura) Some singing mice", "it", "(Hidden) (Golden Aura) | Some singing mice"),
                             ("a knight", "him", "a knight"), ("some guards", "them", "some guards")]:
            self.lua.globals().incoming(f'{mob} chuckles at the thought of you fighting {pronoun}.')
            last = self.lua.eval('replacements[#replacements]')
            self.assertEqual(last['text'], f'{display} | Hard | +5–9 lvls')
            self.assertEqual(tuple(last['fg'].values()), (255,187,85))
        for suffix in ('you.', 'herself.', 'her.   +5 to +9', 'her!'):
            text = 'Cinderella chuckles at the thought of you fighting ' + suffix
            self.lua.globals().incoming(text)
            self.assertEqual(self.lua.eval('visible[#visible]'), text)
        self.lua.execute('assert(#replacements==4 and gagCount==0)')

    def test_disable_colors_persistence_and_lifecycle(self):
        self.lua.execute('''
          assert(c.get('consider','enabled') and c.get('consider','colors'))
          assert(c.set('consider','colors',false)); incoming('No Problem! a goblin is weak compared to you.')
          assert(replacements[1].fg[1]==40 and replacements[1].bg[1]==10)
          assert(visible[1]=='a goblin | Easy | −9…−5 lvls')
          assert(c.set('consider','enabled',false)); incoming('a goblin would crush you like a bug!')
          assert(visible[#visible]=='a goblin would crush you like a bug!' and #replacements==1)
          AardwolfToolboxLifecycle('sysUninstallPackage','AardwolfToolbox')
          assert(count(triggers)==0 and count(timers)==0)
        ''')
        self.lua.execute(self.script)
        self.lua.execute('''
          AardwolfToolbox.start(); c=AardwolfToolbox.config
          assert(not AardwolfToolbox.consider.enabled and not c.get('consider','colors'))
          assert(c.set('consider','enabled',true)); AardwolfToolbox.start(); AardwolfToolbox.consider.start()
          assert(count(triggers)==1)
        ''')
        self.lua.execute(self.script)
        self.lua.execute('''
          incoming('a goblin snickers nervously.'); assert(#replacements==2)
          AardwolfToolbox.stop(); AardwolfToolbox.stop(); assert(count(triggers)==0)
        ''')

    def test_capture_priority_and_independence(self):
        self.lua.execute('''
          incoming('<MAPSTART>'); incoming('a goblin snickers nervously.'); incoming('<MAPEND>')
          assert(#replacements==0 and widgets['AardwolfToolbox.ascii.console'].text=='a goblin snickers nervously.\\n')
          incoming('{block}'); incoming('a goblin snickers nervously.'); incoming('{/block}')
          assert(#replacements==0 and #AardwolfToolbox.tags.recent()==3)
          c.set('tags','suppress',false)
          incoming('{block}'); incoming('a goblin snickers nervously.'); incoming('{/block}'); assert(#replacements==0)
          c.set('tags','enabled',false); c.set('ascii','enabled',false); c.set('vitals','enabled',false); c.set('mapper','enabled',false)
          assert(count(triggers)==1); incoming('a goblin snickers nervously.'); assert(#replacements==1)
          c.set('consider','enabled',false); assert(count(triggers)==1) -- Help and inventory still consume input.
          AardwolfToolbox.stop(); assert(count(triggers)==0)
        ''')

    def test_activation_selection_storage_and_replacement_failures(self):
        self.lua.execute('''
          c.set('consider','enabled',false); local original=replace; replace=nil
          assert(c.set('consider','enabled',true))
          assert(not consider.enabled and consider.last:find('Missing Mudlet API',1,true))
          incoming('a goblin snickers nervously.'); assert(#replacements==0)
          replace=original; assert(consider.start())
          selectionFailure=true; incoming('a goblin snickers nervously.')
          assert(not consider.enabled and visible[#visible]=='a goblin snickers nervously.' and #replacements==0)
          selectionFailure=nil; assert(consider.start()); replaceFailure=true
          incoming('a goblin snickers nervously.'); assert(not consider.enabled and not selectedLine)
          replaceFailure=nil; assert(consider.start()); fileFailures.rename=true
          assert(not c.set('consider','enabled',false)); assert(consider.enabled)
          fileFailures.rename=nil; incoming('a goblin snickers nervously.'); assert(#replacements==1)
          assert(AardwolfToolbox.tags.enabled and AardwolfToolbox.ascii.enabled)
        ''')
