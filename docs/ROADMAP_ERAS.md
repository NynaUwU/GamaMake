# Roadmap: eras, minigames e progressão

Plano em fases do pacote "eras + minigames". Cada fase fecha uma rodada jogável
(com teste e fotos) antes da próxima.

## Base comum (Fase 1 — feita)

- **Minigames como cenas separadas** (`scenes/minigames/*.tscn`): a estação chama
  `Minigame.play(jogador, "forge", contexto, callback)` e recebe a **qualidade 0–1**
  (`-1` = desistiu, nada é gasto). Qualidade vai no item (`q` no slot): dano
  ×0,85…1,2 e desgaste ×1,3…0,7. Aparece na dica do item.
- **Interface de itens nas estações com minigame**: os lugares da estação são um
  "baú" do mundo (host guarda; todos veem o mesmo). Arrasta da mochila, escolhe a
  receita e clica no botão do minigame.
- **Eras com aviso estilo conquista**: cada era tem objetivos; completar os
  objetivos-chave abre a próxima era (aviso grande + som). Não trava conteúdo:
  quem trava são os manuais.
- **Diário do jogador** (tecla **J**): era atual e objetivos (guia de quest),
  receitas descobertas por estação (árvore de receitas), manuais lidos e o que
  liberam, pistas (rádio, manuais).
- **Manuais** (achados em casas, ruínas e airdrops): clique com o manual na mão
  para ler. Liberam receitas/estações (igual aos livros de pesquisa do SevTech).
  O livro continua na mochila (dá para emprestar a outro jogador).
- **Forja a carvão com bigorna** (Era 1): metal + carvão nos lugares, escolhe a
  peça, minigame de **temperatura por cor** (shader que interpola a cor do metal
  pela temperatura). Bate só na faixa certa; fora dela racha (3 rachaduras = peça
  perdida, sobra sucata).
- **Trefiladora** (sem minigame): barra de cobre vira fio de cobre com eixo/motor.
  Fio de cobre rende mais cabo e bobina.

## Fase 2 — Metal fundido e solda (Eras 2-3) — feita

- **Estanho**: parte dos veios de cobre (40%) e de ferro (12%) virou veio de estanho
  (pedra com cristais cinza-prata), escolhido pela posição: saves antigos mantêm as
  chaves. Fornalha: minério de estanho -> barra de estanho.
- **Fundição** (aba Máquinas): 4 lugares (metal, liga, carvão, peça). Bronze = 3 cobre +
  1 estanho (4 barras); engrenagens, polias, canos e machado de bronze fundidos.
- **Minigame de despejar (3D)**: a altura do mouse inclina o cadinho (W/S/roda: fino).
  O metal só passa da borda com inclinação, e precisa inclinar mais quanto mais vazio.
  Vazão na faixa verde enche bem; rápido espirra (perde metal); devagar forma emenda
  fria; passou de cheio transborda; demorou, o metal endurece no cadinho. Pilhas
  (barras, engrenagens) saem em menor quantidade com qualidade baixa.
- **Bancada de solda** (aba Elétrica, Manual de soldagem): elétrica, 300 W. Chapas de
  aço + eletrodos (mesa) viram só armaduras: capacete soldado, couraça, grevas.
- **Minigame de solda**: segure o clique na junta e siga até o fim; velocidade na faixa
  verde. Rápido = cordão fino (solda fraca), devagar = grosso, parado = fura a chapa,
  longe da junta = só respinga. Máscara de solda escurece a tela com o arco aceso.
- Qualidade da armadura muda a proteção (x0,85…1,2) e quanto ela aguenta.
- **Chapas soldadas** (bancada de solda: 3 ferro + 1 eletrodo = 2 chapas): parede,
  piso, telhado e viga de chapa e porta de chapa. Zumbi precisa de 6 golpes por
  pedaço (madeira: 2); porta de chapa aguenta 16 (madeira: 6). Conserto com chapa.
- **Bancada de maçarico** (Manual de soldagem): solda cobre com estanho, a álcool,
  óleo ou gás (botijão achado nas casas = 8 soldas). Serpentina de cobre, células de
  bateria (2 por vez) e lâmpadas (4 por vez). Minigame de solda no modo maçarico.
- Ficou para depois: tornos e serras manuais com qualidade.

## Fase 3 — Elétrica 2 (Era 3) — feita

- **Tensão por rede**: fontes de 12 V (painel solar, bateria, dínamo regulado em 12) e
  de 110 V (dínamo regulado em 110 com [E], banco de baterias). Rede com fonte de 110 V
  vira 110 V: painel de 12 V fica bloqueado e bateria de 12 V queima o fusível ([E]
  troca). Quase tudo é bivolt; a bancada de solda só liga em 110 V.
- **Perda nos cabos**: 12 V perde 0,4% por metro (25 m = 10%); 110 V perde 10x menos.
- **Banco de baterias (110 V)**: 9 células em série (só funciona completo), 2700 Wh.
- **Carregador** (110 -> 12 V, 400 W, 90%) e **inversor** (12 -> 110 V, 600 W, 85%):
  dois bornes (entrada à esquerda, saída à direita), passam a sobra de uma rede para a
  outra. Pedirem mais que o máximo na saída esquenta; demais, queima ([E] com bobina).
- **Desgaste e sobrecarga das baterias**: cada ciclo inteiro gasta 0,4% da saúde;
  ficar vazia com aparelho pedindo gasta mais; tirar acima do normal (até 1,5x) esquenta
  e uma célula estoura. Célula nova sobe a saúde média.
- Futuro: bancada de eletrônicos com módulo de controle e módulo de temperatura
  (máquinas mantêm a temperatura sozinhas).

## Fase 4 — Química e refino (Era 4) — feita

- **Bancada química** (aba Máquinas, Manual de química): balão de vidro no queimador,
  serpentina na tina e três relógios. 3 lugares de reagente (qualquer ordem), queimador
  (carvão, álcool, óleo, biodiesel = 2 lotes, botijão = 8 lotes) e o produto. Água em
  garrafa: a garrafa volta (menos no ácido, que fica nela).
- **Minigame das válvulas**: Gás (chama), Alívio (purga) e Saída (dosagem) mexem em
  Temperatura, Pressão e Vazão, que se puxam (calor sobe a pressão, pressão empurra a
  vazão). Cada receita tem a sua faixa verde nos três relógios; a reação só anda com o
  balão quente e o líquido correndo, e a qualidade é o quanto os ponteiros ficaram na
  faixa. Imprevistos: bolha de vapor, corrente de ar, saída entupida. Vermelho por tempo
  demais = acidente: pólvora quente **explode**, ácido com pressão **vaza gás tóxico**,
  o resto estoura a vedação (perde a mistura). Qualidade = quantidade que sai.
- Receitas: salitre (adubo + água), **pólvora** (salitre, enxofre, carvão — fria),
  **biodiesel** (óleo + álcool), **plástico** (farinha + óleo + água), **ácido de bateria**
  (enxofre + água — quente e com pressão), carvão ativado (carvão + água — bem quente).
- **Enxofre**: veios amarelos (20% dos veios de carvão e 30% das rochas do deserto).
- Mesa: **cartuchos** (cobre + estanho + pólvora = 12), **filtro** (carvão ativado + pano +
  plástico = 2), **máscara de gás** (plástico, vidro, couro, filtro), cabo com plástico.
- **Armas de fogo** (todas com mira de ferro: segure o botão direito, zoom e menos dispersão):
  - Revólver: balas de revólver, tambor de 6, 40 de dano (cabeça = 1 tiro), 0,3 s, recarga 1,9 s.
  - **Rifle de um tiro**: balas de rifle, 115 de dano, atravessa até 3 zumbis (-30% cada),
    190 m, recarga 1,6 s. Na mesa: rifle + **luneta** = rifle com luneta (zoom forte, luneta na tela).
  - **Espingarda de dois canos**: cartuchos de espingarda, 8 bagos de 18, 2 tiros, recarga
    2,3 s; perde força depois de 7 m (até 30%).
  - Cada arma guarda o que está carregado; a munição é rara: só na mesa (Manual de química)
    ou no saque das zonas contaminadas.
- **Ácido** na mão + [E] na bateria: +50% de saúde das células (banco de 110 V: +20%).
- **Biodiesel**: carro +60%, maçarico e queimador rendem 2 por unidade.
- **Zonas contaminadas**: miolo das cidades grandes (sempre) e de metade das médias, e 3
  fábricas químicas abandonadas (laje, tanques vazando, chaminé com fumaça verde, galpão,
  barris, 3 caixotes). Névoa amarelo-esverdeada, placas de perigo na borda, círculo no
  mapa. O gás é pesado (até 14 m do chão: telhado alto respira). Sem máscara: intoxicação
  sobe, tosse, a vida cai, acima de 60% fica doente. **Máscara de gás** (cabeça, sem
  capacete): o filtro dura 3 min no gás cheio e troca sozinho por um da mochila; lentes
  na tela e medidor de filtro/intoxicação no canto. Saque "contaminado" lá dentro.
- Conquistas da Era 4: Laboratório (chave), Cheiro de ovo, Pólvora, Munição, Refinaria,
  Plástico, Eletrólito novo, Respirar fundo, Zona morta, Mão firme.

## Fase 5 — Reconstrução (Era 5)

- **Rádio 2**: sintonizar no ruído, decodificar Morse, triangular o sinal com duas
  leituras em lugares diferentes e marcar a origem no mapa.
- **Cofres e portas de ruínas**: combinação por som, chave improvisada ou cortar a
  dobradiça com maçarico (escolher o método é parte do puzzle).
- **Veículos restauráveis**: projeto em partes (motor, rodas, bateria,
  combustível); alguns vêm com peças inteiras; peças retiráveis (motor vira
  gerador).
- Contato com outras comunidades (pedidos maiores, troca).

## Eras

| Era | Nome | Objetivos-chave (abrem a próxima) |
|---|---|---|
| 0 | Sobrevivente | sucata, ferramenta improvisada, fogueira |
| 1 | Ferreiro de sucata | forja a carvão, barra de ferro, primeira peça forjada |
| 2 | Mecânica | roda d'água ou moinho de vento, serraria ou torno, bronze |
| 3 | Eletrificação | dínamo ou painel solar, bateria |
| 4 | Química/refino | destilaria, álcool, bancada química |
| 5 | Reconstrução | rádio, pedido entregue (veículos na Fase 5) |
