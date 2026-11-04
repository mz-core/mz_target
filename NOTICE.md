# mz_target attribution and license notice

`mz_target` incorporates code from **qb-target 5.5.0** by **BerkieB**
(https://github.com/qbcore-framework/qb-target), licensed under the
**GNU General Public License v3.0**. The full license text is in `LICENSE`.

The following files are derived from qb-target and were modified for the MZ
Framework on 2026-10-20:

- `client/init.lua` (qb-target `init.lua`)
- `client/main.lua` (qb-target `client.lua`)
- `data/bones.lua`
- `web/index.html`, `web/style.css`, `web/app.js` (qb-target NUI)

Modifications:

- removed the PolyZone dependency and all zone targets (`mz_interact` owns MZ zones);
- removed the QBCore job/gang/item/citizenid integration and the ped spawner;
- removed qtarget interoperability exports that have no MZ consumer;
- added owner-aware registration so resource restarts remove only their own options;
- added the ox_lib locale keys and the MZ world-drop prop presentation.

The MZ Framework additions remain subject to the same GPL-3.0 obligations when
this resource is distributed, because they are part of a work based on
qb-target. Do not remove this notice or the license text.

qb-target itself credits qtarget, bt-target and ms-peds in its README. Those
credits are preserved by reference here.
