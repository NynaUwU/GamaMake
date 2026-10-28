class_name HumanoidRig
extends Skeleton3D
## Monta um esqueleto humanoide simples por código: ossos, visual em blocos,
## hitboxes (Area3D) e os ossos físicos do ragdoll (PhysicalBone3D).
##
## Serve como "boneco de teste" para o jogo rodar sem nenhum asset.
## Quando você tiver um modelo real (ex.: Mixamo), troque este nó pelo
## Skeleton3D importado e use "Create Physical Skeleton" no editor.
## O resto (Ragdoll, HitReaction, Zombie) continua funcionando igual.

const LAYER_HITBOX := 1 << 4

@export var skin_color := Color(0.45, 0.52, 0.4)
@export var shirt_color := Color(0.3, 0.25, 0.22)
@export var pants_color := Color(0.18, 0.2, 0.26)

# nome, pai, posição relativa ao pai, comprimento, direção (+1 cima / -1 baixo),
# largura, profundidade, massa, parte (define cor e multiplicador de dano)
const BONES := [
	["Hips", "", Vector3(0, 1.0, 0), 0.14, 1, 0.32, 0.2, 12.0, "pants"],
	["Spine", "Hips", Vector3(0, 0.14, 0), 0.22, 1, 0.28, 0.18, 8.0, "shirt"],
	["Chest", "Spine", Vector3(0, 0.22, 0), 0.26, 1, 0.38, 0.22, 14.0, "shirt"],
	["Head", "Chest", Vector3(0, 0.28, 0), 0.26, 1, 0.22, 0.24, 5.0, "skin"],
	["UpperArm.L", "Chest", Vector3(-0.26, 0.22, 0), 0.3, -1, 0.11, 0.11, 2.5, "shirt"],
	["LowerArm.L", "UpperArm.L", Vector3(0, -0.3, 0), 0.3, -1, 0.09, 0.09, 1.5, "skin"],
	["UpperArm.R", "Chest", Vector3(0.26, 0.22, 0), 0.3, -1, 0.11, 0.11, 2.5, "shirt"],
	["LowerArm.R", "UpperArm.R", Vector3(0, -0.3, 0), 0.3, -1, 0.09, 0.09, 1.5, "skin"],
	["UpperLeg.L", "Hips", Vector3(-0.1, -0.04, 0), 0.45, -1, 0.15, 0.15, 9.0, "pants"],
	["LowerLeg.L", "UpperLeg.L", Vector3(0, -0.45, 0), 0.47, -1, 0.12, 0.12, 4.5, "pants"],
	["UpperLeg.R", "Hips", Vector3(0.1, -0.04, 0), 0.45, -1, 0.15, 0.15, 9.0, "pants"],
	["LowerLeg.R", "UpperLeg.R", Vector3(0, -0.45, 0), 0.47, -1, 0.12, 0.12, 4.5, "pants"],
]

var _materials := {}


func _enter_tree() -> void:
	# Os ossos precisam existir antes dos filhos (Locomotion, HitReaction...) entrarem na árvore.
	if get_bone_count() == 0:
		for def in BONES:
			var idx := add_bone(def[0])
			if def[1] != "":
				set_bone_parent(idx, find_bone(def[1]))
			set_bone_rest(idx, Transform3D(Basis(), def[2]))
		reset_bone_poses()


func _ready() -> void:
	_materials = {
		"skin": _make_material(skin_color),
		"shirt": _make_material(shirt_color),
		"pants": _make_material(pants_color),
	}
	var enemy := owner if owner else get_parent()
	var simulator := get_node_or_null("PhysicalBoneSimulator3D") as PhysicalBoneSimulator3D
	for def in BONES:
		_build_bone_visual(def, enemy)
		if simulator:
			_build_physical_bone(def, simulator, enemy)
	if simulator and simulator.has_method("setup"):
		simulator.setup()


func _build_bone_visual(def: Array, enemy: Node) -> void:
	var bone_name: String = def[0]
	var length: float = def[3]
	var dir: float = def[4]
	var size := Vector3(def[5], length, def[6])
	var center := Vector3(0, dir * length * 0.5, 0)

	var attachment := BoneAttachment3D.new()
	attachment.name = "Att_" + bone_name
	attachment.bone_name = bone_name
	add_child(attachment)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _materials[def[8]]
	mesh.position = center
	attachment.add_child(mesh)

	if bone_name == "Head":
		_add_eyes(attachment, center, size)

	# Hitbox: é o que o golpe do player acerta enquanto o zumbi está de pé.
	var hitbox := Area3D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = LAYER_HITBOX
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	hitbox.set_meta("enemy", enemy)
	hitbox.set_meta("bone", StringName(bone_name))
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size * 1.1
	shape.shape = box_shape
	shape.position = center
	hitbox.add_child(shape)
	attachment.add_child(hitbox)


func _build_physical_bone(def: Array, simulator: PhysicalBoneSimulator3D, enemy: Node) -> void:
	var bone_name: String = def[0]
	var length: float = def[3]
	var dir: float = def[4]
	var width: float = def[5]
	var depth: float = def[6]

	var pb := PhysicalBone3D.new()
	pb.name = "PB_" + bone_name
	pb.set("bone_name", bone_name)
	pb.mass = def[7]
	pb.friction = 0.8
	pb.linear_damp = 0.1
	pb.angular_damp = 1.5
	# Corpo no meio do osso; a junta fica na origem do osso (encaixe com o pai).
	pb.body_offset = Transform3D(Basis(), Vector3(0, dir * length * 0.5, 0))
	pb.joint_offset = pb.body_offset.affine_inverse()
	pb.set_meta("enemy", enemy)
	pb.set_meta("bone", StringName(bone_name))

	var shape := CollisionShape3D.new()
	match bone_name:
		"Head":
			var sphere := SphereShape3D.new()
			sphere.radius = width * 0.55
			shape.shape = sphere
		"Hips", "Spine", "Chest":
			var box := BoxShape3D.new()
			box.size = Vector3(width, length, depth) * 0.95
			shape.shape = box
		_:
			var capsule := CapsuleShape3D.new()
			capsule.radius = width * 0.5
			capsule.height = max(length, width + 0.01)
			shape.shape = capsule
	pb.add_child(shape)

	_configure_joint(pb, bone_name, dir)
	simulator.add_child(pb)


func _configure_joint(pb: PhysicalBone3D, bone_name: String, dir: float) -> void:
	if bone_name == "Hips":
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
		return
	if bone_name.begins_with("Lower"):
		# Joelho e cotovelo: dobradiça no eixo X local do osso.
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
		pb.joint_rotation = Vector3(0, PI / 2, 0)
		pb.set("joint_constraints/angular_limit_enabled", true)
		if bone_name.begins_with("LowerLeg"):
			pb.set("joint_constraints/angular_limit_lower", -5.0)
			pb.set("joint_constraints/angular_limit_upper", 130.0)
		else:
			pb.set("joint_constraints/angular_limit_lower", -140.0)
			pb.set("joint_constraints/angular_limit_upper", 5.0)
		return
	# Coluna, cabeça, ombros e quadris: junta cônica (balança + torce).
	pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
	pb.joint_rotation = Vector3(0, 0, dir * PI / 2) # eixo de torção ao longo do osso
	var swing := 25.0
	var twist := 15.0
	if bone_name == "Head":
		swing = 40.0
		twist = 35.0
	elif bone_name.begins_with("UpperArm"):
		swing = 80.0
		twist = 45.0
	elif bone_name.begins_with("UpperLeg"):
		swing = 60.0
		twist = 20.0
	pb.set("joint_constraints/swing_span", swing)
	pb.set("joint_constraints/twist_span", twist)


func _add_eyes(attachment: Node3D, center: Vector3, size: Vector3) -> void:
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.85, 0.3)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.8, 0.2)
	eye_mat.emission_energy_multiplier = 1.5
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.04, 0.03, 0.02)
		eye.mesh = box
		eye.material_override = eye_mat
		eye.position = center + Vector3(side * 0.05, 0.03, -size.z * 0.5 - 0.005)
		attachment.add_child(eye)


func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	return mat
