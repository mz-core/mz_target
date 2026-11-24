-- Compatibility lookups; mz_inventory owns the drop entities.
local function inventoryLookup(name, ...)
  if GetResourceState('mz_inventory') ~= 'started' then return nil end
  local args = { ... }
  local ok, result = pcall(function() return exports['mz_inventory'][name](exports['mz_inventory'], table.unpack(args)) end)
  return ok and result or nil
end

exports('GetWorldDropByEntity', function(entity) return inventoryLookup('GetWorldDropByEntity', entity) end)
exports('GetWorldDropBackpack', function(entity) return inventoryLookup('GetWorldDropBackpack', entity) end)
exports('GetStreamedWorldDrops', function() return inventoryLookup('GetStreamedWorldDrops') or {} end)
exports('GetWorldDropModels', function()
  return inventoryLookup('GetWorldDropModels') or { Config.Drop.prop_model, Config.Drop.fallback_prop_model }
end)
