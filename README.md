# mz_target

Camada de target visual para `mz_core` e `mz_inventory`.

## Dependencias

- `ox_lib`
- `mz_core`
- `mz_inventory`

## Como iniciar

Como este recurso continua isolado, inicie manualmente com:

```cfg
ensure mz_target
```

## O que ele faz

- segura `ALT ESQ` para abrir o modo target
- mostra o "olho" no centro da tela enquanto o target estiver ativo
- destaca o alvo quando o player mira em um `world drop`, `trunk` ou `glovebox`
- usa clique esquerdo para executar a acao do alvo atual
- abre `trunk` ao mirar na traseira do veiculo
- abre `glovebox` ao mirar nas portas dianteiras
- sincroniza criacao e remocao das bolsas de drop usando os eventos do `mz_core`

## Fluxo esperado

1. Abra o inventario.
2. Use a acao `Largar no chao` em um item do player.
3. O `mz_core` cria ou reutiliza um `world drop`.
4. O `mz_target` materializa a bolsa no mundo.
5. Segure `ALT ESQ`, mire na bolsa e use clique esquerdo para abrir.
