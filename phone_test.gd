extends SceneTree
## Uji otomatis ponsel dalam game 0.8.0: buka/tutup, ganti halaman, dunia
## berhenti selama ponsel terbuka, isi halaman koleksi/harga/kapal/setelan.
## Jalankan: godot --headless --script res://tests/phone_test.gd

var stage := 0
var m: Node = null
var failures: Array = []

func check(cond: bool, label: String) -> void:
	if cond:
		print("LULUS: ", label)
	else:
		failures.append(label)
		print("GAGAL: ", label)

func _initialize() -> void:
	var save_path := ProjectSettings.globalize_path("user://fishing_voyage_save.cfg")
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	var ps: PackedScene = load("res://scenes/main.tscn")
	m = ps.instantiate()
	root.add_child(m)

func _process(_delta: float) -> bool:
	stage += 1
	if stage == 3:
		check(m.phone_panel != null, "panel ponsel terbangun")
		check(m.phone_button != null, "tombol HP ada di HUD")
		check(not m.phone_open and not m.phone_panel.visible, "ponsel tertutup di awal")
		m.open_phone("home")
		check(m.phone_open and m.phone_panel.visible, "ponsel terbuka")
		check((m.phone_pages["home"] as Control).visible, "halaman beranda tampil")
		# Dunia harus berhenti: timer gigitan tidak boleh maju selagi ponsel terbuka
		m.fish_state = "tunggu"
		m.fish_timer = 0.0
		m.bite_wait = 999.0
	elif stage == 8:
		check(m.fish_timer == 0.0, "timer gigitan membeku selama ponsel terbuka")
		m.show_phone_page("koleksi")
		check((m.phone_pages["koleksi"] as Control).visible, "halaman koleksi tampil")
		check(not (m.phone_pages["home"] as Control).visible, "beranda sembunyi di halaman koleksi")
		check(m.collection_box.get_child_count() > 10, "isi koleksi terisi daftar spesies")
		m.show_phone_page("harga")
		check((m.phone_pages["harga"] as Control).visible, "halaman harga tampil")
		m.show_phone_page("kapal")
		check((m.phone_pages["kapal"] as Control).visible, "halaman kapal tampil")
		check(m.phone_kapal_box.get_child_count() >= 3, "daftar kapal terisi 3 kapal")
		m.show_phone_page("setelan")
		check((m.phone_pages["setelan"] as Control).visible, "halaman setelan tampil")
		check(m.reset_button != null, "tombol ULANG tinggal di setelan")
		m.close_phone()
		check(not m.phone_open and not m.phone_panel.visible, "ponsel tertutup lagi")
	elif stage == 12:
		check(m.fish_timer > 0.0, "timer gigitan jalan lagi setelah ponsel ditutup")
		m.fish_state = ""
		if failures.is_empty():
			print("UJI_HP_LULUS")
			quit(0)
		else:
			print("UJI_HP_GAGAL: ", failures)
			quit(1)
		return true
	return false
