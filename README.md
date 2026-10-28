# Zumbi FPS — protótipo (Godot 4.7.2)

Primeira pessoa, combate corpo a corpo, zumbis com animação procedural,
reação física a golpes e ragdoll (estilo Dying Light), visual de PC dos anos 2000 em 960x540 (16:9).

## Como abrir
1. Godot 4.7.2 → **Importar** → selecione `project.godot`.
2. **F5** para rodar.

## Controles
| Tecla | Ação |
|---|---|
| WASD / Shift / Espaço | mover / correr / pular |
| Clique esquerdo (espada/taco) | combo: direita→esquerda, esquerda→direita, de cima para baixo (x1.5) |
| Shift + segurar clique (espada) | **empalar**: corre com a lâmina para frente espetando até 3 zumbis; parou de correr ou soltou → chuta todos para fora |
| Clique esquerdo (pistola) | tiro (12 balas; R recarrega; cabeça mata com um tiro) |
| Clique esquerdo (cajado) | míssil mágico explosivo — segure para disparar sem parar |
| 1 / 2 / 3 / 4 | espada / taco / cajado / pistola (Q ou roda do mouse alterna) |
| F | chute em área: pega todos à frente (~70° para cada lado, 2.4 m) e joga longe |
| E | pegar item (gancho para o inventário) |
| Z | cria um zumbi na sua frente (teste) |
| Backspace | recomeça · Esc solta o mouse |

## Estrutura
```
scenes/
  main.tscn            fase em CSG (blockout, editável no editor)
  player.tscn          CharacterBody3D + câmera + arma
  zombie.tscn          CharacterBody3D + Skeleton3D com os módulos abaixo
  ui/hud.tscn          vida, stamina, mira, avisos (CanvasLayer 2)
  ui/retro_screen.tscn pós-processamento (CanvasLayer 1, não afeta o HUD)
scripts/enemies/
  zombie.gd            IA, vida, dano por osso, equilíbrio, estados (andar, atacar, tranco, cambalear, cair, levantar, morrer)
  humanoid_rig.gd      monta o boneco de teste (ossos, visual, hitboxes, ossos físicos)
  zombie_locomotion.gd animação procedural (andar, ataque, inclinação, agachar, cambaleio, joelho cedendo)
  hit_reaction.gd      SkeletonModifier3D: tronco tomba e volta como mola (pernas de fora)
  limp_limbs.gd        SkeletonModifier3D: membros quebrados pendurados (pêndulos)
  ragdoll.gd           PhysicalBoneSimulator3D: liga/desliga física, impulsos, blend para levantar
scripts/player/player.gd   player, espada, cajado, chute, interação
scripts/weapons/           míssil mágico e explosão
scripts/effects/impact_fx.gd  sangue, faíscas, rastro de bala
scripts/combat/hit_info.gd    dados de um golpe (dano, osso, força, tipo CUT/BLUNT/PIERCE, bias)
shaders/retro_screen.gdshader
tests/                 testes headless (ragdoll, juntas, jogo)
```

## Camadas de colisão
| # | Nome | Quem usa |
|---|---|---|
| 1 | mundo | chão, paredes, caixas |
| 2 | player | player |
| 3 | inimigo | cápsula do zumbi (de pé) |
| 4 | ragdoll | ossos físicos (só quando caído/morto) |
| 5 | hitbox | Area3D por osso (só de pé) |
| 6 | interagivel | itens que dá para pegar |

## Como funciona o combate
1. Cada golpe é um **arco**: a lâmina gira em volta de um eixo (tabela `SWINGS` em `player.gd`)
   em três fases — preparação, corte e volta para a guarda — com rastro do corte na tela.
2. Durante o corte, raios seguem a lâmina pelo trecho do arco percorrido a cada frame.
   Acertou a **hitbox** de um osso → `Zombie.take_hit(HitInfo)`;
   a direção é para onde a lâmina se move, então o zumbi é empurrado para o lado do corte.
   Um corte atravessa até 2 inimigos (`max_targets`).
3. Atacar **não gasta stamina** (stamina é só para correr).
4. Dependendo do golpe:
   - **Tronco**: a reação física (`HitReaction`) atua só da cintura para cima — o tronco é
     jogado na direção do golpe e volta para cima como mola, braços chicoteiam.
     **Pernas ficam firmes**: o corpo agacha dobrando os joelhos com os pés no lugar.
   - **Equilíbrio** (`balance` em `zombie.gd`): cada golpe tira equilíbrio, golpe na perna tira
     mais e faz o joelho ceder. O equilíbrio volta sozinho com o tempo.
     - abaixo de `stumble_at` → tranco curto, já volta a atacar;
     - acima de `stumble_at` → **cambaleia como bêbado**: passos em ziguezague para trás,
       tronco inclinado, braços abertos, quase cai;
     - acima de `fall_at` (ou apanhou cambaleando) → cai em ragdoll e depois levanta.
   - **Tranco**: um ou dois passos para trás (dois com golpe forte, como o taco).
   - **Membros com vida própria** (cabeça 70, braço 35, perna 50 — grupo "Membros" no
     inspetor do Zombie). Quando a vida do membro acaba:
     - **corte** (espada) → o membro **sai voando** (corpo físico, toco sangrando);
     - **impacto** (taco, chute) ou **tiro** → o osso **quebra**: o membro fica mole,
       balançando como ragdoll (`limp_limbs.gd`);
     - cabeça destruída mata; braço inutilizado = ataque mais fraco;
     - **perna arrancada ou quebrada** → o zumbi cai e passa a **rastejar** (mais lento,
       cápsula deitada, ataca mais fraco).
   - **Golpes da espada favorecem membros diferentes** (`bias` em `SWINGS`, `player.gd`):
     horizontais decepam cabeça (2x) e pernas (1.8x) conforme a altura em que pegam;
     o golpe de cima arranca braços (2.4x).
   - **Impacto derruba mais**: taco e chute tiram 1.45x mais equilíbrio
     (`blunt_balance_multiplier`); tiro tira metade.
   - **Explosão que mata despedaça o corpo inteiro**: cabeça, braços e pernas voam.
   - **Levantar em etapas** (poses procedurais em `zombie_locomotion.gd`): de bruços →
     apoio nas mãos e joelhos → ajoelhado → de pé; de costas → senta → agacha → de pé.
     Dá para derrubar de novo no meio. Quem rasteja volta direto a rastejar.
   - **Morte** → ragdoll permanente; continua dando para bater/chutar o corpo.
5. O *hitstop* (jogo quase para por 50–70 ms) e o tremor de câmera dão peso ao impacto.

## Modelo do player
- `scenes/player.tscn` → `Body/Skeleton3D`: o mesmo boneco em blocos dos zumbis (`HumanoidRig`,
  sem hitboxes), animado por `scripts/player/player_body.gd` (pernas andam/correm na direção do
  movimento, pulo dobra os joelhos).
- Olhando para baixo você vê as pernas; cabeça, tronco e braços do corpo só projetam **sombra**
  (`shadow_only_bones`) para não tapar a câmera.
- Braço em primeira pessoa (`_update_fp_arm` em `player.gd`): a mão segue a empunhadura da arma
  atual e o antebraço liga o ombro (fora da tela) até ela.

## Cajado e míssil mágico
- `scripts/weapons/magic_missile.gd`: voa a 24 m/s, curva de leve atrás do zumbi mais próximo
  à frente (`homing_turn`, `homing_cone`) e explode ao tocar em qualquer coisa.
- `scripts/weapons/explosion.gd`: **morte instantânea** até 1.3 m do impacto (medido até o
  ponto mais próximo do corpo — explosão no pé conta); até 3.5 m, dano com queda pela distância, joga os zumbis em
  ragdoll (força espalhada por todos os ossos), empurra caixas e treme a tela do player.
- Cadência em `cast_cooldown` (player). Sem mana por enquanto.

## Trocar o boneco por um modelo real (Mixamo, Blender…)
1. Importe o `.glb`/`.fbx` com esqueleto e animações.
2. Em `zombie.tscn`, troque o `Skeleton3D` (e remova `humanoid_rig.gd` e `Locomotion`).
3. Selecione o Skeleton3D do modelo → menu **Skeleton3D → Create Physical Skeleton**.
4. Coloque `ragdoll.gd` no `PhysicalBoneSimulator3D` gerado e ajuste os limites das juntas.
5. Adicione um `HitReaction` (filho do Skeleton3D, **antes** do simulador).
6. Para as hitboxes: `BoneAttachment3D` + `Area3D` (camada 5) com metadados `enemy` e `bone`.
7. Troque `locomotion.speed/attack/swing` em `zombie.gd` por parâmetros de um `AnimationTree`.
8. Atualize `BONE_DAMAGE` / `LEG_BONES` com os nomes de ossos do modelo.

## Visual 960x540 (16:9)
- `display/window/stretch/mode = viewport` → tudo (3D e UI) é renderizado em 960x540 e ampliado
  (escala exata 2x em 1080p e 4x em 4K).
- Para a versão 4:3 antiga, use 800x600.
- Texturas com filtro *Nearest + mipmaps*; o shader reduz para 32 níveis por canal com dithering.
- Ajuste as cores/intensidade no material de `ui/retro_screen.tscn`.

## Inventário / crafting (próximo passo)
- O player já emite `item_picked_up(item_id, amount)` e reserva a ação `inventory` (Tab).
- Sugestão: um autoload `Inventory` com `Dictionary` de itens + `Resource` para receitas;
  a UI entra como outra `CanvasLayer` (layer 3), já em 960x540, legível.

## Testes headless
```bash
godot --headless -s res://tests/test_game.gd
```
