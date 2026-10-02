extends Node3D

# ══════════════════════════════════════════════════════════════
#  ЧЕЛОВЕК-ПАУК 3D — камера от плеча, модель, рывок, XP
# ══════════════════════════════════════════════════════════════

const WIN_W := 3840
const WIN_H := 2160

const CELL    := 50.0
const GRID    := 6
const BLD_MIN := 18.0
const BLD_MAX := 26.0
const ROAD_W  := 10.0

const GRAVITY   := 30.0
const WALK      := 10.0
const SPRINT    := 16.0
const JUMP      := 11.0
const AIR_ACCEL := 22.0
const AIR_DRAG  := 0.15

const WEB_RANGE     := 120.0
const MIN_ROPE      := 4.0
const PUMP          := 32.0
const REEL          := 12.0
const AUTO_REEL     := 2.2
const MAX_SPEED     := 42.0
const RELEASE_BOOST := 1.08
const SWING_DAMPING := 0.35

const DASH_FORCE    := 42.0
const DASH_UP       := 6.0
const DASH_COOLDOWN := 1.5

const FOV_BASE := 90.0
const FOV_FAST := 105.0
const SENS     := 0.0022

# ─── Камера от плеча ───
const CAM_DIST        := 5.5     # дистанция камеры от пивота
const CAM_HEIGHT      := 1.85    # высота пивота (уровень глаз)
const CAM_SIDE_OFFSET := 0.7     # сдвиг пивота вбок (0.7 = за правым плечом)
const CAM_PITCH_MIN   := -1.2
const CAM_PITCH_MAX   := 1.2
const CAM_PITCH_START := -0.15

# ─── Модель ───
const MODEL_SCALE    := 1.0
const MODEL_YAW_OFF  := 180.0
const MODEL_Y_OFFSET := 0.0

var player: CharacterBody3D
var visual: Node3D
var pivot: Node3D          # точка, вокруг которой вращается камера (у плеча)
var spring: SpringArm3D
var cam: Camera3D
var rope: MeshInstance3D
var xp_label: Label

var yaw := 0.0
var pitch := CAM_PITCH_START
var web_on := false
var anchor := Vector3.ZERO
var rope_len := 4.0
var space_prev := false
var dash_timer := 0.0
var dash_prev := false
var xp := 0.0

var is_mobile := false
var joy_vec := Vector2.ZERO
var joy_touch_id := -1
var joy_center := Vector2.ZERO
var look_touch_id := -1
var look_last := Vector2.ZERO
var btn_web := false
var btn_reel := false
var btn_jump := false
var btn_dash := false

# ══════════════════════════════════════════════════════════════
func _ready() -> void:
	is_mobile = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	_setup_window()
	_build_sky()
	_build_ground()
	_build_roads()
	_build_buildings()
	_build_player()
	_build_camera()
	_build_rope()
	_build_hud()
	if is_mobile:
		_build_touch_controls()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_window() -> void:
	if is_mobile:
		return
	var target := Vector2i(WIN_W, WIN_H)
	var screen := DisplayServer.screen_get_size()
	target.x = mini(target.x, screen.x)
	target.y = mini(target.y, screen.y)
	DisplayServer.window_set_size(target)
	DisplayServer.window_set_position((screen - target) / 2)

func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

func _find_model() -> String:
	var dir := DirAccess.open("res://")
	if dir == null:
		return ""
	dir.list_dir_begin()
	var f := dir.get_next()
	var result := ""
	while f != "":
		if f.ends_with(".obj") or f.ends_with(".glb") or f.ends_with(".gltf"):
			result = "res://" + f
			break
		f = dir.get_next()
	dir.list_dir_end()
	return result

func add_xp(amount: float) -> void:
	xp += amount
	if xp_label:
		xp_label.text = "ОПЫТ: %d" % int(xp)

# ══════════════════════════════════════════════════════════════ НЕБО
func _build_sky() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color        = Color(0.16, 0.28, 0.55)
	sm.sky_horizon_color    = Color(0.95, 0.72, 0.55)
	sm.sky_curve            = 0.12
	sm.ground_bottom_color  = Color(0.04, 0.03, 0.06)
	sm.ground_horizon_color = Color(0.45, 0.38, 0.32)
	sm.sun_angle_max        = 8.0
	sm.sun_curve            = 0.05
	sky.sky_material = sm

	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55

	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.78, 0.72, 0.68)
	env.fog_light_energy = 0.9
	env.fog_density = 0.0
	env.fog_sky_affect = 0.5
	env.fog_aerial_perspective = 0.4
	env.fog_depth_begin = 70.0
	env.fog_depth_end = 340.0
	env.fog_depth_curve = 1.8
	env.fog_height_density = 0.0

	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 2.0
	env.ssao_power = 1.5

	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0

	env.glow_enabled = true
	env.glow_intensity = 1.3
	env.glow_strength = 1.0
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.85
	env.glow_hdr_scale = 2.0

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0

	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.05
	env.adjustment_brightness = 1.0

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.95, 0.82, 0.72)
	env.volumetric_fog_emission = Color(0.7, 0.58, 0.48)
	env.volumetric_fog_emission_energy = 0.5

	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-15, 130, 0)
	sun.light_color = Color(1.0, 0.85, 0.70)
	sun.light_energy = 1.7
	sun.light_volumetric_fog_energy = 1.5
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 2.0
	sun.directional_shadow_max_distance = 350.0
	add_child(sun)

# ══════════════════════════════════════════════════════════════ ЗЕМЛЯ
func _build_ground() -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1600, 2, 1600)
	col.shape = shape
	body.add_child(col)

	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	var tex := _tex("res://ground.png")
	if tex:
		mat.albedo_texture = tex
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.08, 0.08, 0.08)
	else:
		mat.albedo_color = Color(0.16, 0.17, 0.20)

	var nrm := _tex("res://ground_n.png")
	if nrm:
		mat.normal_enabled = true
		mat.normal_texture = nrm
		mat.normal_scale = 1.0

	mat.roughness = 0.95

	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	mesh.material = mat
	mi.mesh = mesh
	mi.position.y = -1.0
	body.add_child(mi)

	add_child(body)

# ══════════════════════════════════════════════════════════════ ДОРОГИ
func _build_roads() -> void:
	var total_len := (GRID * 2 + 2) * CELL

	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	var tex := _tex("res://road.png")
	if tex:
		mat.albedo_texture = tex
		mat.uv1_scale = Vector3(1.0, total_len / 8.0, 1.0)
	else:
		mat.albedo_color = Color(0.09, 0.09, 0.11)

	var nrm := _tex("res://road_n.png")
	if nrm:
		mat.normal_enabled = true
		mat.normal_texture = nrm
		mat.normal_scale = 0.25

	mat.roughness = 0.95

	var road_mesh := BoxMesh.new()
	road_mesh.size = Vector3(ROAD_W, 0.15, total_len)
	road_mesh.material = mat

	for i in range(-GRID, GRID + 2):
		var pos := (i - 0.5) * CELL

		var rz := MeshInstance3D.new()
		rz.mesh = road_mesh
		rz.position = Vector3(pos, 0.12, 0.0)
		add_child(rz)

		var rx := MeshInstance3D.new()
		rx.mesh = road_mesh
		rx.position = Vector3(0.0, 0.04, pos)
		rx.rotation_degrees.y = 90
		add_child(rx)

# ══════════════════════════════════════════════════════════════ ЗДАНИЯ
func _build_buildings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 98765

	var t_color := _tex("res://facade.png")
	var t_norm  := _tex("res://facade_n.png")
	var t_rough := _tex("res://facade_r.png")
	var t_ao    := _tex("res://facade_ao.png")

	var r_color := _tex("res://metal.png")
	if not r_color: r_color = _tex("res://road.png")
	if not r_color: r_color = t_color
	var r_norm  := _tex("res://metal_n.png")
	if not r_norm: r_norm = _tex("res://road_n.png")

	for gx in range(-GRID, GRID + 1):
		for gz in range(-GRID, GRID + 1):
			if abs(gx) <= 1 and abs(gz) <= 1:
				continue

			var w := rng.randf_range(BLD_MIN, BLD_MAX)
			var d := rng.randf_range(BLD_MIN, BLD_MAX)
			var h: float = round(rng.randf_range(6, 22)) * 4.0

			var body := StaticBody3D.new()
			var col := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(w, h, d)
			col.shape = shape
			body.add_child(col)

			var mat := StandardMaterial3D.new()
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

			if t_color:
				mat.albedo_texture = t_color
				mat.uv1_scale = Vector3(w / 12.0, h / 16.0, 1.0)
			else:
				var k := rng.randf()
				mat.albedo_color = Color(0.3 + k * 0.15, 0.32 + k * 0.15, 0.4 + k * 0.15)

			if t_norm:
				mat.normal_enabled = true
				mat.normal_texture = t_norm
				mat.normal_scale = 1.0

			if t_rough:
				mat.roughness_texture = t_rough
				mat.roughness = 1.0
				mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			else:
				mat.roughness = 0.8

			if t_ao:
				mat.ao_enabled = true
				mat.ao_texture = t_ao
				mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
				mat.ao_light_affect = 0.3

			mat.metallic = 0.05

			var mesh := BoxMesh.new()
			mesh.size = shape.size
			mesh.material = mat
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			body.add_child(mi)

			body.position = Vector3(gx * CELL, h * 0.5, gz * CELL)
			add_child(body)

			_build_roof(body.position, w, d, h, r_color, r_norm)

func _build_roof(pos: Vector3, w: float, d: float, h: float,
				r_color: Texture2D, r_norm: Texture2D) -> void:
	var roof_h := 0.4
	var parapet_h := 1.2

	# ─── ФИЗИЧЕСКАЯ КОРОБКА КРЫШИ + БОРТИКА ───
	# Один StaticBody3D на всю крышу: и плита, и бортик
	var roof_body := StaticBody3D.new()
	roof_body.collision_layer = 1
	roof_body.collision_mask = 0

	# 1) Плита крыши (то, на чём стоим)
	var slab_shape := BoxShape3D.new()
	slab_shape.size = Vector3(w + 0.3, roof_h, d + 0.3)
	var slab_col := CollisionShape3D.new()
	slab_col.shape = slab_shape
	slab_col.position.y = h + roof_h * 3
	roof_body.add_child(slab_col)

	# 2) Бортик по краям (за него цепляемся паутиной)
	var p_thick := 0.4
	var edges := [
		[Vector3(0, 0,  d * 0.5), Vector3(w + 0.3, parapet_h, p_thick)],
		[Vector3(0, 0, -d * 0.5), Vector3(w + 0.3, parapet_h, p_thick)],
		[Vector3( w * 0.5, 0, 0), Vector3(p_thick, parapet_h, d + 0.3)],
		[Vector3(-w * 0.5, 0, 0), Vector3(p_thick, parapet_h, d + 0.3)],
	]
	for e in edges:
		var ps := BoxShape3D.new()
		ps.size = e[1]
		var pc := CollisionShape3D.new()
		pc.shape = ps
		pc.position = Vector3(e[0].x, h + roof_h + parapet_h * 0.5, e[0].z)
		roof_body.add_child(pc)

	# позиционируем весь "крыша-коллайдер" в мире
	roof_body.position = Vector3(pos.x, 0.0, pos.z)
	add_child(roof_body)

	# ─── ВИЗУАЛ: плита крыши ───
	var rmat := StandardMaterial3D.new()
	rmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if r_color:
		rmat.albedo_texture = r_color
		rmat.uv1_scale = Vector3(w / 4.0, d / 4.0, 1.0)
	if r_norm:
		rmat.normal_enabled = true
		rmat.normal_texture = r_norm
		rmat.normal_scale = 0.6
	rmat.roughness = 0.55
	rmat.metallic = 0.35

	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(w + 0.3, roof_h, d + 0.3)
	slab_mesh.material = rmat
	var slab_mi := MeshInstance3D.new()
	slab_mi.mesh = slab_mesh
	slab_mi.position = Vector3(pos.x, h + roof_h * 0.5, pos.z)
	add_child(slab_mi)

	# ─── ВИЗУАЛ: бортик ───
	var border_mat := StandardMaterial3D.new()
	if r_color:
		border_mat.albedo_texture = r_color
		border_mat.uv1_scale = Vector3(8, 2, 1)
	border_mat.roughness = 0.6
	border_mat.metallic = 0.3

	for e in edges:
		var pm := BoxMesh.new()
		pm.size = e[1]
		pm.material = border_mat
		var pmi := MeshInstance3D.new()
		pmi.mesh = pm
		pmi.position = Vector3(pos.x, h + roof_h + parapet_h * 0.5, pos.z) + e[0]
		add_child(pmi)
# ══════════════════════════════════════════════════════════════ ИГРОК
func _build_player() -> void:
	player = CharacterBody3D.new()
	player.collision_layer = 2
	player.collision_mask = 1

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 3
	col.shape = shape
	col.position.y = 1.55
	player.add_child(col)

	visual = Node3D.new()
	visual.name = "Visual"
	player.add_child(visual)

	var model_path := _find_model()
	if model_path != "" and ResourceLoader.exists(model_path):
		var res = load(model_path)
		var model: Node3D = null

		if res is PackedScene:
			model = res.instantiate()
		elif res is ArrayMesh:
			model = Node3D.new()
			var mi := MeshInstance3D.new()
			mi.mesh = res
			model.add_child(mi)

		if model:
			model.scale = Vector3(MODEL_SCALE, MODEL_SCALE, MODEL_SCALE)
			model.rotation_degrees.y = MODEL_YAW_OFF
			model.position.y = MODEL_Y_OFFSET
			visual.add_child(model)

			# подключаем текстуру
			var skin := _tex("res://Meshy_AI_Urban_Canvas_0924114354_texture.png")
			if skin == null:
				var dir := DirAccess.open("res://")
				if dir:
					dir.list_dir_begin()
					var f := dir.get_next()
					while f != "":
						if f.ends_with(".png") and f.to_lower().contains("texture"):
							skin = load("res://" + f)
							break
						f = dir.get_next()
					dir.list_dir_end()

			if skin:
				var mat := StandardMaterial3D.new()
				mat.albedo_texture = skin
				mat.roughness = 0.75
				mat.metallic = 0.0
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				for mi in model.find_children("*", "MeshInstance3D", true, false):
					var m := mi as MeshInstance3D
					if m.mesh == null: continue
					for i in m.mesh.get_surface_count():
						m.set_surface_override_material(i, mat)

	player.position = Vector3(0.0, 0.05, 0.0)
	add_child(player)

# ══════════════════════════════════════════════════════════════ КАМЕРА ОТ ПЛЕЧА
func _build_camera() -> void:
	# pivot — точка вращения камеры, чуть вбок и на уровне глаз
	pivot = Node3D.new()
	pivot.position = Vector3(CAM_SIDE_OFFSET, CAM_HEIGHT, 0.0)
	player.add_child(pivot)

	# SpringArm — чтобы камера не проваливалась сквозь стены
	spring = SpringArm3D.new()
	spring.spring_length = CAM_DIST
	spring.collision_mask = 1
	spring.margin = 0.2
	pivot.add_child(spring)

	# камера на конце пружины
	cam = Camera3D.new()
	cam.fov = FOV_BASE
	spring.add_child(cam)

	# применяем начальный поворот
	pivot.rotation = Vector3(pitch, yaw, 0.0)

# ══════════════════════════════════════════════════════════════ НИТЬ
func _build_rope() -> void:
	rope = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.05
	mesh.height = 1.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 1)
	mat.emission_energy_multiplier = 0.7
	mesh.material = mat

	rope.mesh = mesh
	rope.visible = false
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rope)

# ══════════════════════════════════════════════════════════════ HUD
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"

	var dot := ColorRect.new()
	dot.color = Color(1, 0.9, 0.6, 0.95)
	dot.size = Vector2(4, 4)
	dot.anchor_left = 0.5
	dot.anchor_right = 0.5
	dot.anchor_top = 0.5
	dot.anchor_bottom = 0.5
	dot.offset_left = -2
	dot.offset_top = -2
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dot)

	var lbl := Label.new()
	lbl.text = "ОПЫТ: 0"
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_color_override("font_color", Color(1, 0.92, 0.65))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.anchor_left = 0.0
	lbl.anchor_top = 0.0
	lbl.offset_left = 30
	lbl.offset_top = 25
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(lbl)
	xp_label = lbl

	add_child(layer)

# ══════════════════════════════════════════════════════════════ МОБИЛЬНЫЕ КНОПКИ
func _build_touch_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TouchUI"
	layer.layer = 10
	add_child(layer)

	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(1, 1, 1, 0.12)
	base_style.corner_radius_top_left = 130
	base_style.corner_radius_top_right = 130
	base_style.corner_radius_bottom_left = 130
	base_style.corner_radius_bottom_right = 130

	var base := Panel.new()
	base.add_theme_stylebox_override("panel", base_style)
	base.size = Vector2(260, 260)
	base.anchor_top = 1.0
	base.anchor_bottom = 1.0
	base.anchor_left = 0.0
	base.anchor_right = 0.0
	base.offset_left = 50
	base.offset_top = -310
	base.offset_right = 310
	base.offset_bottom = -50
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.name = "JoyBase"
	layer.add_child(base)

	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color(1, 1, 1, 0.35)
	knob_style.corner_radius_top_left = 55
	knob_style.corner_radius_top_right = 55
	knob_style.corner_radius_bottom_left = 55
	knob_style.corner_radius_bottom_right = 55

	var knob := Panel.new()
	knob.add_theme_stylebox_override("panel", knob_style)
	knob.size = Vector2(110, 110)
	knob.position = Vector2(75, 75)
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.name = "JoyKnob"
	base.add_child(knob)

	_make_touch_btn(layer, "🕸", Vector2(1, 1), Vector2(-300, -300), "web")
	_make_touch_btn(layer, "↑", Vector2(1, 1), Vector2(-150, -300), "jump")
	_make_touch_btn(layer, "↓", Vector2(1, 1), Vector2(-300, -150), "reel")
	_make_touch_btn(layer, "⚡", Vector2(1, 1), Vector2(-150, -150), "dash")

# ══════════════════════════════════════════════════════════════ ВВОД (ПК)
func _unhandled_input(e: InputEvent) -> void:
	if is_mobile:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * SENS
		pitch = clampf(pitch - e.relative.y * SENS, CAM_PITCH_MIN, CAM_PITCH_MAX)
		pivot.rotation = Vector3(pitch, yaw, 0.0)

	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_RIGHT:
			if e.pressed: shoot()
			else: release()

	if e.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE \
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			else Input.MOUSE_MODE_CAPTURED

# ══════════════════════════════════════════════════════════════ ВВОД (мобилки)
func _input(event: InputEvent) -> void:
	if not is_mobile:
		return
	if get_viewport().is_input_handled():
		return

	if event is InputEventScreenTouch:
		var half_w := get_viewport().get_visible_rect().size.x * 0.4
		if event.pressed:
			if event.position.x < half_w and joy_touch_id == -1:
				joy_touch_id = event.index
				joy_center = event.position
			elif event.position.x >= half_w and look_touch_id == -1:
				look_touch_id = event.index
				look_last = event.position
		else:
			if event.index == joy_touch_id:
				joy_touch_id = -1
				joy_vec = Vector2.ZERO
				_update_joy_knob(Vector2.ZERO)
			if event.index == look_touch_id:
				look_touch_id = -1

	elif event is InputEventScreenDrag:
		if event.index == joy_touch_id:
			joy_vec = (event.position - joy_center) / 100.0
			if joy_vec.length() > 1.0:
				joy_vec = joy_vec.normalized()
			_update_joy_knob(joy_vec)
		elif event.index == look_touch_id:
			var d: Vector2 = event.position - look_last
			look_last = event.position
			yaw -= d.x * 0.005
			pitch = clampf(pitch - d.y * 0.005, CAM_PITCH_MIN, CAM_PITCH_MAX)
			pivot.rotation = Vector3(pitch, yaw, 0.0)

func _update_joy_knob(v: Vector2) -> void:
	var layer := get_node_or_null("TouchUI")
	if layer == null: return
	var base := layer.get_node_or_null("JoyBase")
	if base == null: return
	var knob := base.get_node_or_null("JoyKnob")
	if knob == null: return
	knob.position = Vector2(75, 75) + v * 75.0

func _make_touch_btn(layer: CanvasLayer, text: String, anchor: Vector2,
					offset: Vector2, action: String) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0.18)
	s.corner_radius_top_left = 70
	s.corner_radius_top_right = 70
	s.corner_radius_bottom_left = 70
	s.corner_radius_bottom_right = 70

	var b := Button.new()
	b.text = text
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("pressed", s)
	b.add_theme_font_size_override("font_size", 48)
	b.size = Vector2(140, 140)
	b.anchor_left = anchor.x
	b.anchor_right = anchor.x
	b.anchor_top = anchor.y
	b.anchor_bottom = anchor.y
	b.offset_left = offset.x
	b.offset_top = offset.y
	b.offset_right = offset.x + 140
	b.offset_bottom = offset.y + 140
	layer.add_child(b)

	b.button_down.connect(func(): _btn_down(action))
	b.button_up.connect(func(): _btn_up(action))

func _btn_down(action: String) -> void:
	match action:
		"web": shoot()
		"reel": btn_reel = true
		"jump": btn_jump = true
		"dash": btn_dash = true

func _btn_up(action: String) -> void:
	match action:
		"web": release()
		"reel": btn_reel = false
		"jump": btn_jump = false
		"dash": btn_dash = false

# ══════════════════════════════════════════════════════════════ ПАУТИНА
func shoot() -> void:
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * WEB_RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return

	anchor = hit.position
	rope_len = maxf(MIN_ROPE, player.global_position.distance_to(anchor) + 0.5)
	web_on = true

func release() -> void:
	if not web_on:
		return
	web_on = false
	rope.visible = false

	var speed := Vector3(player.velocity.x, 0, player.velocity.z).length()
	var boost := RELEASE_BOOST + clampf(speed / MAX_SPEED, 0.0, 1.0) * 0.05
	player.velocity.x *= boost
	player.velocity.z *= boost

# ══════════════════════════════════════════════════════════════ ФИЗИКА
func _physics_process(delta: float) -> void:
	var v := player.velocity

	if not player.is_on_floor():
		v.y -= GRAVITY * delta

	var ix := 0.0
	var iz := 0.0
	if is_mobile:
		ix = joy_vec.x
		iz = joy_vec.y
	else:
		if Input.is_physical_key_pressed(KEY_W): iz -= 1.0
		if Input.is_physical_key_pressed(KEY_S): iz += 1.0
		if Input.is_physical_key_pressed(KEY_A): ix -= 1.0
		if Input.is_physical_key_pressed(KEY_D): ix += 1.0

	var fwd := -pivot.global_transform.basis.z; fwd.y = 0; fwd = fwd.normalized()
	var right := pivot.global_transform.basis.x; right.y = 0; right = right.normalized()
	var wish := right * ix + fwd * -iz
	if wish.length() > 1.0: wish = wish.normalized()

	var jump_pressed := false
	var dash_pressed := false
	var reel_now := false
	if is_mobile:
		jump_pressed = btn_jump
		dash_pressed = btn_dash
		reel_now = btn_reel
	else:
		jump_pressed = Input.is_physical_key_pressed(KEY_SPACE)
		dash_pressed = Input.is_physical_key_pressed(KEY_Q)
		reel_now = Input.is_physical_key_pressed(KEY_E)

	if web_on:
		var to_a := anchor - player.global_position
		var dist := to_a.length()

		if dist > 0.05:
			var dir := to_a / dist

			rope_len = maxf(MIN_ROPE, rope_len - AUTO_REEL * delta)
			if reel_now:
				rope_len = maxf(MIN_ROPE, rope_len - REEL * delta)

			if dist >= rope_len:
				var radial := v.dot(dir)
				if radial < 0.0:
					v -= dir * radial

			var tang_vel := v - dir * v.dot(dir)
			v -= tang_vel * SWING_DAMPING * delta * 0.3

			if wish.length() > 0.05:
				var tang := wish - dir * wish.dot(dir)
				if tang.length() > 0.01:
					v += tang.normalized() * PUMP * delta

			if v.length() > MAX_SPEED:
				v = v.normalized() * MAX_SPEED
	else:
		if player.is_on_floor():
			var speed := WALK
			if not is_mobile and Input.is_physical_key_pressed(KEY_SHIFT):
				speed = SPRINT
			var target := wish * speed
			v.x = lerpf(v.x, target.x, minf(1.0, 15.0 * delta))
			v.z = lerpf(v.z, target.z, minf(1.0, 15.0 * delta))
		else:
			if wish.length() > 0.05:
				v.x += wish.x * AIR_ACCEL * delta
				v.z += wish.z * AIR_ACCEL * delta
			v.x *= 1.0 - AIR_DRAG * delta
			v.z *= 1.0 - AIR_DRAG * delta

	if jump_pressed and not space_prev and player.is_on_floor():
		release()
		v.y = JUMP
	space_prev = jump_pressed

	dash_timer = maxf(0.0, dash_timer - delta)
	if dash_pressed and not dash_prev and dash_timer <= 0.0:
		var dash_dir := -cam.global_transform.basis.z
		dash_dir.y = 0.0
		if dash_dir.length() > 0.01:
			dash_dir = dash_dir.normalized()
			v.x += dash_dir.x * DASH_FORCE
			v.z += dash_dir.z * DASH_FORCE
			v.y = maxf(v.y, DASH_UP)
			dash_timer = DASH_COOLDOWN
			add_xp(15.0)
	dash_prev = dash_pressed

	player.velocity = v
	player.move_and_slide()

	var look_dir := Vector3.ZERO
	if web_on:
		look_dir = anchor - player.global_position
	else:
		look_dir = Vector3(v.x, 0, v.z)

	look_dir.y = 0.0
	if look_dir.length() > 1.0:
		var target_angle := atan2(-look_dir.x, -look_dir.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_angle, minf(1.0, 10.0 * delta))

	var roll := 0.0
	if web_on:
		var side := pivot.global_transform.basis.x
		roll = -clampf(v.dot(side) / MAX_SPEED, -0.5, 0.5)
	visual.rotation.z = lerpf(visual.rotation.z, roll, minf(1.0, 8.0 * delta))

	var xp_gain := 0.0
	if web_on:
		xp_gain += 8.0
	var alt := player.global_position.y
	if alt > 15.0:
		xp_gain += minf(10.0, alt / 12.0)
	if xp_gain > 0.0:
		add_xp(xp_gain * delta)

	var hs := Vector3(v.x, 0, v.z).length()
	cam.fov = lerpf(cam.fov, lerpf(FOV_BASE, FOV_FAST, clampf(hs / MAX_SPEED, 0.0, 1.0)), minf(1.0, 6.0 * delta))

	_draw_rope()

# ══════════════════════════════════════════════════════════════ НИТЬ
func _draw_rope() -> void:
	if not web_on:
		rope.visible = false
		return

	var hand := player.global_position \
		+ pivot.global_transform.basis.x * 0.3 \
		+ Vector3.UP * 1.3

	var d := anchor - hand
	var L := d.length()
	if L < 0.01:
		rope.visible = false
		return

	rope.visible = true
	var axis := d / L
	var ref := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var side := ref.cross(axis).normalized()
	var up2 := side.cross(axis).normalized()
	rope.global_transform = Transform3D(Basis(side, axis * L, up2), (hand + anchor) * 0.5)
