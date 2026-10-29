extends SceneTree
## GOOD DOG F5 procedural audio generator (original work, MIT).
##   godot4 --headless --path . -s res://tools/audio/synth_f5.gd
##
## Every F5 sound except the F1 camera flash is synthesized here from oscillators,
## seeded noise, glottal-pulse/formant models, Karplus-Strong plucks and RBJ
## biquads: no recordings, samples, voice or speech synthesis. Deterministic
## (fixed seed per asset). Output: mono 16-bit 48 kHz PCM WAV under
## res://assets/audio/. Loops carry a RIFF `smpl` forward loop that Godot's WAV
## importer detects (edit/loop_mode = Detect From WAV). SHA-256, BS.1770 loudness
## and true peak of every file go to assets/audio/PROVENANCE.json.

const Loudness := preload("res://tools/audio/loudness.gd")
const SR := 48000
const OUT := "res://assets/audio/"
## Every file's 4x-oversampled true peak stays at or below this (GDD §10 −1 dBTP + margin).
const TRUE_PEAK_CEILING_DB := -1.5

enum { LP, HP, BP }

var rng := RandomNumberGenerator.new()
var manifest: Array = []
var _seed := 0


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	_barks()
	_praise()
	_stick()
	_footsteps()
	_leash()
	_fall()
	_finale()
	_ambience()
	_pressure()
	_events()
	_write_manifest()
	print("SYNTH_F5_DONE files=%d ms=%d" % [manifest.size(), Time.get_ticks_msec() - t0])
	quit(0)


# --- Assets -------------------------------------------------------------------

## GDD §10: five bark variants, human imitation → real dog (formant/source morph).
func _barks() -> void:
	var tiers := [
		# 0: a person imitating a bark: modal voice, /w/ lip glide into /ʌ/, /f/ tail.
		{dur = 0.34, f0 = [135.0, 170.0, 115.0], jitter = 0.008, shimmer = 0.05, sub = 0.0,
			breath = 0.12, drive = 1.2, attack = 0.03, rough = 0.0, body = [0.0, 0.0], fric = 0.09,
			formants = [[300, 640, 6.0, 1.0], [780, 1150, 8.0, 0.55], [2350, 2450, 12.0, 0.18]]},
		# 1: hoarse human throat bark: breathy, rough, harder onset.
		{dur = 0.30, f0 = [118.0, 150.0, 95.0], jitter = 0.035, shimmer = 0.18, sub = 0.1,
			breath = 0.42, drive = 2.2, attack = 0.015, rough = 0.35, body = [0.0, 0.0], fric = 0.0,
			formants = [[430, 720, 5.0, 1.0], [980, 1250, 7.0, 0.6], [2450, 2550, 10.0, 0.22]]},
		# 2: guttural, half human: period-doubled growl under a darker vowel.
		{dur = 0.27, f0 = [100.0, 128.0, 82.0], jitter = 0.05, shimmer = 0.22, sub = 0.55,
			breath = 0.32, drive = 3.2, attack = 0.010, rough = 0.5, body = [150.0, 0.25], fric = 0.0,
			formants = [[560, 820, 4.5, 1.0], [1250, 1480, 6.0, 0.7], [2600, 2700, 9.0, 0.3]]},
		# 3: deep animal bark: short, harsh, chest-heavy, canine formant spacing.
		{dur = 0.21, f0 = [165.0, 215.0, 135.0], jitter = 0.04, shimmer = 0.15, sub = 0.3,
			breath = 0.28, drive = 4.0, attack = 0.005, rough = 0.3, body = [180.0, 0.5], fric = 0.0,
			formants = [[640, 880, 4.0, 1.0], [1500, 1750, 5.5, 0.75], [2800, 2950, 8.0, 0.35]]},
		# 4: resonant dog bark: higher fundamental, bright formants, ringing body.
		{dur = 0.23, f0 = [235.0, 310.0, 190.0], jitter = 0.02, shimmer = 0.1, sub = 0.12,
			breath = 0.22, drive = 3.4, attack = 0.004, rough = 0.15, body = [240.0, 0.8], fric = 0.0,
			formants = [[760, 1020, 4.0, 1.0], [1700, 1950, 5.5, 0.8], [3100, 3300, 8.0, 0.4],
					[4100, 4200, 10.0, 0.18]]},
	]
	for i in tiers.size():
		_seed_with(5100 + i)
		_emit("sfx/bark/bark_step%d.wav" % i, _bark(tiers[i]), "Bark tier %d (GDD §10/§6)" % i, -14.0)


## GDD §10: same bell every time + warm pad + treat-bag rustle. Bell alone for the pit lure.
func _praise() -> void:
	_seed_with(5200)
	var bell := _bell(2.6, 1318.5)
	_emit("sfx/praise/praise_bell.wav", bell.duplicate(), "Conditioned praise bell (E6), pit lure every 6 s", -16.0)
	_seed_with(5201)
	var out := _zeros(2.9)
	_mix(out, bell, 0.0, 1.0)
	var pad := _pad(2.9, [261.63, 329.63, 392.0, 587.33], 0.22, 1.3, 1.4)
	_mix(out, pad, 0.0, 0.32)
	_mix(out, _crinkle(0.55, 140.0, 2600.0, 7500.0), 0.38, 0.22)
	_mix(out, _crinkle(0.35, 90.0, 2200.0, 6000.0), 1.05, 0.14)
	_emit("sfx/praise/good_dog_praise.wav", out, "GOOD DOG praise: bell + pad + treat rustle", -16.0)


## GDD §10: wet blunt sound on pickup and on placement.
func _stick() -> void:
	_seed_with(5300)
	var pick := _zeros(0.5)
	_mix(pick, _wet(0.22, 500.0, 1600.0), 0.0, 0.8)          # peel off the floor
	_mix(pick, _thump(0.2, 120.0, 70.0, 0.09), 0.02, 0.6)
	_mix(pick, _burst(0.08, LP, 650.0, 0.7, 0.002, 0.06), 0.02, 0.45)
	_mix(pick, _droplet(), 0.19, 0.18)
	_emit("sfx/stick/stick_pickup.wav", _hp(pick, 45.0), "Bloody stick pickup: wet peel + blunt thud", -16.0)
	_seed_with(5301)
	var place := _zeros(0.5)
	_mix(place, _thump(0.25, 105.0, 52.0, 0.14), 0.0, 1.0)
	_mix(place, _burst(0.1, LP, 600.0, 0.7, 0.001, 0.08), 0.0, 0.6)
	_mix(place, _burst(0.03, BP, 2300.0, 2.0, 0.0005, 0.018), 0.0, 0.25)  # tile knock
	_mix(place, _wet(0.16, 1700.0, 600.0), 0.012, 0.55)                 # squelch
	_mix(place, _droplet(), 0.23, 0.12)
	_emit("sfx/stick/stick_place.wav", _hp(place, 40.0), "Stick placed in circle: wet thud on tile", -16.0)


## GDD §6/§10: shoes → bare feet → claws on tile, four round-robin variants each.
func _footsteps() -> void:
	for v in 4:
		_seed_with(5400 + v)
		var shoe := _zeros(0.22)
		var heel_at := 0.0
		_mix(shoe, _burst(0.012, BP, rng.randf_range(3000, 4200), 1.4, 0.0003, 0.008), heel_at, 0.55)
		_mix(shoe, _thump(0.06, 150.0, 85.0, 0.035), heel_at, 0.7)
		_mix(shoe, _burst(0.04, LP, 520.0, 0.7, 0.001, 0.03), heel_at, 0.5)
		var toe_at := rng.randf_range(0.055, 0.075)
		_mix(shoe, _burst(0.01, BP, rng.randf_range(2200, 2900), 1.5, 0.0004, 0.007), toe_at, 0.3)
		_mix(shoe, _burst(0.05, BP, 1200.0, 0.9, 0.004, 0.04), toe_at, 0.18)  # rubber scuff
		_emit("sfx/footsteps/shoes_%d.wav" % v, _hp(shoe, 60.0), "Leather/rubber sole on tile %d" % v, -20.0)
	for v in 4:
		_seed_with(5410 + v)
		var bare := _zeros(0.2)
		_mix(bare, _burst(0.04, BP, rng.randf_range(950, 1300), 0.9, 0.0015, 0.022), 0.0, 0.8)
		_mix(bare, _burst(0.006, HP, 2200.0, 0.7, 0.0003, 0.004), 0.0, 0.25)  # skin smack
		_mix(bare, _thump(0.05, 100.0, 70.0, 0.03), 0.0, 0.5)
		_mix(bare, _burst(0.03, BP, rng.randf_range(800, 1100), 1.0, 0.002, 0.018), rng.randf_range(0.035, 0.05), 0.35)
		_emit("sfx/footsteps/barefoot_%d.wav" % v, _hp(bare, 60.0), "Bare foot slap on tile %d" % v, -20.0)
	for v in 4:
		_seed_with(5420 + v)
		var shuffle := _zeros(0.26)
		var drag := _burst(0.14, BP, 0.0, 1.1, 0.03, 0.1, func(t: float) -> float: return lerpf(850.0, 1450.0, t / 0.14))
		_mix(shuffle, drag, 0.0, 0.22)
		_mix(shuffle, _burst(0.04, BP, rng.randf_range(950, 1250), 0.9, 0.0015, 0.022), 0.07, 0.75)
		_mix(shuffle, _thump(0.05, 95.0, 68.0, 0.03), 0.07, 0.45)
		_emit("sfx/footsteps/shuffle_%d.wav" % v, _hp(shuffle, 60.0), "Bare foot shuffle-slap %d" % v, -20.0)
	for v in 4:
		_seed_with(5430 + v)
		var claw := _zeros(0.16)
		_mix(claw, _thump(0.04, 120.0, 75.0, 0.02), 0.0, 0.3)  # soft pad
		var t := 0.004
		for c in rng.randi_range(3, 4):
			_mix(claw, _burst(0.002, HP, 3200.0, 0.7, 0.0001, 0.0012), t, rng.randf_range(0.5, 0.9))
			_mix(claw, _ping(0.02, rng.randf_range(4300, 6600), 0.007), t, rng.randf_range(0.25, 0.45))
			t += rng.randf_range(0.012, 0.028)
		_mix(claw, _burst(0.04, BP, 5200.0, 2.0, 0.003, 0.03), t, 0.18)  # scrape
		_emit("sfx/footsteps/claws_%d.wav" % v, _hp(claw, 80.0), "Claws clicking/scraping on tile %d" % v, -20.0)


## GDD §7/§10: chain clink + leather strain on each outward pull.
func _leash() -> void:
	_seed_with(5500)
	var out := _zeros(0.9)
	var t := 0.0
	for link in 6:
		var base := rng.randf_range(2300, 3400)
		var amp := rng.randf_range(0.4, 1.0) * (1.0 - link * 0.08)
		for r in [[1.0, 1.0, 0.12], [1.58, 0.6, 0.09], [2.31, 0.45, 0.07], [3.17, 0.3, 0.05]]:
			_mix(out, _ping(0.16, base * r[0], r[2]), t, amp * r[1] * 0.4)
		_mix(out, _burst(0.002, HP, 4000.0, 0.7, 0.0001, 0.0015), t, amp * 0.5)
		t += rng.randf_range(0.03, 0.07)
	var creak := _creak(0.7, 38.0, 72.0)
	_mix(out, creak, 0.06, 0.7)
	_emit("sfx/leash/leash_pull.wav", _hp(out, 80.0), "Leash pull: chain clink + leather tension creak", -16.0)


## GDD §5/§7/§10: 4 s descending wind rush, hard cut to silence at 3.7 s.
func _fall() -> void:
	_seed_with(5600)
	var n := _zeros(4.0).size()
	var rush := _filt(_white(n), BP, func(t: float) -> float: return 1500.0 * pow(260.0 / 1500.0, t / 4.0), 1.1)
	var whistle := _filt(_white(n), BP, func(t: float) -> float: return 2100.0 * pow(330.0 / 2100.0, t / 4.0), 14.0)
	var rumble := _filt(_filt(_white(n), LP, 140.0, 0.7), LP, 140.0, 0.7)
	var gust := _smooth_random(n, 3.0)
	var out := _zeros(4.0)
	var cut := int(3.7 * SR)
	for i in cut:
		var tt := float(i) / SR
		var swell := pow(clampf(tt / 3.2, 0.0, 1.0), 1.6)
		var g := 0.7 + 0.3 * gust[i]
		out[i] = (rush[i] * 0.9 + whistle[i] * 1.6 + rumble[i] * 1.4 * swell) * swell * g
	for i in 48:  # 1 ms declick, still an abrupt cut
		out[cut - 48 + i] *= 1.0 - i / 48.0
	_emit("sfx/fall/fall_wind.wav", out, "Pit fall: wind rush with descending pitch, abrupt cut at 3.7 s", -16.0)


## GDD §5/§10: party popper, confetti, children's applause, cheerful jingle.
func _finale() -> void:
	_seed_with(5700)
	var pop := _zeros(2.0)
	for p in [[0.0, 1.0], [0.22, 0.7]]:
		_mix(pop, _burst(0.0015, HP, 1500.0, 0.7, 0.00005, 0.001), p[0], p[1])
		_mix(pop, _burst(0.05, BP, 1200.0, 0.8, 0.0003, 0.03), p[0], p[1] * 0.9)
		_mix(pop, _thump(0.1, 95.0, 50.0, 0.08), p[0], p[1] * 0.7)
	var confetti := _zeros(1.8)
	var t := 0.02
	while t < 1.75:
		var density := 380.0 * exp(-t * 2.4) + 8.0
		t += -log(maxf(rng.randf(), 1e-6)) / density
		var g := _burst(rng.randf_range(0.002, 0.006), BP, rng.randf_range(2500, 7000), 2.0, 0.0002, 0.003)
		_mix(confetti, g, t, rng.randf_range(0.15, 0.6) * exp(-t * 1.2))
	_mix(pop, confetti, 0.0, 0.6)
	_emit("sfx/finale/popper_confetti.wav", _hp(pop, 50.0), "Two party poppers + confetti burst", -16.0)

	_seed_with(5701)
	var clap := _zeros(3.6)
	t = 0.0
	while t < 3.45:
		var env := clampf(t / 0.25, 0.0, 1.0) * clampf((3.4 - t) / 1.0, 0.0, 1.0)
		t += -log(maxf(rng.randf(), 1e-6)) / maxf(55.0 * env, 4.0)
		var c := _burst(0.012, BP, rng.randf_range(1500, 3800), 1.4, 0.0003, rng.randf_range(0.015, 0.03))
		_mix(clap, c, t, rng.randf_range(0.3, 1.0) * maxf(env, 0.05))
	_emit("sfx/finale/applause_children.wav", _hp(clap, 200.0), "Small-hands applause (synthesized claps)", -18.0)

	_seed_with(5702)
	_emit("music/finale_jingle.wav", _jingle(), "Incongruously cheerful C-major toy jingle", -16.0)


## GDD §8/§10: lamp hum, CCTV servo, low drone.
func _ambience() -> void:
	_seed_with(5800)
	var hum_len := 2.0
	var hum := _zeros(hum_len)
	var harmonics := {50: 0.25, 100: 1.0, 150: 0.35, 200: 0.45, 250: 0.12, 300: 0.2, 400: 0.1,
			500: 0.06, 600: 0.05, 800: 0.03, 1000: 0.02}
	for f: int in harmonics:
		var ph := rng.randf() * TAU
		for i in hum.size():
			hum[i] += sin(TAU * f * i / SR + ph) * harmonics[f]
	var x := int(0.25 * SR)
	var buzz := _filt(_white(hum.size() + x), BP, 3200.0, 0.9)
	for i in buzz.size():
		buzz[i] *= pow(absf(sin(TAU * 50.0 * i / SR)), 6.0)
	_mix(hum, _loop_noise(buzz, x), 0.0, 0.35)
	_emit("ambience/fluorescent_hum_loop.wav", hum, "Fluorescent lamp hum, 50 Hz mains + harmonics + arc buzz", -24.0, true)

	_seed_with(5801)
	var servo := _zeros(1.0)
	for h in [[1.0, 1.0], [2.0, 0.45], [3.0, 0.2], [4.0, 0.08]]:
		var f: float = 620.0 * h[0]
		var depth: float = f * 0.012 / 8.0
		for i in servo.size():
			var tt := float(i) / SR
			servo[i] += sin(TAU * f * tt + depth * sin(TAU * 8.0 * tt)) * h[1]
	var gear := _filt(_white(servo.size() + x), BP, 1800.0, 1.5)
	for i in gear.size():
		gear[i] *= 0.5 + 0.5 * signf(sin(TAU * 40.0 * i / SR))
	_mix(servo, _loop_noise(gear, x), 0.0, 0.5)
	_emit("ambience/cctv_servo_loop.wav", _hp(servo, 200.0), "CCTV servo tracking whine (620 Hz motor + gear)", -20.0, true)

	_seed_with(5802)
	var drone := _zeros(8.0)
	for f in [[45.0, 1.0], [55.0, 0.8], [90.0, 0.3], [110.0, 0.25]]:
		for i in drone.size():
			var tt := float(i) / SR
			drone[i] += sin(TAU * f[0] * tt) * f[1] * (0.8 + 0.2 * sin(TAU * 0.25 * tt + f[0]))
	var rumble_x := int(1.0 * SR)
	var rumble := _filt(_filt(_white(drone.size() + rumble_x), LP, 90.0, 0.7), LP, 90.0, 0.7)
	_mix(drone, _loop_noise(rumble, rumble_x), 0.0, 3.0)
	_emit("ambience/drone_loop.wav", drone, "Low pressure drone 45/55 Hz with rumble", -24.0, true)


## GDD §4/§10 pressure layers: metronome, heartbeat, tinnitus, panting.
func _pressure() -> void:
	_seed_with(5900)
	var tick := _zeros(0.07)
	_mix(tick, _burst(0.001, HP, 3000.0, 0.7, 0.00005, 0.0008), 0.0, 0.6)
	_mix(tick, _ping(0.06, 2100.0, 0.025), 0.0, 1.0)
	_mix(tick, _ping(0.03, 4200.0, 0.01), 0.0, 0.35)
	_mix(tick, _ping(0.03, 900.0, 0.015), 0.0, 0.4)
	_emit("sfx/pressure/metronome_tick.wav", tick, "Metronome/clock tick", -18.0)

	_seed_with(5901)
	var heart := _zeros(0.6)
	_mix(heart, _thump(0.3, 62.0, 48.0, 0.18), 0.0, 1.0)
	_mix(heart, _thump(0.2, 124.0, 96.0, 0.1), 0.0, 0.3)
	_mix(heart, _burst(0.05, LP, 150.0, 0.7, 0.003, 0.04), 0.0, 0.5)
	_mix(heart, _thump(0.25, 75.0, 58.0, 0.12), 0.22, 0.7)
	_mix(heart, _thump(0.15, 150.0, 116.0, 0.07), 0.22, 0.22)
	_emit("sfx/pressure/heartbeat.wav", heart, "Heartbeat lub-dub", -18.0)

	_seed_with(5902)
	var ring := _zeros(2.0)
	for i in ring.size():
		var tt := float(i) / SR
		ring[i] = sin(TAU * 7040.0 * tt) * (0.92 + 0.08 * sin(TAU * 0.5 * tt)) + 0.06 * sin(TAU * 7210.0 * tt)
	_emit("sfx/pressure/tinnitus_loop.wav", ring, "Tinnitus 7.04 kHz sine (GDD 6–8 kHz)", -30.0, true)

	_seed_with(5903)
	var pant := _zeros(1.0)
	for k in 3:
		var at := k / 3.0
		_mix(pant, _breath(0.13, [700.0, 1250.0, 2500.0], 0.02, 0.09), at, 1.0)
		_mix(pant, _breath(0.1, [900.0, 1600.0, 2800.0], 0.03, 0.06), at + 0.16, 0.55)
	_emit("sfx/player/panting_loop.wav", _hp(pant, 150.0), "Open-mouth panting loop (from transform step 3)", -22.0, true)


## GDD §5/§6/§10 one-shots: transformation, prologue door, BAD DOG cut.
func _events() -> void:
	_seed_with(6000)
	var crunch := _zeros(2.5)
	for i in crunch.size():
		var tt := float(i) / SR
		var e := pow(sin(PI * tt / 2.5), 1.5)
		crunch[i] = (sin(TAU * 65.0 * tt) + 0.3 * sin(TAU * 130.0 * tt)) * e * 0.35
	var joints := _zeros(2.5)
	for c in 8:
		var at := rng.randf_range(0.15, 1.9)
		for k in rng.randi_range(5, 12):
			var g := _burst(rng.randf_range(0.0004, 0.0012), BP, rng.randf_range(600, 1800), 3.0, 0.0001, 0.003)
			_mix(joints, g, at + rng.randf_range(0.0, 0.04), rng.randf_range(0.3, 1.0))
	_mix(crunch, _filt(joints, LP, 2200.0, 0.7), 0.0, 0.9)
	_emit("sfx/transform/transform_crunch.wav", crunch, "Transformation: muffled joint crunch + low hum", -18.0)

	_seed_with(6001)
	var door := _zeros(1.8)
	_mix(door, _thump(0.4, 85.0, 50.0, 0.15), 0.0, 1.0)
	_mix(door, _burst(0.1, LP, 1000.0, 0.7, 0.0005, 0.06), 0.0, 0.6)
	for p in [[173.0, 1.0, 1.2], [412.0, 0.7, 0.9], [761.0, 0.5, 0.7], [1129.0, 0.35, 0.5], [1597.0, 0.2, 0.35], [2210.0, 0.12, 0.25]]:
		_mix(door, _ping(1.6, p[0] * rng.randf_range(0.99, 1.01), p[2]), 0.0, p[1] * 0.35)
	_mix(door, _burst(0.003, HP, 3000.0, 0.7, 0.0001, 0.002), 0.12, 0.4)
	_mix(door, _ping(0.1, 2600.0, 0.04), 0.12, 0.2)
	_emit("sfx/events/door_clank.wav", _hp(door, 40.0), "Metal cell door clank (prologue, distant slams)", -16.0)

	_seed_with(6002)
	var cut := _zeros(0.6)
	for i in int(0.05 * SR):
		cut[i] = sin(TAU * 100.0 * i / SR) * 0.3  # mains hum, then everything stops
	_mix(cut, _burst(0.0015, HP, 1500.0, 0.7, 0.00005, 0.001), 0.05, 1.0)
	_mix(cut, _thump(0.5, 70.0, 32.0, 0.35), 0.05, 1.0)
	_mix(cut, _burst(0.04, LP, 400.0, 0.7, 0.0005, 0.03), 0.05, 0.6)
	_emit("sfx/events/bad_dog_cut.wav", cut, "BAD DOG: hard power-cut thump before silence", -16.0)


# --- Instruments --------------------------------------------------------------

func _bark(p: Dictionary) -> PackedFloat32Array:
	var dur: float = p.dur
	var f0s: Array = p.f0
	var f0 := func(t: float) -> float:
		var k := t / dur
		return lerpf(f0s[0], f0s[1], k / 0.2) if k < 0.2 else lerpf(f0s[1], f0s[2], (k - 0.2) / 0.8)
	var src := _glottal(dur, f0, p.jitter, p.shimmer, p.sub)
	_normalize_peak(src, 1.0)
	var nz := _white(src.size())
	for i in src.size():
		src[i] = src[i] * (1.0 - p.breath) + nz[i] * p.breath * 0.6
	var voiced := _zeros(dur)
	for f: Array in p.formants:
		var fa: float = f[0]
		var fb: float = f[1]
		var glide := func(t: float) -> float: return lerpf(fa, fb, smoothstep(0.0, 1.0, t / (dur * 0.5)))
		_mix(voiced, _filt(src, BP, glide, f[2]), 0.0, f[3])
	_normalize_peak(voiced, 1.0)
	var attack: float = p.attack
	var drive: float = p.drive
	var rough: float = p.rough
	for i in voiced.size():
		var t := float(i) / SR
		var k := t / dur
		var e := minf(t / attack, 1.0) * (1.0 if k < 0.35 else pow(1.0 - (k - 0.35) / 0.65, 2.0))
		e *= 1.0 - rough * 0.5 * (1.0 + sin(TAU * 33.0 * t))
		voiced[i] = tanh(voiced[i] * e * drive) / tanh(drive)
	var fric: float = p.fric
	var out := _zeros(dur + fric + 0.12)
	_mix(out, voiced)
	var body: Array = p.body
	if body[1] > 0.0:
		_mix(out, _filt(out.duplicate(), BP, body[0], 8.0), 0.0, body[1] * 2.0)
	if fric > 0.0:
		_mix(out, _burst(fric, BP, 1800.0, 0.8, fric * 0.4, fric * 0.8), dur * 0.75, 0.25)
	return _hp(out, 70.0)


## Rosenberg glottal-flow derivative train with jitter, shimmer and period doubling.
func _glottal(seconds: float, f0: Callable, jitter: float, shimmer: float, sub: float) -> PackedFloat32Array:
	var n := int(seconds * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	const OQ := 0.6
	const TP := OQ * 0.65
	var phase := 0.0
	var freq: float = f0.call(0.0)
	var amp := 1.0
	var cycle := 0
	var prev := 0.0
	for i in n:
		phase += freq / SR
		if phase >= 1.0:
			phase -= 1.0
			cycle += 1
			freq = f0.call(float(i) / SR) * (1.0 + rng.randf_range(-jitter, jitter))
			amp = 1.0 + rng.randf_range(-shimmer, shimmer)
			if sub > 0.0 and cycle % 2 == 1:
				amp *= 1.0 - sub
		var g := 0.0
		if phase < TP:
			g = 0.5 - 0.5 * cos(PI * phase / TP)
		elif phase < OQ:
			g = cos(0.5 * PI * (phase - TP) / (OQ - TP))
		g *= amp
		out[i] = g - prev
		prev = g
	return out


func _bell(seconds: float, f: float) -> PackedFloat32Array:
	var out := _zeros(seconds)
	for p in [[1.0, 1.0, 2.4], [2.0, 0.42, 1.5], [3.0, 0.2, 0.9], [4.16, 0.13, 0.55], [5.43, 0.08, 0.35], [6.8, 0.04, 0.2]]:
		for detune in [-0.6, 0.6]:
			var fr: float = f * p[0] + detune
			var k: float = log(1000.0) / p[2]
			for i in out.size():
				var t := float(i) / SR
				out[i] += sin(TAU * fr * t) * p[1] * 0.5 * exp(-k * t)
	for i in 72:  # 1.5 ms strike ramp
		out[i] *= i / 72.0
	_mix(out, _burst(0.004, HP, 5000.0, 0.7, 0.0002, 0.003), 0.0, 0.15)
	return out


## Warm detuned PolyBLEP-saw chord through a 24 dB low-pass.
func _pad(seconds: float, freqs: Array, attack: float, release_at: float, release: float) -> PackedFloat32Array:
	var out := _zeros(seconds)
	for f: float in freqs:
		for cents in [-7.0, 0.0, 7.0]:
			_mix(out, _saw(seconds, f * pow(2.0, cents / 1200.0)), 0.0, 0.2)
	out = _filt(_filt(out, LP, 1400.0, 0.7), LP, 1400.0, 0.7)
	for i in out.size():
		var t := float(i) / SR
		var e := minf(t / attack, 1.0)
		if t > release_at:
			e *= exp(-(t - release_at) * log(1000.0) / release)
		out[i] *= e
	return out


func _saw(seconds: float, f: float) -> PackedFloat32Array:
	var out := _zeros(seconds)
	var dt := f / SR
	var ph := rng.randf()
	for i in out.size():
		var v := 2.0 * ph - 1.0
		if ph < dt:
			var x := ph / dt
			v -= x + x - x * x - 1.0
		elif ph > 1.0 - dt:
			var x := (ph - 1.0) / dt
			v -= x * x + x + x + 1.0
		out[i] = v
		ph += dt
		if ph >= 1.0:
			ph -= 1.0
	return out


## Poisson micro-grains of band-passed noise (plastic bag, paper).
func _crinkle(seconds: float, rate: float, lo: float, hi: float) -> PackedFloat32Array:
	var out := _zeros(seconds + 0.02)
	var t := 0.0
	while true:
		t += -log(maxf(rng.randf(), 1e-6)) / rate
		if t >= seconds:
			break
		var env := sin(PI * t / seconds)
		var g := _burst(rng.randf_range(0.001, 0.005), BP, rng.randf_range(lo, hi), 2.0, 0.0001, 0.003)
		_mix(out, g, t, rng.randf_range(0.2, 1.0) * env)
	return out


## Wet squelch: resonant band-pass sweep over noise.
func _wet(seconds: float, f_from: float, f_to: float) -> PackedFloat32Array:
	return _burst(seconds, BP, 0.0, 4.0, 0.004, seconds * 0.7,
			func(t: float) -> float: return f_from * pow(f_to / f_from, clampf(t / seconds, 0.0, 1.0)))


func _droplet() -> PackedFloat32Array:
	var out := _zeros(0.03)
	var ph := 0.0
	for i in out.size():
		var t := float(i) / SR
		ph += TAU * lerpf(900.0, 1500.0, t / 0.03) / SR
		out[i] = sin(ph) * exp(-t * 120.0)
	return out


## Leather stick-slip creak: irregular pulse train through body resonances.
func _creak(seconds: float, rate_from: float, rate_to: float) -> PackedFloat32Array:
	var pulses := _zeros(seconds)
	var t := 0.0
	while t < seconds:
		var k := t / seconds
		var idx := int(t * SR)
		if idx < pulses.size():
			pulses[idx] = rng.randf_range(0.5, 1.0) * sin(PI * minf(k * 1.4, 1.0))
		t += 1.0 / (lerpf(rate_from, rate_to, k) * rng.randf_range(0.8, 1.2))
	var out := _zeros(seconds)
	for r in [[450.0, 5.0, 1.0], [1100.0, 6.0, 0.6], [2300.0, 8.0, 0.3]]:
		_mix(out, _filt(pulses, BP, r[0], r[1]), 0.0, r[2])
	return out


func _breath(seconds: float, formants: Array, attack: float, decay: float) -> PackedFloat32Array:
	var src := _white(int(seconds * SR))
	var out := _zeros(seconds)
	for i in formants.size():
		_mix(out, _filt(src, BP, formants[i], 5.0), 0.0, [1.0, 0.6, 0.3][i])
	for i in out.size():
		var t := float(i) / SR
		out[i] *= minf(t / attack, 1.0) * exp(-maxf(t - attack, 0.0) * log(1000.0) / decay * 0.5)
	return out


func _pluck(seconds: float, f: float, decay: float) -> PackedFloat32Array:
	var out := _zeros(seconds)
	var size := maxi(2, roundi(SR / f))
	var line := _filt(_white(size), LP, 3000.0, 0.7)
	var idx := 0
	for i in out.size():
		var cur := line[idx]
		var nxt := line[(idx + 1) % size]
		line[idx] = decay * 0.5 * (cur + nxt)
		out[i] = cur
		idx = (idx + 1) % size
	return out


func _glock(seconds: float, f: float) -> PackedFloat32Array:
	var out := _zeros(seconds)
	for p in [[1.0, 1.0, 0.9], [2.756, 0.25, 0.25], [5.404, 0.12, 0.08]]:
		var k: float = log(1000.0) / p[2]
		for i in out.size():
			var t := float(i) / SR
			out[i] += sin(TAU * f * p[0] * t) * p[1] * exp(-k * t)
	for i in 48:
		out[i] *= i / 48.0
	return out


func _jingle() -> PackedFloat32Array:
	const BEAT := 60.0 / 140.0
	var out := _zeros(9.0 * BEAT + 1.3)
	var melody := [[0, 79, 0.5], [0.5, 84, 0.5], [1, 88, 0.5], [1.5, 91, 0.5], [2, 88, 0.5], [2.5, 84, 0.5],
			[3, 86, 1], [4, 89, 0.5], [4.5, 88, 0.5], [5, 86, 0.5], [5.5, 83, 0.5], [6, 84, 0.5],
			[6.5, 79, 0.5], [7, 84, 2], [7, 88, 2], [7, 91, 2]]
	for m in melody:
		_mix(out, _glock(1.2, _midi(m[1])), m[0] * BEAT, 0.5)
	var bass := [[0, 48], [1, 43], [2, 48], [3, 43], [4, 41], [5, 43], [6, 48], [6.5, 43], [7, 36]]
	for b in bass:
		_mix(out, _pluck(0.9 if b[0] < 7 else 1.6, _midi(b[1]), 0.994), b[0] * BEAT, 0.6)
	var chords := {0.5: [60, 64, 67], 1.5: [60, 64, 67], 2.5: [60, 64, 67], 3.5: [62, 67, 71],
			4.5: [65, 69, 72], 5.5: [62, 67, 71], 6.5: [60, 64, 67], 7.0: [60, 64, 67, 72]}
	for at: float in chords:
		for note: int in chords[at]:
			_mix(out, _pluck(0.35 if at < 7.0 else 1.6, _midi(note), 0.985), at * BEAT + rng.randf_range(0, 0.006), 0.22)
	_mix(out, _crinkle(0.6, 220.0, 5000.0, 11000.0), 7.0 * BEAT, 0.18)  # little "ta-da" shimmer
	return _hp(out, 50.0)


# --- DSP primitives -----------------------------------------------------------

func _zeros(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(round(seconds * SR)))
	b.fill(0.0)
	return b


func _white(n: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		b[i] = rng.randf_range(-1.0, 1.0)
	return b


func _mix(dst: PackedFloat32Array, src: PackedFloat32Array, at: float = 0.0, gain: float = 1.0) -> void:
	var o := int(round(at * SR))
	for i in mini(src.size(), dst.size() - o):
		dst[o + i] += src[i] * gain


## Filtered noise burst, linear attack then exponential decay (decay = T60 seconds).
## `sweep` (Callable(t) -> Hz) overrides the fixed centre frequency.
func _burst(seconds: float, kind: int, f: float, q: float, attack: float, decay: float,
		sweep: Variant = null) -> PackedFloat32Array:
	var n := maxi(int(seconds * SR), 1)
	var y := _filt(_white(n), kind, sweep if sweep is Callable else f, q)
	var k := log(1000.0) / maxf(decay, 0.0001)
	for i in n:
		var t := float(i) / SR
		y[i] *= minf(t / maxf(attack, 0.00001), 1.0) * exp(-k * maxf(t - attack, 0.0))
	return y


## Exponential pitch-glide sine with exponential decay (T60 seconds).
func _thump(seconds: float, f_from: float, f_to: float, decay: float) -> PackedFloat32Array:
	var out := _zeros(seconds)
	var ph := 0.0
	var k := log(1000.0) / decay
	for i in out.size():
		var t := float(i) / SR
		ph += TAU * f_from * pow(f_to / f_from, minf(t / decay, 1.0)) / SR
		out[i] = sin(ph) * exp(-k * t) * minf(t / 0.0005, 1.0)
	return out


func _ping(seconds: float, f: float, decay: float) -> PackedFloat32Array:
	var out := _zeros(seconds)
	var k := log(1000.0) / decay
	for i in out.size():
		var t := float(i) / SR
		out[i] = sin(TAU * f * t) * exp(-k * t)
	return out


func _hp(x: PackedFloat32Array, f: float) -> PackedFloat32Array:
	return _filt(x, HP, f, 0.707)


## RBJ biquad. `f` is Hz or Callable(t) -> Hz, re-evaluated every 16 samples.
func _filt(x: PackedFloat32Array, kind: int, f: Variant, q: float = 0.707) -> PackedFloat32Array:
	var y := PackedFloat32Array()
	y.resize(x.size())
	var dynamic := f is Callable
	var c := _coeffs(kind, 1000.0 if dynamic else f, q)
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in x.size():
		if dynamic and i % 16 == 0:
			c = _coeffs(kind, (f as Callable).call(float(i) / SR), q)
		var v := c[0] * x[i] + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
		x2 = x1
		x1 = x[i]
		y2 = y1
		y1 = v
		y[i] = v
	return y


func _coeffs(kind: int, f: float, q: float) -> PackedFloat64Array:
	var w := TAU * clampf(f, 10.0, SR * 0.45) / SR
	var cw := cos(w)
	var alpha := sin(w) / (2.0 * q)
	var b := [0.0, 0.0, 0.0]
	match kind:
		LP:
			b = [(1.0 - cw) * 0.5, 1.0 - cw, (1.0 - cw) * 0.5]
		HP:
			b = [(1.0 + cw) * 0.5, -(1.0 + cw), (1.0 + cw) * 0.5]
		BP:
			b = [alpha, 0.0, -alpha]
	var a0 := 1.0 + alpha
	return PackedFloat64Array([b[0] / a0, b[1] / a0, b[2] / a0, -2.0 * cw / a0, (1.0 - alpha) / a0])


## Smoothed random modulation in [-1, 1] with `rate` new targets per second.
func _smooth_random(n: int, rate: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var step := int(SR / rate)
	var a := rng.randf_range(-1, 1)
	var b := rng.randf_range(-1, 1)
	for i in n:
		if i % step == 0:
			a = b
			b = rng.randf_range(-1, 1)
		out[i] = lerpf(a, b, smoothstep(0.0, 1.0, float(i % step) / step))
	return out


## Seamless loop from noise rendered `x` samples longer: equal-power crossfade of tail into head.
func _loop_noise(src: PackedFloat32Array, x: int) -> PackedFloat32Array:
	var length := src.size() - x
	var out := src.slice(0, length)
	for i in x:
		var a := float(i) / x
		out[i] = src[i] * sin(a * PI * 0.5) + src[length + i] * cos(a * PI * 0.5)
	return out


func _midi(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


func _normalize_peak(x: PackedFloat32Array, target: float) -> void:
	var p := Loudness.sample_peak(x)
	if p <= 0.0:
		return
	for i in x.size():
		x[i] *= target / p


func _seed_with(s: int) -> void:
	_seed = s
	rng.seed = s


# --- Output -------------------------------------------------------------------

## Normalizes to `lufs_target` (whole-file BS.1770; one block if < 400 ms), then
## lowers the gain until the 4x true peak is <= TRUE_PEAK_CEILING_DB.
func _emit(rel: String, x: PackedFloat32Array, description: String, lufs_target: float, loop := false) -> void:
	var m: Dictionary = Loudness.measure(x)
	var level: float = m.integrated if m.integrated > -INF else m.max_momentary
	var gain := pow(10.0, (lufs_target - level) / 20.0)
	for i in x.size():
		x[i] *= gain
	var tp := Loudness.true_peak(x)
	var ceiling := pow(10.0, TRUE_PEAK_CEILING_DB / 20.0)
	if tp > ceiling:
		for i in x.size():
			x[i] *= ceiling / tp
	# Quantize exactly as written, then measure what ships.
	var pcm := PackedByteArray()
	pcm.resize(x.size() * 2)
	for i in x.size():
		var s := clampi(roundi(x[i] * 32767.0), -32768, 32767)
		pcm.encode_s16(i * 2, s)
		x[i] = s / 32767.0
	var path := OUT + rel
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	_write_wav(path, pcm, x.size(), loop)
	var shipped: Dictionary = Loudness.measure(x)
	manifest.append({
		path = path,
		description = description,
		generator = "tools/audio/synth_f5.gd",
		seed = _seed,
		seconds = snappedf(float(x.size()) / SR, 0.0001),
		loop = loop,
		integrated_lufs = snappedf(shipped.integrated, 0.01) if shipped.integrated > -INF else null,
		single_block = shipped.short_block,
		sample_peak_dbfs = snappedf(Loudness.db(Loudness.sample_peak(x)), 0.01),
		true_peak_dbtp = snappedf(Loudness.db(Loudness.true_peak(x)), 0.01),
		sha256 = FileAccess.get_sha256(path),
	})
	print("SYNTH %s %.3fs LUFS %.2f TP %.2f" % [rel, float(x.size()) / SR, shipped.integrated,
			Loudness.db(Loudness.true_peak(x))])


func _write_wav(path: String, pcm: PackedByteArray, frames: int, loop: bool) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	var smpl_size := 36 + 24
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(4 + (8 + 16) + (8 + pcm.size()) + ((8 + smpl_size) if loop else 0))
	f.store_buffer("WAVE".to_ascii_buffer())
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)       # PCM
	f.store_16(1)       # mono
	f.store_32(SR)
	f.store_32(SR * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(pcm.size())
	f.store_buffer(pcm)
	if loop:
		f.store_buffer("smpl".to_ascii_buffer())
		f.store_32(smpl_size)
		# manufacturer, product, sample period (ns), MIDI unity note, pitch fraction,
		# SMPTE format, SMPTE offset, loop count, sampler data size.
		for v in [0, 0, roundi(1.0e9 / SR), 60, 0, 0, 0, 1, 0]:
			f.store_32(v)
		# One forward loop over the whole file; Godot treats loop_end as exclusive.
		for v in [0, 0, 0, frames, 0, 0]:
			f.store_32(v)
	f.close()


func _write_manifest() -> void:
	var f := FileAccess.open(OUT + "PROVENANCE.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({
		generator = "res://tools/audio/synth_f5.gd",
		command = "godot4 --headless --path . -s res://tools/audio/synth_f5.gd",
		engine = Engine.get_version_info().string,
		license = "MIT (original GOOD DOG contributor work; see LICENSE)",
		format = "PCM s16le, 48000 Hz, mono",
		loudness = "ITU-R BS.1770-4 integrated (tools/audio/loudness.gd); single_block = file shorter than 400 ms",
		files = manifest,
	}, "  ") + "\n")
	f.close()
