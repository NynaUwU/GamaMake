class_name Cheats
extends RefCounted
## Trapaças do menu de admin (ESC > Admin; só quem hospeda o mundo, inclusive no solo).
## Valem para o jogador daqui e só nesta sessão (não vão no save; recomeçar desliga).

static var god := false ## vida infinita: não toma dano e nada tira vida
static var stamina := false ## stamina infinita
static var needs := false ## sem fome, sede, frio, doença nem gás
static var ammo := false ## munição infinita (a arma de fogo não gasta)
## Criativo: construir e fabricar sem gastar material. (Chamava "free", mas free() é
## método de todo Object: em alguns scripts Cheats.free virava o método, sempre
## "verdadeiro", e tudo saía de graça.)
static var creative := false
static var invisible := false ## os zumbis não enxergam você
static var fast := false ## anda e corre 2x mais rápido

## [variável, nome no menu, explicação]
const TOGGLES := [
	["god", "Vida infinita", "Não toma dano; fome, frio e gás não matam"],
	["stamina", "Stamina infinita", "Corre sem cansar"],
	["needs", "Sem necessidades", "Fome, sede e calor sempre cheios; sem doença nem intoxicação"],
	["ammo", "Munição infinita", "Armas de fogo não gastam bala"],
	["free", "Criativo (grátis)", "Construir e fabricar sem gastar material"],
	["invisible", "Invisível", "Zumbis não veem você"],
	["fast", "Super velocidade", "Anda e corre 2x mais rápido"],
]


static func get_flag(name: String) -> bool:
	match name:
		"god":
			return god
		"stamina":
			return stamina
		"needs":
			return needs
		"ammo":
			return ammo
		"free":
			return creative
		"invisible":
			return invisible
		"fast":
			return fast
	return false


static func set_flag(name: String, on: bool) -> void:
	match name:
		"god":
			god = on
		"stamina":
			stamina = on
		"needs":
			needs = on
		"ammo":
			ammo = on
		"free":
			creative = on
		"invisible":
			invisible = on
		"fast":
			fast = on


static func reset() -> void:
	for t in TOGGLES:
		set_flag(t[0], false)


## Aplica as trapaças ligadas no jogador daqui (chamado todo quadro pelo Player).
static func apply(player: Player) -> void:
	if god and player.health < player.max_health:
		player.health = player.max_health
		player.health_changed.emit(player.health, player.max_health)
	if stamina and player.stamina < player.max_stamina:
		player.stamina = player.max_stamina
		player.stamina_changed.emit(player.stamina, player.max_stamina)
	if needs:
		if player.hunger < Player.MAX_HUNGER - 0.5:
			player.hunger = Player.MAX_HUNGER
			player.hunger_changed.emit(player.hunger, Player.MAX_HUNGER)
		if player.thirst < Player.MAX_THIRST - 0.5:
			player.thirst = Player.MAX_THIRST
			player.thirst_changed.emit(player.thirst, Player.MAX_THIRST)
		player.heat = Player.MAX_HEAT
		player.toxic = 0.0
		player.bile_time = 0.0
		if player.sick_time > 0.0:
			player.sick_time = 0.0
			player.sick_changed.emit(false)


## Enche tudo uma vez: vida, stamina, fome, sede, calor; cura doença, gás e bile.
static func fill(player: Player) -> void:
	player.health = player.max_health
	player.stamina = player.max_stamina
	player.hunger = Player.MAX_HUNGER
	player.thirst = Player.MAX_THIRST
	player.heat = Player.MAX_HEAT
	player.toxic = 0.0
	player.bile_time = 0.0
	player.sick_time = 0.0
	player.health_changed.emit(player.health, player.max_health)
	player.stamina_changed.emit(player.stamina, player.max_stamina)
	player.hunger_changed.emit(player.hunger, Player.MAX_HUNGER)
	player.thirst_changed.emit(player.thirst, Player.MAX_THIRST)
	player.sick_changed.emit(false)


## Desbloqueia tudo: lê todos os manuais, conta todas as estações como construídas (o
## diário mostra todas as receitas), marca as receitas como vistas e completa as
## conquistas (a era vai para a última).
static func unlock_all() -> void:
	var p := Progress.i
	if p == null:
		return
	for m in Progress.MANUALS:
		p.manuals[m] = true
		Progress.add_clue(Progress.MANUALS[m].clue)
	for r: Dictionary in CraftingUI.RECIPES:
		p.recipes[r.id] = true
	for section in RecipeBook.SECTIONS:
		for kind in section[2]:
			p.built[kind] = true
	var day: int = DayNight.i.day if DayNight.i else 1
	for a: String in Progress.ACHIEVEMENTS:
		if not p.done.has(a):
			p.done[a] = day
	p.era = p.current_era()
	for r: Dictionary in RecipeBook.visible():
		p.seen_recipes[r.key] = true # nada de 180 selos "NOVA" de uma vez
	p.changed.emit()


## Dá "amount" do item (o que não couber cai no chão).
static func give(player: Player, id: StringName, amount := -1) -> void:
	if amount < 0:
		amount = ItemDB.max_stack(id)
	var left := player.inventory.add(id, amount)
	if left > 0:
		Net.i.drop_item(id, left, player.global_transform.translated(Vector3.UP), Vector3.ZERO)
	Sfx.play("pickup", -6.0)


## Mata todos os zumbis vivos (host).
static func kill_zombies(main: Node) -> int:
	var count := 0
	var enemies := main.get_node_or_null("Enemies")
	if enemies == null:
		return 0
	for z in enemies.get_children():
		if z is Zombie and z.state != Zombie.State.DEAD:
			z.take_hit(HitInfo.make(99999.0, &"Chest", z.global_position + Vector3.UP, Vector3.DOWN, 1.0))
			count += 1
	return count


static func set_hour(hour: float) -> void:
	if DayNight.i:
		DayNight.i.hour = hour
		DayNight.i._apply()


static func set_rain(on: bool) -> void:
	if Weather.i:
		Weather.i.target_rain = 1.0 if on else 0.0
		Weather.i.rain = Weather.i.target_rain
		Weather.i._timer = 240.0 # segura assim por uns minutos antes do clima mudar sozinho
