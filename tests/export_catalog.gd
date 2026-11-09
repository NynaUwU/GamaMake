extends SceneTree
## Exporta os dados do jogo para o catálogo em PDF (tools/catalog_pdf.py):
##   godot --headless --path . --script tests/export_catalog.gd   (OUT=arquivo.json)
## Receitas (RecipeBook), construções do martelo, força/elétrica das máquinas,
## itens, plantas, animais, bichos da água, saques, combustíveis, eras e manuais.

func _s(v: Variant) -> Variant:
	# StringName/Color/Vector3 -> tipos que o JSON entende.
	if v is StringName:
		return String(v)
	if v is Dictionary:
		var out := {}
		for k in v:
			out[String(k)] = _s(v[k])
		return out
	if v is Array:
		return v.map(func(x): return _s(x))
	if v is Color or v is Vector3 or v is Vector2:
		return str(v)
	return v


func _init() -> void:
	var data := {}
	var items := {}
	for id in ItemDB.ITEMS:
		var d: Dictionary = ItemDB.ITEMS[id]
		items[String(id)] = {"name": d.get("name", String(id)), "kind": d.get("kind", "material"), "desc": d.get("desc", ""),
			"stack": d.get("stack", 1), "armor": d.get("armor", 0.0), "durability": ItemDB.max_durability(id),
			"weapon": d.get("weapon", ""), "slot": d.get("slot", ""), "damage": d.get("damage", 0), "heal": d.get("heal", 0),
			"food": d.get("food", 0), "warm": d.get("warm", 0.0), "controls": d.get("controls", [])}
	data.items = items
	data.recipes = _s(RecipeBook.all())
	data.sections = _s(RecipeBook.SECTIONS)
	var build := {}
	for tab in Builder.ENTRIES:
		build[tab] = _s(Builder.ENTRIES[tab].map(func(e): return {"id": e.id, "name": e.name, "desc": e.get("desc", ""), "cost": e.get("cost", {}),
			"manual": e.get("manual", ""), "place": e.get("place", ""), "metal": e.get("metal", false)}))
	data.build = build
	data.power = {"output": Power.OUTPUT, "demand": Power.DEMAND}
	data.electric = {"demand": Electric.DEMAND, "converters": Electric.CONVERTERS, "only_110": Electric.ONLY_110,
		"dynamo": Electric.DYNAMO_OUT, "solar": Electric.SOLAR_OUT, "cell_cap": Electric.CELL_CAP, "cell_rate": Electric.CELL_RATE,
		"cells": Electric.CELLS, "bank_cells": Electric.BANK_CELLS}
	data.crops = _s(Farming.CROPS)
	data.animals = _s(Animal.KINDS)
	data.animal_names = Animal.NAMES
	data.animal_spawn = _s(AnimalManager.TABLES)
	data.creatures = _s(Creatures.IDS)
	data.loot = _s(Loot.TABLES)
	data.resources = _s(Loot.FIXED)
	data.start = _s(Loot.START)
	data.fuel_furnace = _s(Smelting.FUEL_TIME)
	data.fuel_fire = _s(Cooking.FIREWOOD)
	data.torch_fuel = _s(Smithing.TORCH_FUEL)
	data.chem_fuel = _s(Smithing.CHEM_FUEL)
	var guns := {}
	for id in Player.GUNS:
		var g: Dictionary = Player.GUNS[id]
		guns[String(id)] = {"ammo": String(g.ammo), "mag": g.mag, "damage": g.damage, "pellets": g.pellets, "rate": g.rate, "reload": g.reload,
			"range": g.range, "pierce": g.pierce, "zoom": g.zoom, "scope": g.get("scope", false), "falloff": g.get("falloff", 0.0)}
	data.guns = guns
	data.gas = {"edge": Contamination.EDGE, "ceiling": Contamination.CEILING, "filter_time": Contamination.FILTER_TIME}
	data.eras = Progress.ERAS
	data.achievements = Progress.ACHIEVEMENTS
	data.manuals = _s(Progress.MANUALS)
	var path := OS.get_environment("OUT")
	if path == "":
		path = "user://catalog.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t", false)) # mantém a ordem (abas do martelo, estações)
	file.close()
	print("catálogo exportado: %d itens, %d receitas -> %s" % [items.size(), data.recipes.size(), path])
	quit()
