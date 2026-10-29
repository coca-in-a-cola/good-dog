extends RefCounted
## ITU-R BS.1770-4 loudness for float buffers (original, MIT).
##
## Integrated loudness: K-weighting (pre-filter design valid at any sample rate),
## 400 ms blocks with 75% overlap, absolute gate -70 LUFS, relative gate -10 LU.
## Channels are power-summed with weight 1.0 (L, R or mono). Buffers shorter than
## one block are measured as a single block over their whole length (reported).
## True peak: 4x windowed-sinc interpolation, evaluated only around samples
## within 6 dB of the sample peak (intersample overs only occur there).

const TAPS := 16  # half-width of the interpolation kernel


static func k_weight(x: PackedFloat32Array, rate: float = 48000.0) -> PackedFloat32Array:
	# Stage 1: high shelf (+4 dB above ~1.7 kHz).
	var k := tan(PI * 1681.974450955533 / rate)
	var q := 0.7071752369554196
	var vh := pow(10.0, 3.999843853973347 / 20.0)
	var vb := pow(vh, 0.4996667741545416)
	var a0 := 1.0 + k / q + k * k
	var y := _biquad(x, (vh + vb * k / q + k * k) / a0, 2.0 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0,
			2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0)
	# Stage 2: RLB high-pass (~38 Hz).
	k = tan(PI * 38.13547087602444 / rate)
	q = 0.5003270373238773
	a0 = 1.0 + k / q + k * k
	return _biquad(y, 1.0, -2.0, 1.0, 2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0)


## Mono: returns {integrated, short_block, max_momentary}. LUFS, -INF when silent.
static func measure(x: PackedFloat32Array, rate: float = 48000.0) -> Dictionary:
	return measure_channels([x], rate)


static func measure_channels(channels: Array, rate: float = 48000.0) -> Dictionary:
	var weighted: Array[PackedFloat32Array] = []
	for c: PackedFloat32Array in channels:
		weighted.append(k_weight(c, rate))
	var size: int = weighted[0].size()
	var block := int(0.4 * rate)
	var step := int(0.1 * rate)
	var energies := PackedFloat64Array()
	var short_block := size < block
	if short_block:
		energies.append(_energy(weighted, 0, size))
	else:
		var start := 0
		while start + block <= size:
			energies.append(_energy(weighted, start, block))
			start += step
	var max_momentary := -INF
	var above_abs := PackedFloat64Array()
	for e in energies:
		var l := _lufs(e)
		max_momentary = maxf(max_momentary, l)
		if l > -70.0:
			above_abs.append(e)
	var integrated := -INF
	if not above_abs.is_empty():
		var rel_gate := _lufs(_mean(above_abs)) - 10.0
		var gated := PackedFloat64Array()
		for e in above_abs:
			if _lufs(e) > rel_gate:
				gated.append(e)
		if not gated.is_empty():
			integrated = _lufs(_mean(gated))
	return {integrated = integrated, short_block = short_block, max_momentary = max_momentary}


static func sample_peak(x: PackedFloat32Array) -> float:
	var p := 0.0
	for v in x:
		p = maxf(p, absf(v))
	return p


static func true_peak(x: PackedFloat32Array) -> float:
	var sp := sample_peak(x)
	var tp := sp
	var near := sp * 0.5
	var n := x.size()
	for i in n:
		if absf(x[i]) < near and (i + 1 >= n or absf(x[i + 1]) < near):
			continue
		for phase in [0.25, 0.5, 0.75]:
			var acc := 0.0
			for j in range(-TAPS + 1, TAPS + 1):
				var idx := i + j
				if idx < 0 or idx >= n:
					continue
				var d: float = phase - j
				var w := 0.5 + 0.5 * cos(PI * d / TAPS)
				acc += x[idx] * _sinc(d) * w
			tp = maxf(tp, absf(acc))
	return tp


static func db(v: float) -> float:
	return 20.0 * log(v) / log(10.0) if v > 0.0 else -INF


static func _sinc(d: float) -> float:
	return 1.0 if absf(d) < 1e-9 else sin(PI * d) / (PI * d)


static func _lufs(mean_square: float) -> float:
	return -0.691 + 10.0 * log(mean_square) / log(10.0) if mean_square > 0.0 else -INF


static func _mean(a: PackedFloat64Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / a.size()


## Sum over channels of the mean square in [start, start + count).
static func _energy(channels: Array[PackedFloat32Array], start: int, count: int) -> float:
	var total := 0.0
	for x in channels:
		var s := 0.0
		for i in range(start, start + count):
			s += x[i] * x[i]
		total += s / maxf(count, 1)
	return total


static func _biquad(x: PackedFloat32Array, b0: float, b1: float, b2: float, a1: float, a2: float) -> PackedFloat32Array:
	var y := PackedFloat32Array()
	y.resize(x.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in x.size():
		var v := b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x[i]
		y2 = y1
		y1 = v
		y[i] = v
	return y
