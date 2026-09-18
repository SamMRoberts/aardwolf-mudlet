local action = matches[2]
if matches[3] then action = "tags-" .. matches[3] end
AardwolfVibe.handleSpellupsCommand(action or "show")
