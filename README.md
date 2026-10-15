# Moon SSH — SNI-Only Tunnel Server (بدون Payload) + بوت تلجرام

خادم نفق **SSH عبر TLS بتمويه SNI فقط** — **بدون أي Payload** (لا WebSocket، لا HTTP payload، لا CONNECT).
تتم إدارته بالكامل عبر **بوت تلجرام**، ولا توجد أي واجهة ويب أو تسجيل دخول — البوت هو نقطة التحكم الوحيدة،
ويعمل حصريًا مع معرف الأدمن المحدد في `TELEGRAM_ADMIN_CHAT_ID`.

## الوضع: SNI فقط (بدون Payload)

- مستمع **TLS عام** (المنفذ `TLS_PORT`، افتراضيًا `8443`) يقبل **أي اسم SNI** (التمويه فقط، لا يُتحقق منه أبدًا)
  ويمرّر التدفق المفكوك **مباشرة إلى خادم SSH**.
- **لا يوجد** مسار WebSocket ولا أي Payload — تمت إزالة كل ما يتعلق بالـ Payload من الكود بالكامل.
- العميل يحتاج **أربعة مدخلات فقط**: الدومين (Host)، اسم المستخدم، كلمة المرور، و SNI.

## المدخلات الأربعة وكيفية توليد إعداد VPN

| المدخل | الوصف | المصدر |
|---|---|---|
| **الدومين (Host)** | نطاق الخدمة العام | يُكتشف تلقائيًا من الطلبات أو `APP_URL` |
| **اسم المستخدم** | مستخدم SSH | `SSH_USERNAME` (افتراضي `moon`) |
| **كلمة المرور** | كلمة مرور SSH | `SSH_PASSWORD` (افتراضي `moon`) |
| **SNI** | اسم التمويه | `SNI_HOST` (افتراضي `youtube.com`) |

عند إدخالها، يولّد الخادم إعدادًا جاهزًا للاستيراد في تطبيقات VPN (HTTP Custom / TLS Tunnel / v2ray / SSH+SNI):

- **نص الإعداد:** `GET /config` → الحقل `configText`
- **رابط الاستيراد:** `GET /config` → الحقل `shareLink` (بصيغة `moon-sni://host:443?sni=...&user=...&pass=...`)
- **JSON:** `GET /config` → الحقل `json`
- **من تلجرام:** زر «🛰️ إعداد SNI» أو الأمر `/sni`

## المزايا

- نفق **SSH** كامل عبر TLS بتمويه SNI (بدون Payload).
- تغيير اسم المستخدم/كلمة المرور لحساب SSH مباشرة من تلجرام (بدون إعادة نشر).
- عرض حالة الخادم (تشغيل، القرص، الذاكرة) والمتصلين النشطين (`/devices`).
- إدارة مشرفين ثانويين (إضافة/حذف) من داخل تلجرام.
- عرض آخر سجلات التشغيل.
- أي مستخدم آخر غير الأدمن (أو المشرفين الثانويين) يُتجاهل تلقائيًا وبصمت.

**غيّر بيانات الاعتماد قبل أي نشر عام.**

## نقاط النهاية (HTTP)

| المسار | الوصف |
|---|---|
| `/` | صفحة الإعداد (محمية بكلمة مرور) إن لم يُضبط البوت، وإلا تحويل إلى `/config` |
| `/health` | فحص الصحة — `{"status":"ok","mode":"sni-only","payload":false,...}` |
| `/config` | المدخلات الأربعة + نص/رابط/JSON الإعداد الجاهز للاستيراد |
| `/telegram/webhook` | ويب هوك تلجرام |

## التشغيل محليًا

**المتطلبات:** Node.js 22+ و `openssl` (لتوليد شهادة TLS ذاتية).

1. تثبيت الاعتماديات: `npm install`
2. انسخ `.env.example` إلى `.env` واضبط:
   - `APP_URL` — نطاق الخادم العام
   - `TELEGRAM_BOT_TOKEN` — توكن بوت تلجرام
   - `TELEGRAM_ADMIN_CHAT_ID` — معرف حساب تلجرام المسموح له وحده بالتحكم
   - `TLS_PORT` (افتراضي `8443`) و `SNI_HOST` (افتراضي `youtube.com`)
3. تشغيل التطبيق: `npm run dev`
4. من تلجرام: أرسل `/start` للبوت لعرض القائمة الرئيسية.

## النشر عبر Docker

```bash
docker build -t ssh-bot .
docker run -e TELEGRAM_BOT_TOKEN=... -e TELEGRAM_ADMIN_CHAT_ID=... -e APP_URL=https://your-domain.com \
  -e TLS_PORT=8443 -e SNI_HOST=youtube.com \
  --ulimit nofile=65536:65536 \
  -p 3000:3000 -p 8443:8443 ssh-bot
```

## النشر على Railway

1. اربط المستودع بخدمة Railway (Dockerfile أو Nixpacks).
2. اضبط متغيرات البيئة: `TELEGRAM_BOT_TOKEN`, `TELEGRAM_ADMIN_CHAT_ID`, `APP_URL`, `SSH_USERNAME`, `SSH_PASSWORD`, `SNI_HOST`, `TLS_PORT`.
3. Railway يضبط `PORT` تلقائيًا (HTTP). لفتح منفذ TLS العام أضف **TCP Proxy** يشير إلى `TLS_PORT` (8443) من إعدادات الخدمة → Networking.

**ملاحظة تخزين:** ملفات `admin.json`/`settings.json`/`ssh-credentials.json` تُحفظ داخل `DATA_DIR` (افتراضيًا `/app/data`).
عرّف `TELEGRAM_ADMIN_CHAT_ID` دائمًا كمتغير بيئة (الكود يعتبره الأولوية) حتى لا تفقد ملكية البوت.
