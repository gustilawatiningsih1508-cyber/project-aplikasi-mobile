import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('marketplace_bengkalis_v7.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Drop everything and recreate for development simplicity
    await db.execute('DROP TABLE IF EXISTS notifications');
    await db.execute('DROP TABLE IF EXISTS transactions');
    await db.execute('DROP TABLE IF EXISTS courier_requests');
    await db.execute('DROP TABLE IF EXISTS chat_messages');
    await db.execute('DROP TABLE IF EXISTS products');
    await db.execute('DROP TABLE IF EXISTS addresses');
    await db.execute('DROP TABLE IF EXISTS users');
    await _createDB(db, newVersion);
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Users Table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT NOT NULL DEFAULT '',
        photoUrl TEXT NOT NULL DEFAULT 'assets/images/avatar.png',
        bio TEXT NOT NULL DEFAULT '',
        role TEXT NOT NULL DEFAULT 'user',
        courierStatus TEXT,
        ktp TEXT,
        vehicle TEXT,
        isActive INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL DEFAULT ''
      )
    ''');

    // 2. Addresses Table
    await db.execute('''
      CREATE TABLE addresses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        name TEXT NOT NULL,
        village TEXT NOT NULL,
        detail TEXT NOT NULL,
        isPrimary INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 3. Products Table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sellerId INTEGER NOT NULL,
        sellerName TEXT NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        imageUrls TEXT NOT NULL DEFAULT '["assets/images/placeholder.png"]',
        condition TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Tersedia',
        createdAt TEXT NOT NULL,
        views INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 4. Chat Messages Table
    await db.execute('''
      CREATE TABLE chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        senderId INTEGER NOT NULL,
        receiverId INTEGER NOT NULL,
        message TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        isRead INTEGER NOT NULL DEFAULT 0,
        isBid INTEGER NOT NULL DEFAULT 0,
        bidProductId INTEGER,
        bidPrice REAL,
        bidStatus TEXT
      )
    ''');

    // 5. Courier Requests Table
    await db.execute('''
      CREATE TABLE courier_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transactionId INTEGER NOT NULL,
        buyerId INTEGER NOT NULL,
        sellerId INTEGER NOT NULL,
        pickupAddress TEXT NOT NULL,
        deliveryAddress TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Menunggu Kurir',
        courierName TEXT NOT NULL DEFAULT '',
        courierId INTEGER,
        price REAL NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT
      )
    ''');

    // 6. Transactions Table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        buyerId INTEGER NOT NULL,
        sellerId INTEGER NOT NULL,
        amount REAL NOT NULL,
        paymentMethod TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Menunggu Konfirmasi',
        courierRequestId INTEGER,
        paymentProofUrl TEXT,
        sellerRating REAL,
        sellerReview TEXT,
        courierRating REAL,
        courierReview TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT
      )
    ''');

    // 7. Notifications Table
    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'info',
        referenceId INTEGER,
        isRead INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    // Seed initial data
    await _seedData(db);
  }

  Future<void> _seedData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Seed Users
    await db.rawInsert('''
      INSERT INTO users (id, name, email, password, phone, address, photoUrl, bio, role, courierStatus, isActive, createdAt) VALUES
      (1, 'Andi Wijaya', 'andi@gmail.com', 'password123', '081234567890', 'Jl. Ahmad Yani No. 12, Kelapapati, Bengkalis', 'assets/images/avatar.png', 'Jual santai barang hobi bekas berkualitas. COD area Bengkalis Kota.', 'user', NULL, 1, '$now'),
      (2, 'Siti Rahma', 'siti@gmail.com', 'password123', '082298765432', 'Jl. Sudirman No. 45, Senggoro, Bengkalis', 'assets/images/avatar.png', 'Preloved fashion & furniture aesthetic. Bengkalis Kota.', 'user', NULL, 1, '$now'),
      (3, 'Budi Santoso', 'budi@gmail.com', 'password123', '085377665544', 'Jl. Antara No. 8, Wonosari, Bengkalis', 'assets/images/avatar.png', 'Gadget specialist. COD Bengkalis Kota OK. Garansi kepuasan.', 'user', NULL, 1, '$now'),
      (4, 'Admin Utama', 'admin@belibekas.com', 'Admin123!', '081122334455', 'Kantor Utama BeliBekas, Bengkalis Kota', 'assets/images/avatar.png', 'Administrator Platform BeliBekas Bengkalis.', 'admin', NULL, 1, '$now'),
      (5, 'Kurir Amanah', 'kurir@gmail.com', 'password123', '089988776655', 'Jl. Bengkalis Kota No. 23, Bengkalis', 'assets/images/avatar.png', 'Kurir cepat dan amanah. Motor matic, siap antar ke seluruh Bengkalis Kota.', 'courier', 'approved', 1, '$now'),
      (6, 'Kurir Pending', 'kurir_pending@gmail.com', 'password123', '082211223344', 'Jl. Damon Gang Damai No. 5, Bengkalis', 'assets/images/avatar.png', 'Calon kurir handal. Motor Honda Beat 2022.', 'courier', 'pending', 1, '$now')
    ''');

    // Seed Addresses
    await db.rawInsert('''
      INSERT INTO addresses (userId, name, village, detail, isPrimary) VALUES
      (1, 'Rumah Utama', 'Kelapapati', 'Jl. Ahmad Yani No. 12, RT 02/RW 03', 1),
      (1, 'Kantor', 'Bengkalis Kota', 'Jl. Jend. Sudirman No. 15, Kantor Bappeda', 0),
      (2, 'Rumah Utama', 'Senggoro', 'Jl. Sudirman No. 45, RT 01/RW 02', 1),
      (3, 'Rumah Utama', 'Wonosari', 'Jl. Antara No. 8, RT 03/RW 04', 1),
      (5, 'Rumah Kurir', 'Bengkalis Kota', 'Jl. Bengkalis Kota No. 23, RT 05/RW 02', 1)
    ''');

    // Seed Products – 15 produk dummy dengan foto Unsplash spesifik sesuai kategori
    await db.rawInsert('''
      INSERT INTO products (id, sellerId, sellerName, name, price, description, category, imageUrls, condition, status, createdAt) VALUES
      (1, 3, 'Budi Santoso', 'Samsung Galaxy A53 5G 128GB', 2800000.0, 'Jual Samsung Galaxy A53 5G warna Awesome Blue 128GB. Kondisi mulus 95%, layar Super AMOLED 6.5 inch tanpa goresan. RAM 6GB, baterai 5000mAh masih tahan seharian. Fullset charger original. COD area Bengkalis Kota.', 'Elektronik', '["https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=400&h=400&fit=crop","https://images.unsplash.com/photo-1592750475338-74b7b21085ab?w=400&h=400&fit=crop"]', 'Sangat Baik', 'Tersedia', '$now'),
      (2, 3, 'Budi Santoso', 'Laptop ASUS VivoBook 14 Core i5 Gen 11', 4200000.0, 'ASUS VivoBook 14 Core i5-1135G7, RAM 8GB DDR4, SSD 512GB NVMe. Layar FHD IPS 14 inch anti-glare. Baterai awet 6-7 jam pemakaian normal. Desain slim & ringan 1.4kg. Cocok kuliah/kerja. Kondisi sangat baik.', 'Elektronik', '["https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=400&h=400&fit=crop","https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=400&h=400&fit=crop"]', 'Baik', 'Tersedia', '$now'),
      (3, 1, 'Andi Wijaya', 'TV LED Samsung 32 Inch Smart TV', 1750000.0, 'Smart TV Samsung 32 inch resolusi HD. Bisa akses Netflix, YouTube, Disney+. Panel layar masih jernih tanpa dead pixel. Remote original lengkap. Sudah dipasang 2 tahun, jarang ditonton karena pindah kos. Kondisi baik.', 'Elektronik', '["https://images.unsplash.com/photo-1593359677879-a4bb92f829d1?w=400&h=400&fit=crop","https://images.unsplash.com/photo-1461151304267-38231e7d4f3b?w=400&h=400&fit=crop"]', 'Baik', 'Tersedia', '$now'),
      (4, 2, 'Siti Rahma', 'Kipas Angin Miyako Stand Fan 16 Inch', 185000.0, 'Kipas angin berdiri Miyako 16 inch 3 kecepatan. Masih kencang dan senyap, timer otomatis berfungsi. Baling-baling bersih tanpa keretakan. Dijual karena sudah ganti AC. Kondisi baik, bisa dicoba langsung.', 'Elektronik', '["https://images.unsplash.com/photo-1585771724684-38269d6639fd?w=400&h=400&fit=crop","https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400&h=400&fit=crop"]', 'Baik', 'Tersedia', '$now'),
      (5, 2, 'Siti Rahma', 'Kemeja Flanel Uniqlo Size M – Merah Kotak', 120000.0, 'Kemeja flanel Uniqlo original ukuran M. Warna merah motif kotak-kotak masih cerah dan tidak pudar. Bahan tebal dan hangat. Dijual karena sudah tidak muat. Kondisi bersih, harum, tanpa noda atau cacat.', 'Pakaian', '["https://images.unsplash.com/photo-1603251578711-3290ca1a0187?w=400&h=400&fit=crop","https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=400&h=400&fit=crop"]', 'Sangat Baik', 'Tersedia', '$now'),
      (6, 1, 'Andi Wijaya', 'Celana Jeans Levis 501 Size 30', 220000.0, 'Celana jeans Levis 501 original size 30. Warna indigo wash, denim tebal kualitas premium. Sudah dicuci bersih. Kondisi 90% – ada sedikit fading alami di lutut yang menambah karakter. Pas buat gaya kasual maupun semi-formal.', 'Pakaian', '["https://images.unsplash.com/photo-1542272604-787c3835535d?w=400&h=400&fit=crop","https://images.unsplash.com/photo-1555689502-c4b22d76c56f?w=400&h=400&fit=crop"]', 'Baik', 'Tersedia', '$now'),
      (7, 3, 'Budi Santoso', 'Sepatu Vans Old Skool Black White Size 42', 280000.0, 'Sepatu Vans Old Skool hitam putih ukuran 42. Original produk, sudah dicuci bersih. Sole masih tebal tidak aus. Upper canvas masih kuat, tidak ada sobekan. Dijual karena naik ukuran. Kondisi 85%.', 'Pakaian', '["https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400&h=400&fit=crop","https://images.unsplash.com/photo-1608231387042-66d1773070a5?w=400&h=400&fit=crop"]', 'Baik', 'Tersedia', '$now'),
      (8, 2, 'Siti Rahma', 'Tas Ransel Consina 40L Outdoor Backpack', 350000.0, 'Tas ransel outdoor Consina 40 liter. Bahan ripstop nylon tahan air. Kantung terorganisir, tali bahu empuk, back system ventilasi. Dipakai 2x hiking, kondisi sangat baik. Cocok untuk pendakian, camping, atau perjalanan.', 'Pakaian', '["https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400&h=400&fit=crop","https://images.unsplash.com/photo-1622560480605-d83c661bc0ba?w=400&h=400&fit=crop"]', 'Sangat Baik', 'Tersedia', '$now'),
      (9, 1, 'Andi Wijaya', 'Kursi Kantor Ergonomis High-Back Hitam', 650000.0, 'Kursi kantor ergonomis high-back jaring (mesh) warna hitam. Sandaran punggung berlubang tetap dingin. Dudukan busa tebal masih empuk. Roda sliding halus, pengatur tinggi berfungsi normal. Sangat nyaman untuk WFH atau gaming. Kondisi 85%.', 'Mebel', '["https://images.unsplash.com/photo-1589492477829-5e65395b66cc?w=400&h=400&fit=crop","https://images.unsplash.com/photo-1592078615290-033d3c3cfc84?w=400&h=400&fit=crop"]', 'Baik', 'Tersedia', '$now'),
      (10, 2, 'Siti Rahma', 'Meja Belajar Minimalis dengan Rak Sisi', 450000.0, 'Meja belajar kayu minimalis 120x60cm dilengkapi rak sisi 3 susun. Finishing HPL putih masih mulus, tidak ada goresan dalam. Dilipat flat, mudah dipindahkan. Dijual karena pindahan kos. Kondisi sangat baik.', 'Mebel', '["https://images.unsplash.com/photo-1518455027359-f3f8164ba6bd?w=400&h=400&fit=crop","https://images.unsplash.com/photo-1593642632559-0c6d3fc62b89?w=400&h=400&fit=crop"]', 'Sangat Baik', 'Tersedia', '$now'),
      (11, 3, 'Budi Santoso', 'Lemari Pakaian 2 Pintu Kayu Jati Belanda', 1100000.0, 'Lemari pakaian 2 pintu material kayu jati Belanda. Ukuran 100x50x180cm. Ada gantungan baju & rak lipatan. Engsel masih rapat, kunci berfungsi. Cat putih bersih tanpa cacat. Dijual karena renovasi kamar.', 'Mebel', '["https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=400&h=400&fit=crop","https://images.unsplash.com/photo-1631679706909-1844bbd07221?w=400&h=400&fit=crop"]', 'Baik', 'Tersedia', '$now'),
      (12, 1, 'Andi Wijaya', 'Paket Buku Pelajaran SMA Kelas 10 Lengkap', 95000.0, 'Paket lengkap buku pelajaran SMA kelas 10 kurikulum Merdeka: Matematika, Fisika, Kimia, Biologi, Bahasa Indonesia, Bahasa Inggris. Total 6 buku. Kondisi mulus, tidak ada coretan berarti, disampul plastik bening semua.', 'Buku', '["https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=400&h=400&fit=crop","https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=400&h=400&fit=crop"]', 'Baik', 'Tersedia', '$now'),
      (13, 2, 'Siti Rahma', 'Novel Dune – Frank Herbert (Edisi Bahasa Indonesia)', 55000.0, 'Novel Dune karya Frank Herbert versi terjemahan Bahasa Indonesia penerbit Gramedia. Tebal 700+ halaman. Kondisi koleksi pribadi, disampul plastik sejak beli, tidak ada coretan. Halaman masih putih bersih.', 'Buku', '["https://images.unsplash.com/photo-1512820790803-83ca734da794?w=400&h=400&fit=crop","https://images.unsplash.com/photo-1476275466078-4007374efbbe?w=400&h=400&fit=crop"]', 'Sangat Baik', 'Tersedia', '$now'),
      (14, 1, 'Andi Wijaya', 'Sepeda Gunung Polygon Monarch 3 MTB 26"', 1850000.0, 'Sepeda gunung Polygon Monarch 3 ukuran ban 26 inch. Rangka alloy ringan, fork suspensi depan SR Suntour, gigi Shimano 21-speed. Kondisi terawat, ban baru diganti, rantai & kampas rem oke. Siap pakai, sudah dicuci bersih.', 'Lainnya', '["https://images.unsplash.com/photo-1485965120184-e220f721d03d?w=400&h=400&fit=crop","https://images.unsplash.com/photo-1576435728678-68d0fbf94e91?w=400&h=400&fit=crop"]', 'Baik', 'Tersedia', '$now'),
      (15, 3, 'Budi Santoso', 'Set Peralatan Dapur: Wajan + Panci + Spatula', 275000.0, 'Set peralatan dapur lengkap: wajan anti lengket diameter 28cm, panci stainless 20cm, spatula + sutil aluminium. Kondisi bersih, lapisan anti-lengket wajan masih baik. Cocok untuk kos-kosan atau rumah baru. Dijual karena sudah double set.', 'Lainnya', '["https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=400&h=400&fit=crop","https://images.unsplash.com/photo-1584990347449-a25d9e774cd2?w=400&h=400&fit=crop"]', 'Baik', 'Tersedia', '$now')
    ''');

    // Seed Chat Messages
    await db.rawInsert('''
      INSERT INTO chat_messages (senderId, receiverId, message, timestamp, isRead, isBid) VALUES
      (1, 3, 'Halo Mas Budi, iPhone 12 Pro Max nya masih ada?', '$now', 1, 0),
      (3, 1, 'Halo Mas Andi, masih ada dan siap. Kondisi sesuai deskripsi ya.', '$now', 1, 0),
      (1, 3, 'Bisa COD di area Senggoro Mas?', '$now', 0, 0)
    ''');

    // Seed Notifications
    await db.rawInsert('''
      INSERT INTO notifications (userId, title, body, type, isRead, createdAt) VALUES
      (1, 'Selamat Datang!', 'Akun BeliBekas Anda berhasil dibuat. Mulai jelajahi barang bekas berkualitas!', 'welcome', 0, '$now'),
      (5, 'Akun Kurir Disetujui', 'Selamat! Akun kurir Anda telah disetujui oleh admin. Mulai terima orderan sekarang!', 'courier_approved', 1, '$now')
    ''');
  }

  // ===== Close =====
  Future close() async {
    final db = await instance.database;
    db.close();
  }

  // ===== Address Methods =====
  Future<List<Map<String, dynamic>>> getUserAddresses(int userId) async {
    final db = await database;
    return await db.query(
      'addresses',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'isPrimary DESC, id DESC',
    );
  }

  Future<int> addAddress(Map<String, dynamic> addressData) async {
    final db = await database;
    if (addressData['isPrimary'] == 1) {
      await db.update(
        'addresses',
        {'isPrimary': 0},
        where: 'userId = ?',
        whereArgs: [addressData['userId']],
      );
    }
    return await db.insert('addresses', addressData);
  }

  Future<int> updateAddress(int id, Map<String, dynamic> addressData) async {
    final db = await database;
    if (addressData['isPrimary'] == 1) {
      await db.update(
        'addresses',
        {'isPrimary': 0},
        where: 'userId = ?',
        whereArgs: [addressData['userId']],
      );
    }
    return await db.update(
      'addresses',
      addressData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAddress(int id) async {
    final db = await database;
    return await db.delete('addresses', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setPrimaryAddress(int userId, int addressId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('addresses', {'isPrimary': 0}, where: 'userId = ?', whereArgs: [userId]);
      await txn.update('addresses', {'isPrimary': 1}, where: 'id = ?', whereArgs: [addressId]);
    });
  }

  // ===== Notification Methods =====
  Future<List<Map<String, dynamic>>> getNotifications(int userId) async {
    final db = await database;
    return await db.query(
      'notifications',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );
  }

  Future<int> getUnreadNotificationCount(int userId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notifications WHERE userId = ? AND isRead = 0',
      [userId],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<void> markNotificationRead(int notificationId) async {
    final db = await database;
    await db.update(
      'notifications',
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }

  Future<void> markAllNotificationsRead(int userId) async {
    final db = await database;
    await db.update(
      'notifications',
      {'isRead': 1},
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }

  Future<int> addNotification({
    required int userId,
    required String title,
    required String body,
    String type = 'info',
    int? referenceId,
  }) async {
    final db = await database;
    return await db.insert('notifications', {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'referenceId': referenceId,
      'isRead': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}
