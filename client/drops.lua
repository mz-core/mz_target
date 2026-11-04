-- MZ world-drop presentation.
-- The inventory owns drop records, contents and transfers. mz_target only
-- streams the physical prop and keeps the real drop_uid <-> entity mapping so
-- a matching-looking map prop can never open an inventory drop.
if MZTargetBootstrapped ~= true or type(Config) ~= 'table' or type(Config.Drop) ~= 'table' then
  error('[mz_target] bootstrap failed: client/drops.lua requires client/init.lua and shared/config.lua', 0)
end

MZTargetDrops = MZTargetDrops or {}

local DROP_MODEL = joaat(Config.Drop.prop_model)
local DROP_FALLBACK_MODEL = joaat(Config.Drop.fallback_prop_model)
local DropEntries = {}
local DropUidByEntity = {}
local DropSyncInFlight = false
local PlayerPedId = PlayerPedId

local function trim(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function getDistance(left, right)
  local dx = (tonumber(left.x) or 0) - (tonumber(right.x) or 0)
  local dy = (tonumber(left.y) or 0) - (tonumber(right.y) or 0)
  local dz = (tonumber(left.z) or 0) - (tonumber(right.z) or 0)
  return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

local function requestModel(modelHash)
  if not IsModelInCdimage(modelHash) then return false end
  RequestModel(modelHash)
  local deadline = GetGameTimer() + 5000
  while not HasModelLoaded(modelHash) do
    if GetGameTimer() >= deadline then return false end
    Wait(0)
  end
  return true
end

local function destroyDropEntity(entry)
  if type(entry) ~= 'table' then return end
  local entity = entry.entity
  if entity and DoesEntityExist(entity) then
    DropUidByEntity[entity] = nil
    DeleteEntity(entity)
  end
  entry.entity = nil
end

local function resolveDropSpawnCoords(entry)
  local x = tonumber(entry.x) or 0
  local y = tonumber(entry.y) or 0
  local z = tonumber(entry.z) or 0
  local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, z + 3.0, false)

  if foundGround == true then
    z = tonumber(groundZ) or z
  end

  return x, y, z
end

local function ensureDropEntity(entry)
  if type(entry) ~= 'table' then return false end

  local spawnX, spawnY, spawnZ = resolveDropSpawnCoords(entry)

  if entry.entity and DoesEntityExist(entry.entity) then
    SetEntityCoordsNoOffset(entry.entity, spawnX, spawnY, spawnZ, false, false, false)
    PlaceObjectOnGroundProperly(entry.entity)
    FreezeEntityPosition(entry.entity, true)
    DropUidByEntity[entry.entity] = entry.drop_uid
    return true
  end

  local model = requestModel(DROP_MODEL) and DROP_MODEL or nil
  if not model and DROP_FALLBACK_MODEL ~= DROP_MODEL and requestModel(DROP_FALLBACK_MODEL) then
    model = DROP_FALLBACK_MODEL
  end
  if not model then return false end

  local entity = CreateObjectNoOffset(model, spawnX, spawnY, spawnZ, false, false, false)
  if not entity or entity == 0 then return false end

  SetEntityAsMissionEntity(entity, true, true)
  SetEntityCollision(entity, true, true)
  SetEntityCanBeDamaged(entity, false)
  SetEntityInvincible(entity, true)
  SetEntityHeading(entity, tonumber(Config.Drop.heading_offset) or 0.0)
  PlaceObjectOnGroundProperly(entity)
  FreezeEntityPosition(entity, true)

  entry.entity = entity
  DropUidByEntity[entity] = entry.drop_uid
  SetModelAsNoLongerNeeded(model)
  return true
end

local function updateDropStreaming(entry, playerCoords)
  if type(entry) ~= 'table' then return end

  local streamDistance = tonumber(Config.Drop.stream_distance) or 120.0
  local dropCoords = vec3(tonumber(entry.x) or 0, tonumber(entry.y) or 0, tonumber(entry.z) or 0)

  if getDistance(playerCoords, dropCoords) <= streamDistance then
    ensureDropEntity(entry)
  else
    destroyDropEntity(entry)
  end
end

local function sanitizeDrop(drop)
  if type(drop) ~= 'table' then return nil end
  local dropUid = trim(drop.drop_uid)
  if dropUid == '' then return nil end

  return {
    drop_uid = dropUid,
    label = trim(drop.label) ~= '' and trim(drop.label) or 'Drop',
    x = tonumber(drop.x) or 0,
    y = tonumber(drop.y) or 0,
    z = tonumber(drop.z) or 0
  }
end

local function upsertDrop(drop)
  local sanitized = sanitizeDrop(drop)
  if not sanitized then return end

  local existing = DropEntries[sanitized.drop_uid] or {}
  existing.drop_uid = sanitized.drop_uid
  existing.label = sanitized.label
  existing.x = sanitized.x
  existing.y = sanitized.y
  existing.z = sanitized.z
  DropEntries[sanitized.drop_uid] = existing
  updateDropStreaming(existing, GetEntityCoords(PlayerPedId()))
end

local function removeDrop(dropUid)
  dropUid = trim(dropUid)
  if dropUid == '' then return end
  local entry = DropEntries[dropUid]
  if not entry then return end
  destroyDropEntity(entry)
  DropEntries[dropUid] = nil
end

local function syncWorldDrops()
  if type(lib) ~= 'table' or type(lib.callback) ~= 'table' or type(lib.callback.await) ~= 'function' then
    return false
  end

  local response = lib.callback.await('mz_target:server:getWorldDrops', false)
  if type(response) ~= 'table' or response.ok ~= true then return false end

  local seen = {}
  for _, drop in ipairs(response.drops or {}) do
    local dropUid = trim(type(drop) == 'table' and drop.drop_uid or '')
    if dropUid ~= '' then
      seen[dropUid] = true
      upsertDrop(drop)
    end
  end

  for dropUid in pairs(DropEntries) do
    if not seen[dropUid] then removeDrop(dropUid) end
  end

  return true
end

local function requestWorldDropSync()
  if DropSyncInFlight then return false end
  DropSyncInFlight = true
  local ok, synced = pcall(syncWorldDrops)
  DropSyncInFlight = false
  return ok == true and synced == true
end

-- Public read-only lookup used by mz_inventory/client/target.lua. It only
-- returns a UID when the exact entity is the prop mz_target created for that
-- real drop record.
function MZTargetDrops.GetDropUid(entity)
  entity = tonumber(entity)
  if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end

  local dropUid = DropUidByEntity[entity]
  if not dropUid then return nil end

  local entry = DropEntries[dropUid]
  if not entry or entry.entity ~= entity then
    DropUidByEntity[entity] = nil
    return nil
  end

  local model = GetEntityModel(entity)
  if model ~= DROP_MODEL and model ~= DROP_FALLBACK_MODEL then
    DropUidByEntity[entity] = nil
    return nil
  end

  return dropUid
end

function MZTargetDrops.GetDrop(entity)
  local dropUid = MZTargetDrops.GetDropUid(entity)
  if not dropUid then return nil end
  return DropEntries[dropUid]
end

function MZTargetDrops.GetModels()
  return { Config.Drop.prop_model, Config.Drop.fallback_prop_model }
end

exports('GetWorldDropByEntity', MZTargetDrops.GetDropUid)
exports('GetWorldDropModels', MZTargetDrops.GetModels)

RegisterNetEvent('mz_target:client:worldDropUpserted', upsertDrop)
RegisterNetEvent('mz_target:client:worldDropRemoved', removeDrop)

CreateThread(function()
  local attempts = 0
  while attempts < 10 do
    Wait(attempts == 0 and 500 or 1500)
    if requestWorldDropSync() then return end
    attempts = attempts + 1
  end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
  if resourceName ~= 'mz_inventory' then return end
  CreateThread(function()
    Wait(1000)
    for _ = 1, 5 do
      if requestWorldDropSync() then return end
      Wait(1500)
    end
  end)
end)

RegisterNetEvent('mz_core:client:playerLoaded', function()
  CreateThread(function()
    Wait(1500)
    requestWorldDropSync()
  end)
end)

CreateThread(function()
  while true do
    local playerCoords = GetEntityCoords(PlayerPedId())
    for _, entry in pairs(DropEntries) do
      updateDropStreaming(entry, playerCoords)
    end
    Wait(1000)
  end
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then return end
  for dropUid in pairs(DropEntries) do
    removeDrop(dropUid)
  end
end)
