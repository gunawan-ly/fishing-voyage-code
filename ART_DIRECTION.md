# Arah Visual (Art Direction) — Fishing Voyage

Dikunci mengikuti strategi aset yang disetujui Awan, 14 November 2026. Acuan diskusi: [Pribadi] Tanggapan ChatGPT - Aset Siap Pakai Fishing Voyage.

## Standar utama

| Aspek | Standar |
|---|---|
| Perspektif | Top-down / 3/4 top-down, konsisten di semua area |
| Grid dunia | 32 px visual (lihat aturan skala di bawah) |
| Filtering | Nearest-neighbor di semua sprite pixel |
| Skala | Integer saja (1x, 2x). Dilarang 1,5x dan interpolasi blur |
| Outline | Ikuti paket acuan yang sedang dipakai; jangan campur sprite ber-outline tebal dengan tanpa outline dalam satu layar |
| Cahaya | Satu arah cahaya konsisten per paket acuan |
| Karakter | Tinggi visual konsisten antar karakter yang setara; ukur dari tinggi sprite, bukan ukuran berkas |

## Aturan skala 16 dan 32

- Standar dunia adalah 32 px supaya dermaga, bangunan, dan kapal terbaca jelas di layar Android.
- Paket gratis Fase 0 (Kenney Tiny Town dan Tiny Dungeon) bergrid 16x16 asli; keduanya dipakai pada skala 2x nearest sehingga tampil 32 px dan tetap konsisten dengan standar dunia.
- Aset 16x16 untuk ikan, ikon, dan detail kecil boleh tampil 1x bila memang dimaksudkan kecil.
- Paket lingkungan 32x32 (kandidat: Harbor & Docks) bisa masuk tanpa perubahan skala.

## Palet

- Fase 0 mengikuti palet bawaan Kenney Tiny (cerah, bersih) sebagai palet prototype.
- Palet final belum dikunci; bila Harbor & Docks diadopsi, palet muted Stonebit menjadi acuan lingkungan.
- Jangan recolor massal secara otomatis; kurasi aset yang cocok, edit hanya yang perlu.

## Uji konsistensi sebelum produksi

Sebelum membangun seluruh pelabuhan, rakit satu scene uji berisi karakter, dermaga, air, satu perahu, satu kios, dan tiga ikan berbeda ukuran. Periksa di resolusi target Android. Bila keenamnya terasa dari game yang sama, kombinasi aset aman dipakai.

## Yang sengaja custom (identitas game)

Kapal besar kelas Kapal Nelayan, ikan khas Indonesia, UI album dan inventaris Bahasa Indonesia, landmark pelabuhan utama. Aset siap pakai adalah fondasi dan pengisi, bukan identitas.
