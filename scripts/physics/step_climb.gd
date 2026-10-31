class_name StepClimb
extends RefCounted
## Sobe degraus baixos (até a canela, ~0,42 m, um passo da grade) andando, sem pular: piso de
## construção, calçada, soleira de porta. Usado pelo jogador, zumbis e animais.
## Chamar logo antes do move_and_slide(). Devolve quanto subiu (0 = nada).

const HEIGHT := 0.42
const REACH := 0.45 ## > raio da cápsula (jogador/zumbi ~0,35-0,4)


static func step(body: CharacterBody3D, delta: float, height := HEIGHT) -> float:
	if not body.is_on_floor():
		return 0.0
	var horizontal := Vector3(body.velocity.x, 0.0, body.velocity.z)
	if horizontal.length() < 0.3:
		return 0.0
	# Olha um pouco à frente mesmo andando devagar.
	var motion := horizontal.normalized() * maxf(horizontal.length() * delta, 0.12)
	var xform := body.global_transform
	var hit := KinematicCollision3D.new()
	if not body.test_move(xform, motion, hit):
		return 0.0 # caminho livre
	if absf(hit.get_normal().y) > 0.7:
		return 0.0 # rampa/chão: o move_and_slide resolve
	var up := Vector3.UP * height
	if body.test_move(xform, up):
		return 0.0 # teto em cima
	var raised := xform.translated(up)
	# Por cima vai além do raio do corpo, para o fundo pousar no topo e não na quina.
	var over := horizontal.normalized() * REACH
	if body.test_move(raised, over):
		return 0.0 # mais alto que um degrau: é parede
	var down := KinematicCollision3D.new()
	if not body.test_move(raised.translated(over), -up, down):
		return 0.0 # buraco do outro lado
	if down.get_normal().y < 0.97: # topo plano; na quina (cápsula arredondada) seria alto demais
		return 0.0
	var rise := height - down.get_travel().length()
	if rise <= 0.03:
		return 0.0
	body.global_position.y += rise + 0.01
	return rise
