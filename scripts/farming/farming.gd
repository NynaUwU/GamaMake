class_name Farming
extends RefCounted
## Plantação: culturas, modelos das plantas e o uso da pá / sementes na mão.
##   Pá (botão direito): no chão de terra cava uma cova; numa cova/pote/canteiro
##   vazio planta a primeira semente da mochila; numa planta pronta, colhe.
##   Semente na mão (clique): planta aquela semente onde estiver mirando.
## Plantas são seres vivos: blocos (como os zumbis e o jogador).

const REACH := 3.6
const CROPS := {
	"cenoura": {"time": 240.0, "food": &"cenoura", "seed": &"semente_cenoura", "yield": [2, 3], "seeds": [1, 2],
		"leaf": Color(0.3, 0.55, 0.2), "fruit": Color(0.85, 0.42, 0.1)},
	"batata": {"time": 300.0, "food": &"batata", "seed": &"semente_batata", "yield": [2, 4], "seeds": [1, 2],
		"leaf": Color(0.25, 0.45, 0.2), "fruit": Color(0.85, 0.82, 0.95)},
	"abobora": {"time": 420.0, "food": &"abobora", "seed": &"semente_abobora", "yield": [1, 2], "seeds": [1, 3],
		"leaf": Color(0.28, 0.5, 0.18), "fruit": Color(0.86, 0.45, 0.1)},
}
const SEED_ORDER := ["cenoura", "batata", "abobora"]


static func manager(player: Node) -> PlacedManager:
	return player.get_parent().get_node_or_null("Placed") as PlacedManager


## crop = "" (pá: escolhe a semente da mochila / cava) ou a semente na mão.
## Devolve true se fez alguma coisa.
static func use(player: Player, crop: String) -> bool:
	var placed := manager(player)
	if placed == null:
		return false
	var cam := player.camera
	var query := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * REACH,
			1 | (1 << 5), [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var obj := hit.collider as PlacedObject
	if crop == "arvore":
		return _plant_tree(player, placed, hit, obj)
	if obj and obj.is_farm() and not obj.extra.has("tree"):
		var slot := obj.slot_at(hit.position)
		var entry: Dictionary = obj.crops[slot]
		if PlacedObject.progress(entry, placed.clock) >= 1.0:
			placed.request("harvest", [obj.net_id, slot])
			return true
		if not entry.is_empty():
			pass # o painel ao lado da mira já mostra a %
			return false
		# Vaga vazia: planta.
		var chosen := crop
		if chosen == "":
			for name in SEED_ORDER:
				if player.inventory.has(CROPS[name].seed) and obj.allows(name):
					chosen = name
					break
		if chosen == "":
			Sfx.play("click", -6.0, 0.6)
			return false
		if not obj.allows(chosen):
			Sfx.play("click", -6.0, 0.6)
			return false
		if not _take_one(player, CROPS[chosen].seed):
			return false
		placed.request("plant", [obj.net_id, slot, chosen])
		Sfx.play_at("step_soft", obj.global_position, 2.0, 0.8)
		return true
	# Pá no chão de terra (terreno, não rua/construção): cava uma cova.
	if crop == "" and _is_terrain(hit.collider) and hit.normal.y > 0.65:
		if _desert(player, hit.position):
			# Deserto: o solo não presta para plantar; a pá junta areia (e às vezes vidro).
			player.pick_up(&"areia", ItemDB.display_name(&"areia"), randi_range(1, 2))
			if randf() < 0.25:
				player.pick_up(&"vidro", ItemDB.display_name(&"vidro"), 1)
			Sfx.play_at("step_soft", hit.position, 4.0, 1.1)
			return true
		if placed.occupied(hit.position, 0.85):
			Sfx.play("click", -6.0, 0.6)
			return false
		var basis := Basis(Vector3.UP, player.rotation.y)
		placed.request("place", ["ground", Transform3D(basis, hit.position)])
		if randf() < 0.3:
			player.pick_up(&"pedra", ItemDB.display_name(&"pedra"), 1)
		return true
	if crop != "":
		Sfx.play("click", -6.0, 0.6)
	return false


static func _desert(player: Node, at: Vector3) -> bool:
	var terrain := player.get_parent().get_node_or_null("Terrain") as TerrainWorld
	return terrain != null and terrain.biome_at(at.x, at.z).desert > 0.5


## Muda: no chão de terra (não no deserto) ou numa floreira/canteiro vazio
## (a árvore ocupa o plantador inteiro).
static func _plant_tree(player: Player, placed: PlacedManager, hit: Dictionary, obj: PlacedObject) -> bool:
	var xform := Transform3D()
	var planter := -1
	if obj and obj.kind in ["pot_wide", "bed"]:
		if obj.extra.has("tree") or obj.crops.any(func(c): return not c.is_empty()):
			Sfx.play("click", -6.0, 0.6)
			return false
		var center := Vector3(0, 0.34, 0) if obj.kind == "pot_wide" else Vector3(BuildPiece.SIZE * 0.5, 0.22, BuildPiece.SIZE * 0.5)
		xform = Transform3D(Basis(Vector3.UP, randf() * TAU), obj.to_global(center))
		planter = obj.net_id
	elif _is_terrain(hit.collider) and hit.normal.y > 0.65 and not _desert(player, hit.position) \
			and not placed.occupied(hit.position, 1.4):
		xform = Transform3D(Basis(Vector3.UP, randf() * TAU), hit.position)
	else:
		Sfx.play("click", -6.0, 0.6)
		return false
	if not _take_one(player, &"muda"):
		return false
	placed.request("plant_tree", [xform, planter])
	Sfx.play_at("step_soft", xform.origin, 2.0, 0.8)
	return true


static func _is_terrain(collider: Object) -> bool:
	var node := collider as Node
	return node != null and node.get_parent() != null and node.get_parent().get_parent() is TerrainWorld


static func _take_one(player: Player, id: StringName) -> bool:
	var slots: Array = player.inventory.slots
	# Prefere a semente da mão (slot selecionado).
	if player.inventory.selected_id() == id:
		player.inventory.take(player.inventory.selected, 1)
		return true
	for i in slots.size():
		if not slots[i].is_empty() and slots[i].id == id:
			player.inventory.take(i, 1)
			return true
	return false


## Planta em blocos: 0 broto, 1 muda, 2 crescendo, 3 pronta (com o fruto à mostra).
static func plant_model(crop: String, stage: int, big := false) -> Node3D:
	var def: Dictionary = CROPS[crop]
	var mb := MeshBuilder.new()
	var leaf: Color = def.leaf
	var s: float = [0.35, 0.6, 0.85, 1.0][stage] * (1.15 if big else 1.0)
	match crop:
		"cenoura":
			for k in 3 + stage:
				var a := TAU * k / (3.0 + stage)
				mb.color(leaf.darkened(0.1 * (k % 2)))
				mb.box(Vector3(cos(a) * 0.04, 0.12 * s, sin(a) * 0.04) * Vector3(s, 1, s), Vector3(0.03, 0.24 * s, 0.03), Basis(Vector3(sin(a), 0, -cos(a)), 0.3))
			if stage == 3:
				mb.color(def.fruit)
				mb.box(Vector3(0, 0.02, 0), Vector3(0.07, 0.07, 0.07)) # ombro da cenoura aparecendo
		"batata":
			for k in 2 + stage:
				var a := TAU * k / (2.0 + stage) + 0.5
				mb.color(leaf.lightened(0.05 * (k % 2)))
				mb.box(Vector3(cos(a) * 0.07 * s, 0.1 * s, sin(a) * 0.07 * s), Vector3(0.1 * s, 0.05 * s, 0.1 * s), Basis(Vector3.UP, a))
			mb.color(leaf.darkened(0.2))
			mb.box(Vector3(0, 0.07 * s, 0), Vector3(0.03, 0.14 * s, 0.03))
			if stage == 3:
				mb.color(def.fruit) # florzinhas brancas: hora de colher
				for k in 3:
					var a := TAU * k / 3.0
					mb.box(Vector3(cos(a) * 0.06, 0.2, sin(a) * 0.06), Vector3(0.035, 0.035, 0.035))
		"abobora":
			mb.color(leaf)
			for k in 2 + stage:
				var a := TAU * k / (2.0 + stage)
				mb.box(Vector3(cos(a) * 0.14 * s, 0.04, sin(a) * 0.14 * s), Vector3(0.14 * s, 0.03, 0.14 * s), Basis(Vector3.UP, a))
			mb.color(leaf.darkened(0.25))
			mb.box(Vector3(0, 0.06, 0), Vector3(0.03, 0.12 * s, 0.03))
			if stage >= 2:
				var r := 0.08 if stage == 2 else 0.17
				mb.color(def.fruit if stage == 3 else Color(0.5, 0.6, 0.2))
				mb.box(Vector3(0.12, r * 0.5, 0.05), Vector3(r * 1.25, r, r * 1.15))
				mb.color(leaf.darkened(0.3))
				mb.box(Vector3(0.12, r + 0.02, 0.05), Vector3(0.025, 0.05, 0.025))
	var node := MeshInstance3D.new()
	node.mesh = mb.finish(PlacedObject._mat(), false)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
