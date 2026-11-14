extends Node2D
## Fishing Voyage — Prototype 0.6.0 (satu pemain).
## Loop inti: jalan di pelabuhan -> naik perahu sistem -> berlayar OTOMATIS ke
## spot mancing -> mancing -> pindah spot bebas -> PULANG otomatis -> jual ikan.
## Kontrol: joystick virtual + WASD/panah. Semua node dibangun dari kode
## supaya mudah diuji otomatis.

const TILE := "res://assets/kenney/tiny-town/Tiles/tile_%04d.png"
const TILE_D := "res://assets/kenney/tiny-dungeon/Tiles/tile_%04d.png"
const FISH := "res://assets/kenney/fish-pack/PNG/Default/"
const SUARA := "res://assets/kenney/interface-sounds/Audio/"

const WORLD_W := 6400.0
const LAND_W := 820.0        # darat berakhir di x ini
const SAND_W := 880.0        # pantai berakhir, air mulai
const DOCK_RECT := Rect2(872, 330, 190, 62)   # area dermaga kayu
const DOCK2_RECT := Rect2(872, 474, 190, 62)  # dermaga kedua untuk Perahu Motor
const DOCK3_RECT := Rect2(872, 618, 190, 62)  # dermaga ketiga untuk Kapal Nelayan
const BOAT_HOME := Vector2(1015, 361)         # posisi tambat Perahu Kayu
const SEA_X := 1500.0        # mancing hanya boleh mulai x ini (Zona Dekat)
const TENGAH_X := 2900.0     # Zona Tengah mulai x ini
const LEPAS_X := 4700.0      # Zona Lepas mulai x ini
const KAYU_MAX_X := 2240.0   # Perahu Kayu tidak boleh menerobos lebih jauh
const MOTOR_MAX_X := 4040.0  # Perahu Motor tidak boleh menerobos lebih jauh
const BOATS := {
	"kayu": {"nama": "Perahu Kayu", "sewa": 7500, "cepat": 175.0, "drain": 3.5, "home": Vector2(1015, 361)},
	"motor": {"nama": "Perahu Motor", "sewa": 20000, "cepat": 235.0, "drain": 4.0, "home": Vector2(1015, 505)},
	"nelayan": {"nama": "Kapal Nelayan", "sewa": 60000, "cepat": 290.0, "drain": 2.5, "home": Vector2(1015, 649)},
}
const STALL_POS := Vector2(255, 322)          # pembeli ikan
const PLAYER_SPEED := 135.0
const BOAT_SPEED := 175.0
const FUEL_MAX := 100.0
const FUEL_DRAIN := 3.5      # per detik saat perahu bergerak
# Joystick virtual (kiri bawah layar) dan titik spot mancing otomatis
const JOYSTICK_CENTER := Vector2(94, 612)
const JOYSTICK_RADIUS := 58.0
const JOYSTICK_KNOB_RADIUS := 23.0
const JOYSTICK_DEADZONE := 0.10
const KAYU_SPOT := Vector2(1800, 360)    # spot otomatis Perahu Kayu (Zona Dekat)
const MOTOR_SPOT := Vector2(3300, 360)   # spot otomatis Perahu Motor (Zona Tengah)
const NELAYAN_SPOT := Vector2(5100, 360) # spot otomatis Kapal Nelayan (Zona Lepas)

var mode := "jalan"          # "jalan" | "perahu"
var coins := 0
var inventory: Array = []    # {nama, berat, harga, ikon}
var fuel := FUEL_MAX
var rng := RandomNumberGenerator.new()

var player_pos := Vector2(330, 430)
var boat_pos := BOAT_HOME
var facing := 1.0

# status mancing: "" | "tunggu" | "gigit"
var fish_state := ""
var fish_timer := 0.0
var bite_wait := 0.0

const SAVE_PATH := "user://fishing_voyage_save.cfg"
const FUEL_PRICE := 120
const TOW_FEE := 15000

var trips_done := 0
var collection: Dictionary = {}   # nama spesies -> {"jumlah": int, "terberat": float}
var rigs := {}                    # kunci perahu -> node/posisi/tambatannya
var active_boat := ""             # "" di darat; "kayu" | "motor" saat berlayar
var zone_warned := false
var pending_species: Dictionary = {}
var bite_window := 1.1
var fish_zone := "dekat"
var trip_n := 0
var trip_kg := 0.0
var trip_rp := 0
var waves: Array = []
var shadows: Array = []
var gulls: Array = []

var demo_mode := false
var demo_phase := 0
var demo_dir := Vector2.ZERO
var demo_t := 0.0
var demo_catches := 0

var time_passed := 0.0
var toast_timer := 0.0
var prev_action := false
var touch_dir := Vector2.ZERO
var touch_action := false
var prev_touch_action := false
var popups: Array = []

# Perjalanan otomatis: "" | "berangkat" (ke spot) | "pulang" (ke dermaga)
var auto_sailing := ""
var auto_target := Vector2.ZERO
# Joystick virtual
var joystick_vector := Vector2.ZERO
var joystick_touch_index := -1
var joystick_mouse_active := false
var joystick_root: Node2D
var joystick_base: Polygon2D
var joystick_knob: Polygon2D

var player_sprite: Sprite2D
var boat_node: Node2D
var boat_visual: Node2D
var boat_label: Label
var boat_rider: Sprite2D
var camera: Camera2D
var bobber: Node2D
var fish_line: Line2D
var bite_mark: Label
var audio: AudioStreamPlayer

var hud_coins: Label
var hud_fish: Label
var hud_zone: Label
var hud_prompt: Label
var hud_toast: Label
var hud_fuel: ProgressBar
var hud_fuel_label: Label
var act_button: Button
var return_button: Button
var collection_panel: PanelContainer
var collection_box: VBoxContainer

func _ready() -> void:
	rng.randomize()
	build_world()
	build_hud()
	load_game()
	show_toast("Selamat datang di Pelabuhan Wapalo! Jual ikan di kios, naik perahu di dermaga.")
	if "--foto" in OS.get_cmdline_user_args():
		_capture_later()
	if "--demo" in OS.get_cmdline_user_args():
		demo_mode = true

func tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func tile_sprite(idx: int, pos: Vector2, parent: Node = self, dungeon := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex((TILE_D if dungeon else TILE) % idx)
	s.position = pos
	s.scale = Vector2(2, 2)
	parent.add_child(s)
	return s

func ground_poly(rect: Rect2, texture_path: String, color := Color.WHITE) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)])
	p.polygon = pts
	if texture_path != "":
		p.texture = tex(texture_path)
		p.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		var uvs := PackedVector2Array()
		for pt in pts:
			uvs.append(pt / 2.0)
		p.uv = uvs
	p.color = color
	add_child(p)
	return p

func flat_poly(points: PackedVector2Array, color: Color, parent: Node) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	parent.add_child(p)
	return p

func world_label(text: String, pos: Vector2, size := 15, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	add_child(l)
	return l

func build_world() -> void:
	# Air laut (datar + garis ombak dekoratif yang hanyut perlahan)
	ground_poly(Rect2(SAND_W, 0, WORLD_W - SAND_W, 720), "", Color("1b6ca8"))
	for i in 40:
		var w := flat_poly(PackedVector2Array([Vector2(-22, -1.5), Vector2(22, -1.5), Vector2(22, 1.5), Vector2(-22, 1.5)]),
			Color(1, 1, 1, 0.16), self)
		w.position = Vector2(rng.randf_range(SAND_W + 80, WORLD_W - 60), rng.randf_range(30, 690))
		w.set_meta("wave", true)
		waves.append(w)
	# Darat: rumput + hamparan tanah di sekitar kios + jalan tanah ke dermaga
	ground_poly(Rect2(0, 0, LAND_W, 720), TILE % 0)
	ground_poly(Rect2(150, 250, 250, 190), TILE % 25)
	ground_poly(Rect2(390, 388, 470, 34), TILE % 25)
	# Pantai pasir + buih tepi air
	ground_poly(Rect2(LAND_W, 0, SAND_W - LAND_W, 720), TILE % 41)
	ground_poly(Rect2(SAND_W - 4, 0, 7, 720), "", Color(1, 1, 1, 0.45))
	# Dua dermaga kayu (satu untuk tiap perahu sewaan)
	for rect in [DOCK_RECT, DOCK2_RECT, DOCK3_RECT]:
		ground_poly(rect, "", Color("9a6a38"))
		for i in 6:
			var x: float = rect.position.x + 14.0 + i * 31.0
			flat_poly(PackedVector2Array([Vector2(x, rect.position.y + 3), Vector2(x + 3, rect.position.y + 3),
				Vector2(x + 3, rect.end.y - 3), Vector2(x, rect.end.y - 3)]), Color(0, 0, 0, 0.16), self)
		for py in [rect.position.y + 8, rect.end.y - 8]:
			for px in [rect.position.x + 8, rect.end.x - 22]:
				flat_poly(PackedVector2Array([Vector2(px, py), Vector2(px + 12, py), Vector2(px + 12, py + 10), Vector2(px, py + 10)]), Color("6e4a22"), self)
	# Pohon dan pagar dekorasi (tile 5 = pohon bulat utuh, 4+16 = pinus tinggi, 8 = pinus kecil, 10 = pohon musim gugur)
	for pos in [Vector2(80, 90), Vector2(180, 130), Vector2(90, 560), Vector2(620, 90), Vector2(720, 620), Vector2(520, 640), Vector2(700, 180)]:
		match rng.randi_range(0, 3):
			0:
				tile_sprite(5, pos)
			1:
				tile_sprite(4, pos - Vector2(0, 16))
				tile_sprite(16, pos + Vector2(0, 16))
			2:
				tile_sprite(8, pos)
			_:
				tile_sprite(10, pos)
	tile_sprite(6, Vector2(140, 620))
	tile_sprite(6, Vector2(660, 250))
	for base_x in [70.0, 230.0]:
		tile_sprite(45, Vector2(base_x, 205))
		tile_sprite(46, Vector2(base_x + 32, 205))
		tile_sprite(47, Vector2(base_x + 64, 205))
	# Rumah sederhana di belakang kios
	var hx := 520.0
	var hy := 120.0
	tile_sprite(52, Vector2(hx, hy)); tile_sprite(53, Vector2(hx + 32, hy)); tile_sprite(54, Vector2(hx + 64, hy))
	tile_sprite(84, Vector2(hx, hy + 32)); tile_sprite(85, Vector2(hx + 32, hy + 32)); tile_sprite(89, Vector2(hx + 64, hy + 32))
	# Kios pembeli ikan: meja, peti, papan, NPC
	tile_sprite(72, STALL_POS + Vector2(-16, 14), self, true)
	tile_sprite(75, STALL_POS + Vector2(30, 16), self, true)
	tile_sprite(83, STALL_POS + Vector2(2, -34))
	var npc := tile_sprite(99, STALL_POS + Vector2(0, -6), self, true)
	npc.z_index = 2
	world_label("PEMBELI IKAN", STALL_POS + Vector2(-52, -66), 15, Color("ffe9a8"))
	# Papan dermaga dan pelampung batas zona
	tile_sprite(83, Vector2(905, 300))
	world_label("DERMAGA", Vector2(872, 268), 15, Color("ffe9a8"))
	for i in 5:
		var b := flat_poly(PackedVector2Array([Vector2(-7, -7), Vector2(7, -7), Vector2(7, 7), Vector2(-7, 7)]), Color("ff8c42"), self)
		b.position = Vector2(SEA_X, 70 + i * 145)
	world_label("ZONA DEKAT", Vector2(SEA_X - 52, 26), 15, Color("cfeeff"))
	for i in 5:
		var b2 := flat_poly(PackedVector2Array([Vector2(-7, -7), Vector2(7, -7), Vector2(7, 7), Vector2(-7, 7)]), Color("e33f2f"), self)
		b2.position = Vector2(TENGAH_X, 70 + i * 145)
	world_label("ZONA TENGAH", Vector2(TENGAH_X - 58, 26), 15, Color("ffd9d0"))
	for i in 5:
		var b3 := flat_poly(PackedVector2Array([Vector2(-7, -7), Vector2(7, -7), Vector2(7, 7), Vector2(-7, 7)]), Color("7e57c2"), self)
		b3.position = Vector2(LEPAS_X, 70 + i * 145)
	world_label("ZONA LEPAS", Vector2(LEPAS_X - 55, 26), 15, Color("e6d7ff"))
	# Bayangan ikan berkeliaran di laut (hidup, bukan sekadar dekorasi diam)
	for i in 7:
		var sh := flat_poly(_circle_points(16.0), Color(0, 0, 0, 0.16), self)
		sh.scale = Vector2(1.6, 0.55)
		sh.position = Vector2(rng.randf_range(1600, WORLD_W - 200), rng.randf_range(100, 640))
		shadows.append({"node": sh, "vel": Vector2(rng.randf_range(14, 30) * (1.0 if i % 2 == 0 else -1.0), 0.0), "fasa": rng.randf() * 6.28})
	# Burung camar melintasi laut (garis putih + bayangannya di air)
	for i in 2:
		var g := Line2D.new()
		g.width = 2.0
		g.default_color = Color(1, 1, 1, 0.85)
		g.points = PackedVector2Array([Vector2(-11, 0), Vector2(-3, -5), Vector2(0, 0), Vector2(3, -5), Vector2(11, 0)])
		add_child(g)
		var bay := Line2D.new()
		bay.width = 2.0
		bay.default_color = Color(0, 0, 0, 0.13)
		bay.points = g.points
		add_child(bay)
		gulls.append({"node": g, "bay": bay, "pos": Vector2(rng.randf_range(1000, 3000), 120.0 + i * 110.0), "cepat": 34.0 + i * 9.0, "fasa": rng.randf() * 6.28})
	# Perahu sewaan (digambar dari poligon, sprite perahu belum ada di paket gratis)
	rigs["kayu"] = build_boat("kayu")
	rigs["motor"] = build_boat("motor")
	rigs["nelayan"] = build_boat("nelayan")
	set_active_rig("kayu")
	# Pemain
	player_sprite = Sprite2D.new()
	player_sprite.texture = tex(TILE_D % 85)
	player_sprite.scale = Vector2(2, 2)
	player_sprite.position = player_pos
	player_sprite.z_index = 3
	add_child(player_sprite)
	# Pelampung pancing + tali + tanda gigitan (tersembunyi dulu)
	bobber = Node2D.new()
	var bb := flat_poly(PackedVector2Array([Vector2(-5, -5), Vector2(5, -5), Vector2(5, 1), Vector2(-5, 1)]), Color("e33f2f"), bobber)
	bb.z_index = 4
	flat_poly(PackedVector2Array([Vector2(-5, 1), Vector2(5, 1), Vector2(5, 5), Vector2(-5, 5)]), Color.WHITE, bobber).z_index = 4
	bobber.visible = false
	add_child(bobber)
	fish_line = Line2D.new()
	fish_line.width = 1.5
	fish_line.default_color = Color(1, 1, 1, 0.7)
	fish_line.visible = false
	fish_line.z_index = 3
	add_child(fish_line)
	bite_mark = world_label("!", Vector2.ZERO, 34, Color("ffd93b"))
	bite_mark.visible = false
	bite_mark.z_index = 5
	# Kamera
	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)
	camera.make_current()
	# Audio
	audio = AudioStreamPlayer.new()
	add_child(audio)

func _circle_points(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

# Membangun satu perahu sewaan lengkap dengan label dan penumpangnya.
func build_boat(key: String) -> Dictionary:
	var info: Dictionary = BOATS[key]
	var home: Vector2 = info["home"]
	var node := Node2D.new()
	node.position = home
	add_child(node)
	var visual := Node2D.new()
	node.add_child(visual)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("cfeeff"))
	var label_x := -52.0
	if key == "kayu":
		flat_poly(PackedVector2Array([Vector2(-56, -17), Vector2(30, -17), Vector2(58, 0), Vector2(30, 17), Vector2(-56, 17), Vector2(-70, 0)]), Color("7a4a21"), visual)
		flat_poly(PackedVector2Array([Vector2(-48, -12), Vector2(26, -12), Vector2(46, 0), Vector2(26, 12), Vector2(-48, 12), Vector2(-58, 0)]), Color("c89b62"), visual)
		for bx in [-26.0, 4.0]:
			flat_poly(PackedVector2Array([Vector2(bx, -12), Vector2(bx + 8, -12), Vector2(bx + 8, 12), Vector2(bx, 12)]), Color("8a5a2b"), visual)
		flat_poly(PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)]), Color("5d3a17"), visual)
		label.text = "PERAHU KAYU"
		label.position = Vector2(-52, -46)
	elif key == "motor":
		flat_poly(PackedVector2Array([Vector2(-84, -20), Vector2(52, -20), Vector2(88, 0), Vector2(52, 20), Vector2(-84, 20), Vector2(-100, 0)]), Color("2f6f79"), visual)
		flat_poly(PackedVector2Array([Vector2(-76, -14), Vector2(48, -14), Vector2(74, 0), Vector2(48, 14), Vector2(-76, 14), Vector2(-88, 0)]), Color("9fc6cf"), visual)
		flat_poly(PackedVector2Array([Vector2(-16, -13), Vector2(30, -13), Vector2(30, 13), Vector2(-16, 13)]), Color("e8f2f4"), visual)
		flat_poly(PackedVector2Array([Vector2(-10, -8), Vector2(24, -8), Vector2(24, 8), Vector2(-10, 8)]), Color("b9d6dd"), visual)
		flat_poly(PackedVector2Array([Vector2(-102, -9), Vector2(-88, -9), Vector2(-88, 9), Vector2(-102, 9)]), Color("263238"), visual)
		label.text = "PERAHU MOTOR"
		label.position = Vector2(-56, -52)
		label_x = -56.0
	else:
		# Kapal Nelayan: lambung besar merah bata, dek krem, kabin + tiang
		flat_poly(PackedVector2Array([Vector2(-118, -26), Vector2(74, -26), Vector2(122, 0), Vector2(74, 26), Vector2(-118, 26), Vector2(-138, 0)]), Color("7a2e22"), visual)
		flat_poly(PackedVector2Array([Vector2(-108, -19), Vector2(68, -19), Vector2(104, 0), Vector2(68, 19), Vector2(-108, 19), Vector2(-122, 0)]), Color("d9b380"), visual)
		flat_poly(PackedVector2Array([Vector2(-30, -17), Vector2(28, -17), Vector2(28, 17), Vector2(-30, 17)]), Color("e8f2f4"), visual)
		flat_poly(PackedVector2Array([Vector2(-22, -10), Vector2(20, -10), Vector2(20, 10), Vector2(-22, 10)]), Color("8fb6c4"), visual)
		flat_poly(PackedVector2Array([Vector2(44, -3), Vector2(48, -3), Vector2(48, 3), Vector2(44, 3)]), Color("4a2c14"), visual)
		flat_poly(PackedVector2Array([Vector2(-140, -11), Vector2(-124, -11), Vector2(-124, 11), Vector2(-140, 11)]), Color("263238"), visual)
		label.text = "KAPAL NELAYAN"
		label.position = Vector2(-64, -62)
		label_x = -64.0
	visual.add_child(label)
	var rider := Sprite2D.new()
	rider.texture = tex(TILE_D % 85)
	rider.scale = Vector2(2, 2)
	rider.position = Vector2(-8, -10) if key == "kayu" else (Vector2(6, -2) if key == "motor" else Vector2(0, -6))
	rider.visible = false
	visual.add_child(rider)
	return {"node": node, "visual": visual, "label": label, "rider": rider, "pos": home, "home": home, "label_x": label_x}

# Menunjuk perahu yang sedang aktif dipakai (variabel boat_* mengikuti perahu ini).
func set_active_rig(key: String) -> void:
	boat_node = rigs[key]["node"]
	boat_visual = rigs[key]["visual"]
	boat_label = rigs[key]["label"]
	boat_rider = rigs[key]["rider"]

func make_label(parent: Node, text: String, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 10)
	layer.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	hud_coins = make_label(vb, "", 19, Color("ffd93b"))
	hud_fish = make_label(vb, "", 16)
	var fuel_row := HBoxContainer.new()
	vb.add_child(fuel_row)
	hud_fuel_label = make_label(fuel_row, "Bahan bakar", 14)
	hud_fuel = ProgressBar.new()
	hud_fuel.min_value = 0
	hud_fuel.max_value = FUEL_MAX
	hud_fuel.custom_minimum_size = Vector2(130, 14)
	fuel_row.add_child(hud_fuel)
	hud_zone = make_label(layer, "", 18, Color("cfeeff"))
	hud_zone.position = Vector2(500, 12)
	hud_prompt = make_label(layer, "", 19, Color("ffe9a8"))
	hud_prompt.position = Vector2(390, 668)
	hud_toast = make_label(layer, "", 18, Color.WHITE)
	hud_toast.position = Vector2(290, 84)
	# Latar gelap tipis supaya teks terbaca di atas rumput terang maupun air
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8.0)
	hud_prompt.add_theme_stylebox_override("normal", sb)
	hud_toast.add_theme_stylebox_override("normal", sb.duplicate())
	# Tombol KOLEKSI + panel album ikan
	var btn_kol := Button.new()
	btn_kol.text = "KOLEKSI"
	btn_kol.position = Vector2(1150, 10)
	btn_kol.custom_minimum_size = Vector2(118, 38)
	btn_kol.modulate.a = 0.9
	btn_kol.pressed.connect(toggle_collection)
	layer.add_child(btn_kol)
	collection_panel = PanelContainer.new()
	collection_panel.position = Vector2(806, 56)
	collection_panel.custom_minimum_size = Vector2(462, 0)
	collection_panel.visible = false
	layer.add_child(collection_panel)
	collection_box = VBoxContainer.new()
	collection_panel.add_child(collection_box)
	# Joystick virtual di kiri bawah: lingkaran dasar diam, knob mengikuti sentuhan
	joystick_root = Node2D.new()
	joystick_root.position = JOYSTICK_CENTER
	layer.add_child(joystick_root)
	joystick_base = flat_poly(_circle_points(JOYSTICK_RADIUS), Color(0.08, 0.12, 0.16, 0.48), joystick_root)
	joystick_knob = flat_poly(_circle_points(JOYSTICK_KNOB_RADIUS), Color(0.85, 0.91, 0.96, 0.82), joystick_root)
	# Tombol PULANG (hanya tampil saat bebas berlayar di laut)
	return_button = Button.new()
	return_button.text = "PULANG"
	return_button.position = Vector2(1010, 500)
	return_button.custom_minimum_size = Vector2(122, 58)
	return_button.modulate.a = 0.9
	return_button.visible = false
	return_button.pressed.connect(request_return)
	layer.add_child(return_button)
	# Tombol AKSI di kanan bawah
	act_button = Button.new()
	act_button.text = "AKSI"
	act_button.position = Vector2(1142, 576)
	act_button.custom_minimum_size = Vector2(122, 72)
	act_button.modulate.a = 0.85
	act_button.button_down.connect(func() -> void: touch_action = true)
	act_button.button_up.connect(func() -> void: touch_action = false)
	layer.add_child(act_button)

# ---------- Joystick virtual (sentuh + mouse untuk uji di desktop) ----------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			if joystick_touch_index == -1 and e.position.distance_to(JOYSTICK_CENTER) <= JOYSTICK_RADIUS + 35.0:
				joystick_touch_index = e.index
				_update_joystick(e.position)
				get_viewport().set_input_as_handled()
		elif e.index == joystick_touch_index:
			joystick_touch_index = -1
			_reset_joystick()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if e.index == joystick_touch_index:
			_update_joystick(e.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				if e.position.distance_to(JOYSTICK_CENTER) <= JOYSTICK_RADIUS + 35.0:
					joystick_mouse_active = true
					_update_joystick(e.position)
					get_viewport().set_input_as_handled()
			elif joystick_mouse_active:
				joystick_mouse_active = false
				_reset_joystick()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and joystick_mouse_active:
		var e := event as InputEventMouseMotion
		_update_joystick(e.position)
		get_viewport().set_input_as_handled()

func _update_joystick(screen_pos: Vector2) -> void:
	var offset := screen_pos - JOYSTICK_CENTER
	offset = offset.limit_length(JOYSTICK_RADIUS)
	joystick_knob.position = offset
	var strength := offset.length() / JOYSTICK_RADIUS
	if strength < JOYSTICK_DEADZONE:
		joystick_vector = Vector2.ZERO
	else:
		joystick_vector = offset.normalized() * strength
	touch_dir = joystick_vector

func _reset_joystick() -> void:
	joystick_vector = Vector2.ZERO
	touch_dir = Vector2.ZERO
	joystick_knob.position = Vector2.ZERO

func toggle_collection() -> void:
	collection_panel.visible = not collection_panel.visible
	if collection_panel.visible:
		refresh_collection_panel()
	play_sound("click_001.ogg")

func refresh_collection_panel() -> void:
	if collection_box == null or not collection_panel.visible:
		return
	for ch in collection_box.get_children():
		collection_box.remove_child(ch)
		ch.queue_free()
	make_label(collection_box, "Koleksi Ikan (%d/%d spesies)" % [collection.size(), FishData.SPECIES.size()], 17, Color("ffd93b"))
	for sp in FishData.SPECIES:
		var nama := String(sp["nama"])
		var baris := make_label(collection_box, "", 14)
		if collection.has(nama):
			var rec: Dictionary = collection[nama]
			baris.text = "%s (%s, Zona %s) — %d ekor, terberat %.1f kg" % [nama, String(sp["raritas"]), String(sp["zona"]).capitalize(), int(rec["jumlah"]), float(rec["terberat"])]
		else:
			baris.text = "%s (%s, Zona %s) — belum ditemukan" % [nama, String(sp["raritas"]), String(sp["zona"]).capitalize()]
			baris.modulate.a = 0.55

func format_rp(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return "Rp " + s + out

func inventory_weight() -> float:
	var w := 0.0
	for f in inventory:
		w += float(f["berat"])
	return w

func inventory_value() -> int:
	var v := 0
	for f in inventory:
		v += int(f["harga"])
	return v

func play_sound(file: String) -> void:
	var path := SUARA + file
	if ResourceLoader.exists(path):
		audio.stream = load(path)
		audio.play()

func show_toast(text: String, dur := 3.2) -> void:
	hud_toast.text = text
	hud_toast.modulate.a = 1.0
	toast_timer = dur

func add_popup(text: String, pos: Vector2, color := Color.WHITE, ukuran := 17) -> void:
	var l := world_label(text, pos, ukuran, color)
	l.z_index = 6
	popups.append({"node": l, "t": 0.0})

func near_stall() -> bool:
	return mode == "jalan" and player_pos.distance_to(STALL_POS) < 78.0

func near_boat() -> bool:
	return nearest_boat_key() != ""

func nearest_boat_key() -> String:
	if mode != "jalan":
		return ""
	var best := ""
	var best_d := 86.0
	for key in rigs.keys():
		var dd: float = player_pos.distance_to(rigs[key]["pos"])
		if dd < best_d:
			best_d = dd
			best = key
	return best

func boat_near_dock() -> bool:
	if active_boat == "":
		return boat_pos.distance_to(BOAT_HOME) < 90.0
	return boat_pos.distance_to(rigs[active_boat]["home"]) < 90.0

func in_sea() -> bool:
	return boat_pos.x >= SEA_X

func zona_saat_ini() -> String:
	if boat_pos.x >= LEPAS_X:
		return "lepas"
	if boat_pos.x >= TENGAH_X:
		return "tengah"
	if boat_pos.x >= SEA_X:
		return "dekat"
	return "pelabuhan"

# Batas gerak perahu: tepi dunia + gerbang zona per kelas perahu.
func clamp_boat() -> void:
	boat_pos.x = clampf(boat_pos.x, 940.0, WORLD_W - 50.0)
	boat_pos.y = clampf(boat_pos.y, 64.0, 656.0)
	if active_boat == "kayu" and boat_pos.x > KAYU_MAX_X:
		boat_pos.x = KAYU_MAX_X
		if not zone_warned:
			zone_warned = true
			show_toast("Perahu Kayu tidak aman menerobos ke Zona Tengah. Sewa Perahu Motor di dermaga.")
	elif active_boat == "motor" and boat_pos.x > MOTOR_MAX_X:
		boat_pos.x = MOTOR_MAX_X
		if not zone_warned:
			zone_warned = true
			show_toast("Perahu Motor tidak aman menerobos ke Zona Lepas. Sewa Kapal Nelayan di dermaga.")

# ---------- Simpan dan muat progres ----------

func save_game() -> void:
	var c := ConfigFile.new()
	c.set_value("progres", "koin", coins)
	c.set_value("progres", "trips", trips_done)
	c.set_value("progres", "bbm", fuel)
	c.set_value("progres", "inventaris", inventory)
	c.set_value("progres", "koleksi", collection)
	c.save(SAVE_PATH)

func load_game() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) == OK:
		coins = int(c.get_value("progres", "koin", 0))
		trips_done = int(c.get_value("progres", "trips", 0))
		fuel = float(c.get_value("progres", "bbm", FUEL_MAX))
		var inv = c.get_value("progres", "inventaris", [])
		if inv is Array:
			inventory = inv
		var kol = c.get_value("progres", "koleksi", {})
		if kol is Dictionary:
			collection = kol

# ---------- Perjalanan otomatis (berangkat ke spot / pulang ke dermaga) ----------

func begin_auto_sailing(target: Vector2, purpose: String) -> void:
	auto_target = target
	auto_sailing = purpose
	_reset_joystick()

func advance_auto_sailing(delta: float) -> void:
	if auto_sailing == "" or mode != "perahu" or active_boat == "":
		return
	var info: Dictionary = BOATS[active_boat]
	var speed := float(info["cepat"])
	var drain := float(info["drain"])
	var to_target := auto_target - boat_pos
	var dist := to_target.length()
	if dist < 1.0:
		boat_pos = auto_target
		_finish_auto_sailing()
		return
	var step := minf(dist, speed * delta)
	var max_by_fuel := fuel / drain * speed
	if step > max_by_fuel:
		# BBM habis di tengah perjalanan: berhenti, pemain bisa minta derek (AKSI).
		boat_pos += to_target.normalized() * max_by_fuel
		fuel = 0.0
		auto_sailing = ""
		clamp_boat()
		rigs[active_boat]["pos"] = boat_pos
		show_toast("Bahan bakar habis di tengah perjalanan! Tekan AKSI untuk minta derek.")
		play_sound("error_001.ogg")
		return
	boat_pos += to_target.normalized() * step
	fuel = maxf(0.0, fuel - drain * (step / speed))
	clamp_boat()
	rigs[active_boat]["pos"] = boat_pos
	if boat_pos.distance_to(auto_target) < 1.0:
		boat_pos = auto_target
		_finish_auto_sailing()

# Melewati sisa perjalanan sekaligus (tombol AKSI saat berangkat).
func finish_auto_sailing() -> void:
	advance_auto_sailing(100000.0)

func _finish_auto_sailing() -> void:
	if auto_sailing == "":
		return
	var purpose := auto_sailing
	auto_sailing = ""
	boat_pos = auto_target
	if purpose == "berangkat":
		show_toast("Sampai di spot mancing Zona %s. Geser perahu untuk pindah spot, lempar kail bila siap." % zona_saat_ini().capitalize())
		play_sound("confirmation_001.ogg")
	elif purpose == "pulang":
		disembark()

func request_return() -> void:
	if mode != "perahu" or auto_sailing != "" or not in_sea():
		return
	if fish_state != "":
		cancel_fishing()
	begin_auto_sailing(Vector2(rigs[active_boat]["home"]), "pulang")
	show_toast("Berlayar otomatis kembali ke dermaga...")
	play_sound("click_001.ogg")

# ---------- Aksi permainan (dipakai input dan uji otomatis) ----------

func board_boat() -> bool:
	var key := nearest_boat_key()
	if key == "":
		return false
	var info: Dictionary = BOATS[key]
	var sewa := int(info["sewa"]) if trips_done > 0 else 0
	var biaya_bbm := int(round(FUEL_MAX - fuel)) * FUEL_PRICE
	var total := sewa + biaya_bbm
	var ditanggung := false
	if coins < total:
		if inventory.is_empty():
			ditanggung = true
		else:
			show_toast("Koin kurang: perlu %s (sewa + BBM). Jual ikan dulu." % format_rp(total))
			play_sound("error_001.ogg")
			return false
	if not ditanggung:
		coins -= total
	fuel = FUEL_MAX
	active_boat = key
	set_active_rig(key)
	boat_pos = Vector2(rigs[key]["pos"])
	zone_warned = false
	trip_n = 0
	trip_kg = 0.0
	trip_rp = 0
	mode = "perahu"
	player_sprite.visible = false
	boat_rider.visible = true
	play_sound("click_001.ogg")
	begin_auto_sailing(KAYU_SPOT if key == "kayu" else (MOTOR_SPOT if key == "motor" else NELAYAN_SPOT), "berangkat")
	if ditanggung:
		show_toast("Koin habis dan tangan kosong: perjalanan ini ditanggung sistem dulu. Perahu berlayar otomatis ke spot mancing.")
	elif trips_done == 0:
		show_toast("Perjalanan pertama: sewa gratis dari sistem. Perahu berlayar otomatis ke spot mancing.")
	elif total > 0:
		show_toast("Sewa %s %s + BBM %s. Perahu berlayar otomatis ke spot mancing." % [String(info["nama"]), format_rp(sewa), format_rp(biaya_bbm)])
	else:
		show_toast("Naik %s. Perahu berlayar otomatis ke spot mancing." % String(info["nama"]))
	save_game()
	return true

func disembark() -> bool:
	if mode != "perahu" or not boat_near_dock() or fish_state != "":
		return false
	rigs[active_boat]["pos"] = rigs[active_boat]["home"]
	boat_node.position = rigs[active_boat]["home"]
	active_boat = ""
	boat_pos = Vector2(rigs["kayu"]["pos"])
	mode = "jalan"
	player_pos = Vector2(985, 361)
	player_sprite.visible = true
	boat_rider.visible = false
	trips_done += 1
	if trip_n > 0:
		show_toast("Turun di dermaga. Hasil perjalanan: %d ekor, %.1f kg, nilai %s." % [trip_n, trip_kg, format_rp(trip_rp)], 5.0)
	else:
		show_toast("Turun di dermaga.")
	play_sound("click_001.ogg")
	save_game()
	return true

func start_fishing() -> bool:
	if mode != "perahu" or not in_sea() or fish_state != "":
		return false
	fish_zone = zona_saat_ini()
	pending_species = {}
	fish_state = "tunggu"
	fish_timer = 0.0
	bite_wait = rng.randf_range(2.0, 4.5)
	bobber.position = boat_pos + Vector2(74, 30)
	bobber.visible = true
	fish_line.points = PackedVector2Array([boat_pos + Vector2(30, -6), bobber.position])
	fish_line.visible = true
	play_sound("click_002.ogg")
	return true

func debug_force_bite() -> void:
	if fish_state == "tunggu":
		fish_timer = bite_wait

func cancel_fishing(lepas := false) -> void:
	fish_state = ""
	pending_species = {}
	fish_timer = 0.0
	bobber.visible = false
	fish_line.visible = false
	bite_mark.visible = false
	if lepas:
		play_sound("error_001.ogg")
		show_toast("Ikannya lepas! Tekan AKSI tepat saat tanda ! muncul.")

func resolve_catch() -> void:
	var sp: Dictionary = pending_species if not pending_species.is_empty() else FishData.pilih_spesies(rng, fish_zone)
	pending_species = {}
	var berat := snappedf(rng.randf_range(float(sp["berat_min"]), float(sp["berat_maks"])), 0.1)
	var harga := int(round(berat * float(sp["harga_kg"])))
	inventory.append({"nama": sp["nama"], "berat": berat, "harga": harga, "ikon": sp["ikon"]})
	var nama := String(sp["nama"])
	var rec: Dictionary = collection.get(nama, {"jumlah": 0, "terberat": 0.0})
	rec["jumlah"] = int(rec["jumlah"]) + 1
	rec["terberat"] = maxf(float(rec["terberat"]), berat)
	collection[nama] = rec
	trip_n += 1
	trip_kg += berat
	trip_rp += harga
	fish_state = ""
	bobber.visible = false
	fish_line.visible = false
	bite_mark.visible = false
	var rar := String(sp["raritas"])
	if rar == "Epik":
		play_sound("confirmation_004.ogg")
		add_popup("EPIK! + %s %.1f kg" % [nama, berat], boat_pos + Vector2(-60, -60), Color("ffb74d"), 22)
		show_toast("LUAR BIASA! Dapat %s %.1f kg (%s)!" % [nama, berat, format_rp(harga)])
	elif rar == "Langka":
		play_sound("confirmation_003.ogg")
		add_popup("+ %s %.1f kg" % [nama, berat], boat_pos + Vector2(-40, -56), Color("ffd93b"), 20)
		show_toast("Dapat %s %.1f kg (%s)! Masuk inventaris." % [nama, berat, format_rp(harga)])
	else:
		play_sound("confirmation_001.ogg")
		add_popup("+ %s %.1f kg" % [nama, berat], boat_pos + Vector2(-40, -56), Color("b8ffb0"))
		show_toast("Dapat %s %.1f kg (%s)! Masuk inventaris." % [nama, berat, format_rp(harga)])
	save_game()
	refresh_collection_panel()

func sell_all() -> int:
	if not near_stall():
		return 0
	if inventory.is_empty():
		show_toast("Belum ada ikan untuk dijual. Melaut dulu sana.")
		return 0
	var total := inventory_value()
	var n := inventory.size()
	coins += total
	inventory.clear()
	play_sound("confirmation_002.ogg")
	show_toast("Terjual %d ikan seharga %s. Lumayan!" % [n, format_rp(total)])
	save_game()
	return total

func tow_home() -> void:
	var derek := mini(coins, TOW_FEE)
	coins -= derek
	boat_pos = Vector2(rigs[active_boat]["home"])
	rigs[active_boat]["pos"] = boat_pos
	boat_node.position = boat_pos
	fuel = 25.0
	show_toast("Perahu ditarik pulang ke dermaga. Biaya derek %s, BBM darurat 25%%." % format_rp(derek))
	play_sound("open_001.ogg")
	save_game()

func on_action() -> void:
	# Selama berlayar otomatis: AKSI melewati perjalanan berangkat; perjalanan pulang tidak diganggu.
	if auto_sailing == "berangkat":
		finish_auto_sailing()
		return
	if auto_sailing == "pulang":
		return
	if fish_state == "gigit":
		resolve_catch()
		return
	if fish_state == "tunggu":
		cancel_fishing()
		show_toast("Kail ditarik kembali.")
		return
	if mode == "jalan":
		if near_boat():
			board_boat()
		elif near_stall():
			sell_all()
	else:
		if boat_near_dock():
			disembark()
		elif fuel <= 0.0:
			tow_home()
		elif in_sea():
			start_fishing()
		else:
			show_toast("Terlalu dekat dengan pelabuhan. Lewati pelampung oranye dulu.")

# ---------- Perulangan utama ----------

func read_dir() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		d.x += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		d.x -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		d.y += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		d.y -= 1
	d += touch_dir
	if demo_mode:
		d = demo_dir
	if d.length() > 1.0:
		d = d.normalized()
	return d

# Demo otomatis untuk rekaman: jalan ke dermaga, naik, berlayar otomatis ke spot,
# mancing 2x, pulang otomatis, jalan ke kios, jual.
func run_demo(delta: float) -> void:
	demo_t += delta
	match demo_phase:
		0:
			demo_dir = Vector2(0.5, -0.35) if demo_t < 0.8 else Vector2(1, 0)
			if near_boat():
				demo_dir = Vector2.ZERO
				on_action()
				demo_phase = 1
				demo_t = 0.0
		1:
			# Menunggu perjalanan otomatis tiba di spot mancing
			demo_dir = Vector2.ZERO
			if auto_sailing == "":
				demo_phase = 2
				demo_t = 0.0
		2:
			if fish_state == "" and demo_t > 0.6:
				on_action()
				demo_t = 0.0
			elif fish_state == "tunggu" and demo_t > 1.2:
				debug_force_bite()
			elif fish_state == "gigit":
				on_action()
				demo_catches += 1
				demo_t = 0.0
				if demo_catches >= 2:
					request_return()
					demo_phase = 3
		3:
			# Menunggu perjalanan pulang otomatis selesai (pemain turun sendiri)
			demo_dir = Vector2.ZERO
			if mode == "jalan":
				demo_phase = 4
				demo_t = 0.0
		4:
			demo_dir = Vector2(-1, -0.12)
			if near_stall():
				demo_dir = Vector2.ZERO
				on_action()
				demo_phase = 5
				demo_t = 0.0
		_:
			demo_dir = Vector2.ZERO

func walkable(p: Vector2) -> bool:
	if Rect2(24, 36, LAND_W - 24, 648).has_point(p):
		return true
	if Rect2(800, 320, 266, 84).has_point(p):
		return true
	if Rect2(800, 466, 266, 84).has_point(p):
		return true
	if Rect2(800, 610, 266, 84).has_point(p):
		return true
	return false

func _process(delta: float) -> void:
	time_passed += delta
	if demo_mode:
		run_demo(delta)
	var d := read_dir()
	# Aksi (tepi naik)
	var act := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_E) \
		or Input.is_physical_key_pressed(KEY_ENTER) or touch_action
	if act and not prev_action:
		on_action()
	prev_action = act
	# Gerakan
	if mode == "jalan":
		if d != Vector2.ZERO:
			var cand := player_pos + d * PLAYER_SPEED * delta
			if walkable(cand):
				player_pos = cand
			elif walkable(Vector2(cand.x, player_pos.y)):
				player_pos.x = cand.x
			elif walkable(Vector2(player_pos.x, cand.y)):
				player_pos.y = cand.y
			if d.x != 0.0:
				facing = signf(d.x)
		player_sprite.position = player_pos + Vector2(0, sin(time_passed * 9.0) * (1.5 if d != Vector2.ZERO else 0.0))
		player_sprite.flip_h = facing < 0.0
	else:
		if auto_sailing != "":
			advance_auto_sailing(delta)
			if mode == "perahu" and active_boat != "":
				var dx := auto_target.x - boat_pos.x
				if absf(dx) > 1.0:
					boat_visual.scale.x = -1.0 if dx < 0.0 else 1.0
					boat_label.scale.x = boat_visual.scale.x
					boat_label.position.x = float(rigs[active_boat]["label_x"]) * boat_visual.scale.x
		elif d != Vector2.ZERO and fuel > 0.0 and fish_state == "":
			var info: Dictionary = BOATS[active_boat]
			boat_pos += d * float(info["cepat"]) * delta
			clamp_boat()
			fuel = maxf(0.0, fuel - float(info["drain"]) * delta)
			if d.x != 0.0:
				boat_visual.scale.x = -1.0 if d.x < 0.0 else 1.0
				boat_label.scale.x = boat_visual.scale.x
				boat_label.position.x = float(rigs[active_boat]["label_x"]) * boat_visual.scale.x
			rigs[active_boat]["pos"] = boat_pos
		boat_node.position = boat_pos
		boat_visual.position.y = sin(time_passed * 2.1) * 2.0
	# Status mancing (ikan dipilih saat menggigit; kelangkaan menentukan jendela reaksi)
	if fish_state == "tunggu":
		fish_timer += delta
		bobber.position.y = boat_pos.y + 30.0 + sin(time_passed * 3.2) * 2.0
		if fish_timer >= bite_wait:
			fish_state = "gigit"
			fish_timer = 0.0
			pending_species = FishData.pilih_spesies(rng, fish_zone)
			var rar := String(pending_species.get("raritas", "Umum"))
			bite_window = 0.6 if rar == "Epik" else (0.85 if rar == "Langka" else 1.1)
			bite_mark.text = "!!" if rar == "Epik" else "!"
			bite_mark.add_theme_color_override("font_color", Color("ff7043") if rar == "Epik" else Color("ffd93b"))
			bite_mark.position = bobber.position + Vector2(-6, -46)
			bite_mark.visible = true
			play_sound("tick_001.ogg")
	elif fish_state == "gigit":
		fish_timer += delta
		bite_mark.scale = Vector2.ONE * (1.0 + 0.25 * sin(time_passed * 18.0))
		if fish_timer > bite_window:
			cancel_fishing(true)
	# Laut yang hidup: ombak hanyut, bayangan ikan berkeliaran, camar melintas, perahu tambat bergoyang
	for w in waves:
		var wn := w as Node2D
		wn.position.x -= 7.0 * delta
		if wn.position.x < SAND_W + 40.0:
			wn.position.x = WORLD_W - 60.0
			wn.position.y = rng.randf_range(30, 690)
	for s in shadows:
		var sn := s["node"] as Node2D
		var vel: Vector2 = s["vel"]
		sn.position += vel * delta
		sn.position.y += sin(time_passed * 0.9 + float(s["fasa"])) * 4.0 * delta
		if sn.position.x < 1560.0 or sn.position.x > WORLD_W - 120.0:
			s["vel"] = Vector2(-vel.x, 0.0)
	for g in gulls:
		var gp: Vector2 = g["pos"]
		gp.x += float(g["cepat"]) * delta
		if gp.x > WORLD_W - 40.0:
			gp.x = SAND_W + 60.0
		g["pos"] = gp
		var flap := sin(time_passed * 7.0 + float(g["fasa"])) * 4.0
		var pts := PackedVector2Array([Vector2(-11, 0), Vector2(-3, -5.0 - flap), Vector2(0, 0), Vector2(3, -5.0 - flap), Vector2(11, 0)])
		(g["node"] as Line2D).points = pts
		(g["node"] as Line2D).position = gp
		(g["bay"] as Line2D).points = pts
		(g["bay"] as Line2D).position = gp + Vector2(16, 20)
	for key in rigs.keys():
		if key != active_boat:
			(rigs[key]["visual"] as Node2D).position.y = sin(time_passed * 2.1 + float(rigs[key]["home"].x)) * 2.0
	# Kamera mengikuti yang aktif
	var target := player_pos if mode == "jalan" else boat_pos
	camera.position = Vector2(clampf(target.x, 640.0, WORLD_W - 640.0), 360.0)
	# Popup tangkapan
	for p in popups:
		p["t"] = float(p["t"]) + delta
		var n: Label = p["node"]
		n.position.y -= 24.0 * delta
		n.modulate.a = clampf(1.0 - float(p["t"]) / 2.0, 0.0, 1.0)
	popups = popups.filter(func(p: Dictionary) -> bool:
		if float(p["t"]) >= 2.0:
			(p["node"] as Node).queue_free()
			return false
		return true)
	# Toast memudar
	if toast_timer > 0.0:
		toast_timer -= delta
		hud_toast.modulate.a = clampf(toast_timer, 0.0, 1.0)
	refresh_hud()

func refresh_hud() -> void:
	hud_coins.text = "Koin: " + format_rp(coins)
	hud_fish.text = "Ikan: %d ekor (%.1f kg) — %s" % [inventory.size(), inventory_weight(), format_rp(inventory_value())]
	hud_fuel.value = fuel
	var di_perahu := mode == "perahu"
	hud_fuel.visible = di_perahu
	hud_fuel_label.visible = di_perahu
	if return_button != null:
		return_button.visible = mode == "perahu" and auto_sailing == "" and in_sea()
	if mode == "jalan":
		hud_zone.text = "Pelabuhan Wapalo"
	elif in_sea():
		hud_zone.text = "Laut — Zona Lepas" if zona_saat_ini() == "lepas" else ("Laut — Zona Tengah" if zona_saat_ini() == "tengah" else "Laut — Zona Dekat")
	else:
		hud_zone.text = "Perairan Pelabuhan"
	if fish_state == "gigit":
		hud_prompt.text = "TEKAN AKSI SEKARANG!"
	elif fish_state == "tunggu":
		hud_prompt.text = "Menunggu gigitan ikan…"
	elif mode == "jalan":
		if near_boat():
			if trips_done == 0:
				hud_prompt.text = "[AKSI] Naik Perahu (sewa pertama GRATIS)"
			else:
				hud_prompt.text = "[AKSI] Naik Perahu (Kayu %s / Motor %s / Nelayan %s + BBM)" % [format_rp(int(BOATS["kayu"]["sewa"])), format_rp(int(BOATS["motor"]["sewa"])), format_rp(int(BOATS["nelayan"]["sewa"]))]
		elif near_stall():
			hud_prompt.text = "[AKSI] Jual Semua Ikan" if not inventory.is_empty() else "Kios Pembeli Ikan (belum ada tangkapan)"
		else:
			hud_prompt.text = "Jalan: joystick / WASD — dekati dermaga atau kios"
	else:
		if auto_sailing == "berangkat":
			hud_prompt.text = "Berlayar otomatis ke spot mancing… [AKSI] Lewati perjalanan"
		elif auto_sailing == "pulang":
			hud_prompt.text = "Berlayar otomatis kembali ke dermaga…"
		elif boat_near_dock():
			hud_prompt.text = "[AKSI] Turun di Dermaga"
		elif fuel <= 0.0:
			hud_prompt.text = "[AKSI] Bahan bakar habis — minta tarik ke dermaga"
		elif in_sea():
			hud_prompt.text = "[AKSI] Lempar Kail"
		else:
			hud_prompt.text = "Berlayar ke kanan, lewati pelampung oranye"
	# Label tombol AKSI mengikuti konteks supaya pemain tidak menebak fungsinya
	if act_button != null:
		if auto_sailing == "berangkat":
			act_button.text = "LEWATI"
		elif auto_sailing == "pulang":
			act_button.text = "AKSI"
		elif fish_state == "gigit":
			act_button.text = "TARIK!"
		elif fish_state == "tunggu":
			act_button.text = "BATAL"
		elif mode == "jalan":
			act_button.text = "NAIK" if near_boat() else ("JUAL" if near_stall() and not inventory.is_empty() else "AKSI")
		else:
			act_button.text = "TURUN" if boat_near_dock() else ("DEREK" if fuel <= 0.0 else ("LEMPAR" if in_sea() else "AKSI"))

func _capture_later() -> void:
	player_pos = Vector2(700, 385)
	await get_tree().create_timer(2.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("/home/hatch/workspace/tools/fase0_pelabuhan.png")
	boat_pos = Vector2(1750, 360)
	mode = "perahu"
	player_sprite.visible = false
	boat_rider.visible = true
	start_fishing()
	await get_tree().create_timer(1.2).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/home/hatch/workspace/tools/fase0_laut.png")
	cancel_fishing()
	boat_pos = Vector2(3300, 360)
	await get_tree().create_timer(1.0).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/home/hatch/workspace/tools/fase1_tengah.png")
	boat_pos = Vector2(5100, 360)
	await get_tree().create_timer(1.0).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/home/hatch/workspace/tools/060_lepas.png")
	print("FOTO_SELESAI")
