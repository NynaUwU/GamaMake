class_name BuildingManager
extends Node3D
## Todas as construções do mundo (nó "Building" da cena principal).
## Online o host decide (lugar livre? triângulo ainda existe?) e repassa a
## todos; quem entra depois recebe tudo (peças + triângulos tirados).
## Cada lugar da grade só aceita uma peça de cada tipo e direção.

var pieces := {} ## net_id -> BuildPiece
var _slots := {} # "tipo|x|y|z|rot" -> net_id
var _next_id := 1


static func slot_key(kind: int, cell: Vector3i, rot: int) -> String:
	return "%d|%d|%d|%d|%d" % [kind, cell.x, cell.y, cell.z, rot]


func can_place(kind: int, cell: Vector3i, rot: int) -> bool:
	return not _slots.has(slot_key(kind, cell, rot))


# --- Pedidos (qualquer jogador) -------------------------------------------------

func request_place(kind: int, cell: Vector3i, rot: int) -> void:
	Net.i.build_request("place", [kind, cell, rot])


func request_cut(piece: BuildPiece, triangle: int) -> void:
	Net.i.build_request("cut", [piece.net_id, triangle])


func request_remove(piece: BuildPiece) -> void:
	Net.i.build_request("remove", [piece.net_id])


## Talhadeira arrastada: vários triângulos de uma vez.
func request_cut_many(piece: BuildPiece, triangles: PackedInt32Array) -> void:
	Net.i.build_request("cut_many", [piece.net_id, triangles])


func request_fill(piece: BuildPiece, type: String, triangles: PackedInt32Array) -> void:
	Net.i.build_request("fill", [piece.net_id, type, triangles])


func request_door(piece: BuildPiece, index: int, open: bool) -> void:
	Net.i.build_request("door", [piece.net_id, index, open])


func request_unfill(piece: BuildPiece, index: int) -> void:
	Net.i.build_request("unfill", [piece.net_id, index])


# --- Host -------------------------------------------------------------------------

## Valida e aplica. Devolve o que mandar para os outros ([] = recusado).
func host_apply(action: String, args: Array) -> Array:
	match action:
		"place":
			var kind: int = args[0]
			var cell: Vector3i = args[1]
			var rot: int = args[2] if kind == BuildPiece.Kind.WALL else 0
			if not can_place(kind, cell, rot):
				return []
			var id := _next_id
			_next_id += 1
			_spawn(id, kind, cell, rot, PackedByteArray())
			return [id, kind, cell, rot]
		"cut":
			var piece: BuildPiece = pieces.get(args[0])
			if piece == null or args[1] < 0 or args[1] >= BuildPiece.TRIS or piece.removed[args[1]] == 1:
				return []
			piece.remove_triangle(args[1])
			return args
		"remove":
			if not pieces.has(args[0]):
				return []
			_remove(args[0])
			return args
		"cut_many":
			var piece: BuildPiece = pieces.get(args[0])
			if piece == null:
				return []
			var cut := PackedInt32Array()
			for t in args[1]:
				if t >= 0 and t < BuildPiece.TRIS and piece.removed[t] == 0:
					piece.removed[t] = 1
					cut.append(t)
			if cut.is_empty():
				return []
			piece.rebuild()
			return [args[0], cut]
		"fill":
			var piece: BuildPiece = pieces.get(args[0])
			var tris: PackedInt32Array = args[2]
			if piece == null or tris.is_empty() or args[1] not in ["window", "door"]:
				return []
			for t in tris:
				if t < 0 or t >= BuildPiece.TRIS or piece.removed[t] == 0 or piece.filled(t):
					return []
			if args[1] == "door" and (piece.kind != BuildPiece.Kind.WALL or not BuildPiece.touches_bottom(tris)):
				return []
			piece.add_fill(args[1], tris)
			return args
		"door":
			var piece: BuildPiece = pieces.get(args[0])
			if piece == null or args[1] >= piece.fills.size() or piece.fills[args[1]].type != "door":
				return []
			piece.set_door_open(args[1], args[2])
			return args
		"unfill":
			var piece: BuildPiece = pieces.get(args[0])
			if piece == null or args[1] >= piece.fills.size():
				return []
			piece.remove_fill(args[1])
			return args
	return []


## Chegou do host (clientes).
func apply_remote(action: String, args: Array) -> void:
	match action:
		"place":
			if not pieces.has(args[0]):
				_spawn(args[0], args[1], args[2], args[3], PackedByteArray())
		"cut":
			var piece: BuildPiece = pieces.get(args[0])
			if piece:
				piece.remove_triangle(args[1])
		"remove":
			_remove(args[0])
		"cut_many":
			var piece: BuildPiece = pieces.get(args[0])
			if piece:
				for t in args[1]:
					piece.removed[t] = 1
				piece.rebuild()
		"fill":
			var piece: BuildPiece = pieces.get(args[0])
			if piece:
				piece.add_fill(args[1], args[2])
		"door":
			var piece: BuildPiece = pieces.get(args[0])
			if piece:
				piece.set_door_open(args[1], args[2])
		"unfill":
			var piece: BuildPiece = pieces.get(args[0])
			if piece:
				piece.remove_fill(args[1])


func state() -> Array:
	var list := []
	for id in pieces:
		var piece: BuildPiece = pieces[id]
		list.append([id, piece.kind, piece.cell, piece.rot, piece.removed, piece.fills])
	return list


func load_state(list: Array) -> void:
	for entry in list:
		if not pieces.has(entry[0]):
			_spawn(entry[0], entry[1], entry[2], entry[3], entry[4])
			if entry.size() > 5:
				for fill in entry[5]:
					pieces[entry[0]].add_fill(fill.type, fill.tris, fill.open)
		_next_id = maxi(_next_id, entry[0] + 1)


func _spawn(id: int, kind: int, cell: Vector3i, rot: int, removed: PackedByteArray) -> void:
	var piece := BuildPiece.new()
	piece.name = "Piece_%d" % id
	piece.net_id = id
	piece.setup(kind, cell, rot)
	if removed.size() == BuildPiece.TRIS:
		piece.removed = removed
	add_child(piece)
	pieces[id] = piece
	_slots[slot_key(kind, cell, rot)] = id
	_next_id = maxi(_next_id, id + 1)


func _remove(id: int) -> void:
	var piece: BuildPiece = pieces.get(id)
	if piece == null:
		return
	pieces.erase(id)
	_slots.erase(slot_key(piece.kind, piece.cell, piece.rot))
	piece.queue_free()
