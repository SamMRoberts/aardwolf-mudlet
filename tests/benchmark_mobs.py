"""Read-only Lua 5.1 processing benchmark; excludes native Geyser rendering."""
from pathlib import Path
from time import perf_counter
import zipfile
from lupa.lua51 import LuaRuntime

root=Path(__file__).resolve().parents[1]
lua=LuaRuntime()
with zipfile.ZipFile(root/'build/AardwolfToolbox.mpackage') as archive:
    for name,var in [('mob-state','State'),('mob-protocol','Protocol')]:
        lua.globals()[var]=lua.execute(archive.read(name+'.lua').decode())
for count in (10,50,200,512):
    lua.globals().n=count
    lua.execute('''state=State.new(function() return 100 end);state.clear('12')
      local entries={};for i=1,n do entries[i]={name='A creature '..i} end;state.observe(entries)''')
    def measure(expression):
        timings=[]
        for _ in range(3):
            start=perf_counter();lua.execute(expression);timings.append(perf_counter()-start)
        return min(timings)*1000
    before=measure('''for i=1,2000 do
      Protocol.combat('[4404/4404hp 3047/3047mn] >',state.snapshot(12).rows) end''')
    after=measure('''for i=1,2000 do
      Protocol.combat('[4404/4404hp 3047/3047mn] >',state.known) end''')
    reduction=100*(1-after/before)
    print(f'{count:3d} mobs: snapshot path {before:.2f} ms; indexed path {after:.2f} ms; {reduction:.1f}% reduction')
    if count==200:
        assert reduction>=80,'Did not achieve the 80% ordinary-line processing target'
