# Kas Siswa

Aplikasi manajemen kas kelas berbasis Flutter untuk membantu bendahara mencatat pembayaran kas siswa, pengeluaran, saldo, dan rekap pembayaran secara sederhana dan offline.

✨ Features

- 👨‍🎓 Manajemen data siswa
- 💵 Pencatatan pembayaran kas mingguan
- 🟢 Status siswa yang sudah membayar
- 🔴 Status siswa yang belum membayar
- 📅 Rekap pembayaran berdasarkan bulan
- 💸 Pencatatan pengeluaran
- 🧮 Perhitungan pemasukan dan saldo
- 🗄️ Penyimpanan data menggunakan SQLite
- 📱 Dapat digunakan secara offline
- 🖨️ Generate dan cetak laporan PDF
- 🏫 Logo sekolah pada aplikasi dan laporan

🖥️ Preview

Tampilan utama aplikasi menampilkan status pembayaran siswa berdasarkan minggu.

Pembayaran Minggu Ini

🟢 Rangga       Rp5.000
🟢 Arven        Rp5.000
🔴 Bastian      Rp5.000
🟢 Celestia     Rp5.000
🔴 Darian       Rp5.000
🟢 Elric        Rp5.000

Warna digunakan untuk memudahkan bendahara melihat siapa yang sudah dan belum membayar.

🛠️ Tech Stack

- Flutter
- Dart
- SQLite
- sqflite
- sqflite_common_ffi_web
- PDF
- Printing

🗃️ Database

Aplikasi menggunakan SQLite untuk menyimpan data secara lokal.

Database terdiri dari beberapa tabel utama:

Students

Menyimpan data siswa.

students
├── id
└── name

Payments

Menyimpan riwayat pembayaran.

payments
├── id
├── student_id
├── week_start
├── amount
└── created_at

Pembayaran menggunakan tanggal awal minggu, bukan nomor minggu tetap.

Contohnya:

2026-09-21
2026-09-28
2026-10-05
2026-10-12

Dengan pendekatan ini, data pembayaran tidak terbatas hanya pada 4 minggu atau 1 bulan.

Expenses

Menyimpan pengeluaran kas.

expenses
├── id
├── description
├── amount
└── date

📅 Penyimpanan Mingguan

Aplikasi tidak menggunakan struktur seperti:

Minggu 1
Minggu 2
Minggu 3
Minggu 4

sebagai data permanen.

Sebaliknya, setiap minggu direpresentasikan menggunakan tanggal.

Contoh:

September 2026

07 Sep ── pembayaran
14 Sep ── pembayaran
21 Sep ── pembayaran
28 Sep ── pembayaran

October 2026

05 Okt ── pembayaran
12 Okt ── pembayaran
19 Okt ── pembayaran
26 Okt ── pembayaran

Dengan demikian aplikasi dapat digunakan terus menerus tanpa perlu membuat bulan baru secara manual.

🚀 Getting Started

1. Clone repository

git clone https://github.com/USERNAME/kas-siswa.git

Masuk ke folder project:

cd kas-siswa

2. Install dependencies

flutter pub get

3. Setup SQLite Web

Jika ingin menjalankan aplikasi melalui Flutter Web:

dart run sqflite_common_ffi_web:setup

4. Jalankan aplikasi

Untuk Edge:

flutter run -d edge

Untuk Android:

flutter run

🖼️ Logo Sekolah

Letakkan logo sekolah pada:

assets/
└── images/
    └── logo_sekolah.png

Kemudian pastikan asset tersebut terdaftar di "pubspec.yaml":

flutter:
  uses-material-design: true

  assets:
    - assets/images/logo_sekolah.png

📊 Contoh Alur Penggunaan

1. Tambahkan siswa

Masuk ke menu:

Siswa

Kemudian tambahkan nama siswa.

2. Catat pembayaran

Masuk ke:

Kas

Pilih minggu pembayaran.

Kemudian tekan nama siswa.

🔴 Belum bayar
        ↓
      klik
        ↓
🟢 Sudah bayar

3. Catat pengeluaran

Masuk ke:

Pengeluaran

Masukkan:

Keterangan : Membeli spidol
Jumlah     : Rp20.000
Tanggal    : 24/09/2026

4. Lihat saldo

Dashboard akan menghitung:

Total Pemasukan
        -
Total Pengeluaran
        =
Saldo

5. Lihat rekap

Menu:

Rekap

menampilkan status pembayaran siswa berdasarkan minggu dalam suatu bulan.

📴 Offline

Aplikasi dirancang untuk dapat digunakan tanpa koneksi internet.

Data utama disimpan secara lokal menggunakan SQLite.

Flutter App
     │
     ▼
   SQLite
     │
     ├── Students
     ├── Payments
     └── Expenses

Internet tidak diperlukan untuk mencatat transaksi.

🖨️ Laporan PDF

Aplikasi dapat membuat laporan PDF yang berisi:

- Logo sekolah
- Judul laporan
- Periode
- Daftar siswa
- Status pembayaran
- Total pemasukan
- Total pengeluaran
- Saldo
- Kolom tanda tangan

⚠️ Backup Data

Karena database disimpan secara lokal, data tidak otomatis tersinkronisasi ke cloud.

Jika aplikasi dihapus dari perangkat, database lokal dapat ikut terhapus.

Fitur backup dan restore merupakan salah satu pengembangan yang direncanakan.

🗺️ Roadmap

MVP

- [x] Data siswa
- [x] Pembayaran mingguan
- [x] Status pembayaran
- [x] SQLite
- [x] Pengeluaran
- [x] Saldo
- [x] Rekap bulanan
- [x] PDF
- [x] Logo sekolah
- [x] Offline storage

Next

- [ ] Edit siswa
- [ ] Edit transaksi
- [ ] Backup data
- [ ] Restore data
- [ ] Export JSON
- [ ] Import JSON
- [ ] Pengaturan nama sekolah
- [ ] Pengaturan kelas
- [ ] Pengaturan nominal kas
- [ ] Tahun ajaran
- [ ] Dashboard statistik
- [ ] Riwayat transaksi lengkap

Future

- [ ] PIN / App Lock
- [ ] Cloud backup
- [ ] Multi-device synchronization
- [ ] User roles
- [ ] Backend API
- [ ] Authentication
- [ ] Web deployment

📂 Project Structure

Versi awal project sengaja menggunakan satu file "main.dart" agar mudah dipelajari dan digunakan sebagai MVP.

lib/
└── main.dart

assets/
└── images/
    └── logo_sekolah.png

Ketika aplikasi berkembang, struktur akan dipisahkan menjadi beberapa layer.

Contoh rencana:

lib/
├── main.dart
│
├── database/
│   └── database_helper.dart
│
├── models/
│   ├── student.dart
│   ├── payment.dart
│   └── expense.dart
│
├── screens/
│   ├── dashboard_page.dart
│   ├── students_page.dart
│   ├── recap_page.dart
│   └── expenses_page.dart
│
├── services/
│   └── pdf_service.dart
│
└── utils/
    └── formatters.dart

🎯 Project Goal

Project ini dibuat sebagai aplikasi sederhana untuk membantu pengelolaan kas kelas sekaligus menjadi project pembelajaran Flutter.

Fokus utama project:

Simple
   ↓
Offline
   ↓
Persistent
   ↓
Useful
   ↓
Maintainable
