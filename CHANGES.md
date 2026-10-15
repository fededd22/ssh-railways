# Moon SSH — SNI-only (بدون Payload): ملخّص التعديلات والنشر

## 1) نوع المشروع (قبل التعديل)
- **Node.js / TypeScript** (Bun lock). نقطة الدخول `server.ts` (جسر SSH عبر **WebSocket/Payload** إلى خادم SSH داخلي على `127.0.0.1:10093`)، + خادم HTTP (Express) + **بوت تلجرام** للتحكم.
- أوامر: البناء `npm run build` (esbuild → `dist/server.cjs`)، التشغيل `npm start` (`node dist/server.cjs`) أو `npm run dev` (`tsx server.ts`).

## 2) ما تغيّر (Payload أُزيل بالكامل، الوضع الآن SNI فقط)

### server.ts
| قبل | بعد |
|---|---|
| ثابت `SSH_WS_PATH="/by_moon_ssh"` ووسيط WebSocket + مُعالج `server.on("upgrade")` يرد `101 Switching Protocols` | **محذوف بالكامل** |
| دالة توليد بايلود: `getSshWsPayloadText()` تُنتج `GET /by_moon_ssh HTTP/1.1[crlf]...` | **محذوفة** |
| زر/أمر «بايلود WebSocket» (`send_payload_ws`, `/ws`, `/payload`) | مُستبدل بـ «🛰️ إعداد SNI» (`send_sni_config`, `/sni`) |
| `FAKE_SNI_HOST="youtube.com"` (تمويه فقط) | `DEFAULT_SNI_HOST = process.env.SNI_HOST \|\| "youtube.com"` |
| — (لا يوجد) | **مستمع TLS عام جديد** `startSniTlsServer()` على `TLS_PORT` (افتراضي 8443) يقبل **أي SNI** (`SNICallback` يقبل كل الأسماء) ويجسر التدفق المفكوك مباشرة إلى SSH |
| — (لا يوجد) | توليد شهادة TLS ذاتية تلقائيًا عبر `openssl` إن لم تكن موجودة |
| — (لا يوجد) | نقاط نهاية جديدة: `/health` (status ok, `payload:false`) و`/config` |

### المولّد الجديد (المدخلات الأربعة → إعداد جاهز)
- `getSniConfigInput()` → `{ domain, username, password, sni }`
- `buildSniConfigText()` → نص إعداد جاهز للاستيراد
- `buildSniShareLink()` → رابط `moon-sni://host:443?sni=..&user=..&pass=..&mode=sni`
- `buildSniJsonConfig()` → JSON بنيوي

### ملفات أخرى
- `README.md` — أُعيد كتابته بالكامل لوضع SNI فقط (المدخلات الأربعة وطريقة توليد الإعداد، نقاط النهاية، النشر).
- `Dockerfile` — تعليق محدّث، `EXPOSE 8080 8443`.
- `docker-compose.yml` — إضافة المنفذ `TLS_PORT` ومتغير `SNI_HOST`.
- `.env.example` — إضافة `TLS_PORT=8443` و`SNI_HOST=youtube.com`.
- `metadata.json` — الوصف صار «SNI-only, no payload».

## 3) التحقق المحلي (ناجح)
- `npm run build` ✓ (esbuild → dist/server.cjs)
- `GET /` → 200 (صفحة الإعداد) · `GET /health` → 200 `{"status":"ok","mode":"sni-only","payload":false,...}` · `GET /config` → 200 (المدخلات + configText + shareLink + json)
- **نفق SNI يعمل**: مصافحة TLS ناجحة مع `-servername youtube.com` / `example.org` / عشوائي، والسجل يؤكد `[TLS] Accepted SNI-only TLS connection, bridging to SSH backend.` و**بانر SSH** يصل عبر النفق: `SSH-2.0-ssh2js1.17.0`.
- لا يوجد أي ملف payload، ولا أي مسار WebSocket/بايلود في الكود.

## 4) متغيرات البيئة المطلوبة
| المتغير | الوصف |
|---|---|
| `PORT` | منفذ HTTP (تضبطه المنصة عادة) — صفحة الإعداد و`/health` و`/config` والـ webhook |
| `TLS_PORT` | منفذ مستمع TLS الخاص بـ SNI (افتراضي 8443) |
| `SNI_HOST` | اسم SNI المموّه المعلن (افتراضي youtube.com) |
| `SSH_USERNAME` / `SSH_PASSWORD` | بيانات اعتماد SSH (افتراضي moon/moon) |
| `APP_URL` | الدومين العام (يُستخدم في الإعداد) |
| `TELEGRAM_BOT_TOKEN` / `TELEGRAM_ADMIN_CHAT_ID` | للتحكم عبر البوت |
| `MURAD_SETUP_PASSWORD` | كلمة مرور صفحة الإعداد (افتراضي moon2026) |

## 5) حالة النشر على Railway — **متوقفة**
- التوكن المزوّد هو **Project Token** (صلاحية على مستوى مشروع/بيئة واحدة فقط): يمكنه قراءة `projects`، ولا يمكنه `me`/إنشاء مشروع.
- `projectCreate` → مرفوض: `Free plan resource provision limit exceeded.` (حد الخطة المجانية).
- `serviceCreate` (على مشروع `spirited-beauty`) → **فشل الاتصال** (`HTTP 000`، `tunnel error`) بلا أي استجابة؛ لم تُنشأ خدمة.
- كذلك `railway` CLI لا يستطيع الوصول إلى `backboard.railway.com` من هذه البيئة (خطأ نفق).
- **البديل الأقرب (يدوي عبر لوحة Railway):**
  1. ادفع الملفات المعدّلة إلى مستودع GitHub خاص بك (فرع/نسخة من `fededd22/a-feed21-v3-ssh`) — مطلوب حساب GitHub بصلاحية كتابة.
  2. Railway → **New Project → Deploy from GitHub repo** واختر المستودع (سيقرأ `Dockerfile`).
  3. **Variables**: `TLS_PORT=8443`, `SNI_HOST=youtube.com`, `SSH_USERNAME`, `SSH_PASSWORD`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_ADMIN_CHAT_ID`, `APP_URL`.
  4. **Networking → TCP Proxy** اختر المنفذ `8443` (لمنفذ TLS العام)، و**Generate Domain** لمنفذ HTTP.
  5. تحقق من `https://<domain>/health` → يجب أن يعيد `payload:false`.
