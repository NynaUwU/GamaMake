extends SceneTree
## Gera todos os sons do Sfx e confere tamanho/volume (sem tocar).
func _init() -> void:
	for name in ["swing","hit","slice","thud","shot","explosion","step_soft","step_hard","groan","growl","death","engine","creak","knock","ping","pickup","crunch","slap","whirr","wind","click"]:
		var t := Time.get_ticks_msec()
		var s: AudioStreamWAV = Sfx.stream(name)
		var peak := 0
		var d := s.data
		for i in range(0, d.size(), 2):
			peak = maxi(peak, absi(d.decode_s16(i)))
		print("%-10s %.2fs pico=%5d loop=%s %dms" % [name, s.get_length(), peak, s.loop_mode != 0, Time.get_ticks_msec() - t])
	quit()
