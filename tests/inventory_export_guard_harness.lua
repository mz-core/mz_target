local function expect(condition, message)
  if not condition then error(message, 2) end
end

local file = assert(io.open('client/main.lua', 'rb'))
local source = file:read('*a')
file:close()

local directCalls = 0
for _ in source:gmatch("exports%['mz_inventory'%]:IsOpen%(%)") do
  directCalls = directCalls + 1
end

expect(directCalls == 1, 'IsOpen deve aparecer somente dentro do wrapper protegido')
expect(source:find('local function isInventoryOpen()', 1, true) ~= nil,
  'wrapper de disponibilidade do inventario ausente')
expect(source:find("GetResourceState('mz_inventory') == 'started'", 1, true) ~= nil,
  'estado do recurso nao e validado antes do export')
expect(source:find("pcall(function()\n    return exports['mz_inventory']:IsOpen()", 1, true) ~= nil,
  'IsOpen nao esta protegido contra restart')
expect(source:find('local callOk, ok, resultOrErr = pcall(callback)', 1, true) ~= nil,
  'exports de abertura nao estao protegidos contra restart')

print('inventory_export_guard_harness: ok')
