-- Based on qb-target 5.5.0 by BerkieB (GPL-3.0), init.lua.
-- Modified for MZ Framework: no QBCore job/gang/item checks. MZ resources
-- enforce their own permissions inside each option's canInteract callback.
local currentResourceName = GetCurrentResourceName()
local UTF8_BOM = string.char(239, 187, 191)

function Load(name)
  local file = ('data/%s.lua'):format(name)
  local chunk = LoadResourceFile(currentResourceName, file)
  if not chunk then
    error(('[mz_target] bootstrap failed: %s not found'):format(file), 0)
  end

  -- Lua's load() reports a UTF-8 BOM as "unexpected symbol near '<\239>'".
  -- Fail with the real cause instead of a misleading syntax error.
  if chunk:sub(1, #UTF8_BOM) == UTF8_BOM then
    error(('[mz_target] bootstrap failed: %s has a UTF-8 BOM; save it as UTF-8 without BOM'):format(file), 0)
  end

  local compiled, err = load(chunk, ('@@%s/%s'):format(currentResourceName, file), 't')
  if not compiled then
    error(('[mz_target] bootstrap failed: %s\n%s'):format(file, tostring(err)), 0)
  end

  local ok, result = pcall(compiled)
  if not ok then
    error(('[mz_target] bootstrap failed while executing %s:\n%s'):format(file, tostring(result)), 0)
  end

  return result
end

-- CheckOptions must exist before main.lua captures it. Declaring it before
-- Load('bones') also keeps the contract identical to qb-target's init.lua.
function CheckOptions(data, entity, distance)
  if distance and data.distance and distance > data.distance then
    return false
  end

  if data.canInteract then
    local ok, allowed = pcall(data.canInteract, entity, distance, data)
    return ok == true and allowed == true
  end

  return true
end

Bones = Load('bones')

if type(Bones) ~= 'table'
    or type(Bones.Options) ~= 'table'
    or type(Bones.Vehicle) ~= 'table'
    or #Bones.Vehicle == 0 then
  error('[mz_target] bootstrap failed: data/bones.lua must return { Options = {}, Vehicle = { ... } }', 0)
end

if type(CheckOptions) ~= 'function' then
  error('[mz_target] bootstrap failed: CheckOptions is not a function', 0)
end

-- main.lua and drops.lua refuse to expose anything unless this flag is set.
MZTargetBootstrapped = true
