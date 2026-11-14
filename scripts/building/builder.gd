class_name Builder
extends Node
## Ferramentas de construção na mão do player (só o jogador local tem).
##
## Martelo: mostra a peça "fantasma" na grade (verde = cabe, vermelho = já tem
## peça ali). Clique constrói, R gira a parede, Shift + botão direito desmonta a peça
## (ou tira a janela/porta) mirada. SEGURAR o botão direito abre o menu de
## construção (abas + lista com rolagem): solte em cima do item para escolher.
## Encaixes: parede mirando um piso/teto vai para a borda mais perto dele;
## mirando o topo de uma parede empilha; piso/teto mirando a borda de outro
## piso vai para o lado; teto mirando o topo de uma parede cobre o cômodo.
## Janela/Porta: mire um buraco feito pela talhadeira; ela preenche o buraco
## inteiro (qualquer formato). A porta precisa de um buraco que encoste na base
## da parede.
##
## Talhadeira: clique tira o meio quadrado mirado (triângulo); R troca a
## diagonal do corte ("/" ou "\\"). Clique e ARRASTE seleciona uma área
## (retângulo de quadrados) e tira tudo ao soltar.
##
## Custo: cada peça gasta material do inventário ("cost"); desmontar devolve
## metade. Aba Outros: potes, floreira, canteiro (piso de terra na grade) e
## bancada de fabricação (PlacedManager).

const REACH := 7.0
const MASK := 1 | (1 << 5) # mundo + interagíveis (armadilhas no chão)
const ENTRIES := {
	"Estrutura": [
		{"id": "wall", "name": "Parede", "kind": BuildPiece.Kind.WALL, "desc": "2,8 x 2,8 m; R gira", "cost": {&"tabua": 4}},
		{"id": "floor", "name": "Piso", "kind": BuildPiece.Kind.FLOOR, "desc": "Topo na altura da grade", "cost": {&"tabua": 4}},
		{"id": "roof", "name": "Teto", "kind": BuildPiece.Kind.ROOF, "desc": "Apoia no topo das paredes. R: telhado inclinado (45°), subindo para o seu lado: de dentro da casa, sobe da parede para o meio", "cost": {&"tabua": 4}},
		{"id": "pillar", "name": "Pilar", "kind": BuildPiece.Kind.PILLAR, "desc": "0,4 m de lado, 2,8 m de altura. R deita (viga): em cima de uma parede cobre o topo dela", "cost": {&"tabua": 1, &"pedra": 1}},
		{"id": "wall_metal", "name": "Parede de chapa", "kind": BuildPiece.Kind.WALL, "mat": BuildPiece.Mat.METAL, "desc": "Chapas de aço soldadas (bancada de solda): zumbi precisa de 3x mais golpes para abrir buraco. R gira", "cost": {&"chapa": 2}},
		{"id": "floor_metal", "name": "Piso de chapa", "kind": BuildPiece.Kind.FLOOR, "mat": BuildPiece.Mat.METAL, "desc": "Chapa xadrez soldada", "cost": {&"chapa": 2}},
		{"id": "roof_metal", "name": "Telhado de chapa", "kind": BuildPiece.Kind.ROOF, "mat": BuildPiece.Mat.METAL, "desc": "Chapa ondulada. R: inclinado (45°)", "cost": {&"chapa": 1}},
		{"id": "pillar_metal", "name": "Viga de aço", "kind": BuildPiece.Kind.PILLAR, "mat": BuildPiece.Mat.METAL, "desc": "Viga em I de chapa soldada. R deita", "cost": {&"chapa": 1}},
		{"id": "wall_stone", "name": "Parede de pedra", "kind": BuildPiece.Kind.WALL, "mat": BuildPiece.Mat.STONE, "desc": "Pedras do chão assentadas em amarração: zumbi precisa de 2,5x mais golpes que na madeira. R gira", "cost": {&"pedra": 10}},
		{"id": "floor_stone", "name": "Piso de pedra", "kind": BuildPiece.Kind.FLOOR, "mat": BuildPiece.Mat.STONE, "desc": "Lajes de pedra", "cost": {&"pedra": 8}},
		{"id": "pillar_stone", "name": "Pilar de pedra", "kind": BuildPiece.Kind.PILLAR, "mat": BuildPiece.Mat.STONE, "desc": "Pedras empilhadas, 0,4 m de lado. R deita", "cost": {&"pedra": 3}},
		{"id": "wall_earth", "name": "Parede de taipa", "kind": BuildPiece.Kind.WALL, "mat": BuildPiece.Mat.EARTH, "desc": "Terra cavada do chão socada em camadas, com gravetos: mais forte que madeira (3 golpes por pedaço) e barata. R gira", "cost": {&"terra": 8, &"graveto": 2}},
		{"id": "stairs", "name": "Escada", "place": "stairs", "desc": "Sobe um andar (2,8 m) para a frente", "cost": {&"tabua": 6, &"graveto": 2}},
	],
	"Aberturas": [
		{"id": "window", "name": "Janela", "fill": "window", "desc": "Preenche um buraco feito pela talhadeira", "cost": {&"graveto": 2, &"vidro": 1}},
		{"id": "door", "name": "Porta", "fill": "door", "desc": "Buraco que encoste no chão; [E] abre", "cost": {&"tabua": 3, &"sucata": 1}},
		{"id": "door_metal", "name": "Porta de chapa", "fill": "door", "metal": true, "desc": "Folha de aço soldada com reforços: zumbi demora quase 3x mais para arrombar. [E] abre", "cost": {&"chapa": 2, &"barra_ferro": 1}},
	],
	"Outros": [
		{"id": "pot_small", "name": "Pote", "place": "pot_small", "desc": "Pote de barro: 1 planta (não cabe abóbora)", "cost": {&"pedra": 2}},
		{"id": "pot_wide", "name": "Floreira", "place": "pot_wide", "desc": "Floreira larga: 3 plantas", "cost": {&"tabua": 2, &"pedra": 2}},
		{"id": "bed", "name": "Canteiro", "place": "bed", "desc": "Piso de terra na grade da construção: 9 plantas", "cost": {&"tabua": 3, &"pedra": 4}},
		{"id": "chest", "name": "Baú", "place": "chest", "desc": "Guarda 20 itens (arraste entre o baú e a mochila)", "cost": {&"tabua": 6, &"sucata": 1}},
		{"id": "drawboard", "name": "Lousa", "place": "drawboard", "desc": "Cavalete com tela: desenhe junto com os outros jogadores", "cost": {&"tabua": 4, &"pano": 1}},
	],
	"Máquinas": [
		{"id": "workbench", "name": "Mesa de trabalho", "place": "workbench", "desc": "A bancada de fabricação: ferramentas, armas, lanterna...", "cost": {&"tabua": 6, &"sucata": 3}},
		{"id": "campfire", "name": "Fogueira", "place": "campfire", "desc": "Fogueira com grelha: assa comida (enche mais a fome) e ilumina", "cost": {&"pedra": 5, &"tabua": 3}},
		{"id": "furnace", "name": "Fornalha", "place": "furnace", "desc": "Funde minério em barras, faz vidro e carvão", "cost": {&"pedra": 10, &"tabua": 2}},
		{"id": "rain_collector", "name": "Coletor", "place": "rain_collector", "desc": "Barril com funil: junta água da chuva (potável). Clique nele com uma garrafa vazia", "cost": {&"tabua": 4, &"pano": 1}},
		{"id": "dryer", "name": "Secador", "place": "dryer", "desc": "Varal de galhos: peixe e frutos do lago viram peixe seco (enche mais, não queima)", "cost": {&"graveto": 6, &"pano": 1}},
		{"id": "grindstone", "name": "Amolar", "place": "grindstone", "desc": "Pedra de amolar: segure E com a lâmina/ferramenta na mão para afiar: até +35% de dano, que vai embora com o uso (~25 golpes). Não conserta. Com eixo ou motor elétrico na porta de latão: [E] deixa a ferramenta e ela afia sozinha", "cost": {&"pedra": 6, &"tabua": 2, &"graveto": 2}},
		{"id": "quern", "name": "Moinho", "place": "quern", "desc": "Moinho manual: ponha trigo e segure E para moer em farinha (gasta stamina)", "cost": {&"pedra": 8, &"tabua": 2}},
		{"id": "oven", "name": "Forno", "place": "oven", "desc": "Forno de tijolo: farinha + água = pão (com combustível)", "cost": {&"tijolo": 10, &"pedra": 4}},
		{"id": "pump", "name": "Bomba", "place": "pump", "desc": "Bomba d'água manual: só na beira do lago. Segure E com uma garrafa vazia: água suja sem fim. Com eixo ou motor na porta de latão: põe água no cano sozinha (flange à direita)", "cost": {&"barra_ferro": 2, &"tabua": 3, &"sucata": 2}},
		{"id": "filter", "name": "Filtro", "place": "filter", "desc": "Areia + carvão: ponha água suja e espere, sai potável", "cost": {&"tabua": 3, &"areia": 4, &"carvao": 3, &"pano": 1}},
		{"id": "stone_furnace", "name": "Forn. pedra", "place": "stone_furnace", "desc": "Fornalha de tijolo com fole: a única que funde minério de ferro. Segure E para esquentar no fole. Com eixo ou motor na porta de latão: o fole sopra sozinho", "cost": {&"tijolo": 12, &"pedra": 6, &"pano": 2}},
		{"id": "forge", "name": "Forja", "place": "forge", "desc": "Forja a carvão com bigorna (Era 1). Ponha barras e carvão, escolha a peça e martele no minigame: bata só com o metal na cor certa (fora dela racha). A peça sai com qualidade: mais dano e menos desgaste", "cost": {&"pedra": 12, &"barra_ferro": 4, &"tronco": 1, &"pano": 1}},
		{"id": "foundry", "name": "Fundição", "place": "foundry", "desc": "Fornalhinha com cadinho e caixa de areia com molde (Era 2). Metais + carvão: despeje no molde com a inclinação certa (rápido transborda, devagar esfria antes de encher). Bronze = 3 cobre + 1 estanho; engrenagens, polias, canos e machado fundidos", "cost": {&"tijolo": 8, &"areia": 6, &"barra_ferro": 2, &"pedra": 4}},
		{"id": "torch_bench", "name": "Maçarico", "place": "torch_bench", "manual": &"manual_soldagem", "desc": "Bancada de maçarico a álcool, óleo ou gás (botijão = 8 soldas): solda cobre com estanho. Serpentina, células de bateria (2 por vez) e lâmpadas (4 por vez)", "cost": {&"tabua": 4, &"tijolo": 4, &"barra_ferro": 2, &"cano": 2}},
		{"id": "chem_bench", "name": "Química", "place": "chem_bench", "manual": &"manual_quimico", "desc": "Bancada química (Era 4): balão no queimador (carvão, álcool, óleo, biodiesel ou botijão = 8 lotes), serpentina e três relógios. Reagentes nos lugares e o minigame das válvulas: mantenha temperatura, pressão e vazão na faixa verde. Salitre, pólvora (fria!), biodiesel, plástico, ácido de bateria e carvão ativado", "cost": {&"tabua": 4, &"vidro": 4, &"serpentina": 1, &"cano": 2, &"barra_ferro": 2}},
		{"id": "sieve", "name": "Peneira", "place": "sieve", "desc": "Ponha argila e segure E: cada argila peneirada tem 50% de chance de dar uma pedra. Com eixo ou motor na porta de latão: peneira sozinha", "cost": {&"tabua": 3, &"graveto": 4, &"pano": 1}},
		{"id": "spinning", "name": "Roca", "place": "spinning", "desc": "Fibra de algodão vira fio (segure E)", "cost": {&"tabua": 4, &"graveto": 4, &"sucata": 1}},
		{"id": "loom", "name": "Tear", "place": "loom", "desc": "Fio vira tecido (segure E)", "cost": {&"tabua": 6, &"graveto": 6}},
		{"id": "water_wheel", "name": "Roda d'água", "place": "water_wheel", "desc": "Na beira de um rio, de frente para a água: gira sem parar (força 4). A porta de latão fica na margem", "cost": {&"tabua": 14, &"barra_ferro": 3}},
		{"id": "windmill", "name": "Moinho vento", "place": "windmill", "desc": "Força conforme o vento (até 6, mais alto = mais forte). Porta de latão na base", "cost": {&"tabua": 12, &"tecido": 4, &"barra_ferro": 2}},
		{"id": "sawmill", "name": "Serraria", "place": "sawmill", "desc": "Com energia: 1 tronco vira 12 tábuas (força 3)", "cost": {&"tabua": 8, &"barra_ferro": 4, &"sucata": 2}},
		{"id": "ram_pump", "name": "Carneiro", "place": "ram_pump", "desc": "Na beira de um rio: bombeia água sem energia. Irriga as plantações em volta (10 m crescem 50% mais rápido) e enche garrafas", "cost": {&"barra_ferro": 4, &"sucata": 4, &"tabua": 2}},
		{"id": "smoker", "name": "Defumador", "place": "smoker", "desc": "Peixe cru vira defumado: enche muito e nunca estraga", "cost": {&"tijolo": 4, &"tabua": 4, &"sucata": 1}},
		{"id": "rotisserie", "name": "Assador", "place": "rotisserie", "desc": "Assador giratório: fogueira com espeto de 4 lugares. Com lenha e força no eixo (porta de latão à esquerda, ou motor elétrico) assa e NÃO QUEIMA: o espeto fica girando a comida pronta", "cost": {&"pedra": 6, &"barra_ferro": 2, &"tabua": 2, &"engrenagem_madeira": 1}},
		{"id": "compost", "name": "Composteira", "place": "compost", "desc": "Comida estragada e restos viram adubo (colheitas em dobro)", "cost": {&"tabua": 5, &"graveto": 2}},
	],
	"Vapor": [
		{"id": "blast_furnace", "name": "Alto-forno", "place": "blast_furnace", "desc": "Base do alto-forno: empilhe 2 anéis em cima e ligue um eixo com força no fole. Ferro + carvão = aço", "cost": {&"tijolo": 16, &"pedra": 6, &"barra_ferro": 2}},
		{"id": "blast_stack", "name": "Anel alto-forno", "place": "blast_stack", "desc": "Mire no topo da base do alto-forno (ou de outro anel) para empilhar. Precisa de 2", "cost": {&"tijolo": 10}},
		{"id": "boiler", "name": "Caldeira", "place": "boiler", "desc": "Fogo + água = vapor para o motor. Água pelo cano (latão à esquerda) ou despejada com garrafa. SECA E QUENTE, EXPLODE", "cost": {&"barra_aco": 4, &"tijolo": 6, &"barra_cobre": 2, &"parafuso": 4}},
		{"id": "steam_engine", "name": "Motor a vapor", "place": "steam_engine", "desc": "Vapor da caldeira (cano no alto do cilindro) vira força 10 nos eixos (porta à direita)", "cost": {&"barra_aco": 3, &"engrenagem": 2, &"parafuso": 6, &"eixo_aco": 1, &"oleo": 1}},
		{"id": "pipe_pump", "name": "Bomba de recalque", "place": "pipe_pump", "desc": "No meio do cano (flanges na frente e atrás): com eixo ou motor elétrico na porta de latão (carga 1), a água da rede SOBE. Sem ela, caixa d'água e coletor só mandam água para baixo", "cost": {&"barra_ferro": 4, &"engrenagem": 1, &"barra_cobre": 2, &"parafuso": 2}},
		{"id": "water_tank", "name": "Caixa d'água", "place": "water_tank", "desc": "Guarda 60 de água (4 portas). Guarda o que sobra e solta quando falta. [E] enche garrafa", "cost": {&"tabua": 8, &"barra_ferro": 2}},
		{"id": "sprinkler", "name": "Aspersor", "place": "sprinkler", "desc": "Com água no cano, molha as plantações a 8 m: crescem 50% mais rápido", "cost": {&"barra_cobre": 2, &"parafuso": 1}},
		{"id": "lathe", "name": "Torno", "place": "lathe", "desc": "Com eixo girando: parafusos, engrenagens, eixo de aço e canos", "cost": {&"tabua": 6, &"barra_ferro": 4, &"sucata": 2}},
		{"id": "wire_drawer", "name": "Trefiladora", "place": "wire_drawer", "manual": &"manual_eletricista", "desc": "Com eixo ou motor na porta de latão: 1 barra de cobre vira 8 fios de cobre (cabo e bobina rendem bem mais)", "cost": {&"tabua": 6, &"barra_ferro": 4, &"engrenagem": 1}},
		{"id": "press", "name": "Prensa", "place": "press", "desc": "Com eixo girando: fruta = suco; sementes de algodão ou gordura = óleo", "cost": {&"tabua": 6, &"barra_ferro": 3, &"parafuso": 2}},
		{"id": "distillery", "name": "Destilaria", "place": "distillery", "desc": "Fogo + água + trigo, fruta ou batata = álcool (combustível dos carros e antisséptico)", "cost": {&"barra_cobre": 6, &"tijolo": 6, &"cano": 2}},
	],
	"Elétrica": [
		{"id": "drill", "name": "Perfuratriz", "place": "drill", "desc": "Só elétrica (400 W, cabo no borne em cima): em cima de uma JAZIDA (o veio colorido no salão do fim das cavernas) tira 1 minério a cada 5 s, sem a jazida acabar. Guarda 100; [E] pega", "cost": {&"barra_aco": 4, &"engrenagem": 2, &"bobina": 2, &"parafuso": 6}},
		{"id": "connector", "name": "Conector", "place": "connector", "desc": "Poste com isolador para emendar cabos. Mirando uma parede, vai na parede", "cost": {&"tabua": 2, &"argila": 1}},
		{"id": "insulator", "name": "Isolador", "place": "insulator", "desc": "Isolador de cerâmica: vai na parede, no teto ou no chão e leva o cabo esticado, rente à superfície (organiza a fiação)", "cost": {&"argila": 1}},
		{"id": "switch", "name": "Interruptor", "place": "switch", "desc": "No chão (pedestal) ou na parede. Dois bornes: um cabo na entrada e outro na saída; desligado, a energia não passa. [E] liga/desliga", "cost": {&"barra_cobre": 1, &"tabua": 1}},
		{"id": "electric_motor", "name": "Motor elétrico", "place": "electric_motor", "desc": "Encaixa na porta de latão de qualquer máquina de rotação (moinho, roca, tear, serraria, torno, prensa, peneira, fole, amolar, bomba, assador...): com energia dá força 4 a ela. Gasta 300 W, só com a máquina trabalhando. Não move dínamo", "cost": {&"bobina": 2, &"barra_ferro": 3, &"parafuso": 2}},
		{"id": "dynamo", "name": "Dínamo", "place": "dynamo", "desc": "Eixo com força na porta de latão (carga 2) vira 600 W. [E] no regulador: 12 V (carrega bateria direto) ou 110 V (bancada de solda, banco de baterias; bateria de 12 V só pelo carregador). Ponteiro: quanto da geração está sendo usado", "cost": {&"bobina": 2, &"barra_ferro": 4, &"barra_cobre": 2, &"parafuso": 4}},
		{"id": "solar_panel", "name": "Painel solar", "place": "solar_panel", "desc": "Até 300 W em 12 V com sol a pino (nublado e chuva rendem menos, noite nada). Numa rede de 110 V fica bloqueado", "cost": {&"vidro": 4, &"barra_cobre": 3, &"bobina": 1, &"barra_ferro": 2}},
		{"id": "battery", "name": "Bateria", "place": "battery", "desc": "Bateria de 12 V: estrutura para até 6 células (mesa ou maçarico). [E] com célula: põe uma. Cada célula guarda 300 Wh e dá 500 W (até 750 W esquentando: demais, estoura). Gasta com os ciclos. Numa rede de 110 V queima o fusível ([E] troca)", "cost": {&"tabua": 4, &"barra_ferro": 1, &"barra_cobre": 1}},
		{"id": "battery_bank", "name": "Banco de baterias", "place": "battery_bank", "desc": "110 V: 9 células em série (só funciona com as 9). Guarda 2700 Wh e dá até 4500 W. Liga direto no dínamo em 110 V e na bancada de solda", "cost": {&"barra_ferro": 6, &"barra_cobre": 4, &"tabua": 2}},
		{"id": "charger", "name": "Carregador", "place": "charger", "desc": "Carregador de baterias: 110 V na entrada (borne da esquerda) vira 12 V na saída (direita), até 400 W (90%). Consumo maior na saída esquenta e queima ([E] com bobina conserta)", "cost": {&"bobina": 2, &"cabo": 2, &"barra_ferro": 2}},
		{"id": "inverter", "name": "Inversor", "place": "inverter", "desc": "12 V na entrada (esquerda) vira 110 V na saída (direita), até 600 W (85%): bancada de solda no painel solar e nas baterias de 12 V. Sobrecarga esquenta e queima", "cost": {&"bobina": 3, &"cabo": 2, &"barra_cobre": 2, &"barra_ferro": 1}},
		{"id": "lamp", "name": "Lâmpada", "place": "lamp", "desc": "Luz elétrica (50 W). No chão vira lampadário; mirando uma parede, arandela. Para apagar, ponha um interruptor no cabo", "cost": {&"lampada": 1, &"barra_ferro": 1, &"barra_cobre": 1}},
		{"id": "electric_fence", "name": "Cerca elétrica", "place": "electric_fence", "desc": "2,4 m de fios: com energia (100 W) dá choque em quem encosta (dano e tontura)", "cost": {&"tabua": 3, &"barra_cobre": 2, &"cabo": 2, &"argila": 2}},
		{"id": "fridge", "name": "Geladeira", "place": "fridge", "desc": "Guarda 21 itens; ligada (150 W) a comida quase não estraga. Desligada estraga como num baú", "cost": {&"tabua": 8, &"barra_ferro": 4, &"cano": 2, &"bobina": 1, &"barra_cobre": 2}},
		{"id": "radio", "name": "Rádio", "place": "radio", "desc": "Ligado (50 W) pega transmissões: direção da horda, airdrops no mapa e pedidos de sobreviventes (com recompensa)", "cost": {&"tabua": 4, &"vidro": 2, &"barra_cobre": 3, &"bobina": 1, &"lampada": 2}},
		{"id": "electric_pump", "name": "Bomba elétrica", "place": "electric_pump", "desc": "Poço: com energia (200 W) põe 1,5 de água por segundo no cano, em qualquer lugar", "cost": {&"barra_ferro": 4, &"bobina": 1, &"cano": 2, &"parafuso": 2}},
		{"id": "weld_bench", "name": "Bancada de solda", "place": "weld_bench", "manual": &"manual_soldagem", "desc": "Mesa de aço com transformador (300 W, só em 110 V: dínamo em 110 V, banco de baterias ou inversor): armaduras soldadas e chapas. Minigame: siga a junta com velocidade constante", "cost": {&"barra_aco": 4, &"bobina": 2, &"cabo": 4, &"tabua": 2}},
	],
	"Decoração": [
		{"id": "deco_table", "name": "Mesa", "place": "deco_table", "desc": "Mesa de madeira (enfeite)", "cost": {&"tabua": 4}},
		{"id": "deco_chair", "name": "Cadeira", "place": "deco_chair", "desc": "Cadeira de madeira (enfeite)", "cost": {&"tabua": 2, &"graveto": 2}},
		{"id": "deco_stool", "name": "Banquinho", "place": "deco_stool", "desc": "Banquinho de três pés", "cost": {&"tabua": 1, &"graveto": 3}},
		{"id": "deco_rug", "name": "Tapete", "place": "deco_rug", "desc": "Tapete de pano com franja (dá para pisar)", "cost": {&"pano": 4}},
		{"id": "deco_vase", "name": "Vaso", "place": "deco_vase", "desc": "Vaso de barro com flores", "cost": {&"argila": 2}},
		{"id": "deco_plant", "name": "Planta", "place": "deco_plant", "desc": "Planta grande num vaso de barro", "cost": {&"argila": 3, &"graveto": 1}},
		{"id": "deco_barrel", "name": "Barril", "place": "deco_barrel", "desc": "Barril de madeira com cintas de ferro", "cost": {&"tabua": 4, &"barra_ferro": 1}},
		{"id": "deco_crates", "name": "Caixotes", "place": "deco_crates", "desc": "Pilha de caixotes", "cost": {&"tabua": 5}},
		{"id": "deco_painting", "name": "Quadro", "place": "deco_painting", "desc": "Quadro com paisagem: mire uma parede", "cost": {&"tabua": 2, &"pano": 1}},
		{"id": "deco_shelf", "name": "Prateleira", "place": "deco_shelf", "desc": "Prateleira com livros e potes: mire uma parede", "cost": {&"tabua": 2, &"graveto": 2}},
		{"id": "deco_clock", "name": "Relógio", "place": "deco_clock", "desc": "Relógio de parede que marca a hora do jogo: mire uma parede", "cost": {&"tabua": 1, &"barra_cobre": 1, &"vidro": 1}},
	],
	"Fazenda": [
		{"id": "trough", "name": "Cocho", "place": "trough", "desc": "Ponha a comida dos bichos mansos: sementes (galinha), trigo (ovelha, vaca, porco) ou legumes (porco). [E] abre", "cost": {&"tabua": 4, &"graveto": 2}},
		{"id": "water_trough", "name": "Bebedouro", "place": "water_trough", "desc": "Água para os bichos (até 12). Encha com garrafa, chuva ou cano. Comida + água = filhotes", "cost": {&"tabua": 4, &"barra_ferro": 1}},
		{"id": "fence", "name": "Cerca", "place": "fence", "desc": "Cerca de madeira de 2,4 m: segura os bichos (na grade: encaixa ponta com ponta)", "cost": {&"tabua": 2, &"graveto": 2}},
		{"id": "gate", "name": "Porteira", "place": "gate", "desc": "Cerca que abre e fecha com [E]", "cost": {&"tabua": 3, &"graveto": 2, &"sucata": 1}},
	],
	"Armadilhas": [
		{"id": "spikes", "name": "Estacas", "place": "spikes", "desc": "Machucam a perna de quem passa (30 usos)", "cost": {&"tabua": 4}},
		{"id": "beartrap", "name": "Arm. de urso", "place": "beartrap", "desc": "Prende o zumbi: atordoa e quebra a perna. [E] arma de novo", "cost": {&"barra_ferro": 2}},
		{"id": "barbed", "name": "Cerca de espinhos", "place": "barbed", "desc": "Bloqueia; quem bate nela se machuca (12 golpes)", "cost": {&"tabua": 4, &"barra_ferro": 1}},
		{"id": "mine", "name": "Mina", "place": "mine", "desc": "Explode quando um zumbi chega perto (uma vez)", "cost": {&"sucata": 2, &"carvao": 3}},
	],
}

## Tamanho (caixa do fantasma) dos objetos da aba Outros.
const PLACE_SIZE := {"pot_small": Vector3(0.46, 0.31, 0.46), "pot_wide": Vector3(1.24, 0.36, 0.48), "bench": Vector3(1.6, 0.9, 0.75),
	"campfire": Vector3(1.0, 0.6, 1.0), "furnace": Vector3(1.2, 1.2, 1.0), "workbench": Vector3(1.9, 1.95, 0.85),
	"spikes": Vector3(1.2, 0.35, 1.2), "beartrap": Vector3(0.55, 0.1, 0.55), "barbed": Vector3(2.4, 1.1, 0.3), "mine": Vector3(0.36, 0.1, 0.36), "drawboard": Vector3(1.1, 1.8, 0.6), "chest": Vector3(1.0, 0.84, 0.62),
	"rain_collector": Vector3(0.8, 1.1, 0.8), "dryer": Vector3(1.5, 1.5, 0.5), "grindstone": Vector3(0.9, 1.1, 0.5),
	"quern": Vector3(0.8, 0.9, 0.8), "oven": Vector3(1.24, 1.1, 1.24), "pump": Vector3(0.6, 1.2, 0.6), "filter": Vector3(0.7, 0.9, 0.45),
	"stone_furnace": Vector3(1.6, 1.6, 1.1), "spinning": Vector3(1.0, 1.1, 0.4), "loom": Vector3(1.3, 1.2, 0.8),
	"smoker": Vector3(0.8, 1.4, 0.6), "compost": Vector3(1.0, 0.7, 0.9), "sieve": Vector3(0.95, 0.8, 0.65),
	"water_wheel": Vector3(1.3, 1.6, 3.2), "windmill": Vector3(1.5, 4.5, 1.5), "shaft": Vector3(2.0, 0.7, 0.5),
	"sawmill": Vector3(2.1, 0.9, 0.75), "ram_pump": Vector3(0.6, 1.8, 2.0), "stairs": Vector3(1.2, 2.8, 2.8),
	"blast_furnace": Vector3(1.6, 1.3, 1.6), "blast_stack": Vector3(1.4, 1.05, 1.4), "boiler": Vector3(2.3, 2.9, 1.15),
	"steam_engine": Vector3(1.6, 1.4, 1.4), "water_tank": Vector3(1.1, 1.45, 1.1), "sprinkler": Vector3(0.36, 0.8, 0.36),
	"lathe": Vector3(2.0, 1.1, 0.6), "press": Vector3(1.3, 1.7, 0.8), "distillery": Vector3(1.7, 1.45, 0.9), "pipe": Vector3(0.18, 0.18, 1.0), "pipe_stand": Vector3(0.5, 0.5, 0.5), "pipe_pump": Vector3(0.75, 0.55, 0.9),
	"trough": Vector3(1.5, 0.6, 0.5), "water_trough": Vector3(1.32, 0.5, 0.55), "fence": Vector3(2.4, 1.15, 0.14), "gate": Vector3(2.4, 1.15, 0.14),
	"connector": Vector3(0.24, 1.3, 0.24), "connector_wall": Vector3(0.14, 0.22, 0.2), "dynamo": Vector3(1.0, 0.9, 0.6), "solar_panel": Vector3(1.3, 1.25, 0.9),
	"battery": Vector3(0.9, 0.8, 0.55), "lamp": Vector3(0.36, 1.7, 0.36), "lamp_wall": Vector3(0.2, 0.3, 0.32), "electric_fence": Vector3(2.5, 1.35, 0.16),
	"fridge": Vector3(0.8, 1.75, 0.7), "radio": Vector3(0.7, 0.7, 0.45), "electric_pump": Vector3(0.6, 0.95, 0.6),
	"deco_table": Vector3(1.2, 0.78, 0.7), "deco_chair": Vector3(0.44, 0.98, 0.44), "deco_stool": Vector3(0.38, 0.54, 0.38), "deco_rug": Vector3(1.8, 0.03, 1.2),
	"deco_vase": Vector3(0.3, 0.7, 0.3), "deco_plant": Vector3(0.6, 0.9, 0.6), "deco_barrel": Vector3(0.64, 0.9, 0.64), "deco_crates": Vector3(1.1, 0.96, 0.55),
	"deco_painting": Vector3(0.9, 0.7, 0.06), "deco_shelf": Vector3(1.0, 0.3, 0.26), "deco_clock": Vector3(0.48, 0.48, 0.08),
	"torch": Vector3(0.14, 0.8, 0.14), "torch_wall": Vector3(0.14, 0.35, 0.2),
	"insulator": Vector3(0.08, 0.08, 0.08), "switch": Vector3(0.26, 1.1, 0.26), "switch_wall": Vector3(0.24, 0.26, 0.08),
	"electric_motor": Vector3(0.7, 0.8, 0.42), "rotisserie": Vector3(1.6, 1.0, 0.9), "forge": Vector3(2.5, 2.65, 1.05), "wire_drawer": Vector3(2.0, 1.0, 0.7),
	"foundry": Vector3(2.2, 1.7, 1.2), "weld_bench": Vector3(1.9, 1.5, 0.85), "torch_bench": Vector3(1.9, 1.3, 0.85), "chem_bench": Vector3(1.75, 1.65, 0.85),
	"battery_bank": Vector3(1.35, 0.85, 1.0), "charger": Vector3(0.5, 0.7, 0.36), "inverter": Vector3(0.5, 0.7, 0.36),
	"drill": Vector3(1.6, 2.7, 1.3)}
## Centro da caixa (vermelha, ao desmontar) quando não é logo acima da origem.
const PLACE_CENTER := {"bed": Vector3(1.4, 0.1, 1.4), "stairs": Vector3(0, 1.4, -1.4), "steam_engine": Vector3(0.45, 0.7, -0.3),
	"distillery": Vector3(0.15, 0.72, 0), "boiler": Vector3(0, 1.45, 0), "pipe": Vector3(0, 0, 0.5),
	"connector_wall": Vector3(0, 0, 0.1), "lamp_wall": Vector3(0, 0, 0.16), "deco_painting": Vector3(0, 0, 0.03), "deco_shelf": Vector3(0, 0.05, 0.13),
	"deco_clock": Vector3(0, 0, 0.04), "torch_wall": Vector3(0, -0.05, 0.1), "insulator": Vector3(0, 0, 0.04),
	"switch_wall": Vector3(0, 0, 0.04), "electric_motor": Vector3(0.38, -0.2, 0), "forge": Vector3(-0.2, 1.32, 0), "wire_drawer": Vector3(-0.05, 0.5, 0),
	"foundry": Vector3(0.1, 0.85, 0), "weld_bench": Vector3(-0.05, 0.75, 0), "torch_bench": Vector3(0.05, 0.65, 0), "chem_bench": Vector3(-0.05, 0.8, 0)}
## Deslocamento da origem na grade (a escada tem 3 quadrados de largura: borda na linha da grade).
const GRID_OFFSET := {"stairs": Vector3(0.2, 0, 0)}
const PLACE_RADIUS := {"pot_small": 0.35, "pot_wide": 0.7, "bench": 0.9, "campfire": 0.6, "furnace": 0.8, "workbench": 1.0,
	"spikes": 0.7, "beartrap": 0.35, "barbed": 0.9, "mine": 0.3, "drawboard": 0.6, "chest": 0.6, "rain_collector": 0.5, "dryer": 0.8, "grindstone": 0.5,
	"quern": 0.5, "oven": 0.7, "pump": 0.35, "filter": 0.45, "stone_furnace": 0.9, "spinning": 0.55, "loom": 0.7, "smoker": 0.5, "compost": 0.6, "sieve": 0.55,
	"water_wheel": 0.6, "windmill": 0.9, "shaft": 0.3, "sawmill": 1.0, "ram_pump": 0.4, "stairs": 0.6,
	"blast_furnace": 0.9, "blast_stack": 0.1, "boiler": 1.1, "steam_engine": 0.9, "water_tank": 0.6, "sprinkler": 0.25,
	"lathe": 1.0, "press": 0.7, "distillery": 0.9, "drill": 0.9, "pipe_pump": 0.45, "trough": 0.8, "water_trough": 0.7, "fence": 0.15, "gate": 0.15,
	"connector": 0.2, "dynamo": 0.7, "solar_panel": 0.7, "battery": 0.6, "lamp": 0.25, "electric_fence": 0.15, "fridge": 0.5, "radio": 0.45, "electric_pump": 0.4,
	"deco_table": 0.7, "deco_chair": 0.3, "deco_stool": 0.25, "deco_rug": 0.3, "deco_vase": 0.2, "deco_plant": 0.3, "deco_barrel": 0.4, "deco_crates": 0.6,
	"deco_painting": 0.12, "deco_shelf": 0.12, "deco_clock": 0.12, "insulator": 0.06, "switch": 0.15, "electric_motor": 0.1,
	"rotisserie": 0.8, "forge": 1.1, "wire_drawer": 0.95, "foundry": 1.0, "weld_bench": 0.9, "torch_bench": 0.9, "chem_bench": 0.9, "battery_bank": 0.75, "charger": 0.3, "inverter": 0.3}

var player: Player
var selection: Dictionary = ENTRIES["Estrutura"][0]
var kind := BuildPiece.Kind.WALL
var flip := false ## R: gira a parede (o padrão é ficar de frente para quem constrói), deita o pilar (viga) ou inclina o teto (telhado)
var target := {} ## onde o martelo vai construir {kind, cell, rot, valid}
var fill_target := {} ## buraco mirado para janela/porta {piece, tris, valid}
var cut_target := {} ## {piece, quarters}: meio quadrado mirado pela talhadeira
var repair_target: BuildPiece ## peça com dano de zumbi mirada (clique conserta)
var cut_selection := PackedInt32Array() ## partes (quartos) da área arrastada
var diag := "/" ## diagonal do corte da talhadeira (R troca)

var _ghost: Node3D
var _ghost_mesh: MeshInstance3D
var _ghost_material: StandardMaterial3D
var _model_ghost: Node3D ## silhueta do modelo de verdade (objetos colocáveis)
var _model_material: StandardMaterial3D
var _model_kind := ""
var _remove_mesh: MeshInstance3D ## Shift: caixa vermelha no que o clique direito desmonta
var _highlight: MeshInstance3D
var _highlight_mesh := ImmediateMesh.new()
var _mark: StandardMaterial3D
var _drag := {} # talhadeira arrastando: {piece, square, triangle}
## Martelo arrastando (pôr em massa): {"kind", "rot", "start", "end": célula}. Parede: fileira
## (e andares, subindo); piso/teto: área; pilar: linha. Até ROW_MAX peças.
var _row := {}
var _row_ghosts: Array[MeshInstance3D] = []
var _row_ok: StandardMaterial3D
var _row_bad: StandardMaterial3D
const ROW_MAX := 24
var _menu: BuildMenu


func _ready() -> void:
	_ghost = Node3D.new()
	_ghost.top_level = true
	add_child(_ghost)
	_ghost_mesh = MeshInstance3D.new()
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost_mesh.material_override = _ghost_material
	_ghost_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.add_child(_ghost_mesh)
	_model_material = StandardMaterial3D.new()
	_model_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_model_material.cull_mode = BaseMaterial3D.CULL_BACK
	_model_material.roughness = 1.0
	_model_ghost = Node3D.new()
	_ghost.add_child(_model_ghost)
	_remove_mesh = MeshInstance3D.new()
	_remove_mesh.top_level = true
	var remove_mat := StandardMaterial3D.new()
	remove_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	remove_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	remove_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	remove_mat.albedo_color = Color(1.0, 0.2, 0.15, 0.28)
	_remove_mesh.material_override = remove_mat
	_remove_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_remove_mesh.visible = false
	add_child(_remove_mesh)
	_highlight = MeshInstance3D.new()
	_highlight.top_level = true
	_highlight.mesh = _highlight_mesh
	_mark = StandardMaterial3D.new()
	_mark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mark.albedo_color = Color(1.0, 0.85, 0.2, 0.55)
	_mark.cull_mode = BaseMaterial3D.CULL_DISABLED
	_highlight.material_override = _mark
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_highlight)
	_menu = BuildMenu.new()
	_menu.builder = self
	add_child(_menu)
	_set_ghost_shape()


## Modelo para a foto do menu (a peça em si; janela/porta numa parede com o buraco).
static func preview_model(entry: Dictionary) -> Node3D:
	if entry.has("place"):
		var obj := PlacedObject.new()
		obj.setup(entry.place)
		if entry.place == "pot_small" or entry.place == "pot_wide":
			obj.crops[0] = {"crop": "cenoura", "t": -1000.0} # com uma planta, para a foto
			obj.refresh(0.0)
		return obj
	var piece := BuildPiece.new()
	if entry.has("kind"):
		piece.setup(entry.kind, Vector3i.ZERO, 0, entry.get("mat", BuildPiece.Mat.WOOD))
		return piece
	piece.setup(BuildPiece.Kind.WALL, Vector3i.ZERO, 0)
	var parts := PackedInt32Array()
	var rows := range(0, 5) if entry.fill == "door" else range(2, 5)
	for j in rows:
		for i in range(2, 5):
			for q in 4:
				parts.append((j * BuildPiece.N + i) * 4 + q)
	for t in parts:
		piece.removed[t] = 1
	piece.add_fill(entry.fill, parts, false, entry.get("metal", false))
	return piece


func _manager() -> BuildingManager:
	return player.get_parent().get_node_or_null("Building") as BuildingManager


func tool_name() -> String:
	if repair_target:
		return "Consertar  [%s]" % cost_text(repair_cost(repair_target), player.inventory)
	var text: String = "%s%s" % [selection.name, "  (girada)" if flip and selection.get("kind", -1) == BuildPiece.Kind.WALL else
		("  (inclinado)" if flip and selection.get("kind", -1) == BuildPiece.Kind.ROOF else "")]
	if selection.has("cost"):
		text += "  [%s]" % cost_text(selection.cost, player.inventory if player else null)
	return text


# --- Custo -----------------------------------------------------------------------

## "4 Tábua, 1 Pedra" (com inventário: "4/10 Tábua").
static func cost_text(cost: Dictionary, inventory: Inventory = null) -> String:
	var parts := []
	for id in cost:
		if inventory:
			parts.append("%d/%d %s" % [inventory.count(id), cost[id], ItemDB.display_name(id)])
		else:
			parts.append("%d %s" % [cost[id], ItemDB.display_name(id)])
	return ", ".join(parts)


## Consertar: 1 tábua a cada 2 quadradinhos quebrados.
static func repair_cost(piece: BuildPiece) -> Dictionary:
	match piece.material:
		BuildPiece.Mat.METAL:
			return {&"chapa": maxi(1, ceili(piece.damaged.size() / 16.0))} # chapa: remenda com chapa nova
		BuildPiece.Mat.STONE:
			return {&"pedra": maxi(1, ceili(piece.damaged.size() / 5.0))} # assenta pedra nova
		BuildPiece.Mat.EARTH:
			return {&"terra": maxi(1, ceili(piece.damaged.size() / 6.0))} # soca terra no buraco
	return {&"tabua": maxi(1, ceili(piece.damaged.size() / 8.0))}


static func can_afford(inventory: Inventory, cost: Dictionary) -> bool:
	if Cheats.creative:
		return true # admin: criativo
	for id in cost:
		if inventory.count(id) < cost[id]:
			return false
	return true


static func pay(inventory: Inventory, cost: Dictionary) -> void:
	if Cheats.creative:
		return # admin: criativo
	for id in cost:
		var left: int = cost[id]
		for i in inventory.slots.size():
			if left <= 0:
				break
			if not inventory.slots[i].is_empty() and inventory.slots[i].id == id:
				left -= inventory.take(i, left).get("amount", 0)


## Desmontou: devolve metade (arredondando para cima).
func _refund(cost: Dictionary) -> void:
	for id in cost:
		var amount := ceili(cost[id] * 0.5)
		var left := player.inventory.add(id, amount)
		if left > 0:
			Net.i.drop_item(id, left, player.global_transform.translated(Vector3.UP), Vector3.ZERO)


func _paid(entry: Dictionary) -> bool:
	var cost: Dictionary = entry.get("cost", {})
	if not can_afford(player.inventory, cost) or not Progress.knows(entry.get("manual", "")):
		Sfx.play("click", -6.0, 0.6)
		return false
	pay(player.inventory, cost)
	return true


static func entry_for_kind(kind_: int, material: Variant = BuildPiece.Mat.WOOD) -> Dictionary:
	var mat := BuildPiece.to_mat(material)
	for entry in ENTRIES["Estrutura"]:
		if entry.get("kind", -1) == kind_ and int(entry.get("mat", BuildPiece.Mat.WOOD)) == mat:
			return entry
	return {}


## Janela/porta (de madeira ou de chapa).
static func entry_for_fill(type: String, metal := false) -> Dictionary:
	for entry in ENTRIES["Aberturas"]:
		if entry.get("fill", "") == type and entry.get("metal", false) == metal:
			return entry
	return {}


static func entry_for(key: String, value: String) -> Dictionary:
	for tab in ENTRIES:
		for entry in ENTRIES[tab]:
			if entry.get(key, "") == value:
				return entry
	return {}


func select(entry: Dictionary) -> void:
	selection = entry
	_apply_ghost(entry)
	player._emit_weapon_text()


func _apply_ghost(entry: Dictionary) -> void:
	_ghost_mesh.visible = true
	_model_ghost.visible = false
	if entry.has("kind"):
		kind = entry.kind
		_set_ghost_shape()
	elif entry.has("place"):
		if entry.place == "bed":
			kind = BuildPiece.Kind.FLOOR
		_build_model_ghost(entry.place)
		_ghost_mesh.visible = false
		_model_ghost.visible = true


## Copia só as malhas do modelo de verdade (sem colisão, sem grupos, sem fogo
## registrado) para a silhueta translúcida.
func _build_model_ghost(place: String) -> void:
	if place == _model_kind:
		return
	_model_kind = place
	for child in _model_ghost.get_children():
		_model_ghost.remove_child(child)
		child.queue_free()
	var obj := PlacedObject.new()
	obj.setup(place)
	Cooking.fires.erase(obj)
	var stack := [[obj, Transform3D()]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		for child in item[0].get_children():
			if not child is Node3D:
				continue
			var xform: Transform3D = item[1] * child.transform
			if child is MeshInstance3D and child.mesh and child.visible:
				var copy := MeshInstance3D.new()
				copy.mesh = child.mesh
				copy.transform = xform
				copy.material_override = _model_material
				copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_model_ghost.add_child(copy)
			stack.append([child, xform])
	obj.free()


func _tint(valid: bool) -> void:
	_ghost_material.albedo_color = Color(0.3, 1.0, 0.4, 0.35) if valid else Color(1.0, 0.25, 0.2, 0.35)
	_model_material.albedo_color = Color(0.55, 1.0, 0.6, 0.5) if valid else Color(1.0, 0.35, 0.3, 0.5)
	_model_material.emission_enabled = true
	_model_material.emission = Color(0.1, 0.4, 0.15) if valid else Color(0.45, 0.08, 0.05)


func open_menu() -> void:
	_menu.open()


func menu_open() -> bool:
	return _menu.visible


func rotate() -> void:
	flip = not flip


func toggle_diagonal() -> void:
	diag = "\\" if diag == "/" else "/"


## Chamado todo frame pelo player com a ferramenta da mão ("hammer", "chisel" ou "").
func update(tool: String) -> void:
	target = {}
	fill_target = {}
	cut_target = {}
	repair_target = null
	_ghost.visible = false
	_highlight.visible = false
	_remove_mesh.visible = false
	if tool != "chisel":
		_drag = {}
	if tool != "hammer" and not _row.is_empty():
		_row = {}
		_hide_row()
	if _manager() == null or player.vehicle != null or _menu.visible:
		return
	if tool == "hammer":
		if not _row.is_empty():
			_update_row()
			return
		if Input.is_key_pressed(KEY_SHIFT):
			_mark_removal() # o que o Shift + clique direito desmontaria fica vermelho
		# Mirando uma peça quebrada por zumbi: o clique conserta (mostra o dano).
		var aimed := _ray()
		if aimed and aimed.collider is BuildPiece and not aimed.collider.damaged.is_empty():
			repair_target = aimed.collider
			_draw_triangles(repair_target, PackedInt32Array(repair_target.damaged.keys()), Color(0.3, 1.0, 0.45, 0.5))
			return
		if selection.has("place"):
			target = _compute_place()
			if target.is_empty():
				return
			_build_model_ghost(target.get("kind", selection.place)) # parede: a variante de parede
			_ghost.visible = true
			_ghost.global_transform = target.xform
			_tint(target.valid)
			return
		if selection.has("fill"):
			fill_target = _compute_hole()
			if not fill_target.is_empty():
				var color := Color(0.4, 0.7, 1.0, 0.5) if selection.fill == "window" else Color(0.8, 0.5, 0.25, 0.6)
				_draw_triangles(fill_target.piece, fill_target.tris, color if fill_target.valid else Color(1, 0.2, 0.15, 0.5))
			return
		target = _compute_target()
		if target.is_empty():
			return
		_ghost.visible = true
		_ghost.global_transform = BuildPiece.piece_transform(target.kind, target.cell, target.rot)
		_slope_ghost(target)
		_tint(target.valid)
	elif tool == "chisel":
		if not _drag.is_empty():
			_update_drag()
			return
		var hit := _ray()
		if hit.is_empty() or not hit.collider is BuildPiece:
			return
		var piece: BuildPiece = hit.collider
		var half := piece.half_at(hit.position, hit.normal, diag)
		if half.is_empty():
			return
		cut_target = {"piece": piece, "quarters": half}
		_draw_triangles(piece, half, Color(1.0, 0.85, 0.2, 0.55))


## Clique com o martelo (constrói ou encaixa janela/porta)
## ou com a talhadeira (começa a selecionar). Devolve true se fez algo.
func use(tool: String) -> bool:
	var manager := _manager()
	if manager == null or _menu.visible:
		return false
	if tool == "hammer":
		if repair_target:
			var cost := repair_cost(repair_target)
			if _paid({"cost": cost}):
				manager.request_repair(repair_target)
				Sfx.play_at("knock", repair_target.global_position, 0.0, 1.1)
				return true
			return false
		if selection.has("place"):
			if selection.place in ["water_wheel", "ram_pump"] and not target.is_empty() and not _placed().river_bank(target.xform.origin):
				Sfx.play("click", -6.0, 0.6) # só na beira de um rio
				return false
			if selection.place == "pump" and not target.is_empty() and not Farming._shore(target.xform.origin):
				Sfx.play("click", -6.0, 0.6) # bomba só na beira do lago
				return false
			if selection.place == "drill" and not target.is_empty() and TerrainWorld.i and TerrainWorld.i.deposit_near(target.xform.origin) == &"":
				Sfx.play("click", -6.0, 0.6) # perfuratriz só em cima de jazida
				return false
			if not target.is_empty() and target.valid and _paid(selection):
				_placed().request("place", [target.get("kind", selection.place), target.xform])
				Progress.event("place", String(selection.place))
				return true
			return false
		if selection.has("fill"):
			if not fill_target.is_empty() and fill_target.valid and _paid(selection):
				manager.request_fill(fill_target.piece, selection.fill, fill_target.tris, selection.get("metal", false))
				return true
			return false
		if not target.is_empty() and Input.is_action_pressed("attack"):
			# Segurando: arrasta para pôr uma fileira/área (solta para construir).
			_row = {"kind": target.kind, "rot": target.rot, "start": target.cell, "end": target.cell}
			return true
		if not target.is_empty() and target.valid and _paid(selection):
			manager.request_place(target.kind, target.cell, target.rot, selection.get("mat", BuildPiece.Mat.WOOD))
			Progress.event("place", String(selection.id))
			return true
	elif tool == "chisel" and not cut_target.is_empty():
		var piece: BuildPiece = cut_target.piece
		var square: int = cut_target.quarters[0] / 4
		_drag = {"piece": piece, "quarters": cut_target.quarters, "square": Vector2i(square % BuildPiece.N, square / BuildPiece.N)}
		cut_selection = cut_target.quarters
		return true
	return false


# --- Martelo em massa ----------------------------------------------------------------

## Células da fileira/área entre o começo e o fim (passos de uma peça).
func _row_cells() -> Array:
	var a: Vector3i = _row.start
	var e: Vector3i = _row.end
	var n := BuildPiece.N
	var steps := func(from: int, to: int) -> Array:
		var out := []
		var dir := 1 if to >= from else -1
		var count := absi(to - from) / n
		for k in count + 1:
			out.append(from + dir * k * n)
		return out
	var cells := []
	match int(_row.kind):
		BuildPiece.Kind.WALL:
			for y in steps.call(a.y, e.y):
				if int(_row.rot) == 0:
					for x in steps.call(a.x, e.x):
						cells.append(Vector3i(x, y, a.z))
				else:
					for z in steps.call(a.z, e.z):
						cells.append(Vector3i(a.x, y, z))
		BuildPiece.Kind.FLOOR, BuildPiece.Kind.ROOF:
			if BuildPiece.is_slope(_row.kind, _row.rot):
				cells.append(a) # telhado inclinado: um de cada vez
			else:
				for z in steps.call(a.z, e.z):
					for x in steps.call(a.x, e.x):
						cells.append(Vector3i(x, a.y, z))
		_:
			# Pilar: linha no sentido em que mais andou.
			if absi(e.x - a.x) >= absi(e.z - a.z):
				for x in steps.call(a.x, e.x):
					cells.append(Vector3i(x, a.y, a.z))
			else:
				for z in steps.call(a.z, e.z):
					cells.append(Vector3i(a.x, a.y, z))
	return cells.slice(0, ROW_MAX)


func _update_row() -> void:
	if Input.is_action_pressed("attack"):
		var t := _compute_target()
		if not t.is_empty() and t.kind == _row.kind:
			_row.end = t.cell
		_show_row()
		return
	# Soltou: constrói o que couber e der para pagar.
	var manager := _manager()
	var built := 0
	if manager:
		for cell: Vector3i in _row_cells():
			if not manager.can_place(_row.kind, cell, _row.rot):
				continue
			if not _paid(selection):
				break
			manager.request_place(_row.kind, cell, _row.rot, selection.get("mat", BuildPiece.Mat.WOOD))
			built += 1
	if built > 0:
		Progress.event("place", String(selection.id))
	else:
		Sfx.play("click", -6.0, 0.6)
	_row = {}
	_hide_row()


func _show_row() -> void:
	if _row_ok == null:
		_row_ok = _ghost_material.duplicate()
		_row_ok.albedo_color = Color(0.3, 1.0, 0.4, 0.35)
		_row_bad = _ghost_material.duplicate()
		_row_bad.albedo_color = Color(1.0, 0.25, 0.2, 0.35)
	var cells := _row_cells()
	var manager := _manager()
	while _row_ghosts.size() < cells.size():
		var g := MeshInstance3D.new()
		g.top_level = true
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(g)
		_row_ghosts.append(g)
	for k in _row_ghosts.size():
		var g := _row_ghosts[k]
		g.visible = k < cells.size()
		if not g.visible:
			continue
		g.mesh = _ghost_mesh.mesh
		g.global_transform = BuildPiece.piece_transform(_row.kind, cells[k], _row.rot) * _ghost_mesh.transform
		var ok: bool = manager != null and manager.can_place(_row.kind, cells[k], _row.rot)
		g.material_override = _row_ok if ok else _row_bad


func _hide_row() -> void:
	for g in _row_ghosts:
		g.visible = false


## Shift + botão direito (ao soltar): desmonta a peça, janela/porta ou objeto
## mirado e devolve metade do custo. Devolve true se desmontou algo.
func _mark_removal() -> void:
	var hit := _ray()
	if hit.is_empty():
		return
	var node: Object = hit.collider
	if node is BuildFill:
		var fill: BuildFill = node
		_draw_triangles(fill.piece, fill.piece.fills[fill.fill_index].tris, Color(1, 0.2, 0.15, 0.55))
		return
	var box := BoxMesh.new()
	var center := Vector3.ZERO
	if node is BuildPiece:
		var size := BuildPiece.SIZE
		var t := BuildPiece.THICK
		match node.kind:
			BuildPiece.Kind.WALL:
				box.size = Vector3(size, size, t)
				center = Vector3(size * 0.5, size * 0.5, 0)
			BuildPiece.Kind.FLOOR:
				box.size = Vector3(size, t, size)
				center = Vector3(size * 0.5, -t * 0.5, size * 0.5)
			BuildPiece.Kind.ROOF:
				box.size = Vector3(size, t, size)
				center = Vector3(size * 0.5, t * 0.5, size * 0.5)
			_:
				box.size = Vector3(BuildPiece.SEG, size, BuildPiece.SEG)
				center = Vector3(0, size * 0.5, 0)
	elif node is PlacedObject and node.kind in ["axle", "pipe"]:
		var length: float = node.extra.get("len", 1.0)
		box.size = Vector3(0.18, 0.18, length)
		center = Vector3(0, 0, length * 0.5)
	elif node is PlacedObject and PowerParts.has(node.kind):
		box.size = Vector3(0.5, 0.5, 0.5)
		center = Vector3.ZERO
	elif node is PlacedObject and not node.kind in ["ground", "tree", "airdrop"]:
		box.size = PLACE_SIZE.get(node.kind, Vector3(0.8, 0.8, 0.8))
		center = PLACE_CENTER.get(node.kind, Vector3(0, box.size.y * 0.5, 0))
	else:
		return
	box.size *= 1.03
	_remove_mesh.mesh = box
	_remove_mesh.global_transform = node.global_transform * Transform3D(Basis(), center)
	_remove_mesh.visible = true


func dismantle() -> bool:
	var manager := _manager()
	if manager == null or _menu.visible or player.vehicle != null:
		return false
	var hit := _ray()
	if hit and hit.collider is BuildFill:
		_refund(entry_for_fill(hit.collider.type, hit.collider.metal).get("cost", {}))
		manager.request_unfill(hit.collider.piece, hit.collider.fill_index)
		return true
	if hit and hit.collider is BuildPiece:
		_refund(entry_for_kind(hit.collider.kind, hit.collider.material).get("cost", {}))
		manager.request_remove(hit.collider)
		return true
	if hit and hit.collider is PlacedObject and not hit.collider.kind in ["ground", "tree", "airdrop"]:
		if hit.collider.kind == "pipe":
			player.inventory.add(&"cano", Fluids.pipe_cost(hit.collider.extra.get("len", 1.0))) # cano volta inteiro
		elif hit.collider.kind == "axle":
			player.inventory.add(PowerParts.AXLE_ITEM, PowerParts.axle_cost(hit.collider.extra.get("len", 1.0)))
		elif PowerParts.ITEMS.has(hit.collider.kind):
			player.inventory.add(PowerParts.ITEMS[hit.collider.kind], 1)
			if hit.collider.extra.get("belts", []).size() > 0:
				player.inventory.add(&"correia", hit.collider.extra.belts.size()) # esteiras voltam junto
		elif hit.collider.kind in ["tripod", "pipe_stand"]:
			pass # tripé vem junto com o eixo/cano
		elif hit.collider.kind == "shaft":
			player.inventory.add(PowerParts.AXLE_ITEM, 1) # eixo antigo vira eixo novo
		elif PlacedTorch.has(hit.collider.kind):
			pass # a tocha volta pelo host, com o que sobrou
		else:
			var base := _base_kind(hit.collider.kind)
			_refund(entry_for("place", base).get("cost", {}))
			if Electric.is_battery(base) and Electric.cells(hit.collider) > 0:
				player.inventory.add(Electric.CELL_ITEM, Electric.cells(hit.collider)) # as células voltam inteiras
			if Electric.has(base):
				for other_id in hit.collider.extra.get("cables", []):
					var other: PlacedObject = _placed().objects.get(other_id)
					if other:
						player.inventory.add(Electric.CABLE_ITEM, Electric.cable_cost(Electric.terminal(other).distance_to(Electric.terminal(hit.collider)))) # cabos voltam junto
		_placed().request("remove", [hit.collider.net_id])
		return true
	return false


# --- Talhadeira: seleção de área ---------------------------------------------------

func _update_drag() -> void:
	var piece: BuildPiece = _drag.piece
	if not is_instance_valid(piece):
		_drag = {}
		return
	var here: Dictionary = piece.ray_to_panel(_ray_from(), _ray_to())
	if not here.is_empty():
		var a: Vector2i = _drag.square
		var b: Vector2i = here.square
		cut_selection = PackedInt32Array()
		if a == b:
			cut_selection = _drag.quarters # mesmo quadrado: só o meio quadrado do clique
		else:
			for j in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
				for i in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
					for q in 4:
						var t := (j * BuildPiece.N + i) * 4 + q
						if piece.removed[t] == 0:
							cut_selection.append(t)
	_draw_triangles(piece, cut_selection, Color(1.0, 0.55, 0.15, 0.55))
	if not Input.is_action_pressed("attack"):
		# Soltou: tira tudo o que estava selecionado.
		var manager := _manager()
		if manager and not cut_selection.is_empty():
			manager.request_cut_many(piece, cut_selection)
		_drag = {}
		cut_selection = PackedInt32Array()


# --- Janela / porta ------------------------------------------------------------------

## Buraco mirado: onde a mira atravessa o plano de uma peça num triângulo tirado.
func _compute_hole() -> Dictionary:
	var manager := _manager()
	var from := _ray_from()
	var to := _ray_to()
	var hit := _ray()
	var limit: float = from.distance_to(hit.position) + 0.05 if hit else REACH
	var best := {}
	var best_t := INF
	for piece: BuildPiece in manager.pieces.values():
		if not piece.has_panel() or piece.global_position.distance_to(from) > REACH + BuildPiece.SIZE * 1.5:
			continue
		var res: Dictionary = piece.ray_to_panel(from, to)
		if res.is_empty() or res.t * REACH > limit or res.t >= best_t:
			continue
		if piece.removed[res.triangle] == 0 or piece.filled(res.triangle):
			continue
		best_t = res.t
		best = {"piece": piece, "triangle": res.triangle}
	if best.is_empty():
		return {}
	var tris: PackedInt32Array = best.piece.hole_at(best.triangle)
	var valid := not tris.is_empty()
	if selection.fill == "door":
		valid = valid and best.piece.kind == BuildPiece.Kind.WALL and BuildPiece.touches_bottom(tris)
	return {"piece": best.piece, "tris": tris, "valid": valid}


# --- Potes, canteiro, bancada --------------------------------------------------------

func _placed() -> PlacedManager:
	return player.get_parent().get_node_or_null("Placed") as PlacedManager


## Canteiro: na grade como um piso. Pote/floreira/bancada: em cima de qualquer
## chão plano mirado, virado para quem coloca.
func _compute_place() -> Dictionary:
	var placed := _placed()
	if placed == null:
		return {}
	if selection.place == "bed":
		var previous := kind
		kind = BuildPiece.Kind.FLOOR
		var grid := _compute_target()
		kind = previous
		if grid.is_empty():
			return {}
		var valid: bool = grid.valid and not placed.bed_at(grid.cell)
		return {"xform": BuildPiece.piece_transform(BuildPiece.Kind.FLOOR, grid.cell, 0), "valid": valid}
	var hit := _ray()
	if selection.place == "blast_stack":
		return _compute_stack(placed, hit)
	if selection.place == "electric_motor":
		return _compute_motor(placed, hit)
	if selection.place in Electric.ANY_SURFACE and not hit.is_empty():
		# Isolador/interruptor: em qualquer superfície (chão, parede, teto), virado para fora.
		var n: Vector3 = hit.normal
		var up := Vector3.UP if absf(n.y) < 0.9 else Vector3.FORWARD
		var surf := Transform3D(Basis.looking_at(-n, up), GridSnap.on_surface(hit.position, n) + n * 0.004) # na grade da superfície
		return {"xform": surf, "valid": not placed.occupied(surf.origin, 0.06), "kind": selection.place}
	# Conector, lâmpada e enfeites de parede: mirando uma parede, vão na parede.
	var wall := wall_kind(selection.place)
	if wall != "" and not hit.is_empty() and absf(hit.normal.y) < 0.35:
		var flat := Vector3(hit.normal.x, 0, hit.normal.z).normalized()
		var on_wall := Transform3D(Basis.looking_at(-flat, Vector3.UP), GridSnap.on_surface(hit.position, flat) + flat * 0.005) # na grade da parede
		var ok := not placed.occupied(on_wall.origin, 0.12) and player.global_position.distance_to(on_wall.origin) > 0.4
		return {"xform": on_wall, "valid": ok, "kind": wall}
	if selection.place in Decor.WALL_KINDS:
		return {} # quadro, prateleira e relógio: só na parede
	if hit.is_empty() or hit.normal.y < 0.7 or hit.collider is PlacedObject and hit.collider.kind != "bed":
		return {}
	# Sempre na grade de 0,4 m e virado em passos de 90° (nada mais solto/torto).
	var xform := grid_snap(selection.place, Transform3D(Basis(Vector3.UP, player.rotation.y), hit.position))
	if selection.place == "shaft":
		var snapped := _snap_shaft(placed, hit.position)
		if snapped != Transform3D():
			return {"xform": snapped, "valid": true}
	var valid := not placed.occupied(xform.origin, PLACE_RADIUS[selection.place]) \
			and player.global_position.distance_to(xform.origin) > 0.6
	return {"xform": xform, "valid": valid}


## Motor elétrico: encaixa na porta de latão mais perto da máquina mirada (máquina de
## rotação, não gerador). O corpo sai para fora da porta.
func _compute_motor(placed: PlacedManager, hit: Dictionary) -> Dictionary:
	if hit.is_empty() or not hit.collider is PlacedObject:
		return {}
	var machine: PlacedObject = hit.collider
	if not Power.DEMAND.has(machine.kind) or machine.kind == "dynamo":
		return {}
	var best := []
	for port in Power.world_ports(machine):
		if best.is_empty() or port[0].distance_to(hit.position) < best[0].distance_to(hit.position):
			best = port
	if best.is_empty():
		return {}
	var out: Vector3 = best[1].normalized()
	var xform := Transform3D(Basis(out, Vector3.UP, out.cross(Vector3.UP)), best[0])
	var taken := false
	for obj: PlacedObject in placed.objects.values():
		if obj.kind == "electric_motor" and obj.global_position.distance_to(best[0]) < 0.15:
			taken = true
	return {"xform": xform, "valid": not taken}


## Variante de parede do que está no martelo ("" = não vai na parede).
static func wall_kind(place: String) -> String:
	if Electric.WALL_VARIANT.has(place):
		return Electric.WALL_VARIANT[place]
	return place if place in Decor.WALL_KINDS else ""


## Tipo do menu de um objeto (a lâmpada de parede é a "lamp" do menu).
static func _base_kind(kind: String) -> String:
	for base in Electric.WALL_VARIANT:
		if Electric.WALL_VARIANT[base] == kind:
			return base
	return kind


## Anel do alto-forno: vai em cima da base ou do anel mirado, alinhado com ele.
func _compute_stack(placed: PlacedManager, hit: Dictionary) -> Dictionary:
	if hit.is_empty() or not hit.collider is PlacedObject or not hit.collider.kind in ["blast_furnace", "blast_stack"]:
		return {}
	var below: PlacedObject = hit.collider
	var height := Fluids.BLAST_BASE_H if below.kind == "blast_furnace" else Fluids.BLAST_RING_H
	var xform := Transform3D(below.global_basis, below.global_position + Vector3.UP * height)
	return {"xform": xform, "valid": placed.stack_spot_free(xform.origin)}


## Gira em passos de 90° e prende na grade das peças (0,4 m), igual ao piso construído
## (a grade começa em 0,0 do mundo). Vale para tudo o que se põe com o martelo.
static func grid_snap(place: String, xform: Transform3D) -> Transform3D:
	var yaw := snappedf(xform.basis.get_euler().y, PI / 2.0)
	var basis := Basis(Vector3.UP, yaw)
	var offset: Vector3 = basis * GRID_OFFSET.get(place, Vector3.ZERO)
	var p := xform.origin - offset
	p.x = snappedf(p.x, BuildPiece.SEG)
	p.z = snappedf(p.z, BuildPiece.SEG)
	return Transform3D(basis, p + offset)


## Eixo: encaixa a ponta na porta de latão livre mais perto (até 1,2 m), alinhado com ela.
func _snap_shaft(placed: PlacedManager, near: Vector3) -> Transform3D:
	var best := {}
	for obj: PlacedObject in placed.objects.values():
		if not Power.is_power(obj.kind) or obj.global_position.distance_to(near) > 4.0:
			continue
		for port in Power.world_ports(obj):
			var d := Vector2(port[0].x - near.x, port[0].z - near.z).length()
			if d < 1.2 and (best.is_empty() or d < best.d):
				best = {"d": d, "pos": port[0], "dir": port[1]}
	if best.is_empty():
		return Transform3D()
	var dir: Vector3 = best.dir
	dir.y = 0.0
	dir = dir.normalized()
	var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP)) # eixo X do eixo = direção da porta
	var center: Vector3 = best.pos + dir * 1.0
	return Transform3D(basis, center - Vector3.UP * 0.6)


# --- Onde construir ---------------------------------------------------------------

func _ray_from() -> Vector3:
	return player.camera.global_position


func _ray_to() -> Vector3:
	return player.camera.global_position - player.camera.global_basis.z * REACH


func _ray() -> Dictionary:
	var cam := player.camera
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * REACH, MASK, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	# As peças colidem dos dois lados: a normal pode vir invertida. Vira para quem mira.
	if hit and hit.normal.dot(dir) > 0.0:
		hit.normal = -hit.normal
	return hit


func _compute_target() -> Dictionary:
	var hit := _ray()
	if hit.is_empty():
		return {}
	var p: Vector3 = hit.position + hit.normal * 0.02
	var piece := hit.collider as BuildPiece
	var on_top: bool = hit.normal.y > 0.7
	# Mirando a quina de cima de uma parede/pilar também conta como "em cima".
	if piece and piece.kind in [BuildPiece.Kind.WALL, BuildPiece.Kind.PILLAR] \
			and piece.to_local(hit.position).y > BuildPiece.SIZE - 0.35:
		on_top = true
	var seg := BuildPiece.SEG
	var n := BuildPiece.N
	var forward := -player.camera.global_basis.z
	var cell := Vector3i.ZERO
	var rot := 0
	var me := player.global_position
	match kind:
		BuildPiece.Kind.WALL:
			# De frente para quem constrói (R gira 90°).
			rot = 1 if absf(forward.x) > absf(forward.z) else 0
			if flip:
				rot = 1 - rot
			if piece and on_top and piece.kind == BuildPiece.Kind.WALL:
				cell = piece.cell + Vector3i(0, n, 0) # empilha
				rot = piece.rot
			elif piece and on_top and piece.kind in [BuildPiece.Kind.FLOOR, BuildPiece.Kind.ROOF]:
				# Na borda mais perto do piso/teto mirado.
				var o := piece.cell
				var y := o.y # no teto a base afunda um pouco na laje (o topo dele não cai na grade)
				if rot == 0:
					var z := o.z if absf(p.z - o.z * seg) < absf(p.z - (o.z + n) * seg) else o.z + n
					cell = Vector3i(o.x, y, z)
				else:
					var x := o.x if absf(p.x - o.x * seg) < absf(p.x - (o.x + n) * seg) else o.x + n
					cell = Vector3i(x, y, o.z)
			else:
				var y := roundi(p.y / seg)
				if rot == 0:
					cell = Vector3i(roundi(p.x / seg) - n / 2, y, roundi(p.z / seg))
				else:
					cell = Vector3i(roundi(p.x / seg), y, roundi(p.z / seg) - n / 2)
		BuildPiece.Kind.ROOF when flip:
			# Telhado inclinado: sobe para o lado de quem constrói (de dentro da casa, a
			# borda de baixo fica na parede e ele sobe para o meio).
			var back := Vector3(-forward.x, 0.0, -forward.z)
			if absf(back.z) >= absf(back.x):
				rot = 2 if back.z > 0.0 else 4
			else:
				rot = 3 if back.x > 0.0 else 5
			var up_dir := BuildPiece.slope_dir(rot)
			if piece and piece.kind == BuildPiece.Kind.WALL and on_top:
				# Em cima da parede: do lado para onde ele sobe.
				var o := piece.cell
				var y := o.y + n
				if piece.rot == 0:
					cell = Vector3i(o.x, y, o.z if up_dir.z > 0.0 else o.z - n) if absf(up_dir.z) > 0.5 else Vector3i(roundi(p.x / seg) - n / 2, y, o.z if me.z > o.z * seg else o.z - n)
				else:
					cell = Vector3i(o.x if up_dir.x > 0.0 else o.x - n, y, o.z) if absf(up_dir.x) > 0.5 else Vector3i(o.x if me.x > o.x * seg else o.x - n, y, roundi(p.z / seg) - n / 2)
			elif piece and BuildPiece.is_slope(piece.kind, piece.rot):
				# Encostado noutro telhado: continua a fileira (de lado) ou sobe/desce junto.
				var o := piece.cell
				rot = piece.rot
				up_dir = BuildPiece.slope_dir(rot)
				var local := piece.to_local(p)
				var lu := local.x / seg
				var lv := local.z / seg
				var edges := [lu, n - lu, lv, n - lv]
				var best: int = edges.find(edges.min())
				var side := piece.global_basis.x.normalized()
				var step: Vector3 = [-side, side, -up_dir, up_dir][best]
				cell = o + Vector3i(roundi(step.x) * n, (n if best == 3 else (-n if best == 2 else 0)), roundi(step.z) * n)
			else:
				cell = Vector3i(roundi(p.x / seg) - n / 2, roundi(p.y / seg), roundi(p.z / seg) - n / 2)
		BuildPiece.Kind.FLOOR, BuildPiece.Kind.ROOF:
			if piece and on_top and piece.kind == kind:
				# Perto da borda de outro piso/teto igual: vai para o lado dele.
				var o := piece.cell
				var lu := p.x / seg - o.x
				var lv := p.z / seg - o.z
				var edges := [lu, n - lu, lv, n - lv]
				var best: int = edges.find(edges.min())
				var offsets := [Vector3i(-n, 0, 0), Vector3i(n, 0, 0), Vector3i(0, 0, -n), Vector3i(0, 0, n)]
				cell = o + offsets[best]
			elif piece and on_top and piece.kind == BuildPiece.Kind.WALL:
				# Em cima de uma parede: cobre o lado onde o jogador está.
				var o := piece.cell
				var y := o.y + n
				if piece.rot == 0:
					cell = Vector3i(o.x, y, o.z - n if me.z < o.z * seg else o.z)
				else:
					cell = Vector3i(o.x - n if me.x < o.x * seg else o.x, y, o.z)
			else:
				cell = Vector3i(roundi(p.x / seg) - n / 2, roundi(p.y / seg), roundi(p.z / seg) - n / 2)
		BuildPiece.Kind.PILLAR:
			# R deita o pilar (viga), no sentido da parede que fica de frente para quem constrói.
			var lying := flip
			if lying:
				rot = 1 if absf(forward.z) >= absf(forward.x) else 2
			var standing_piece: bool = piece != null and (piece.kind == BuildPiece.Kind.WALL or (piece.kind == BuildPiece.Kind.PILLAR and piece.rot == 0))
			if lying and piece and on_top and piece.kind == BuildPiece.Kind.WALL:
				cell = piece.cell + Vector3i(0, n, 0) # cobre o topo da parede inteiro
				rot = 1 if piece.rot == 0 else 2
			elif piece and on_top and standing_piece:
				cell = Vector3i(roundi(p.x / seg), piece.cell.y + n, roundi(p.z / seg))
			else:
				cell = Vector3i(roundi(p.x / seg), roundi(p.y / seg), roundi(p.z / seg))
	if kind != BuildPiece.Kind.WALL and kind != BuildPiece.Kind.PILLAR and not (kind == BuildPiece.Kind.ROOF and flip):
		rot = 0
	return {"kind": kind, "cell": cell, "rot": rot, "valid": _manager().can_place(kind, cell, rot)}


# --- Visual ---------------------------------------------------------------------

func _set_ghost_shape() -> void:
	var box := BoxMesh.new()
	var size := BuildPiece.SIZE
	var t := BuildPiece.THICK
	_ghost_mesh.scale = Vector3.ONE
	match kind:
		BuildPiece.Kind.WALL:
			box.size = Vector3(size, size, t)
			_ghost_mesh.position = Vector3(size * 0.5, size * 0.5, 0)
		BuildPiece.Kind.FLOOR:
			box.size = Vector3(size, t, size)
			_ghost_mesh.position = Vector3(size * 0.5, -t * 0.5, size * 0.5)
		BuildPiece.Kind.ROOF:
			box.size = Vector3(size, t, size)
			_ghost_mesh.position = Vector3(size * 0.5, t * 0.5, size * 0.5)
		BuildPiece.Kind.PILLAR:
			box.size = Vector3(BuildPiece.SEG, size, BuildPiece.SEG)
			_ghost_mesh.position = Vector3(0, size * 0.5, 0)
	_ghost_mesh.mesh = box


## Fantasma do telhado inclinado: a placa deitada a 45° (sobe SIZE ao longo de +Z local).
func _slope_ghost(t: Dictionary) -> void:
	if t.kind != BuildPiece.Kind.ROOF:
		return
	var size := BuildPiece.SIZE
	var th := BuildPiece.THICK
	if BuildPiece.is_slope(t.kind, t.rot):
		var box := BoxMesh.new()
		box.size = Vector3(size, th, size * sqrt(2.0))
		_ghost_mesh.mesh = box
		_ghost_mesh.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 4.0), Vector3(size * 0.5, size * 0.5 + th * 0.5, size * 0.5))
	elif _ghost_mesh.transform.basis != Basis.IDENTITY:
		_ghost_mesh.transform = Transform3D.IDENTITY
		_set_ghost_shape()


## Triângulos realçados na face virada para quem mira (um pouco para fora dela).
func _draw_triangles(piece: BuildPiece, tris: PackedInt32Array, color: Color) -> void:
	var w := Vector2(-BuildPiece.THICK * 0.5, BuildPiece.THICK * 0.5) if piece.kind == BuildPiece.Kind.WALL 			else Vector2(0.0, BuildPiece.THICK)
	var eye := piece.to_local(player.camera.global_position)
	var eye_w := eye.z if piece.kind == BuildPiece.Kind.WALL else eye.y + (BuildPiece.THICK if piece.kind == BuildPiece.Kind.FLOOR else 0.0) - eye.z * piece.slope()
	var depth := w.y + 0.01 if eye_w > (w.x + w.y) * 0.5 else w.x - 0.01
	_highlight_mesh.clear_surfaces()
	if tris.is_empty():
		return
	_highlight_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in tris:
		var c := BuildPiece.triangle_uv(index)
		var center := (c[0] + c[1] + c[2]) / 3.0
		for k in 3:
			var corner: Vector2 = center.lerp(c[k], 0.92) # um pouco menor: dá para ver cada triângulo
			_highlight_mesh.surface_add_vertex(piece.uvw(corner.x, corner.y, depth))
	_highlight_mesh.surface_end()
	_mark.albedo_color = color
	_highlight.global_transform = piece.global_transform
	_highlight.visible = true
