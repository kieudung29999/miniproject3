import 'package:path/path.dart' as p;
import 'package:receipt_tracker/core/constants.dart';
import 'package:receipt_tracker/data/models/category.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  Future<Database> get db async => _db ??= await _open();

  static const defaultCategories = <Category>[
    Category(
      name: 'Ăn uống',
      icon: 'restaurant',
      color: 0xFFFF7043,
      keywords:
          'an uong,nha hang,quan an,cafe,ca phe,coffee,tra sua,highlands,starbucks,phuc long,kfc,lotteria,jollibee,pizza,bun,pho,com tam,com ga,banh mi,grabfood,shopeefood,beefood,lau,nuong,restaurant,bakery,tiem banh,sinh to,tra dao,tra da',
    ),
    Category(
      name: 'Di chuyển',
      icon: 'directions_car',
      color: 0xFF42A5F5,
      keywords:
          'grab,gojek,xanh sm,taxi,mai linh,vinasun,xang,petrolimex,xang dau,gui xe,bai xe,ve xe,ve tau,ve may bay,vietjet,vietnam airlines,bamboo airways,parking,phi cau duong',
    ),
    Category(
      name: 'Mua sắm',
      icon: 'shopping_bag',
      color: 0xFFAB47BC,
      keywords:
          'sieu thi,winmart,vinmart,coopmart,big c,lotte mart,aeon,bach hoa xanh,circle k,family mart,familymart,ministop,gs25,shopee,lazada,tiki,tiktok shop,the gioi di dong,dien may xanh,fpt shop,uniqlo,zara,quan ao,giay,mua sam',
    ),
    Category(
      name: 'Hóa đơn & tiện ích',
      icon: 'receipt_long',
      color: 0xFFFFA726,
      keywords:
          'tien dien,evn,tien nuoc,internet,wifi,fpt,viettel,vnpt,mobifone,vinaphone,cuoc,nap tien dien thoai,nap the,dien thoai,truyen hinh,gas,hoa don dien,phi dich vu,phi quan ly',
    ),
    Category(
      name: 'Giải trí',
      icon: 'movie',
      color: 0xFFEC407A,
      keywords:
          'cgv,lotte cinema,galaxy,bhd,phim,rap phim,netflix,spotify,youtube,game,steam,karaoke,du lich,khach san,hotel,booking,agoda,traveloka,vui choi,massage,spa',
    ),
    Category(
      name: 'Sức khỏe',
      icon: 'favorite',
      color: 0xFFEF5350,
      keywords:
          'nha thuoc,thuoc,pharmacy,long chau,pharmacity,an khang,benh vien,phong kham,kham benh,nha khoa,y te,vitamin,gym,fitness,yoga',
    ),
    Category(
      name: 'Giáo dục',
      icon: 'school',
      color: 0xFF26A69A,
      keywords:
          'hoc phi,truong,khoa hoc,sach,nha sach,fahasa,phuong nam,udemy,coursera,van phong pham,vpp,tai lieu,photocopy',
    ),
    Category(
      name: 'Nhà cửa',
      icon: 'home',
      color: 0xFF8D6E63,
      keywords: 'tien nha,thue nha,tien tro,phong tro,chung cu,noi that,sua chua,ikea,ve sinh,thiet bi',
    ),
    Category(
      name: kIncomeCategory,
      icon: 'payments',
      color: 0xFF66BB6A,
      keywords:
          'luong,thuong,hoan tien,nhan tien,chuyen den,tien thuong,lai suat,cashback,refund,salary,bonus,payroll',
    ),
    Category(
      name: kOtherCategory,
      icon: 'category',
      color: 0xFF90A4AE,
      keywords: '',
    ),
  ];

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'receipt_tracker.db'),
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        keywords TEXT NOT NULL DEFAULT ''
      )''');
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category_id INTEGER,
        merchant TEXT,
        note TEXT,
        date INTEGER NOT NULL,
        source TEXT NOT NULL DEFAULT 'manual',
        image_path TEXT,
        raw_text TEXT,
        confidence REAL NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE ai_insights(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month TEXT NOT NULL,
        content TEXT NOT NULL,
        model TEXT,
        created_at INTEGER NOT NULL
      )''');
    await db.execute('CREATE INDEX idx_tx_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_tx_category ON transactions(category_id)');
    await db.execute('CREATE INDEX idx_ins_month ON ai_insights(month)');

    final batch = db.batch();
    for (final c in defaultCategories) {
      batch.insert('categories', c.toMap());
    }
    await batch.commit(noResult: true);
  }
}
