# 09 — Submit: วิเคราะห์ spec ก่อน implement (Phase 8B)

ที่มา: `Submit Logic.docx` (ผู้ใช้ส่ง 2026-09-21) + วิธีทำจาก POC
[`poc-payment`](https://github.com/Thianthai/poc-payment) (`I_JournalEntryTP~Post` ผ่าน EML) และ
[`poc-clearing`](https://github.com/Thianthai/poc-clearing) (SOAP `JournalEntryBulkClearingRequest_In`)
— **เอาแค่วิธีทำ ไม่เอา logic ของ POC**

สถานะ: ✅ **ตัดสินแล้ว 2026-09-22** (ประชุมฟังก์ชันนอล) — ดู §0 · §5 เหลือข้อที่ยังเปิด

---

## 0. ผลประชุม 2026-09-22 — flow ที่ตกลง

```
Fiori (extension)  ──POST list ที่เลือก──▶  API #1  ABAP · HTTP service (ไม่ใช่ RAP action)
                                              ต่อใบ: validate → post JE → COMMIT → เลข JE
                   ◀──ผล post ต่อใบ (success/error)──   แสดงบนจอ ARE002 ทันที
                                              ใบที่ post ได้ → call API #2 ทีละใบ
API #2  BOT (RPA)  ◀──payment + JE + items──   BOT clear ผ่าน standard app (SpGL Z / partial ได้หมด)
API #3  ABAP · inbound  ◀──clearing document / error──  BOT เรียกกลับเมื่อเสร็จ
                                              ABAP: save ผล post + clearing ลง ZTABLE → ยิง SFDC ผลเดียวกัน
```

| ประเด็นใน §3 | ผล |
|---|---|
| 3.3 ที่รัน post | **B — HTTP service** · Reject ยังเป็น RAP action เหมือนเดิม · ผลต่อใบ sync |
| 3.1 SpGL Z clear ผ่าน API ไม่ได้ | **BOT clear ผ่านหน้าจอ** — ไม่ใช้ Clearing API · ไม่เปลี่ยน business |
| 3.2 clearing async / นิยาม C | BOT เรียก API #3 กลับพร้อมเลข clearing → ถึงตอนนั้นค่อย `C` + SFDC · ไม่มี job / AIF |
| 3.4 หา partial เก่าด้วย InvoiceReference | เป็นงานของ BOT บนหน้าจอ — ABAP แค่ส่งข้อมูลให้พอ |
| bgPF / SOAP / SAP_COM_0002 self-call | **ไม่ต้องมี** |

### คำตอบเพิ่มเติม 2026-09-22 (หลังประชุม)

| เรื่อง | คำตอบ |
|---|---|
| UI + table | เพิ่ม 2 คอลัมน์ **Payment Doc** · **Clearing Doc** (header) + column เก็บ **submit message** — ขอ ZARI002 |
| ปุ่ม Submit ตัดสินจาก 2 คอลัมน์ ไม่ใช่ status | ไม่มีทั้งคู่ → post + clearing · มีแค่ Payment Doc → clearing (call BOT) อย่างเดียว · มีครบ → ปฏิเสธ · **ไม่เพิ่ม `P` ใน domain** |
| partial | field `partial_amount` = `X` → post อย่างเดียว · ใบ final (ไม่มี X) → post + clearing (n payment : 1 clearing) · **sprint อื่น ยังไม่ทำ** |
| clearing ต่อ payment | ปกติ 1 : 1 |
| ค่าคงที่ | constant ใน class ก่อน |
| deferred tax | ไม่มีใน spec นี้ |
| หลาย customer/ใบ | ยังเกิดไม่ได้ — default 1 customer |
| ปีบัญชีของ 2 doc | ไม่เก็บ — ใช้ปีของ `posting_date` (assumption FY = ปีปฏิทิน) |

### ข้อมูลจาก tenant 2026-09-22 (Q1–Q9 · company 2000)

| เรื่อง | ผล |
|---|---|
| `I_JournalEntryTP` | released บน `my442178` ✓ |
| ตัวอย่าง `3200000006` (DZ · Fiori) | 2 บรรทัด: bank `0011011003` Dr / customer `1000000014` Cr (PK 15 · recon `0011020001`) · **ไม่มี business place** · ไม่มี WHT · ไม่มี profit center · ยังไม่ clear |
| G/L master | bank: tax cat ว่าง · ไม่ OIM · planning `F0` — fees `0054030012`: tax cat `-` ไม่บังคับ code — **rounding `0059090001`: tax cat `*` + `TaxCodeIsRequired X`** — recon: tax cat `*` |
| WHT ของ customer | **ไม่มี released view** (`I_CustomerWithHoldingTaxTP` ไม่ C1) · customer ทดสอบไม่มี WHT · เสนอกติกา: invoice มี `WithholdingTaxCode` → ปฏิเสธ Submit (OQ) |
| SpGL Z | **ไม่มี open item ใน tenant เลย** — เคส advance ลบทดสอบไม่ได้จนกว่าจะ post บวกก่อน |
| cost center `2002010000` | company 2000 / `A000` · valid ถึง 9999 · ไม่ block primary cost · profit center `0000002000` |
| tax code ที่ใช้ใน 2000 | `O1` 340 · `OX` 2 (เอกสารทดสอบ) · ไม่มี `O0` |

**คำตอบฟังก์ชันนอล 2026-09-22**: doc type **`DS`** · rounding **ไม่ใส่ tax code** ← ⚠️ ขัดกับ master (`TaxCodeIsRequired X`)
ต้องแก้ master หรือกำหนด code — รอดูจากเอกสารตัวอย่าง 5 ขาที่ฟังก์ชันนอลจะส่งมา

**ฟังก์ชันนอล 2026-09-22 (รอบ 2 · จากหน้าจอ Clear Incoming Payments)**:
- bank incoming G/L ที่ SBPA จะส่ง: `11011211` SCB 8303 · `11011214` SCB 7603 · `11011212` TTB 0976 · `11011213` KBK 5698 · `11011215` KBK 9737
  · **เฉพาะ `11011211` บังคับ House Bank `SCB01` / Account `SA001`** (fix ค่า) · ตัวอื่นไม่ใส่
- bank charge `54030012`: **tax code `WP`** (non-taxable purchase 0%) + **business place `0000`**
- rounding `59090001`: **ไม่ใส่ tax code** (หน้าจอผ่านโดยว่าง แม้ master บอก required) · business place `0000`
- ตัวอย่างบนจอ: rounding Cr 1.00 = `rounding_diff` บวก → ตรงสูตร `−rounding_diff`

### เอกสารตัวอย่าง 5 ขา `3500000001` (ฟังก์ชันนอล post จากหน้าจอ 2026-09-22)

company 2000 · `DS` · posting/doc date `20260922` · header text `Doc Test ARE002 #1` · ไม่มี `DocumentReferenceID` ·
invoice ที่จะไป clear = `6000000021` (billing `O600000025` · 10,700 ยัง open)

| # | PK | บัญชี | ยอด | field ที่สำคัญ |
|---|---|---|---|---|
| 001 | 40 | G/L `0011011211` | +10,791.00 | bplace `0000` · house bank `SCB01`/`SA001` · value date `20260922` · **ไม่มี assignment** |
| 002 | 40 | G/L `0054030012` | +10.00 | cost center `2002010000` · tax `WP` · bplace `0000` · assignment `2002010000` (sort key เติมเอง) |
| 003 | 50 | G/L `0059090001` | −1.00 | cost center `2002010000` · bplace `0000` · **ไม่มี tax code** · assignment `20260922` (sort key) |
| 004 | **19** | customer SpGL `Z` (G/L `0022020004`) | −100.00 | bplace `0000` · baseline `20261022` (= posting + 30) · tax `**` (ระบบ derive) |
| 005 | **15** | customer (recon `0011020001`) | −10,700.00 | bplace `0000` · **ไม่มี assignment / text** |

ค่าที่ map กลับมาเป็น test data: `payment_amount 10791` · `fees 10` · `rounding_diff +1` · `advance_payment +100` ·
item เดียว `amount_paid 10700` → สมดุล 0 ✓ เครื่องหมายทุกขาตรงกับสูตรที่ builder ใช้

**สิ่งที่แก้ตาม (commit `a7cdbb9`)**: business place `0000` ทุกบรรทัด · เลขบรรทัดไล่ G/L ให้จบก่อนแล้วต่อ AR ·
บรรทัดลูกหนี้ไม่ใส่ assignment / item text (BOT จับคู่จาก customer + จำนวนเงินแทน — ฟังก์ชันนอลตัดสิน) ·
`ty_line_no` เป็น `n LENGTH 6` ให้ได้ `000001` ไม่ใช่ char ชิดขวา

**post จริงผ่านแล้ว 2026-09-22 — เอกสาร `3500000004`** (ใบทดสอบ `1000002300` สร้างด้วย `set_test_data`)
พิสูจน์ว่า ABAP post เอกสารรับชำระ 5 ขาตาม spec ได้จริงผ่าน `I_JournalEntryTP~Post`

ทางที่กว่าจะผ่าน (เก็บไว้กันลืม):
1. `An entry is required in House bank field` -> บรรทัด bank ของ G/L `11011211` ต้องมี house bank `SCB01`/`SA001`
2. `Tax statement item missing for tax code WP` -> ต้องส่ง `_TaxItems` เอง หน้าจอสร้างให้ แต่ API ไม่สร้าง
   ยอดภาษี 0 ฐานภาษี = ยอด fees
3. `KSCHL is empty` -> tax item ต้องมี `ConditionType` (`MWVS`) คู่กับ account key (`VST`)

**ผลเทียบ `3500000004` กับตัวอย่าง `3500000001` (2026-09-22)**

| # | ตรงไหม | หมายเหตุ |
|---|---|---|
| 001 bank | ✅ | PK 40 · 10,791 · bplace `0000` · `SCB01`/`SA001` · value date ตรง |
| 002 bank charge | ✅ | PK 40 · cc `2002010000` · PC `0000002000` · tax `WP` · **`TaxItemGroup 001`** = tax statement เกิดจริง |
| 003 rounding | ✅ | PK 50 · −1.00 · ไม่มี tax code |
| 004 advance SpGL | ✅ | **PK 19** · G/L `0022020004` · SpGL `Z` · tax `**` · baseline `20261022` — ระบบ derive ให้ครบ |
| 005 ลูกหนี้ | ❌ | ได้ **PK 11** ตัวอย่างเป็น **PK 15** · tax code ได้ `**` ตัวอย่างว่าง · ที่เหลือตรงหมด — **OQ-39 high priority** |

จุดต่างเล็ก: assignment ของบรรทัด G/L — **แก้แล้ว 2026-09-22 ไม่ส่ง assignment เลย** ปล่อยให้ sort key ของแต่ละบัญชีเติมเอง
(001 ว่าง · 002 `2002010000` · 003 `20260922`) · สเปกไม่ได้ระบุเรื่องนี้ ยึดเอกสารตัวอย่างเป็นหลัก (OQ-40 ปิด)

**เก็บปีบัญชีเพิ่ม 2026-09-24**: ตาราง +`payment_fiscal_year` `clearing_fiscal_year` `clearing_message` ·
`find_document` คืนปีมาจาก `I_JournalEntry` · API #4 expose `PaymentAccountingDocumentYear` และ
`InvoiceAccountingDocumentYear` (join `I_JournalEntry` เทียบ company + เลขเอกสาร + posting date) ·
ทดสอบผ่านด้วยเอกสาร `3500000006` ได้ปี `2026` ทั้งคู่ · **ข้อควรระวัง**: `invoice_posting_date` ในตารางต้องตรงกับ
เอกสาร FI จริง ไม่งั้น join ไม่เจอและปีจะว่าง (เจอจริงตอน test data ตั้งวันผิด)

**ช่องว่างของสเปก**: `Submit Logic.docx` ระบุแค่ company code · document date · posting date · doc type `DS` · branch `0000` ที่ header
และ account type / Dr-Cr / G/L / amount ที่บรรทัด — house bank · business place · tax code `WP` · cost center ของ rounding ·
baseline date · assignment ล้วนมาจากฟังก์ชันนอลและเอกสารตัวอย่าง ไม่ได้มาจากสเปก

**POC = method `post_payment_poc` ใน `ZCL_ZARE002_UTIL`** (ผู้ใช้เลือก 2026-09-22) · รอเอกสารตัวอย่าง 5 ขาก่อนเขียน

**ขั้นถัดไปที่ผู้ใช้สั่ง**: POC class post payment ตามเอกสารตัวอย่างในระบบก่อน (พิสูจน์ว่า API post โครงตาม spec ได้จริง —
fees + cost center · rounding · SpGL Z + baseline date) ก่อนออกแบบ API #1–#3 · SQL export อยู่ §6

ยังเปิด: contract JSON ของ API #1 #2 #3 · พฤติกรรมเมื่อ API #2 เรียกไม่ได้ (BOT ล่ม) — ใบค้างที่ "มี Payment Doc" กดซ้ำได้ตามกฎข้างบน

---

## 1. Flow ตาม spec (ย่อ)

```
เลือกหลายใบ → กด Submit → popup ยืนยัน (UI)
  ต่อ 1 payment:
    R1  status ต้องเป็น N หรือ E               (E = submit ซ้ำได้)
    R2  payment_method = Cheque → error ไม่ post  (ข้อความตาม 5.2.6 ข้อ 4 — ยังไม่มี)
    R3  post JE (I_JournalEntryTP)  doc type DS · branch 0000 · doc date = posting date
          001 Dr  G/L bank         = header.gl_account        amount = payment_amount (net)
          002 Dr  G/L 54030012     cost center 2002010000     amount = fees            (ถ้ามี)
          003 Cr/Dr customer       1 บรรทัด / item            amount = amount_paid  (+ = Cr · − CN = Dr)
          004 Dr/Cr G/L 59090001   cost center 2002010000     amount = rounding_diff (− = Dr · + = Cr)
          005 Cr/Dr customer SpGL Z  baseline = posting+30    amount = advance_payment
                (− = ต้องมี SpGL Z open item รวม = ยอด ไม่งั้น error "Special G/L open item balance is not enough.")
    R4  clearing (SOAP)  เฉพาะ item ที่ partial_amount ว่าง · doc type DS
          001 AR line ของ JE ที่เพิ่ง post + payment เก่าที่เคยจ่ายบางส่วน (หาโดย InvoiceReference = accounting_document)
          002 AR line ของ invoice/CN  (accounting_document + FY จาก invoice_posting_date · FinancialAccountType D)
          003 SpGL Z open item ทั้งหมดของ customer
    R5  สำเร็จ → status C → popup Success: n / Error: m
    R6  C → แจ้ง Salesforce (Completed)
    R7  fail → status E + เก็บ error message ลง table · ไม่แจ้ง Salesforce
```

เครื่องหมายฝั่ง API (`JournalEntryItemAmount`: เดบิต = บวก · เครดิต = ลบ) เมื่อแปลงจาก table:

| บรรทัด | amount ที่ส่ง | ที่มา |
|---|---|---|
| bank | `+payment_amount` | Dr |
| fees | `+fees` | Dr |
| customer (ต่อ item) | `−amount_paid` | invoice + → Cr · CN − → Dr — สูตรเดียวครอบทั้งคู่ |
| rounding | `−rounding_diff` | − → Dr · + → Cr — สูตรเดียวครอบทั้งคู่ |
| advance SpGL Z | `−advance_payment` | + → Cr · − → Dr |

**สมดุลที่ต้องเป็นจริงก่อน post**: `payment_amount + fees − Σamount_paid − rounding_diff − advance_payment = 0`
— ZARI002 มี `check_payment_total` เป็นที่ว่างไว้ (OQ-05 ของฝั่งนั้น) ยังไม่เคยเช็ค · ZARE002 ต้องเช็คเองก่อน post

## 2. วิธีทำที่เอามาจาก POC ได้เลย

| เรื่อง | จาก POC | ใช้กับ ZARE002 |
|---|---|---|
| post JE | `MODIFY ENTITIES OF i_journalentrytp ENTITY journalentry EXECUTE post` + `COMMIT ENTITIES` · type `TABLE FOR ACTION IMPORT i_journalentrytp~post` | เหมือนกัน · `_GLItems` (bank/fees/rounding — มี `CostCenter`) · `_ARItems` (customer · มี `SpecialGLCode` สำหรับ 005) · `_CurrencyAmount` role `00` |
| header ที่ POC พบว่าบังคับ | `TaxDeterminationDate` = posting date (time-dependent tax) · `BusinessPlace 0000` ทุกบรรทัด G/L + AR (Thai) | spec ไม่ได้เขียนแต่ต้องใส่ |
| เลขเอกสารหลัง post | late numbering — `MAPPED` ให้แค่ `%pid` · POC query `I_JournalEntry` ด้วย `DocumentReferenceID` ที่ generate เอง | ใช้ `DocumentReferenceID` = `payment_document_no` (10 ตัว ≤ 16) หรือ `CONVERT KEY` ถ้าอยู่ใน save phase ของ RAP |
| WHT | ลูกหนี้ต้องมี `_WithHoldingTaxItems` ครบทุก type ตาม customer master (amount 0) **ไม่งั้น clearing ปฏิเสธ F5 787** | spec ไม่พูดถึง — ต้องอ่าน WHT type ของ customer จาก released CDS แล้วใส่ให้ |
| clearing | SOAP envelope เป็น string · `SOAPAction` + `Content-Type text/xml` · ยิงกลับ `-api` host ของ tenant ผ่าน arrangement (Basic) · `SAP_COM_0002` inbound · response **202 body ว่าง = แค่รับเรื่อง** ผลจริงอยู่ Message Dashboard (AIF) | โครงเดียวกัน · `APARItems` หลาย doc ในคำขอเดียวได้ · `TestDataIndicator` ไว้ simulate |
| ตรวจ open item | `I_OperationalAcctgDocItem` (released) — `ClearingAccountingDocument` ว่าง = ยัง open | ใช้หา AR line ของ invoice / payment เก่า / SpGL |

## 3. จุดที่ spec ชนกับความจริงของ API (ต้องตัดสินก่อนเขียน code)

### 3.1 🔴 Clearing API ไม่รองรับ Special G/L — R4 บรรทัด 003 ทำไม่ได้

POC clearing บันทึกไว้ชัด: `JournalEntryBulkClearingRequest_In` **ไม่รองรับ `SpecialGLCode`** · บรรทัด 003
"clear SpGL Z open item ทั้งหมดของ customer" จึงส่งผ่าน API นี้ไม่ได้ · ทางเลือก:
(ก) ตัด 003 ออก — advance ค้างเป็น SpGL open item ให้บัญชี clear มือ (F-32) ·
(ข) เปลี่ยนวิธี: ตอน advance ติดลบ ไม่ post บรรทัด SpGL ใหม่ แต่ post บรรทัด customer ธรรมดาแล้วให้ clearing
จับกับ SpGL ไม่ได้อยู่ดี · (ค) ถามฟังก์ชันนอลว่า SpGL Z จำเป็นไหม หรือใช้ G/L "เงินรับล่วงหน้า" ธรรมดา (OIM) แทน
→ clear ได้ผ่าน `GLItems`

### 3.2 🔴 Post กับ Clearing อยู่คนละ LUW และ clearing เป็น async — "สำเร็จ" ของ Submit นิยามว่าอะไร

- JE post สำเร็จ = commit แล้วได้เลขเอกสาร (sync)
- clearing = HTTP 202 แปลว่า "รับคำขอ" ยังไม่ clear · ผล (สำเร็จ/ตก) ไปโผล่ที่ AIF ทีหลัง ไม่กลับมาหาเรา
- ถ้า status `C` = "JE post แล้ว + ส่ง clearing แล้ว" → clearing ตกทีหลังจะไม่มีใครรู้ นอกจากไปดู Message Dashboard
- ทางเลือก: (ก) ยอมรับ `C` = post + ส่งคำขอ clearing · (ข) เพิ่ม job ตามผล — query `I_OperationalAcctgDocItem`
  ว่า invoice ถูก clear แล้วจริง (`ClearingAccountingDocument` ไม่ว่าง) ค่อยขึ้น `C` · (ค) เปิด outbound
  *Journal Entry – Clearing Confirmation* ให้ SAP ยิงผลกลับ (ต้องมี inbound รับ)

### 3.3 🔴 RAP action post FI ไม่ได้ — ต้องเลือกที่รัน

SAP ระบุ (POC docs/01): `I_JournalEntryTP~Post` เรียกจาก RAP BO ได้เฉพาะใน **save sequence**
(`save_modified` / determination on save) — ใน action handler (interaction phase) ไม่ได้ · และ `COMMIT ENTITIES`
ห้ามใน RAP ทุกที่ · ผลคือ **1 ครั้งที่กด Submit = 1 LUW** ถ้าอยู่ใน RAP:

| ทาง | ทำยังไง | ได้ | เสีย |
|---|---|---|---|
| **A. ใน saver ของ BO** (`with additional save` ที่มีอยู่) | `rejectItem`-style: action validate + buffer → `save_modified` EXECUTE post ทุกใบ → outer commit | ไม่มี object ใหม่ · pattern เดิม | **all-or-nothing** ใบใดใบหนึ่ง post ตก = rollback ทั้งหมด · เขียน `E` ให้ใบที่ตกไม่ได้ (rollback ไปด้วย) · Success 9 / Error 1 ตาม spec **ทำไม่ได้** · เลขเอกสาร (late numbering) อาจยังไม่รู้ตอน saver → ส่ง clearing ใน LUW เดียวกันไม่ได้ ต้องเป็นรอบถัดไป |
| **B. HTTP Service** (`if_http_service_extension` — ZARI002 ใช้อยู่แล้วขา inbound) | UI extension เรียก `POST /sap/bc/http/sap/zare002_submit` ส่ง list uuid · handler นอก RAP: loop ทีละใบ → post → `COMMIT ENTITIES` → query เลข → SOAP clearing → UPDATE status → SFDC → คืน JSON `{success, error, messages}` | **ต่อใบ 1 LUW** ตรง spec R5/R7 เป๊ะ · sync ได้ popup ทันที · code ไม่ผูก RAP | object ใหม่: HTTP service + handler class + IAM ผูก service · UI extension ต้องเรียก endpoint นี้แทน action (ทีม Fiori extend อยู่แล้ว) · ต้องกัน double-submit เอง |
| **C. Background Processing (bgPF)** | action ตั้ง status `P` → bgPF process ต่อใบ | ต่อใบ 1 LUW · ทนใบเยอะ | **async** — popup บอกได้แค่ "ส่งแล้ว n ใบ" ผลมาทีหลัง · ต้อง refresh ดู · ขัด R5 |

**เสนอ B** — เป็นทางเดียวที่ให้ผลต่อใบแบบ sync ตาม spec · ZARE002 มีทั้ง Reject (RAP action) และ Submit (HTTP
service) ได้ ไม่ขัดกัน · ถ้าฟังก์ชันนอลยอมรับ all-or-nothing สำหรับ Submit (เหมือน Reject) ค่อยกลับไป A

### 3.4 🟠 หา "payment เก่าที่จ่ายบางส่วน" ด้วย `InvoiceReference` — API ตั้งค่านั้นให้ไม่ได้

R4 บรรทัด 001 ให้หา payment เก่าจาก `I_OperationalAcctgDocItem.InvoiceReference = accounting_document` ·
แต่ `_ARItems` ของ `I_JournalEntryTP` **ไม่มี field InvoiceReference** (POC docs/01) — เอกสารที่เราเอง post ไว้
รอบก่อนจะไม่มีค่านี้ → หาไม่เจอ · ทางแก้: เราใส่ **`AssignmentReference` = `accounting_document` ของ invoice**
ที่ทุกบรรทัด customer ตอน post แล้วหาด้วย `AssignmentReference` แทน (ค่าเป็นของเราเอง คุมได้) — ต้องให้ฟังก์ชันนอลยืนยัน

### 3.5 🟠 Deferred output tax — spec ไม่พูดถึงเลย

POC ทั้ง 2 ตัวหมดเวลาไปกับเรื่องนี้: invoice ที่มี deferred tax (DM) ตอนรับเงินต้องโอน DM→O1 เป็นใบ SA แยก
และ clearing ต้องรวม `GLItems` ของ `0021082005` ด้วย · ถ้า invoice ของ SBPA มี deferred tax ทั้งหมดที่เขียนใน spec
จะ clear ไม่ครบ · ต้องถาม: **invoice ที่ผ่าน flow นี้มี deferred tax ไหม** ถ้ามี spec ต้องเพิ่มใบ SA + GL clearing

### 3.6 🟠 Error message เก็บที่ไหน — table ไม่มีที่

R7 "จัดเก็บ Error Message ลง ZTABLE" · header มี `salesforce_message` (ผล SFDC · 200 ตัว) แต่ **`error_message`
ถูก ZARI002 ถอดออกไปแล้ว** (zari002 docs/04 ข้อ 3) · ต้องขอ ZARI002 เพิ่ม field (เช่น `submit_message` char 200 +
`accounting_document` ของ payment ที่ post ได้ + `clearing_message_id` ไว้ตามผลที่ AIF) — cross-package ต้องคุยก่อน

### 3.7 🟡 ค่าคงที่ใน spec

`54030012` · `59090001` · cost center `2002010000` · `+30 วัน` · SpGL `Z` · doc type `DS` · branch `0000`
— hardcode ใน class ได้แต่เปลี่ยนต้อง transport · ผู้ใช้เคยเอ่ยถึง constant table `ZTBC_PARAM` (ZBCUTILITY?)
→ ถ้ามีอยู่แล้ว ใช้ที่นั่น

### 3.8 🟡 อื่น ๆ ที่ต้องรู้

- `AccountingDocumentType` `DS` — POC ใช้ `DZ` (payment) / `DA` (clearing) · `DS` ต้องมีใน config + number range
- `BusinessTransactionType` — POC ใส่ `RFPI` · spec ไม่ระบุ · ปล่อยว่างให้ derive หรือใส่ `RFPI`
- 005 advance ติดลบ: "SpGL open item รวม = advance" เท่ากันเป๊ะถึงจะ post — ถ้ามากกว่าก็ error (ตาม spec)
- customer ต่อ payment: 003 ต่อ item รองรับหลาย customer · แต่ 005 ใช้ "Customer Code" เดียว — ถ้าใบมีหลาย customer ใช้ตัวไหน
- Cheque: ตาม ZARI002 `payment_method` เก็บเป็นคำ `Cheque` / `Cash` / `Transfer` — เทียบ string ตรง ๆ
- SFDC Completed (R6): reuse `ZCL_ZARE002_SFDC_RESULT` (`gc_status_completed` มีแล้ว) · ถ้า SFDC ตกหลัง post
  แล้ว: FI ย้อนไม่ได้ → status `C` แต่ `salesforce_status` = `E` + message ให้ re-send ทีหลัง (ต่างจาก Reject)
- double-submit: ใบเดียวกันถูกกดจาก 2 หน้าจอพร้อมกัน → ต้อง lock (`cl_abap_lock_object` ผ่าน lock object ของ table
  — table เป็นของ ZARI002 · หรือ optimistic: อ่าน status ซ้ำก่อน post + UPDATE ... WHERE status IN (N,E) แล้วดู sy-dbcnt)
- popup ยืนยัน + popup ผล Success/Error = งาน UI extension · backend คืน message ต่อใบ + สรุปนับ

## 4. ที่ต้องเช็คบน tenant ก่อนตัดสิน

| เช็ค | ทำไม |
|---|---|
| `I_JournalEntryTP` มี function `Validate` ไหม (Released Objects) | ถ้ามี ใช้ตรวจก่อน post ลดโอกาส dump |
| released CDS สำหรับ WHT type ของ customer (`I_CustomerWithholdingTax`?) | ใส่ `_WithHoldingTaxItems` ให้ครบ (3.x WHT) |
| doc type `DS` มีใน tenant | R3/R4 |
| `SAP_COM_0002` arrangement + communication system ชี้ `-api` host ของ tenant (`ABAP_DEV` มีอยู่แล้ว — เห็นใน list arrangement) | clearing |
| `ZTBC_PARAM` มีจริงไหม | 3.7 |

## 5. คำถามที่ต้องตอบก่อนสรุปชื่อ object

1. **3.3** — เลือกทาง B (HTTP service · ผลต่อใบ sync) หรือ A (RAP saver · all-or-nothing)?
2. **3.1** — SpGL Z clear ผ่าน API ไม่ได้ จะเอายังไง (ตัด / เปลี่ยนเป็น G/L OIM / clear มือ)?
3. **3.2** — `C` = post + ส่ง clearing แล้ว พอไหม หรือต้องรอ clearing สำเร็จจริง?
4. **3.5** — invoice มี deferred tax ไหม?
5. **3.6** — ขอ ZARI002 เพิ่ม field เก็บ error/เลขเอกสาร ได้ไหม (ชื่ออะไร)?
6. **3.4** — ใช้ `AssignmentReference` = invoice no. เป็นตัวหา partial payment เก่า โอเคไหม?
7. ข้อความ error ของ Cheque (5.2.6 ข้อ 4) และรูปแบบ popup ผล — ทีม Fiori ต้องการ message แบบไหนจาก backend?
8. หลาย customer ในใบเดียว: 005 ใช้ customer ไหน?
9. ค่าคงที่ (3.7) ไว้ที่ไหน?

---

## 6. SQL export เอกสารตัวอย่าง (2026-09-22)

รูปแบบสำหรับ **ADT SQL Console** (Data Preview → SQL Console) — ถ้าจะวางใน console class ให้เติม `INTO TABLE @DATA(lt_x).`
แทนค่า `<CC>` `<DOC>` `<FY>` ก่อนรัน · เอกสารตัวอย่างควรเป็นใบที่ post จาก *Post Incoming Payments* และมีบรรทัดครบที่สุด
(bank · fees · customer · rounding · advance SpGL Z) — ถ้าไม่มีใบเดียวครบ ส่งหลายใบ

| # | ดึงอะไร | View |
|---|---|---|
| Q1 | header | `I_JournalEntry` |
| Q2 | บรรทัด entry view (สิ่งที่ต้องส่งเข้า API) | `I_OperationalAcctgDocItem` |
| Q3 | ทุก field ของบรรทัด (หา baseline date / business place / WHT / planning level) | `I_OperationalAcctgDocItem` `SELECT *` |
| Q4 | G/L view รวมบรรทัด splitting (ไว้เทียบหลัง post) | `I_JournalEntryItem` |
| Q5 | G/L master ของบัญชีที่ spec ใช้ (tax category — ถ้า `*` ต้องใส่ tax code) | `I_GLAccountInCompanyCode` |
| Q6 | WHT type/code ของ customer (ต้องส่ง `_WithHoldingTaxItems`) | `I_CustomerWithholdingTax` (เช็คว่า released) |
| Q7 | SpGL Z open item ของ customer (เช็คยอดก่อน post advance ลบ) | `I_OperationalAcctgDocItem` |
| Q8 | invoice ที่ payment ตัวอย่างจ่าย (ไว้ให้ BOT/clearing เทียบ) | `I_OperationalAcctgDocItem` |
