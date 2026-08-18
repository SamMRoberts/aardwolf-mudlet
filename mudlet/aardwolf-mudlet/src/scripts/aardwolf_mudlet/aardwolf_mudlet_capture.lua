aardwolf_mudlet = aardwolf_mudlet or {}
aardwolf_mudlet.capture = aardwolf_mudlet.capture or {}

local capture = aardwolf_mudlet.capture

function capture.start(command)
  command = aardwolf_mudlet.util.text(command, 200)
  if not command or command == "" or command:find("[%c]") then return false, "Capture command must be one printable line" end
  if aardwolf_mudlet.state.connection ~= "connected" then return false, "Capture requires an active connection" end
  capture.active = {command = command, token = command:match("^%s*([%w_]+)"), lines = {}, started = false, deadline = os.time() + 30, overflow = false}
  send(command, false)
  return true
end

function capture.on_tag(token, phase)
  local active = capture.active
  if not active or not active.token or tostring(token or ""):lower() ~= active.token:lower() then return false end
  if phase == "Start" then active.started = true; return true end
  if phase == "End" and active.started then
    aardwolf_mudlet.state.record("capture", {command = active.command, lines = active.lines, overflow = active.overflow}, "current")
    capture.active = nil
    if aardwolf_mudlet.ui and aardwolf_mudlet.ui.request_render then aardwolf_mudlet.ui.request_render() end
    return true
  end
  return false
end

function capture.on_line(line)
  local active = capture.active
  if not active or not active.started then return false end
  line = aardwolf_mudlet.util.text(line, 2000)
  if not line or line:match("^%{Command:[%w_]+ (Start|End)%}$") then return false end
  if #active.lines >= 500 then active.overflow = true; return false end
  active.lines[#active.lines + 1] = line
  return true
end

function capture.expire()
  if capture.active and os.time() > capture.active.deadline then
    aardwolf_mudlet.state.record("capture", {command = capture.active.command, lines = capture.active.lines, overflow = capture.active.overflow}, "error", "Capture timed out after 30 seconds")
    capture.active = nil
    return true
  end
  return false
end

function capture.cancel() capture.active = nil end

function capture.copy()
  if type(setClipboardText) ~= "function" then return false, "Clipboard support is unavailable" end
  local value = aardwolf_mudlet.state.value("capture")
  setClipboardText(table.concat(type(value.lines) == "table" and value.lines or {}, "\n"))
  return true
end
