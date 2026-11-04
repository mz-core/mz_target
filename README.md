# mz_target

Detecção e despacho de interações contextuais do MZ Framework. O motor de
raycast/seleção e a NUI são baseados no **qb-target 5.5.0** (GPL-3.0), com
adaptações mínimas para o MZ. Leia `NOTICE.md` e `LICENSE`.

`mz_target` não possui regra de negócio de inventário, veículo ou polícia.
Cada resource registra suas ações em `client/target.lua` e mantém suas próprias
validações server-authoritative.

## Uso

- Segure `ALT ESQ` e mire em uma entidade.
- As opções aparecem ao lado da mira.
- Clique com o botão direito para liberar o cursor e clique em uma opção.
- `ESC` fecha. O radial (F3) e o MDT continuam em `mz_radialmenu`/`mz_police`.

`mz_interact` continua sendo o dono de zonas. O `mz_target` não registra
PolyZone nem varre zonas.

## API de registro (padrão qb-target)

```lua
-- opção global para qualquer jogador
exports['mz_target']:AddGlobalPlayer({
  distance = 2.5,
  options = {
    {
      label = 'Ação',
      icon = 'badge', -- nome lucide opcional
      distance = 2.5,
      canInteract = function(entity, distance, data) return true end,
      action = function(entity) end
    }
  }
})

-- opção por osso de veículo
exports['mz_target']:AddTargetBone('boot', {
  distance = 3.0,
  options = { { label = 'Abrir porta-malas', action = function(vehicle) end } }
})

-- opção por modelo de objeto
exports['mz_target']:AddTargetModel({ 'prop_example' }, {
  distance = 3.0,
  options = { { label = 'Usar', action = function(entity) end } }
})
```

Remoção por label (não apaga opções de outros resources):

```lua
exports['mz_target']:RemoveTargetBone('boot', 'Abrir porta-malas')
exports['mz_target']:RemoveTargetModel({ 'prop_example' }, 'Usar')
exports['mz_target']:RemoveGlobalPlayer('Ação')
```

Opções também aceitam `event`, `type = 'client' | 'server' | 'command'` quando
o consumidor preferir evento a callback. `canInteract(entity, distance, data)`
é executado no cliente; a validação definitiva continua no servidor do owner.

O registro é idempotente por owner + label: reiniciar o resource substitui sua
opção anterior. Quando um resource para, o `mz_target` remove somente as opções
daquele owner.

## Drops do inventário

O `mz_target` apresenta o prop físico dos world drops, mas o `mz_inventory`
continua dono do `drop_uid`, conteúdo e transferências. O `mz_inventory` usa:

```lua
local dropUid = exports['mz_target']:GetWorldDropByEntity(entity)
```

A export só retorna UID para o prop exato criado para um drop real. Um prop
parecido do mapa retorna `nil`, então a opção "Abrir bolsa" não aparece.

## Locales

A língua é global do servidor, via `ox:locale` (mesmo mecanismo do
`mz_radialmenu`). O padrão é `pt-br`.

```cfg
setr ox:locale pt-br
-- ou
setr ox:locale en
```

Arquivos: `mz_target/locales/pt-br.json`, `en.json` e `en-us.json`. Cada
resource consumidor mantém as traduções das próprias ações.

## Exports de engine

- `AddGlobalPlayer`, `AddGlobalVehicle`, `AddGlobalPed`, `AddGlobalObject`
- `RemoveGlobalPlayer`, `RemoveGlobalVehicle`, `RemoveGlobalPed`, `RemoveGlobalObject`
- `AddTargetEntity`, `RemoveTargetEntity`
- `AddTargetModel`, `RemoveTargetModel`
- `AddTargetBone`, `RemoveTargetBone`
- `StartTargeting`, `AllowTargeting`, `IsTargetActive`, `IsTargetSuccess`
- `RaycastCamera`, `CheckEntity`, `CheckBones`, `DrawOutlineEntity`
- `EnableNUI`, `DisableNUI`, `LeftTarget`, `DisableTarget`
- `GetWorldDropByEntity`, `GetWorldDropModels`

## Start

```cfg
ensure ox_lib
ensure mz_target
ensure mz_inventory
ensure mz_vehicles
ensure mz_police
```

`mz_target` não depende de `qb-core` nem de `PolyZone`.
