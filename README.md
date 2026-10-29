jawaban soal 


1. Apa perbedaan Model, View, dan ViewModel pada aplikasi ini?

Model menyimpan data buku dan pinjaman. ViewModel mengelola state serta aturan perpustakaan, sedangkan View menampilkan data dan meneruskan tindakan pengguna.

2. Mengapa perhitungan denda tidak boleh diletakkan di dalam `LoanCard.build()`?

View hanya bertugas menampilkan data, bukan menjalankan aturan bisnis. Perhitungan di ViewModel membuat aturan denda konsisten dan mudah diuji.

3. Apa yang seharusnya terjadi jika mahasiswa mencoba meminjam buku yang masih memiliki pinjaman aktif olehnya?

Peminjaman ditolak dan catatan pinjaman lama tetap aktif. Salinan buku hanya dapat dipinjam jika masih tersedia.

4. Mengapa denda sebaiknya dihitung di satu tempat, bukan diulang di beberapa widget?

Satu perhitungan mencegah hasil berbeda antara daftar pinjaman dan ringkasan denda. Perubahan tarif juga cukup dilakukan pada satu aturan.

5. Apa perbedaan buku yang terlambat dan buku yang hilang?

Buku terlambat belum melewati enam bulan dan dikenai denda berdasarkan minggu keterlambatan yang selesai. Buku yang mencapai enam bulan berstatus hilang dan dikenai biaya penggantian buku ditambah denda enam bulan.

6. Jika denda mingguan berubah dari Rp5.000 menjadi Rp7.000, bagaimana aplikasi sebaiknya diperbarui?

Ubah nilai tarif pada aturan denda di ViewModel, lalu sesuaikan pengujian dan dokumentasi. View tidak perlu diubah karena hanya menampilkan jumlah yang diberikan ViewModel.
