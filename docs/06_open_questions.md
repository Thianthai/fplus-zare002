# ZARE002 — ทะเบียนข้อสงสัย

รวมทุกอย่างที่ยัง**ไม่เคลียร์** ไว้ที่เดียว — **รีวิวทุกครั้งที่จบ phase**

> เจอจุดไหนไม่ชัดให้ **note ไว้ที่นี่แล้วเดินต่อ** อย่าหยุดรอ

สถานะ: `⬜` เปิดอยู่ · `🟨` มีคำตอบชั่วคราวแล้ว เดินต่อได้ · `⏸` hold โดยผู้ใช้ · `✅` ปิด

| # | เรื่อง | เจ้าของคำตอบ | ยกมาจาก | บล็อกอะไร | สถานะ |
|---|--------|-------------|---------|-----------|--------|
| OQ-02 | **Payment Document No. ใน mockup เป็น link** แต่ไม่มี Object Page → จะให้ link ไปไหน หรือเป็น text ธรรมดา | ผู้ใช้ | Phase 0 | ไม่บล็อก — ทำเป็น text ไปก่อน | 🟨 |
| OQ-03 | mockup ทำปุ่ม Submit เขียว / Reject แดง — Fiori elements ไม่ให้กำหนดสีปุ่ม action เอง รับได้ไหม | ผู้ใช้ | Phase 0 | ไม่บล็อก | 🟨 |
| OQ-04 | **`status` อยู่ระดับ header แต่ผู้ใช้ติ๊กระดับ item** — **ตอบแล้ว 2026-09-15**: เลือก item ใดก็ตาม = เลือกทั้ง payment · handler ต้อง distinct `PaymentUuid` จาก keys แล้วทำงานกับ item ทุกตัวของ payment เหล่านั้น · **ทำที่ RAP ล้วน ไม่ต้องแก้ Fiori** · ปุ่มตั้ง `invocationGrouping: #CHANGE_SET` ไว้แล้วตั้งแต่ Phase 5 เพื่อให้ keys ทั้งหมดมาถึง handler รอบเดียว ไม่ post ใบเดิมซ้ำ | — | Phase 0 | ไม่บล็อก — เป็น spec ของเฟส logic แล้ว | 🟨 |
| OQ-05 | `ZD_REQUEST_STATUS` มี 4 ค่า (`N` `C` `R` `E`) แต่ mockup มี 3 icon — `R` กับ `E` ใช้สีแดงเหมือนกันได้ไหม หรือต้องแยก | ผู้ใช้ | Phase 3 | ไม่บล็อก — ใช้สีแดงทั้งคู่ไปก่อน | 🟨 |
| OQ-12 | รายงานควร filter เฉพาะ `status = 'N'` โดย default ไหม หรือแสดงทุกสถานะ · mockup แสดงทั้ง 🕐 ✅ ❌ = แสดงทุกสถานะ | ผู้ใช้ | Phase 3 | ไม่บล็อก — แสดงทุกสถานะตาม mockup ไปก่อน | 🟨 |
| OQ-13 | **`reject_reason` แก้ได้ทุกสถานะหรือเฉพาะ `N`** — **ตอบแล้ว 2026-09-16**: หลังกด Reject (header `status = 'R'`) **ห้ามแก้อีก** → `field ( features : instance ) RejectReason` readonly เมื่อ `_Payment.Status = 'R'` | ผู้ใช้ | Phase 3 | spec ของ Phase 7 | 🟨 |
| OQ-19 | **กติกา: กด Reject ต้องมี `reject_reason`** — **ยืนยันซ้ำ 2026-09-16** validate เสมอ · ยังต้องตกลง scope: ทุก item ของ payment หรือเฉพาะ item ที่ติ๊ก (OQ-22) | ผู้ใช้ | Phase 6 | spec ของ Phase 7 | 🟨 |
| OQ-21 | **ตอน Reject ต้องเขียน `salesforce_status` / `salesforce_message` ด้วยไหม** — **ตอบแล้ว 2026-09-16: เขียนแค่ `status = 'R'` ไปก่อน** · เพิ่ม 2 field ทีหลังในจุดเดียวกัน (saver) | ผู้ใช้ | Phase 7 | spec ของ 7.6 | 🟨 |
| OQ-22 | **scope ของ validation reject reason** — **ตอบแล้ว 2026-09-16: ทุก item ของ payment** เหตุผล: logic บังคับว่า Reject ครอบทุก item ของ payment อยู่แล้ว (OQ-04) ต่อให้ผู้ใช้ติ๊กไม่ครบ ดังนั้นทุก item ที่จะถูก reject ต้องมีเหตุผล | ผู้ใช้ | Phase 7 | spec ของ 7.6 | 🟨 |
| OQ-23 | **ปุ่ม Submit ปิดด้วยไหมเมื่อ `status = 'R'`** — **ตอบแล้ว 2026-09-16: ปิดทั้ง Submit และ Reject** → `action ( features : instance )` ทั้งสองตัว | ผู้ใช้ | Phase 7 | spec ของ 7.5 / 7.6 | 🟨 |
| OQ-24 | **`save_modified` ถูกเรียกไหมถ้า action ไม่แก้ field ของ item** — **ตัดสินใจแล้ว 2026-09-16: ใช้ fallback ตั้งแต่ต้น** ไม่ spike — `rejectItem` จะ `MODIFY ENTITIES UPDATE FIELDS ( RejectReason )` ด้วยค่าเดิม เพื่อบังคับ save phase ให้ saver ถูกเรียกแน่นอน | ผู้ใช้ | Phase 7 | spec ของ 7.6 | 🟨 |
| OQ-15 | **สิทธิ์ระดับ company code** — **hold (2026-09-16)** หลังตกลงว่าจะแยกตาม CC คุมด้วย business role · **ข้อเท็จจริงที่ต้องจำ: ตอนนี้ยังไม่มีอะไรกรองแถวเลย** — role ให้แค่สิทธิ์เข้า app · `#NOT_REQUIRED` · `( global )` · ไม่มี auth object · ข้อมูลเป็น 2000 ล้วนจึงยังไม่เห็นปัญหา · วันที่ CC 1000 เข้ามา ทุกคนจะเห็นทั้งสองบริษัท · เมื่อกลับมาทำ: auth object `Z_ARE002` + DCL `ZC_ZARE002` + `#CHECK` + IAM App restriction + role · **ไม่ต้องมี `get_instance_authorizations`** เพราะ DCL กันการอ่านแล้ว modify ล้มเอง | ผู้ใช้ | Phase 0 | ไม่บล็อก Reject logic — แต่เป็นความเสี่ยงทันทีที่มีข้อมูล CC 1000 | ⏸ hold |
| OQ-14 | ต้อง log ไหมว่าใครแก้ `reject_reason` เป็นอะไรเมื่อไหร่ — ตอนนี้มีแค่ `last_changed_by` ที่เก็บค่าล่าสุด ไม่มีประวัติ | ผู้ใช้ / audit | Phase 3 | ไม่บล็อก — ถ้าต้องการให้ทำเป็น append-only log table แยก **ไม่ใช่** ย้ายที่เก็บค่าปัจจุบัน (ดู `01_architecture.md` §2) | ⬜ |

## ที่ปิดไปแล้ว

| # | เรื่อง | ข้อสรุป | ปิดเมื่อ |
|---|--------|---------|---------|
| OQ-00 | **แยก table `ZTAR_E002_EDIT` เก็บ `reject_reason` หรือใช้จาก `ZTAR_I002_ITEM`** | **ใช้ `ZTAR_I002_ITEM.REJECT_REASON` · ยกเลิก `ZTAR_E002_EDIT`** — field มีอยู่แล้วและ ZARI002 ออกแบบไว้ให้ ZARE002 เขียนตั้งแต่แรก · managed RAP BO เขียนได้ table เดียว การแยก table บังคับให้ต้องใช้ unmanaged save เพื่อ field เดียว · เหตุผลเต็มใน `01_architecture.md` §2 | 2026-09-07 |
| OQ-06 | **inline edit ใน List Report ต้อง draft-enabled จริงหรือไม่** | **คำถามผิดตั้งแต่ต้น** — ทดสอบจริง 2026-09-07 แล้ว **แก้ในตารางไม่ได้ทั้ง draft และ non-draft** · List Report ที่ไม่มี Object Page ไม่มี edit flow ในตัวเอง และ inline / mass edit เป็น feature ระดับ **manifest ของ Fiori app** ซึ่ง Preview ของ service binding ใน ADT ตั้งไม่ได้ · แก้ด้วย **action ที่มี parameter** ให้ FE generate dialog แทน → draft ถูกถอดออก | 2026-09-07 |
| OQ-08 | **ขอเพิ่ม `last_changed_at` ที่ `ZTAR_I002_ITEM`** | **ทำแล้ว** — เพิ่ม `abp_lastchange_tstmpl` ต่อท้าย `last_changed_by` · ZARI002 ไม่ต้องแก้โค้ด · push ขึ้น `fplus-zari002` แล้ว (commit `0762ada`) · ปลดล็อกให้ `total etag LastChangedAt` ประกาศได้ | 2026-09-07 |
| OQ-16 | **Status แสดงเป็น icon เปล่าตาม mockup ได้ไหม** | **ได้ — แยก element** (2026-09-15): `StatusIcon` = `''` ใส่ `@UI.lineItem` + `criticality` → FE วาดแต่ icon · `Status` ตัวจริงถอดออกจาก lineItem เหลือ `@UI.selectionField` เพื่อให้ filter ยังใช้ fixed value ของ domain ได้ · **ไม่เขียนทับ `Status` ด้วย `''`** เพราะ filter จะไม่มีวันเจออะไร | 2026-09-15 |
| OQ-18 | **BDEF บน tenant เป็น `with unmanaged save` โดยไม่มี saver** — save ไม่ลง table | **แก้แล้ว** commit `f1063da`: กลับเป็น `managed implementation` + `persistent table ztar_i002_item` · diff แค่ 2 บรรทัดตามที่ส่ง · pool ไม่มี saver — ถูกต้อง managed runtime เขียนเอง | 2026-09-15 |
| OQ-17 | **ทีม Fiori จะทำให้คอลัมน์ Reject Reason แก้ได้ด้วยวิธีไหน** | **inline / mass edit มาตรฐานของ FE ใน manifest** (functional ยืนยัน 2026-09-15) → **draft คงไว้** · การ save เป็นของ managed runtime ล้วน: Edit → draft → Activate → เขียน `ztar_i002_item` ทั้งกรอกครั้งแรกและแก้ซ้ำ ไม่มี saver | 2026-09-15 |
| OQ-11 | **object type ของ IAM App / Business Catalog บน tenant นี้** | **เห็นของจริงแล้ว 2026-09-16**: IAM App = `SIA6` (`ZIAM_ZARE002_EXT` — ระบบต่อ `_EXT`) · Business Catalog = `SIA1` (`ZBC_ZARE002`) · App Assignment = `SIA7` (`ZBC_ZARE002_0001`) · Launchpad App Descriptor Item = `UIAD` (`ZARE002_UI5R` — ไฟล์ `.uiad.json`) · **type EXT ของ IAM App คือแบบที่ใช้กับ UI5 app ที่ deploy จาก BAS** (`UI_APP_ID` ชี้ไป UIAD) · ผู้ใช้สร้างเองทั้งหมด | 2026-09-16 |
| OQ-01 | **1 row = 1 item หรือ 1 payment** | **item level ตาม requirement — เห็นจริงบน launchpad 2026-09-16**: payment `1000000002` (3 item) ขึ้น 3 แถว header ซ้ำกัน · ผู้ใช้รับได้ | 2026-09-16 |
| OQ-09 | **สิทธิ์อ่าน `I_BusinessPartner` ของ business role จริง** | **ไม่มีปัญหา** — เปิดด้วย business user บน launchpad แล้ว Customer Name ขึ้นครบทุกแถว รวมชื่อไทยหลายท่อน (`บริษัท สยามแม็คโคร จำกัด สำนักงานใหญ่`) ที่ `concat_with_space` ต่อให้ | 2026-09-16 |
| OQ-10 | **ใครใช้ app / role ไหน** | business role สร้างและ assign แล้ว (Phase 6.5) — รายละเอียด role อยู่ฝั่ง Fiori config ไม่ขึ้น git | 2026-09-16 |
| OQ-20 | **default sort ไม่ทำงาน** | **แก้แล้ว 2026-09-16** — FE V4 หยิบ `@UI.presentationVariant` มาเป็น default ก็ต่อเมื่อมี `visualizations: [ { type: #AS_LINEITEM } ]` · เติมแล้วเรียง `PostingDate` DESC บน launchpad จริง | 2026-09-16 |
| OQ-25 | **ทีม Fiori เปิด inline edit ที่คอลัมน์ Reject Reason** | **ทำแล้ว 2026-09-16** — manifest `inlineEdit.enabledFields: ["RejectReason"]` + **ตัด `@UI.multiLineText` ออก** (ตัวบล็อกจริง) · ค่าลง `ztar_i002_item` reload แล้วยังอยู่ · ระหว่างทาง Claude สรุปผิดว่า RAP ไม่รองรับ — demo `Thianthai/demo-rapedit` พิสูจน์ว่ารองรับ | 2026-09-16 |
| OQ-07 | **ชื่อลูกค้าดึงจาก view ไหน** — mockup มี Customer Name แต่ไม่มีใน table | **`I_BusinessPartner`** · `BusinessPartner = customer_code` เทียบตรง ๆ ได้เพราะ ZARI002 แปลง `ALPHA = IN` ก่อน insert อยู่แล้ว · ชื่อลูกค้า **ต่อเอง** จาก `OrganizationBPName1..4` คั่นด้วยช่องว่าง ผ่าน view `ZI_ZARE002_BP` ไม่ใช้ `BusinessPartnerFullName` | 2026-09-07 |

## วิธีใช้

- เจอข้อสงสัยใหม่ระหว่างทำ → **เพิ่มแถวที่นี่ทันที** อย่าเก็บไว้ในหัวหรือใน commit message
- ตอนจบ phase → ไล่ทั้งตาราง ถามเจ้าของคำตอบ แล้วอัปเดตสถานะ
