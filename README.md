# Fishing Voyage — File Sumber (Datar)

Repo publik ini berisi **salinan datar** file-file sumber game **Fishing Voyage**
(game memancing pixel 2D, Godot 4.7.2, GDScript) yang boleh diubah.
Tujuannya supaya mudah dibaca dan dianalisis, termasuk oleh AI seperti ChatGPT,
tanpa terhalang struktur folder.

Repo proyek aslinya bersifat privat dan terstruktur folder. Repo ini hanya
cerminan untuk dibaca; pemetaan nama file datar ke lokasi aslinya:

| File di repo ini | Lokasi asli di proyek |
|---|---|
| `main.gd` | `scripts/main.gd` (seluruh logika game, satu file) |
| `fish_data.gd` | `scripts/fish_data.gd` (tabel spesies ikan per zona) |
| `main.tscn` | `scenes/main.tscn` (scene utama, isinya dirujuk dari `main.gd`) |
| `project.godot` | `project.godot` (konfigurasi proyek) |
| `export_presets.cfg` | `export_presets.cfg` (preset ekspor Android + Web) |
| `smoke_test.gd` | `tests/smoke_test.gd` (uji asap otomatis alur permainan) |
| `ART_DIRECTION.md` | `docs/ART_DIRECTION.md` (arah visual) |

Aset gambar dan suara (folder `assets/` di proyek asli) tidak disertakan
karena bukan file kode yang diubah di sini.

## Aturan kalau menghasilkan kode

- Tulis ulang file secara **utuh** untuk setiap file yang diubah, jangan potongan.
- Pertahankan nama fungsi, variabel, dan konstanta yang sudah ada kecuali
  perubahan memang mengharuskannya.
- Jangan menghapus fitur yang sudah jalan: simpanan permanen (koin, BBM,
  inventaris, koleksi), ekonomi sewa + BBM + derek, dua perahu (Kayu dan
  Motor), dua zona laut (Dekat dan Tengah), panel koleksi, dan uji asap.
- Bahasa antarmuka game: Bahasa Indonesia.
- Versi game saat ini: 0.5.0.
