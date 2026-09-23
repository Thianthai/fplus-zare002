# 10 — API Contract ของ ZARE002

เอกสารสำหรับทีม Fiori และทีม BOT · ฝั่ง ABAP เป็นผู้ดูแล contract นี้
เปลี่ยนอะไรจะแจ้งก่อนเสมอ

| API | ทิศทาง | สถานะ |
|---|---|---|
| **#1 Submit** | Fiori → ABAP | ✅ ใช้งานได้ (2026-09-22) |
| #2 Clearing request | ABAP → BOT | ⬜ 8B.5 รอตกลงกับทีม BOT |
| #3 Clearing result | BOT → ABAP | ⬜ 8B.6 |

---

## API #1 — Submit payments

### Endpoint

```
POST /sap/bc/http/sap/ZARE002_SUBMIT
```

- เรียกแบบ **relative URL** จากหน้า app ได้เลย ใช้ session ของผู้ใช้ที่ login อยู่
- สิทธิ์: ผู้ใช้ที่เข้า app **Automatic Incoming Payments** ได้ (business catalog `ZBC_ZARE002`)
  จะเรียก API นี้ได้อัตโนมัติ ไม่ต้องขอสิทธิ์เพิ่ม
- **ไม่ต้องใช้ CSRF token** — tenant นี้ไม่บังคับ (`GET x-csrf-token: fetch` คืน `null` และ POST ผ่าน)
  จะส่ง header มาด้วยก็ไม่มีผลเสีย
- `Content-Type: application/json`

### GET = เอกสารในตัว

```
GET /sap/bc/http/sap/ZARE002_SUBMIT
```

ตอบตัวอย่าง request / response / ความหมายของ Outcome / ข้อจำกัด กลับมาเป็น JSON
เปิดใน browser ที่ login launchpad อยู่ได้เลย ใช้เช็คว่า service ทำงานอยู่ด้วย

### Request

```json
{
  "Payments": [
    "FA163E19-5F2E-1FE1-AAE6-A0E51561A3EF",
    "FA163E195F2E1FE1AAE6A0E51561A3F0"
  ]
}
```

| Field | ชนิด | รายละเอียด |
|---|---|---|
| `Payments` | array of string | `PaymentUuid` ของใบที่ผู้ใช้เลือก รับทั้งแบบ 36 ตัวมีขีดและ 32 ตัวไม่มีขีด ตัวพิมพ์เล็ก/ใหญ่ก็ได้ |

- สูงสุด **60 ใบ** ต่อ 1 request (เกินได้ 400)
- `PaymentUuid` ซ้ำในคำขอเดียว ระบบตัดให้เหลือครั้งเดียว
- ค่าที่ส่งมาคือ `PaymentUuid` ของ entity ไม่ใช่ `PaymentDocumentNo`

### Response 200

```json
{
  "Status": "S",
  "Message": "Payments posted successfully: Success 1 / Error 1",
  "Success": 1,
  "Error": 1,
  "Results": [
    {
      "PaymentUuid": "FA163E19-5F2E-1FE1-AAE6-A0E51561A3EF",
      "PaymentDocumentNo": "1000000002",
      "Outcome": "P",
      "AccountingDocument": "3200000010",
      "Message": "Payment 1000000002 posted: document 3200000010"
    },
    {
      "PaymentUuid": "FA163E19-5F2E-1FE1-AAE6-A0E51561A3F0",
      "PaymentDocumentNo": "1000000003",
      "Outcome": "E",
      "AccountingDocument": "",
      "Message": "Payment 1000000003: cheque must be posted manually"
    }
  ]
}
```

| Field | ชนิด | รายละเอียด |
|---|---|---|
| `Status` | string(1) | `S` = สำเร็จอย่างน้อย 1 ใบ · `E` = ไม่สำเร็จเลย |
| `Message` | string | ข้อความสรุปพร้อมแสดงผู้ใช้ทันที ไม่ต้องประกอบเอง |
| `Success` | int | จำนวนใบที่ `Outcome` เป็น `P` หรือ `A` |
| `Error` | int | จำนวนใบที่ `Outcome` เป็น `E` |
| `Results` | array | 1 แถวต่อ 1 ใบ เรียงตามลำดับที่ประมวลผล |
| `Results[].PaymentUuid` | string | 36 ตัวมีขีด ใช้ map กลับไปหาแถวบนตาราง |
| `Results[].PaymentDocumentNo` | string | เลขใบจาก SBPA ใช้แสดงใน message ให้ผู้ใช้อ่าน |
| `Results[].Outcome` | string(1) | `P` / `A` / `E` — ดูตารางล่าง |
| `Results[].AccountingDocument` | string | เลขเอกสารบัญชีที่ post ได้ ว่างเมื่อ `E` |
| `Results[].Message` | string | ข้อความของใบนั้น ภาษาอังกฤษ ไม่เกิน 200 ตัว |

| Outcome | หมายถึง | นับเป็น |
|---|---|---|
| `P` | post เอกสารบัญชีสำเร็จในรอบนี้ | Success |
| `A` | ใบนี้เคย post ไว้แล้ว ยังไม่ได้ clearing ระบบไม่ post ซ้ำ | Success |
| `E` | ไม่ผ่าน ดูเหตุผลที่ `Message` | Error |

ข้อความใน `Message` ระดับบนสุดมี 3 แบบ

| เคส | Status | Message |
|---|---|---|
| สำเร็จทั้งหมด | `S` | `Payments posted successfully: Success 3` |
| สำเร็จบางส่วน | `S` | `Payments posted successfully: Success 2 / Error 1` |
| ไม่สำเร็จเลย | `E` | `Payments posted failed: Error 3` |

### Response 400

โครงเดียวกับ 200 เพื่อให้อ่าน `Status` กับ `Message` ที่เดียวทุกเคส

```json
{ "Status": "E", "Message": "Payments is empty", "Success": 0, "Error": 0, "Results": [] }
```

เกิดเมื่อ body ไม่ใช่ JSON ที่อ่านได้ · `Payments` ว่าง · `PaymentUuid` ผิดรูปแบบ · เกิน 60 ใบ
ในกรณีนี้ **ไม่มีใบไหนถูกประมวลผลเลย**

### Response 405

method อื่นนอกจาก `GET` / `POST`

---

## สิ่งที่ฝั่ง Fiori ต้องรู้

1. **ต่อใบ 1 transaction** — ใบที่ไม่ผ่านไม่กระทบใบอื่น ถ้า body ถูกต้องจะได้ `200` เสมอ
   แม้ทุกใบจะเป็น `E` (ไม่ใช่ error ของ HTTP)
2. **เวลา** — post ต่อใบประมาณ 1 วินาที 60 ใบ ≈ 1 นาที
   ตั้ง timeout ฝั่ง client ให้พอ และแสดง busy indicator ระหว่างรอ
3. **หลังได้ response** — refresh ตาราง คอลัมน์ **Payment Doc** ของใบที่สำเร็จจะมีค่า
   แล้วแสดง popup จาก `Status` กับ `Message` ระดับบนสุด พร้อมรายการ `Results[].Message`
4. **ปุ่ม Submit กดซ้ำได้** — ใบที่มี Payment Doc แล้วแต่ยังไม่มี Clearing Doc จะได้ `A`
   ใบที่มีครบทั้งสองจะได้ `E` พร้อมข้อความว่าทำครบแล้ว
5. **ยังไม่มี clearing** — ตอนนี้ใบที่สำเร็จจะได้ Payment Doc อย่างเดียว
   Clearing Doc ยังว่างและ status ยังไม่เป็น Completed จนกว่า API #2/#3 กับ BOT จะเสร็จ (8B.5 / 8B.6)

### ตัวอย่างเรียกจาก UI5

```javascript
const response = await fetch("/sap/bc/http/sap/ZARE002_SUBMIT", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ Payments: selectedPaymentUuids })
});

if (!response.ok) {
  const { Message } = await response.json();
  // body ผิดรูปแบบ ไม่มีใบไหนถูกประมวลผล โครง response เหมือนเคส 200
  return;
}

const { Status, Message, Success, Error: errorCount, Results } = await response.json();
// Status และ Message ใช้ขึ้น popup ได้ทันที
// Results ใช้แสดงรายบรรทัด แล้ว refresh ตาราง
```

---

## ข้อความที่ผู้ใช้จะเห็น (message class `ZARE002`)

| No | ข้อความ | เกิดเมื่อ |
|---|---|---|
| 101 | `Payment &1 not found` | `PaymentUuid` ไม่มีในระบบ |
| 102 | `Payment &1 already processed (status &2)` | ใบถูก reject หรือ complete แล้ว หรือมีครบทั้ง Payment Doc และ Clearing Doc |
| 103 | `Payment &1 already posted (document &2), clearing pending` | `Outcome = A` |
| 104 | `Payment &1: cheque must be posted manually` | `payment_method = Cheque` |
| 105 | `Payment &1: missing &2` | ไม่มี item / ไม่มี G/L account / ไม่มี currency / ไม่มี customer code |
| 106 | `Payment &1 does not balance (difference &2)` | ยอดเดบิตไม่เท่าเครดิต ข้อมูลจาก SBPA ไม่ครบหรือไม่ตรงกันเอง |
| 107 | `Special G/L open item balance is not enough` | ใช้เงินรับล่วงหน้าแต่ยอดค้างไม่ตรงกับที่ขอใช้ |
| 108 | `Payment &1: &2&3&4` | FI ปฏิเสธการ post ข้อความที่ตามมาเป็นของ FI เอง |
| 109 | `Payment &1 posted: document &2` | `Outcome = P` |
| 110 | `Payments posted successfully: Success &1` | `Message` ระดับบนสุด สำเร็จทั้งหมด |
| 111 | `Payments posted successfully: Success &1 / Error &2` | `Message` ระดับบนสุด สำเร็จบางส่วน |
| 112 | `Payments posted failed: Error &1` | `Message` ระดับบนสุด ไม่สำเร็จเลย |

---

## API #2 / #3 (BOT) — รอตกลง

โครงที่เสนอไว้ใน `docs/09_submit_analysis.md` §0
จะเขียนลงเอกสารนี้เมื่อคุยกับทีม BOT จบ
