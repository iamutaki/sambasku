# HMS Push Kit Integration — Flutter

## Tujuan

Dokumen ini menjadi panduan integrasi **Huawei Push Kit (HMS)** ke aplikasi Flutter yang saat ini sudah menggunakan **Firebase Cloud Messaging (FCM)**.

Target utama:

- Menambahkan HMS Push Kit tanpa mengganggu FCM.
- Tetap menggunakan satu codebase Flutter.
- Menjadikan FCM dan HMS sebagai **provider** yang dapat dipertukarkan.
- Memisahkan logic notification dari implementasi vendor.
- Menyimpan token berdasarkan provider (`fcm` / `hms`).
- Mempertahankan notification handling yang sudah ada, termasuk local notification.
- Memungkinkan penambahan provider lain di masa depan tanpa mengubah feature/UI.

> Package utama HMS yang digunakan adalah `huawei_push`, plugin resmi HMS Core untuk Flutter. Versi stable yang diverifikasi saat dokumen ini dibuat adalah `6.15.0+300`, Android-only.

---

# 1. Arsitektur Target

Jangan membuat feature menggunakan `FirebaseMessaging` atau `huawei_push` secara langsung.

Gunakan abstraction:

```text
                    Application
                         │
                         ▼
              NotificationRepository
                         │
                         ▼
               NotificationService
                         │
                Provider Resolver
                         │
             ┌───────────┴───────────┐
             │                       │
             ▼                       ▼
       FcmPushProvider         HmsPushProvider
             │                       │
             ▼                       ▼
  firebase_messaging          huawei_push
             │                       │
             ▼                       ▼
            FCM                     HMS
```

Notification display tetap menjadi concern aplikasi:

```text
FCM / HMS
    │
    ▼
Push Provider
    │
    ▼
Normalized Notification
    │
    ▼
NotificationService
    │
    ├── Foreground
    ├── Background
    ├── Notification tap
    └── Local notification
```

## Prinsip utama

### UI tidak boleh tahu provider

Jangan:

```dart
if (isHuawei) {
  // ...
}
```

di widget.

Jangan juga:

```dart
FirebaseMessaging.instance.getToken();
```

di feature.

Gunakan:

```dart
ref.read(notificationRepositoryProvider).registerDevice();
```

---

# 2. Dependency

Tambahkan HMS:

```yaml
dependencies:
  firebase_messaging: ^YOUR_CURRENT_VERSION
  huawei_push: ^6.15.0+300
```

Opsional untuk mendeteksi keberadaan HMS Core:

```yaml
dependencies:
  huawei_hmsavailability: ^6.13.0+300
```

`huawei_push` adalah plugin resmi HMS Flutter yang dipublikasikan oleh `developer.huawei.com`.

Referensi:

- https://pub.dev/packages/huawei_push
- https://pub.dev/packages/huawei_hmsavailability
- https://developer.huawei.com/consumer/en/hms/huawei-pushkit/

> Jangan melakukan upgrade `firebase_messaging` hanya demi integrasi HMS. Pertahankan versi Firebase yang sedang digunakan dan upgrade secara terpisah bila memang diperlukan.

---

# 3. Konsep Provider

Definisikan provider sebagai abstraction aplikasi.

```dart
enum PushProviderType {
  fcm,
  hms,
}
```

Buat interface:

```dart
abstract interface class PushProvider {
  PushProviderType get type;

  Future<void> initialize();

  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  Stream<PushMessage> get onMessage;

  Stream<PushMessage> get onMessageOpenedApp;

  Future<void> subscribeToTopic(String topic);

  Future<void> unsubscribeFromTopic(String topic);

  Future<void> dispose();
}
```

Interface di atas adalah milik aplikasi, bukan milik Firebase/Huawei.

---

# 4. Normalisasi Message

Jangan membiarkan model Firebase/HMS masuk ke domain.

Buat model internal:

```dart
class PushMessage {
  const PushMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    this.imageUrl,
  });

  final String? id;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
  final String? imageUrl;
}
```

Dengan begitu:

```text
Firebase RemoteMessage ──┐
                         ├──> PushMessage
HMS RemoteMessage ───────┘
```

Feature aplikasi hanya mengenal `PushMessage`.

---

# 5. FCM Provider

Contoh struktur:

```dart
final class FcmPushProvider implements PushProvider {
  FcmPushProvider(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  PushProviderType get type => PushProviderType.fcm;

  @override
  Future<void> initialize() async {
    // Existing FCM initialization.
  }

  @override
  Future<String?> getToken() {
    return _messaging.getToken();
  }

  @override
  Stream<String> get onTokenRefresh {
    return _messaging.onTokenRefresh;
  }

  @override
  Stream<PushMessage> get onMessage {
    return FirebaseMessaging.onMessage.map(_mapMessage);
  }

  @override
  Stream<PushMessage> get onMessageOpenedApp {
    return FirebaseMessaging.onMessageOpenedApp.map(_mapMessage);
  }

  PushMessage _mapMessage(RemoteMessage message) {
    return PushMessage(
      id: message.messageId,
      title: message.notification?.title,
      body: message.notification?.body,
      data: message.data,
    );
  }

  @override
  Future<void> subscribeToTopic(String topic) {
    return _messaging.subscribeToTopic(topic);
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) {
    return _messaging.unsubscribeFromTopic(topic);
  }

  @override
  Future<void> dispose() async {}
}
```

> Sesuaikan dengan implementasi FCM existing. Jangan melakukan rewrite besar jika FCM saat ini sudah berjalan.

---

# 6. HMS Provider

Implementasi HMS berada di infrastructure layer.

Contoh:

```dart
final class HmsPushProvider implements PushProvider {
  @override
  PushProviderType get type => PushProviderType.hms;

  @override
  Future<void> initialize() async {
    // Initialize Huawei Push Kit.
    // Register HMS listeners.
  }

  @override
  Future<String?> getToken() async {
    // Obtain HMS Push Kit token.
    return null;
  }

  @override
  Stream<String> get onTokenRefresh {
    // Map HMS token refresh event.
    return const Stream.empty();
  }

  @override
  Stream<PushMessage> get onMessage {
    // Map HMS RemoteMessage -> PushMessage.
    return const Stream.empty();
  }

  @override
  Stream<PushMessage> get onMessageOpenedApp {
    return const Stream.empty();
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    // HMS topic subscription.
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    // HMS topic unsubscription.
  }

  @override
  Future<void> dispose() async {}
}
```

Implementasi aktual API HMS harus mengikuti versi `huawei_push` yang dipasang. Jangan menyalin API dari versi lama secara blind karena API plugin dapat berubah antarversi.

---

# 7. Provider Resolver

Gunakan resolver khusus untuk memilih provider.

```dart
abstract interface class PushProviderResolver {
  Future<PushProvider?> resolve();
}
```

Implementasi:

```dart
final class DefaultPushProviderResolver
    implements PushProviderResolver {
  DefaultPushProviderResolver({
    required this.fcm,
    required this.hms,
  });

  final PushProvider fcm;
  final PushProvider hms;

  @override
  Future<PushProvider?> resolve() async {
    // 1. Check whether HMS Core / HMS Push is available.
    // 2. If available, use HMS.
    // 3. Otherwise use FCM when GMS/FCM is available.
    // 4. Return null if no provider is available.

    return fcm;
  }
}
```

Jangan hanya menggunakan:

```dart
Platform.isAndroid
```

untuk menentukan HMS.

Android bukan berarti Huawei.

---

# 8. Strategi Provider Selection

Target:

```text
iOS
 └── FCM

Android + HMS available
 └── HMS

Android + no HMS
 └── FCM
```

Secara konsep:

```text
                 Device
                    │
             Is Android?
              /       \
            No         Yes
            │           │
           FCM      HMS available?
                       /      \
                     Yes       No
                      │         │
                     HMS       FCM
```

Jika perangkat tidak memiliki HMS maupun GMS:

```text
No provider
    ↓
Notification unavailable
```

Aplikasi tetap harus dapat berjalan.

---

# 9. Device Registration

Backend jangan menyimpan token sebagai satu field FCM-only.

Gunakan konsep:

```text
device_tokens

id
user_id
token
provider
platform
app_version
device_id
created_at
updated_at
```

Contoh:

```text
user_id | token | provider | platform
--------|-------|----------|---------
1001    | xxx   | fcm      | android
1001    | yyy   | hms      | android
1001    | zzz   | fcm      | ios
```

Hal ini memungkinkan satu user memiliki beberapa device.

---

# 10. Device Token Repository

Domain:

```dart
class DeviceToken {
  const DeviceToken({
    required this.token,
    required this.provider,
    required this.platform,
  });

  final String token;
  final PushProviderType provider;
  final String platform;
}
```

Repository:

```dart
abstract interface class DeviceTokenRepository {
  Future<void> register(DeviceToken token);

  Future<void> unregister({
    required String token,
  });
}
```

Notification provider tidak boleh langsung memanggil Dio/API.

Alurnya:

```text
PushProvider
      │
      ▼
NotificationService
      │
      ▼
DeviceTokenRepository
      │
      ▼
API
```

---

# 11. Token Lifecycle

Token harus didaftarkan ketika:

1. App pertama kali dijalankan.
2. User login.
3. Provider token berubah.
4. App update bila diperlukan.
5. User logout → token dilepas dari user/session.

Flow:

```text
App Start
   │
   ▼
Resolve Provider
   │
   ▼
Initialize Provider
   │
   ▼
Get Token
   │
   ▼
Register Token API
   │
   ▼
Listen Token Refresh
   │
   ▼
Update API
```

Jangan hanya mengambil token sekali saat login.

---

# 12. Notification Service

Buat satu service sebagai entry point.

```dart
abstract interface class NotificationService {
  Future<void> initialize();

  Future<void> registerDevice();

  Future<void> unregisterDevice();

  Future<void> subscribe(String topic);

  Future<void> unsubscribe(String topic);
}
```

Implementasi:

```dart
final class DefaultNotificationService
    implements NotificationService {
  DefaultNotificationService({
    required this.resolver,
    required this.deviceTokenRepository,
    required this.notificationDisplayService,
  });

  final PushProviderResolver resolver;
  final DeviceTokenRepository deviceTokenRepository;
  final NotificationDisplayService notificationDisplayService;

  late final PushProvider provider;

  @override
  Future<void> initialize() async {
    final resolved = await resolver.resolve();

    if (resolved == null) {
      return;
    }

    provider = resolved;

    await provider.initialize();

    provider.onMessage.listen(
      notificationDisplayService.handleForeground,
    );

    provider.onMessageOpenedApp.listen(
      notificationDisplayService.handleOpened,
    );

    provider.onTokenRefresh.listen(
      _registerToken,
    );
  }

  @override
  Future<void> registerDevice() async {
    final token = await provider.getToken();

    if (token == null || token.isEmpty) {
      return;
    }

    await _registerToken(token);
  }

  Future<void> _registerToken(String token) {
    return deviceTokenRepository.register(
      DeviceToken(
        token: token,
        provider: provider.type,
        platform: Platform.operatingSystem,
      ),
    );
  }

  @override
  Future<void> unregisterDevice() async {
    // Remove current provider token from backend.
  }

  @override
  Future<void> subscribe(String topic) {
    return provider.subscribeToTopic(topic);
  }

  @override
  Future<void> unsubscribe(String topic) {
    return provider.unsubscribeFromTopic(topic);
  }
}
```

---

# 13. Local Notification

Jika aplikasi sudah menggunakan `flutter_local_notifications` atau Awesome Notifications, **pertahankan implementasi tersebut**.

HMS/FCM hanya bertanggung jawab terhadap transport.

```text
                 FCM
                  │
                 HMS
                  │
                  ▼
          Notification Provider
                  │
                  ▼
          PushMessage (domain)
                  │
                  ▼
       NotificationDisplayService
                  │
                  ▼
        Awesome Notifications
```

Jangan membuat:

```text
HMS → HMS Local Notification
FCM → FCM Local Notification
```

jika sebenarnya aplikasi sudah mempunyai notification display layer sendiri.

Tujuannya adalah menghindari duplikasi behavior.

---

# 14. Background Notification

Pastikan behavior berikut tetap konsisten:

```text
                    Notification
                         │
              ┌──────────┴──────────┐
              │                     │
          Foreground            Background
              │                     │
              ▼                     ▼
      onMessage/event          provider callback
              │                     │
              └──────────┬──────────┘
                         ▼
               Notification Handler
                         │
                         ▼
                  Local Notification
```

Payload FCM dan HMS harus memiliki kontrak data yang sama.

Contoh:

```json
{
  "type": "event",
  "id": "123",
  "title": "Acara baru",
  "body": "Ada acara baru di Sambas",
  "route": "/event/123"
}
```

Dengan demikian deep link tidak bergantung pada provider.

---

# 15. Notification Payload Contract

Tetapkan payload contract di backend.

Minimal:

```json
{
  "type": "string",
  "id": "string",
  "title": "string",
  "body": "string",
  "route": "string"
}
```

Opsional:

```json
{
  "image": "https://...",
  "action": "open",
  "metadata": {}
}
```

Jangan membuat payload khusus:

```text
FCM payload
HMS payload
```

sebisa mungkin.

Buat satu canonical notification payload, kemudian backend sender menerjemahkannya ke format FCM/HMS.

---

# 16. Backend Sender

Backend juga sebaiknya menggunakan abstraction.

```text
NotificationService
        │
        ▼
NotificationSenderResolver
        │
        ├── FcmNotificationSender
        │
        └── HmsNotificationSender
```

Contoh:

```dart
abstract interface class PushSender {
  PushProviderType get provider;

  Future<void> send({
    required DeviceToken token,
    required NotificationPayload payload,
  });
}
```

Implementasi:

```text
FcmPushSender
    ↓
Firebase Admin / FCM HTTP API

HmsPushSender
    ↓
Huawei Push Kit Server API
```

Backend membaca:

```text
device_tokens.provider
```

bukan menebak provider berdasarkan device.

---

# 17. Struktur Folder yang Direkomendasikan

Untuk Clean Architecture / feature-based:

```text
lib/
└── features/
    └── notification/
        ├── data/
        │   ├── datasources/
        │   │   ├── fcm_push_datasource.dart
        │   │   └── hms_push_datasource.dart
        │   │
        │   ├── models/
        │   │   ├── push_message_model.dart
        │   │   └── device_token_model.dart
        │   │
        │   └── repositories/
        │       └── device_token_repository_impl.dart
        │
        ├── domain/
        │   ├── entities/
        │   │   ├── push_message.dart
        │   │   └── device_token.dart
        │   │
        │   ├── repositories/
        │   │   └── device_token_repository.dart
        │   │
        │   └── services/
        │       ├── notification_service.dart
        │       └── push_provider.dart
        │
        └── presentation/
            └── ...
```

Provider-specific package hanya boleh muncul di:

```text
data/datasources/
```

atau infrastructure layer.

Contoh:

```text
huawei_push
firebase_messaging
```

**tidak boleh di-import oleh UI/domain.**

---

# 18. Riverpod

Jika menggunakan Riverpod, expose abstraction:

```dart
final pushProviderProvider = Provider<PushProvider>((ref) {
  throw UnimplementedError();
});
```

Resolver:

```dart
final pushProviderResolverProvider =
    Provider<PushProviderResolver>((ref) {
  return DefaultPushProviderResolver(
    fcm: ref.read(fcmPushProviderProvider),
    hms: ref.read(hmsPushProviderProvider),
  );
});
```

Notification service:

```dart
final notificationServiceProvider =
    Provider<NotificationService>((ref) {
  return DefaultNotificationService(
    resolver: ref.read(pushProviderResolverProvider),
    deviceTokenRepository:
        ref.read(deviceTokenRepositoryProvider),
    notificationDisplayService:
        ref.read(notificationDisplayServiceProvider),
  );
});
```

Application bootstrap:

```dart
await ref
    .read(notificationServiceProvider)
    .initialize();
```

---

# 19. Huawei AppGallery Connect

Sebelum HMS Push dapat digunakan:

1. Buat project di AppGallery Connect.
2. Tambahkan Android app.
3. Gunakan package name yang sama dengan aplikasi.
4. Konfigurasikan signing certificate fingerprint.
5. Aktifkan Push Kit.
6. Download `agconnect-services.json`.
7. Letakkan file pada:

```text
android/app/agconnect-services.json
```

Huawei mendokumentasikan bahwa konfigurasi AppGallery Connect dan signing certificate fingerprint diperlukan untuk integrasi Push Kit.

> Jangan commit credential/configuration sensitif tanpa memeriksa isi file dan kebijakan repository. Untuk project dengan beberapa flavor, pastikan konfigurasi AGC tidak tertukar antar environment.

---

# 20. Flavor

Jika project menggunakan:

```text
dev
uat
prod
```

jangan langsung mengubah semua flavor.

Tentukan terlebih dahulu apakah AppGallery menggunakan package yang sama atau flavor khusus.

Contoh:

```text
dev
 └── HMS testing

uat
 └── HMS testing

prod
 ├── Google Play
 └── AppGallery
```

Jika package name sama:

```text
id.example.app
```

maka signing certificate dan konfigurasi AppGallery harus konsisten dengan build yang dipublikasikan.

Jika package berbeda:

```text
id.example.app
id.example.app.uat
```

masing-masing perlu konfigurasi AppGallery yang sesuai.

---

# 21. Android Manifest

Jangan menyalin seluruh konfigurasi manifest dari contoh internet tanpa mengecek versi plugin.

Mulai dari konfigurasi yang dibutuhkan oleh `huawei_push` versi yang digunakan.

Kemudian verifikasi:

- notification permission Android 13+
- notification channel
- icon notification
- exported components
- intent filter
- background handling

Integrasi existing FCM jangan dihapus.

Target akhirnya:

```text
AndroidManifest
    ├── FCM configuration
    └── HMS configuration
```

---

# 22. Non-Huawei Compatibility

HMS integration harus bersifat **optional capability**.

Perangkat Samsung/Xiaomi/OPPO/realme/etc. tidak boleh crash hanya karena `huawei_push` terpasang.

Strateginya:

```text
Application Start
      │
      ▼
Resolve Push Provider
      │
      ├── HMS available → HMS
      │
      ├── HMS unavailable → FCM
      │
      └── Neither → Disabled
```

Jangan:

```dart
await HuaweiPush.getToken();
```

tanpa melakukan capability/provider resolution.

---

# 23. Error Handling

Push notification bukan critical dependency untuk menjalankan aplikasi.

Jika HMS gagal:

```text
HMS initialization failed
        │
        ▼
Log error
        │
        ▼
Try FCM
```

Jika FCM gagal:

```text
FCM initialization failed
        │
        ▼
Log error
        │
        ▼
Application continues
```

Jangan:

```dart
await initializeNotifications(); // jika throw → app tidak start
```

Lebih aman:

```dart
try {
  await notificationService.initialize();
} catch (error, stackTrace) {
  logger.error(
    'Notification initialization failed',
    error,
    stackTrace,
  );
}
```

---

# 24. Observability

Tambahkan logging provider:

```text
notification.provider = fcm
notification.provider = hms
notification.provider = none
```

Event yang sebaiknya dicatat:

```text
notification_provider_resolved
notification_token_registered
notification_token_refresh
notification_received
notification_opened
notification_initialization_failed
```

Jangan log full push token ke production log.

---

# 25. Testing Matrix

Minimal test:

| Device | GMS | HMS | Expected |
|---|---:|---:|---|
| Huawei | ❌ | ✅ | HMS |
| Huawei | ❌ | ✅ | HMS |
| Samsung | ✅ | ❌ | FCM |
| Xiaomi | ✅ | ❌ | FCM |
| Android emulator | ✅ | ❌ | FCM |
| iPhone | N/A | N/A | FCM |

Test masing-masing:

- Token registration
- Token refresh
- Foreground notification
- Background notification
- Terminated app notification
- Notification tap
- Deep link
- Topic subscription
- Logout
- Login user berbeda
- Reinstall
- App update

---

# 26. Rollout Plan

Jangan menggabungkan semua perubahan sekaligus.

## Phase 1 — Refactor FCM

Pastikan FCM saat ini sudah berada di balik:

```text
PushProvider
```

Tanpa mengubah behavior user.

Target:

```text
App → PushProvider → FCM
```

## Phase 2 — Notification normalization

Buat:

```text
PushMessage
NotificationPayload
DeviceToken
```

Target:

```text
FCM → PushMessage → NotificationService
```

## Phase 3 — HMS

Tambahkan:

```text
HmsPushProvider
```

Target:

```text
HMS → PushMessage → NotificationService
```

## Phase 4 — Provider resolver

Aktifkan:

```text
HMS → Huawei
FCM → non-Huawei
```

## Phase 5 — Backend

Tambahkan:

```text
provider = fcm | hms
```

pada device token.

## Phase 6 — Testing

Test actual Huawei device.

## Phase 7 — AppGallery release

Setelah HMS notification berhasil:

```text
Build
  ↓
Internal testing
  ↓
AppGallery testing
  ↓
Production
```

---

# 27. Definition of Done

Integrasi dianggap selesai jika:

- [ ] FCM tetap bekerja di perangkat Google/GMS.
- [ ] HMS bekerja di perangkat Huawei.
- [ ] Aplikasi non-Huawei tidak crash.
- [ ] Token HMS berhasil diperoleh.
- [ ] Token FCM tetap berhasil diperoleh.
- [ ] Backend membedakan `fcm` dan `hms`.
- [ ] Token refresh ditangani.
- [ ] Foreground notification bekerja.
- [ ] Background notification bekerja.
- [ ] Terminated notification bekerja.
- [ ] Notification tap bekerja.
- [ ] Deep link bekerja.
- [ ] Local notification tetap menggunakan implementation existing.
- [ ] UI tidak meng-import FCM/HMS package.
- [ ] Domain layer tidak meng-import FCM/HMS package.
- [ ] Provider dapat diganti tanpa mengubah feature.
- [ ] Huawei configuration tidak merusak Google Play build.
- [ ] Production logs tidak membocorkan push token.

---

# 28. Keputusan Arsitektur

### Dipilih

```text
Provider Pattern
        +
Repository Pattern
        +
Capability-based Provider Resolution
        +
Normalized Notification Model
```

### Tidak dipilih

```text
if (isHuawei) di seluruh aplikasi
```

atau:

```text
FirebaseMessaging di UI
HuaweiPush di UI
```

atau:

```text
HMS version dari aplikasi yang berbeda
FCM version dari aplikasi yang berbeda
```

Target akhirnya:

```text
                    Notification API
                           │
                           ▼
                 NotificationService
                           │
                           ▼
                  PushProviderResolver
                           │
                ┌──────────┴──────────┐
                │                     │
                ▼                     ▼
          FcmPushProvider       HmsPushProvider
                │                     │
                ▼                     ▼
               FCM                   HMS
```

Dengan desain ini, menambahkan provider ketiga di masa depan cukup membuat:

```text
XxxPushProvider implements PushProvider
```

tanpa mengubah feature notification yang sudah ada.

---

# 29. Referensi

- Huawei Push Kit Flutter plugin: https://pub.dev/packages/huawei_push
- Huawei Push Kit API reference: https://pub.dev/documentation/huawei_push/latest/
- Huawei Push Kit official documentation: https://developer.huawei.com/consumer/en/hms/huawei-pushkit/
- Huawei Push Kit codelab: https://developer.huawei.com/consumer/en/codelab/HMSPushKit/
- HMS Flutter plugins: https://pub.dev/publishers/developer.huawei.com/packages
