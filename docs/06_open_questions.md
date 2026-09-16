# ZARE002 — ทะเบียนข้อสงสัย

รวมทุกอย่างที่ยัง**ไม่เคลียร์** ไว้ที่เดียว — **รีวิวทุกครั้งที่จบ phase**

> เจอจุดไหนไม่ชัดให้ **note ไว้ที่นี่แล้วเดินต่อ** อย่าหยุดรอ

สถานะ: `⬜` เปิดอยู่ · `🟨` มีคำตอบชั่วคราวแล้ว เดินต่อได้ · `✅` ปิด

| # | เรื่อง | เจ้าของคำตอบ | ยกมาจาก | บล็อกอะไร | สถานะ |
|---|--------|-------------|---------|-----------|--------|
| OQ-02 | **Payment Document No. ใน mockup เป็น link** แต่ไม่มี Object Page → จะให้ link ไปไหน หรือเป็น text ธรรมดา | ผู้ใช้ | Phase 0 | ไม่บล็อก — ทำเป็น text ไปก่อน | 🟨 |
| OQ-03 | mockup ทำปุ่ม Submit เขียว / Reject แดง — Fiori elements ไม่ให้กำหนดสีปุ่ม action เอง รับได้ไหม | ผู้ใช้ | Phase 0 | ไม่บล็อก | 🟨 |
| OQ-04 | **`status` อยู่ระดับ header แต่ผู้ใช้ติ๊กระดับ item** — **ตอบแล้ว 2026-09-15**: เลือก item ใดก็ตาม = เลือกทั้ง payment · handler ต้อง distinct `PaymentUuid` จาก keys แล้วทำงานกับ item ทุกตัวของ payment เหล่านั้น · **ทำที่ RAP ล้วน ไม่ต้องแก้ Fiori** · ปุ่มตั้ง `invocationGrouping: #CHANGE_SET` ไว้แล้วตั้งแต่ Phase 5 เพื่อให้ keys ทั้งหมดมาถึง handler รอบเดียว ไม่ post ใบเดิมซ้ำ | — | Phase 0 | ไม่บล็อก — เป็น spec ของเฟส logic แล้ว | 🟨 |
| OQ-05 | `ZD_REQUEST_STATUS` มี 4 ค่า (`N` `C` `R` `E`) แต่ mockup มี 3 icon — `R` กับ `E` ใช้สีแดงเหมือนกันได้ไหม หรือต้องแยก | ผู้ใช้ | Phase 3 | ไม่บล็อก — ใช้สีแดงทั้งคู่ไปก่อน | 🟨 |
| OQ-12 | รายงานควร filter เฉพาะ `status = 'N'` โดย default ไหม หรือแสดงทุกสถานะ · mockup แสดงทั้ง 🕐 ✅ ❌ = แสดงทุกสถานะ | ผู้ใช้ | Phase 3 | ไม่บล็อก — แสดงทุกสถานะตาม mockup ไปก่อน | 🟨 |
| OQ-13 | **`reject_reason` แก้ได้ทุกสถานะหรือเฉพาะ `N`** — ใบที่ post ไปแล้ว (`C`) ควรแก้เหตุผลได้อีกไหม | ผู้ใช้ / business | Phase 3 | ไม่บล็อก — เปิดให้แก้ได้หมดไปก่อน · ถ้าต้องคุมใช้ `field ( features : instance )` เพิ่มทีหลังได้ | ⬜ |
| OQ-19 | **กติกา: กด Reject ต้องมี `reject_reason` ก่อน** (ผู้ใช้แจ้ง 2026-09-15) → validation ใน `rejectItem`: item ทุกตัวของ payment ที่เลือกต้องมี `RejectReason` ไม่ว่าง ไม่งั้น `failed` + message · ต้องมี message class `ZARE002` ตอนนั้น | — | Phase 6 | ไม่บล็อก — spec ของเฟส logic | 🟨 |
| OQ-20 | **default sort ไม่ทำงาน** — บน launchpad แถวเรียงตามลำดับ insert ไม่ใช่ `PostingDate` DESC ตาม `@UI.presentationVariant` · สาเหตุน่าจะเป็น FE V4 ใช้ presentation variant เป็น default ก็ต่อเมื่อมี `visualizations: [ { type: #AS_LINEITEM } ]` ระบุไว้ด้วย — ยังไม่ได้ใส่ | Claude → ผู้ใช้ | Phase 6 | ไม่บล็อก — cosmetic · แก้ 1 บรรทัดใน metadata extension ถ้าต้องการ | ⬜ |
| OQ-14 | ต้อง log ไหมว่าใครแก้ `reject_reason` เป็นอะไรเมื่อไหร่ — ตอนนี้มีแค่ `last_changed_by` ที่เก็บค่าล่าสุด ไม่มีประวัติ | ผู้ใช้ / audit | Phase 3 | ไม่บล็อก — ถ้าต้องการให้ทำเป็น append-only log table แยก **ไม่ใช่** ย้ายที่เก็บค่าปัจจุบัน (ดู `01_architecture.md` §2) | ⬜ |
| OQ-15 | **สิทธิ์ระดับ company code — ผู้ใช้ควรเห็นทุก CC หรือเฉพาะของตัวเอง** · mockup มีทั้ง `1000` และ `2000` ปนกัน · **ยังไม่รู้คำตอบ ตกลงเดิน `authorization master ( global )` ไปก่อน (2026-09-07)** | ผู้ใช้ / business | Phase 0 | ไม่บล็อกตอนนี้ — แต่ถ้าคำตอบเปลี่ยนเป็น "แยกตาม CC" ต้องรื้อ BDEF เป็น `( instance )` + `get_instance_authorizations` + restriction type/field ที่ IAM App และ business role · **ยิ่งตอบช้ายิ่งรื้อเยอะ** | ⬜ |

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
| OQ-07 | **ชื่อลูกค้าดึงจาก view ไหน** — mockup มี Customer Name แต่ไม่มีใน table | **`I_BusinessPartner`** · `BusinessPartner = customer_code` เทียบตรง ๆ ได้เพราะ ZARI002 แปลง `ALPHA = IN` ก่อน insert อยู่แล้ว · ชื่อลูกค้า **ต่อเอง** จาก `OrganizationBPName1..4` คั่นด้วยช่องว่าง ผ่าน view `ZI_ZARE002_BP` ไม่ใช้ `BusinessPartnerFullName` | 2026-09-07 |

## วิธีใช้

- เจอข้อสงสัยใหม่ระหว่างทำ → **เพิ่มแถวที่นี่ทันที** อย่าเก็บไว้ในหัวหรือใน commit message
- ตอนจบ phase → ไล่ทั้งตาราง ถามเจ้าของคำตอบ แล้วอัปเดตสถานะ
