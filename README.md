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

## Máquinas — Tier 0 (primitivo). Plano completo em `docs/ROADMAP_MAQUINAS.md`
- **Sede** (arco azul "A" no HUD, por dentro da fome): esvazia em ~15 min (correndo, mais rápido). Zerada, a vida cai. Com sede baixa a vida não regenera; aviso só por som.
- **Garrafa** (fornalha: 1 vidro → 2 garrafas; casas e caixote inicial): clique com ela na **água do lago** → **água suja**; num **coletor de chuva** → **água potável**. Beber devolve a garrafa vazia.
- **Doença** (água suja: 60% de chance): por 3 min a vida cai devagar (até 15), a stamina enche pela metade e fome/sede gastam 60% mais rápido. Arco da vida fica verde. Some sozinha.
- **Clima** (`scripts/world/weather.gd`): o host sorteia o tempo a cada 2–5 min (~35% de chuva) e o vento (mais forte com chuva; vai mover moinhos no Tier 2). Chuva: gotas em volta da câmera, céu cinza, sol fraco, som de chuva. Vai no save e na rede.
- **Coletor de água da chuva** (martelo → Outros: 4 tábuas + 1 pano): barril com funil; chovendo enche (chuva forte ≈ 1 garrafa a cada 25 s, até 10). A água aparece subindo dentro.
- **Secador** (martelo → Outros: 6 gravetos + 1 pano): varal com 4 ganchos; peixe/frutos do lago viram **peixe seco** em 90 s (+40 fome, não queima). Pele → couro entra quando houver animais.
- **Argila → tijolo:** a pá na **beira dos lagos** (até ~1 m acima da água) tira argila em vez de abrir cova; na grelha da fogueira vira tijolo e **não queima** (pode esquecer lá). O tijolo é a base da fornalha de pedra (Tier 1).
- **A fogueira afasta zumbis à noite:** eles não entram a menos de ~6 m dela, nem indo atrás de quem está ao lado do fogo; ficam rondando a borda da luz. De dia não adianta.

## Airdrop, desgaste por uso, bandeira e menos fita (rodada de feedback)
- **Zumbis da onda noturna não soltam nada.** Ao vencer a onda (cota da noite abatida), **cai um airdrop** a 10–25 m de cada jogador: caixa militar descendo de paraquedas, com uma **luz vermelha piscando** em cima e um quadrado vermelho pulsando no mapa/minimapa. Dentro: suprimentos bons (bandagem, comida, sucata, pano, barras, vidro, fita, carvão, às vezes colete/capacete/pistola). O sinal apaga quando a caixa fica vazia. `scripts/farming/airdrop_fx.gd`, `HordeManager._drop_airdrops`.
- **Desgaste conforme o uso:** atacar gasta 100% (qualquer arma ou ferramenta); ferramenta no serviço certo gasta 75% (machado em árvore/tronco/móvel, picareta em pedra/minério, pá cavando, martelo/talhadeira construindo); no serviço errado gasta **200%** (espada na árvore, machado na pedra). A **maça** gasta sempre 100%. `Player._wear_cost`.
- **Bandeira** (mesa: 2 gravetos + 2 panos): clique no chão para fincar; vira um **waypoint no mapa e no minimapa** para todo mundo (no minimapa, a que está longe fica presa na borda apontando a direção). [E] nela recolhe de volta.
- **Fita só em coisa complexa:** saiu do machado, picareta, lança, bumerangue, chinelo e colete (trocada por sucata/pano/tábua). Continua só na lanterna.

## Carros nas cidades e mapa mais nítido (rodada de feedback)
- **Carros abandonados nas cidades** (`scripts/world/city_cars.gd`): 1 nas vilas, 2 nas médias e 4 nas grandes (23 no mapa padrão), modelo e lugar sorteados pela semente da cidade, largados meio tortos na rua. Ficam **congelados** (sem física, sem rede) até alguém chegar a 150 m e o chão embaixo existir; voltam a congelar quando todos se afastam. Vão no save como os outros.
- **Ícone do carro no mapa só depois de entrar nele uma vez** (vale para todos os carros, inclusive os da garagem; saves antigos já contam como conhecidos).
- **Desvirar mais robusto:** conta como tombado também o carro inclinado/encalhado (apoiado em algo, com menos de 2 rodas no chão e parado); ao desvirar ele acorda a física e pousa 1 m acima do chão que estiver embaixo.
- **Mapa 4x mais nítido** (2 m por pixel): o relevo continua amostrado a 8 m e suavizado, mas ruas, avenidas, a pista e as casas (giradas, com contorno; ruínas mais escuras) são desenhadas por cima em alta resolução. Minimapa mostra 260 m (antes 320). Gera em ~4 s.

## Durabilidade, mudas, degraus e vidro (rodada de feedback)
- **Durabilidade** em roupas/armaduras, ferramentas e armas corpo a corpo: só uma barra embaixo do ícone (verde → amarelo → vermelho), sem texto. Cada golpe que acerta gasta 1 uso (uma vez por golpe, mesmo acertando vários); cada dano recebido gasta a roupa vestida. Ao zerar, quebra com um som de estalo. Ferramentas simples (de pedra) duram ~35% das de metal. `ItemDB.max_durability`, `Inventory.wear`.
- **Golpe acerta 2 a 5 zumbis** (sorteado a cada golpe): hordas voltaram a ser perigosas.
- **Zumbis soltam recursos** ao morrer: 30% sucata, 30% pano e 12% uma roupa já gasta (capuz, calça, botas ou colete).
- **Mudas de árvore:** árvores do mapa às vezes soltam uma muda. Plante no solo ou num **canteiro** (ocupa o canteiro inteiro). No **vaso ou floreira** ela não cresce: fica de decoração (um golpe arranca e devolve a muda). Cresce em ~8 min (muda → arvoreta → árvore); só dá para derrubar depois de crescida (machado corta bem, o resto mal arranha). Árvore plantada pelo jogador sempre solta **1 muda (10% de chance de 2)**, troncos e gravetos.
- **Subir degraus** de até 0,42 m (altura da canela, um passo da grade) andando, sem pular: jogador e zumbis (os animais vão usar o mesmo `scripts/physics/step_climb.gd`). A câmera sobe suave, sem tranco. Resolve o degrau do piso na entrada das casas construídas.
- **Menus sem botão "Fechar":** clicar fora do painel fecha qualquer menu (mochila, baú, porta-malas, baú do mapa, mesa/fornalha, lousa, construção e pausa). `LegacyGUI.close_on_outside`.
- **Janela** agora custa 2 gravetos + 1 vidro (era tábua + sucata).
- **Deserto:** a pá não abre cova (o solo é ruim: só dá para plantar em plantadores construídos), mas cava **areia** (1–2). O vidro sai só da fornalha: 2 areia → 1 vidro.

## Inventário, crafting, carros e casas (rodada de feedback)

- **Hotbar de 9** (teclas 1-9). **Mochila 9x5** (hotbar + 9x4). Em cima: o **personagem** girando com 4 slots de **roupa/armadura** (cabeça, corpo, pernas, pés) presas no boneco, e o **crafting de mão**.
- **Pilhas de até 100** (armas, ferramentas e roupas: 1 por slot).
- **Shift + clique** transfere rápido: na mochila (hotbar <-> mochila; roupa veste/tira) e no baú construído/porta-malas (baú <-> mochila).
- **Roupas e armaduras** reduzem o dano (somam até 80%): capuz 5%, capacete de ferro 15%, colete de sucata 18%, peitoral de ferro 30%, calça 10%, botas 5%.
- **Crafting de mão** (só o básico e versões que rendem menos): gravetos (2 por tábua), tábuas (3 por tronco), machado e picareta **simples** (pedra + graveto, rendem ~60%), bandagem, capuz.
- **Gravetos:** caem em volta de algumas árvores; golpe de machado numa tábua no chão = 2 gravetos; na mesa, 1 tábua = 4 gravetos. Ferramentas da mesa usam gravetos.
- **Mesa e fornalha em grade:** ícone com o nome embaixo (estilo do menu de construção); passando o mouse mostra o que precisa. Clique fabrica 1; **Shift + clique fabrica o máximo** (até uma pilha de 100: dá para fundir uma pilha inteira de minério).
- **Menos avisos na tela:** pesca, construção, plantio e grelha agora avisam por **som** (boia afundando, "clique" seco quando falta material ou não dá, martelada no conserto...). Sem frases de instrução nos menus.
- **Pesca:** o peixe do minijogo ficou bem mais calmo; a linha sai da ponta da vara.
- **Peixes repovoam a cada 5 dias:** cada lago tem uma quantidade padrão de cada bicho (sorteada na criação do mundo); o que você pega só volta no repovoamento.
- **Carros:** mais pesados (gravidade 1,5x no carro, mola compensada, aceleração igual); **desvirar** com [E] no carro tombado (só de fora do carro); **porta-malas** com [E] atrás do carro (21 slots, arrastar e soltar).
- **Baús de saque** pintados em cores fortes (baú vermelho, armário turquesa, caixote amarelo).
- **Casas com interior:** ~30% das casas grandes (9x9 m ou mais) têm o térreo oco, com porta aberta, **janelas de verdade** (vãos com moldura: dá para olhar e atirar através), piso de tábua e lampião aceso na sala.
- **8 plantas prontas** (`scripts/world/house_plans.gd`) com **4 a 7 cômodos** (sala, cozinha, quartos, banheiro, corredor, escritório, oficina, despensa), paredes internas com vãos de passagem e móveis encostados nas paredes certas de cada cômodo.
- **Móveis:** mesa (com cadeiras), cama, armário, estante, fogão a lenha, sofá, banheira, privada, pia, balcão de cozinha e cômoda. **Qualquer golpe desmonta** (arma, ferramenta ou soco) e eles soltam tábuas, gravetos, pano, sucata, pedra...
- Slots de roupa vazios mostram só a **silhueta** da peça; nas grades de receitas e no menu de construção o **nome curto fica dentro do quadrado** e a quantidade no canto de cima (o resto aparece passando o mouse).
- **Threads:** terreno, casas e sons usam tarefas de alta prioridade no WorkerThreadPool (as comuns dividem só ~30% das threads e a imagem do mapa, que leva ~20 s, ocupava tudo).

## Ajustes (feedback)

- **HUD** de arcos menor (letrinhas S/V/F na ponta).
- **Onda noturna:** só uma barra vermelha abaixo do relógio que esvazia conforme os zumbis da noite morrem. Cada noite tem uma **cota** maior (12 na 1ª, +6 por noite); matou a cota, a onda acaba e não nascem mais noturnos até amanhecer.
- **Mesa de trabalho** é a única bancada de fabricação (6 tábuas + 3 sucatas, sem ferro); a "bancada" antiga saiu do martelo (as já construídas abrem a mesa). Uma já vem na área inicial.
- **Fornalha** de barro: cúpula redonda sobre pedras, boca em arco e chaminé de barro.
- **Pedras soltas** no chão em volta de rochas e veios ([E] pega): dá para fazer a primeira picareta sem ferramenta.
- **Baús, armários e caixotes do mundo:** [E] abre a lista do saque; **só dá para retirar** (clique num item pega; "Pegar tudo"). O saque é sorteado na primeira abertura, sincronizado no multiplayer e salvo.
- **Baú construível** (martelo → Outros, 6 tábuas + 1 sucata): 21 slots (7x3), com **arrastar e soltar igual ao inventário** entre o baú e a mochila (move, troca e junta pilhas; soltar do baú num slot da mochila vai para aquele slot). O conteúdo é do mundo (todos veem, vai no save); desmontar o baú derruba o que tinha dentro. `scripts/ui/storage_ui.gd`.
- **Modelo 3D girando** ao lado do nome do item (janela de detalhes da mochila e no baú). `scripts/ui/item_spinner.gd`.
- **Som:** soco com som próprio (grave e curto); motor sem "pop" (loop periódico sem emenda e liga/desliga com fade, mais baixo).
- **Água** mais transparente, fundo do lago verde de alga; debaixo d'água bem menos escuro.
- **Peixes** nadam devagar e só fogem se você chega muito perto ou ataca por perto.
- **Peixe-baixo** agora é um peixe (cabeça, boca, guelras, barbatanas, rabo bifurcado) com acabamento de contrabaixo (madeira sunburst, captadores, 4 cordas no flanco, tarraxas na barbatana).

## Lagos, pesca e vida aquática (`scripts/water/`, `shaders/`)

- **Lagos e lagoas:** 9 lagos (raio 22-48 m, até 9 m de fundo) e 16 lagoas (9-18 m, 2,5-4 m), sorteados pela semente e longe de cidades, pista, avenidas e da área inicial. O terreno afunda numa bacia com fundo de areia/lodo. Aparecem em azul no mapa. Lagos na neve **congelam** (dá para andar no gelo).
- **Água:** superfície translúcida com ondinhas, mais clara na margem e refletindo de lado.
- **Nadar:** com água acima de ~1,2 m você nada: Espaço sobe, C desce, olhar para baixo andando mergulha; parado, boia. Com água na cintura anda mais devagar.
- **Debaixo d'água:** tela ondulando, verde-azulada e mais escura no fundo, neblina curta, som abafado, bolhas saindo e sujeirinha flutuando.
- **Plantas:** algas compridas que balançam no fundo, juncos e taboas na margem, vitórias-régias boiando (algumas com flor) e pedras com musgo.
- **Bichos (em blocos):** camarão, lagosta, caranguejo, caranguejo-aranha (pernas enormes), atum (só nos lagos grandes) e o **peixe-baixo**: corpo de contrabaixo sunburst, braço com tarraxas fazendo de rabo, 4 cordas e captadores. Nadam/andam pelo lago, caranguejos andam de lado e alguns ficam na margem; fogem de quem chega perto. Pegos voltam depois de 1 min.
- **Lança** (mesa de trabalho: 2 tábuas + 1 sucata + 1 fita): estocada longa que pega qualquer bicho (funciona debaixo d'água) e machuca zumbi.
- **Com a mão:** [E] pega camarão, lagosta e caranguejos (os do fundo e da margem).
- **Vara de pesca** (mesa de trabalho: 2 tábuas + 1 pano + 1 sucata): clique lança a boia onde você mira na água (até 22 m). Espere a boia **afundar** e clique em até 1,2 s. No minijogo, segure o clique para empurrar a faixa verde e manter o peixe dentro dela até a barra amarela encher. O atum briga muito; o camarão é fácil. Botão direito recolhe a linha. À noite eles mordem mais rápido.
- **Na grelha:** todos viram versões assadas que enchem muito mais a fome (atum assado +80, lagosta +55, peixe-baixo +48...).
- Teste: `tests/test_water.gd`.

## HUD, lousa, carros e desempenho

- **HUD em quarto de círculo** (canto de baixo à esquerda): stamina por fora (amarelo), vida no meio (vermelho, pisca quando baixa) e fome por dentro (laranja). `scripts/ui/status_arcs.gd`.
- **Painel do canteiro:** mirando um pote/floreira/canteiro/cova (ou a grelha da fogueira) aparece ao lado da mira a foto de cada planta, a barra de crescimento e a porcentagem. `scripts/ui/plant_panel.gd`.
- **Contador da onda noturna** abaixo do relógio: de dia "Próxima noite em 6:20"; de noite "Onda noturna 2 · 5 vivos · 11 abatidos · amanhece em 3:10".
- **Lousa** (martelo → Outros, 4 tábuas + 1 pano): cavalete com tela. [E] abre a tela grande: 12 cores, 4 espessuras, borracha e Limpar. Todos desenham juntos e veem ao vivo; o desenho vai no save. `scripts/crafting/draw_board.gd`, `scripts/ui/draw_ui.gd`.
- **Carros:** todos dirigem como o primeiro (mesma aderência, esterço, freio e estabilidade); cada um mantém só o próprio torque e a velocidade máxima.
- **Multithread:** o terreno já era gerado em threads e o Jolt já usa vários núcleos na física. Agora também: casas das cidades montadas em threads (WorkerThreadPool), sons sintetizados em paralelo na abertura (o primeiro gemido não trava mais) e a navegação calculada em outra thread. O render em thread separada do Godot foi testado, mas quebra a leitura de malhas dos zumbis (é experimental), então ficou desligado.

## Recursos, estações, conserto e armadilhas

### Árvores, rochas e minérios (`scripts/world/resource_node.gd`)
- **Machado** derruba árvore em 3 golpes (ela tomba de verdade) e solta **troncos** (2-3). Outras armas quase não fazem efeito.
- Tronco: carregue até a **bancada** (1 tronco = **8 tábuas**) ou golpeie com o machado ali mesmo (**2 tábuas**). Na fornalha vira carvão.
- **Picareta** quebra rochas (pedra) e **veios de minério**: ferro (pedaços laranja), cobre (verdes) e carvão (pretos), mais comuns na montanha.
- Árvores e rochas usadas não voltam (vão no save e valem para todos no multiplayer).

### Estações (martelo → aba Outros)
- **Fogueira com grelha** (5 pedras + 3 tábuas): segure comida crua e aperte [E] para pôr na grelha (3 lugares). Em 20 s fica pronta; esquecida 1 min depois vira carvão. Assada enche muito mais: batata 22→45, cenoura 15→30, abóbora 40→75, enlatado 45→65, pão 25→40. Também ilumina à noite.
- **Fornalha** (10 pedras + 2 tábuas): minério → barra de ferro/cobre, 3 sucatas → barra de ferro, pedra → vidro, tronco → 2 carvões. Cada fundição gasta combustível (carvão, tronco ou 2 tábuas).
- **Mesa de trabalho** (6 tábuas + 2 barras de ferro + 2 sucatas): tudo da bancada + receitas de metal (espada, pistola, lanterna, carregador, gancho, colherona, cajado).
- **Bancada:** tábuas do tronco, machado, picareta, pá, martelo, talhadeira, bandagem, bumerangue, chinelo, maça.

### Conserto com o martelo
- Mirando uma peça quebrada por zumbi, o dano aparece em verde e o **clique conserta** (1 tábua a cada 2 quadradinhos). Cortes feitos com a talhadeira não contam como dano.

### Armadilhas (martelo → aba Armadilhas)
- **Estacas** (4 tábuas): machucam a perna de quem passa (30 usos).
- **Armadilha de urso** (2 barras de ferro): prende o zumbi (atordoa 5 s e quebra a perna). Depois fica fechada: [E] arma de novo.
- **Cerca de espinhos** (4 tábuas + 1 barra de ferro): bloqueia; zumbi que bate nela se machuca (aguenta 12 golpes).
- **Mina** (2 sucatas + 3 carvões): explode quando um zumbi chega perto.

### Outros ajustes
- Stamina 4x maior (enche no mesmo tempo de antes).
- **Som:** volume geral bem mais baixo, cada som com o mesmo pico (sem clipping), limitador no canal Master, menos agudos e tom máximo limitado.
- Itens do baú nascem na frente dele (antes podiam ficar presos dentro do armário).
- Testes: `tests/test_resources.gd`, `tests/test_stations.gd`.

## Chat e marcador (`scripts/ui/chat.gd`, `scripts/ui/ping_markers.gd`)

- **Enter** abre o chat (Enter envia, Esc cancela). As mensagens aparecem no canto de baixo à esquerda e somem depois de uns segundos; entradas/saídas de jogadores também aparecem ali.
- **Comandos do host:** `/noite`, `/dia`, `/hora 14`, `/horda` (uma horda a ~90 m vindo até você). `/ajuda` lista.
- **B ou botão do meio do mouse:** marca onde você mira (até 300 m). Todos veem um losango por cima de tudo (atravessa paredes) com o nome, o que é (**Zumbi!**, Item, Carro ou Aqui) e a distância; também aparece no mapa e no minimapa (preso na borda se estiver longe). Some em 12 s.
- O nome no chat vem da lista do host (ninguém consegue falar como outro jogador).
- Teste: `tests/test_chat.gd` (e `net_host.gd`/`net_client.gd` na rede).

## Dia e noite, hordas e zumbis quebrando construções

### Dia e noite (`scripts/world/day_night.gd`)
- Um dia dura **20 minutos**: dia das 6h às 20h, noite das 20h às 6h. Relógio no canto de cima ("Dia 2  21:30").
- O sol gira (nasce, põe), o céu e a neblina escurecem; à noite entra uma lua azulada fraca. Lanterna (L) e faróis fazem diferença.
- Os **postes das cidades só acendem à noite** (os quebrados continuam piscando).
- O host manda a hora para todos; ela vai no save.

### Hordas noturnas (`scripts/enemies/horde_manager.gd`)
- De noite nascem zumbis a 45-65 m de cada jogador, fora da vista, **já vindo atrás dele**.
- Limite por jogador: 13 na 1ª noite, +3 a cada dia (até 30). Ao amanhecer os que estão longe vão embora.

### Hordas no mapa
- 5 hordas (7 de noite) de 12-30 zumbis andando **de cidade em cidade** (mais rápido de noite). Aparecem no mapa/minimapa como manchas vermelhas pulsando, com a contagem.
- Longe de todo mundo são só um ponto no mapa; a **120 m** de um jogador surgem de verdade e **marcham juntas**; se todos se afastam (200 m), os vivos voltam a ser um ponto.
- Matou todos: a horda some; outra nasce longe depois de um tempo. As hordas vão no save.

### Zumbis quebram construções
- Zumbi perseguindo alguém com uma parede/porta/janela de construção na frente **para e bate nela**.
- **Parede:** cava um buraco de ~1,2 m de largura do chão para cima (cada pedaço aguenta 2 golpes). Um zumbi sozinho demora; uma horda passa rápido.
- **Janela** aguenta 3 golpes e **porta** 6; depois caem.
- Teste: `tests/test_night.gd`.

## Saque, fome, fabricação e plantação

### Saque (`scripts/loot/`)
- **Baús, armários e caixotes** na frente de ~65% das casas das cidades (escombros têm caixote de ruína). **[E] revista**: os itens pulam para fora.
- Cada um só pode ser revistado **uma vez por mundo** (todo mundo vê aberto; o save lembra).
- Tabelas em `loot.gd`: casa (comida, pano, sementes), caixote (tábua, pedra, sucata, ferramentas raras), ruína (pedra, sucata, raros).
- **Caixote inicial** ao lado da mesa de armas: 20 tábuas, 10 pedras, sementes, 2 enlatados e uma pá.

### Construção custa material
- Parede/piso/teto: 4 tábuas · pilar: 1 tábua + 1 pedra · janela: 2 gravetos + 1 vidro · porta: 3 tábuas + 1 sucata.
- O menu do martelo mostra o custo (tem/precisa) e deixa o slot avermelhado quando falta. Shift + clique (desmontar) **devolve metade**.

### Fome
- Barra laranja embaixo da stamina. Cai em ~22 min (mais rápido correndo).
- Acima de 80: recupera vida devagar. Zerada: perde vida aos poucos.
- Comidas: enlatado (+45), pão velho (+25), abóbora (+40), batata (+22), cenoura (+15), fruta (+10 e vida). Bandagem só cura.

### Bancada de fabricação (`scripts/ui/crafting_ui.gd`)
- Uma ao lado da mesa de armas; dá para construir outras pelo martelo (aba Outros: 6 tábuas + 2 sucatas).
- [E] abre as receitas: pá, martelo, talhadeira, bandagem, bumerangue, chinelo, lanterna, maça, pistola.

### Plantação (`scripts/farming/`)
- **Martelo → aba Outros:** pote (1 planta, 2 pedras), floreira (3 plantas), **canteiro** (piso de terra na grade da construção, 9 plantas), bancada.
- **Pá:** clique = golpe. **Botão direito** no chão de terra cava uma **cova** (às vezes acha pedra); numa cova/pote/canteiro vazio planta a primeira semente da mochila; numa planta pronta, colhe.
- **Semente na mão:** clique planta onde mirar. **[E]** colhe tudo que estiver pronto.
- Culturas: cenoura (~4 min), batata (~5 min), abóbora (~7 min, não cabe no pote pequeno). A colheita dá comida + sementes.
- As plantas crescem pelo relógio do mundo (salvo junto) e sincronizam no multiplayer.
- Testes: `tests/test_farming.gd`.

## Salvar e carregar (`scripts/save/save_game.gd`)

- **Menu inicial:** "Continuar (Mundo N)" abre o último save; "Carregar mundo..." lista todos (com data) e deixa apagar (clique duas vezes em Apagar). "Novo mundo" começa do zero.
- **Pausa (ESC):** botão "Salvar". "Sair para o menu" salva antes de sair. **Autosave a cada 2 minutos.**
- **O que é salvo:** semente do mapa, itens já pegos, itens soltos no chão, construções (peças, recortes, portas/janelas abertas), carros (posição e faróis), jogador (posição, direção, vida, inventário).
- **Multiplayer:** só o host salva (o mundo fica no computador dele). Ao salvar, o host pede o estado de cada cliente e guarda pelo **nome**: quem entrar de novo com o mesmo nome volta com posição, vida e inventário.
- Arquivos em `user://saves/<nome>.save` (no Linux: `~/.local/share/godot/app_userdata/<projeto>/saves`).
- Sistemas novos se salvam sozinhos: basta entrar no grupo `persist` e ter `persist_key()`, `save_data()` e `load_data()`.
- Teste: `tests/test_save.gd`.

## Som (`scripts/audio/sfx.gd`)

Todos os sons são **sintetizados no código** ao abrir o jogo (sem arquivos de áudio): ruído filtrado, tons e "vozes" com formantes para os zumbis. Ficam em cache depois da primeira vez.

- **Combate:** golpe no ar, pancada, corte de membro, corpo caindo, tiro, explosão, tapa do chinelo, zumbido do bumerangue.
- **Zumbis:** gemem de vez em quando (só os próximos), rosnam ao atacar, último gemido ao morrer. Funciona também nas cópias do multiplayer.
- **Mundo:** passos (terra fofa x construção/rua dura), motor dos carros (o tom sobe com a velocidade), porta rangendo, marteladas e talhadeira na construção, pegar item, comer, vento de fundo.
- Sons 3D usam um conjunto de 40 tocadores reaproveitados (`Sfx.play_at`); loops (motor, vento, bumerangue) com `Sfx.loop_player`.
- Teste: `tests/test_sfx.gd` gera todos e mostra duração/pico.

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
| Enter | chat (comandos do host: `/noite`, `/dia`, `/hora N`, `/horda`) |
| B / botão do meio | marcar (ping) onde mira |
| Botão direito (pá) | cavar cova / plantar / colher |
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
  uma tábua, e só no chão vira ragdoll. Depois o chinelo **volta para a mão**; dá para ter **2 no ar**
  (o HUD mostra quantos sobraram) e aí é preciso esperar um voltar.
- **Bumerangue:** vai até o zumbi mirado e **ricocheteia** de zumbi em zumbi (até **5**, os mais perto
  num raio de 14 m). A cada acerto ele **sobe** e cai em arco no próximo; cada acerto tem **40% de
  chance de atordoar** (o zumbi fica parado cambaleando ~2 s). Voa devagar, grande e com rastro para
  dar para acompanhar; **só um por vez**: espere ele voltar para a mão (HUD: "voltando...").
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
