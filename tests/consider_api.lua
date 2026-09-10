-- Native in-place output contracts; actual selection/ANSI behavior is tested offline.
local nativeFg=setFgColor
mainForeground={40,50,60}; mainBackground={10,20,30}
replacements, formatResets = {}, 0
function selectCurrentLine() selectedLine=not selectionFailure end
function getSelection() return selectedLine and visible[#visible] or '' end
function replace(text,keepColor)
  assert(selectedLine and keepColor)
  if replaceFailure then return nil,'Replacement failed' end
  visible[#visible]=text
  replacements[#replacements+1]={text=text,fg=mainForeground,bg=mainBackground}
end
function setFgColor(first,...)
  if type(first)=='string' then return nativeFg(first,...) end
  assert(selectedLine)
  replacements[#replacements].fg={first,...}
end
function deselect() selectedLine=false end
function resetFormat() formatResets=formatResets+1 end
