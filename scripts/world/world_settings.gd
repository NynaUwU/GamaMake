class_name WorldSettings
extends RefCounted
## Configurações do mundo escolhidas no menu "Criar mundo" (sliders). Ficam em
## WorldSettings.values, vão no save e o host manda para quem entrar, então
## todo mundo gera exatamente o mesmo mapa. Valor que falta = padrão.
##
## Cada linha: [chave, nome, mínimo, máximo, passo, padrão, formato, grupo].
## Formato: "%" (100 = normal), "km", "min", "n" (número), "temp" (frio/quente), "onoff".

const DEFS := [
	["size", "Tamanho do mapa", 1.5, 4.5, 0.5, 3.0, "km", "Mapa"],
	["island", "Tamanho da ilha", 60.0, 95.0, 1.0, 86.0, "%", "Mapa"],
	["coast", "Recorte da costa", 0.0, 200.0, 10.0, 100.0, "%", "Mapa"],
	["mountain_height", "Altura das montanhas", 0.0, 200.0, 10.0, 100.0, "%", "Relevo"],
	["mountains", "Quantidade de montanhas", 0.0, 200.0, 10.0, 100.0, "%", "Relevo"],
	["hills", "Morros nas planícies", 0.0, 200.0, 10.0, 100.0, "%", "Relevo"],
	["temperature", "Clima (frio / quente)", -100.0, 100.0, 10.0, 0.0, "temp", "Relevo"],
	["cities", "Cidades", 0.0, 200.0, 25.0, 100.0, "%", "Lugares"],
	["lakes", "Lagos", 0.0, 200.0, 25.0, 100.0, "%", "Lugares"],
	["rivers", "Rios", 0.0, 12.0, 1.0, 5.0, "n", "Lugares"],
	["track", "Pista de corrida", 0.0, 1.0, 1.0, 1.0, "onoff", "Lugares"],
	["trees", "Árvores e plantas", 0.0, 200.0, 10.0, 100.0, "%", "Recursos"],
	["rocks", "Rochas e minérios", 0.0, 200.0, 10.0, 100.0, "%", "Recursos"],
	["loot", "Saque nos baús", 25.0, 300.0, 25.0, 100.0, "%", "Recursos"],
	["zombies", "Zumbis", 0.0, 300.0, 10.0, 100.0, "%", "Perigo"],
	["hordes", "Hordas", 0.0, 300.0, 25.0, 100.0, "%", "Perigo"],
	["specials", "Zumbis especiais", 0.0, 300.0, 25.0, 100.0, "%", "Perigo"],
	["animals", "Animais", 0.0, 300.0, 25.0, 100.0, "%", "Perigo"],
	["day_length", "Duração do dia", 5.0, 60.0, 5.0, 20.0, "min", "Tempo"],
	["rain", "Chuva", 0.0, 250.0, 25.0, 100.0, "%", "Tempo"],
]

static var values := {}


static func def(key: String) -> Array:
	for row in DEFS:
		if row[0] == key:
			return row
	return []


static func default_of(key: String) -> float:
	var row := def(key)
	return row[5] if not row.is_empty() else 0.0


static func get_value(key: String) -> float:
	return float(values.get(key, default_of(key)))


## Multiplicador (para os "%": 100 -> 1.0).
static func mult(key: String) -> float:
	return get_value(key) / 100.0


static func reset() -> void:
	values = {}


## Só o que é diferente do padrão (save/rede menores e saves antigos continuam iguais).
static func export() -> Dictionary:
	var out := {}
	for row in DEFS:
		var v := get_value(row[0])
		if not is_equal_approx(v, row[5]):
			out[row[0]] = v
	return out


static func load_from(data: Dictionary) -> void:
	values = {}
	for key in data:
		if not def(String(key)).is_empty():
			values[String(key)] = float(data[key])


static func text(key: String, v: float) -> String:
	var row := def(key)
	match row[6]:
		"%":
			return "%d%%" % roundi(v)
		"km":
			return "%.1f km" % v
		"min":
			return "%d min" % roundi(v)
		"temp":
			if absf(v) < 1.0:
				return "normal"
			return ("mais quente +%d" if v > 0.0 else "mais frio %d") % roundi(v)
		"onoff":
			return "sim" if v > 0.5 else "não"
	return str(roundi(v))
