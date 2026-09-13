-- Manual, single-item operations. Observations change only on server evidence.
local Actions={}
function Actions.new(inventory,readiness,Items)
  local self={enabled=false};local epoch=0
  function self.configure(values) epoch=epoch+1;self.enabled=values.enabled==true;return true end
  function self.start() return self.configure({enabled=true}) end
  function self.stop() epoch=epoch+1;self.enabled=false end
  self.destroy=self.stop
  function self.context(id)
    local row=inventory.get(Items.id(id))
    if not row then return nil,'Item is no longer observed' end
    return {id=row.id,revision=inventory.status().revision,epoch=epoch}
  end
  function self.current(context)
    if type(context)~='table' or context.epoch~=epoch or context.revision~=inventory.status().revision then
      return false,'Items changed. Select the item again.'
    end
    local row=inventory.get(Items.id(context.id))
    if not row then return false,'Item is no longer observed' end
    return true,row
  end
  local function container(id)
    local row=inventory.get(Items.id(id))
    if not row or not row.fresh or row.type~=11 or row.location~='carried' then
      return nil,'Select a fresh, directly carried container'
    end
    return row
  end
  function self.preview(context,action,target)
    if not self.enabled then return nil,'Manual item actions are disabled' end
    if inventory.status().capturing then return nil,'Item snapshot in progress. Select again after it completes.' end
    local ok,row=self.current(context);if not ok then return nil,row end
    if not row.fresh then return nil,'Item location is stale. Refresh first.' end
    if action=='wear' and row.location=='carried' then return 'wear '..row.id end
    if action=='remove' and row.location=='equipped' then return 'remove '..row.id end
    if action=='put' and row.location=='carried' then
      local bag,why=container(target);if not bag then return nil,why end
      if bag.id==row.id then return nil,'An item cannot contain itself' end
      return 'put '..row.id..' '..bag.id
    end
    if action=='get' and row.location=='container' then
      local bag,why=container(row.container);if not bag then return nil,why end
      return 'get '..row.id..' '..bag.id
    end
    return nil,'Action is unavailable at this item location'
  end
  function self.activate(context,action,target)
    local command,why=self.preview(context,action,target)
    if not command then return false,why end
    local ready,reason=readiness.check('manual');if not ready then return false,reason end
    return readiness.send('command',command)
  end
  local function numeric(value)
    local n=tonumber(value)
    if n and n==n and n~=math.huge and n~=-math.huge then return n end
  end
  local function values(row)
    local result={Level=row.level};local seen={}
    if not row.detailsFresh then return result end
    for _,record in ipairs(row.details or {}) do
      local f=record.fields or {}
      if record.tag=='invheader' and Items.id(f[1])==row.id then
        result.Weight=numeric(f[5]);result.Value=numeric(f[4])
      elseif record.tag=='statmod' and #f==2 and type(f[1])=='string' and #f[1]<=80 then
        local key='Stat: '..f[1]
        -- Repeated or nonnumeric fields are ambiguous, not additive evidence.
        result[key]=not seen[key] and numeric(f[2]) or nil;seen[key]=true
      end
    end
    return result
  end
  function self.compare(context,otherId)
    local ok,left=self.current(context);if not ok then return nil,left end
    local right=inventory.get(Items.id(otherId));if not right then return nil,'Comparison item is no longer observed' end
    local a,b=values(left),values(right);local keys={};for k in pairs(a) do keys[k]=true end;for k in pairs(b) do keys[k]=true end
    local names={};for k in pairs(keys) do names[#names+1]=k end;table.sort(names)
    local rows={}
    for _,key in ipairs(names) do rows[#rows+1]={label=key,left=a[key],right=b[key],delta=a[key] and b[key] and a[key]-b[key] or nil} end
    return {left=left,right=right,rows=rows,detailsFresh=left.detailsFresh==true and right.detailsFresh==true}
  end
  return self
end
return Actions
