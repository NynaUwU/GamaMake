extends SceneTree
## Menu de gráficos (ESC > Gráficos): predefinições (Clássico/Baixa/Média/Alta), opções
## soltas viram "Personalizado", e o que cada uma muda de verdade no mundo.

func _init() -> void:
	SaveGame.start_new()
	change_scene_to_file("res://scenes/main.tscn")
	for k in 30:
		await physics_frame
	var main := current_scene
	var keep := {}
	for key in Look.DEFAULTS:
		keep[key] = Look.get_setting(key)
	var pause: PauseMenu = main.get_node("PauseMenu")
	pause.open()
	await process_frame
	print("botão do ESC: '%s'" % pause._graphics_button.text)
	pause._graphics_button.pressed.emit()
	await process_frame
	var panel := pause._graphics
	print("menu aberto: %s, opções %d, principal escondido %s" % [panel.box.visible, panel._controls.size(), not pause._main_box.visible])
	var env: Environment = (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sun := main.get_node("Sun") as DirectionalLight3D
	var grass := main.get_node("Grass")
	var terrain: TerrainWorld = main.get_node("Terrain")
	var retro: Node = main.find_children("*", "CanvasLayer", true, false).filter(func(n): return n.is_in_group("look_screen"))[0]
	var mat: ShaderMaterial = terrain._material
	for k in Look.PRESET_ORDER.size():
		panel._preset.select(k)
		panel._preset.item_selected.emit(k)
		for f in 5:
			await process_frame
		print("%s: tonemap %s, glow %s, ssao %s, sombra %s (%.0f m), grama raio %.0f, textura PS2 %.1f, cores fortes %.0f" % [Look.preset_name(),
			["linear", "reinhard", "filmic", "aces", "agx"][env.tonemap_mode], env.glow_enabled, env.ssao_enabled, Look.shadows_on(),
			sun.directional_shadow_max_distance, grass._radius, mat.get_shader_parameter("detail_strength"), mat.get_shader_parameter("srgb_fix")])
	# Opções soltas.
	panel._preset.select(2)
	panel._preset.item_selected.emit(2)
	var lines: OptionButton = panel._controls["lines"]
	lines.select(3)
	lines.item_selected.emit(3)
	await process_frame
	print("resolução 3D da janela: escala %.2f; 540 linhas daria %.2f" % [get_root().scaling_3d_scale, 540.0 / get_root().size.y])
	(panel._controls["retro"] as CheckButton).button_pressed = false
	await process_frame
	print("filtro retrô desligado: níveis de cor %.0f, pontilhado %.1f" % [retro._effect.material.get_shader_parameter("color_levels"),
		retro._effect.material.get_shader_parameter("dither_strength")])
	var view: OptionButton = panel._controls["view"]
	view.select(2)
	view.item_selected.emit(2)
	await process_frame
	print("distância longa: terreno carrega até %.0f m" % terrain.view_distance)
	var fov: OptionButton = panel._controls["fov"]
	fov.select(3)
	fov.item_selected.emit(3)
	for f in 3:
		await physics_frame
		await process_frame
	print("campo de visão 95: câmera %.0f°" % main.player.camera.fov)
	(panel._controls["grid"] as CheckButton).button_pressed = true
	await process_frame
	print("grade do terreno: %.0f" % mat.get_shader_parameter("grid_lines"))
	(panel._controls["ssao"] as CheckButton).button_pressed = false
	await process_frame
	print("mexeu no SSAO: predefinição agora '%s' (botão '%s')" % [Look.preset_name(), panel._preset.get_item_text(panel._preset.selected)])
	var shadows: OptionButton = panel._controls["shadows"]
	shadows.select(0)
	shadows.item_selected.emit(0)
	for f in 3:
		await process_frame
	DayNight.i._apply()
	print("sombras desligadas: sol com sombra %s" % sun.shadow_enabled)
	var cfg := ConfigFile.new()
	cfg.load(Look.CONFIG)
	print("salvo em graphics.cfg: preset=%s lines=%s fov=%s grid=%s" % [cfg.get_value("video", "preset"), cfg.get_value("video", "lines"),
		cfg.get_value("video", "fov"), cfg.get_value("video", "grid")])
	panel.box.visible = false
	pause._show(pause._main_box)
	print("voltar: botão agora '%s'" % pause._graphics_button.text)
	# Devolve o que estava.
	for key in keep:
		Look._settings[key] = keep[key]
	Look._save_and_apply()
	quit()
