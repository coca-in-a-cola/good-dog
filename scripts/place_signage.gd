extends Node3D
## PLACE escalation signage: each PLACE ladder rung bolts more "STICK. HERE."
## signs into the observation room, every arrow aimed at the pedestal.
##
## Built-in Label3D/BoxMesh/PrismMesh only, no collision. Rung 0 adds nothing:
## the level's single PLACE THE STICK HERE label and arrow stay the only cue.
## Reveals are driven by reveal(rung) from the director's PLACE pressure signal
## and animated only by advance(dt), so a paused level never progresses them.

const TARGET := Vector3(0, 0.45, -24.6)
const CEILING_Y := 3.0
## Cumulative sign count per PLACE rung (0–5). Bounded: never more than SIGNS.size().
const COUNTS := [0, 2, 5, 9, 14, 20]
const POP_SECONDS := 0.35
const STAGGER_SECONDS := 0.08
const RED := Color("e53935")
const FONT := preload("res://addons/command_overlay/assets/fonts/NotoSans-Bold.ttf")
## Hand-placed, deterministic. kind: wall (bolted), hung (ceiling rod), floor (painted).
## Positions keep clear of the entrance→pedestal→exit lane, the observation
## window (+x wall), the CCTV mount and the pedestal label, and stay off the
## label, pedestal and exit doorway on screen from the entrance, the window
## corner and the final approach (the back-left wall sits behind the label there).
const SIGNS := [
	{p = Vector3(2.75, 0.95, -28.46), r = Vector3(0, 0, -6), s = 1.0, kind = &"wall"},
	{p = Vector3(-3.96, 1.6, -24.6), r = Vector3(0, 90, 4), s = 1.1, kind = &"wall"},
	{p = Vector3(2.6, 1.9, -28.46), r = Vector3(0, 0, 9), s = 0.9, kind = &"wall"},
	{p = Vector3(0, 0.02, -22.3), r = Vector3(-90, 0, 0), s = 0.9, kind = &"floor"},
	{p = Vector3(-2.0, 2.45, -22.6), r = Vector3(-15, 30, -12), s = 0.8, kind = &"hung"},
	{p = Vector3(-3.96, 2.4, -22.4), r = Vector3(0, 90, -18), s = 0.85, kind = &"wall"},
	{p = Vector3(-3.96, 0.75, -25.9), r = Vector3(0, 90, 22), s = 1.0, kind = &"wall"},
	{p = Vector3(-1.9, 0.02, -24.6), r = Vector3(-90, 0, 8), s = 1.0, kind = &"floor"},
	{p = Vector3(2.9, 2.45, -27.3), r = Vector3(-10, -35, 10), s = 1.0, kind = &"hung"},
	{p = Vector3(-2.6, 1.8, -20.74), r = Vector3(0, 180, -10), s = 1.0, kind = &"wall"},
	{p = Vector3(2.4, 1.5, -20.74), r = Vector3(0, 180, 14), s = 0.9, kind = &"wall"},
	{p = Vector3(-3.96, 2.35, -23.5), r = Vector3(0, 90, -14), s = 0.75, kind = &"wall"},
	{p = Vector3(1.9, 0.02, -23.2), r = Vector3(-90, 20, 0), s = 1.1, kind = &"floor"},
	{p = Vector3(-2.3, 2.45, -24.0), r = Vector3(-20, 20, 15), s = 1.1, kind = &"hung"},
	{p = Vector3(-3.95, 2.25, -26.0), r = Vector3(0, 90, -8), s = 1.2, kind = &"wall"},
	{p = Vector3(-3.96, 1.3, -21.6), r = Vector3(0, 90, 12), s = 1.25, kind = &"wall"},
	# Painted where the entrance view reads it, not foreshortened behind the pedestal.
	{p = Vector3(-1.7, 0.02, -22.8), r = Vector3(-90, 35, 0), s = 1.2, kind = &"floor"},
	{p = Vector3(-2.0, 2.45, -21.4), r = Vector3(-25, 10, -20), s = 1.0, kind = &"hung"},
	{p = Vector3(3.2, 2.45, -25.6), r = Vector3(-10, -60, -25), s = 0.95, kind = &"hung"},
	{p = Vector3(3.3, 2.4, -28.46), r = Vector3(0, 0, 30), s = 0.8, kind = &"wall"},
]

var rung := -1
var signs: Array[Node3D] = []
var _panels: Array[Node3D] = []
var _age: Array[float] = []


func _ready() -> void:
	var board_mat := StandardMaterial3D.new()
	board_mat.albedo_color = Color("f4f7f7")
	board_mat.roughness = 0.55
	var red_mat := StandardMaterial3D.new()
	red_mat.albedo_color = RED
	red_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rod_mat := StandardMaterial3D.new()
	rod_mat.albedo_color = Color("52757e")
	rod_mat.roughness = 0.34
	rod_mat.metallic = 0.55
	for i in SIGNS.size():
		var spec: Dictionary = SIGNS[i]
		var root := Node3D.new()
		root.name = "StickSign%d" % i
		root.position = spec.p
		add_child(root)
		var panel := Node3D.new()
		panel.name = "Panel"
		panel.rotation_degrees = spec.r
		panel.scale = Vector3.ONE * spec.s
		root.add_child(panel)
		if spec.kind != &"floor":
			_mesh(panel, "Board", Vector3(1.0, 0.75, 0.03), Vector3.ZERO, board_mat)
			_mesh(panel, "Border", Vector3(1.08, 0.83, 0.02), Vector3(0, 0, -0.012), red_mat)
		if spec.kind == &"hung":
			# Rod drops to the top edge just behind the board, never across the print.
			var top: Vector3 = panel.transform * Vector3(0, 0.415, -0.03)
			var length: float = CEILING_Y - spec.p.y - top.y
			_mesh(root, "Rod", Vector3(0.015, length, 0.015), top + Vector3(0, length / 2, 0), rod_mat)
		var label := Label3D.new()
		label.name = "Text"
		label.text = "STICK. HERE."
		label.font = FONT
		label.font_size = 64
		label.pixel_size = 0.0018
		label.modulate = RED
		label.outline_size = 0
		label.double_sided = false  # blank board back, no mirrored text
		label.position = Vector3(0, 0.15, 0.02)
		panel.add_child(label)
		# Arrow drawn pointing +X, then turned in the panel plane toward the pedestal.
		var arrow := Node3D.new()
		arrow.name = "Arrow"
		arrow.position = Vector3(0, -0.15, 0.02)
		var to_target := (Transform3D(Basis.from_euler(panel.rotation).scaled(panel.scale), spec.p).affine_inverse() * TARGET)
		arrow.rotation.z = atan2(to_target.y - arrow.position.y, to_target.x - arrow.position.x)
		panel.add_child(arrow)
		_mesh(arrow, "Stem", Vector3(0.24, 0.07, 0.01), Vector3(-0.06, 0, 0), red_mat)
		var head := _mesh(arrow, "Head", Vector3.ZERO, Vector3(0.12, 0, 0), red_mat)
		var prism := PrismMesh.new()
		prism.size = Vector3(0.2, 0.16, 0.01)
		head.mesh = prism
		head.rotation.z = -PI / 2
		signs.append(root)
		_panels.append(panel)
		_age.append(0.0)
	reset()


## Shows the cumulative sign set for a PLACE rung. Repeats and lower rungs are no-ops.
func reveal(level: int) -> void:
	level = clampi(level, 0, COUNTS.size() - 1)
	if level <= rung:
		return
	var from: int = COUNTS[rung] if rung >= 0 else 0
	rung = level
	for i in range(from, COUNTS[level]):
		signs[i].visible = true
		_age[i] = -STAGGER_SECONDS * (i - from)
		_panels[i].scale = Vector3.ONE * 0.001


func reset() -> void:
	rung = -1
	for i in signs.size():
		signs[i].visible = false
		_age[i] = 0.0
		_panels[i].scale = Vector3.ONE * SIGNS[i].s


func visible_count() -> int:
	return signs.filter(func(s: Node3D) -> bool: return s.visible).size()


## Real seconds from the level's pause-aware clock; dt 0 freezes every pop-in.
func advance(dt: float) -> void:
	if dt <= 0.0:
		return
	var overlay := get_node_or_null(^"/root/Overlay")
	var calm: bool = overlay != null and overlay.reduce_shake
	for i in signs.size():
		if not signs[i].visible or _age[i] >= POP_SECONDS:
			continue
		_age[i] += dt
		var t := clampf(_age[i] / POP_SECONDS, 0.0, 1.0)
		# Cartoon overshoot "boing"; reduced shake settles without overshoot.
		var k := 1.0 - pow(1.0 - t, 3.0) if calm else 1.0 + 2.70158 * pow(t - 1.0, 3.0) + 1.70158 * pow(t - 1.0, 2.0)
		_panels[i].scale = Vector3.ONE * maxf(SIGNS[i].s * k, 0.001)


func _mesh(parent: Node3D, label: String, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	if size != Vector3.ZERO:
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
	mesh.position = at
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh
