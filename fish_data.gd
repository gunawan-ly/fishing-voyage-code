class_name FishData
extends RefCounted

## Tabel spesies ikan per zona (placeholder, sprite Kenney Fish Pack CC0).
## berat dalam kg, harga per kg dalam Rp, peluang = bobot undian relatif.
## zona: "dekat" hanya bisa ditangkap di Zona Dekat, "tengah" hanya di Zona Tengah.
const SPECIES: Array = [
	{"nama": "Kembung", "ikon": "fish_blue.png", "berat_min": 0.2, "berat_maks": 0.5, "harga_kg": 18000, "peluang": 40, "raritas": "Umum", "zona": "dekat"},
	{"nama": "Tongkol", "ikon": "fish_grey.png", "berat_min": 0.8, "berat_maks": 2.5, "harga_kg": 22000, "peluang": 25, "raritas": "Umum", "zona": "dekat"},
	{"nama": "Baronang", "ikon": "fish_green.png", "berat_min": 0.3, "berat_maks": 0.8, "harga_kg": 25000, "peluang": 15, "raritas": "Umum", "zona": "dekat"},
	{"nama": "Kakap Merah", "ikon": "fish_red.png", "berat_min": 0.5, "berat_maks": 3.0, "harga_kg": 45000, "peluang": 10, "raritas": "Langka", "zona": "dekat"},
	{"nama": "Tuna", "ikon": "fish_yellow.png", "berat_min": 2.0, "berat_maks": 8.0, "harga_kg": 38000, "peluang": 6, "raritas": "Langka", "zona": "dekat"},
	{"nama": "Kerapu", "ikon": "fish_brown.png", "berat_min": 0.5, "berat_maks": 4.0, "harga_kg": 60000, "peluang": 4, "raritas": "Epik", "zona": "dekat"},
	{"nama": "Cakalang", "ikon": "fish_orange.png", "berat_min": 1.0, "berat_maks": 4.0, "harga_kg": 26000, "peluang": 34, "raritas": "Umum", "zona": "tengah"},
	{"nama": "Kuwe", "ikon": "fish_pink.png", "berat_min": 1.5, "berat_maks": 7.0, "harga_kg": 48000, "peluang": 26, "raritas": "Langka", "zona": "tengah"},
	{"nama": "Tenggiri", "ikon": "fish_grey_long_a.png", "berat_min": 2.0, "berat_maks": 9.0, "harga_kg": 55000, "peluang": 26, "raritas": "Langka", "zona": "tengah"},
	{"nama": "Marlin", "ikon": "fish_grey_long_b.png", "berat_min": 8.0, "berat_maks": 25.0, "harga_kg": 65000, "peluang": 14, "raritas": "Epik", "zona": "tengah"},
	{"nama": "Kakap Putih", "ikon": "fish_grey.png", "berat_min": 3.0, "berat_maks": 12.0, "harga_kg": 52000, "peluang": 34, "raritas": "Langka", "zona": "lepas"},
	{"nama": "Tuna Sirip Kuning", "ikon": "fish_yellow.png", "berat_min": 5.0, "berat_maks": 20.0, "harga_kg": 58000, "peluang": 30, "raritas": "Langka", "zona": "lepas"},
	{"nama": "Kerapu Macan", "ikon": "fish_brown.png", "berat_min": 2.0, "berat_maks": 10.0, "harga_kg": 72000, "peluang": 22, "raritas": "Epik", "zona": "lepas"},
	{"nama": "Ikan Pedang", "ikon": "fish_grey_long_b.png", "berat_min": 15.0, "berat_maks": 45.0, "harga_kg": 80000, "peluang": 14, "raritas": "Epik", "zona": "lepas"},
]

static func spesies_di_zona(zona: String) -> Array:
	var hasil: Array = []
	for s in SPECIES:
		if String(s["zona"]) == zona:
			hasil.append(s)
	return hasil

static func pilih_spesies(rng: RandomNumberGenerator, zona := "dekat") -> Dictionary:
	var daftar := spesies_di_zona(zona)
	if daftar.is_empty():
		daftar = SPECIES
	var total := 0
	for s in daftar:
		total += int(s["peluang"])
	var lempar := rng.randi_range(1, total)
	var jalan := 0
	for s in daftar:
		jalan += int(s["peluang"])
		if lempar <= jalan:
			return s
	return daftar[0]
