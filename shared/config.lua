-- Based on qb-target 5.5.0 by BerkieB (GPL-3.0).
-- Modified for MZ Framework on 2026-10-20: removed PolyZone, QBCore,
-- ped spawner and qtarget interoperability; added MZ world-drop presentation.
Config = {}

-- Maximum interaction distance measured from the player to the ray hit.
Config.MaxDistance = 7.0
Config.Debug = false

-- Draw an outline around the targeted entity.
Config.EnableOutline = false
Config.OutlineColor = { 255, 255, 255, 255 }

-- false: hold the key to target. true: toggle with the key.
Config.Toggle = false

-- qb-target's built-in vehicle door options are disabled. MZ resources own
-- their vehicle interactions through their own client/target.lua.
Config.EnableDefaultOptions = false

-- Keep the target available inside vehicles; consumers still filter actions.
Config.DisableInVehicle = false

-- Left Alt. FiveM input mapper name, not a control index.
Config.OpenKey = 'LMENU'

-- Right mouse button while the interaction list is open.
Config.MenuControlKey = 238

-- Disable all controls while targeting, like qb-target.
Config.DisableControls = true

-- MZ world drops are presented by mz_target, but opened only by mz_inventory.
Config.Drop = {
  prop_model = 'bkr_prop_duffel_bag_01a',
  fallback_prop_model = 'prop_cs_heist_bag_02',
  stream_distance = 120.0,
  heading_offset = 0.0
}
