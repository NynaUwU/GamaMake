class_name ZombieSpecial
extends Node
## Zumbis especiais (inspirados nos "infectados especiais" dos jogos de horda, com
## nomes e regras próprios). O zumbi especial ganha este nó como filho; o Zombie
## chama os ganchos (idle/chase/on_hit/on_death) e este nó decide o resto.
##
##   inchado      gordo e lento. Perto de você vomita bile; morto, estoura. Bile na
##                cara = tela verde, os zumbis a 40 m vêm atrás de você e chega mais gente.
##   saltador     magro, braços compridos, curvado. De 4 a 14 m dá um bote e cai em cima.
##   brutamontes  enorme, braço gigante. Investida em linha reta: arremessa quem
##                acertar e arrebenta parede de construção (fica tonto depois).
##   cuspidor     fica longe e cospe ácido: poça que queima por alguns segundos.
##
## O corpo é deformado de verdade (HumanoidRig.part_mods: blocos esticados, inchados,
## tortos) + blocos a mais (pústulas, osso saindo, papo de ácido...).
##
## Online: o host roda tudo; as cópias recebem o visual pelo spawn_data (variant) e os
## efeitos (estouro, cuspe, grito...) pelo evento "special".

const KINDS := ["inchado", "saltador", "brutamontes", "cuspidor"]
const NAMES := {"inchado": "Inchado", "saltador": "Saltador", "brutamontes": "Brutamontes", "cuspidor": "Cuspidor"}
const BILE := Color(0.5, 0.62, 0.12)
const BILE_TIME := 7.0
const BILE_RADIUS := 4.5

var zombie: Zombie
var kind := ""
var _cd := 2.0 # recarga do poder
var _phase := 0 # 0 normal, 1 preparando, 2 em ação
var _phase_time := 0.0
var _dir := Vector3.ZERO
var _hit_done := false
var _strafe := 1.0

static var _extra_cache := {}


# --- Sorteio e corpo ----------------------------------------------------------------

## Sorteia se o zumbi que vai nascer é especial ("" = comum). where: open, city, horde, night.
static func roll(where: String) -> String:
	var day: int = DayNight.i.day if DayNight.i else 1
	var chance := 0.05
	match where:
		"night":
			chance = minf(0.05 + 0.012 * day, 0.16)
		"horde":
			chance = 0.07
		"city":
			chance = 0.06
	if randf() >= chance * WorldSettings.mult("specials"):
		return ""
	var weights := {"inchado": 3.0, "saltador": 3.0, "cuspidor": 2.0, "brutamontes": 0.6}
	if where in ["night", "horde"]:
		weights.brutamontes = 0.4 + minf(day * 0.1, 1.2)
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := randf() * total
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			return k
	return "inchado"


## Antes do esqueleto montar a malha (Zombie._enter_tree): cores, deformação, vida, velocidade.
static func setup_body(z: Zombie, kind_: String) -> void:
	var rig := z.get_node("Skeleton3D") as HumanoidRig
	var loco := z.get_node("Skeleton3D/Locomotion") as ZombieLocomotion
	z.weapon_chance = 0.0
	rig.look_key = kind_
	rig.part_mods = _deform(kind_)
	match kind_:
		"inchado":
			_colors(rig, Color(0.62, 0.64, 0.36), Color(0.5, 0.47, 0.37), Color(0.27, 0.23, 0.19))
			z.max_health = 50.0
			z.move_speed = 1.0
			z.attack_damage = 8.0
			loco.hunch = 0.05 # a barriga puxa para trás
			loco.stride_angle = 0.28 # passinho curto
		"saltador":
			_colors(rig, Color(0.46, 0.5, 0.44), Color(0.13, 0.14, 0.17), Color(0.2, 0.22, 0.28))
			z.max_health = 110.0
			z.move_speed = 2.4
			z.attack_damage = 7.0
			z.attack_cooldown = 0.55
			loco.hunch = 0.85 # quase de quatro
		"brutamontes":
			_colors(rig, Color(0.42, 0.45, 0.36), Color(0.36, 0.2, 0.16), Color(0.22, 0.2, 0.18))
			z.max_health = 520.0
			z.move_speed = 1.3
			z.attack_damage = 28.0
			z.attack_range = 2.1
			z.balance_per_force = 0.004
			z.wall_power = 2
			z.stagger_resist = 55.0
			loco.hunch = 0.55
		"cuspidor":
			_colors(rig, Color(0.64, 0.6, 0.34), Color(0.4, 0.3, 0.42), Color(0.2, 0.2, 0.24))
			z.max_health = 80.0
			z.move_speed = 1.5
			loco.hunch = 0.4
	z.health = z.max_health


static func _colors(rig: HumanoidRig, skin: Color, shirt: Color, pants: Color) -> void:
	rig.skin_color = skin
	rig.shirt_color = shirt
	rig.pants_color = pants


## Deformação do corpo: {osso: [escala (largura, comprimento, fundura), rotação (graus), deslocamento]}.
static func _deform(kind_: String) -> Dictionary:
	var V := Vector3.ONE
	match kind_:
		"inchado":
			# Tronco virou um barril, pernas e braços curtos e grossos, cabeça pequena afundada.
			return {
				"Hips": [Vector3(1.7, 1.2, 1.7), Vector3.ZERO, Vector3(0, -0.02, -0.03)],
				"Spine": [Vector3(2.4, 1.5, 3.0), Vector3(-8, 0, 0), Vector3(0, -0.02, -0.12), "skin"],
				"Chest": [Vector3(1.9, 1.05, 2.2), Vector3(6, 0, 4), Vector3(0, -0.02, -0.05)],
				"Head": [Vector3(0.82, 0.78, 0.85), Vector3(10, 0, -12), Vector3(0.02, 0.0, -0.16)],
				"UpperArm.L": [Vector3(1.9, 0.75, 1.9), Vector3(0, 0, -18), Vector3(-0.16, 0, 0)],
				"LowerArm.L": [Vector3(1.6, 0.7, 1.6), Vector3.ZERO, Vector3(-0.17, 0, 0)],
				"UpperArm.R": [Vector3(1.9, 0.75, 1.9), Vector3(0, 0, 18), Vector3(0.16, 0, 0)],
				"LowerArm.R": [Vector3(1.6, 0.7, 1.6), Vector3.ZERO, Vector3(0.17, 0, 0)],
				"UpperLeg.L": [Vector3(1.8, 0.95, 1.8), Vector3.ZERO, Vector3(-0.03, 0, 0)],
				"UpperLeg.R": [Vector3(1.8, 0.95, 1.8), Vector3.ZERO, Vector3(0.03, 0, 0)],
				"LowerLeg.L": [Vector3(1.6, 1.0, 1.6), Vector3.ZERO, Vector3.ZERO],
				"LowerLeg.R": [Vector3(1.6, 1.0, 1.6), Vector3.ZERO, Vector3.ZERO],
			}
		"saltador":
			# Esticado e magro: braços até o chão, pescoço para frente, cabeça torta.
			return {
				"Spine": [Vector3(0.75, 1.1, 0.8), Vector3.ZERO, Vector3.ZERO],
				"Chest": [Vector3(0.8, 1.05, 0.75), Vector3.ZERO, Vector3.ZERO],
				"Head": [Vector3(0.85, 1.15, 1.1), Vector3(25, 0, 18), Vector3(0, -0.02, -0.1)],
				"UpperArm.L": [Vector3(0.7, 1.45, 0.7), Vector3.ZERO, Vector3.ZERO],
				"LowerArm.L": [Vector3(0.7, 1.6, 0.7), Vector3.ZERO, Vector3(0, -0.13, 0)],
				"UpperArm.R": [Vector3(0.7, 1.45, 0.7), Vector3.ZERO, Vector3.ZERO],
				"LowerArm.R": [Vector3(0.7, 1.6, 0.7), Vector3.ZERO, Vector3(0, -0.13, 0)],
				"UpperLeg.L": [Vector3(0.75, 1.0, 0.75), Vector3.ZERO, Vector3.ZERO],
				"UpperLeg.R": [Vector3(0.75, 1.0, 0.75), Vector3.ZERO, Vector3.ZERO],
				"LowerLeg.L": [Vector3(0.7, 1.0, 0.7), Vector3.ZERO, Vector3.ZERO],
				"LowerLeg.R": [Vector3(0.7, 1.0, 0.7), Vector3.ZERO, Vector3.ZERO],
			}
		"brutamontes":
			# Montanha de músculo torta: braço direito gigante, esquerdo atrofiado, cabeça minúscula
			# enterrada nos ombros.
			return {
				"Hips": [Vector3(1.5, 1.1, 1.5), Vector3.ZERO, Vector3.ZERO],
				"Spine": [Vector3(1.8, 1.2, 1.7), Vector3(0, 0, -5), Vector3.ZERO],
				"Chest": [Vector3(2.2, 1.3, 2.0), Vector3(0, 0, -8), Vector3(0.04, 0.02, 0.02)],
				"Head": [Vector3(0.72, 0.68, 0.75), Vector3(0, 0, 10), Vector3(-0.03, -0.06, -0.14)],
				"UpperArm.R": [Vector3(2.6, 1.3, 2.6), Vector3(0, 0, 12), Vector3(0.12, 0.02, 0)],
				"LowerArm.R": [Vector3(3.2, 1.35, 3.2), Vector3.ZERO, Vector3(0.1, -0.05, 0)],
				"UpperArm.L": [Vector3(0.8, 0.85, 0.8), Vector3(0, 0, -6), Vector3(-0.04, 0, 0)],
				"LowerArm.L": [Vector3(0.7, 0.75, 0.7), Vector3.ZERO, Vector3(-0.04, 0.02, 0)],
				"UpperLeg.L": [Vector3(1.6, 1.0, 1.6), Vector3.ZERO, Vector3(-0.04, 0, 0)],
				"UpperLeg.R": [Vector3(1.7, 1.0, 1.7), Vector3.ZERO, Vector3(0.04, 0, 0)],
				"LowerLeg.L": [Vector3(1.4, 1.0, 1.4), Vector3.ZERO, Vector3.ZERO],
				"LowerLeg.R": [Vector3(1.5, 1.0, 1.5), Vector3.ZERO, Vector3.ZERO],
			}
		"cuspidor":
			# Pescoço esticado (cabeça lá em cima e para frente), mandíbula pendurada, corpo seco.
			return {
				"Spine": [Vector3(0.75, 1.0, 0.7), Vector3.ZERO, Vector3.ZERO],
				"Chest": [Vector3(0.8, 1.0, 0.75), Vector3(0, 0, 6), Vector3.ZERO],
				"Head": [Vector3(0.9, 1.25, 1.05), Vector3(-20, 0, 24), Vector3(0.05, 0.16, -0.1)],
				"UpperArm.L": [Vector3(0.65, 1.2, 0.65), Vector3.ZERO, Vector3.ZERO],
				"LowerArm.L": [Vector3(0.6, 1.25, 0.6), Vector3.ZERO, Vector3(0, -0.06, 0)],
				"UpperArm.R": [Vector3(0.65, 1.1, 0.65), Vector3.ZERO, Vector3.ZERO],
				"LowerArm.R": [Vector3(0.6, 1.15, 0.6), Vector3.ZERO, Vector3(0, -0.03, 0)],
				"UpperLeg.L": [Vector3(0.75, 1.0, 0.75), Vector3.ZERO, Vector3.ZERO],
				"UpperLeg.R": [Vector3(0.75, 1.0, 0.75), Vector3.ZERO, Vector3.ZERO],
			}
	return {}


## Blocos a mais presos nos ossos (pústulas, osso saindo, papo de ácido, capuz...).
## Uma malha por osso, com cor por vértice (mesmo material do corpo). Giram junto com
## a parte deformada (mesma rotação em volta da junta).
static func add_extras(z: Zombie, kind_: String) -> void:
	var rig := z.get_node("Skeleton3D") as HumanoidRig
	var parts := _extra_parts(kind_, rig)
	for bone: String in parts:
		var key := kind_ + "|" + bone
		if not _extra_cache.has(key):
			var bend := Basis()
			if rig.part_mods.has(bone):
				bend = Basis.from_euler(rig.part_mods[bone][1] * PI / 180.0)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for p: Array in parts[bone]:
				var local := Transform3D(Basis.from_euler(p[3] * PI / 180.0) if p.size() > 3 else Basis(), p[0])
				HumanoidRig._add_box(st, -1, Transform3D(bend, Vector3.ZERO) * local, p[1], p[2])
			var mesh := st.commit()
			mesh.surface_set_material(0, HumanoidRig._get_body_material())
			_extra_cache[key] = mesh
		var att := rig.get_node_or_null(HumanoidRig.attachment_name(bone)) as Node3D
		if att == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Extra"
		mi.mesh = _extra_cache[key]
		att.add_child(mi)


## {osso: [[centro, tamanho, cor, (rotação própria em graus)], ...]} no espaço do osso
## (frente = -Z), já contando o deslocamento da parte deformada.
static func _extra_parts(kind_: String, rig: HumanoidRig) -> Dictionary:
	var skin := rig.skin_color
	var shirt := rig.shirt_color
	var bone := Color(0.86, 0.82, 0.7)
	var flesh := Color(0.45, 0.08, 0.07)
	match kind_:
		"inchado":
			var boil := Color(0.86, 0.82, 0.38)
			var vein := skin.darkened(0.32)
			return {
				# Barriga: pústulas enormes, umbigo estourado, veias; camisa rasgada só no peito.
				"Spine": [[Vector3(0.17, 0.22, -0.41), Vector3(0.15, 0.15, 0.1), boil], [Vector3(-0.15, 0.07, -0.42), Vector3(0.18, 0.13, 0.1), boil],
					[Vector3(0.03, 0.0, -0.4), Vector3(0.1, 0.1, 0.04), flesh], [Vector3(-0.22, 0.25, -0.4), Vector3(0.09, 0.09, 0.08), boil],
					[Vector3(0.37, 0.12, -0.12), Vector3(0.1, 0.16, 0.15), boil], [Vector3(-0.37, 0.03, -0.06), Vector3(0.1, 0.12, 0.13), boil],
					[Vector3(0.0, 0.14, -0.395), Vector3(0.4, 0.022, 0.02), vein, Vector3(0, 0, 20)],
					[Vector3(0.13, -0.0, -0.395), Vector3(0.022, 0.22, 0.02), vein, Vector3(0, 0, -15)],
					[Vector3(0.0, 0.25, 0.18), Vector3(0.13, 0.11, 0.08), boil]],
				"Chest": [[Vector3(0, 0.1, -0.05), Vector3(0.75, 0.18, 0.5), shirt], [Vector3(-0.2, 0.18, -0.31), Vector3(0.12, 0.12, 0.08), boil],
					[Vector3(0.24, 0.16, 0.21), Vector3(0.14, 0.12, 0.08), boil]],
				# Papada caindo sobre o peito, pústula na testa.
				"Head": [[Vector3(0.02, 0.0, -0.22), Vector3(0.24, 0.07, 0.12), skin.darkened(0.04)], [Vector3(0.06, 0.16, -0.27), Vector3(0.05, 0.05, 0.03), boil]],
				"UpperArm.L": [[Vector3(-0.27, -0.1, -0.04), Vector3(0.1, 0.1, 0.1), boil]],
				"UpperLeg.R": [[Vector3(0.1, -0.16, -0.15), Vector3(0.1, 0.12, 0.08), boil]],
			}
		"saltador":
			var tape := Color(0.78, 0.76, 0.7)
			var claw := Color(0.2, 0.18, 0.15)
			return {
				# Capuz rasgado (nuca e topo), boca rasgada; costelas no rasgo da blusa; vértebras.
				"Head": [[Vector3(0, 0.29, -0.09), Vector3(0.22, 0.04, 0.29), shirt], [Vector3(0, 0.14, 0.05), Vector3(0.22, 0.3, 0.04), shirt],
					[Vector3(0, 0.04, -0.24), Vector3(0.11, 0.05, 0.03), flesh]],
				"Chest": [[Vector3(0, 0.29, 0.07), Vector3(0.3, 0.08, 0.1), shirt], [Vector3(0.0, 0.16, -0.09), Vector3(0.16, 0.02, 0.02), bone],
					[Vector3(0.0, 0.1, -0.09), Vector3(0.18, 0.02, 0.02), bone], [Vector3(0.0, 0.04, -0.09), Vector3(0.16, 0.02, 0.02), bone]],
				"Spine": [[Vector3(0, 0.14, 0.085), Vector3(0.04, 0.04, 0.04), bone], [Vector3(0, 0.05, 0.085), Vector3(0.04, 0.04, 0.04), bone]],
				# Garras compridas saindo da mão e fita nos antebraços.
				"LowerArm.L": [[Vector3(0, -0.25, 0), Vector3(0.075, 0.05, 0.075), tape], [Vector3(0, -0.45, 0), Vector3(0.075, 0.05, 0.075), tape],
					[Vector3(-0.025, -0.76, -0.03), Vector3(0.022, 0.2, 0.022), claw, Vector3(-20, 0, 0)], [Vector3(0.025, -0.77, -0.03), Vector3(0.022, 0.22, 0.022), claw, Vector3(-20, 0, 0)]],
				"LowerArm.R": [[Vector3(0, -0.25, 0), Vector3(0.075, 0.05, 0.075), tape], [Vector3(0, -0.45, 0), Vector3(0.075, 0.05, 0.075), tape],
					[Vector3(-0.025, -0.76, -0.03), Vector3(0.022, 0.2, 0.022), claw, Vector3(-20, 0, 0)], [Vector3(0.025, -0.77, -0.03), Vector3(0.022, 0.22, 0.022), claw, Vector3(-20, 0, 0)]],
			}
		"brutamontes":
			var vein := skin.darkened(0.3)
			return {
				# Corcunda de músculo e ossos espetados nas costas; veia no peito.
				"Chest": [[Vector3(0.05, 0.38, 0.1), Vector3(0.7, 0.16, 0.36), skin], [Vector3(0.05, 0.47, 0.14), Vector3(0.36, 0.1, 0.24), skin.darkened(0.05)],
					[Vector3(-0.1, 0.38, 0.29), Vector3(0.05, 0.16, 0.05), bone, Vector3(-30, 0, 15)], [Vector3(0.1, 0.43, 0.3), Vector3(0.05, 0.2, 0.05), bone, Vector3(-35, 0, -10)],
					[Vector3(0.24, 0.32, 0.26), Vector3(0.04, 0.14, 0.04), bone, Vector3(-25, 0, -30)],
					[Vector3(0.04, 0.15, -0.205), Vector3(0.5, 0.03, 0.02), vein, Vector3(0, 0, 8)]],
				"Spine": [[Vector3(0, 0.12, 0), Vector3(0.52, 0.2, 0.33), shirt]],
				# Queixo para fora com dentes de baixo.
				"Head": [[Vector3(-0.03, -0.07, -0.19), Vector3(0.17, 0.05, 0.09), skin.darkened(0.1)],
					[Vector3(-0.07, -0.04, -0.24), Vector3(0.025, 0.04, 0.02), bone], [Vector3(0.01, -0.04, -0.24), Vector3(0.025, 0.04, 0.02), bone]],
				# Punho gigante, nós dos dedos em osso, veias.
				"LowerArm.R": [[Vector3(0.1, -0.56, 0), Vector3(0.42, 0.26, 0.42), skin.darkened(0.08)],
					[Vector3(0.0, -0.6, -0.22), Vector3(0.07, 0.06, 0.05), bone], [Vector3(0.1, -0.61, -0.22), Vector3(0.07, 0.06, 0.05), bone],
					[Vector3(0.2, -0.6, -0.22), Vector3(0.07, 0.06, 0.05), bone],
					[Vector3(0.04, -0.25, -0.15), Vector3(0.03, 0.3, 0.02), vein, Vector3(0, 0, 10)]],
				"UpperArm.R": [[Vector3(0.28, -0.06, 0.0), Vector3(0.12, 0.07, 0.08), bone, Vector3(0, 0, -50)],
					[Vector3(0.12, -0.2, -0.15), Vector3(0.03, 0.26, 0.02), vein, Vector3(0, 0, -12)]],
			}
		"cuspidor":
			var acid := Color(0.55, 0.92, 0.16)
			return {
				# Mandíbula aberta pendurada, língua comprida pingando ácido.
				"Head": [[Vector3(0.05, 0.14, -0.2), Vector3(0.17, 0.06, 0.16), skin.darkened(0.25)],
					[Vector3(0.05, 0.06, -0.27), Vector3(0.05, 0.22, 0.03), acid],
					[Vector3(0.1, 0.42, -0.235), Vector3(0.04, 0.05, 0.02), acid]],
				# Pescoço esticado ligando o peito à cabeça + papo de ácido brilhando.
				"Chest": [[Vector3(0.03, 0.36, -0.06), Vector3(0.1, 0.24, 0.1), skin.darkened(0.08), Vector3(-15, 0, 10)],
					[Vector3(0.0, 0.24, -0.12), Vector3(0.24, 0.16, 0.14), acid], [Vector3(0.0, 0.3, -0.19), Vector3(0.12, 0.08, 0.06), acid.lightened(0.2)]],
				"Spine": [[Vector3(0.06, 0.06, -0.07), Vector3(0.18, 0.12, 0.02), acid.darkened(0.25)], [Vector3(-0.06, 0.1, 0.07), Vector3(0.05, 0.05, 0.04), bone]],
				"Hips": [[Vector3(0.05, 0.02, -0.105), Vector3(0.12, 0.08, 0.02), acid.darkened(0.3)]],
			}
	return {}


# --- Ganchos chamados pelo Zombie (host) -----------------------------------------------

## Parado (sem ver ninguém). true = já cuidou do movimento.
func idle(_delta: float) -> bool:
	if _phase != 0:
		_phase = 0 # perdeu o alvo no meio do bote/investida
		zombie.locomotion.attack = 0.0
		zombie.pose_crouch = 0.0
	return false


## Perseguindo. true = já cuidou do movimento neste tick.
func chase(delta: float) -> bool:
	_cd -= delta
	var to_target := zombie._flat_to_target()
	match kind:
		"saltador":
			zombie.pose_crouch = 0.22 if _phase == 0 else zombie.pose_crouch
			return _chase_saltador(delta, to_target)
		"brutamontes":
			return _chase_brutamontes(delta, to_target)
		"cuspidor":
			return _chase_cuspidor(delta, to_target)
		"inchado":
			return _chase_inchado(delta, to_target)
	return false


func on_hit() -> void:
	if kind != "brutamontes" and _phase != 0:
		_phase = 0 # apanhou preparando o bote/cuspe: perde a vez
		_cd = maxf(_cd, 1.5)
		zombie.locomotion.attack = 0.0
		zombie.pose_crouch = 0.0


func on_death() -> void:
	_phase = 0
	zombie.locomotion.attack = 0.0
	match kind:
		"inchado":
			_burst()
		"cuspidor":
			AcidPuddle.spawn(zombie.get_parent(), zombie.global_position, 1.6, 5.0, true)
			zombie._rep("special", ["puddle", [zombie.global_position]])


# --- Saltador ------------------------------------------------------------------------

func _chase_saltador(delta: float, to_target: Vector3) -> bool:
	var d := to_target.length()
	match _phase:
		0:
			if _cd <= 0.0 and zombie.is_on_floor() and d > 4.5 and d < 14.0 and _clear_line():
				_phase = 1
				_phase_time = 0.0
				Sfx.play_at("growl", zombie.global_position + Vector3.UP, 2.0, 1.4)
				return true
			return false
		1: # agacha e mira
			_phase_time += delta
			zombie.pose_crouch = 0.45
			zombie._brake(delta)
			zombie._face(to_target, delta, 12.0)
			if _phase_time >= 0.5:
				_leap()
			return true
		_: # no ar
			_phase_time += delta
			zombie.locomotion.attack = 1.0
			zombie.pose_crouch = 0.0
			var t: Node3D = zombie.target
			if not _hit_done and is_instance_valid(t):
				var reach := (zombie.global_position + Vector3.UP * 0.8).distance_to(t.global_position + Vector3.UP * 0.9)
				if reach < 1.4:
					_hit_done = true
					var dir := Vector3(zombie.velocity.x, 0.0, zombie.velocity.z).normalized()
					if t.has_method("take_damage"):
						t.take_damage(22.0, dir, zombie)
					ZombieSpecial.effect(t, "knock", 4.0, dir)
					Sfx.play_at("hit", t.global_position + Vector3.UP, 3.0, 0.8)
					zombie.velocity.x *= 0.15
					zombie.velocity.z *= 0.15
			if (_phase_time > 0.2 and zombie.is_on_floor()) or _phase_time > 2.5:
				_phase = 0
				_cd = randf_range(3.5, 5.0)
				zombie.locomotion.attack = 0.0
				zombie._cooldown = 0.15 if _hit_done else 0.6
			return true


## Salto balístico até onde o alvo vai estar (pouco à frente dele).
func _leap() -> void:
	var t: Node3D = zombie.target
	var aim: Vector3 = t.global_position
	var tv = t.get("velocity")
	if tv is Vector3:
		aim += Vector3(tv.x, 0.0, tv.z) * 0.35
	var flat := Vector3(aim.x - zombie.global_position.x, 0.0, aim.z - zombie.global_position.z)
	var flight := clampf(flat.length() / 10.0, 0.6, 1.1)
	var g := zombie._gravity
	var vy := (aim.y - zombie.global_position.y + 0.5 * g * flight * flight) / flight
	zombie.velocity = flat / flight + Vector3.UP * clampf(vy, 3.5, 9.0)
	zombie.rotation.y = atan2(-flat.x, -flat.z)
	_phase = 2
	_phase_time = 0.0
	_hit_done = false
	fx_all("leap", [])


# --- Brutamontes ---------------------------------------------------------------------

const CHARGE_SPEED := 9.0


func _chase_brutamontes(delta: float, to_target: Vector3) -> bool:
	var d := to_target.length()
	match _phase:
		0:
			if _cd <= 0.0 and zombie.is_on_floor() and d > 5.0 and d < 22.0 and _clear_line(true):
				_phase = 1
				_phase_time = 0.0
				fx_all("roar", [])
				return true
			return false
		1: # urra e mira
			_phase_time += delta
			zombie._brake(delta)
			zombie._face(to_target, delta, 8.0)
			zombie.pose_crouch = 0.15
			if _phase_time >= 0.85:
				_dir = to_target.normalized()
				_phase = 2
				_phase_time = 0.0
				_hit_done = false
			return true
		_: # investida
			_phase_time += delta
			zombie.pose_crouch = 0.1
			zombie.locomotion.attack = 0.55
			zombie.velocity.x = _dir.x * CHARGE_SPEED
			zombie.velocity.z = _dir.z * CHARGE_SPEED
			zombie._face(_dir, delta, 20.0)
			_charge_bump()
			for p in _players():
				var off: Vector3 = p.global_position - zombie.global_position
				if absf(off.y) < 1.6 and Vector2(off.x, off.z).length() < 1.4:
					if p.has_method("take_damage"):
						p.take_damage(30.0, _dir, zombie)
					ZombieSpecial.effect(p, "knock", 11.0, _dir)
					Sfx.play_at("thud", p.global_position + Vector3.UP, 4.0, 0.7)
					_end_charge(0.0)
					return true
			var space := zombie.get_world_3d().direct_space_state
			var from := zombie.global_position + Vector3.UP * 1.0
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + _dir * 1.1, 1, [zombie.get_rid()]))
			if hit and hit.normal.y < 0.6:
				if Zombie.is_build(hit.collider):
					# Arrebenta a parede: abre um buraco de uma vez.
					var normal: Vector3 = hit.normal if hit.normal.dot(_dir) < 0.0 else -hit.normal
					zombie._wall = {"normal": normal, "direction": _dir}
					for k in 3:
						zombie._damage_wall()
					zombie._wall = {}
					Sfx.play_at("crunch", hit.position, 6.0, 0.5)
					_end_charge(1.0)
				else:
					Sfx.play_at("thud", hit.position, 5.0, 0.6)
					_end_charge(1.8) # árvore/pedra/carro: bate a cabeça
				return true
			if _phase_time > 2.2:
				_end_charge(0.0)
			return true


func _end_charge(stun_time: float) -> void:
	_phase = 0
	_cd = randf_range(6.0, 9.0)
	zombie.locomotion.attack = 0.0
	zombie.pose_crouch = 0.0
	zombie.velocity.x *= 0.2
	zombie.velocity.z *= 0.2
	if stun_time > 0.0:
		zombie.stun(stun_time)


## Zumbis na frente da investida são jogados para o lado.
func _charge_bump() -> void:
	for other in zombie.get_tree().get_nodes_in_group("enemy"):
		if other == zombie or not other.has_method("bumped"):
			continue
		var off: Vector3 = other.global_position - zombie.global_position
		off.y = 0.0
		if off.length() < 1.3 and off.normalized().dot(_dir) > 0.3:
			other.bumped((_dir + off.normalized()).normalized(), 2.5)


# --- Cuspidor ------------------------------------------------------------------------

func _chase_cuspidor(delta: float, to_target: Vector3) -> bool:
	var d := to_target.length()
	if _phase == 1:
		_phase_time += delta
		zombie._brake(delta)
		zombie._face(to_target, delta, 10.0)
		zombie.locomotion.attack = minf(_phase_time * 2.5, 1.0)
		if _phase_time >= 0.55:
			_spit()
			_phase = 0
			_cd = randf_range(6.0, 8.0)
			zombie.locomotion.attack = 0.0
		return true
	if _cd <= 0.0 and d > 4.0 and d < 20.0 and _clear_line():
		_phase = 1
		_phase_time = 0.0
		return true
	var desired := Vector3.ZERO
	if d < 7.0:
		desired = -to_target.normalized() * zombie.move_speed * 0.9 # perto demais: recua
	elif d < 13.0 and _cd > 0.0:
		if randf() < delta * 0.3:
			_strafe = -_strafe
		desired = to_target.normalized().cross(Vector3.UP) * _strafe * 0.9 # ronda de lado
	else:
		return false
	desired += zombie._separation() * 2.5
	zombie.velocity.x = lerpf(zombie.velocity.x, desired.x, 1.0 - exp(-5.0 * delta))
	zombie.velocity.z = lerpf(zombie.velocity.z, desired.z, 1.0 - exp(-5.0 * delta))
	zombie._face(to_target, delta, 6.0)
	return true


func _spit() -> void:
	var t: Node3D = zombie.target
	var aim: Vector3 = t.global_position
	var tv = t.get("velocity")
	if tv is Vector3:
		aim += Vector3(tv.x, 0.0, tv.z) * 0.6
	var space := zombie.get_world_3d().direct_space_state
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(aim + Vector3.UP * 2.0, aim + Vector3.DOWN * 4.0, 1))
	if down:
		aim = down.position
	var from := zombie.global_position + Vector3.UP * 1.6 - zombie.global_basis.z * 0.3
	fx_all("spit", [from, aim])


# --- Inchado -------------------------------------------------------------------------

func _chase_inchado(delta: float, to_target: Vector3) -> bool:
	var d := to_target.length()
	if _phase == 1:
		_phase_time += delta
		zombie._brake(delta)
		zombie._face(to_target, delta, 8.0)
		if _phase_time >= 0.45:
			_phase = 0
			_cd = randf_range(10.0, 14.0)
			var t: Node3D = zombie.target
			var facing := (-zombie.global_basis.z).dot(to_target.normalized())
			fx_all("vomit", [t.global_position + Vector3.UP * 1.2])
			if d < 4.2 and facing > 0.6:
				ZombieSpecial.bile(t, zombie)
		return true
	if _cd <= 0.0 and d < 3.4:
		_phase = 1
		_phase_time = 0.0
		return true
	return false


## Estouro: bile em quem estiver perto, empurra os zumbis em volta, corpo em pedaços.
func _burst() -> void:
	var center := zombie.global_position + Vector3.UP * 1.0
	fx_all("burst", [center])
	for p in _players():
		if p.global_position.distance_to(center) < BILE_RADIUS:
			ZombieSpecial.bile(p, zombie)
	for other in zombie.get_tree().get_nodes_in_group("enemy"):
		if other == zombie or not other.has_method("bumped"):
			continue
		var off: Vector3 = other.global_position - zombie.global_position
		off.y = 0.0
		if off.length() < 3.0:
			other.bumped(off.normalized(), 1.5)
	zombie._dismember_all(center, 260.0)


## Bile num jogador: tela verde e os zumbis por perto (e alguns de longe) vêm atrás dele.
static func bile(player: Node3D, from: Zombie) -> void:
	ZombieSpecial.effect(player, "bile", BILE_TIME, Vector3.ZERO)
	for other in from.get_tree().get_nodes_in_group("enemy"):
		if other is Zombie and other != from and other.state != Zombie.State.DEAD \
				and other.global_position.distance_to(player.global_position) < 40.0:
			other.alert(player)
	if HordeManager.i:
		HordeManager.i.call_mob(player, 5)


## Efeito num jogador (local ou boneco de outro): "bile" (segundos) ou "knock" (força).
static func effect(player: Node3D, what: String, value: float, direction: Vector3) -> void:
	if player and player.has_method("apply_special"):
		player.apply_special(what, value, direction)


# --- Utilidades ----------------------------------------------------------------------

func _players() -> Array:
	var list := []
	for group in [&"player", &"remote_player"]:
		for p in zombie.get_tree().get_nodes_in_group(group):
			if p.get("health") == null or p.health > 0.0:
				list.append(p)
	return list


## Nada no caminho entre o peito do zumbi e o alvo (builds = construção pode estar no meio).
func _clear_line(builds_ok := false) -> bool:
	var t: Node3D = zombie.target
	if not is_instance_valid(t):
		return false
	var from := zombie.global_position + Vector3.UP * 1.2
	var to := t.global_position + Vector3.UP * 1.0
	var exclude := [zombie.get_rid()]
	if t is CollisionObject3D:
		exclude.append(t.get_rid())
	var hit := zombie.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1, exclude))
	return hit.is_empty() or (builds_ok and Zombie.is_build(hit.collider))


# --- Efeitos (host e cópias) ---------------------------------------------------------

## Host: toca o efeito aqui e manda para as cópias.
func fx_all(what: String, args: Array) -> void:
	zombie._rep("special", [what, args])
	fx(what, args)


func fx(what: String, args: Array) -> void:
	var head := zombie.global_position + Vector3.UP * 1.6
	var world := zombie.get_parent()
	match what:
		"roar":
			Sfx.play_at("roar", head, 4.0, 0.9)
		"leap":
			Sfx.play_at("growl", head, 2.0, 1.5)
		"spit":
			Sfx.play_at("spit", head, 1.0, 1.0)
			AcidPuddle.launch(world, args[0], args[1], not zombie.puppet)
		"puddle":
			if zombie.puppet:
				AcidPuddle.spawn(world, args[0], 1.6, 5.0, false)
		"vomit":
			Sfx.play_at("retch", head, 2.0, 1.0)
			var dir: Vector3 = (args[0] - head).normalized()
			for k in 3:
				ImpactFX.burst(world, head + dir * 0.3, dir, BILE, 26, 6.0, 0.07, 6.0)
		"burst":
			Sfx.play_at("explosion", args[0], -6.0, 0.6)
			Sfx.play_at("retch", args[0], 0.0, 0.7)
			ImpactFX.burst(world, args[0], Vector3.UP, BILE, 70, 6.0, 0.1, 5.0)
			ImpactFX.burst(world, args[0], Vector3.UP, BILE.darkened(0.3), 40, 3.0, 0.16, 1.0)


## Cópia (cliente): pose de acordo com o estado que chega do host.
func puppet_tick() -> void:
	match kind:
		"saltador":
			zombie.pose_crouch = 0.22
