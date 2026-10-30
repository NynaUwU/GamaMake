class_name ItemDB
## Catálogo de itens: nome, tipo, quanto empilha e o modelo usado no chão
## (e na mão dos zumbis). Para criar um item novo, adicione uma entrada aqui.
##
## kind: "weapon" (equipa ao selecionar na hotbar), "tool" (funciona estando
## no inventário, ex.: lanterna) ou "material" (para crafting no futuro).

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
	&"martelo": {"name": "Martelo", "kind": "weapon", "weapon": "hammer", "stack": 1, "size": Vector3(0.16, 0.2, 0.45),
		"desc": "Constrói na grade invisível: paredes, pisos, tetos, pilares, janelas e portas.",
		"controls": ["Clique: constrói a peça escolhida", "Segurar botão direito: menu de construção (solte no item)",
			"R: gira a parede", "Shift + clique: desmonta a peça (ou tira janela/porta)",
			"Janela/Porta: mire um buraco feito pela talhadeira", "Porta: o buraco precisa encostar no chão"]},
	&"talhadeira": {"name": "Talhadeira", "kind": "weapon", "weapon": "chisel", "stack": 1, "size": Vector3(0.05, 0.05, 0.35),
		"desc": "Tira triângulos de paredes, pisos e tetos. Janela, porta, buraco para espiar zumbi.",
		"controls": ["Clique: tira o triângulo (meio quadrado) mirado", "R: troca a diagonal do corte (/ ou \\)",
			"Clique e arraste: seleciona uma área e tira tudo ao soltar"]},
	&"cajado": {"name": "Cajado", "kind": "weapon", "weapon": "staff", "stack": 1, "size": Vector3(0.12, 0.12, 1.2),
		"damage_type": "Explosão", "damage": 70, "knockback": 450,
		"desc": "Dispara mísseis mágicos. Ler o manual antes era opcional.",
		"controls": ["Segurar clique: dispara mísseis"]},
	&"pistola": {"name": "Pistola", "kind": "weapon", "weapon": "pistol", "stack": 1, "size": Vector3(0.05, 0.15, 0.22),
		"damage_type": "Perfuração", "damage": 40, "knockback": 20,
		"desc": "Latão, madeira e pólvora de procedência duvidosa. 12 tiros e munição infinita.",
		"controls": ["Clique: atira", "R: recarrega"]},
	&"lanterna": {"name": "Lanterna", "kind": "tool", "stack": 1, "size": Vector3(0.08, 0.08, 0.24),
		"desc": "Lanterna de latão (L). Gasta bateria; recarregue com o carregador. Zumbis adoram uma luz na cara.",
		"controls": ["L: liga/desliga (precisa estar no inventário)"]},
	&"carregador": {"name": "Carregador", "kind": "weapon", "weapon": "charger", "stack": 1, "size": Vector3(0.26, 0.2, 0.1),
		"desc": "Dínamo de mão para a bateria da lanterna. Aperte rápido: devagar só cansa o braço.",
		"controls": ["Clique rápido: gira o dínamo e carrega a lanterna"]},
	&"fruta": {"name": "Fruta", "kind": "food", "heal": 25, "stack": 10, "size": Vector3(0.14, 0.14, 0.14),
		"desc": "Vermelha, meio torta, provavelmente comestível. Recupera 25 de vida (clique para comer).",
		"controls": ["Clique: come (+25 de vida)"]},
	&"sucata": {"name": "Sucata", "kind": "material", "stack": 10, "size": Vector3(0.3, 0.12, 0.2),
		"desc": "Ferro torto e cano de cobre. Um dia vai virar algo incrível. Hoje é só sucata."},
	&"pano": {"name": "Pano", "kind": "material", "stack": 10, "size": Vector3(0.3, 0.05, 0.25),
		"desc": "Cheira estranho. Não pergunte de onde veio."},
	&"fita": {"name": "Fita adesiva", "kind": "material", "stack": 10, "size": Vector3(0.14, 0.06, 0.14),
		"desc": "Conserta tudo, menos o fim do mundo. Ainda."},
}

## Armas que zumbis podem carregar (só corpo a corpo).
const ZOMBIE_WEAPONS := [&"taco", &"espada"]


static func has(id: StringName) -> bool:
	return ITEMS.has(id)


static func def(id: StringName) -> Dictionary:
	return ITEMS.get(id, {"name": String(id), "kind": "material", "stack": 10, "size": Vector3(0.2, 0.2, 0.2)})


static func display_name(id: StringName) -> String:
	return def(id).name


static func description(id: StringName) -> String:
	return def(id).get("desc", "")


static func weapon_of(id: StringName) -> String:
	return def(id).get("weapon", "")


static func max_stack(id: StringName) -> int:
	return def(id).stack


## Modelo 3D do item, montado ao longo de -Z (como as armas na mão do player).
static func make_mesh(id: StringName) -> Node3D:
	return ItemModels.build(id)


## Centro da caixa de colisão do item no chão.
static func shape_center(id: StringName) -> Vector3:
	if def(id).kind in ["weapon", "tool"] and id not in [&"pistola", &"carregador"]:
		return Vector3(0, 0, -def(id).size.z * 0.5 + 0.05)
	return Vector3.ZERO
