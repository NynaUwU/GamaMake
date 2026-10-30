class_name Sfx
extends RefCounted
## Sons do jogo, todos SINTETIZADOS por código (sem arquivos de áudio): ruído
## filtrado, tons com envelope e uma "voz" com formantes para os zumbis. Cada
## som é gerado uma vez (na primeira vez que toca) e fica guardado.
##
## Uso: Sfx.play_at("hit", posição) (som 3D, cai com a distância) ou
## Sfx.play("pickup") (som de interface, sem posição). Loops (motor, vento,
## bumerangue) com Sfx.loop_player(nome, nó_pai).

const RATE := 22050
const MAX_PLAYERS := 40 ## sons 3D tocando ao mesmo tempo (os mais velhos são reaproveitados)

static var _streams := {}
static var _pool: Array[AudioStreamPlayer3D] = []
static var _ui: AudioStreamPlayer
static var _rng := RandomNumberGenerator.new()


## Som 3D num ponto do mundo. pitch_jitter: variação aleatória de tom (não repetitivo).
static func play_at(name: String, position: Vector3, volume_db := 0.0, pitch := 1.0, pitch_jitter := 0.08) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var player := _free_player(tree)
	player.stream = stream(name)
	player.global_position = position
	player.volume_db = volume_db + _VOLUME.get(name, 0.0)
	player.pitch_scale = maxf(pitch * (1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)), 0.05)
	player.play()


## Som sem posição (interface, coisas do próprio jogador).
static func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if not is_instance_valid(_ui):
		_ui = AudioStreamPlayer.new()
		_ui.max_polyphony = 6
		tree.root.add_child.call_deferred(_ui)
	if not _ui.is_inside_tree():
		await tree.process_frame
		if not is_instance_valid(_ui) or not _ui.is_inside_tree():
			return
	_ui.stream = stream(name)
	_ui.volume_db = volume_db + _VOLUME.get(name, 0.0)
	_ui.pitch_scale = pitch * (1.0 + _rng.randf_range(-0.05, 0.05))
	_ui.play()


## Player 3D em loop preso a um nó (motor de carro, bumerangue girando, vento).
static func loop_player(name: String, parent: Node, volume_db := 0.0) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream(name)
	player.volume_db = volume_db + _VOLUME.get(name, 0.0)
	player.max_distance = 45.0
	player.unit_size = 5.0
	parent.add_child(player)
	return player


static func _free_player(tree: SceneTree) -> AudioStreamPlayer3D:
	_pool = _pool.filter(func(p): return is_instance_valid(p) and p.is_inside_tree())
	for player in _pool:
		if not player.playing:
			return player
	if _pool.size() >= MAX_PLAYERS:
		var oldest: AudioStreamPlayer3D = _pool.pop_front()
		_pool.append(oldest)
		return oldest
	var player := AudioStreamPlayer3D.new()
	player.max_distance = 40.0
	player.unit_size = 4.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	tree.current_scene.add_child(player)
	_pool.append(player)
	return player


# --- Síntese --------------------------------------------------------------------

## Ajuste de volume por som (dB).
const _VOLUME := {"groan": -4.0, "growl": -2.0, "step_soft": -14.0, "step_hard": -10.0, "engine": -6.0,
	"wind": -20.0, "whirr": -8.0, "swing": -6.0, "pickup": -8.0, "explosion": 4.0, "shot": 2.0}


static func stream(name: String) -> AudioStreamWAV:
	if not _streams.has(name):
		_streams[name] = _make(name)
	return _streams[name]


static func _make(name: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	match name:
		"swing": # chicotada de ar: ruído com filtro subindo e descendo
			return _wav(_sweep_noise(rng, 0.22, 600.0, 3000.0, 0.04))
		"hit": # pancada na carne: ruído grave + baque
			return _wav(_mix([_noise_env(rng, 0.12, 900.0, 0.002, 0.08), _tone(0.16, 95.0, 55.0, 0.002, 0.12, 0.8)]))
		"slice": # corte: chiado agudo curto + pancada leve
			return _wav(_mix([_noise_env(rng, 0.09, 5000.0, 0.001, 0.05, 1500.0), _tone(0.12, 110.0, 70.0, 0.002, 0.08, 0.5)]))
		"thud": # corpo caindo
			return _wav(_mix([_tone(0.35, 70.0, 45.0, 0.003, 0.25, 0.9), _noise_env(rng, 0.25, 350.0, 0.003, 0.18)]))
		"shot": # tiro: estalo forte e estrondo
			return _wav(_mix([_noise_env(rng, 0.06, 9000.0, 0.0005, 0.03), _noise_env(rng, 0.5, 700.0, 0.002, 0.3), _tone(0.3, 80.0, 40.0, 0.001, 0.2, 0.7)]))
		"explosion":
			return _wav(_mix([_noise_env(rng, 1.4, 260.0, 0.005, 1.0), _tone(1.0, 55.0, 28.0, 0.01, 0.8, 0.9), _noise_env(rng, 0.2, 3000.0, 0.001, 0.12)]))
		"step_soft": # passo na grama/areia
			return _wav(_noise_env(rng, 0.07, 650.0, 0.004, 0.05))
		"step_hard": # passo em madeira/pedra
			return _wav(_mix([_noise_env(rng, 0.05, 2500.0, 0.001, 0.03, 600.0), _tone(0.08, 260.0, 200.0, 0.001, 0.05, 0.5)]))
		"groan": # gemido de zumbi: "voz" grossa com vibrato e formantes
			return _wav(_voice(rng, 1.3, 92.0, 0.25, [520.0, 1150.0]))
		"growl": # rosnado antes de atacar
			return _wav(_voice(rng, 0.6, 70.0, 0.9, [450.0, 900.0]))
		"death": # último gemido
			return _wav(_voice(rng, 1.0, 85.0, 0.4, [480.0, 950.0], true))
		"engine": # motor em loop: dentes de serra graves (o tom muda com a velocidade)
			return _wav(_engine(rng), true)
		"creak": # porta rangendo
			return _wav(_creak(rng))
		"knock": # martelada na madeira
			return _wav(_mix([_tone(0.12, 190.0, 150.0, 0.001, 0.08, 0.9), _noise_env(rng, 0.04, 3000.0, 0.0005, 0.02, 800.0)]))
		"ping": # talhadeira: metal
			return _wav(_mix([_tone(0.35, 1850.0, 1840.0, 0.001, 0.25, 0.5), _tone(0.3, 2770.0, 2760.0, 0.001, 0.18, 0.3), _noise_env(rng, 0.03, 6000.0, 0.0005, 0.015)]))
		"pickup": # pegou item: dois bipes
			return _wav(_concat([_tone(0.05, 620.0, 620.0, 0.002, 0.04, 0.5), _tone(0.07, 930.0, 930.0, 0.002, 0.06, 0.5)]))
		"crunch": # mordida
			return _wav(_concat([_noise_env(rng, 0.05, 2200.0, 0.002, 0.04), _noise_env(rng, 0.04, 1800.0, 0.002, 0.03), _noise_env(rng, 0.06, 1500.0, 0.002, 0.05)]))
		"slap": # chinelada
			return _wav(_mix([_noise_env(rng, 0.06, 4000.0, 0.0005, 0.04, 900.0), _tone(0.08, 210.0, 160.0, 0.001, 0.05, 0.6)]))
		"whirr": # bumerangue girando (loop)
			return _wav(_whirr(rng), true)
		"wind": # vento ambiente (loop)
			return _wav(_wind(rng), true)
		"click":
			return _wav(_tone(0.03, 1400.0, 1300.0, 0.0005, 0.02, 0.4))
	return _wav(_tone(0.1, 440.0, 440.0, 0.01, 0.08, 0.3))


static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav


## Envelope: sobe em "attack" segundos e cai exponencialmente com meia-vida ~decay.
static func _env(t: float, attack: float, decay: float) -> float:
	if t < attack:
		return t / attack
	return exp(-(t - attack) / maxf(decay * 0.5, 0.0001))


## Ruído com passa-baixa (e passa-alta opcional) e envelope.
static func _noise_env(rng: RandomNumberGenerator, duration: float, lowpass: float, attack: float, decay: float, highpass := 0.0) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var a := 1.0 - exp(-TAU * lowpass / RATE)
	var b := 1.0 - exp(-TAU * highpass / RATE)
	var lp := 0.0
	var hp := 0.0
	for i in n:
		lp += (rng.randf_range(-1.0, 1.0) - lp) * a
		var s := lp
		if highpass > 0.0:
			hp += (lp - hp) * b
			s = lp - hp
		out[i] = s * _env(float(i) / RATE, attack, decay) * (2.0 if lowpass < 1500.0 else 1.0)
	return out


## Seno com o tom deslizando de f0 a f1.
static func _tone(duration: float, f0: float, f1: float, attack: float, decay: float, amp: float) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(f0, f1, t) / RATE
		out[i] = sin(phase) * amp * _env(float(i) / RATE, attack, decay)
	return out


static func _sweep_noise(rng: RandomNumberGenerator, duration: float, f_low: float, f_high: float, attack: float) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var hp := 0.0
	for i in n:
		var t := float(i) / n
		var cutoff := lerpf(f_low, f_high, sin(t * PI))
		lp += (rng.randf_range(-1.0, 1.0) - lp) * (1.0 - exp(-TAU * cutoff / RATE))
		hp += (lp - hp) * (1.0 - exp(-TAU * cutoff * 0.3 / RATE))
		out[i] = (lp - hp) * 2.5 * sin(t * PI) * minf(t / attack * duration, 1.0)
	return out


## "Voz": dente de serra com vibrato, passando por dois filtros de formante.
static func _voice(rng: RandomNumberGenerator, duration: float, f0: float, roughness: float, formants: Array, falling := false) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var filters := []
	for f in formants:
		filters.append(_bandpass_coeffs(f, 4.0))
	var states := [[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0]]
	var wobble := rng.randf() * TAU
	for i in n:
		var t := float(i) / n
		var pitch := f0 * (1.0 + 0.06 * sin(t * 18.0 + wobble) + 0.12 * sin(t * 3.0))
		if falling:
			pitch *= lerpf(1.1, 0.6, t)
		phase = fmod(phase + pitch / RATE, 1.0)
		var source := (phase * 2.0 - 1.0) + rng.randf_range(-1.0, 1.0) * roughness * 0.6
		var s := 0.0
		for k in filters.size():
			s += _biquad(source, filters[k], states[k])
		var env := sin(minf(t * 3.0, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.65, 1.0, t))
		out[i] = s * env * 1.6
	return out


static func _engine(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(RATE * 0.4) # 0,4 s com nº inteiro de ciclos de 50 Hz: loop sem estalo
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var saw := fmod(t * 50.0, 1.0) * 2.0 - 1.0
		var saw2 := fmod(t * 100.0, 1.0) * 2.0 - 1.0
		var chug := 0.7 + 0.3 * sin(t * TAU * 12.5) # explosões dos cilindros
		var s := (saw * 0.6 + saw2 * 0.3 + rng.randf_range(-1.0, 1.0) * 0.15) * chug
		lp += (s - lp) * 0.18
		out[i] = lp * 0.9
	return out


static func _creak(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(RATE * 0.7)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * (240.0 + 260.0 * t + rng.randf_range(-30.0, 30.0)) / RATE
		var stick := 0.5 + 0.5 * sin(t * 90.0) # vai e trava (rangido)
		out[i] = sin(phase) * stick * sin(t * PI) * 0.35
	return out


static func _whirr(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(RATE * 0.5)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.25
		out[i] = lp * (0.4 + 0.6 * absf(sin(t * TAU * 8.0))) * 1.2 # "vum-vum" 16x por segundo
	return out


static func _wind(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := RATE * 3
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.02
		out[i] = lp * (0.6 + 0.4 * sin(t * TAU)) * 3.0 # sobe e desce (o loop fecha no mesmo ponto)
	return out


static func _mix(parts: Array) -> PackedFloat32Array:
	var length := 0
	for p: PackedFloat32Array in parts:
		length = maxi(length, p.size())
	var out := PackedFloat32Array()
	out.resize(length)
	for p: PackedFloat32Array in parts:
		for i in p.size():
			out[i] += p[i]
	return out


static func _concat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p: PackedFloat32Array in parts:
		out.append_array(p)
	return out


## Passa-faixa (biquad RBJ): [b0, b1, b2, a1, a2].
static func _bandpass_coeffs(freq: float, q: float) -> Array:
	var w := TAU * freq / RATE
	var alpha := sin(w) / (2.0 * q)
	var a0 := 1.0 + alpha
	return [alpha / a0, 0.0, -alpha / a0, -2.0 * cos(w) / a0, (1.0 - alpha) / a0]


static func _biquad(x: float, c: Array, s: Array) -> float:
	var y: float = c[0] * x + c[1] * s[0] + c[2] * s[1] - c[3] * s[2] - c[4] * s[3]
	s[1] = s[0]
	s[0] = x
	s[3] = s[2]
	s[2] = y
	return y
