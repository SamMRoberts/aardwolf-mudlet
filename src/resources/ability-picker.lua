-- Editor-only results are released when its owned widget tree is discarded.
local Picker={}
local function options(values)
  local result={}; for _,v in ipairs(values) do result[#result+1]={value=v,label=v} end; return result
end
function Picker.render(abilities,record,corrections,view,controls)
  local function change(fn) controls.capture(); fn(); controls.redraw() end
  if not record.ability_mode or record.ability_mode=='manual' then
    controls.button('Choose learned ability',function() change(function() record.ability_mode='specific' end) end)
    return
  end
  controls.button('Use regular command / alias',function() change(function() record.ability_mode='manual' end) end)
  controls.text(abilities.last)
  controls.button('Refresh catalog',function() controls.capture(); local _,message=abilities.refresh(); controls.feedback(message) end)
  local function choose(label,key,values)
    controls.button(label..': '..tostring(record[key]),function()
      change(function() view.choosing=view.choosing==key and nil or key end)
    end)
    if view.choosing==key then
      for _,option in ipairs(values) do
        controls.button(option.label,function() change(function() record[key]=option.value; view.choosing=nil; view.page=1 end) end)
      end
    end
  end
  choose('Selection','ability_mode',{{value='specific',label='Specific ability'},{value='highest',label='Highest level of this type'}})
  choose('Role','ability_role',options({'any','damage','protection','healing','stat','buff','utility','unknown'}))
  choose('Spell / Skill','ability_kind',options({'both','spell','skill'}))
  choose('Targeting','ability_targeting',options({'any','single','area','self','object','special','unknown'}))
  local types={{value='',label='All types'}}
  for _,kind in ipairs(abilities.types(record.ability_role,corrections)) do types[#types+1]={value=kind,label=kind} end
  choose('Type','ability_type',types)
  view.search=view.search or ''
  controls.field({key='search',label='Search names or numbers',type='text'},view)
  controls.button('Search',function() change(function() view.page=1 end) end)
  local rows=abilities.list({role=record.ability_role,type=record.ability_type,kind=record.ability_kind,
    targeting=record.ability_targeting,search=view.search},corrections)
  local pages=math.max(1,math.ceil(#rows/10)); view.page=math.min(view.page or 1,pages)
  controls.text(#rows..' learned abilities · page '..view.page..'/'..pages)
  for index=(view.page-1)*10+1,math.min(#rows,view.page*10) do
    local r=rows[index]
    local text=r.name..' (#'..r.id..') · Lv '..tostring(r.level or '?')..' · '..
      (r.cost~=nil and tostring(r.cost)..' '..(r.resource or 'unknown resource') or 'cost unknown')..
      (r.passive and ' · passive' or '')..(r.corrected and ' · local type' or '')
    controls.button(text,function()
      change(function()
        if r.passive then controls.feedback('Passive abilities cannot be used as buttons'); return end
        if not r.command then controls.feedback('No verified skill command. Use a regular command / alias button.'); return end
        record.ability_mode='specific'; record.ability_id=r.id
        if record.label=='New button' or record.label=='' then record.label=r.name end
      end)
    end)
  end
  if view.page>1 then controls.button('Previous abilities',function() change(function() view.page=view.page-1 end) end) end
  if view.page<pages then controls.button('Next abilities',function() change(function() view.page=view.page+1 end) end) end
  controls.field({key='arguments',label='Optional target / arguments',type='text'},record)
  local command,selected=abilities.preview(record,corrections)
  controls.text(command and ('Command preview: '..command) or ('Unavailable: '..tostring(selected)))
  controls.button('Update preview',function() change(function() end) end)
  if record.ability_id and record.ability_id>0 then
    controls.button('Add local type correction for #'..record.ability_id,function()
      change(function()
        if #corrections>=48 then controls.feedback('Maximum 48 type corrections'); return end
        local status=abilities.status()
        if not status.character then controls.feedback('No character catalog available'); return end
        local used={}; for _,c in ipairs(corrections) do used[c.id]=true end
        local n=1; while used['correction_'..n] do n=n+1 end
        corrections[#corrections+1]={id='correction_'..n,label='Ability #'..record.ability_id,
          character=status.character,ability_id=record.ability_id,role=record.ability_role~='any' and record.ability_role or 'unknown',
          ability_type=record.ability_type~='' and record.ability_type or 'unknown'}
        controls.selectCorrections()
      end)
    end)
  end
end
return Picker
