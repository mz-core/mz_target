MZTarget = MZTarget or {}

local OPEN_KEY = tostring(MZTargetConfig.open_key or 'LMENU')
local OPEN_LABEL = tostring(MZTargetConfig.open_label or MZTargetConfig.interaction_label or ''):gsub('^%s+', ''):gsub('%s+$', '')
if OPEN_LABEL == '' then
  OPEN_LABEL = 'ALT ESQ'
end

local MENU_CONTROL = tonumber(MZTargetConfig.menu_control or MZTargetConfig.select_control) or 25
local MENU_LABEL = tostring(MZTargetConfig.menu_label or MZTargetConfig.select_label or ''):gsub('^%s+', ''):gsub('%s+$', '')
if MENU_LABEL == '' then
  MENU_LABEL = 'Botao direito'
end

local DROP_MODEL_HASH = joaat((MZTargetConfig.drop and MZTargetConfig.drop.prop_model) or 'prop_cs_heist_bag_02')

local ActiveTarget = nil
local TargetModeActive = false
local MenuFocusActive = false
local OpenKeyHeld = false
local BLOCKED_TARGET_CONTROLS = {
  24,
  25,
  37,
  140,
  141,
  142,
  143,
  257,
  263,
  264
}
local OverlayState = {
  mode = 'closed',
  signature = nil
}
local MenuState = {
  signature = nil
}

local DropEntries = {}
local DropUidByEntity = {}
local rotationToDirection

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

local function debugPrint(message, payload)
  if MZTargetConfig.debug ~= true then
    return
  end

  local suffix = ''
  if type(payload) == 'table' then
    local ok, encoded = pcall(function()
      return json.encode(payload)
    end)

    if ok then
      suffix = (' %s'):format(tostring(encoded or '{}'))
    end
  end

  print(('[mz_target] %s%s'):format(tostring(message or 'debug'), suffix))
end

local function normalizeNotifyType(notifyType)
  local key = tostring(notifyType or 'info'):lower()

  if key == 'success' or key == 'error' or key == 'warning' or key == 'info' then
    return key
  end

  if key == 'inform' then
    return 'info'
  end

  return 'info'
end

local function notify(message, notifyType)
  local normalizedType = normalizeNotifyType(notifyType)
  local payload = {
    type = normalizedType,
    title = 'MZ Target',
    message = tostring(message or 'Acao concluida.'),
    duration = 5000
  }

  if GetResourceState('mz_notify') == 'started' then
    exports['mz_notify']:Notify(payload)
    return
  end

  if lib and type(lib.notify) == 'function' then
    lib.notify({
      title = payload.title,
      description = payload.message,
      type = normalizedType == 'info' and 'inform' or normalizedType
    })
    return
  end

  print(('[mz_target][%s] %s - %s'):format(payload.type, payload.title, payload.message))
end

local function normalizePlate(plate)
  local normalized = trim(plate):upper()
  if normalized == '' then
    return nil
  end

  return normalized
end

local function getDistance(leftCoords, rightCoords)
  local dx = (tonumber(leftCoords.x) or 0) - (tonumber(rightCoords.x) or 0)
  local dy = (tonumber(leftCoords.y) or 0) - (tonumber(rightCoords.y) or 0)
  local dz = (tonumber(leftCoords.z) or 0) - (tonumber(rightCoords.z) or 0)
  return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

local function getVectorFromCoords(coords)
  return vec3(
    tonumber(coords.x) or 0,
    tonumber(coords.y) or 0,
    tonumber(coords.z) or 0
  )
end

local function getScreenDistanceFromCenter(coords)
  local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(
    tonumber(coords.x) or 0,
    tonumber(coords.y) or 0,
    tonumber(coords.z) or 0
  )

  if onScreen ~= true then
    return nil
  end

  local dx = screenX - 0.5
  local dy = screenY - 0.5
  return math.sqrt((dx * dx) + (dy * dy))
end

local function getCameraRaycastResult(maxDistance)
  local ped = PlayerPedId()
  local camCoords = GetGameplayCamCoord()
  local camRotation = GetGameplayCamRot(2)
  local direction = rotationToDirection(camRotation)
  local distance = tonumber(maxDistance) or 6.0
  local destination = vec3(
    camCoords.x + (direction.x * distance),
    camCoords.y + (direction.y * distance),
    camCoords.z + (direction.z * distance)
  )

  local rayHandle = StartShapeTestRay(
    camCoords.x,
    camCoords.y,
    camCoords.z,
    destination.x,
    destination.y,
    destination.z,
    18,
    ped,
    0
  )

  local _, hit, endCoords, _, entityHit = GetShapeTestResult(rayHandle)
  if hit == 1 and entityHit and entityHit ~= 0 then
    return entityHit, getVectorFromCoords(endCoords), GetEntityType(entityHit)
  end

  return nil, getVectorFromCoords(destination), 0
end

local function buildTargetSignature(target)
  if type(target) ~= 'table' then
    return nil
  end

  return table.concat({
    tostring(target.type or ''),
    tostring(target.drop_uid or ''),
    tostring(target.plate or ''),
    tostring(target.bone or ''),
    tostring(target.entity or 0)
  }, '|')
end

local function setOverlayMode(mode, target)
  local nextSignature = buildTargetSignature(target)
  mode = tostring(mode or 'closed')

  if OverlayState.signature == nextSignature and OverlayState.mode == mode then
    return
  end

  OverlayState.signature = nextSignature
  OverlayState.mode = mode

  if mode == 'closed' then
    SendNUIMessage({ action = 'closeTarget' })
    return
  end

  if mode == 'open' then
    SendNUIMessage({
      action = 'openTarget',
      target = {
        label = tostring(target and target.label or ''),
        hint = ('Segure %s para mirar'):format(OPEN_LABEL)
      }
    })
    return
  end

  SendNUIMessage({
    action = 'foundTarget',
    target = {
      kind = tostring(target and target.type or 'default'),
      label = tostring(target and target.label or 'Interagir'),
      hint = tostring(target and target.hint or ('%s para abrir menu'):format(MENU_LABEL))
    }
  })
end

local function disableTargetCombatControls()
  local ped = PlayerPedId()
  if ped and ped ~= 0 then
    DisablePlayerFiring(ped, true)
  end

  for _, control in ipairs(BLOCKED_TARGET_CONTROLS) do
    DisableControlAction(0, control, true)
  end

  if MenuFocusActive then
    DisableControlAction(0, 1, true)
    DisableControlAction(0, 2, true)
    DisableControlAction(0, 4, true)
    DisableControlAction(0, 5, true)
    DisableControlAction(0, 6, true)
  end
end

local function isMzVehiclesStarted()
  return GetResourceState('mz_vehicles') == 'started'
end

local function isPlayerInVehicleTrunk()
  if not isMzVehiclesStarted() then
    return false
  end

  local ok, inTrunk = pcall(function()
    return exports['mz_vehicles']:IsInVehicleTrunk()
  end)

  return ok == true and inTrunk == true
end

local function buildTargetMenuOptions(target)
  if type(target) ~= 'table' then
    return {}
  end

  if target.type == 'drop' then
    return {
      {
        id = 'open_drop',
        kind = 'drop',
        label = tostring(MZTargetConfig.drop and MZTargetConfig.drop.label or 'Abrir bolsa no chao'),
        description = 'Abrir a bolsa deixada no chao.'
      }
    }
  end

  if target.type == 'trunk' then
    local options = {
      {
        id = 'open_trunk',
        kind = 'trunk',
        label = tostring(MZTargetConfig.vehicle and MZTargetConfig.vehicle.trunk and MZTargetConfig.vehicle.trunk.label or 'Abrir porta-malas'),
        description = 'Abrir o inventario do porta-malas.'
      }
    }

    if isMzVehiclesStarted() then
      if isPlayerInVehicleTrunk() then
        options[#options + 1] = {
          id = 'exit_trunk',
          kind = 'trunk',
          label = 'Sair do porta-malas',
          description = 'Sair fisicamente do porta-malas.'
        }
      else
        options[#options + 1] = {
          id = 'enter_trunk',
          kind = 'trunk',
          label = 'Entrar no porta-malas',
          description = 'Entrar fisicamente no porta-malas.'
        }
      end
    end

    return options
  end

  if target.type == 'glovebox' then
    return {
      {
        id = 'open_glovebox',
        kind = 'glovebox',
        label = tostring(MZTargetConfig.vehicle and MZTargetConfig.vehicle.glovebox and MZTargetConfig.vehicle.glovebox.label or 'Abrir porta-luvas'),
        description = 'Abrir o inventario do porta-luvas.'
      }
    }
  end

  return {}
end

local function clearMenuFocus(sendLeftTarget)
  if MenuFocusActive then
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
  end

  MenuFocusActive = false
  MenuState.signature = nil

  if sendLeftTarget == true then
    SendNUIMessage({ action = 'leftTarget' })
  end
end

local function syncTargetMenu(target)
  local targetSignature = buildTargetSignature(target)
  if targetSignature == nil then
    return false
  end

  if MenuState.signature == targetSignature then
    return true
  end

  local options = buildTargetMenuOptions(target)
  if #options == 0 then
    return false
  end

  MenuState.signature = targetSignature

  SendNUIMessage({
    action = 'validTarget',
    target = {
      kind = tostring(target.type or 'default'),
      label = tostring(target.label or 'Interagir'),
      hint = 'Mouse liberado. Escolha uma opcao.'
    },
    options = options
  })

  return true
end

local function openTargetMenu(target)
  if type(target) ~= 'table' then
    return false
  end

  if not syncTargetMenu(target) then
    return false
  end

  if not MenuFocusActive then
    SetCursorLocation(
      tonumber(MZTargetConfig.menu_cursor_x) or 0.58,
      tonumber(MZTargetConfig.menu_cursor_y) or 0.5
    )
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    MenuFocusActive = true
  end

  return true
end

local function requestModel(modelHash)
  if not IsModelInCdimage(modelHash) then
    return false
  end

  RequestModel(modelHash)

  local deadline = GetGameTimer() + 5000
  while not HasModelLoaded(modelHash) do
    if GetGameTimer() >= deadline then
      return false
    end

    Wait(0)
  end

  return true
end

local function destroyDropEntity(entry)
  if type(entry) ~= 'table' then
    return
  end

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
  local probeZ = z + 3.0
  local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, probeZ, false)

  if foundGround == true then
    z = tonumber(groundZ) or z
  end

  return x, y, z
end

local function ensureDropEntity(entry)
  if type(entry) ~= 'table' then
    return false
  end

  local spawnX, spawnY, spawnZ = resolveDropSpawnCoords(entry)

  if entry.entity and DoesEntityExist(entry.entity) then
    SetEntityCoordsNoOffset(
      entry.entity,
      spawnX,
      spawnY,
      spawnZ,
      false,
      false,
      false
    )
    PlaceObjectOnGroundProperly(entry.entity)
    FreezeEntityPosition(entry.entity, true)
    DropUidByEntity[entry.entity] = entry.drop_uid
    return true
  end

  if not requestModel(DROP_MODEL_HASH) then
    debugPrint('failed_to_request_drop_model', { model = DROP_MODEL_HASH })
    return false
  end

  local entity = CreateObjectNoOffset(
    DROP_MODEL_HASH,
    spawnX,
    spawnY,
    spawnZ,
    false,
    false,
    false
  )
  if not entity or entity == 0 then
    return false
  end

  SetEntityAsMissionEntity(entity, true, true)
  SetEntityCollision(entity, true, true)
  SetEntityCanBeDamaged(entity, false)
  SetEntityInvincible(entity, true)
  SetEntityHeading(entity, tonumber(MZTargetConfig.drop and MZTargetConfig.drop.heading_offset) or 0.0)
  PlaceObjectOnGroundProperly(entity)
  FreezeEntityPosition(entity, true)

  entry.entity = entity
  DropUidByEntity[entity] = entry.drop_uid
  SetModelAsNoLongerNeeded(DROP_MODEL_HASH)
  return true
end

local function updateDropStreaming(entry, playerCoords)
  if type(entry) ~= 'table' then
    return
  end

  local streamDistance = tonumber(MZTargetConfig.drop and MZTargetConfig.drop.stream_distance) or 120.0
  local dropCoords = vec3(tonumber(entry.x) or 0, tonumber(entry.y) or 0, tonumber(entry.z) or 0)
  local distance = getDistance(playerCoords, dropCoords)

  if distance <= streamDistance then
    ensureDropEntity(entry)
    return
  end

  destroyDropEntity(entry)
end

local function getDropAimPoint(entry)
  if type(entry) ~= 'table' then
    return nil
  end

  if entry.entity and DoesEntityExist(entry.entity) then
    local model = GetEntityModel(entry.entity)
    local minDim, maxDim = GetModelDimensions(model)
    local centerHeight = ((tonumber(maxDim.z) or 0.0) - (tonumber(minDim.z) or 0.0)) * 0.55
    local aimCoords = GetOffsetFromEntityInWorldCoords(
      entry.entity,
      0.0,
      0.0,
      math.max(centerHeight, 0.18)
    )

    return getVectorFromCoords(aimCoords)
  end

  return vec3(
    tonumber(entry.x) or 0,
    tonumber(entry.y) or 0,
    (tonumber(entry.z) or 0) + 0.2
  )
end

local function sanitizeDrop(drop)
  if type(drop) ~= 'table' then
    return nil
  end

  local dropUid = trim(drop.drop_uid)
  if dropUid == '' then
    return nil
  end

  return {
    drop_uid = dropUid,
    label = trim(drop.label) ~= '' and trim(drop.label) or 'Drop',
    x = tonumber(drop.x) or 0,
    y = tonumber(drop.y) or 0,
    z = tonumber(drop.z) or 0,
    metadata = cloneTable(type(drop.metadata) == 'table' and drop.metadata or {})
  }
end

local function upsertDrop(drop)
  local sanitized = sanitizeDrop(drop)
  if not sanitized then
    return
  end

  local existing = DropEntries[sanitized.drop_uid] or {}
  existing.drop_uid = sanitized.drop_uid
  existing.label = sanitized.label
  existing.x = sanitized.x
  existing.y = sanitized.y
  existing.z = sanitized.z
  existing.metadata = sanitized.metadata
  DropEntries[sanitized.drop_uid] = existing

  updateDropStreaming(existing, GetEntityCoords(PlayerPedId()))
end

local function removeDrop(dropUid)
  dropUid = trim(dropUid)
  if dropUid == '' then
    return
  end

  local entry = DropEntries[dropUid]
  if not entry then
    return
  end

  if type(ActiveTarget) == 'table' and tostring(ActiveTarget.drop_uid or '') == dropUid then
    ActiveTarget = nil
    if TargetModeActive then
      setOverlayMode('open')
    else
      setOverlayMode('closed')
    end
  end

  destroyDropEntity(entry)
  DropEntries[dropUid] = nil
end

local function syncWorldDrops()
  local response = lib.callback.await('mz_target:server:getWorldDrops', false)
  if type(response) ~= 'table' or response.ok ~= true then
    debugPrint('world_drop_sync_failed', response)
    return false
  end

  local seen = {}
  for _, drop in ipairs(response.drops or {}) do
    local dropUid = trim(type(drop) == 'table' and drop.drop_uid or '')
    if dropUid ~= '' then
      seen[dropUid] = true
      upsertDrop(drop)
    end
  end

  for dropUid in pairs(DropEntries) do
    if not seen[dropUid] then
      removeDrop(dropUid)
    end
  end

  return true
end

rotationToDirection = function(rotation)
  local rotX = math.rad(rotation.x)
  local rotZ = math.rad(rotation.z)
  local cosX = math.abs(math.cos(rotX))

  return vec3(
    -math.sin(rotZ) * cosX,
    math.cos(rotZ) * cosX,
    math.sin(rotX)
  )
end

local function getVehicleSectionPoints(vehicle, sectionConfig)
  local points = {}

  for index, boneName in ipairs(sectionConfig.bones or {}) do
    local boneIndex = GetEntityBoneIndexByName(vehicle, boneName)
    if boneIndex and boneIndex ~= -1 then
      local coords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
      points[#points + 1] = {
        point = getVectorFromCoords(coords),
        bone = boneName,
        door_index = type(sectionConfig.door_indices) == 'table' and sectionConfig.door_indices[boneName] or nil,
        source = 'bone'
      }
    end
  end

  if #points > 0 then
    return points
  end

  for index, offset in ipairs(sectionConfig.fallback_offsets or {}) do
    local coords = GetOffsetFromEntityInWorldCoords(
      vehicle,
      tonumber(offset.x) or 0,
      tonumber(offset.y) or 0,
      tonumber(offset.z) or 0
    )

    local fallbackBone = sectionConfig.bones and sectionConfig.bones[index] or nil
    points[#points + 1] = {
      point = getVectorFromCoords(coords),
      bone = fallbackBone,
      door_index = type(sectionConfig.door_indices) == 'table' and sectionConfig.door_indices[fallbackBone] or nil,
      source = 'fallback'
    }
  end

  return points
end

local function resolveVehicleSectionTarget(vehicle, plate, playerCoords, sectionName, sectionConfig, raycastCoords, isRaycastVehicle)
  local bestTarget = nil
  local aimThreshold = tonumber(sectionConfig.aim_threshold) or 0.12
  local hitThreshold = tonumber(sectionConfig.raycast_hit_distance) or 1.3

  for _, candidate in ipairs(getVehicleSectionPoints(vehicle, sectionConfig)) do
    local playerDistance = getDistance(playerCoords, candidate.point)
    local screenDistance = getScreenDistanceFromCenter(candidate.point)
    local hitDistance = raycastCoords and getDistance(raycastCoords, candidate.point) or math.huge
    local validByRaycast = isRaycastVehicle == true and hitDistance <= hitThreshold
    local validByScreen = screenDistance and screenDistance <= aimThreshold

    if playerDistance <= (tonumber(sectionConfig.max_distance) or 2.5)
      and (validByRaycast or validByScreen) then
      local targetData = {
        type = sectionName,
        label = tostring(sectionConfig.label or 'Interagir'),
        hint = ('%s para abrir menu'):format(MENU_LABEL),
        plate = plate,
        entity = vehicle,
        point = candidate.point,
        bone = candidate.bone,
        door_index = candidate.door_index,
        distance = playerDistance,
        screen_distance = validByRaycast and 0.0 or screenDistance,
        hit_distance = hitDistance,
        source = candidate.source
      }

      if not bestTarget
        or targetData.screen_distance < bestTarget.screen_distance
        or (math.abs(targetData.screen_distance - bestTarget.screen_distance) < 0.005 and playerDistance < bestTarget.distance) then
        bestTarget = targetData
      end
    end
  end

  return bestTarget
end

local function buildVehicleRegionTarget(vehicle, plate, playerCoords, sectionName, label, hitPoint)
  if not raycastCoords then
    return nil
  end

  local model = GetEntityModel(vehicle)
  local minDim, maxDim = GetModelDimensions(model)
  local localHit = GetOffsetFromEntityGivenWorldCoords(
    vehicle,
    tonumber(hitPoint.x) or 0,
    tonumber(hitPoint.y) or 0,
    tonumber(hitPoint.z) or 0
  )

  local localX = tonumber(localHit.x) or 0
  local localY = tonumber(localHit.y) or 0
  local widthHalf = math.max(math.abs(tonumber(maxDim.x) or 0), math.abs(tonumber(minDim.x) or 0), 0.8)
  local rearLimit = (tonumber(minDim.y) or -2.0) + 0.95
  local frontDoorStart = -0.15
  local frontDoorEnd = (tonumber(maxDim.y) or 2.0) * 0.78
  local sideThreshold = math.max(widthHalf * 0.42, 0.48)
  local centerThreshold = math.max(widthHalf * 0.95, 0.9)

  if sectionName == 'trunk' then
    if localY > rearLimit or math.abs(localX) > centerThreshold then
      return nil
    end
  elseif sectionName == 'glovebox' then
    if localY < frontDoorStart or localY > frontDoorEnd or math.abs(localX) > centerThreshold then
      return nil
    end

    if math.abs(localX) < sideThreshold then
      return nil
    end
  else
    return nil
  end

  return {
    type = sectionName,
    label = tostring(label or 'Interagir'),
    hint = ('%s para abrir menu'):format(MENU_LABEL),
    plate = plate,
    entity = vehicle,
    point = hitPoint,
    distance = getDistance(playerCoords, hitPoint),
    screen_distance = 0.0,
    source = 'raycast_region'
  }
end

local function resolveVehicleTarget(vehicle, playerCoords, raycastCoords, isRaycastVehicle)
  if not DoesEntityExist(vehicle) then
    return nil
  end

  local plate = normalizePlate(GetVehicleNumberPlateText(vehicle))
  if not plate then
    return nil
  end

  if isRaycastVehicle == true and raycastCoords then
    local regionCandidates = {
      buildVehicleRegionTarget(
        vehicle,
        plate,
        playerCoords,
        'trunk',
        MZTargetConfig.vehicle and MZTargetConfig.vehicle.trunk and MZTargetConfig.vehicle.trunk.label or 'Abrir porta-malas',
        raycastCoords
      ),
      buildVehicleRegionTarget(
        vehicle,
        plate,
        playerCoords,
        'glovebox',
        MZTargetConfig.vehicle and MZTargetConfig.vehicle.glovebox and MZTargetConfig.vehicle.glovebox.label or 'Abrir porta-luvas',
        raycastCoords
      )
    }

    for _, candidate in ipairs(regionCandidates) do
      if candidate then
        return candidate
      end
    end
  end

  local candidates = {
    resolveVehicleSectionTarget(vehicle, plate, playerCoords, 'trunk', MZTargetConfig.vehicle.trunk or {}, raycastCoords, isRaycastVehicle),
    resolveVehicleSectionTarget(vehicle, plate, playerCoords, 'glovebox', MZTargetConfig.vehicle.glovebox or {}, raycastCoords, isRaycastVehicle)
  }

  local bestTarget = nil
  for _, candidate in ipairs(candidates) do
    if candidate and (
      not bestTarget
      or candidate.screen_distance < bestTarget.screen_distance
      or (math.abs(candidate.screen_distance - bestTarget.screen_distance) < 0.005 and candidate.distance < bestTarget.distance)
    ) then
      bestTarget = candidate
    end
  end

  return bestTarget
end

local function resolveDropTarget(entry, playerCoords, isRaycastHit)
  if type(entry) ~= 'table' then
    return nil
  end

  if not entry.entity or not DoesEntityExist(entry.entity) then
    return nil
  end

  local entityCoords = GetEntityCoords(entry.entity)
  local distance = getDistance(playerCoords, entityCoords)
  local aimPoint = getDropAimPoint(entry) or getVectorFromCoords(entityCoords)
  local screenDistance = getScreenDistanceFromCenter(aimPoint)
  local maxDistance = tonumber(MZTargetConfig.drop and MZTargetConfig.drop.max_distance) or 2.1
  local aimThreshold = tonumber(MZTargetConfig.drop and MZTargetConfig.drop.aim_threshold) or 0.11

  if isRaycastHit == true then
    screenDistance = 0.0
    aimThreshold = 1.0
  end

  if distance > maxDistance
    or not screenDistance
    or screenDistance > aimThreshold then
    return nil
  end

  return {
    type = 'drop',
    label = tostring(MZTargetConfig.drop and MZTargetConfig.drop.label or 'Abrir drop'),
    hint = ('%s para abrir menu'):format(MENU_LABEL),
    drop_uid = entry.drop_uid,
    entity = entry.entity,
    point = aimPoint,
    distance = distance,
    screen_distance = screenDistance
  }
end

local function findBestDropTarget(playerCoords, raycastEntity)
  if raycastEntity and raycastEntity ~= 0 then
    local raycastDropUid = DropUidByEntity[raycastEntity]
    if raycastDropUid then
      local raycastEntry = DropEntries[raycastDropUid]
      local raycastTarget = resolveDropTarget(raycastEntry, playerCoords, true)
      if raycastTarget then
        return raycastTarget
      end
    end
  end

  local bestTarget = nil

  for _, entry in pairs(DropEntries) do
    if type(entry) == 'table' and entry.entity and DoesEntityExist(entry.entity) then
      local candidate = resolveDropTarget(entry, playerCoords, false)
      if candidate and (
        not bestTarget
        or candidate.screen_distance < bestTarget.screen_distance
        or (math.abs(candidate.screen_distance - bestTarget.screen_distance) < 0.005 and candidate.distance < bestTarget.distance)
      ) then
        bestTarget = candidate
      end
    end
  end

  return bestTarget
end

local function findBestVehicleTarget(playerCoords, raycastEntity, raycastCoords, raycastEntityType)
  if raycastEntity and raycastEntity ~= 0 and raycastEntityType == 2 and DoesEntityExist(raycastEntity) then
    local raycastTarget = resolveVehicleTarget(raycastEntity, playerCoords, raycastCoords, true)
    if raycastTarget then
      return raycastTarget
    end
  end

  local bestTarget = nil
  local maxDistance = tonumber(MZTargetConfig.raycast_distance) or 6.0

  for _, vehicle in ipairs(GetGamePool('CVehicle')) do
    if DoesEntityExist(vehicle) then
      local vehicleDistance = getDistance(playerCoords, GetEntityCoords(vehicle))
      if vehicleDistance <= maxDistance then
        local candidate = resolveVehicleTarget(vehicle, playerCoords, nil, false)
        if candidate and (
          not bestTarget
          or candidate.screen_distance < bestTarget.screen_distance
          or (math.abs(candidate.screen_distance - bestTarget.screen_distance) < 0.005 and candidate.distance < bestTarget.distance)
        ) then
          bestTarget = candidate
        end
      end
    end
  end

  return bestTarget
end

local function resolveCurrentTarget()
  local ped = PlayerPedId()
  if not ped or ped == 0 or IsPauseMenuActive() or IsPedInAnyVehicle(ped, false) then
    return nil
  end

  local playerCoords = GetEntityCoords(ped)
  local raycastEntity, raycastCoords, raycastEntityType = getCameraRaycastResult(tonumber(MZTargetConfig.raycast_distance) or 6.0)
  local dropTarget = findBestDropTarget(playerCoords, raycastEntity)
  local vehicleTarget = findBestVehicleTarget(playerCoords, raycastEntity, raycastCoords, raycastEntityType)

  if dropTarget and vehicleTarget then
    if dropTarget.screen_distance < vehicleTarget.screen_distance then
      return dropTarget
    end

    if math.abs(dropTarget.screen_distance - vehicleTarget.screen_distance) < 0.005 then
      return dropTarget.distance <= vehicleTarget.distance and dropTarget or vehicleTarget
    end
  end

  return dropTarget or vehicleTarget
end

local function openInventoryView(callback)
  local ok, resultOrErr = callback()
  if ok == false and type(resultOrErr) == 'table' and trim(resultOrErr.message) ~= '' then
    notify(resultOrErr.message, 'error')
    return false
  end

  return ok ~= false
end

local function activateTarget(target, optionId)
  if type(target) ~= 'table' then
    return false
  end

  optionId = trim(optionId)

  if target.type == 'drop' and (optionId == '' or optionId == 'open_drop') then
    return openInventoryView(function()
      return exports['mz_inventory']:OpenTargetView({
        type = 'drop',
        drop_uid = target.drop_uid
      })
    end)
  end

  if target.type == 'trunk' and (optionId == '' or optionId == 'open_trunk') then
    return openInventoryView(function()
      return exports['mz_inventory']:OpenVehicleTrunkView(target.plate)
    end)
  end

  if target.type == 'trunk' and optionId == 'enter_trunk' then
    if not isMzVehiclesStarted() then
      return false
    end

    TriggerEvent('mz_vehicles:client:enterVehicleTrunk', { entity = target.entity })
    return true
  end

  if target.type == 'trunk' and optionId == 'exit_trunk' then
    if not isMzVehiclesStarted() then
      return false
    end

    TriggerEvent('mz_vehicles:client:exitVehicleTrunk')
    return true
  end

  if target.type == 'glovebox' and (optionId == '' or optionId == 'open_glovebox') then
    return openInventoryView(function()
      return exports['mz_inventory']:OpenVehicleGloveboxView(target.plate)
    end)
  end

  return false
end

local function startTargetMode()
  if TargetModeActive or MenuFocusActive then
    return
  end

  if IsPauseMenuActive() or exports['mz_inventory']:IsOpen() then
    return
  end

  TargetModeActive = true
  ActiveTarget = nil
  setOverlayMode('open')
end

local function stopTargetMode()
  clearMenuFocus(false)

  if not TargetModeActive then
    ActiveTarget = nil
    setOverlayMode('closed')
    return
  end

  TargetModeActive = false
  ActiveTarget = nil
  setOverlayMode('closed')
end

RegisterNUICallback('selectTarget', function(data, cb)
  local optionId = ''
  if type(data) == 'table' then
    optionId = tostring(data.option_id or data.optionId or data.id or '')
  else
    optionId = tostring(data or '')
  end

  local target = ActiveTarget
  clearMenuFocus(false)
  local ok = activateTarget(target, optionId)
  stopTargetMode()

  cb({
    ok = ok == true
  })
end)

RegisterNUICallback('leftTarget', function(_, cb)
  clearMenuFocus(true)

  if not OpenKeyHeld then
    stopTargetMode()
  elseif TargetModeActive then
    if ActiveTarget then
      setOverlayMode('found', ActiveTarget)
    else
      setOverlayMode('open')
    end
  else
    setOverlayMode('closed')
  end

  cb({
    ok = true
  })
end)

RegisterNUICallback('closeTarget', function(_, cb)
  stopTargetMode()

  cb({
    ok = true
  })
end)

RegisterNetEvent('mz_target:client:worldDropUpserted', function(drop)
  upsertDrop(drop)
end)

RegisterNetEvent('mz_target:client:worldDropRemoved', function(dropUid)
  removeDrop(dropUid)
end)

RegisterCommand('+mzTargetEye', function()
  OpenKeyHeld = true
  startTargetMode()
end, false)

RegisterCommand('-mzTargetEye', function()
  OpenKeyHeld = false

  if MenuFocusActive then
    return
  end

  stopTargetMode()
end, false)

RegisterKeyMapping('+mzTargetEye', 'Abrir target', 'keyboard', OPEN_KEY)

CreateThread(function()
  local attempts = 0

  while attempts < 10 do
    Wait(attempts == 0 and 500 or 1500)
    if syncWorldDrops() then
      return
    end

    attempts = attempts + 1
  end
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

CreateThread(function()
  while true do
    local sleep = tonumber(MZTargetConfig.loop_idle_ms) or 180

    if not TargetModeActive then
      ActiveTarget = nil
      setOverlayMode('closed')
    elseif exports['mz_inventory']:IsOpen() or IsPauseMenuActive() then
      stopTargetMode()
    else
      disableTargetCombatControls()
      local target = resolveCurrentTarget()
      if target then
        sleep = tonumber(MZTargetConfig.loop_active_ms) or 0
        ActiveTarget = target
        if MenuFocusActive then
          if not syncTargetMenu(target) then
            clearMenuFocus(true)
            setOverlayMode('found', target)
          end
        else
          setOverlayMode('found', target)

          if IsDisabledControlJustPressed(0, MENU_CONTROL) then
            openTargetMenu(target)
          end
        end
      else
        if MenuFocusActive then
          clearMenuFocus(true)
        end

        ActiveTarget = nil
        setOverlayMode('open')
      end
    end

    Wait(sleep)
  end
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end

  stopTargetMode()

  for dropUid in pairs(DropEntries) do
    removeDrop(dropUid)
  end
end)
