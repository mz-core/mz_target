-- Based on qb-target 5.5.0 by BerkieB (GPL-3.0), client.lua.
-- Modified for MZ Framework on 2026-10-20:
--   * removed PolyZone zones, QBCore job/gang/item checks, ped spawner and
--     qtarget interoperability;
--   * registration is owner-aware so a stopping resource cannot leave stale
--     options behind and a restart can re-register idempotently;
--   * added MZ external-UI guards and the ox_lib locale keys used by the UI.
local GetEntityCoords = GetEntityCoords
local Wait = Wait
local IsDisabledControlPressed = IsDisabledControlPressed
local GetEntityBoneIndexByName = GetEntityBoneIndexByName
local GetWorldPositionOfEntityBone = GetWorldPositionOfEntityBone
local SetPauseMenuActive = SetPauseMenuActive
local DisableAllControlActions = DisableAllControlActions
local EnableControlAction = EnableControlAction
local NetworkGetEntityIsNetworked = NetworkGetEntityIsNetworked
local NetworkGetNetworkIdFromEntity = NetworkGetNetworkIdFromEntity
local GetEntityModel = GetEntityModel
local IsPedAPlayer = IsPedAPlayer
local GetEntityType = GetEntityType
local PlayerPedId = PlayerPedId
local GetShapeTestResult = GetShapeTestResult
local StartShapeTestLosProbe = StartShapeTestLosProbe
local HasEntityClearLosToEntity = HasEntityClearLosToEntity
local currentResourceName = GetCurrentResourceName()
local Config, Types, Players, Entities, Models, nuiData, sendData, sendDistance = Config, { {}, {}, {} }, {}, {},
    {}, {}, {}, {}

local playerPed, targetActive, hasFocus, success, allowTarget = PlayerPedId(), false, false, false, true
local screen = {}
local table_wipe = table.wipe
local pairs = pairs
local pcall = pcall

if MZTargetBootstrapped ~= true or type(CheckOptions) ~= 'function' then
  error('[mz_target] bootstrap failed: CheckOptions is missing; client/init.lua must load before client/main.lua', 0)
end
if type(Bones) ~= 'table' or type(Bones.Options) ~= 'table' or type(Bones.Vehicle) ~= 'table' then
  error('[mz_target] bootstrap failed: Bones is invalid; client/init.lua must load data/bones.lua before client/main.lua', 0)
end

local CheckOptions = CheckOptions
local Bones = Bones

---------------------------------------
--- Source: https://github.com/citizenfx/lua/blob/luaglm-dev/cfx/libs/scripts/examples/scripting_gta.lua
--- Credits to gottfriedleibniz
local glm = require 'glm'

local glm_rad = glm.rad
local glm_quatEuler = glm.quatEulerAngleZYX
local glm_rayPicking = glm.rayPicking
local glm_up = glm.up()
local glm_forward = glm.forward()

local function ScreenPositionToCameraRay()
  local pos = GetFinalRenderedCamCoord()
  local rot = glm_rad(GetFinalRenderedCamRot(2))
  local q = glm_quatEuler(rot.z, rot.y, rot.x)
  return pos, glm_rayPicking(
    q * glm_forward,
    q * glm_up,
    glm_rad(screen.fov),
    screen.ratio,
    0.10000,
    10000.0,
    0, 0
  )
end
---------------------------------------

-- Owner tracking -------------------------------------------------------------
-- qb-target keys options by label. MZ adds an owner record so a resource can
-- be restarted (or stopped) without leaving stale options and without wiping
-- another resource's option that happens to share a table.
local OwnerEntries = {}

local function rememberOwner(owner, tbl, label, option)
  if not owner or owner == '' then return end
  OwnerEntries[owner] = OwnerEntries[owner] or {}
  OwnerEntries[owner][#OwnerEntries[owner] + 1] = {
    tbl = tbl,
    label = label,
    option = option
  }
end

local function forgetOwnerLabel(owner, tbl, label)
  if not owner or owner == '' then return end
  local entries = OwnerEntries[owner]
  if not entries then return end

  for index = #entries, 1, -1 do
    local entry = entries[index]
    if entry.tbl == tbl and entry.label == label then
      if tbl[label] == entry.option then
        tbl[label] = nil
      end
      table.remove(entries, index)
    end
  end

  if next(entries) == nil then
    OwnerEntries[owner] = nil
  end
end

local function removeOwnerOptions(owner)
  local entries = OwnerEntries[owner]
  if not entries then return false end

  for _, entry in ipairs(entries) do
    if entry.tbl[entry.label] == entry.option then
      entry.tbl[entry.label] = nil
    end
  end

  OwnerEntries[owner] = nil
  return true
end

local function resolveOwner(owner)
  owner = owner or GetInvokingResource()
  if not owner or owner == '' then
    owner = currentResourceName
  end
  return owner
end

local function copyOption(option)
  local copy = {}
  for key, value in pairs(option) do
    copy[key] = value
  end
  return copy
end

-- Local helpers --------------------------------------------------------------

local function debugPrint(message, payload)
  if Config.Debug ~= true then return end
  if payload ~= nil then
    print(('[mz_target] %s %s'):format(tostring(message), tostring(payload)))
    return
  end
  print(('[mz_target] %s'):format(tostring(message)))
end

local function isExternalUiOpen()
  if GetResourceState('mz_inventory') == 'started' then
    local ok, open = pcall(function() return exports['mz_inventory']:IsOpen() end)
    if ok and open == true then return true end
  end

  if GetResourceState('mz_radialmenu') == 'started' then
    local ok, open = pcall(function() return exports['mz_radialmenu']:IsOpen() end)
    if ok and open == true then return true end
  end

  return false
end

-- qb-target engine -----------------------------------------------------------

local function RaycastCamera(flag, playerCoords)
  if not playerPed then playerPed = PlayerPedId() end
  if not playerCoords then playerCoords = GetEntityCoords(playerPed) end

  local rayPos, rayDir = ScreenPositionToCameraRay()
  local destination = rayPos + 16 * rayDir
  local rayHandle = StartShapeTestLosProbe(rayPos.x, rayPos.y, rayPos.z, destination.x, destination.y, destination.z,
    flag or -1, playerPed, 4)

  while true do
    local result, _, endCoords, _, entityHit = GetShapeTestResult(rayHandle)

    if result ~= 1 then
      local distance = playerCoords and #(playerCoords - endCoords)

      if flag == 30 and entityHit and entityHit ~= 0 then
        entityHit = HasEntityClearLosToEntity(entityHit, playerPed, 7) and entityHit
      end

      local entityType = entityHit and entityHit ~= 0 and GetEntityType(entityHit)

      if entityType == 0 and entityHit and entityHit ~= 0 and pcall(GetEntityModel, entityHit) then
        entityType = 3
      end

      return endCoords, distance, entityHit, entityType or 0
    end

    Wait(0)
  end
end

exports('RaycastCamera', RaycastCamera)

local function DisableNUI()
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)
  hasFocus = false
end

exports('DisableNUI', DisableNUI)

local function EnableNUI(options)
  if not targetActive or hasFocus then return end
  SetCursorLocation(0.5, 0.5)
  SetNuiFocus(true, true)
  SetNuiFocusKeepInput(true)
  hasFocus = true
  SendNUIMessage({ response = 'validTarget', data = options })
end

exports('EnableNUI', EnableNUI)

local function LeftTarget()
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)
  success, hasFocus = false, false
  table_wipe(sendData)
  SendNUIMessage({ response = 'leftTarget' })
end

exports('LeftTarget', LeftTarget)

local function DisableTarget(forcedisable)
  if (not targetActive and hasFocus and not Config.Toggle) or not forcedisable then return end
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)
  Wait(100)
  targetActive, success, hasFocus = false, false, false
  SendNUIMessage({ response = 'closeTarget' })
end

exports('DisableTarget', DisableTarget)

local function DrawOutlineEntity(entity, bool)
  if not Config.EnableOutline or IsEntityAPed(entity) then return end
  SetEntityDrawOutline(entity, bool)
  SetEntityDrawOutlineColor(Config.OutlineColor[1], Config.OutlineColor[2], Config.OutlineColor[3],
    Config.OutlineColor[4])
end

exports('DrawOutlineEntity', DrawOutlineEntity)

local function SetupOptions(datatable, entity, distance)
  table_wipe(nuiData)
  table_wipe(sendData)
  table_wipe(sendDistance)
  local slot = 0

  for _, data in pairs(datatable) do
    if CheckOptions(data, entity, distance) then
      slot = data.num or slot + 1
      if sendData[slot] then slot = #sendData + 1 end

      -- Do not mutate the registered option: several entities can share a model.
      local entry = copyOption(data)
      entry.entity = entity
      sendData[slot] = entry
      nuiData[slot] = {
        icon = data.icon,
        targeticon = data.targeticon,
        label = data.label
      }
      sendDistance[data.distance] = true
    end
  end

  return slot
end

local function CheckEntity(flag, datatable, entity, distance)
  if not next(datatable) then return end
  table_wipe(sendDistance)
  local slot = SetupOptions(datatable, entity, distance)
  if not next(nuiData) then
    LeftTarget()
    DrawOutlineEntity(entity, false)
    return
  end

  success = true
  SendNUIMessage({ response = 'foundTarget', data = nuiData[slot].targeticon, options = nuiData })
  DrawOutlineEntity(entity, true)

  while targetActive and success do
    local _, dist, entity2 = RaycastCamera(flag)
    if entity ~= entity2 then
      LeftTarget()
      DrawOutlineEntity(entity, false)
      break
    elseif not hasFocus and IsDisabledControlPressed(0, Config.MenuControlKey) then
      EnableNUI(nuiData)
      DrawOutlineEntity(entity, false)
    else
      for optionDistance, enabled in pairs(sendDistance) do
        if enabled and dist > optionDistance then
          LeftTarget()
          DrawOutlineEntity(entity, false)
          break
        end
      end
    end
    Wait(0)
  end

  LeftTarget()
  DrawOutlineEntity(entity, false)
end

exports('CheckEntity', CheckEntity)

local function CheckBones(coords, entity, bonelist)
  local closestBone = -1
  local closestDistance = 20
  local closestPos, closestBoneName

  for _, boneName in pairs(bonelist) do
    if Bones.Options[boneName] then
      local boneId = GetEntityBoneIndexByName(entity, boneName)
      local bonePos = GetWorldPositionOfEntityBone(entity, boneId)
      local distance = #(coords - bonePos)
      if closestBone == -1 or distance < closestDistance then
        closestBone, closestDistance, closestPos, closestBoneName = boneId, distance, bonePos, boneName
      end
    end
  end

  if closestBone ~= -1 then
    return closestBone, closestPos, closestBoneName
  end

  return false
end

exports('CheckBones', CheckBones)

local function EnableTarget()
  if not allowTarget or success or IsNuiFocused() or IsPauseMenuActive() or isExternalUiOpen()
    or (Config.DisableInVehicle and IsPedInAnyVehicle(playerPed or PlayerPedId(), false)) then
    return
  end
  if targetActive then return end

  targetActive = true
  playerPed = PlayerPedId()
  screen.ratio = GetAspectRatio(true)
  screen.fov = GetFinalRenderedCamFov()

  SendNUIMessage({ response = 'openTarget', hint = MZTargetText('target.hint') })

  CreateThread(function()
    repeat
      SetPauseMenuActive(false)
      if Config.DisableControls then
        DisableAllControlActions(0)
      else
        DisableControlAction(0, 1, true)
        DisableControlAction(0, 2, true)
        DisableControlAction(0, 4, true)
        DisableControlAction(0, 5, true)
        DisableControlAction(0, 6, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 24, true)
      end

      EnableControlAction(0, 30, true)
      EnableControlAction(0, 31, true)

      if not hasFocus then
        EnableControlAction(0, 1, true)
        EnableControlAction(0, 2, true)
      end

      Wait(0)
    until not targetActive
  end)

  local flag = 30
  local uiCheckAt = 0

  while targetActive do
    local sleep = 0

    -- Another MZ UI (phone, inventory, radial, pause) takes priority. Check
    -- every 250 ms instead of calling cross-resource exports every frame.
    if GetGameTimer() - uiCheckAt >= 250 then
      uiCheckAt = GetGameTimer()
      if IsPauseMenuActive() or isExternalUiOpen() then
        DisableTarget(true)
        break
      end
    end

    if flag == 30 then flag = -1 else flag = 30 end

    local coords, distance, entity, entityType = RaycastCamera(flag)
    if distance <= Config.MaxDistance then
      if entityType > 0 then
        -- Local (non-networked) entity targets.
        if Entities[entity] then
          CheckEntity(flag, Entities[entity], entity, distance)
        end

        -- Owned entity targets.
        if NetworkGetEntityIsNetworked(entity) then
          local data = Entities[NetworkGetNetworkIdFromEntity(entity)]
          if data then CheckEntity(flag, data, entity, distance) end
        end

        -- Player and ped targets.
        if entityType == 1 then
          local data = Models[GetEntityModel(entity)]
          if IsPedAPlayer(entity) then data = Players end
          if data and next(data) then CheckEntity(flag, data, entity, distance) end

        -- Vehicle bones and models.
        elseif entityType == 2 then
          local closestBone, _, closestBoneName = CheckBones(coords, entity, Bones.Vehicle)
          local datatable = Bones.Options[closestBoneName]

          if datatable and next(datatable) and closestBone then
            local slot = SetupOptions(datatable, entity, distance)
            if next(nuiData) then
              success = true
              SendNUIMessage({ response = 'foundTarget', data = nuiData[slot].targeticon, options = nuiData })
              DrawOutlineEntity(entity, true)
              while targetActive and success do
                local coords2, dist, entity2 = RaycastCamera(flag)
                if entity == entity2 then
                  local closestBone2 = CheckBones(coords2, entity, Bones.Vehicle)
                  if closestBone ~= closestBone2 then
                    LeftTarget()
                    DrawOutlineEntity(entity, false)
                    break
                  elseif not hasFocus and IsDisabledControlPressed(0, Config.MenuControlKey) then
                    EnableNUI(nuiData)
                    DrawOutlineEntity(entity, false)
                  else
                    for optionDistance, enabled in pairs(sendDistance) do
                      if enabled and dist > optionDistance then
                        LeftTarget()
                        DrawOutlineEntity(entity, false)
                        break
                      end
                    end
                  end
                else
                  LeftTarget()
                  DrawOutlineEntity(entity, false)
                  break
                end
                Wait(0)
              end
              LeftTarget()
              DrawOutlineEntity(entity, false)
            end
          end

          local data = Models[GetEntityModel(entity)]
          if data then CheckEntity(flag, data, entity, distance) end

        -- Object targets.
        elseif entityType > 2 then
          local data = Models[GetEntityModel(entity)]
          if data then CheckEntity(flag, data, entity, distance) end
        end

        -- Generic targets.
        if not success then
          local data = Types[entityType]
          if data and next(data) then CheckEntity(flag, data, entity, distance) end
        end
      else
        sleep = sleep + 20
      end
    else
      sleep = sleep + 20
    end

    Wait(sleep)
  end

  DisableTarget(false)
end

-- Registration ---------------------------------------------------------------

local function SetOptions(tbl, distance, options, owner)
  for _, option in pairs(options or {}) do
    local label = type(option) == 'table' and tostring(option.label or '') or ''
    if label ~= '' then
      local copy = copyOption(option)
      if not copy.distance or copy.distance > distance then
        copy.distance = distance
      end

      if owner then
        forgetOwnerLabel(owner, tbl, label)
      end

      tbl[label] = copy
      rememberOwner(owner, tbl, label, copy)
    else
      debugPrint('option_without_label', owner)
    end
  end
end

local function AddTargetBone(bones, parameters, owner)
  local distance, options = parameters.distance or Config.MaxDistance, parameters.options or {}
  if type(bones) == 'table' then
    for _, bone in pairs(bones) do
      Bones.Options[bone] = Bones.Options[bone] or {}
      SetOptions(Bones.Options[bone], distance, options, owner)
    end
  elseif type(bones) == 'string' then
    Bones.Options[bones] = Bones.Options[bones] or {}
    SetOptions(Bones.Options[bones], distance, options, owner)
  end
end

local function RemoveTargetBone(bones, labels, owner)
  local function removeFromBone(bone)
    local tbl = Bones.Options[bone]
    if not tbl then return end
    if labels then
      local list = type(labels) == 'table' and labels or { labels }
      for _, label in pairs(list) do
        if owner then forgetOwnerLabel(owner, tbl, label) end
        tbl[label] = nil
      end
    else
      if owner then removeOwnerOptions(owner) end
      Bones.Options[bone] = nil
    end
  end

  if type(bones) == 'table' then
    for _, bone in pairs(bones) do removeFromBone(bone) end
  else
    removeFromBone(bones)
  end
end

local function AddTargetEntity(entities, parameters, owner)
  local distance, options = parameters.distance or Config.MaxDistance, parameters.options or {}

  local function addEntity(entity)
    if NetworkGetEntityIsNetworked(entity) then
      entity = NetworkGetNetworkIdFromEntity(entity)
    end
    Entities[entity] = Entities[entity] or {}
    SetOptions(Entities[entity], distance, options, owner)
  end

  if type(entities) == 'table' then
    for _, entity in pairs(entities) do addEntity(entity) end
  elseif type(entities) == 'number' then
    addEntity(entities)
  end
end

local function RemoveTargetEntity(entities, labels, owner)
  local function removeEntity(entity)
    if NetworkGetEntityIsNetworked(entity) then
      entity = NetworkGetNetworkIdFromEntity(entity)
    end
    local tbl = Entities[entity]
    if not tbl then return end
    if labels then
      local list = type(labels) == 'table' and labels or { labels }
      for _, label in pairs(list) do
        if owner then forgetOwnerLabel(owner, tbl, label) end
        tbl[label] = nil
      end
    else
      if owner then removeOwnerOptions(owner) end
      Entities[entity] = nil
    end
  end

  if type(entities) == 'table' then
    for _, entity in pairs(entities) do removeEntity(entity) end
  elseif type(entities) == 'number' then
    removeEntity(entities)
  end
end

local function AddTargetModel(models, parameters, owner)
  local distance, options = parameters.distance or Config.MaxDistance, parameters.options or {}

  local function addModel(model)
    if type(model) == 'string' then model = joaat(model) end
    Models[model] = Models[model] or {}
    SetOptions(Models[model], distance, options, owner)
  end

  if type(models) == 'table' then
    for _, model in pairs(models) do addModel(model) end
  else
    addModel(models)
  end
end

local function RemoveTargetModel(models, labels, owner)
  local function removeModel(model)
    if type(model) == 'string' then model = joaat(model) end
    local tbl = Models[model]
    if not tbl then return end
    if labels then
      local list = type(labels) == 'table' and labels or { labels }
      for _, label in pairs(list) do
        if owner then forgetOwnerLabel(owner, tbl, label) end
        tbl[label] = nil
      end
    else
      if owner then removeOwnerOptions(owner) end
      Models[model] = nil
    end
  end

  if type(models) == 'table' then
    for _, model in pairs(models) do removeModel(model) end
  else
    removeModel(models)
  end
end

local function AddGlobalType(typ, parameters, owner)
  local distance, options = parameters.distance or Config.MaxDistance, parameters.options or {}
  SetOptions(Types[typ], distance, options, owner)
end

local function RemoveGlobalType(typ, labels, owner)
  local tbl = Types[typ]
  if not tbl then return end
  if labels then
    local list = type(labels) == 'table' and labels or { labels }
    for _, label in pairs(list) do
      if owner then forgetOwnerLabel(owner, tbl, label) end
      tbl[label] = nil
    end
  else
    if owner then removeOwnerOptions(owner) end
    Types[typ] = {}
  end
end

local function AddGlobalPed(parameters, owner) AddGlobalType(1, parameters, owner) end
local function AddGlobalVehicle(parameters, owner) AddGlobalType(2, parameters, owner) end
local function AddGlobalObject(parameters, owner) AddGlobalType(3, parameters, owner) end

local function AddGlobalPlayer(parameters, owner)
  local distance, options = parameters.distance or Config.MaxDistance, parameters.options or {}
  SetOptions(Players, distance, options, owner)
end

local function RemoveGlobalPlayer(labels, owner)
  if labels then
    local list = type(labels) == 'table' and labels or { labels }
    for _, label in pairs(list) do
      if owner then forgetOwnerLabel(owner, Players, label) end
      Players[label] = nil
    end
  else
    if owner then removeOwnerOptions(owner) end
    Players = {}
  end
end

exports('AddTargetBone', function(bones, parameters)
  AddTargetBone(bones, parameters, resolveOwner())
end)
exports('RemoveTargetBone', function(bones, labels)
  RemoveTargetBone(bones, labels, resolveOwner())
end)
exports('AddTargetEntity', function(entities, parameters)
  AddTargetEntity(entities, parameters, resolveOwner())
end)
exports('RemoveTargetEntity', function(entities, labels)
  RemoveTargetEntity(entities, labels, resolveOwner())
end)
exports('AddTargetModel', function(models, parameters)
  AddTargetModel(models, parameters, resolveOwner())
end)
exports('RemoveTargetModel', function(models, labels)
  RemoveTargetModel(models, labels, resolveOwner())
end)
exports('AddGlobalPed', function(parameters) AddGlobalPed(parameters, resolveOwner()) end)
exports('RemoveGlobalPed', function(labels) RemoveGlobalType(1, labels, resolveOwner()) end)
exports('AddGlobalVehicle', function(parameters) AddGlobalVehicle(parameters, resolveOwner()) end)
exports('RemoveGlobalVehicle', function(labels) RemoveGlobalType(2, labels, resolveOwner()) end)
exports('AddGlobalObject', function(parameters) AddGlobalObject(parameters, resolveOwner()) end)
exports('RemoveGlobalObject', function(labels) RemoveGlobalType(3, labels, resolveOwner()) end)
exports('AddGlobalPlayer', function(parameters) AddGlobalPlayer(parameters, resolveOwner()) end)
exports('RemoveGlobalPlayer', function(labels) RemoveGlobalPlayer(labels, resolveOwner()) end)

-- Read-only getters kept from the qb-target API.
exports('GetTargetBoneData', function(bone, label)
  return Bones.Options[bone] and Bones.Options[bone][label] or nil
end)
exports('GetTargetEntityData', function(entity, label)
  return Entities[entity] and Entities[entity][label] or nil
end)
exports('GetTargetModelData', function(model, label)
  if type(model) == 'string' then model = joaat(model) end
  return Models[model] and Models[model][label] or nil
end)
exports('GetGlobalPedData', function(label) return Types[1][label] end)
exports('GetGlobalVehicleData', function(label) return Types[2][label] end)
exports('GetGlobalObjectData', function(label) return Types[3][label] end)
exports('GetGlobalPlayerData', function(label) return Players[label] end)

-- NUI callbacks --------------------------------------------------------------

RegisterNUICallback('selectTarget', function(option, cb)
  option = tonumber(option) or option
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)
  Wait(100)
  targetActive, success, hasFocus = false, false, false
  if not next(sendData) then
    cb('ok')
    return
  end

  local data = sendData[option]
  if not data then
    cb('ok')
    return
  end

  table_wipe(sendData)

  if data.entity and data.entity ~= 0 and not DoesEntityExist(data.entity) then
    cb('ok')
    return
  end

  -- Revalidate the option before dispatch. The option may have been hidden by
  -- its owner while the list was open; never execute a hidden action.
  if data.entity and data.entity ~= 0 then
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - GetEntityCoords(data.entity))
    if data.distance and distance > data.distance + 6.0 then
      cb('ok')
      return
    end
    if data.canInteract then
      local ok, allowed = pcall(data.canInteract, data.entity, data.distance, data)
      if not ok or allowed ~= true then
        cb('ok')
        return
      end
    end
  end

  CreateThread(function()
    Wait(0)
    if data.entity ~= nil then
      data.coords = GetEntityCoords(data.entity)
    end
    if data.action then
      data.action(data.entity)
    elseif data.event then
      if data.type == 'client' then
        TriggerEvent(data.event, data)
      elseif data.type == 'server' then
        TriggerServerEvent(data.event, data)
      elseif data.type == 'command' then
        ExecuteCommand(data.event)
      else
        TriggerEvent(data.event, data)
      end
    else
      error('No trigger setup')
    end
  end)

  cb('ok')
end)

RegisterNUICallback('closeTarget', function(_, cb)
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)
  Wait(100)
  targetActive, success, hasFocus = false, false, false
  cb('ok')
end)

RegisterNUICallback('leftTarget', function(_, cb)
  if Config.Toggle then
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    Wait(100)
    table_wipe(sendData)
    success, hasFocus = false, false
  else
    DisableTarget(true)
  end
  cb('ok')
end)

-- Startup --------------------------------------------------------------------

CreateThread(function()
  if Config.Toggle then
    RegisterCommand('mzTarget', function()
      if targetActive then
        DisableTarget(true)
      else
        CreateThread(EnableTarget)
      end
    end, false)
    RegisterKeyMapping('mzTarget', MZTargetText('target.keymapping'), 'keyboard', Config.OpenKey)
    TriggerEvent('chat:removeSuggestion', '/mzTarget')
  else
    RegisterCommand('+mzTarget', function()
      CreateThread(EnableTarget)
    end, false)
    RegisterCommand('-mzTarget', DisableTarget, false)
    RegisterKeyMapping('+mzTarget', MZTargetText('target.keymapping'), 'keyboard', Config.OpenKey)
    TriggerEvent('chat:removeSuggestion', '/+mzTarget')
    TriggerEvent('chat:removeSuggestion', '/-mzTarget')
  end
end)

-- Misc. exports --------------------------------------------------------------

local function IsTargetActive() return targetActive end
exports('IsTargetActive', IsTargetActive)

local function IsTargetSuccess() return success end
exports('IsTargetSuccess', IsTargetSuccess)

local function AllowTargeting(bool)
  allowTarget = bool
  if allowTarget then return end
  DisableTarget(true)
end

exports('AllowTargeting', AllowTargeting)

-- Used by the existing police radial entry ("Selecionar cidadão"). Keeps the
-- radial contract intact without adding a new radial menu.
exports('StartTargeting', function()
  if targetActive then return true end
  if not allowTarget or success or IsNuiFocused() or IsPauseMenuActive() or isExternalUiOpen() then
    return false
  end
  CreateThread(EnableTarget)
  return true
end)

-- Lifecycle ------------------------------------------------------------------

CreateThread(function()
  Wait(0)
  TriggerEvent('mz_target:client:ready')
end)

AddEventHandler('onClientResourceStart', function(resourceName)
  if resourceName ~= currentResourceName then return end
  CreateThread(function()
    Wait(0)
    TriggerEvent('mz_target:client:ready')
  end)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
  if resourceName == currentResourceName then return end
  if removeOwnerOptions(resourceName) and hasFocus then
    DisableTarget(true)
  end
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= currentResourceName then return end
  targetActive, success, hasFocus = false, false, false
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)
  SendNUIMessage({ response = 'closeTarget' })
end)
