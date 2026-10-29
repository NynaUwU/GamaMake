# Zumbi FPS — protótipo (Godot 4.7.2)

Primeira pessoa, combate corpo a corpo, zumbis com animação procedural,
reação física a golpes e ragdoll (estilo Dying Light), visual de PC dos anos 2000 em 960x540 (16:9).

## Como abrir
1. Godot 4.7.2 → **Importar** → selecione `project.godot`.
2. **F5** para rodar.

## Controles
| Tecla | Ação |
|---|---|
| WASD / Shift | mover / correr |
| Espaço | pular — de frente para obstáculo: **vault** (correndo, até o quadril e curto), **subir** (comprido ou até um pouco acima da cabeça) ou **pular cerca** |
| C | agachar — **correndo: deslizar** (passa por baixo dos zumbis e derruba quem estiver em cima) |
| Clique esquerdo | atacar com a arma do slot (sem arma: **soco**) |
| Botão direito | **bloquear** (espada/taco). Bloquear logo antes do golpe = parry (zumbi cambaleia) |
| Shift + segurar clique (espada) | **empalar** até 3 zumbis (só de frente ou de costas); parou → chuta todos |
| F | chute em área |
| 1–5 / Q / roda | escolher slot da hotbar |
| Tab | mochila (clique em dois slots para trocar) |
| E / G | pegar / soltar item |
| L | lanterna (precisa estar no inventário) |
| R | recarregar a pistola |
| E (no carro) | entrar/sair. Dirigindo: W/S acelera/ré, A/D vira, Espaço freio de mão |
| Z | novo zumbi (teste) · Backspace recomeça · Esc solta o mouse |

## Área inicial e carro
- Ao lado de onde você nasce: uma bancada coberta (com lâmpada) com **um exemplar de cada arma**
  — espada, taco, cajado e pistola — e a lanterna.
- Estacionado ao lado, virado para a saída sul da cidade: o **carro** (`scenes/vehicles/vintage_car.tscn`,
  `scripts/vehicles/vintage_car.gd`), inspirado no **Alfa Romeo 8C 2300 Monza (1932)**: capô
  comprido com venezianas, grade cromada em "coração", faróis torneados, para-lamas de moto curvos,
  rodas raiadas (pneu, aro, 16 raios cruzados, cubo knock-off), "rabo de barco" com estepe,
  escapamento lateral, feixes de mola, número 8 e volante à direita. Suspensão alta e com curso
  longo para fora de estrada; tração traseira, ~100 km/h.
- **Dirigir é em primeira pessoa**: você senta no banco, olha em volta com o mouse e as mãos
  ficam no volante (que gira com a direção). Sem para-brisa: o **velocímetro** (0–140 km/h,
  ponteiro funcionando) fica embutido no centro do painel.
- Atropelar derruba o zumbi (dano ~7 por m/s; rápido mata e pode arrancar membros).

## Estilo visual
- **Seres vivos** (player, zumbis, animais no futuro) são em **blocos**.
- **Todo o resto** é **poligonal estilo PS2**: poucos lados, sombreamento suave mas silhueta
  facetada — nunca completamente liso. Peças complexas (painel, rodas) podem ter mais polígonos.
- **Mãos** (`scripts/util/blocky_hand.gd`): em blocos, com 4 dedos e polegar. O player segura
  as armas e o volante com a mão fechada; zumbis têm dedos tortos de garra.
- **Temas:**
  - **Carros:** pré-guerra — de corrida (como o Alfa 8C Monza) e, no futuro, civis.
  - **Armas:** **medieval steampunk** — aço, ferro, latão, cobre, couro e madeira, com
    canos, serpentinas, cintas e manômetros — tudo gasto e fosco (pós-apocalíptico).
  - **Arquitetura:** **medieval com um toque de steampunk, em ruínas** (pedra, madeira,
    telhados quebrados, canos e caldeiras abandonadas).
- `scripts/util/mesh_builder.gd` gera essas malhas por código: seções interpoladas (`loft`),
  peças torneadas (`lathe`), toros, tubos ao longo de um caminho, chapas curvas e extrusões.

## Armas (`scripts/items/item_models.gd`)
Modelos medieval steampunk feitos com o `MeshBuilder`. A mesma função alimenta a arma na mão,
o item no chão, a arma dos zumbis e os ícones.
- **Espada:** lâmina de aço em losango, cano de cobre na base, guarda de latão curvada,
  cabo de couro encorpado com cintas de latão, pomo de ferro.
- **Maça** (o antigo taco): cabo de madeira com empunhadura de couro, cabeça de ferro com
  6 flanges e cintas de latão, serpentina de cobre.
- **Cajado:** madeira com cintas de latão, manômetro, bobina de cobre e o orbe numa gaiola de latão.
- **Pistola:** cano octogonal de latão, tambor de ferro, cão, guarda-mato,
  cano de cobre e coronha curva de madeira.
- **Lanterna** a manivela, **sucata** (ferro torto + cano), **pano** e **fita**.

## Inventário
- `scripts/items/item_db.gd`: catálogo (nome, tipo, pilha, modelo 3D). Item novo = uma entrada lá.
- `scripts/items/inventory.gd`: 5 slots de hotbar + 15 de mochila. Armas/ferramentas vão para a
  hotbar; materiais para a mochila (empilham até 10).
- As armas ficam **no mapa** (espada, taco e lanterna perto do início; cajado na plataforma;
  pistola em cima do contêiner). O player começa sem nada.
- A arma na mão é a do slot selecionado; slot sem arma = punhos.

### Ícones e janela de informação
- `scripts/items/item_icons.gd` (autoload `ItemIcons`) fotografa o modelo 3D de cada item
  (64x64, fundo transparente) — **ninguém precisa desenhar ícone**.
- Os PNGs ficam **na pasta do jogo**: `assets/icons/` (vão no repositório e no jogo exportado).
- Rodando pelo editor, o jogo confere a assinatura em `assets/icons/manifest.txt`
  (`application/config/version` + `RENDER_VERSION` + conteúdo do `ItemDB`). Mudou item ou versão →
  fotografa de novo e regrava os PNGs. A GPU só desenha a foto uma vez; nada fica guardado nela.
- No jogo exportado os PNGs são só carregados. Faltou algum? É gerado em `user://icon_cache/`.
- Os slots mostram só o ícone (e a quantidade). Passando o mouse na mochila aparece uma
  janelinha que segue o mouse com nome, tipo de dano, dano, empurrão e descrição
  (campos `damage_type`, `damage`, `knockback`, `desc` no `ItemDB`).

## Mapa aberto (`scripts/world/`)
- `terrain_world.gd`: mapa de **3 km x 3 km** gerado pela semente (`seed`; `randomize_seed`
  para sortear). Norte = **inverno** (morros com neve, floresta densa de pinheiros), meio =
  **planícies** onduladas (morros + elevações menores) e **montanhas** (~30% do mapa, formas
  **arredondadas** de até ~120 m: grama embaixo, rocha no alto e nas encostas íngremes — boas
  para andar e para estradas no futuro), sul = **deserto** com dunas fortes (até ~16 m) e cactos.
  Bordas sobem em montanhas; o centro é a cidade.
- O terreno vem em pedaços de 64 m que aparecem perto do player e somem longe (até 220 m).
  O cálculo roda em threads; a thread principal só monta os nós (~2.5 ms por pedaço).
- `terrain_props.gd`: árvores, arbustos, pinheiros, rochas e **3 tipos de cacto grandes e tortos**
  (gomos inclinados, braços caídos, florzinha), em blocos via MultiMesh, com colisão no
  tronco/rocha. Sempre os mesmos para a mesma semente.
- `biome_atmosphere.gd`: neblina por distância conforme o bioma, com transição suave:
  planície ~130 m, deserto ~150 m, montanha ~115 m, **neve ~50 m** (com neve caindo e sol mais
  fraco). Valores na tabela `FOG`.
- `zombie_spawner.gd`: mantém ~14 zumbis entre 45 e 110 m do player (mais no inverno) e apaga os
  que ficam a mais de 200 m. Fora da cidade eles andam em linha reta (sem NavigationMesh).

## Movimento (`scripts/player/parkour.gd`)
- Sonda à frente: altura do topo e profundidade do obstáculo decidem o movimento.
  - até `vault_max_height` (1.3 m) e até `vault_max_depth` (1.6 m), correndo → passa por cima;
  - mais comprido (ex.: carro no sentido do comprimento) → sobe em cima;
  - até `climb_max_height` (2.3 m): fino (cerca) → passa para o outro lado; grosso → sobe.
- Deslizar desliga a colisão com zumbis e chama `Zombie.trip()` em quem passar por cima.

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
   - **Membro quebrado** recebe só 15% do dano (`broken_limb_damage`).
   - **Encontrão**: zumbi cambaleando (ou voando em ragdoll) empurra os outros um pouco.
   - **Morte** → ragdoll permanente; continua dando para bater/chutar o corpo.
5. O *hitstop* (jogo quase para por 50–70 ms) e o tremor de câmera dão peso ao impacto.

## Zumbis: navegação, escalada, armas e lanterna
- **Contornam obstáculos** com NavigationMesh gerado da fase ao iniciar (`main.gd`).
- **Escalam** só quando o caminho em volta é mais que o dobro da distância reta (ou não existe)
  e o obstáculo tem até 2.3 m (`climb_detour_ratio`, `climb_max_height`). Atrás da cerca longa
  do norte tem um zumbi para testar.
- **30% nascem armados** (taco ou espada, `weapon_chance`): batem 1.6x mais forte e soltam a arma
  quando morrem ou perdem o braço direito — dá para pegar.
- **Lanterna** apontada para um zumbi **de frente** para você (até 45 m, com linha de visão)
  faz ele vir de qualquer distância.

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
