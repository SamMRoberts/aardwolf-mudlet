aardwolf_map = aardwolf_map or {}
aardwolf_map.ui = aardwolf_map.ui or {}

function aardwolf_map.ui.message(message)
  echo("\n[Aardwolf Map] " .. tostring(message) .. "\n")
end

function aardwolf_map.ui.import_started(total_rooms, total_exits)
  aardwolf_map.ui.message("Import started: " .. tostring(total_rooms) .. " rooms and " .. tostring(total_exits) .. " exits will merge in batches.")
end

function aardwolf_map.ui.import_finished(status)
  aardwolf_map.ui.message("Import complete. Registered " .. tostring(status.registered_environments or 0) .. " terrain colors. Created " .. tostring(status.created_rooms) .. " rooms, reused " .. tostring(status.reused_rooms) .. ", and skipped " .. tostring(status.skipped_rooms) .. " protected collisions. Imported " .. tostring(status.imported_exits) .. " exits; skipped " .. tostring(status.skipped_exits) .. ".")
end

function aardwolf_map.ui.status(status)
  local phase = status.phase or "idle"
  local error_text = status.error_message and ("; error " .. tostring(status.error_message)) or ""
  local guidance = ""
  if (status.owned_count or 0) == 0 and phase ~= "rooms" and phase ~= "exits" then
    guidance = " No Aardwolf rooms have been merged yet. Run 'aard map import'; do not use Mudlet's 'map load' or Mapper > Load Map for the packaged database, JSON, XML, or .mpackage files."
  end
  aardwolf_map.ui.message("Status: " .. phase .. "; rooms " .. tostring(status.room_index or 0) .. "/" .. tostring(status.room_total or 0) .. ", exits " .. tostring(status.exit_index or 0) .. "/" .. tostring(status.exit_total or 0) .. "; palette " .. tostring(status.palette or "source") .. error_text .. "." .. guidance)
end
