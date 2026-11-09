class_name ItemDB
## Catálogo de itens: nome, tipo, quanto empilha e o modelo usado no chão
## (e na mão dos zumbis). Para criar um item novo, adicione uma entrada aqui.
##
## kind: "weapon" (equipa ao selecionar na hotbar), "tool" (funciona estando
## no inventário, ex.: lanterna), "food" (clique come: "hunger" enche a fome,
## "heal" recupera vida), "seed" (planta em pote/canteiro/cova: "crop") ou
## "material" (construção e fabricação na bancada).

## Campos da janela de informação (hover no inventário): damage_type, damage,
## knockback e desc. Os números são os valores padrão das armas no Player.
const ITEMS := {
	&"espada": {"name": "Espada", "kind": "weapon", "weapon": "sword", "stack": 1, "size": Vector3(0.2, 0.05, 1.0),
		"damage_type": "Corte", "damage": 34, "knockback": 30,
		"desc": "Lâmina de aço, guarda de latão. Corta braços, pão e a paciência de quem afia.",
		"controls": ["Clique: golpe (combo de 3)", "Botão direito: bloquear (na hora certa = parry)", "Correndo + segurar clique: empalar até 3"]},
	&"taco": {"name": "Maça", "kind": "weapon", "weapon": "bat", "stack": 1, "size": Vector3(0.14, 0.14, 0.95),
		"damage_type": "Impacto", "damage": 24, "knockback": 58,
		"desc": "Pedaço de pau com ferro na ponta. A tecnologia mais confiável do fim do mundo.",
		"controls": ["Clique: golpe (combo de 3)", "Botão direito: bloquear"]},
	&"colher": {"name": "Colherona", "kind": "weapon", "weapon": "spoon", "stack": 1, "size": Vector3(0.36, 0.12, 1.6),
		"damage_type": "Impacto", "damage": 20, "knockback": 95,
		"desc": "Uma colher de sopa para um gigante com muita fome. Ninguém sabe de onde veio. Ninguém pergunta.",
		"controls": ["Clique: golpe lento que arremessa", "Botão direito: bloquear"]},
	&"gancho": {"name": "Gancho", "kind": "weapon", "weapon": "grapple", "stack": 1, "size": Vector3(0.12, 0.18, 0.5),
		"desc": "Clique e segure para balançar; a corda se recolhe sozinha. Não teste em zumbis.",
		"controls": ["Segurar clique: prende e balança", "WASD: controla no ar", "Soltar: solta a corda"]},
	&"chinelo": {"name": "Chinelo", "kind": "weapon", "weapon": "slipper", "stack": 1, "size": Vector3(0.1, 0.03, 0.26),
		"damage_type": "Impacto", "damage": 75, "knockback": 0,
		"desc": "A arma mais temida de qualquer mãe. Nunca erra a cabeça: o zumbi cai duro para trás. E volta.",
		"controls": ["Clique: joga o chinelo no zumbi mais perto da mira (sempre na cabeça)",
			"Ele volta para a mão; dá para ter 2 no ar, depois espere voltar"]},
	&"bumerangue": {"name": "Bumerangue", "kind": "weapon", "weapon": "boomerang", "stack": 1, "size": Vector3(0.3, 0.02, 0.3),
		"damage_type": "Impacto", "damage": 18, "knockback": 28,
		"desc": "Ricocheteia de zumbi em zumbi (até 5) e pode deixar cada um tonto. Sempre volta. Quase sempre.",
		"controls": ["Clique: joga (mire num zumbi); ele quica até 5 zumbis e volta para a mão",
			"Só um por vez: espere ele voltar para jogar de novo"]},
	&"martelo": {"name": "Martelo", "kind": "weapon", "weapon": "hammer", "stack": 1, "size": Vector3(0.16, 0.2, 0.45),
		"desc": "Constrói na grade invisível: paredes, pisos, tetos, pilares, janelas e portas.",
		"controls": ["Clique: constrói a peça escolhida", "Segurar botão direito: menu de construção (solte no item)",
			"R: gira a parede / deita o pilar (viga)", "Shift + botão direito: desmonta o que está mirado (fica vermelho)", "Segure Shift: alinha com a grade do piso",
			"Janela/Porta: mire um buraco feito pela talhadeira", "Porta: o buraco precisa encostar no chão"]},
	&"talhadeira": {"name": "Talhadeira", "kind": "weapon", "weapon": "chisel", "stack": 1, "size": Vector3(0.05, 0.05, 0.35),
		"desc": "Tira triângulos de paredes, pisos e tetos. Janela, porta, buraco para espiar zumbi.",
		"controls": ["Clique: tira o triângulo (meio quadrado) mirado", "R: troca a diagonal do corte (/ ou \\)",
			"Clique e arraste: seleciona uma área e tira tudo ao soltar"]},
	&"cajado": {"name": "Cajado", "kind": "weapon", "weapon": "staff", "stack": 1, "size": Vector3(0.12, 0.12, 1.2),
		"damage_type": "Explosão", "damage": 70, "knockback": 450,
		"desc": "Dispara mísseis mágicos. Ler o manual antes era opcional.",
		"controls": ["Segurar clique: dispara mísseis"]},
	&"pistola": {"name": "Revólver", "short": "Revólver", "kind": "weapon", "weapon": "pistol", "stack": 1, "size": Vector3(0.05, 0.15, 0.22),
		"damage_type": "Perfuração", "damage": 40, "knockback": 20,
		"desc": "Latão, madeira e pólvora de procedência duvidosa. 12 tiros e munição infinita.",
		"controls": ["Clique: atira", "R: recarrega"]},
	&"lanterna": {"name": "Lanterna", "kind": "tool", "slot": "offhand", "stack": 1, "size": Vector3(0.08, 0.08, 0.24),
		"desc": "Lanterna de latão (L). Gasta bateria; recarregue com o carregador. Zumbis adoram uma luz na cara. Na mão secundária fica sempre à mão.",
		"controls": ["L: liga/desliga (na mão secundária ou na mochila)", "Arraste para o slot da mão (ao lado da roupa)"]},
	&"carregador": {"name": "Carregador", "kind": "weapon", "weapon": "charger", "stack": 1, "size": Vector3(0.26, 0.2, 0.1),
		"desc": "Dínamo de mão para a bateria da lanterna. Aperte rápido: devagar só cansa o braço.",
		"controls": ["Clique rápido: gira o dínamo e carrega a lanterna"]},
	&"pa": {"name": "Pá", "kind": "weapon", "weapon": "shovel", "stack": 1, "size": Vector3(0.2, 0.05, 1.1),
		"damage_type": "Impacto", "damage": 26, "knockback": 50,
		"desc": "Cava, planta e, se precisar, resolve zumbi. A ferramenta do fazendeiro do fim do mundo.",
		"controls": ["Clique: golpe", "Botão direito no chão de terra: cava uma cova (às vezes acha pedra)",
			"Botão direito em cova/pote/canteiro vazio: planta a primeira semente da mochila",
			"Botão direito numa planta pronta: colhe"]},
	&"fruta": {"name": "Fruta", "kind": "food", "heal": 25, "hunger": 10, "stack": 10, "size": Vector3(0.14, 0.14, 0.14),
		"desc": "Vermelha, meio torta, provavelmente comestível.",
		"controls": ["Clique: come (+25 vida, +10 fome)"]},
	&"lata": {"name": "Enlatado", "kind": "food", "hunger": 45, "heal": 5, "stack": 5, "size": Vector3(0.1, 0.13, 0.1),
		"desc": "Rótulo ilegível. Pode ser feijão, pode ser pêssego. É comida.",
		"controls": ["Clique: come (+45 fome)"]},
	&"pao": {"name": "Pão velho", "kind": "food", "hunger": 25, "stack": 5, "size": Vector3(0.22, 0.1, 0.12),
		"desc": "Duro como tijolo. Serve de comida e, em último caso, de arma.",
		"controls": ["Clique: come (+25 fome)"]},
	&"cenoura": {"name": "Cenoura", "kind": "food", "hunger": 15, "heal": 3, "stack": 10, "size": Vector3(0.05, 0.05, 0.2),
		"desc": "Colhida no seu próprio canteiro. Faz bem para enxergar zumbi no escuro (dizem).",
		"controls": ["Clique: come (+15 fome)"]},
	&"batata": {"name": "Batata", "kind": "food", "hunger": 22, "stack": 10, "size": Vector3(0.1, 0.08, 0.12),
		"desc": "Cresce em qualquer lugar, até no apocalipse.",
		"controls": ["Clique: come (+22 fome)"]},
	&"abobora": {"name": "Abóbora", "kind": "food", "hunger": 40, "heal": 8, "stack": 4, "size": Vector3(0.3, 0.24, 0.3),
		"desc": "Demora para crescer, mas enche a barriga de verdade.",
		"controls": ["Clique: come (+40 fome)"]},
	&"bandagem": {"name": "Bandagem", "kind": "food", "heal": 35, "stack": 5, "size": Vector3(0.12, 0.06, 0.12),
		"desc": "Pano fervido e enrolado. Não é hospital, mas ajuda.",
		"controls": ["Clique: usa (+35 vida)"]},
	&"semente_cenoura": {"name": "Sementes de cenoura", "kind": "seed", "crop": "cenoura", "stack": 20, "size": Vector3(0.1, 0.03, 0.14),
		"desc": "Plante em pote, canteiro ou cova (pá). Cresce em ~4 minutos.",
		"controls": ["Clique num pote/canteiro/cova vazio: planta"]},
	&"semente_batata": {"name": "Batata-semente", "kind": "seed", "crop": "batata", "stack": 20, "size": Vector3(0.1, 0.03, 0.14),
		"desc": "Plante em pote, canteiro ou cova (pá). Cresce em ~5 minutos.",
		"controls": ["Clique num pote/canteiro/cova vazio: planta"]},
	&"semente_abobora": {"name": "Sementes de abóbora", "kind": "seed", "crop": "abobora", "stack": 20, "size": Vector3(0.1, 0.03, 0.14),
		"desc": "Plante em pote largo, canteiro ou cova (pá). Cresce em ~7 minutos.",
		"controls": ["Clique num pote/canteiro/cova vazio: planta"]},
	&"machado": {"name": "Machado", "kind": "weapon", "weapon": "axe", "stack": 1, "size": Vector3(0.24, 0.05, 0.8),
		"damage_type": "Corte", "damage": 32, "knockback": 34,
		"desc": "Derruba árvore em 3 golpes, zumbi em 2. Corta o tronco caído ali mesmo (2 tábuas).",
		"controls": ["Clique: golpe (árvore: 3 golpes derruba)", "Golpe num tronco no chão: vira 2 tábuas (na bancada rende 8)"]},
	&"picareta": {"name": "Picareta", "kind": "weapon", "weapon": "pickaxe", "stack": 1, "size": Vector3(0.4, 0.05, 0.8),
		"damage_type": "Perfuração", "damage": 28, "knockback": 30,
		"desc": "Quebra rocha e veios de minério (ferro, cobre, carvão). Veios: pedra com pedaços laranja (ferro), verdes (cobre) ou pretos (carvão), mais comuns na montanha.",
		"controls": ["Clique: golpe (rocha/veio: 4 golpes)"]},
	&"lanca": {"name": "Lança", "kind": "weapon", "weapon": "spear", "stack": 1, "size": Vector3(0.08, 0.08, 1.7),
		"damage_type": "Perfuração", "damage": 30, "knockback": 22,
		"desc": "Haste comprida com ponta de ferro e farpa. Espeta peixe, caranguejo e zumbi (de longe).",
		"controls": ["Clique: estocada longa (pega bichos na água)", "Funciona debaixo d'água"]},
	&"vara": {"name": "Vara de pesca", "kind": "weapon", "weapon": "rod", "stack": 1, "size": Vector3(0.06, 0.06, 1.5),
		"desc": "Bambu, carretilha de latão e uma boia vermelha. Paciência inclusa.",
		"controls": ["Clique: lança a boia na água", "Quando a boia afundar: clique para fisgar",
			"Puxando: segure o clique para mover a faixa verde e mantenha o peixe dentro dela", "Botão direito: recolhe a linha"]},
	&"camarao": {"name": "Camarão", "kind": "food", "hunger": 6, "stack": 20, "size": Vector3(0.05, 0.05, 0.12),
		"desc": "Pequeno, transparente e rápido. Na grelha fica rosa.", "controls": ["Clique: come cru (+6 fome)"]},
	&"lagosta": {"name": "Lagosta", "kind": "food", "hunger": 18, "stack": 5, "size": Vector3(0.14, 0.08, 0.4),
		"desc": "Garras grandes, humor pior ainda. Assada vale um banquete.", "controls": ["Clique: come crua (+18 fome)"]},
	&"caranguejo": {"name": "Caranguejo", "kind": "food", "hunger": 12, "stack": 8, "size": Vector3(0.24, 0.08, 0.18),
		"desc": "Anda de lado e belisca. Mora no fundo e na margem.", "controls": ["Clique: come cru (+12 fome)"]},
	&"caranguejo_aranha": {"name": "Caranguejo-aranha", "kind": "food", "hunger": 14, "stack": 5, "size": Vector3(0.5, 0.12, 0.5),
		"desc": "Pernas compridas demais para um bicho tão pequeno. Pouca carne, muito estilo.", "controls": ["Clique: come cru (+14 fome)"]},
	&"atum": {"name": "Atum", "kind": "food", "hunger": 30, "heal": 5, "stack": 2, "size": Vector3(0.26, 0.3, 0.9),
		"desc": "O peixe grande dos lagos fundos. Briga muito na linha.", "controls": ["Clique: come cru (+30 fome)"]},
	&"baixo": {"name": "Peixe-baixo", "kind": "food", "hunger": 20, "stack": 4, "size": Vector3(0.3, 0.08, 0.7),
		"desc": "Peixe com acabamento de contrabaixo: madeira sunburst, captadores, 4 cordas no flanco e tarraxas na barbatana. Comum em qualquer lago.",
		"controls": ["Clique: come cru (+20 fome)"]},
	&"camarao_assado": {"name": "Camarão assado", "kind": "food", "hunger": 14, "heal": 2, "stack": 20, "size": Vector3(0.05, 0.05, 0.12),
		"desc": "Rosinha e crocante.", "controls": ["Clique: come (+14 fome)"]},
	&"lagosta_assada": {"name": "Lagosta assada", "kind": "food", "hunger": 55, "heal": 15, "stack": 5, "size": Vector3(0.14, 0.08, 0.4),
		"desc": "Vermelha, perfumada, digna de restaurante (que não existe mais).", "controls": ["Clique: come (+55 fome)"]},
	&"caranguejo_assado": {"name": "Caranguejo assado", "kind": "food", "hunger": 32, "heal": 8, "stack": 8, "size": Vector3(0.24, 0.08, 0.18),
		"desc": "Dá trabalho para comer. Vale a pena.", "controls": ["Clique: come (+32 fome)"]},
	&"caranguejo_aranha_assado": {"name": "Caranguejo-aranha assado", "kind": "food", "hunger": 36, "heal": 8, "stack": 5, "size": Vector3(0.5, 0.12, 0.5),
		"desc": "As pernas viram petisco.", "controls": ["Clique: come (+36 fome)"]},
	&"atum_assado": {"name": "Atum assado", "kind": "food", "hunger": 80, "heal": 20, "stack": 2, "size": Vector3(0.26, 0.3, 0.9),
		"desc": "Alimenta um grupo inteiro (ou você, com muita fome).", "controls": ["Clique: come (+80 fome)"]},
	&"baixo_assado": {"name": "Peixe-baixo assado", "kind": "food", "hunger": 48, "heal": 10, "stack": 4, "size": Vector3(0.3, 0.08, 0.7),
		"desc": "Grave, encorpado, com notas defumadas.", "controls": ["Clique: come (+48 fome)"]},
	&"muda": {"name": "Muda de árvore", "short": "Muda", "kind": "seed", "crop": "arvore", "stack": 100, "size": Vector3(0.2, 0.35, 0.2),
		"desc": "Planta no chão de terra (fora do deserto) ou numa floreira/canteiro vazio, que fica todo ocupado. Cresce em ~8 min; derrubada sempre devolve uma muda.",
		"controls": ["Clique no chão de terra ou numa floreira/canteiro vazio: planta"]},
	&"bandeira": {"name": "Bandeira", "kind": "placeable", "place": "flag", "stack": 100, "size": Vector3(0.3, 1.2, 0.05),
		"desc": "Fincada no chão, marca um ponto no mapa e no minimapa (para todo mundo). [E] nela recolhe de volta.",
		"controls": ["Clique no chão: finca a bandeira"]},
	&"garrafa": {"name": "Garrafa vazia", "short": "Garrafa", "kind": "material", "stack": 100, "size": Vector3(0.09, 0.28, 0.09),
		"desc": "Clique na água de um lago (sai suja) ou num coletor de chuva (sai potável).",
		"controls": ["Clique na água do lago ou num coletor de chuva: enche"]},
	&"agua_suja": {"name": "Água suja", "short": "Água suja", "kind": "food", "thirst": 35, "sick": 0.6, "returns": &"garrafa",
		"stack": 100, "size": Vector3(0.09, 0.28, 0.09),
		"desc": "Do lago, sem filtrar. Mata a sede, mas tem boa chance de deixar doente (vida caindo, stamina lenta, mais fome e sede).",
		"controls": ["Clique: bebe (+35 sede, risco de doença)"]},
	&"agua": {"name": "Água potável", "short": "Água", "kind": "food", "thirst": 40, "returns": &"garrafa", "stack": 100,
		"size": Vector3(0.09, 0.28, 0.09), "desc": "Água limpa (chuva ou filtrada).", "controls": ["Clique: bebe (+40 sede)"]},
	&"argila": {"name": "Argila", "kind": "material", "stack": 100, "size": Vector3(0.18, 0.12, 0.16),
		"desc": "Cavada com a pá na beira dos lagos. Na fogueira vira tijolo."},
	&"tijolo": {"name": "Tijolo", "kind": "material", "stack": 100, "size": Vector3(0.22, 0.07, 0.11),
		"desc": "Argila cozida na fogueira. Base das fornalhas e construções mais fortes."},
	&"peixe_seco": {"name": "Peixe seco", "short": "Peixe seco", "kind": "food", "hunger": 40, "heal": 6, "stack": 100,
		"size": Vector3(0.28, 0.04, 0.12), "desc": "Peixe salgado e seco no varal. Enche bem e não estraga.",
		"controls": ["Clique: come (+40 fome)"]},
	&"comida_estragada": {"name": "Comida estragada", "short": "Estragada", "kind": "food", "hunger": 5, "sick": 0.8, "stack": 100,
		"size": Vector3(0.18, 0.08, 0.16), "desc": "Passou do ponto. Quase não enche e quase sempre deixa doente. Na composteira vira adubo.",
		"controls": ["Clique: come (risco alto de doença)"]},
	&"semente_trigo": {"name": "Sementes de trigo", "short": "Sem. trigo", "kind": "seed", "crop": "trigo", "stack": 100, "size": Vector3(0.1, 0.03, 0.14),
		"desc": "Planta trigo (não se come cru: moa no moinho manual).", "controls": ["Clique num pote, floreira, canteiro ou cova: planta"]},
	&"trigo": {"name": "Trigo", "kind": "material", "stack": 100, "size": Vector3(0.06, 0.4, 0.06), "desc": "Moa no moinho manual para fazer farinha."},
	&"farinha": {"name": "Farinha", "kind": "material", "stack": 100, "size": Vector3(0.16, 0.2, 0.12), "desc": "Farinha + água no forno de tijolo = pão."},
	&"pao_fresco": {"name": "Pão caseiro", "short": "Pão", "kind": "food", "hunger": 38, "heal": 4, "stack": 100, "size": Vector3(0.22, 0.1, 0.12),
		"desc": "Saído do forno. Estraga em uns 20 min.", "controls": ["Clique: come (+38 fome)"]},
	&"semente_algodao": {"name": "Sementes de algodão", "short": "Sem. algodão", "kind": "seed", "crop": "algodao", "stack": 100, "size": Vector3(0.1, 0.03, 0.14),
		"desc": "Planta algodão: dá fibra para a roca.", "controls": ["Clique num pote, floreira, canteiro ou cova: planta"]},
	&"fibra": {"name": "Fibra de algodão", "short": "Fibra", "kind": "material", "stack": 100, "size": Vector3(0.14, 0.1, 0.14), "desc": "Fie na roca para fazer fio."},
	&"fio": {"name": "Fio", "kind": "material", "stack": 100, "size": Vector3(0.1, 0.1, 0.1), "desc": "Teça no tear para fazer tecido."},
	&"tecido": {"name": "Tecido", "kind": "material", "stack": 100, "size": Vector3(0.24, 0.03, 0.2), "desc": "Pano firme do tear: roupas quentes e pano melhor."},
	&"casaco": {"name": "Casaco de tecido", "kind": "armor", "slot": "body", "armor": 0.08, "warm": 0.6, "stack": 1, "size": Vector3(0.44, 0.52, 0.24),
		"desc": "Forrado: protege do frio (isolamento térmico) e um pouco dos golpes (8%)."},
	&"adubo": {"name": "Adubo", "kind": "material", "stack": 100, "size": Vector3(0.16, 0.12, 0.16),
		"desc": "Da composteira. Clique num plantador: as próximas 3 colheitas dele rendem o dobro.",
		"controls": ["Clique num pote, floreira, canteiro ou cova: aduba"]},
	&"peixe_defumado": {"name": "Peixe defumado", "short": "Defumado", "kind": "food", "hunger": 50, "heal": 10, "stack": 100,
		"size": Vector3(0.28, 0.05, 0.12), "desc": "Do defumador. Enche muito e nunca estraga.", "controls": ["Clique: come (+50 fome)"]},
	&"tocha": {"name": "Tocha", "kind": "tool", "slot": "offhand", "durability": 600, "stack": 1, "size": Vector3(0.06, 0.45, 0.06),
		"desc": "Ilumina em volta enquanto está na mão (ou na mão secundária, sem largar a arma). Queima por meio dia (10 min) e acaba. Dá para pôr no chão ou na parede: continua queimando o que tinha.",
		"controls": ["Arraste para o slot da mão (ao lado da roupa): fica acesa na mão esquerda",
			"Na mão, clique mirando o chão ou uma parede: põe a tocha ali", "[E] na tocha posta: reabastece (outra tocha, ou pano + graveto)"]},
	&"cabo": {"name": "Cabo elétrico", "short": "Cabo", "kind": "material", "stack": 100, "size": Vector3(0.22, 0.08, 0.22),
		"desc": "Fio de cobre encapado em pano. Liga duas peças elétricas (borne de latão) a até 12 m: cada 4 m gasta 1. Pendura entre os bornes.",
		"controls": ["Clique numa peça elétrica e depois na outra: liga", "Ligar o mesmo par de novo: tira o cabo (volta)"]},
	&"lampada": {"name": "Lâmpada", "kind": "material", "stack": 100, "size": Vector3(0.08, 0.12, 0.08),
		"desc": "Bulbo de vidro com filamento de cobre. Vai nas lâmpadas e nas válvulas do rádio."},
	&"celula": {"name": "Célula de bateria", "short": "Célula", "kind": "material", "stack": 100, "size": Vector3(0.2, 0.38, 0.2),
		"desc": "Jarro de vidro com placas de cobre e zinco. Vai na estrutura da bateria (até 6): cada uma guarda 300 Wh e carrega/descarrega até 500 W.",
		"controls": ["[E] na estrutura da bateria: põe uma célula"]},
	&"fio_cobre": {"name": "Fio de cobre", "short": "Fio cobre", "kind": "material", "stack": 100, "size": Vector3(0.16, 0.06, 0.16),
		"desc": "Barra de cobre puxada na trefiladora. Com fio, a mesa faz o dobro de cabo e o torno faz bobina com menos cobre."},
	&"manual_ferreiro": {"name": "Manual do ferreiro", "short": "Man. ferreiro", "kind": "book", "stack": 1, "size": Vector3(0.18, 0.04, 0.24),
		"desc": "Livro velho de oficina, com a tabela de cores do metal quente. Libera espada, capacete e peitoral na forja.",
		"controls": ["Clique: lê (vai para o diário, J). O livro fica: dá para emprestar"]},
	&"manual_soldagem": {"name": "Manual de soldagem", "short": "Man. solda", "kind": "book", "stack": 1, "size": Vector3(0.18, 0.04, 0.24),
		"desc": "Apostila com fotos de cordões bons e ruins. Libera a bancada de solda (armaduras e chapas) e a bancada de maçarico (cobre).",
		"controls": ["Clique: lê (vai para o diário, J). O livro fica: dá para emprestar"]},
	&"manual_eletricista": {"name": "Manual do eletricista", "short": "Man. eletric.", "kind": "book", "stack": 1, "size": Vector3(0.18, 0.04, 0.24),
		"desc": "Apostila de curso técnico, cheia de esquemas. Libera a trefiladora e as receitas com fio de cobre.",
		"controls": ["Clique: lê (vai para o diário, J). O livro fica: dá para emprestar"]},
	&"bobina": {"name": "Bobina de cobre", "short": "Bobina", "kind": "material", "stack": 100, "size": Vector3(0.14, 0.14, 0.18),
		"desc": "Fio de cobre enrolado num núcleo de ferro (torno). Peça do dínamo, do painel solar, da geladeira, do rádio e da bomba elétrica."},
	&"correia": {"name": "Esteira de couro", "short": "Esteira", "kind": "material", "stack": 100, "size": Vector3(0.2, 0.05, 0.2),
		"desc": "Liga uma polia a outra polia (ou à polia de latão de uma máquina) a até 10 m, com as duas paralelas. Serve para levar a força do meio de um eixo até uma máquina.",
		"controls": ["Clique numa polia e depois na outra polia ou máquina: liga", "Ligar o mesmo par de novo: tira a esteira"]},
	&"eixo": {"name": "Eixo de madeira", "short": "Eixo", "kind": "material", "stack": 100, "size": Vector3(0.08, 0.08, 0.5),
		"desc": "Leva a força rotacional. Cada item = 2 m (até 8 m por trecho). A ponta encaixa na porta de latão das máquinas; ponta solta vira um tripé, de onde outro eixo continua.",
		"controls": ["Segure o clique no começo (porta, tripé ou chão) e solte no fim", "Shift: reto (45°)", "Fica no nível de onde começou; mire numa porta para descer/subir até ela"]},
	&"engrenagem_madeira": {"name": "Engrenagem de madeira", "short": "Engrenagem", "kind": "material", "stack": 100, "size": Vector3(0.3, 0.3, 0.08),
		"desc": "Vira a força em 90°: monte uma no eixo (ou tripé/porta) e outra no eixo que sai de lado, com os dentes encostados (montando perto, ela encaixa sozinha no ponto certo). Eixos paralelos se ligam por polia + esteira.",
		"controls": ["Clique num eixo, tripé ou porta: monta a engrenagem"]},
	&"polia": {"name": "Polia", "kind": "material", "stack": 100, "size": Vector3(0.3, 0.3, 0.14),
		"desc": "Monte no meio de um eixo e ligue com esteira a uma máquina ou a outra polia (eixos paralelos). Não vira tripé.",
		"controls": ["Clique num eixo, tripé ou porta: monta a polia"]},
	&"carne_crua": {"name": "Carne crua", "short": "Carne", "kind": "food", "hunger": 12, "sick": 0.35, "stack": 100, "size": Vector3(0.2, 0.06, 0.14),
		"desc": "De caça. Crua faz mal: asse na fogueira, seque no secador ou defume.", "controls": ["Clique: come crua (risco de doença)"]},
	&"carne_assada": {"name": "Carne assada", "short": "Assada", "kind": "food", "hunger": 55, "heal": 12, "stack": 100, "size": Vector3(0.2, 0.06, 0.14),
		"desc": "Suculenta. Estraga em uns 15 min.", "controls": ["Clique: come (+55 fome)"]},
	&"carne_seca": {"name": "Carne seca", "short": "Charque", "kind": "food", "hunger": 45, "heal": 6, "stack": 100, "size": Vector3(0.2, 0.03, 0.1),
		"desc": "Salgada e seca (secador ou defumador). Nunca estraga.", "controls": ["Clique: come (+45 fome)"]},
	&"pele": {"name": "Pele crua", "short": "Pele", "kind": "material", "stack": 100, "size": Vector3(0.3, 0.03, 0.25),
		"desc": "De caça. No secador vira couro."},
	&"couro": {"name": "Couro", "kind": "material", "stack": 100, "size": Vector3(0.3, 0.02, 0.24),
		"desc": "Pele curtida no secador: casaco de pele, correias, botas."},
	&"gordura": {"name": "Gordura", "kind": "material", "stack": 100, "size": Vector3(0.12, 0.08, 0.12),
		"desc": "Do javali. Na prensa vira óleo (2 gorduras + garrafa)."},
	&"ovo": {"name": "Ovo", "kind": "food", "hunger": 6, "sick": 0.25, "stack": 100, "size": Vector3(0.05, 0.065, 0.05),
		"desc": "Da galinha mansa (bota sozinha quando está alimentada). Cru faz mal: frite na fogueira.", "controls": ["Clique: come cru (risco de doença)"]},
	&"ovo_frito": {"name": "Ovo frito", "short": "Ovo frito", "kind": "food", "hunger": 22, "heal": 4, "stack": 100, "size": Vector3(0.1, 0.02, 0.1),
		"desc": "Da grelha da fogueira.", "controls": ["Clique: come (+22 fome)"]},
	&"leite": {"name": "Leite", "kind": "food", "thirst": 25, "hunger": 15, "heal": 3, "returns": &"garrafa", "stack": 100, "size": Vector3(0.09, 0.28, 0.09),
		"desc": "Da vaca mansa e alimentada ([E] com garrafa vazia). Estraga rápido.", "controls": ["Clique: bebe (+25 sede, +15 fome)"]},
	&"la": {"name": "Lã", "kind": "material", "stack": 100, "size": Vector3(0.18, 0.12, 0.16),
		"desc": "Tosquie a ovelha mansa ([E]). Na roca vira fio (1 lã = 1 fio); gorro e casaco de lã na mesa."},
	&"pena": {"name": "Pena", "kind": "material", "stack": 100, "size": Vector3(0.03, 0.01, 0.16),
		"desc": "De pássaros e galinhas. Casaco de penas na mesa (quente e leve)."},
	&"gorro_la": {"name": "Gorro de lã", "kind": "armor", "slot": "head", "armor": 0.02, "warm": 0.45, "stack": 1, "size": Vector3(0.24, 0.18, 0.24),
		"desc": "Esquenta bem a cabeça (isolamento 0,45)."},
	&"casaco_la": {"name": "Casaco de lã", "kind": "armor", "slot": "body", "armor": 0.06, "warm": 0.8, "stack": 1, "size": Vector3(0.44, 0.52, 0.24),
		"desc": "Tricô grosso com remendo de couro: quase tão quente quanto o de pele."},
	&"casaco_penas": {"name": "Casaco de penas", "kind": "armor", "slot": "body", "armor": 0.03, "warm": 0.75, "stack": 1, "size": Vector3(0.44, 0.5, 0.26),
		"desc": "Acolchoado de penas: quente e leve."},
	&"casaco_pele": {"name": "Casaco de pele", "kind": "armor", "slot": "body", "armor": 0.12, "warm": 0.9, "stack": 1, "size": Vector3(0.46, 0.55, 0.26),
		"desc": "Forrado de pele: o mais quente (isolamento alto) e protege 12%."},
	&"areia": {"name": "Areia", "kind": "material", "stack": 100, "size": Vector3(0.16, 0.08, 0.16),
		"desc": "Cavada no deserto com a pá. Na fornalha vira vidro."},
	&"graveto": {"name": "Graveto", "kind": "material", "stack": 100, "size": Vector3(0.04, 0.04, 0.5),
		"desc": "Galho seco. Cabo de ferramenta simples. Cai das árvores, sai da tábua no machado ou na bancada."},
	&"machado_simples": {"name": "Machado simples", "kind": "weapon", "weapon": "axe", "power": 0.6, "stack": 1, "size": Vector3(0.2, 0.05, 0.65),
		"damage_type": "Corte", "damage": 19, "knockback": 25,
		"desc": "Pedra amarrada num graveto. Derruba árvore, mas devagar.",
		"controls": ["Clique: golpe (árvore: ~5 golpes)"]},
	&"picareta_simples": {"name": "Picareta simples", "kind": "weapon", "weapon": "pickaxe", "power": 0.6, "stack": 1, "size": Vector3(0.32, 0.05, 0.65),
		"damage_type": "Perfuração", "damage": 17, "knockback": 20,
		"desc": "Lasca de pedra presa num graveto. Quebra rocha e veio, com paciência.",
		"controls": ["Clique: golpe (rocha: ~7 golpes)"]},
	&"capuz": {"name": "Capuz de pano", "kind": "armor", "slot": "head", "armor": 0.05, "warm": 0.2, "stack": 1, "size": Vector3(0.24, 0.22, 0.24),
		"desc": "Protege um pouco a cabeça (5% menos dano)."},
	&"capacete": {"name": "Capacete de ferro", "kind": "armor", "slot": "head", "armor": 0.15, "stack": 1, "size": Vector3(0.26, 0.22, 0.28),
		"desc": "Panela de ferro com tiras de couro. 15% menos dano."},
	&"colete": {"name": "Colete de sucata", "kind": "armor", "slot": "body", "armor": 0.18, "stack": 1, "size": Vector3(0.42, 0.5, 0.24),
		"desc": "Chapas de sucata presas com fita. 18% menos dano."},
	&"peitoral": {"name": "Peitoral de ferro", "kind": "armor", "slot": "body", "armor": 0.3, "stack": 1, "size": Vector3(0.44, 0.52, 0.26),
		"desc": "Armadura de verdade, feita na fornalha e na mesa. 30% menos dano."},
	&"capacete_soldado": {"name": "Capacete soldado", "short": "Capacete", "kind": "armor", "slot": "head", "armor": 0.22, "stack": 1, "size": Vector3(0.28, 0.24, 0.3),
		"desc": "Chapas de aço soldadas com viseira. 22% menos dano (a qualidade da solda muda a proteção e quanto aguenta)."},
	&"couraca": {"name": "Couraça soldada", "short": "Couraça", "kind": "armor", "slot": "body", "armor": 0.42, "stack": 1, "size": Vector3(0.46, 0.54, 0.28),
		"desc": "Peito e costas de chapa de aço soldada. 42% menos dano (a qualidade da solda muda a proteção e quanto aguenta)."},
	&"grevas": {"name": "Grevas soldadas", "short": "Grevas", "kind": "armor", "slot": "legs", "armor": 0.2, "stack": 1, "size": Vector3(0.34, 0.6, 0.22),
		"desc": "Canelas e coxas de chapa de aço soldada. 20% menos dano."},
	&"calca": {"name": "Calça reforçada", "kind": "armor", "slot": "legs", "armor": 0.1, "warm": 0.15, "stack": 1, "size": Vector3(0.34, 0.6, 0.2),
		"desc": "Pano grosso com joelheiras de sucata. 10% menos dano."},
	&"botas": {"name": "Botas", "kind": "armor", "slot": "feet", "armor": 0.05, "warm": 0.15, "stack": 1, "size": Vector3(0.3, 0.2, 0.3),
		"desc": "Sola de pneu velho. 5% menos dano."},
	&"tronco": {"name": "Tronco", "kind": "material", "stack": 4, "size": Vector3(0.3, 0.3, 1.1),
		"desc": "Pesado. Na bancada vira 8 tábuas; com o machado, ali mesmo, só 2. Na fornalha vira carvão."},
	&"minerio_ferro": {"name": "Minério de ferro", "kind": "material", "stack": 20, "size": Vector3(0.16, 0.12, 0.16),
		"desc": "Pedra avermelhada e pesada. Na fornalha vira barra de ferro."},
	&"minerio_cobre": {"name": "Minério de cobre", "kind": "material", "stack": 20, "size": Vector3(0.16, 0.12, 0.16),
		"desc": "Pedra com veias verdes. Na fornalha vira barra de cobre."},
	&"minerio_estanho": {"name": "Minério de estanho", "short": "Min. estanho", "kind": "material", "stack": 20, "size": Vector3(0.16, 0.12, 0.16),
		"desc": "Pedra pesada com cristais cinza-prata (veios claros nas montanhas e no deserto). Na fornalha vira barra de estanho."},
	&"barra_estanho": {"name": "Barra de estanho", "short": "Estanho", "kind": "material", "stack": 20, "size": Vector3(0.1, 0.06, 0.3),
		"desc": "Metal mole e claro. Com cobre, na fundição, vira bronze."},
	&"barra_bronze": {"name": "Barra de bronze", "short": "Bronze", "kind": "material", "stack": 20, "size": Vector3(0.1, 0.06, 0.3),
		"desc": "Liga de cobre (3) e estanho (1), da fundição. Não enferruja: engrenagens, polias e peças fundidas."},
	&"chapa": {"name": "Chapa soldada", "short": "Chapa", "kind": "material", "stack": 20, "size": Vector3(0.5, 0.03, 0.5),
		"desc": "Chapa grande de ferro, de barras emendadas na bancada de solda. Paredes, pisos, telhados, vigas e portas de chapa (bem mais fortes que madeira)."},
	&"botijao": {"name": "Botijão de gás", "short": "Botijão", "kind": "material", "stack": 5, "size": Vector3(0.3, 0.45, 0.3),
		"desc": "Gás de cozinha achado nas casas. Na bancada de maçarico rende 8 soldas (álcool e óleo rendem 1 cada)."},
	&"serpentina": {"name": "Serpentina de cobre", "short": "Serpentina", "kind": "material", "stack": 20, "size": Vector3(0.22, 0.3, 0.22),
		"desc": "Cano de cobre enrolado com as emendas soldadas a estanho (bancada de maçarico). Condensador da estação química e do alambique."},
	&"eletrodo": {"name": "Eletrodos", "short": "Eletrodo", "kind": "material", "stack": 100, "size": Vector3(0.04, 0.04, 0.3),
		"desc": "Varetas de ferro com capa de barro (mesa). A bancada de solda gasta um por cordão."},
	&"carvao": {"name": "Carvão", "kind": "material", "stack": 20, "size": Vector3(0.12, 0.1, 0.12),
		"desc": "Combustível da fornalha. Também serve para minas (pólvora caseira)."},
	&"barra_ferro": {"name": "Barra de ferro", "kind": "material", "stack": 20, "size": Vector3(0.1, 0.06, 0.3),
		"desc": "Para a mesa de trabalho: armas de metal e armadilhas."},
	&"barra_cobre": {"name": "Barra de cobre", "kind": "material", "stack": 20, "size": Vector3(0.1, 0.06, 0.3),
		"desc": "Fios, engrenagens e peças de latão. Para a mesa de trabalho."},
	&"vidro": {"name": "Vidro", "kind": "material", "stack": 20, "size": Vector3(0.25, 0.02, 0.25),
		"desc": "Feito na fornalha com pedra. Lentes, lanternas, cajados."},
	&"batata_assada": {"name": "Batata assada", "kind": "food", "hunger": 45, "heal": 5, "stack": 10, "size": Vector3(0.1, 0.08, 0.12),
		"desc": "Feita na grelha da fogueira. O dobro da crua.", "controls": ["Clique: come (+45 fome)"]},
	&"cenoura_assada": {"name": "Cenoura assada", "kind": "food", "hunger": 30, "heal": 5, "stack": 10, "size": Vector3(0.05, 0.05, 0.2),
		"desc": "Doce e quente.", "controls": ["Clique: come (+30 fome)"]},
	&"abobora_assada": {"name": "Abóbora assada", "kind": "food", "hunger": 75, "heal": 15, "stack": 4, "size": Vector3(0.3, 0.2, 0.3),
		"desc": "Banquete de fim do mundo.", "controls": ["Clique: come (+75 fome)"]},
	&"lata_quente": {"name": "Enlatado quente", "kind": "food", "hunger": 65, "heal": 10, "stack": 5, "size": Vector3(0.1, 0.13, 0.1),
		"desc": "Esquentado na grelha. Agora dá até para saber o que era.", "controls": ["Clique: come (+65 fome)"]},
	&"torrada": {"name": "Torrada", "kind": "food", "hunger": 40, "heal": 3, "stack": 5, "size": Vector3(0.22, 0.06, 0.12),
		"desc": "O pão velho finalmente mastigável.", "controls": ["Clique: come (+40 fome)"]},
	# Tier 3: aço, peças do torno, canos, prensa e destilaria.
	&"barra_aco": {"name": "Barra de aço", "kind": "material", "stack": 20, "size": Vector3(0.1, 0.06, 0.3),
		"desc": "Do alto-forno (ferro + carvão, com o fole girando). Caldeira, motor a vapor e peças fortes."},
	&"parafuso": {"name": "Parafusos", "kind": "material", "stack": 100, "size": Vector3(0.1, 0.04, 0.1),
		"desc": "Torneados no torno. Prendem caldeira, prensa e motor."},
	&"engrenagem": {"name": "Engrenagem", "kind": "material", "stack": 20, "size": Vector3(0.18, 0.04, 0.18),
		"desc": "Feita no torno. O coração de qualquer máquina que gira."},
	&"eixo_aco": {"name": "Eixo torneado", "short": "Eixo aço", "kind": "material", "stack": 20, "size": Vector3(0.05, 0.05, 0.45),
		"desc": "Aço torneado no torno: o virabrequim do motor a vapor."},
	&"cano": {"name": "Cano de cobre", "short": "Cano", "kind": "material", "stack": 100, "size": Vector3(0.06, 0.06, 0.4),
		"desc": "Leva água e vapor entre as máquinas (bomba, caixa d'água, caldeira, motor, destilaria, aspersor). Cada 2 m de cano gasta 1.",
		"controls": ["Segure o clique numa saída (latão) ou na ponta de um cano e solte onde o cano termina", "Shift: cano reto (nível e em ângulos de 45°)", "Clique na ponta de um cano: continua a linha"]},
	&"suco": {"name": "Suco de fruta", "short": "Suco", "kind": "food", "thirst": 45, "hunger": 12, "heal": 4, "returns": &"garrafa", "stack": 100,
		"size": Vector3(0.09, 0.28, 0.09), "desc": "Da prensa: fruta espremida. Mata a sede e ainda enche um pouco.", "controls": ["Clique: bebe (+45 sede)"]},
	&"oleo": {"name": "Óleo", "kind": "material", "stack": 100, "size": Vector3(0.09, 0.28, 0.09),
		"desc": "Da prensa (sementes de algodão ou gordura). Lubrifica o motor a vapor e também roda nos carros (+20% de tanque).",
		"controls": ["Clique num carro: abastece (+20%)"]},
	&"alcool": {"name": "Álcool", "kind": "material", "stack": 100, "size": Vector3(0.09, 0.28, 0.09),
		"desc": "Da destilaria (trigo, fruta ou batata + água + fogo). Combustível dos carros (+35%) e antisséptico (bandagem com álcool).",
		"controls": ["Clique num carro: abastece (+35%)"]},
	&"bandagem_esteril": {"name": "Bandagem com álcool", "short": "Band. álcool", "kind": "food", "heal": 60, "cure": true, "stack": 5,
		"size": Vector3(0.12, 0.06, 0.12), "desc": "Limpa a ferida com álcool: cura mais e acaba com a doença.", "controls": ["Clique: usa (+60 vida, cura doença)"]},
	&"tabua": {"name": "Tábua", "kind": "material", "stack": 20, "size": Vector3(0.12, 0.03, 0.6),
		"desc": "Madeira de porta velha e cerca caída. Base de qualquer construção."},
	&"pedra": {"name": "Pedra", "kind": "material", "stack": 20, "size": Vector3(0.14, 0.1, 0.14),
		"desc": "Pedra de rua e de muro desabado. Vira pote, canteiro e alicerce."},
	&"sucata": {"name": "Sucata", "kind": "material", "stack": 10, "size": Vector3(0.3, 0.12, 0.2),
		"desc": "Ferro torto e cano de cobre. Um dia vai virar algo incrível. Hoje é só sucata."},
	&"pano": {"name": "Pano", "kind": "material", "stack": 10, "size": Vector3(0.3, 0.05, 0.25),
		"desc": "Cheira estranho. Não pergunte de onde veio."},
	&"fita": {"name": "Fita adesiva", "kind": "material", "stack": 10, "size": Vector3(0.14, 0.06, 0.14),
		"desc": "Conserta tudo, menos o fim do mundo. Ainda."},
}

## Armas que zumbis podem carregar (só corpo a corpo).
const ZOMBIE_WEAPONS := [&"taco", &"espada"]


## Comida que estraga: segundos de fresca até estragar. O frescor (0..1) fica no
## campo "dur" do slot (o mesmo da durabilidade, que já passa por mochila, baús,
## chão e rede); ao zerar vira "comida estragada".
const SPOIL := {
	&"camarao": 480.0, &"lagosta": 480.0, &"caranguejo": 480.0, &"caranguejo_aranha": 480.0, &"atum": 480.0, &"baixo": 480.0,
	&"camarao_assado": 900.0, &"lagosta_assada": 900.0, &"caranguejo_assado": 900.0, &"caranguejo_aranha_assado": 900.0,
	&"atum_assado": 900.0, &"baixo_assado": 900.0,
	&"cenoura": 1500.0, &"batata": 1800.0, &"abobora": 2400.0, &"fruta": 900.0,
	&"cenoura_assada": 900.0, &"batata_assada": 900.0, &"abobora_assada": 900.0, &"lata_quente": 600.0,
	&"pao_fresco": 1200.0, &"torrada": 1500.0, &"carne_crua": 480.0, &"carne_assada": 900.0,
	&"ovo": 1800.0, &"ovo_frito": 900.0, &"leite": 600.0,
}


## Comida estragando numa lista de vagas (mochila, baú, geladeira...): o frescor
## (dur) cai; o que zera vira "comida estragada" (uma pilha só).
## Devolve {any: tinha comida que estraga, rotted: algo apodreceu, rotten: quantos}.
static func spoil_slots(slots: Array, seconds: float) -> Dictionary:
	var any := false
	var rotten := 0
	for i in slots.size():
		if not slots[i].is_empty() and spoils(slots[i].id):
			slots[i].dur = slots[i].get("dur", 1.0) - seconds / SPOIL[slots[i].id]
			any = true
			if slots[i].dur <= 0.0:
				rotten += slots[i].amount
				slots[i] = {}
	if rotten > 0:
		var first := -1
		for i in slots.size():
			if not slots[i].is_empty() and slots[i].id == &"comida_estragada":
				if first < 0:
					first = i
				else:
					slots[first].amount += slots[i].amount
					slots[i] = {}
		if first >= 0:
			slots[first].amount += rotten
		else:
			for i in slots.size():
				if slots[i].is_empty():
					slots[i] = {"id": &"comida_estragada", "amount": rotten}
					break
	return {"any": any, "rotted": rotten > 0, "rotten": rotten}


## Afiar na pedra de amolar: lâminas e ferramentas de corte/ponta ganham dano (o "fio",
## 0..1 no slot como "sharp") e perdem o fio a cada uso.
const SHARPEN := ["sword", "axe", "pickaxe", "spear", "shovel"]
const SHARP_BONUS := 0.35 ## +35% de dano com o fio cheio
const SHARP_PER_USE := 0.04 ## ~25 golpes até perder o fio


## Campos extras de um item que viajam com ele (baú, chão, rede): qualidade da
## forja e fio da pedra de amolar.
const EXTRA_KEYS := ["q", "sharp"]


static func extras(slot: Dictionary) -> Dictionary:
	var out := {}
	for key in EXTRA_KEYS:
		if slot.has(key):
			out[key] = slot[key]
	return out


## Qualidade da forja (0..1 em "q"; sem "q" = peça comum, 0,5): dano x0,85..1,2
## e desgaste x1,3..0,7.
static func quality_damage(slot: Dictionary) -> float:
	return 0.85 + 0.35 * clampf(float(slot.q), 0.0, 1.0) if slot.has("q") else 1.0


static func quality_wear(slot: Dictionary) -> float:
	return 1.3 - 0.6 * clampf(float(slot.q), 0.0, 1.0) if slot.has("q") else 1.0


static func sharpenable(id: StringName) -> bool:
	return def(id).get("weapon", "") in SHARPEN


static func spoils(id: StringName) -> bool:
	return SPOIL.has(id)


## Junta "moved" itens com frescor "dur" numa pilha: o frescor vira a média ponderada.
static func merge_into(target: Dictionary, moved: int, dur := 1.0) -> void:
	if spoils(target.id):
		var total: int = target.amount + moved
		target.dur = (target.get("dur", 1.0) * target.amount + dur * moved) / maxf(total, 1)
	target.amount += moved


static func has(id: StringName) -> bool:
	return ITEMS.has(id)


static func def(id: StringName) -> Dictionary:
	return ITEMS.get(id, {"name": String(id), "kind": "material", "stack": 10, "size": Vector3(0.2, 0.2, 0.2)})


static func display_name(id: StringName) -> String:
	return def(id).name


## Quantos usos aguenta (0 = não gasta): armas corpo a corpo e ferramentas
## gastam a cada golpe/uso; roupas e armaduras a cada dano recebido.
const DURABILITY := {"sword": 300, "bat": 350, "spoon": 300, "axe": 220, "pickaxe": 220, "shovel": 200,
	"spear": 160, "hammer": 400, "chisel": 300}


static func max_durability(id: StringName) -> int:
	var d := def(id)
	if d.has("durability"):
		return d.durability
	if d.kind == "armor":
		return int(60 + d.get("armor", 0.1) * 900.0) # mais proteção, mais resistente
	var base: int = DURABILITY.get(d.get("weapon", ""), 0)
	return int(base * 0.35) if d.get("power", 1.0) < 1.0 else base # ferramenta simples dura pouco


## Nome curto para caber dentro de um slot ("Machado simples" -> "Machado").
static func short_name(id: StringName) -> String:
	var d := def(id)
	if d.has("short"):
		return d.short
	return short_text(d.name)


static func short_text(text: String) -> String:
	var first := text.split(" ")[0]
	return first if first.length() <= 9 else first.left(8) + "."


static func description(id: StringName) -> String:
	return def(id).get("desc", "")


static func weapon_of(id: StringName) -> String:
	return def(id).get("weapon", "")


## Armas, ferramentas e roupas: 1 por slot. Todo o resto empilha até 100.
static func max_stack(id: StringName) -> int:
	var d := def(id)
	if d.kind in ["weapon", "tool", "armor"]:
		return 1
	return 100


## Modelo 3D do item, montado ao longo de -Z (como as armas na mão do player).
static func make_mesh(id: StringName) -> Node3D:
	return ItemModels.build(id)


## Centro da caixa de colisão do item no chão.
static func shape_center(id: StringName) -> Vector3:
	if def(id).kind in ["weapon", "tool"] and id not in [&"pistola", &"carregador"]:
		return Vector3(0, 0, -def(id).size.z * 0.5 + 0.05)
	return Vector3.ZERO
