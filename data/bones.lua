-- Based on qb-target 5.5.0 data/bones.lua by BerkieB (GPL-3.0).
-- Modified for MZ: default door options are disabled; hashes use joaat().
local Bones = { Options = {}, Vehicle = { 'chassis', 'windscreen', 'seat_pside_r', 'seat_dside_r', 'bodyshell', 'suspension_lm', 'suspension_lr', 'platelight', 'attach_female', 'attach_male', 'bonnet', 'boot', 'chassis_dummy', 'chassis_Control', 'door_dside_f', 'door_dside_r', 'door_pside_f', 'door_pside_r', 'Gun_GripR', 'windscreen_f', 'platelight', 'VFX_Emitter', 'window_lf', 'window_lr', 'window_rf', 'window_rr', 'engine', 'gun_ammo', 'ROPE_ATTATCH', 'wheel_lf', 'wheel_lr', 'wheel_rf', 'wheel_rr', 'exhaust', 'overheat', 'seat_dside_f', 'seat_pside_f', 'Gun_Nuzzle', 'seat_r' } }

if Config.EnableDefaultOptions then
    local BackEngineVehicles = {
        [joaat('ninef')] = true,
        [joaat('adder')] = true,
        [joaat('vagner')] = true,
        [joaat('t20')] = true,
        [joaat('infernus')] = true,
        [joaat('zentorno')] = true,
        [joaat('reaper')] = true,
        [joaat('comet2')] = true,
        [joaat('comet3')] = true,
        [joaat('jester')] = true,
        [joaat('jester2')] = true,
        [joaat('cheetah')] = true,
        [joaat('cheetah2')] = true,
        [joaat('prototipo')] = true,
        [joaat('turismor')] = true,
        [joaat('pfister811')] = true,
        [joaat('ardent')] = true,
        [joaat('nero')] = true,
        [joaat('nero2')] = true,
        [joaat('tempesta')] = true,
        [joaat('vacca')] = true,
        [joaat('bullet')] = true,
        [joaat('osiris')] = true,
        [joaat('entityxf')] = true,
        [joaat('turismo2')] = true,
        [joaat('fmj')] = true,
        [joaat('re7b')] = true,
        [joaat('tyrus')] = true,
        [joaat('italigtb')] = true,
        [joaat('penetrator')] = true,
        [joaat('monroe')] = true,
        [joaat('ninef2')] = true,
        [joaat('stingergt')] = true,
        [joaat('surfer')] = true,
        [joaat('surfer2')] = true,
        [joaat('gp1')] = true,
        [joaat('autarch')] = true,
        [joaat('tyrant')] = true
    }

    local function ToggleDoor(vehicle, door)
        if GetVehicleDoorLockStatus(vehicle) < 2 then
            if GetVehicleDoorAngleRatio(vehicle, door) > 0.0 then
                SetVehicleDoorShut(vehicle, door, false)
            else
                SetVehicleDoorOpen(vehicle, door, false)
            end
        end
    end

    Bones.Options['seat_dside_f'] = {
        ['Toggle Front Door'] = {
            icon = 'fas fa-door-open',
            label = 'Toggle Front Door',
            canInteract = function(entity)
                return GetEntityBoneIndexByName(entity, 'door_dside_f') ~= -1
            end,
            action = function(entity)
                ToggleDoor(entity, 0)
            end,
            distance = 1.2
        },
    }

    Bones.Options['seat_pside_f'] = {
        ['Toggle Front Door'] = {
            icon = 'fas fa-door-open',
            label = 'Toggle Front Door',
            canInteract = function(entity)
                return GetEntityBoneIndexByName(entity, 'door_pside_f') ~= -1
            end,
            action = function(entity)
                ToggleDoor(entity, 1)
            end,
            distance = 1.2
        }
    }

    Bones.Options['seat_dside_r'] = {
        ['Toggle Rear Door'] = {
            icon = 'fas fa-door-open',
            label = 'Toggle Rear Door',
            canInteract = function(entity)
                return GetEntityBoneIndexByName(entity, 'door_dside_r') ~= -1
            end,
            action = function(entity)
                ToggleDoor(entity, 2)
            end,
            distance = 1.2
        }
    }

    Bones.Options['seat_pside_r'] = {
        ['Toggle Rear Door'] = {
            icon = 'fas fa-door-open',
            label = 'Toggle Rear Door',
            canInteract = function(entity)
                return GetEntityBoneIndexByName(entity, 'door_pside_r') ~= -1
            end,
            action = function(entity)
                ToggleDoor(entity, 3)
            end,
            distance = 1.2
        }
    }

    Bones.Options['bonnet'] = {
        ['Toggle Hood'] = {
            icon = 'fa-duotone fa-engine',
            label = 'Toggle Hood',
            action = function(entity)
                ToggleDoor(entity, BackEngineVehicles[GetEntityModel(entity)] and 5 or 4)
            end,
            distance = 0.9
        }
    }

    Bones.Options['boot'] = {
        ['Toggle Trunk'] = {
            icon = 'fas fa-truck-ramp-box',
            label = 'Toggle Trunk',
            action = function(entity)
                ToggleDoor(entity, BackEngineVehicles[GetEntityModel(entity)] and 4 or 5)
            end,
            distance = 0.9
        }
    }
end

return Bones
