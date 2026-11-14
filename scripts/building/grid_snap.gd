class_name GridSnap
extends RefCounted
## Grade de 0,4 m (a mesma das paredes, BuildPiece.SEG, começando em 0,0 do mundo) para
## tudo o que se põe: objetos no chão/parede e os trechos de cano e eixo. Canos e eixos só
## andam nas 6 direções da grade (±X, ±Y, ±Z): curvas só de 90°, em passos de 0,4 m.

const STEP := 0.4


## Ponto na grade em x e z (y fica: o chão não é plano).
static func flat(p: Vector3) -> Vector3:
	return Vector3(snappedf(p.x, STEP), p.y, snappedf(p.z, STEP))


## Ponto numa superfície (parede, teto): só as duas direções ao longo dela vão para a grade.
static func on_surface(p: Vector3, normal: Vector3) -> Vector3:
	var n := normal.abs()
	var out := p
	if n.x < 0.7:
		out.x = snappedf(p.x, STEP)
	if n.y < 0.7:
		out.y = snappedf(p.y, STEP)
	if n.z < 0.7:
		out.z = snappedf(p.z, STEP)
	return out


## Fim do trecho reto que sai de "a" seguindo a mira (raio origin + s*dir): escolhe o eixo da
## grade (X, Y ou Z) que passa mais perto do raio, com o comprimento em passos de 0,4 m
## (de 0,4 até max_len). "allow_vertical" = false: só X e Z (no nível do começo).
## Devolve {"end", "axis", "len"} ou {} se a mira não indica nenhum.
static func segment(a: Vector3, origin: Vector3, dir: Vector3, max_len: float, allow_vertical := true) -> Dictionary:
	var best := {}
	var best_d := INF
	var axes := [Vector3.RIGHT, Vector3.BACK]
	if allow_vertical:
		axes.append(Vector3.UP)
	for u: Vector3 in axes:
		var w0 := origin - a
		var b := dir.dot(u)
		var denom := 1.0 - b * b # dir e u unitários
		if denom < 0.02:
			continue # mira quase paralela a esse eixo: o outro decide
		var s := (b * u.dot(w0) - dir.dot(w0)) / denom
		var t := (u.dot(w0) - b * dir.dot(w0)) / denom
		if s <= 0.0:
			continue
		var gap := (origin + dir * s).distance_to(a + u * t)
		if gap < best_d and absf(t) > 0.05:
			best_d = gap
			var length := clampf(snappedf(absf(t), STEP), STEP, max_len)
			var axis := u * signf(t)
			best = {"end": a + axis * length, "axis": axis, "len": length}
	return best


## O ponto "p" está numa das linhas da grade que saem de "a"? (encaixe numa porta alinhada)
static func on_axis(a: Vector3, p: Vector3, tolerance := 0.08) -> bool:
	var d := (p - a).abs()
	var off := 0
	for k in 3:
		if d[k] > tolerance:
			off += 1
	return off == 1
