class_name Loot
extends RefCounted
## Tabelas de saque. Cada linha: [item, chance (0-1), mínimo, máximo].
## roll() sorteia de 2 a 4 linhas diferentes (pelo menos 1 sempre sai).

const TABLES := {
	"casa": [ # baú/armário de casa: comida, pano, um pouco de material
		[&"lata", 0.45, 1, 2], [&"pao", 0.35, 1, 2], [&"fruta", 0.25, 1, 3], [&"pano", 0.4, 1, 3],
		[&"tabua", 0.45, 2, 5], [&"fita", 0.2, 1, 1], [&"bandagem", 0.15, 1, 1],
		[&"semente_cenoura", 0.25, 2, 4], [&"semente_batata", 0.2, 2, 3], [&"semente_abobora", 0.12, 1, 3],
		[&"chinelo", 0.02, 1, 1],
	],
	"caixote": [ # caixote de rua: material de construção
		[&"tabua", 0.7, 3, 8], [&"pedra", 0.55, 2, 6], [&"sucata", 0.5, 1, 4], [&"fita", 0.25, 1, 2],
		[&"pa", 0.05, 1, 1], [&"martelo", 0.04, 1, 1], [&"talhadeira", 0.04, 1, 1], [&"lata", 0.15, 1, 1],
	],
	"ruina": [ # escombros: sucata e pedra, às vezes algo raro
		[&"pedra", 0.7, 3, 7], [&"sucata", 0.6, 2, 5], [&"tabua", 0.35, 1, 4], [&"pano", 0.25, 1, 2],
		[&"bumerangue", 0.03, 1, 1], [&"pa", 0.05, 1, 1], [&"semente_abobora", 0.15, 1, 2],
	],
}


## Caixote da área inicial: o básico para começar a construir e plantar.
const START := [[&"tabua", 20], [&"pedra", 10], [&"semente_cenoura", 4], [&"semente_batata", 3], [&"lata", 2], [&"pa", 1]]


## Recursos do mapa: sempre dão isso (quantidade sorteada no intervalo).
const FIXED := {
	"arvore": [[&"tronco", 2, 3], [&"muda", 0, 1]],
	"arvore_fruta": [[&"tronco", 1, 2], [&"fruta", 1, 3], [&"muda", 0, 1]],
	"rocha": [[&"pedra", 3, 5]],
	"ferro": [[&"minerio_ferro", 2, 4], [&"pedra", 1, 2]],
	"cobre": [[&"minerio_cobre", 2, 4], [&"pedra", 1, 2]],
	"carvao": [[&"carvao", 3, 5]],
	# Móveis desmontados.
	"movel_mesa": [[&"tabua", 2, 3], [&"graveto", 0, 2]],
	"movel_cadeira": [[&"tabua", 1, 1], [&"graveto", 1, 2]],
	"movel_cama": [[&"tabua", 2, 3], [&"pano", 2, 3]],
	"movel_armario": [[&"tabua", 3, 4], [&"sucata", 0, 1]],
	"movel_estante": [[&"tabua", 2, 3], [&"graveto", 1, 3]],
	"movel_fogao": [[&"sucata", 2, 4], [&"pedra", 1, 2]],
	"movel_sofa": [[&"pano", 2, 4], [&"tabua", 1, 2]],
	"movel_banheira": [[&"sucata", 3, 5]],
	"movel_privada": [[&"pedra", 2, 3], [&"sucata", 0, 1]],
	"movel_pia": [[&"pedra", 1, 2], [&"vidro", 0, 1]],
	"movel_balcao": [[&"tabua", 2, 3], [&"pedra", 1, 2], [&"lata", 0, 1]],
	"movel_comoda": [[&"tabua", 2, 3], [&"pano", 0, 2]],
}


static func roll(table: String) -> Array:
	if table == "inicio":
		return START.duplicate(true)
	if FIXED.has(table):
		var fixed := []
		for row in FIXED[table]:
			var amount := randi_range(row[1], row[2])
			if amount > 0:
				fixed.append([row[0], amount])
		return fixed
	var rows: Array = TABLES.get(table, TABLES.casa)
	var result := []
	var want := randi_range(2, 4)
	var order := rows.duplicate()
	order.shuffle()
	for row in order:
		if result.size() >= want:
			break
		if randf() < row[1]:
			result.append([row[0], randi_range(row[2], row[3])])
	if result.is_empty():
		var row: Array = rows[0]
		result.append([row[0], row[2]])
	return result
