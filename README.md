# 💸 Chi tiêu AI – Expense Tracker (Flutter)

Ứng dụng theo dõi chi tiêu cá nhân **chạy hoàn toàn offline trên thiết bị**. Người dùng chụp hóa đơn hoặc dán tin nhắn ngân hàng, ứng dụng tự bóc tách số tiền, ngày, cửa hàng, lưu vào SQLite, vẽ biểu đồ và phân tích chi tiêu theo tháng và tuần.

> Mini-project môn Cross-Platform Mobile App Development (Flutter & Dart) – VKU.

---

## ✨ Tính năng

| Nhóm | Mô tả |
|---|---|
| **OCR hóa đơn** | Chụp ảnh hoặc chọn ảnh từ thư viện, nhận dạng chữ bằng Google ML Kit (on-device). |
| **Bóc tách bằng Regex** | Tự lấy **Tổng tiền**, **Ngày**, **Tên cửa hàng** và đoán **danh mục** từ văn bản OCR. |
| **Tin nhắn ngân hàng** | Dán tin nhắn biến động số dư, regex lấy số tiền chi, nội dung và ngày; bỏ qua tin nhận tiền. |
| **Xem lại & sửa tay** | Hộp thoại xác nhận (ảnh hóa đơn, văn bản gốc, các trường chỉnh sửa được) trước khi lưu. |
| **SQLite local** | CRUD đầy đủ, lưu cả ảnh hóa đơn trong thư mục riêng của app. |
| **Biểu đồ tự vẽ** | Pie, Donut và biểu đồ cột biến động theo tuần, vẽ bằng `CustomPainter` có animation. |
| **AI phân tích (offline)** | So sánh với cùng kỳ tháng trước, dự báo cuối tháng, danh mục nổi bật, xu hướng tuần, cảnh báo khoản bất thường. |
| **Giao diện** | Material 3, chế độ sáng/tối (lưu lại lựa chọn), bố cục co giãn theo màn hình. |

---

## 🧱 Công nghệ

- **Flutter / Dart** (Material 3)
- **State management:** `provider`
- **CSDL:** `sqflite` (SQLite local)
- **OCR:** `google_mlkit_text_recognition` (on-device)
- **Ảnh:** `image_picker`, `path_provider`
- **Khác:** `intl` (định dạng tiền và ngày VN), `shared_preferences` (lưu theme)

Ứng dụng **không gọi API hay server nào**, mọi dữ liệu nằm trên máy.


## 🗂️ Cấu trúc thư mục

lib/
├── data/                              # Tầng dữ liệu
│   ├── db/
│   │   └── app_database.dart          # Khởi tạo SQLite, tạo bảng, migration
│   ├── models/
│   │   ├── transaction.dart           # Giao dịch (số tiền, ngày, cửa hàng, ảnh, nguồn…)
│   │   ├── category.dart              # Danh mục chi tiêu
│   │   └── ai_insight.dart            # Kết quả phân tích AI được lưu lại
│   └── repositories/
│       ├── transaction_repository.dart  # CRUD giao dịch
│       ├── category_repository.dart     # CRUD danh mục
│       └── insight_repository.dart      # Lưu/đọc insight
│
├── domain/                            # Tầng nghiệp vụ (không phụ thuộc UI)
│   ├── ocr_service.dart               # Gọi ML Kit nhận dạng chữ từ ảnh
│   ├── regex_parser.dart              # Regex: tổng tiền, ngày, cửa hàng, tin nhắn ngân hàng
│   ├── extraction_pipeline.dart       # Ghép OCR → parser → categorizer thành 1 luồng
│   ├── categorizer.dart               # Gán danh mục theo từ khóa/quy tắc
│   ├── insight_engine.dart            # Phân tích chi tiêu offline (so sánh, dự báo, bất thường)
│   ├── gemini_service.dart            # (Tùy chọn) phân tích nâng cao bằng Gemini khi có mạng
│   ├── csv_exporter.dart              # Xuất giao dịch ra CSV
│   ├── settings_service.dart          # Cài đặt người dùng (theme, tuỳ chọn AI…)
│   └── seed_data.dart                 # Dữ liệu mẫu / danh mục mặc định
│
└── presentation/                      # Tầng giao diện
    ├── painters/                      # CustomPainter: Pie, Donut, Bar tuần
    └── ... 


## 🚀 Cài đặt & chạy

### Yêu cầu
- Flutter SDK 3.19 trở lên (Dart ≥ 3.3)
- Android Studio hoặc VS Code, thiết bị thật hoặc emulator Android

### Các bước

```bash
git clone <repo-url>
cd expense_ai
flutter create . --platforms=android    # sinh thư mục android/ nếu chưa có
flutter pub get
flutter run
```

### Cấu hình Android

Trong `android/app/build.gradle` (hoặc `.kts`):

```gradle
defaultConfig {
    minSdk = 21        // ML Kit yêu cầu >= 21
}
```

(Tùy chọn) khai báo camera trong `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
```

> Nếu build cho iOS, thêm `NSCameraUsageDescription` và `NSPhotoLibraryUsageDescription` vào `ios/Runner/Info.plist`.

---

## 📦 Build APK release (có ký)

1. Tạo keystore:
```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
2. Tạo `android/key.properties` (**không commit file này**):
```properties
   storePassword=<mật khẩu>
   keyPassword=<mật khẩu>
   keyAlias=upload
   storeFile=/đường/dẫn/upload-keystore.jks
```
3. Cấu hình `signingConfigs.release` trong `android/app/build.gradle` để đọc `key.properties`.
4. Build:
```bash
   flutter build apk --release
```
   File xuất ra tại `build/app/outputs/flutter-apk/app-release.apk`.

---

## Hướng dẫn sử dụng

1. Tab **Chi tiêu**, nhấn **Thêm**, chọn:
   - 📷 *Chụp hóa đơn* hoặc 🖼️ *Chọn ảnh hóa đơn*
   - 💬 *Dán tin nhắn ngân hàng*
   - ✏️ *Nhập tay*
2. Kiểm tra lại kết quả trong hộp thoại, sửa nếu OCR sai, rồi nhấn **Lưu**.
3. **Chạm** vào một khoản chi để sửa, **vuốt sang trái** để xóa.
4. Tab **Thống kê**: chọn tháng bằng mũi tên, đổi Pie/Donut, xem cột theo tuần và phần **AI phân tích**.
5. Biểu tượng mặt trăng/mặt trời ở góc trên để đổi giao diện sáng/tối.


