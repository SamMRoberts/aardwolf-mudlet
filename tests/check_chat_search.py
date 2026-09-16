"""Local native-buffer contracts; native mouse/focus acceptance is separate."""
import unittest
import check_package


class ChatSearchTests(unittest.TestCase):
    def setUp(self):
        harness = check_package.PackageTests()
        harness.setUp()
        self.addCleanup(harness.doCleanups)
        self.lua = harness.lua
        self.lua.execute('''
          assert(AardwolfToolbox.start());t=AardwolfToolbox
          keys={};mudlet.key={Escape=16777216}
          local serial=0
          function tempKey(key,callback) serial=serial+1;keys[serial]=callback;return serial end
          function killKey(id) keys[id]=nil end
          nativeLines={'older hello','Éowyn <red> hello','100% [literal]','newest hello'}
          local console=t.shell.getBase().chats.all
          function getLineCount(name) assert(name==console.name);return #nativeLines end
          function getLines(name,first,last)
            assert(name==console.name);local result={}
            for n=first,last-1 do result[#result+1]=nativeLines[n+1] end;return result
          end
          function console:scrollTo(line) scrolled=line end
          function send() error('Search must not dispatch') end
          function expandAlias() error('Search must not expand aliases') end
        ''')

    def test_literal_unicode_search_jumps_without_changing_buffer(self):
        self.lua.execute('''
          assert(t.dashboard.searchChat('all'));assert(t.dashboard.isEditing())
          local input=widgets['AardwolfToolbox.chatSearch.input']
          input.action('hello')
          assert(widgets['AardwolfToolbox.chatSearch.status'].text:find('3 matches'))
          assert(widgets['AardwolfToolbox.chatSearch.result.1'].preview=='newest hello')
          input.action('Éowyn')
          local row=widgets['AardwolfToolbox.chatSearch.result.1']
          assert(row.text:find('&lt;red&gt;',1,true))
          row.callback();assert(scrolled==1 and not t.dashboard.isEditing())
          assert(#nativeLines==4 and nativeLines[2]=='Éowyn <red> hello')
          assert(t.dashboard.searchChat('all'));widgets['AardwolfToolbox.chatSearch.input'].action('% [')
          assert(widgets['AardwolfToolbox.chatSearch.status'].text:find('1 match'))
        ''')

    def test_stale_result_buffer_trimming_and_reopened_input_are_guarded(self):
        self.lua.execute('''
          assert(t.dashboard.searchChat('all'));local input=widgets['AardwolfToolbox.chatSearch.input']
          input.action('hello');local click=widgets['AardwolfToolbox.chatSearch.result.1'].callback
          table.remove(nativeLines,1);click();assert(scrolled==nil and t.dashboard.isEditing())
          assert(widgets['AardwolfToolbox.chatSearch.status'].text:find('Buffer changed'))
          assert(t.dashboard.searchChat('all'));input.action('ignored stale input');click()
          assert(not widgets['AardwolfToolbox.chatSearch.result.1'] and scrolled==nil)
          widgets['AardwolfToolbox.chatSearch.close'].callback();assert(not t.dashboard.isEditing())
        ''')

    def test_bounds_errors_and_teardown(self):
        self.lua.execute('''
          assert(t.dashboard.searchChat('all'));local input=widgets['AardwolfToolbox.chatSearch.input']
          nativeLines={};for i=1,12000 do nativeLines[i]='match '..i end
          input.action('match');assert(widgets['AardwolfToolbox.chatSearch.result.100'])
          assert(not widgets['AardwolfToolbox.chatSearch.result.101'])
          assert(widgets['AardwolfToolbox.chatSearch.status'].text:find('limit reached'))
          input.action(string.rep('x',257));assert(not widgets['AardwolfToolbox.chatSearch.result.1'])
          getLines=function() return nil,'buffer unavailable' end;input.action('match')
          assert(widgets['AardwolfToolbox.chatSearch.status'].text:find('Search unavailable'))
          t.stop();assert(not t.dashboard.isEditing() and count(widgets)==0 and count(keys)==0)
          assert(t.start());assert(not t.dashboard.isEditing())
        ''')

    def test_view_menu_entry_and_hidden_tab_closes_search(self):
        self.lua.execute('''
          t.views.menu('all');assert(widgetContaining('Search chat'))
          widgetContaining('Search chat').callback();assert(t.dashboard.isEditing())
          t.shell.getBase().selectChatTab('tells');assert(not t.dashboard.isEditing())
        ''')

    def test_unchanged_layout_writes_nothing_and_partial_start_cleans_up(self):
        self.lua.execute('''
          local Search=assert(loadstring(sources['chat-search']))()
          local search=Search.new(_G,t.ui)
          local host=Geyser.Container:new({name='SearchTest',x=0,y=0,width=500,height=400})
          assert(search.open(host,t.shell.getBase().chats.all));assert(search.find('hello'))
          local row=widgets['AardwolfToolbox.chatSearch.result.1'];local original=row.echo;local writes=0
          row.echo=function(...) writes=writes+1;return original(...) end
          search.layout();search.layout();assert(writes==0)
          search.close();local createKey=tempKey;tempKey=function() return nil end
          assert(not search.open(host,t.shell.getBase().chats.all))
          assert(not search.isEditing() and not widgets['AardwolfToolbox.chatSearch'])
          tempKey=createKey;host:delete()
        ''')
