-- One snapshot and at most one gag, even when several Toolbox consumers run.
local Incoming = {}
function Incoming.new(api)
  local self, consumers, trigger = {}, {}, nil
  function self.remove(owner)
    consumers[owner]=nil
    if not next(consumers) and trigger then api.killTrigger(trigger); trigger=nil end
  end
  function self.add(owner, priority, receive, failed, processed)
    consumers[owner]={priority=priority,receive=receive,failed=failed,processed=processed}
    if trigger then return end
    local ok,err=pcall(function()
      trigger=assert(api.tempRegexTrigger([[^.*$]],function()
        local text=api.line
        local ordered={}
        for name,consumer in pairs(consumers) do ordered[#ordered+1]={name=name,consumer=consumer} end
        table.sort(ordered,function(a,b) return a.consumer.priority<b.consumer.priority end)
        local function completed(hidden,owner)
          for _,entry in ipairs(ordered) do
            local consumer=entry.consumer
            if consumers[entry.name]==consumer and consumer.processed then
              local ok,err=pcall(consumer.processed,text,hidden,owner)
              if not ok then self.remove(entry.name); consumer.failed(err) end
            end
          end
        end
        for _,entry in ipairs(ordered) do
          local consumer=entry.consumer
          if consumers[entry.name]==consumer then
            local worked,claimed,suppress,forward=pcall(consumer.receive,text)
            if not worked then self.remove(entry.name); consumer.failed(claimed); completed(false,nil); return end
            if claimed then
              -- A machine-readable consumer can forward the same snapshot to the
              -- generic tag archive, without allowing ordinary formatters to claim it.
              if suppress then api.deleteLine() end
              completed(suppress==true,entry.name)
              local observer=forward and consumers[forward]
              if observer then
                local observed,err=pcall(observer.receive,text)
                if not observed then self.remove(forward); observer.failed(err) end
              end
              return
            end
          end
        end
        completed(false,nil)
      end),"Cannot register incoming-line trigger")
    end)
    if not ok then consumers[owner]=nil; error(err,0) end
  end
  function self.destroy()
    consumers={}
    if trigger then api.killTrigger(trigger); trigger=nil end
  end
  return self
end
return Incoming
