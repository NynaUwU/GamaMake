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


func state() -> Array:
	var list := []
	for id in pieces:
		var piece: BuildPiece = pieces[id]
		list.append([id, piece.kind, piece.cell, piece.rot, piece.removed])
	return list


func load_state(list: Array) -> void:
	for entry in list:
		if not pieces.has(entry[0]):
			_spawn(entry[0], entry[1], entry[2], entry[3], entry[4])
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
