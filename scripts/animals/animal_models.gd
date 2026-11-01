class_name AnimalModels
extends RefCounted
## Modelos dos bichos (seres vivos = blocos). Cada bicho vira poucas malhas com cor
## por vértice: corpo, cabeça (gira para pastar/bicar), pernas (balançam no passo),
## asas (batem no voo) e lã (some quando a ovelha é tosquiada). As malhas ficam
## guardadas por espécie: o 2º bicho igual não monta nada.
## Frente do bicho = +Z.
##
## Parte: [centro, tamanho, cor, (rotação em graus)]
## Perna: [pivô (quadril), comprimento, largura, cor, cor do casco]
## Asa:   [pivô (ombro), lado (-1/1), partes]

static var _cache := {}


static func spec(kind: String) -> Dictionary:
	match kind:
		"cervo":
			var fur := Color(0.55, 0.38, 0.22)
			var belly := Color(0.85, 0.75, 0.6)
			var antler := Color(0.75, 0.68, 0.55)
			return {
				"body": [[Vector3(0, 0.85, 0), Vector3(0.42, 0.4, 0.95), fur], [Vector3(0, 0.67, 0), Vector3(0.36, 0.06, 0.8), belly],
					[Vector3(0, 1.12, 0.42), Vector3(0.2, 0.42, 0.2), fur, Vector3(-20, 0, 0)], [Vector3(0, 0.95, -0.5), Vector3(0.1, 0.14, 0.06), belly]],
				"head_at": Vector3(0, 1.3, 0.52),
				"head": [[Vector3(0, 0.1, 0.08), Vector3(0.22, 0.22, 0.36), fur], [Vector3(0, 0.06, 0.27), Vector3(0.1, 0.08, 0.04), Color(0.15, 0.1, 0.08)],
					[Vector3(-0.112, 0.14, 0.16), Vector3(0.02, 0.04, 0.04), Color.BLACK], [Vector3(0.112, 0.14, 0.16), Vector3(0.02, 0.04, 0.04), Color.BLACK],
					[Vector3(-0.15, 0.23, -0.02), Vector3(0.12, 0.06, 0.04), fur], [Vector3(0.15, 0.23, -0.02), Vector3(0.12, 0.06, 0.04), fur],
					[Vector3(-0.08, 0.35, 0.0), Vector3(0.04, 0.3, 0.04), antler], [Vector3(0.08, 0.35, 0.0), Vector3(0.04, 0.3, 0.04), antler],
					[Vector3(-0.16, 0.45, 0.0), Vector3(0.16, 0.04, 0.04), antler], [Vector3(0.16, 0.45, 0.0), Vector3(0.16, 0.04, 0.04), antler],
					[Vector3(-0.1, 0.48, 0.08), Vector3(0.04, 0.04, 0.14), antler], [Vector3(0.1, 0.48, 0.08), Vector3(0.04, 0.04, 0.14), antler]],
				"legs": _four(0.14, 0.35, 0.66, 0.66, 0.08, fur.darkened(0.15), Color(0.1, 0.08, 0.06)),
			}
		"coelho":
			var fur := Color(0.62, 0.55, 0.46)
			return {
				"body": [[Vector3(0, 0.15, 0), Vector3(0.2, 0.18, 0.3), fur], [Vector3(0, 0.17, -0.16), Vector3(0.07, 0.07, 0.05), Color(0.95, 0.95, 0.92)]],
				"head_at": Vector3(0, 0.2, 0.13),
				"head": [[Vector3(0, 0.04, 0.03), Vector3(0.14, 0.13, 0.14), fur],
					[Vector3(-0.035, 0.18, 0.01), Vector3(0.035, 0.16, 0.025), fur.lightened(0.1)], [Vector3(0.035, 0.18, 0.01), Vector3(0.035, 0.16, 0.025), fur.lightened(0.1)],
					[Vector3(-0.072, 0.06, 0.07), Vector3(0.012, 0.025, 0.025), Color.BLACK], [Vector3(0.072, 0.06, 0.07), Vector3(0.012, 0.025, 0.025), Color.BLACK]],
				"legs": _four(0.07, 0.09, 0.08, 0.08, 0.045, fur.darkened(0.1), fur.darkened(0.2)),
			}
		"javali":
			var fur := Color(0.3, 0.22, 0.17)
			return {
				"body": [[Vector3(0, 0.55, 0), Vector3(0.5, 0.45, 0.9), fur], [Vector3(0, 0.8, 0.05), Vector3(0.12, 0.08, 0.8), fur.darkened(0.2)]],
				"head_at": Vector3(0, 0.55, 0.42),
				"head": [[Vector3(0, 0, 0.13), Vector3(0.36, 0.34, 0.3), fur], [Vector3(0, -0.05, 0.32), Vector3(0.18, 0.14, 0.1), Color(0.5, 0.35, 0.3)],
					[Vector3(-0.1, -0.05, 0.36), Vector3(0.03, 0.1, 0.03), Color(0.9, 0.88, 0.8)], [Vector3(0.1, -0.05, 0.36), Vector3(0.03, 0.1, 0.03), Color(0.9, 0.88, 0.8)],
					[Vector3(-0.16, 0.07, 0.24), Vector3(0.02, 0.03, 0.03), Color.BLACK], [Vector3(0.16, 0.07, 0.24), Vector3(0.02, 0.03, 0.03), Color.BLACK],
					[Vector3(-0.13, 0.2, 0.06), Vector3(0.08, 0.1, 0.04), fur], [Vector3(0.13, 0.2, 0.06), Vector3(0.08, 0.1, 0.04), fur]],
				"legs": _four(0.16, 0.3, 0.34, 0.34, 0.1, fur.darkened(0.1), Color(0.12, 0.1, 0.08)),
			}
		"lobo":
			var fur := Color(0.42, 0.42, 0.44)
			var light := Color(0.7, 0.68, 0.64)
			return {
				"body": [[Vector3(0, 0.56, 0), Vector3(0.3, 0.32, 0.85), fur], [Vector3(0, 0.42, 0.05), Vector3(0.24, 0.06, 0.7), light],
					[Vector3(0, 0.62, 0.3), Vector3(0.34, 0.36, 0.3), fur.lightened(0.05)], [Vector3(0, 0.6, -0.55), Vector3(0.09, 0.09, 0.34), fur, Vector3(25, 0, 0)],
					[Vector3(0, 0.5, -0.7), Vector3(0.07, 0.07, 0.1), light, Vector3(25, 0, 0)]],
				"head_at": Vector3(0, 0.7, 0.45),
				"head": [[Vector3(0, 0.03, 0.08), Vector3(0.24, 0.22, 0.24), fur], [Vector3(0, -0.03, 0.26), Vector3(0.12, 0.1, 0.16), light],
					[Vector3(0, 0.0, 0.345), Vector3(0.05, 0.04, 0.02), Color.BLACK],
					[Vector3(-0.07, 0.18, 0.03), Vector3(0.06, 0.1, 0.04), fur.darkened(0.2)], [Vector3(0.07, 0.18, 0.03), Vector3(0.06, 0.1, 0.04), fur.darkened(0.2)],
					[Vector3(-0.08, 0.07, 0.2), Vector3(0.03, 0.025, 0.02), Color(0.95, 0.8, 0.2)], [Vector3(0.08, 0.07, 0.2), Vector3(0.03, 0.025, 0.02), Color(0.95, 0.8, 0.2)]],
				"legs": _four(0.1, 0.3, 0.42, 0.42, 0.07, fur.darkened(0.1), Color(0.15, 0.14, 0.14)),
			}
		"urso":
			var fur := Color(0.3, 0.21, 0.14)
			return {
				"body": [[Vector3(0, 0.78, 0), Vector3(0.72, 0.66, 1.25), fur], [Vector3(0, 1.12, 0.3), Vector3(0.52, 0.2, 0.42), fur.lightened(0.04)],
					[Vector3(0, 0.75, -0.65), Vector3(0.14, 0.12, 0.08), fur.darkened(0.1)]],
				"head_at": Vector3(0, 0.92, 0.66),
				"head": [[Vector3(0, 0.03, 0.14), Vector3(0.42, 0.38, 0.36), fur], [Vector3(0, -0.06, 0.37), Vector3(0.2, 0.16, 0.14), Color(0.55, 0.42, 0.3)],
					[Vector3(0, -0.02, 0.45), Vector3(0.08, 0.06, 0.03), Color.BLACK],
					[Vector3(-0.15, 0.23, 0.06), Vector3(0.1, 0.1, 0.06), fur.darkened(0.15)], [Vector3(0.15, 0.23, 0.06), Vector3(0.1, 0.1, 0.06), fur.darkened(0.15)],
					[Vector3(-0.11, 0.08, 0.32), Vector3(0.03, 0.03, 0.02), Color.BLACK], [Vector3(0.11, 0.08, 0.32), Vector3(0.03, 0.03, 0.02), Color.BLACK]],
				"legs": _four(0.22, 0.42, 0.5, 0.5, 0.18, fur.darkened(0.08), Color(0.85, 0.82, 0.72)),
			}
		"raposa":
			var fur := Color(0.78, 0.4, 0.15)
			var white := Color(0.94, 0.92, 0.88)
			return {
				"body": [[Vector3(0, 0.33, 0), Vector3(0.2, 0.2, 0.5), fur], [Vector3(0, 0.27, 0.15), Vector3(0.16, 0.1, 0.18), white],
					[Vector3(0, 0.36, -0.4), Vector3(0.13, 0.13, 0.36), fur, Vector3(20, 0, 0)], [Vector3(0, 0.3, -0.6), Vector3(0.1, 0.1, 0.1), white, Vector3(20, 0, 0)]],
				"head_at": Vector3(0, 0.42, 0.27),
				"head": [[Vector3(0, 0.0, 0.05), Vector3(0.16, 0.15, 0.16), fur], [Vector3(0, -0.03, 0.17), Vector3(0.07, 0.07, 0.12), white],
					[Vector3(0, -0.02, 0.235), Vector3(0.03, 0.03, 0.02), Color.BLACK],
					[Vector3(-0.05, 0.11, 0.0), Vector3(0.05, 0.09, 0.03), fur.darkened(0.3)], [Vector3(0.05, 0.11, 0.0), Vector3(0.05, 0.09, 0.03), fur.darkened(0.3)],
					[Vector3(-0.05, 0.03, 0.13), Vector3(0.02, 0.02, 0.02), Color.BLACK], [Vector3(0.05, 0.03, 0.13), Vector3(0.02, 0.02, 0.02), Color.BLACK]],
				"legs": _four(0.06, 0.17, 0.24, 0.24, 0.05, Color(0.15, 0.1, 0.08), Color(0.1, 0.08, 0.06)),
			}
		"cabra":
			var fur := Color(0.76, 0.73, 0.66)
			var horn := Color(0.4, 0.36, 0.3)
			return {
				"body": [[Vector3(0, 0.62, 0), Vector3(0.32, 0.34, 0.7), fur], [Vector3(0, 0.66, -0.37), Vector3(0.08, 0.12, 0.06), fur.lightened(0.1)]],
				"head_at": Vector3(0, 0.82, 0.36),
				"head": [[Vector3(0, 0.03, 0.08), Vector3(0.16, 0.2, 0.24), fur], [Vector3(0, -0.12, 0.13), Vector3(0.06, 0.12, 0.05), fur.darkened(0.1)],
					[Vector3(-0.05, 0.2, -0.02), Vector3(0.04, 0.2, 0.04), horn, Vector3(-35, 0, 0)], [Vector3(0.05, 0.2, -0.02), Vector3(0.04, 0.2, 0.04), horn, Vector3(-35, 0, 0)],
					[Vector3(-0.11, 0.08, 0.02), Vector3(0.08, 0.03, 0.05), fur], [Vector3(0.11, 0.08, 0.02), Vector3(0.08, 0.03, 0.05), fur],
					[Vector3(-0.082, 0.08, 0.14), Vector3(0.02, 0.025, 0.03), Color(0.8, 0.65, 0.2)], [Vector3(0.082, 0.08, 0.14), Vector3(0.02, 0.025, 0.03), Color(0.8, 0.65, 0.2)]],
				"legs": _four(0.1, 0.26, 0.45, 0.45, 0.06, fur.darkened(0.1), Color(0.2, 0.17, 0.14)),
			}
		"galinha":
			var white := Color(0.93, 0.91, 0.86)
			var red := Color(0.82, 0.12, 0.1)
			var orange := Color(0.92, 0.6, 0.15)
			return {
				"body": [[Vector3(0, 0.23, 0), Vector3(0.18, 0.18, 0.26), white], [Vector3(0, 0.33, -0.14), Vector3(0.12, 0.15, 0.06), white, Vector3(-25, 0, 0)]],
				"head_at": Vector3(0, 0.33, 0.1),
				"head": [[Vector3(0, 0.05, 0.03), Vector3(0.1, 0.12, 0.1), white], [Vector3(0, 0.04, 0.1), Vector3(0.04, 0.03, 0.05), orange],
					[Vector3(0, 0.13, 0.03), Vector3(0.03, 0.05, 0.08), red], [Vector3(0, -0.0, 0.085), Vector3(0.025, 0.05, 0.02), red],
					[Vector3(-0.052, 0.07, 0.05), Vector3(0.01, 0.02, 0.02), Color.BLACK], [Vector3(0.052, 0.07, 0.05), Vector3(0.01, 0.02, 0.02), Color.BLACK]],
				"legs": [[Vector3(-0.05, 0.14, 0), 0.14, 0.025, orange, orange], [Vector3(0.05, 0.14, 0), 0.14, 0.025, orange, orange]],
				"wings": [[Vector3(-0.09, 0.27, 0.0), -1.0, [[Vector3(-0.06, -0.03, -0.02), Vector3(0.13, 0.03, 0.17), white.darkened(0.06)]]],
					[Vector3(0.09, 0.27, 0.0), 1.0, [[Vector3(0.06, -0.03, -0.02), Vector3(0.13, 0.03, 0.17), white.darkened(0.06)]]]],
			}
		"ovelha":
			var wool := Color(0.91, 0.89, 0.83)
			var face := Color(0.2, 0.18, 0.16)
			return {
				"body": [[Vector3(0, 0.62, 0), Vector3(0.38, 0.34, 0.68), Color(0.78, 0.68, 0.64)]],
				"wool": [[Vector3(0, 0.64, 0), Vector3(0.52, 0.46, 0.82), wool], [Vector3(0, 0.88, 0.05), Vector3(0.36, 0.08, 0.6), wool.darkened(0.04)],
					[Vector3(0, 0.62, -0.42), Vector3(0.14, 0.14, 0.06), wool]],
				"head_at": Vector3(0, 0.76, 0.42),
				"head": [[Vector3(0, 0.0, 0.08), Vector3(0.18, 0.2, 0.26), face], [Vector3(0, 0.12, 0.02), Vector3(0.22, 0.09, 0.18), wool],
					[Vector3(-0.13, 0.03, 0.02), Vector3(0.09, 0.04, 0.06), face], [Vector3(0.13, 0.03, 0.02), Vector3(0.09, 0.04, 0.06), face],
					[Vector3(-0.092, 0.04, 0.12), Vector3(0.02, 0.025, 0.03), Color(0.85, 0.75, 0.3)], [Vector3(0.092, 0.04, 0.12), Vector3(0.02, 0.025, 0.03), Color(0.85, 0.75, 0.3)]],
				"legs": _four(0.13, 0.27, 0.45, 0.45, 0.07, face, Color(0.1, 0.09, 0.08)),
			}
		"vaca":
			var white := Color(0.93, 0.92, 0.88)
			var black := Color(0.12, 0.11, 0.1)
			var pink := Color(0.9, 0.62, 0.6)
			return {
				"body": [[Vector3(0, 0.98, 0), Vector3(0.62, 0.6, 1.3), white],
					[Vector3(0.315, 1.05, 0.2), Vector3(0.02, 0.32, 0.4), black], [Vector3(-0.315, 0.95, -0.25), Vector3(0.02, 0.36, 0.46), black],
					[Vector3(0.0, 1.285, -0.1), Vector3(0.4, 0.02, 0.5), black], [Vector3(0.0, 0.66, -0.3), Vector3(0.22, 0.1, 0.22), pink],
					[Vector3(0, 0.95, -0.67), Vector3(0.04, 0.5, 0.04), white.darkened(0.1)], [Vector3(0, 0.68, -0.67), Vector3(0.07, 0.1, 0.07), black]],
				"head_at": Vector3(0, 1.15, 0.68),
				"head": [[Vector3(0, 0, 0.14), Vector3(0.3, 0.32, 0.36), white], [Vector3(0.02, 0.08, 0.2), Vector3(0.14, 0.14, 0.2), black],
					[Vector3(0, -0.09, 0.34), Vector3(0.24, 0.14, 0.08), pink],
					[Vector3(-0.14, 0.2, 0.05), Vector3(0.05, 0.12, 0.05), Color(0.9, 0.86, 0.7)], [Vector3(0.14, 0.2, 0.05), Vector3(0.05, 0.12, 0.05), Color(0.9, 0.86, 0.7)],
					[Vector3(-0.21, 0.08, 0.06), Vector3(0.12, 0.05, 0.07), white], [Vector3(0.21, 0.08, 0.06), Vector3(0.12, 0.05, 0.07), white],
					[Vector3(-0.152, 0.06, 0.22), Vector3(0.02, 0.035, 0.035), black], [Vector3(0.152, 0.06, 0.22), Vector3(0.02, 0.035, 0.035), black]],
				"legs": _four(0.2, 0.48, 0.68, 0.68, 0.12, white.darkened(0.05), black),
			}
		"porco":
			var pink := Color(0.92, 0.66, 0.62)
			return {
				"body": [[Vector3(0, 0.44, 0), Vector3(0.44, 0.38, 0.76), pink], [Vector3(0, 0.5, -0.4), Vector3(0.05, 0.05, 0.05), pink.darkened(0.1)]],
				"head_at": Vector3(0, 0.48, 0.38),
				"head": [[Vector3(0, 0, 0.07), Vector3(0.3, 0.28, 0.24), pink], [Vector3(0, -0.03, 0.21), Vector3(0.14, 0.1, 0.06), pink.darkened(0.15)],
					[Vector3(-0.03, -0.03, 0.242), Vector3(0.025, 0.03, 0.01), Color(0.35, 0.2, 0.2)], [Vector3(0.03, -0.03, 0.242), Vector3(0.025, 0.03, 0.01), Color(0.35, 0.2, 0.2)],
					[Vector3(-0.1, 0.15, 0.08), Vector3(0.08, 0.08, 0.04), pink.darkened(0.05), Vector3(30, 0, 0)], [Vector3(0.1, 0.15, 0.08), Vector3(0.08, 0.08, 0.04), pink.darkened(0.05), Vector3(30, 0, 0)],
					[Vector3(-0.08, 0.05, 0.19), Vector3(0.02, 0.025, 0.02), Color.BLACK], [Vector3(0.08, 0.05, 0.19), Vector3(0.02, 0.025, 0.02), Color.BLACK]],
				"legs": _four(0.13, 0.26, 0.26, 0.26, 0.09, pink.darkened(0.05), Color(0.4, 0.3, 0.28)),
			}
		"pombo":
			return _bird(Color(0.55, 0.57, 0.62), Color(0.3, 0.45, 0.42), Color(0.3, 0.3, 0.32), Color(0.75, 0.35, 0.35), 1.0, 0.19, Color(0.95, 0.5, 0.15))
		"corvo":
			return _bird(Color(0.1, 0.1, 0.12), Color(0.12, 0.12, 0.16), Color(0.08, 0.08, 0.08), Color(0.12, 0.12, 0.12), 1.25, 0.24, Color(0.4, 0.35, 0.2))
		"pato":
			var s := _bird(Color(0.55, 0.45, 0.32), Color(0.1, 0.45, 0.2), Color(0.45, 0.38, 0.3), Color(0.92, 0.55, 0.15), 1.35, 0.24, Color.BLACK)
			s.head.append([Vector3(0, 0.01, 0.075), Vector3(0.05, 0.015, 0.06), Color(0.9, 0.8, 0.2)]) # bico chato
			s.body.append([Vector3(0, 0.17, 0.075), Vector3(0.07, 0.02, 0.06), Color(0.95, 0.95, 0.95)]) # coleira branca
			return s
		"gaivota":
			var s := _bird(Color(0.95, 0.95, 0.94), Color(0.95, 0.95, 0.94), Color(0.66, 0.69, 0.73), Color(0.9, 0.75, 0.2), 1.3, 0.34, Color(0.9, 0.75, 0.2))
			for w in s.wings:
				w[2].append([Vector3(w[1] * 0.3, 0, -0.02), Vector3(0.06, 0.021, 0.1), Color(0.1, 0.1, 0.1)]) # pontas pretas
			return s
	return spec("cervo")


## Quatro pernas: [x, z da frente, z de trás, y do quadril, comprimento, largura].
static func _four(x: float, z: float, hip: float, length: float, width: float, color: Color, hoof: Color) -> Array:
	var list := []
	for zz in [z, -z]:
		for xx in [-x, x]:
			list.append([Vector3(xx, hip, zz), length, width, color, hoof])
	return list


## Pássaro genérico: corpo, cabeça, rabo, 2 asas e 2 perninhas (escala = tamanho).
static func _bird(body_c: Color, head_c: Color, wing_c: Color, leg_c: Color, s: float, span: float, eye_c: Color) -> Dictionary:
	return {
		"body": [[Vector3(0, 0.12, 0) * s, Vector3(0.12, 0.11, 0.2) * s, body_c], [Vector3(0, 0.13, -0.14) * s, Vector3(0.08, 0.02, 0.1) * s, wing_c],
			[Vector3(0, 0.16, 0.07) * s, Vector3(0.07, 0.06, 0.06) * s, head_c]],
		"head_at": Vector3(0, 0.18, 0.08) * s,
		"head": [[Vector3(0, 0.02, 0.02) * s, Vector3(0.07, 0.07, 0.08) * s, head_c], [Vector3(0, 0.01, 0.07) * s, Vector3(0.02, 0.02, 0.05) * s, leg_c.darkened(0.2)],
			[Vector3(-0.036, 0.03, 0.03) * s, Vector3(0.01, 0.015, 0.015) * s, eye_c], [Vector3(0.036, 0.03, 0.03) * s, Vector3(0.01, 0.015, 0.015) * s, eye_c]],
		"legs": [[Vector3(-0.025, 0.07, 0) * s, 0.07 * s, 0.015 * s, leg_c, leg_c], [Vector3(0.025, 0.07, 0) * s, 0.07 * s, 0.015 * s, leg_c, leg_c]],
		"wings": [[Vector3(-0.05, 0.15, 0) * s, -1.0, [[Vector3(-span * 0.5, 0, -0.01), Vector3(span, 0.02, 0.12 * s), wing_c]]],
			[Vector3(0.05, 0.15, 0) * s, 1.0, [[Vector3(span * 0.5, 0, -0.01), Vector3(span, 0.02, 0.12 * s), wing_c]]]],
	}


## Malha (com cache) de uma lista de partes.
static func mesh(kind: String, part: String, parts: Array) -> ArrayMesh:
	var key := kind + "|" + part
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p: Array in parts:
		var basis := Basis.from_euler(p[3] * PI / 180.0) if p.size() > 3 else Basis()
		HumanoidRig._add_box(st, -1, Transform3D(basis, p[0]), p[1], p[2])
	var m := st.commit()
	m.surface_set_material(0, HumanoidRig._get_body_material())
	_cache[key] = m
	return m


## Monta o bicho dentro de "root". Devolve {head, legs: [], wings: [], wool}.
static func build(kind: String, root: Node3D) -> Dictionary:
	var s := spec(kind)
	var out := {"legs": [], "wings": [], "head": null, "wool": null}
	var body := MeshInstance3D.new()
	body.mesh = mesh(kind, "body", s.body)
	root.add_child(body)
	if s.has("wool"):
		var wool := MeshInstance3D.new()
		wool.name = "Wool"
		wool.mesh = mesh(kind, "wool", s.wool)
		root.add_child(wool)
		out.wool = wool
	var head := Node3D.new()
	head.name = "Head"
	head.position = s.head_at
	root.add_child(head)
	var head_mesh := MeshInstance3D.new()
	head_mesh.mesh = mesh(kind, "head", s.head)
	head.add_child(head_mesh)
	out.head = head
	for i in s.legs.size():
		var leg: Array = s.legs[i]
		var pivot := Node3D.new()
		pivot.position = leg[0]
		root.add_child(pivot)
		var lm := MeshInstance3D.new()
		lm.mesh = mesh(kind, "leg%d" % i, [[Vector3(0, -leg[1] * 0.5, 0), Vector3(leg[2], leg[1], leg[2]), leg[3]],
			[Vector3(0, -leg[1] + 0.02, 0.01), Vector3(leg[2] * 1.1, 0.04, leg[2] * 1.25), leg[4]]])
		pivot.add_child(lm)
		out.legs.append(pivot)
	for i in s.get("wings", []).size():
		var wing: Array = s.wings[i]
		var pivot := Node3D.new()
		pivot.position = wing[0]
		pivot.set_meta("side", wing[1])
		root.add_child(pivot)
		var wm := MeshInstance3D.new()
		wm.mesh = mesh(kind, "wing%d" % i, wing[2])
		pivot.add_child(wm)
		out.wings.append(pivot)
	return out
