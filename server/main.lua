local function trim(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function cloneTable(value)
  if type(value) ~= 'table' then
    return value
  end

  local out = {}
  for key, entry in pairs(value) do
    out[key] = cloneTable(entry)
  end

  return out
end

local function sanitizeWorldDrop(drop)
  if type(drop) ~= 'table' then
    return nil
  end

  local dropUid = trim(drop.drop_uid)
  if dropUid == '' then
    return nil
  end

  local metadata = type(drop.metadata) == 'table' and drop.metadata
      or (type(drop.metadata_json) == 'table' and drop.metadata_json)
      or {}

  return {
    drop_uid = dropUid,
    label = trim(drop.label) ~= '' and trim(drop.label) or 'Drop',
    x = tonumber(drop.x) or 0,
    y = tonumber(drop.y) or 0,
    z = tonumber(drop.z) or 0,
    metadata = cloneTable(metadata)
  }
end

lib.callback.register('mz_target:server:getWorldDrops', function()
  if GetResourceState('mz_inventory') ~= 'started' then
    return {
      ok = false,
      drops = {}
    }
  end

  local callOk, ok, dropsOrErr = pcall(function()
    return exports['mz_inventory']:ListWorldDrops()
  end)
  if not callOk or not ok or type(dropsOrErr) ~= 'table' then
    return {
      ok = false,
      drops = {}
    }
  end

  local drops = {}
  for _, drop in ipairs(dropsOrErr) do
    local sanitized = sanitizeWorldDrop(drop)
    if sanitized then
      drops[#drops + 1] = sanitized
    end
  end

  return {
    ok = true,
    drops = drops
  }
end)

AddEventHandler('mz_inventory:server:worldDropUpserted', function(drop)
  local sanitized = sanitizeWorldDrop(drop)
  if not sanitized then
    return
  end

  TriggerClientEvent('mz_target:client:worldDropUpserted', -1, sanitized)
end)

AddEventHandler('mz_inventory:server:worldDropRemoved', function(dropUid)
  dropUid = trim(dropUid)
  if dropUid == '' then
    return
  end

  TriggerClientEvent('mz_target:client:worldDropRemoved', -1, dropUid)
end)
