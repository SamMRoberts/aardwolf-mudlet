"""Main-console suppression through the built package's single dispatcher."""
import unittest
import check_package

PROMPT='[4053/4053hp 2803/2803mn 3228/3228mv 0qt 730tnl] >'

class CleanupTests(unittest.TestCase):
    def setUp(self):
        check_package.PackageTests.setUp(self)
        self.lua.globals().prompt=PROMPT
        self.lua.execute('AardwolfToolbox.start(); c=AardwolfToolbox.config; cleanup=AardwolfToolbox.consoleCleanup')

    def test_supplied_flood_and_changed_readings(self):
        self.lua.execute('''
          for i=1,10 do incoming(prompt); incoming(''); incoming('  \t ') end
          assert(#visible==1 and visible[1]==prompt and gagCount==29)
          incoming('[4053/4053hp 2803/2803mn 3228/3228mv 0qt 729tnl] >')
          incoming('You arrive at the lake.'); incoming(prompt)
          assert(#visible==4)
          incoming('Someone says "'..prompt..'"'); incoming(prompt)
          assert(#visible==6)
          incoming('[custom prompt] >'); incoming('[custom prompt] >'); assert(#visible==8)
        ''')

    def test_captured_content_preserves_spacing_and_gags_once(self):
        self.lua.execute('''
          incoming(prompt); local before=gagCount
          incoming('<MAPSTART>'); incoming('Room title'); incoming('   '); incoming(''); incoming('<MAPEND>')
          assert(gagCount-before==5)
          incoming(prompt); assert(#visible==1)
          incoming('{help}'); incoming('{helpkeywords}Topic'); incoming('{helpbody}'); incoming('first'); incoming(''); incoming('second'); incoming('{/helpbody}'); incoming('{/help}')
          incoming(prompt); assert(#visible==1)
          assert(c.set('tags','suppress',false))
          incoming('{example}data'); incoming(prompt); assert(#visible==3)
        ''')

    def test_visible_consider_breaks_prompt_run_hidden_tags_do_not(self):
        self.lua.execute('''
          incoming(prompt); incoming('{unknown}record'); incoming(prompt); assert(#visible==1)
          incoming('You would stomp a frog into the ground.'); incoming(prompt)
          assert(#visible==3 and #replacements==1)
          incoming('  '); assert(#visible==3)
        ''')

    def test_independent_switches_persist_and_disable_is_reversible(self):
        self.lua.execute('''
          assert(c.set('console_cleanup','blank_lines',false))
          incoming(''); incoming(prompt); incoming(''); incoming(prompt); assert(#visible==3)
          assert(c.set('console_cleanup','repeated_prompts',false))
          incoming(prompt); incoming(prompt); assert(#visible==5)
          assert(c.set('console_cleanup','blank_lines',true)); incoming(''); assert(#visible==5)
          AardwolfToolbox.stop(); AardwolfToolbox.start()
          assert(not AardwolfToolbox.config.get('console_cleanup','repeated_prompts'))
          assert(AardwolfToolbox.config.set('console_cleanup','enabled',false))
          incoming(''); assert(visible[#visible]=='')
          AardwolfToolbox.stop(); assert(count(triggers)==0)
        ''')

    def test_session_reset_and_repeat_start(self):
        self.lua.execute('''
          cleanup.start(); cleanup.start(); assert(count(triggers)==1)
          incoming(prompt); incoming(prompt); assert(#visible==1)
          fire('sysDisconnectionEvent'); incoming(prompt); assert(#visible==2)
          fire('sysConnectionEvent'); incoming(prompt); assert(#visible==3)
          cleanup.stop(); cleanup.stop(); incoming(''); assert(#visible==4)
          assert(cleanup.start()); incoming(prompt); assert(#visible==5)
        ''')

    def test_failed_activation_leaves_original_output(self):
        self.lua.execute('''
          AardwolfToolbox.stop(); triggerFailure=true
          local ok=cleanup.start(); assert(not ok and not cleanup.enabled)
          assert(count(triggers)==0 and cleanup.last:find('Stopped'))
          triggerFailure=false
        ''')

if __name__=='__main__': unittest.main()
