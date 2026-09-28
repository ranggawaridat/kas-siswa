import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================================
  // SQLITE WEB
  // ==========================================================

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  runApp(const KasSiswaApp());
}

// ============================================================
// APP
// ============================================================

class KasSiswaApp extends StatelessWidget {
  const KasSiswaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kas Siswa',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xfff5f7fb),
      ),
      home: const SplashScreen(),
    );
  }
}

// ============================================================
// SPLASH SCREEN
// ============================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomePage(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo_sekolah.png',
              width: 110,
              height: 110,
            ),
            const SizedBox(height: 20),
            const Text(
              'KAS SISWA',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manajemen Kas Kelas',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DATABASE
// ============================================================

class DatabaseHelper {
  static final DatabaseHelper instance =
      DatabaseHelper._internal();

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();

    return _database!;
  }

  Future<Database> _initDatabase() async {
    String databasePath;

    if (kIsWeb) {
      // Browser database.
      //
      // sqflite_common_ffi_web menyimpan database
      // secara persistent melalui IndexedDB.
      databasePath = 'kas_siswa.db';
    } else {
      final databasesPath = await getDatabasesPath();

      databasePath = p.join(
        databasesPath,
        'kas_siswa.db',
      );
    }

    return await openDatabase(
      databasePath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(
    Database db,
    int version,
  ) async {
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        week_start TEXT NOT NULL,
        amount INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(student_id, week_start)
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT NOT NULL,
        amount INTEGER NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await _insertDefaultStudents(db);
  }

  // ==========================================================
  // DEFAULT STUDENTS
  // ==========================================================

  Future<void> _insertDefaultStudents(
    Database db,
  ) async {
    final students = [
      'Rangga',
      'Arven',
      'Bastian',
      'Celestia',
      'Darian',
      'Elric',
    ];

    for (final student in students) {
      await db.insert(
        'students',
        {
          'name': student,
        },
      );
    }
  }

  // ==========================================================
  // STUDENTS
  // ==========================================================

  Future<List<Map<String, dynamic>>> getStudents() async {
    final db = await database;

    return await db.query(
      'students',
      orderBy: 'name ASC',
    );
  }

  Future<int> addStudent(
    String name,
  ) async {
    final db = await database;

    return await db.insert(
      'students',
      {
        'name': name,
      },
    );
  }

  Future<int> deleteStudent(
    int id,
  ) async {
    final db = await database;

    await db.delete(
      'payments',
      where: 'student_id = ?',
      whereArgs: [id],
    );

    return await db.delete(
      'students',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================================
  // PAYMENT
  // ==========================================================

  Future<bool> hasPaid(
    int studentId,
    String weekStart,
  ) async {
    final db = await database;

    final result = await db.query(
      'payments',
      where: '''
        student_id = ?
        AND week_start = ?
      ''',
      whereArgs: [
        studentId,
        weekStart,
      ],
    );

    return result.isNotEmpty;
  }

  Future<void> addPayment({
    required int studentId,
    required String weekStart,
    required int amount,
  }) async {
    final db = await database;

    await db.insert(
      'payments',
      {
        'student_id': studentId,
        'week_start': weekStart,
        'amount': amount,
        'created_at':
            DateTime.now().toIso8601String(),
      },
      conflictAlgorithm:
          ConflictAlgorithm.ignore,
    );
  }

  Future<void> removePayment({
    required int studentId,
    required String weekStart,
  }) async {
    final db = await database;

    await db.delete(
      'payments',
      where: '''
        student_id = ?
        AND week_start = ?
      ''',
      whereArgs: [
        studentId,
        weekStart,
      ],
    );
  }

  Future<List<Map<String, dynamic>>>
      getPaymentsForMonth(
    DateTime month,
  ) async {
    final db = await database;

    final firstDay = DateTime(
      month.year,
      month.month,
      1,
    );

    final nextMonth = DateTime(
      month.year,
      month.month + 1,
      1,
    );

    return await db.rawQuery(
      '''
      SELECT
        payments.*,
        students.name AS student_name
      FROM payments
      INNER JOIN students
        ON students.id = payments.student_id
      WHERE week_start >= ?
        AND week_start < ?
      ORDER BY
        week_start ASC,
        students.name ASC
      ''',
      [
        formatDate(firstDay),
        formatDate(nextMonth),
      ],
    );
  }

  Future<int> getTotalIncome() async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT SUM(amount) AS total
      FROM payments
      ''',
    );

    return (result.first['total'] as int?) ?? 0;
  }

  // ==========================================================
  // EXPENSE
  // ==========================================================

  Future<List<Map<String, dynamic>>> getExpenses() async {
    final db = await database;

    return await db.query(
      'expenses',
      orderBy: 'date DESC',
    );
  }

  Future<int> addExpense({
    required String description,
    required int amount,
    required DateTime date,
  }) async {
    final db = await database;

    return await db.insert(
      'expenses',
      {
        'description': description,
        'amount': amount,
        'date': formatDate(date),
      },
    );
  }

  Future<int> deleteExpense(
    int id,
  ) async {
    final db = await database;

    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getTotalExpense() async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT SUM(amount) AS total
      FROM expenses
      ''',
    );

    return (result.first['total'] as int?) ?? 0;
  }
}

// ============================================================
// MODEL
// ============================================================

class Student {
  final int id;
  final String name;

  Student({
    required this.id,
    required this.name,
  });
}

class Expense {
  final int id;
  final String description;
  final int amount;
  final DateTime date;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
  });
}

// ============================================================
// DATE HELPERS
// ============================================================

String formatDate(
  DateTime date,
) {
  final year =
      date.year.toString().padLeft(4, '0');

  final month =
      date.month.toString().padLeft(2, '0');

  final day =
      date.day.toString().padLeft(2, '0');

  return '$year-$month-$day';
}

String formatDateIndonesia(
  DateTime date,
) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String formatRupiah(
  int value,
) {
  final text = value.toString();

  final buffer = StringBuffer();

  for (int i = 0; i < text.length; i++) {
    if (i > 0 &&
        (text.length - i) % 3 == 0) {
      buffer.write('.');
    }

    buffer.write(text[i]);
  }

  return 'Rp$buffer';
}

String monthName(
  int month,
) {
  const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  return months[month - 1];
}

DateTime startOfWeek(
  DateTime date,
) {
  final difference =
      date.weekday - DateTime.monday;

  final result = DateTime(
    date.year,
    date.month,
    date.day,
  ).subtract(
    Duration(days: difference),
  );

  return DateTime(
    result.year,
    result.month,
    result.day,
  );
}

String weekLabel(
  DateTime date,
) {
  final start = startOfWeek(date);

  final end = start.add(
    const Duration(days: 6),
  );

  return '${formatDateIndonesia(start)} - '
      '${formatDateIndonesia(end)}';
}

// ============================================================
// HOME PAGE
// ============================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() =>
      _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;

  final pages = const [
    DashboardPage(),
    StudentsPage(),
    RecapPage(),
    ExpensesPage(),
  ];

  final titles = const [
    'Kas Siswa',
    'Data Siswa',
    'Rekap Pembayaran',
    'Pengeluaran',
  ];

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[currentIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: pages[currentIndex],
      bottomNavigationBar:
          NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected:
            (index) {
          setState(() {
            currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons
                  .account_balance_wallet_outlined,
            ),
            selectedIcon: Icon(
              Icons.account_balance_wallet,
            ),
            label: 'Kas',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.people_outline,
            ),
            selectedIcon: Icon(
              Icons.people,
            ),
            label: 'Siswa',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.calendar_month_outlined,
            ),
            selectedIcon: Icon(
              Icons.calendar_month,
            ),
            label: 'Rekap',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.receipt_long_outlined,
            ),
            selectedIcon: Icon(
              Icons.receipt_long,
            ),
            label: 'Pengeluaran',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DASHBOARD
// ============================================================

class DashboardPage
    extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() =>
      _DashboardPageState();
}

class _DashboardPageState
    extends State<DashboardPage> {
  static const int weeklyFee = 5000;

  DateTime selectedWeek =
      startOfWeek(DateTime.now());

  List<Student> students = [];

  Set<int> paidStudentIds = {};

  int totalIncome = 0;

  int totalExpense = 0;

  bool loading = true;

  @override
  void initState() {
    super.initState();

    loadData();
  }

  Future<void> loadData() async {
    setState(() {
      loading = true;
    });

    final studentRows =
        await DatabaseHelper.instance
            .getStudents();

    final loadedStudents =
        studentRows
            .map(
              (row) => Student(
                id: row['id'] as int,
                name:
                    row['name'] as String,
              ),
            )
            .toList();

    final paidIds = <int>{};

    for (final student
        in loadedStudents) {
      final paid =
          await DatabaseHelper.instance
              .hasPaid(
        student.id,
        formatDate(selectedWeek),
      );

      if (paid) {
        paidIds.add(student.id);
      }
    }

    final income =
        await DatabaseHelper.instance
            .getTotalIncome();

    final expense =
        await DatabaseHelper.instance
            .getTotalExpense();

    if (!mounted) return;

    setState(() {
      students =
          loadedStudents;

      paidStudentIds =
          paidIds;

      totalIncome =
          income;

      totalExpense =
          expense;

      loading = false;
    });
  }

  Future<void> togglePayment(
    Student student,
  ) async {
    final isPaid =
        paidStudentIds
            .contains(student.id);

    if (isPaid) {
      await DatabaseHelper.instance
          .removePayment(
        studentId:
            student.id,
        weekStart:
            formatDate(selectedWeek),
      );
    } else {
      await DatabaseHelper.instance
          .addPayment(
        studentId:
            student.id,
        weekStart:
            formatDate(selectedWeek),
        amount:
            weeklyFee,
      );
    }

    await loadData();
  }

  void previousWeek() {
    setState(() {
      selectedWeek =
          selectedWeek.subtract(
        const Duration(days: 7),
      );
    });

    loadData();
  }

  void nextWeek() {
    setState(() {
      selectedWeek =
          selectedWeek.add(
        const Duration(days: 7),
      );
    });

    loadData();
  }

  int get weeklyIncome {
    return paidStudentIds.length *
        weeklyFee;
  }

  int get balance {
    return totalIncome -
        totalExpense;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    final paidCount =
        paidStudentIds.length;

    final unpaidCount =
        students.length -
            paidCount;

    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          Center(
            child: Image.asset(
              'assets/images/logo_sekolah.png',
              width: 70,
              height: 70,
            ),
          ),

          const SizedBox(height: 12),

          const Center(
            child: Text(
              'Kas Siswa',
              style: TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  const Text(
                    'Saldo Kas',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    formatRupiah(
                      balance,
                    ),
                    style:
                        const TextStyle(
                      fontSize: 30,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: summaryCard(
                  title:
                      'Pemasukan',
                  value:
                      formatRupiah(
                    totalIncome,
                  ),
                  icon: Icons
                      .arrow_downward,
                  iconColor:
                      Colors.green,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: summaryCard(
                  title:
                      'Pengeluaran',
                  value:
                      formatRupiah(
                    totalExpense,
                  ),
                  icon:
                      Icons.arrow_upward,
                  iconColor:
                      Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Minggu Pembayaran',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    weekLabel(
                      selectedWeek,
                    ),
                    style:
                        const TextStyle(
                      fontSize: 18,
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                    children: [
                      IconButton(
                        onPressed:
                            previousWeek,
                        icon: const Icon(
                          Icons
                              .chevron_left,
                        ),
                      ),
                      const Text(
                        'Minggu',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                      IconButton(
                        onPressed:
                            nextWeek,
                        icon: const Icon(
                          Icons
                              .chevron_right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: statusCard(
                  title:
                      'Sudah Bayar',
                  value:
                      '$paidCount',
                  color:
                      Colors.green,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: statusCard(
                  title:
                      'Belum Bayar',
                  value:
                      '$unpaidCount',
                  color:
                      Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            'Pembayaran Minggu Ini',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontWeight:
                      FontWeight.bold,
                ),
          ),

          const SizedBox(height: 10),

          ...students.map(
            (student) {
              final paid =
                  paidStudentIds
                      .contains(
                student.id,
              );

              return Card(
                margin:
                    const EdgeInsets.only(
                  bottom: 10,
                ),
                child: ListTile(
                  leading:
                      CircleAvatar(
                    backgroundColor:
                        paid
                            ? Colors.green
                            : Colors.red,
                    child: Icon(
                      paid
                          ? Icons.check
                          : Icons.close,
                      color:
                          Colors.white,
                    ),
                  ),
                  title: Text(
                    student.name,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    paid
                        ? 'Sudah membayar'
                        : 'Belum membayar',
                  ),
                  trailing: Text(
                    formatRupiah(
                      weeklyFee,
                    ),
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      color:
                          paid
                              ? Colors
                                  .green
                              : Colors
                                  .red,
                    ),
                  ),
                  onTap: () {
                    togglePayment(
                      student,
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          Card(
            color:
                Colors.indigo.shade50,
            child: Padding(
              padding:
                  const EdgeInsets.all(18),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                children: [
                  const Text(
                    'Terkumpul minggu ini',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  Text(
                    formatRupiah(
                      weeklyIncome,
                    ),
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed:
                generatePdf,
            icon: const Icon(
              Icons.picture_as_pdf,
            ),
            label: const Text(
              'Cetak Laporan PDF',
            ),
          ),
        ],
      ),
    );
  }

  Widget summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: iconColor,
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              title,
              style:
                  const TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              value,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget statusCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              value,
              style:
                  TextStyle(
                fontSize: 26,
                fontWeight:
                    FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(title),
          ],
        ),
      ),
    );
  }

  Future<void> generatePdf() async {
    final pdf = pw.Document();

    final logoData =
        await rootBundle.load(
      'assets/images/logo_sekolah.png',
    );

    final logo =
        pw.MemoryImage(
      logoData.buffer
          .asUint8List(),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat:
            PdfPageFormat.a4,
        build: (context) {
          return [
            pw.Center(
              child: pw.Image(
                logo,
                width: 70,
                height: 70,
              ),
            ),

            pw.SizedBox(
              height: 10,
            ),

            pw.Center(
              child: pw.Text(
                'LAPORAN KAS SISWA',
                style:
                    pw.TextStyle(
                  fontSize: 20,
                  fontWeight:
                      pw.FontWeight
                          .bold,
                ),
              ),
            ),

            pw.SizedBox(
              height: 5,
            ),

            pw.Center(
              child: pw.Text(
                'Minggu '
                '${weekLabel(selectedWeek)}',
              ),
            ),

            pw.SizedBox(
              height: 20,
            ),

            pw.Table
                .fromTextArray(
              headers: [
                'Siswa',
                'Status',
                'Jumlah',
              ],
              data: students.map(
                (student) {
                  final paid =
                      paidStudentIds
                          .contains(
                    student.id,
                  );

                  return [
                    student.name,
                    paid
                        ? 'Sudah Bayar'
                        : 'Belum Bayar',
                    paid
                        ? formatRupiah(
                            weeklyFee,
                          )
                        : '-',
                  ];
                },
              ).toList(),
            ),

            pw.SizedBox(
              height: 20,
            ),

            pw.Text(
              'Total pemasukan: '
              '${formatRupiah(totalIncome)}',
            ),

            pw.Text(
              'Total pengeluaran: '
              '${formatRupiah(totalExpense)}',
            ),

            pw.Text(
              'Saldo: '
              '${formatRupiah(balance)}',
            ),

            pw.SizedBox(
              height: 30,
            ),

            pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment
                      .spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text(
                      'Bendahara',
                    ),
                    pw.SizedBox(
                      height: 50,
                    ),
                    pw.Text(
                      '(________________)',
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text(
                      'Wali Kelas',
                    ),
                    pw.SizedBox(
                      height: 50,
                    ),
                    pw.Text(
                      '(________________)',
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async {
        return pdf.save();
      },
    );
  }
}

// ============================================================
// STUDENTS PAGE
// ============================================================

class StudentsPage
    extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() =>
      _StudentsPageState();
}

class _StudentsPageState
    extends State<StudentsPage> {
  List<Student> students = [];

  @override
  void initState() {
    super.initState();

    loadStudents();
  }

  Future<void> loadStudents() async {
    final rows =
        await DatabaseHelper.instance
            .getStudents();

    if (!mounted) return;

    setState(() {
      students = rows
          .map(
            (row) => Student(
              id: row['id'] as int,
              name:
                  row['name'] as String,
            ),
          )
          .toList();
    });
  }

  Future<void> addStudent() async {
    final controller =
        TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text(
            'Tambah Siswa',
          ),
          content: TextField(
            controller:
                controller,
            autofocus: true,
            decoration:
                const InputDecoration(
              labelText:
                  'Nama siswa',
              border:
                  OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );
              },
              child:
                  const Text(
                'Batal',
              ),
            ),
            FilledButton(
              onPressed:
                  () async {
                final name =
                    controller
                        .text
                        .trim();

                if (name
                    .isEmpty) {
                  return;
                }

                await DatabaseHelper
                    .instance
                    .addStudent(
                  name,
                );

                if (!context
                    .mounted) {
                  return;
                }

                Navigator.pop(
                  context,
                );

                await loadStudents();
              },
              child:
                  const Text(
                'Simpan',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> deleteStudent(
    Student student,
  ) async {
    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Hapus siswa?',
          ),
          content: Text(
            'Data ${student.name} '
            'dan seluruh riwayat '
            'pembayarannya akan '
            'dihapus.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child:
                  const Text(
                'Batal',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child:
                  const Text(
                'Hapus',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    await DatabaseHelper
        .instance
        .deleteStudent(
      student.id,
    );

    await loadStudents();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: ListView.builder(
        padding:
            const EdgeInsets.all(16),
        itemCount:
            students.length,
        itemBuilder:
            (context, index) {
          final student =
              students[index];

          return Card(
            child: ListTile(
              leading:
                  CircleAvatar(
                child: Text(
                  student.name
                      .substring(
                        0,
                        1,
                      )
                      .toUpperCase(),
                ),
              ),
              title: Text(
                student.name,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              trailing:
                  IconButton(
                icon: const Icon(
                  Icons
                      .delete_outline,
                  color:
                      Colors.red,
                ),
                onPressed: () {
                  deleteStudent(
                    student,
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            addStudent,
        icon: const Icon(
          Icons.person_add,
        ),
        label:
            const Text(
          'Tambah',
        ),
      ),
    );
  }
}

// ============================================================
// RECAP PAGE
// ============================================================

class RecapPage
    extends StatefulWidget {
  const RecapPage({super.key});

  @override
  State<RecapPage> createState() =>
      _RecapPageState();
}

class _RecapPageState
    extends State<RecapPage> {
  DateTime selectedMonth =
      DateTime.now();

  List<Map<String, dynamic>>
      payments = [];

  List<Student> students = [];

  @override
  void initState() {
    super.initState();

    loadData();
  }

  Future<void> loadData() async {
    final studentRows =
        await DatabaseHelper
            .instance
            .getStudents();

    final paymentRows =
        await DatabaseHelper
            .instance
            .getPaymentsForMonth(
      selectedMonth,
    );

    if (!mounted) return;

    setState(() {
      students =
          studentRows
              .map(
                (row) => Student(
                  id: row['id']
                      as int,
                  name: row[
                          'name']
                      as String,
                ),
              )
              .toList();

      payments =
          paymentRows;
    });
  }

  bool isPaid(
    int studentId,
    String weekStart,
  ) {
    return payments.any(
      (payment) =>
          payment[
              'student_id'] ==
          studentId &&
          payment[
              'week_start'] ==
          weekStart,
    );
  }

  List<DateTime>
      getWeeksInMonth() {
    final firstDay =
        DateTime(
      selectedMonth.year,
      selectedMonth.month,
      1,
    );

    final lastDay =
        DateTime(
      selectedMonth.year,
      selectedMonth.month +
          1,
      0,
    );

    final firstWeek =
        startOfWeek(
      firstDay,
    );

    final weeks =
        <DateTime>[];

    DateTime current =
        firstWeek;

    while (
        current.isBefore(
      lastDay.add(
        const Duration(
          days: 1,
        ),
      ),
    )) {
      weeks.add(
        current,
      );

      current =
          current.add(
        const Duration(
          days: 7,
        ),
      );
    }

    return weeks;
  }

  Future<void>
      selectMonth() async {
    final picked =
        await showDatePicker(
      context: context,
      initialDate:
          selectedMonth,
      firstDate:
          DateTime(2020),
      lastDate:
          DateTime(2100),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      selectedMonth =
          DateTime(
        picked.year,
        picked.month,
        1,
      );
    });

    await loadData();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final weeks =
        getWeeksInMonth();

    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.all(
            16,
          ),
          child: Card(
            child: ListTile(
              leading:
                  const Icon(
                Icons
                    .calendar_month,
              ),
              title:
                  const Text(
                'Bulan',
              ),
              subtitle:
                  Text(
                '${monthName(selectedMonth.month)} '
                '${selectedMonth.year}',
              ),
              trailing:
                  const Icon(
                Icons.chevron_right,
              ),
              onTap:
                  selectMonth,
            ),
          ),
        ),

        Expanded(
          child:
              SingleChildScrollView(
            scrollDirection:
                Axis.horizontal,
            child:
                SingleChildScrollView(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 16,
              ),
              child:
                  DataTable(
                headingRowColor:
                    WidgetStateProperty
                        .all(
                  Colors
                      .indigo
                      .shade50,
                ),
                columns: [
                  const DataColumn(
                    label: Text(
                      'Nama',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
                  ),
                  ...weeks.map(
                    (week) =>
                        DataColumn(
                      label: Text(
                        '${week.day}/${week.month}',
                      ),
                    ),
                  ),
                ],
                rows: students.map(
                  (student) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            student
                                .name,
                          ),
                        ),
                        ...weeks.map(
                          (week) {
                            final paid =
                                isPaid(
                              student
                                  .id,
                              formatDate(
                                week,
                              ),
                            );

                            return DataCell(
                              Icon(
                                paid
                                    ? Icons
                                        .check_circle
                                    : Icons
                                        .cancel,
                                color:
                                    paid
                                        ? Colors
                                            .green
                                        : Colors
                                            .red,
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// EXPENSE PAGE
// ============================================================

class ExpensesPage
    extends StatefulWidget {
  const ExpensesPage({
    super.key,
  });

  @override
  State<ExpensesPage> createState() =>
      _ExpensesPageState();
}

class _ExpensesPageState
    extends State<ExpensesPage> {
  List<Expense> expenses = [];

  @override
  void initState() {
    super.initState();

    loadExpenses();
  }

  Future<void> loadExpenses() async {
    final rows =
        await DatabaseHelper
            .instance
            .getExpenses();

    if (!mounted) return;

    setState(() {
      expenses = rows
          .map(
            (row) => Expense(
              id: row['id'] as int,
              description:
                  row['description']
                      as String,
              amount:
                  row['amount'] as int,
              date:
                  DateTime.parse(
                row['date'] as String,
              ),
            ),
          )
          .toList();
    });
  }

  Future<void> addExpense() async {
    final descriptionController =
        TextEditingController();

    final amountController =
        TextEditingController();

    DateTime selectedDate =
        DateTime.now();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title:
                  const Text(
                'Tambah Pengeluaran',
              ),
              content:
                  SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller:
                          descriptionController,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Keterangan',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                          amountController,
                      keyboardType:
                          TextInputType
                              .number,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Jumlah',
                        prefixText:
                            'Rp ',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    ListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      leading:
                          const Icon(
                        Icons
                            .calendar_month,
                      ),
                      title:
                          const Text(
                        'Tanggal',
                      ),
                      subtitle:
                          Text(
                        formatDateIndonesia(
                          selectedDate,
                        ),
                      ),
                      onTap:
                          () async {
                        final picked =
                            await showDatePicker(
                          context:
                              context,
                          initialDate:
                              selectedDate,
                          firstDate:
                              DateTime(
                                  2020),
                          lastDate:
                              DateTime(
                                  2100),
                        );

                        if (picked !=
                            null) {
                          setDialogState(
                            () {
                              selectedDate =
                                  picked;
                            },
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                      const Text(
                    'Batal',
                  ),
                ),
                FilledButton(
                  onPressed:
                      () async {
                    final description =
                        descriptionController
                            .text
                            .trim();

                    final amount =
                        int.tryParse(
                      amountController
                          .text
                          .trim(),
                    );

                    if (description
                            .isEmpty ||
                        amount ==
                            null ||
                        amount <=
                            0) {
                      return;
                    }

                    await DatabaseHelper
                        .instance
                        .addExpense(
                      description:
                          description,
                      amount:
                          amount,
                      date:
                          selectedDate,
                    );

                    if (!dialogContext
                        .mounted) {
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                    );

                    await loadExpenses();
                  },
                  child:
                      const Text(
                    'Simpan',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    descriptionController
        .dispose();

    amountController
        .dispose();
  }

  Future<void> deleteExpense(
    Expense expense,
  ) async {
    await DatabaseHelper
        .instance
        .deleteExpense(
      expense.id,
    );

    await loadExpenses();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final total =
        expenses.fold<int>(
      0,
      (sum, expense) =>
          sum + expense.amount,
    );

    return Scaffold(
      body: Column(
        children: [
          Card(
            margin:
                const EdgeInsets.all(
              16,
            ),
            child: Padding(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                children: [
                  const Text(
                    'Total Pengeluaran',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),
                  Text(
                    formatRupiah(
                      total,
                    ),
                    style:
                        const TextStyle(
                      color:
                          Colors.red,
                      fontWeight:
                          FontWeight
                              .bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: expenses.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada pengeluaran.',
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 16,
                    ),
                    itemCount:
                        expenses.length,
                    itemBuilder:
                        (context, index) {
                      final expense =
                          expenses[
                              index];

                      return Card(
                        child:
                            ListTile(
                          leading:
                              const CircleAvatar(
                            backgroundColor:
                                Colors
                                    .red,
                            child:
                                Icon(
                              Icons
                                  .arrow_upward,
                              color:
                                  Colors
                                      .white,
                            ),
                          ),
                          title:
                              Text(
                            expense
                                .description,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                          subtitle:
                              Text(
                            formatDateIndonesia(
                              expense
                                  .date,
                            ),
                          ),
                          trailing:
                              Row(
                            mainAxisSize:
                                MainAxisSize
                                    .min,
                            children: [
                              Text(
                                formatRupiah(
                                  expense
                                      .amount,
                                ),
                                style:
                                    const TextStyle(
                                  color:
                                      Colors
                                          .red,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                              IconButton(
                                icon:
                                    const Icon(
                                  Icons
                                      .delete_outline,
                                  color:
                                      Colors
                                          .red,
                                ),
                                onPressed:
                                    () {
                                  deleteExpense(
                                    expense,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            addExpense,
        icon:
            const Icon(
          Icons.add,
        ),
        label:
            const Text(
          'Pengeluaran',
        ),
      ),
    );
  }
}