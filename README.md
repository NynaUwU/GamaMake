# Zumbi FPS — protótipo (Godot 4.7.2)

Primeira pessoa, combate corpo a corpo, zumbis com animação procedural,
reação física a golpes e ragdoll (estilo Dying Light), visual de PC dos anos 2000 em 960x540 (16:9).

## Como abrir
1. Godot 4.7.2 → **Importar** → selecione `project.godot`.
2. **F5** para rodar. Abre o **menu**: jogar sozinho, criar servidor na rede local ou entrar num.

## Multiplayer na rede local (até 32 jogadores)
- **Criar:** menu → *Multiplayer (rede local)* → *Criar servidor*. Ou, como no Minecraft, no meio
  de uma partida solo: **Esc → Abrir para LAN** (vira servidor na hora, sem recarregar).
- **Entrar:** menu → *Multiplayer*: as partidas da rede aparecem na lista (clique para entrar).
  Também dá para digitar o IP (`192.168.0.10` ou `192.168.0.10:7779`). Dá para entrar no meio.
- **Firewall:** igual ao Minecraft. Quem **entra não precisa liberar nada**: o cliente *pergunta*
  na rede "tem partida aí?" e o host responde direto para ele (resposta a uma pergunta que o
  próprio PC fez passa pelo firewall). Só o **host** recebe conexões, e o Windows pergunta uma
  vez "Permitir acesso?" para o jogo, como faz com o Java do Minecraft: clique em Permitir.
  Se a porta 7777 estiver ocupada (outro servidor no mesmo PC), usa a próxima livre.
- **Só o host** usa as teclas de admin: **Z** (zumbi), **H** (100 zumbis) e **Backspace**
  (recomeça a partida para todo mundo; também em Esc → Recomeçar). Nos outros, Backspace só
  **renasce** quando morre.
- Online o Esc **não pausa** o jogo (o mundo é de todos) e o "congelamento" dos golpes fica desligado.
- Os outros jogadores aparecem com o nome em cima, o item da mão, a lanterna acesa e uma bolinha
  azul no minimapa/mapa. Em cima, no meio da tela, aparece quem está online.

## Construção (`scripts/building/`)
- Ferramentas na área inicial (no chão, ao lado da bancada): **martelo** e **talhadeira**.
  No inventário (Tab), **segure Shift** com o mouse em cima de um item para ver os controles dele.
- **Grade invisível** de **0,4 m** no mundo inteiro. Paredes, pisos e tetos têm **2,8 m**
  (7 x 7 quadrados de 0,4 m); o pilar ocupa 1 quadrado e tem 2,8 m de altura.
- **Martelo:** mostra a peça "fantasma" (verde = cabe, vermelho = já tem peça ali).
  - Clique constrói · **segure o botão direito** para abrir o menu de construção (abas +
    slots com foto de cada peça, como o inventário; solte em cima do slot) · **R** gira a parede ·
    **Shift + clique** desmonta a peça (ou tira a janela/porta) mirada. Ao soltar o botão direito
    o menu escolhe o slot que estiver embaixo do mouse.
  - Encaixes: parede mirando um piso vai para a borda dele; mirando o topo de uma parede empilha;
    piso mirando a borda de outro piso vai para o lado; teto mirando o topo de uma parede cobre o
    cômodo do lado onde você está. Piso fica com o topo na grade (pisa-se nele); teto apoia em cima.
- **Talhadeira:** cada quadrado é cortado pelas **duas diagonais** (4 triângulos de quarto), então
  dá para tirar meio quadrado em **"/" ou "\\"** (**R** troca a diagonal). Clique tira o triângulo
  mirado; **clique e arraste** seleciona uma área retangular e tira tudo ao soltar. O buraco tira a
  colisão também e as bordas mostram a espessura da peça.
- **Janela** e **porta** (aba *Aberturas* do menu): mire um buraco feito pela talhadeira e ela
  preenche o buraco **inteiro, em qualquer formato**. A janela tem vidro, batente, guarnição
  saliente, peitoril e **frisos a cada 2 quadrados**; a **porta** precisa de um buraco que encoste na
  base da parede, tem maçaneta, uma **vidraça na altura dos olhos** (porta com 3+ quadrados de largura)
  e abre/fecha com **E**.
- Online o host confere tudo (lugar livre, partes existem, buraco válido) e manda para todos; quem
  entra depois recebe as construções com buracos, janelas e portas.
- Testes: `tests/test_building.gd`, `tests/test_openings.gd`.

## Desempenho dos zumbis
- Corpo do zumbi numa **malha só** deformada pelo esqueleto (antes ~25 peças por zumbi): com 100
  zumbis as chamadas de desenho caíram de ~11.700 para ~2.600 (incluindo o mapa).
- Ossos do ragdoll ficam **fora da física** enquanto o zumbi está de pé.
- Longe (> 30 m): sem sombra, animação a cada 2 quadros e hitboxes desligadas (o tiro acerta a
  cápsula); > 70 m: animação a cada 4 quadros e IA a cada 2.
- Zumbis não colidem fisicamente entre si (se afastam com uma grade de vizinhança).
- A horda (H) nasce em lotes de 10 por quadro: o travão ao criar 100 caiu de ~275 ms para ~24 ms.

## Animações dos outros jogadores
- Quem joga online vê os golpes dos outros no corpo deles: os três arcos da espada/taco/colher,
  soco (alternando os braços), chute, tiro (com recuo), cajado, martelo/talhadeira e dínamo;
  e as poses contínuas: arma de mira apontada para onde a pessoa olha e bloqueio.

## Menus (`scripts/ui/legacy_gui.gd`)
- Estilo dos menus padrão das versões antigas da Unity (GUI.Box/GUI.Button): caixa preta
  translúcida com o título, botões cinza em degradê com borda escura, campos de texto escuros.
- O menu inicial fica na frente de uma cena 3D (carro e zumbi, câmera balançando). O menu de
  pausa usa o mesmo visual.

### Como funciona (`scripts/net/net.gd`, autoload `Network`, acesso por `Net.i`)
- **Mundo:** todo mundo gera o mesmo mapa pela mesma semente (terreno, cidades, pista, frutas).
  Só passa pela rede o que muda.
- **Zumbis:** a IA roda **só no host**. Nos clientes eles são marionetes que seguem a posição e o
  estado (~15x/s, só os que estão a até 170 m) e repetem os eventos visuais (ragdoll, membro
  arrancado, braço quebrado, levantar, arma). O host gera zumbis, terreno e cidades em volta de
  **todos** os jogadores, e cada zumbi persegue o jogador mais perto.
- **Golpes:** quem bate calcula o acerto na hora (sem atraso) e manda o golpe para o host aplicar
  (espada, taco, colher, tiro, chute, explosão, atropelar, deslizar, empalar). O dano dos zumbis
  nos jogadores vai para o dono do boneco, que decide se bloqueou.
- **Itens:** o host decide quem pegou primeiro; o item some para todos. Itens soltos e armas que
  zumbis largam aparecem para todos.
- **Carros:** quem dirige simula a física e manda a posição (~20x/s); nos outros o carro só segue.
  Só uma pessoa dirige cada carro. Se o dono sair do jogo, o host assume o carro.
- Teste com dois processos: rode `tests/net_host.gd` e, logo depois, `tests/net_client.gd`
  (atalho por linha de comando: `godot -- --host --name=Fulano` ou `-- --join=IP`).

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
| Tab | mochila (arraste os itens entre os slots) |
| E / G | pegar / soltar item |
| M | mapa do mundo (o minimapa fica no canto de baixo à direita) |
| L | lanterna (precisa estar no inventário e ter bateria) |
| R | recarregar a pistola |
| E (no carro) | entrar/sair. Dirigindo: W/S acelera/ré, A/D vira, Espaço freio de mão |
| Z / H | novo zumbi / **100 zumbis** em volta (teste, só o host online) · Backspace recomeça · **Esc pausa** (Continuar / Recomeçar / Sair) |

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
- No ar (saltos, rampas) o carro segura o giro e se endireita devagar para cair de rodas.
- Pneus escorregam um pouco antes de tombar. Em alta velocidade a roda vira bem menos
  (100% parado, ~45% a 50 km/h, ~15% a 100 km/h). Dirigindo, volante e braços ficam semitransparentes
  e o mouse gira só a cabeça (o corpo fica sentado). **Faróis** acendem ao entrar; **L** liga/desliga.
- Atropelar derruba o zumbi (dano ~7 por m/s; rápido mata e pode arrancar membros).

### Garagem: mais 6 carros (`scripts/vehicles/cars/`)
Estacionados em duas fileiras ao lado do Monza. Cada um herda de `VintageCar` e só muda a
**ficha** em `_configure()` (medidas, peso, curva de torque, aderência, banco/volante) e a
carroceria em `_build_body()`.

| Carro | Inspiração | 0–100 | Máx. | Como anda |
|---|---|---|---|---|
| Aero V12 | especial feito à mão com V12 de avião | ~6 s | ~180 km/h | pesado, puxa forte em alta, vira devagar (entre-eixos enorme) |
| Brutus | BMW Brutus (V12 de avião num chassi de 1907) | ~3,5 s | ~170 km/h | **torque demais**: acelerando na curva a traseira sai de lado (~30°); volante reto ou contra-esterço trazem de volta |
| Final Objective | Chevrolet Sports Coupe 1955 | ~6,5 s | ~160 km/h | cupê fechado, o mais equilibrado e previsível |
| Darracq V8 | Darracq V8 de recorde (1905) | ~5 s | ~180 km/h | levíssimo, fraco embaixo e bravo no giro, direção nervosa, freio fraco |
| Hall-Scott Four | especial de 1917 com motor Hall-Scott | ~9 s | ~125 km/h | muita força no arranque que acaba cedo |
| Mormon Meteor | Duesenberg Special (1935) | ~8,5 s | ~225 km/h | sai devagar mas não para de puxar; estável, vira pouco em alta |

- Curva de torque: `torque_low` / `torque_peak` / `torque_high` (fração da força no arranque,
  onde fica o pico e quanto sobra na máxima). `wheelspin` tira aderência da traseira com o pé
  no fundo; `drift_max` limita o quanto o carro fica de lado.
- Teste: `tests/test_cars.gd` (arrancada e curva de cada carro; `CAR=brutus` testa só um).

## Estilo visual
- **Seres vivos** (player, zumbis, animais no futuro) são em **blocos**.
- **Todo o resto** é **poligonal estilo PS2**: poucos lados, sombreamento suave mas silhueta
  facetada — nunca completamente liso. Peças complexas (painel, rodas) podem ter mais polígonos.
- **Mãos** (`scripts/util/blocky_hand.gd`): em blocos, com 4 dedos e polegar. O player segura
  as armas e o volante com a mão fechada; zumbis têm dedos tortos de garra.
- **Temas:**
  - **Carros:** pré-guerra — de corrida (como o Alfa 8C Monza) e, no futuro, civis.
  - **Armas:** **medieval steampunk** — aço, ferro, latão, cobre, couro e madeira, com
    formas simples, poucas peças — tudo gasto e fosco (pós-apocalíptico).
  - **Arquitetura:** **medieval com um toque de steampunk, em ruínas** (pedra, madeira,
    telhados quebrados, canos e caldeiras abandonadas).
- `scripts/util/mesh_builder.gd` gera essas malhas por código: seções interpoladas (`loft`),
  peças torneadas (`lathe`), toros, tubos ao longo de um caminho, chapas curvas e extrusões.

## Armas (`scripts/items/item_models.gd`)
Modelos medieval steampunk **simples** (poucas peças retas, no máximo uma cinta de latão), feitos
com o `MeshBuilder`. A mesma função alimenta a arma na mão, o item no chão, a arma dos zumbis e
os ícones.
- **Espada:** lâmina de aço em losango, guarda reta de latão, cabo liso de couro, pomo de ferro.
- **Maça:** cabo de madeira com empunhadura de couro, cabeça de ferro octogonal com 4 flanges e
  uma cinta de latão.
- **Cajado:** cabo de madeira, ponteira de ferro, uma cinta de latão e o orbe preso por 3 garras.
- **Pistola:** cano de latão, tambor e armação de ferro, cão, guarda-mato, coronha de madeira.
- **Carregador** (inspirado no do Metro Exodus): dínamo de mão horizontal: motor de ferro deitado
  com bobina de cobre embaixo, alavanca vermelha, medidor com ponteiro da bateria e vários fios. Equipe na hotbar e
  **clique rápido** para carregar; o volante na ponta esquerda gira.
  A carga só aparece no ponteiro do carregador. A lanterna gasta a bateria (~2,5 min cheia) e a
  luz vai ficando mais fraca bem aos poucos (é preciso prestar atenção para notar) até apagar.
- **Colherona:** colher de sopa ridiculamente grande (1,5 m). Lenta, pouco dano, e **arremessa
  o zumbi ~10 m** girando (`spoon_launch`).
- **Gancho:** clique e **segure** para prender e balançar (pêndulo com um impulso para cima ao
  prender, WASD controla no ar); a corda **se recolhe sozinha** quando você chega perto; soltar o clique solta a corda e mantém o impulso no ar. Alcance 45 m.
  **5 cargas**; acabou, espere ~6 s sem usar para recarregar todas (usar de novo reinicia a contagem).
- **Lanterna** de latão, **sucata**, **pano** e **fita**.

## Chinelo e bumerangue (`scripts/weapons/`)
- **Chinelo** (no chão, ao lado da bancada): clique joga no zumbi mais perto do centro da mira e
  **sempre acerta a cabeça** (headshot): o zumbi cai **duro para trás**, braços e pernas juntos, como
  uma tábua, e só no chão vira ragdoll. Dá para jogar de novo logo em seguida.
- **Bumerangue:** vai até o zumbi mirado e **ricocheteia** de zumbi em zumbi (até **5**, os mais perto
  num raio de 14 m). A cada acerto ele **sobe** e cai em arco no próximo; cada acerto tem **40% de
  chance de atordoar** (o zumbi fica parado cambaleando ~2 s). Depois volta para a sua mão.
- Online os outros veem o arremesso no seu boneco e o chinelo/bumerangue voando.
- Teste: `tests/test_throwables.gd`.

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
  **arredondadas** de até ~110 m, com pé baixo e picos só no meio das cordilheiras — sem paredões: grama embaixo, rocha no alto e nas encostas íngremes — boas
  para andar e para estradas no futuro), sul = **deserto** com dunas fortes (até ~16 m) e cactos.
  Bordas sobem em montanhas; o centro é a cidade.
- O terreno vem em pedaços de 64 m que aparecem perto do player e somem longe (até 220 m).
  O cálculo roda em threads; a thread principal só monta os nós (~2.5 ms por pedaço).
- `terrain_props.gd`: árvores normais, **tortas**, **gigantes** e **frutíferas** (frutas no chão:
  pegue e clique para comer, +25 de vida), arbustos, pinheiros, rochas, **3 tipos de cacto grandes
  e tortos** e muita **grama/arbustos de folhas cruzadas** (estilo Minecraft), via MultiMesh, com
  colisão no tronco/rocha. Planejado em thread. Sempre os mesmos para a mesma semente.
- `race_track.gd`: **autódromo** no deserto inspirado na The Motor Raceway (FlatOut 2), com
  traçado 3D (cada ponto tem altura; o terreno é moldado pela pista). Tudo aberto, sem trechos fechados:
  - **oval** com as **curvas inclinadas** (~10°) e uma **lombada na reta oposta** que faz o carro voar a partir de ~85 km/h;
  - **misto**: desce numa valeta, sobe o **morro do infield**, **grampo** lá em cima e desce em S;
  - **cruzamento** de ponta a ponta num **rebaixo** de barrancos suaves; o misto passa por cima numa **ponte**;
  - **atalhos de terra**: um corta a curva 1 por dentro (**rampa** sobre uma valeta), outro sai do grampo e
    **pula por cima do rebaixo**;
  - muretas vermelho/branco seguindo a inclinação, pneus, placas, largada quadriculada, pórtico e arquibancada.
  - Traçado em constantes no topo do arquivo (`INFIELD`, `CROSS`, `SHORTCUT_*`, `RAMPS`); teste em `tests/test_track.gd`.
- `biome_atmosphere.gd`: neblina por distância conforme o bioma, com transição suave:
  planície ~130 m, deserto ~150 m, montanha ~115 m, **neve ~50 m** (com neve caindo e sol mais
  fraco). Valores na tabela `FOG`.
- `zombie_spawner.gd`: mantém ~14 zumbis entre 45 e 110 m do player (mais no inverno) e apaga os
  que ficam a mais de 200 m. Fora da cidade eles andam em linha reta (sem NavigationMesh).

## Movimento (`scripts/player/parkour.gd`)
- **Peso:** aceleração e frenagem graduais, queda mais pesada que a subida, balanço de cabeça; a animação das pernas tem velocidade máxima (não acelera no gancho/no ar).
- Sonda à frente: altura do topo e profundidade do obstáculo decidem o movimento.
  - até `vault_max_height` (1.3 m) e até `vault_max_depth` (1.6 m), correndo → passa por cima;
  - mais comprido (ex.: carro no sentido do comprimento) → sobe em cima;
  - até `climb_max_height` (2.3 m): fino (cerca) → passa para o outro lado; grosso → sobe.
- Deslizar desliga a colisão com zumbis e chama `Zombie.trip()` em quem passar por cima.
- **Deslize:** o **mouse** curva de leve; ladeira abaixo ele acelera e não para até o chão ficar plano.
- **Vault** em objetos de até 4 m de comprimento (capô de carro no sentido do comprimento, mesas).
- **Sem perder o ritmo:** deslizar termina na velocidade de corrida (ou de andar), vault e subir
  saem na mesma velocidade em que entraram (a duração depende dela). Só escalar a cerca para.
- **Animação:** mãos apoiando no obstáculo (as duas ao subir/escalar, a esquerda no vault e
  arrastando no chão no deslize), câmera inclinando e mergulhando, pernas encolhidas no corpo e
  "afundada" da cabeça ao aterrissar.

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
scripts/net/net.gd            multiplayer LAN (autoload Network; use Net.i)
scripts/ui/main_menu.gd       menu inicial (solo / multiplayer: lista, IP, criar)
scripts/ui/legacy_gui.gd      visual dos menus (Unity antiga)
scripts/building/             construção (peça com 98 triângulos, grade, martelo/talhadeira)
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

## Cidades (`scripts/world/city_gen.gd`, `city_manager.gd`)
- Geradas pela semente: **2 grandes**, **4 médias** e **7 vilas**, em terreno plano (fora das
  montanhas), com o chão achatado, formato **quase quadrado** (grade de quarteirões com bordas
  comidas) e ruas: **avenida** no eixo central, **ruas comuns** na grade e **terra** na borda e
  nas vilas. **Avenidas** tortas (curvas largas + desvios a cada ~35 m) ligam as cidades grandes e médias pelo mapa.
- Torres altas ganham **ramificações tortas** como os cactos: um braço (ponte fechada) que sai
  do meio do prédio e vira uma mini-torre inclinada com telhado.
- Casas medievais com toque steampunk, em ruínas, no estilo **Hello Neighbor**: andares
  empilhados de tamanhos diferentes, tortos e deslocados, puxadinhos, telhados íngremes (alguns
  desabados, com os caibros à mostra), chaminés, canos de cobre, caldeiras, janelas tapadas.
- **Grande:** torres-casa de até 15 andares (~50 m) no centro, baixando para fora; caldeira gigante
  com chaminé na praça. **Média:** 2–6 andares. **Vila:** casinhas de 1–2 andares espalhadas,
  cercas e um poço.
- São construídas aos poucos quando você chega perto (2 casas por frame) e apagadas longe; cada
  uma ganha zumbis nas ruas. Aparecem no mapa e no minimapa.

## Mapa (`scripts/ui/world_map.gd`)
- Gerado uma vez, em thread, a partir do próprio terreno (cor do bioma + sombreado do relevo,
  8 m por pixel) com os prédios da cidade por cima. Leva ~1 s no início.
- **Minimapa** (320 m, norte para cima): seta do player, carro e zumbis próximos.
- **M**: mapa do mundo inteiro com o player, o carro e a legenda dos biomas.

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
