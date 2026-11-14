extends SceneTree
## Uji otomatis loop inti Fase 0: naik perahu -> melaut -> mancing -> tangkap ->
## pulang -> turun -> jual. Jalankan: godot --headless --script res://tests/smoke_test.gd

var stage := 0
var m: Node = null
var failures: Array = []
var home_pos := Vector2.ZERO

func check(cond: bool, label: String) -> void:
	if cond:
		print("LULUS: ", label)
	else:
		failures.append(label)
		print("GAGAL: ", label)

func _initialize() -> void:
	# Hapus simpanan lama supaya uji selalu mulai dari nol.
	var save_path := ProjectSettings.globalize_path("user://fishing_voyage_save.cfg")
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	var ps: PackedScene = load("res://scenes/main.tscn")
	m = ps.instantiate()
	root.add_child(m)

func _process(_delta: float) -> bool:
	stage += 1
	if stage == 3:
		home_pos = m.boat_pos
		check(m.coins == 0, "koin awal 0")
		check(m.mode == "jalan", "mode awal jalan")
		m.player_pos = Vector2(985, 361)
		check(m.near_boat(), "pemain dekat perahu")
		check(m.board_boat(), "naik perahu berhasil")
		check(m.mode == "perahu", "mode perahu aktif")
		m.boat_pos = Vector2(1800, 360)
		check(m.in_sea(), "perahu di zona laut")
		check(m.start_fishing(), "lempar kail berhasil")
		m.debug_force_bite()
	elif stage == 8:
		check(m.fish_state == "gigit", "ikan menggigit")
		m.on_action()
		check(m.inventory.size() == 1, "satu ikan masuk inventaris")
		check(m.fish_state == "", "status mancing bersih setelah tangkap")
		m.boat_pos = home_pos
		check(m.disembark(), "turun di dermaga berhasil")
		m.player_pos = Vector2(255, 340)
		check(m.near_stall(), "pemain dekat kios")
		var hasil: int = m.sell_all()
		check(hasil > 0, "hasil jual lebih dari 0")
		check(m.coins == hasil, "koin bertambah sesuai hasil jual")
		check(m.inventory.is_empty(), "inventaris kosong setelah jual")
		check(m.trips_done == 1, "trip pertama tercatat")
		m.player_pos = Vector2(985, 361)
		m.coins = 100000
		m.fuel = 50.0
		check(m.board_boat(), "naik untuk trip kedua")
		check(m.coins == 100000 - 7500 - 50 * 120, "sewa dan BBM trip kedua terpotong")
		check(m.fuel == 100.0, "BBM terisi penuh saat berangkat")
		check(m.disembark(), "turun setelah trip kedua")
		check(m.trips_done == 2, "trip kedua tercatat")
		# Perahu Motor dan Zona Tengah
		m.player_pos = Vector2(985, 505)
		m.coins = 100000
		m.fuel = 100.0
		check(m.board_boat(), "naik Perahu Motor")
		check(m.active_boat == "motor", "perahu aktif adalah motor")
		check(m.coins == 100000 - 20000, "sewa Perahu Motor terpotong")
		m.boat_pos = Vector2(3300, 360)
		check(m.zona_saat_ini() == "tengah", "zona tengah terdeteksi")
		check(m.start_fishing(), "lempar kail di Zona Tengah")
		m.debug_force_bite()
	elif stage == 13:
		check(m.fish_state == "gigit", "ikan Zona Tengah menggigit")
		m.on_action()
		check(m.inventory.size() == 1, "ikan Zona Tengah masuk inventaris")
		var nama_ikan := String(m.inventory[0]["nama"])
		check(nama_ikan in ["Cakalang", "Kuwe", "Tenggiri", "Marlin"], "spesies khas Zona Tengah")
		check(m.collection.has(nama_ikan), "koleksi mencatat spesies baru")
		m.boat_pos = Vector2(1015, 505)
		check(m.disembark(), "turun dari Perahu Motor")
		# Gerbang zona untuk Perahu Kayu
		m.player_pos = Vector2(985, 361)
		check(m.board_boat(), "naik Perahu Kayu lagi")
		m.boat_pos = Vector2(3000, 360)
		m.clamp_boat()
		check(m.boat_pos.x == 2240.0, "Perahu Kayu tertahan gerbang Zona Tengah")
		check(m.disembark() == false, "tidak bisa turun di tengah laut")
		m.boat_pos = Vector2(1015, 361)
		check(m.disembark(), "turun dari Perahu Kayu")
		# Simpan dan muat ulang
		var koin_simpan: int = m.coins
		m.save_game()
		m.coins = 0
		m.collection = {}
		m.load_game()
		check(m.coins == koin_simpan, "koin pulih dari simpanan")
		check(not m.collection.is_empty(), "koleksi pulih dari simpanan")
		if failures.is_empty():
			print("UJI_LOOP_LULUS")
			quit(0)
		else:
			print("UJI_LOOP_GAGAL: ", failures)
			quit(1)
		return true
	return false
