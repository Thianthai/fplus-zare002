# ZARE002 — Implementation Phases

ทำทีละ phase — จบ phase แล้ว push → ฝั่ง SAP pull + activate → verify → ค่อยขึ้น phase ถัดไป

สัญลักษณ์: `⬜` ยังไม่ทำ · `🟨` กำลังทำ / ส่ง code ให้แล้วรอ activate · `✅` เสร็จ

> **ผลจริง (2026-09-07): เดินถึง Phase 4 แล้ว และ draft ถูกเปิดใช้** — object ทั้งหมดของ
> Phase 1–4 activate + push ขึ้น repo แล้ว (commit `7936197`) เหลือแค่ยืนยันผลทดสอบ 4.1 / 4.8
>
> **ลำดับนี้ถูกจัดใหม่เมื่อ 2026-09-07** — เดิมเอา DDIC (draft table + แก้ table ของ ZARI002)
> ไว้ก่อน CDS เพราะคิดว่า draft เป็นของบังคับ · ตอนนี้เดินแบบ **non-draft ก่อนแล้ววัดผลจริง**
> DDIC จึงถูกเลื่อนไปเป็น Phase 4 และเป็น **phase ที่อาจไม่ต้องทำเลย**

---

## Phase 0 — Repository & package setup

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 0.1 | สร้าง local repo + `docs/` + `README.md` + `CLAUDE.md` | Claude | ✅ |
| 0.2 | Push commit แรก (เอกสารล้วน) ขึ้น GitHub | ผู้ใช้ | ⬜ |
| 0.3 | สร้าง package `ZARE002` บน tenant | ผู้ใช้ | ✅ |
| 0.4 | ผูก abapGit repo กับ package `ZARE002` | ผู้ใช้ | ✅ |
| 0.5 | abapGit push ให้ SAP serialize `.abapgit.xml` + `package.devc.xml` ขึ้นมาเป็น baseline | ผู้ใช้ | ✅ |
| 0.6 | Claude ตรวจ baseline แล้วอัปเดต path ในเอกสารให้ตรง | Claude | ✅ |

**Exit criteria**: pull/push ระหว่าง GitHub ↔ tenant ผ่านทั้ง 2 ทาง

> ⚠️ **ห้ามเขียน `.abapgit.xml` / `package.devc.xml` เองล่วงหน้า** — ZARI002 เจอมาแล้วว่า
> folder logic ที่เขียนมือไม่ตรงกับที่ ADT wizard ตั้ง ทำให้ link ไม่ผ่าน (HTTP 500)

---

## Phase 1 — CDS read layer

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 1.1 | `ZI_ZARE002_PYMT` — interface view บน `ztar_i002_pymt` (1:1) | Claude → ผู้ใช้ | ✅ |
| 1.2 | `ZI_ZARE002_BP` — interface view บน `I_BusinessPartner` ต่อ `OrganizationBPName1..4` เป็น `CustomerName` | Claude → ผู้ใช้ | ✅ |
| 1.3 | `ZI_ZARE002_ITEM` — interface view บน `ztar_i002_item` (1:1) + association `_Payment` `_BusinessPartner` | Claude → ผู้ใช้ | ✅ |
| 1.4 | ใส่ `@Semantics.amount.currencyCode` ให้ field จำนวนเงินทุกตัว | Claude → ผู้ใช้ | ✅ |
| 1.5 | Data Preview `ZI_ZARE002_BP` — ยืนยันว่าชื่อที่ต่อออกมาตรงกับที่ต้องการ ไม่มีช่องว่างซ้อน | ผู้ใช้ | ⬜ |
| 1.6 | Data Preview `ZI_ZARE002_ITEM` — เห็นข้อมูลจริงที่ ZARI002 ยิงเข้ามาครบทุกคอลัมน์ **รวม Customer Name** | ผู้ใช้ | ⬜ |

**Exit criteria**: Data Preview แสดงครบทั้ง 12 คอลัมน์ตาม `04_field_mapping.md`

> phase นี้ **ไม่ขึ้นกับข้อสงสัยที่ค้างอยู่เลยสักข้อ** เริ่มได้ทันที

---

## Phase 2 — RAP Business Object (non-draft)

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 2.1 | `ZR_ZARE002` — root view entity (projection บน `ZI_ZARE002_ITEM`) | Claude → ผู้ใช้ | ✅ |
| 2.2 | `ZR_ZARE002` — behavior definition **managed ไม่มี draft · update อย่างเดียว** | Claude → ผู้ใช้ | ✅ |
| 2.3 | `field ( readonly )` ทุก field ยกเว้น `RejectReason` | Claude → ผู้ใช้ | ✅ |
| 2.4 | `ZBP_R_ZARE002` — behavior pool + `lhc_Item` (ยังว่าง) | Claude → ผู้ใช้ | ✅ |
| 2.5 | activate BDEF ผ่าน — ยืนยันว่าไม่มี mapping error | ผู้ใช้ | ✅ |
| 2.6 | ทดสอบ EML update `reject_reason` ได้จริง | ผู้ใช้ | ✅ |

**Exit criteria**: EML update `reject_reason` แล้วค่าลง `ztar_i002_item` จริง

`authorization master ( global )` — ทุกคนที่เข้า app ได้เห็นทุกแถว (OQ-15)
**ไม่ประกาศ `total etag`** เพราะยังไม่มี draft (ZARI002 พิสูจน์แล้วว่าประกาศไม่ได้ถ้าไม่มี draft)

---

## Phase 3 — Projection + UI annotation

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 3.0 | เพิ่ม `StatusCriticality` (case → int1) ที่ `ZI_ZARE002_PYMT` — แก้ view ที่ activate ไปแล้ว | Claude → ผู้ใช้ | ✅ |
| 3.1 | `ZC_ZARE002` — projection view + path expression ดึง field header ครบ + `CustomerName` | Claude → ผู้ใช้ | ✅ |
| 3.2 | `ZC_ZARE002` — behavior projection (`use update`) | Claude → ผู้ใช้ | ✅ |
| 3.3 | `ZC_ZARE002` — metadata extension: `@UI.lineItem` เรียง header → item → reject_reason | Claude → ผู้ใช้ | ✅ |
| 3.4 | Status ใช้ `@UI.criticality` ให้ได้ icon 3 สีตาม mockup | Claude → ผู้ใช้ | ✅ |
| 3.5 | `@UI.selectionField` — filter bar (ดู `05_ui_spec.md` §6) | Claude → ผู้ใช้ | ✅ |
| 3.6 | `reject_reason` ใช้ `@UI.multiLineText` | Claude → ผู้ใช้ | ✅ |
| 3.7 | **ไม่ใส่ `@UI.facet`** — ยืนยันว่าไม่มี Object Page | Claude | ✅ |
| 3.8 | `ZUI_ZARE002` service definition + `ZUI_ZARE002_O4` service binding (V4 UI) → publish → preview | ผู้ใช้ | ✅ |

**Exit criteria**: preview ได้หน้าจอตรง mockup — คอลัมน์ครบ ลำดับถูก icon ขึ้น

---

## Phase 4 — 🔀 จุดตัดสิน: inline edit ได้ไหม

**ผลจริง: เดินสาย draft** — 4.3–4.7 ทำครบและ push แล้ว · เหลือยืนยันผลทดสอบ 4.8

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 4.1 | **ทดสอบใน preview — คลิกช่อง Reject Reason แล้วพิมพ์แก้ได้ไหม** | ผู้ใช้ | ⬜ |
| 4.2 | ถ้า **ได้** → ปิด OQ-06 · ข้าม 4.3–4.7 ไป Phase 5 เลย | Claude | ➖ ไม่ได้ใช้เส้นนี้ |
| 4.3 | ถ้า **ไม่ได้** → เพิ่ม `last_changed_at : abp_lastchange_tstmpl` ที่ `ZTAR_I002_ITEM` (repo `ZARI002`) | ผู้ใช้ | ✅ |
| 4.4 | ZARI002 activate + push table ที่แก้แล้ว | ผู้ใช้ | ✅ |
| 4.5 | สร้าง draft table `ZTAR_E002_ITEM_D` ใน package `ZARE002` | ผู้ใช้ | ✅ |
| 4.6 | เติม `with draft` + `draft table` + `total etag LastChangedAt` ใน BDEF | Claude → ผู้ใช้ | ✅ |
| 4.7 | เติม `use draft;` ใน behavior projection | Claude → ผู้ใช้ | ✅ |
| 4.8 | ทดสอบ 4.1 ซ้ำ | ผู้ใช้ | ⬜ |

**Exit criteria**: คลิกช่อง Reject Reason พิมพ์แก้แล้ว Save ค่าลง `ztar_i002_item` จริง

การเพิ่ม field ท้ายตารางที่มีข้อมูลอยู่เป็น `ALTER TABLE` ธรรมดา **ข้อมูลเดิมไม่หาย**
และ ZARI002 **ไม่ต้องแก้โค้ด** — managed runtime เติมค่าให้เองจาก annotation
(ZARI002 พิสูจน์ไว้แล้ว 2026-08-28)

---

## Phase 5 — Action Submit / Reject (ปุ่มเปล่า)

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 5.1 | ประกาศ `action submitItem;` `action rejectItem;` ใน BDEF | Claude → ผู้ใช้ | ✅ |
| 5.2 | `use action submitItem; use action rejectItem;` ใน behavior projection | Claude → ผู้ใช้ | ✅ |
| 5.3 | implement ใน `lhc_Item` — **ไม่ทำอะไร ไม่ raise error** + เติม `%action-*` ใน `get_global_authorizations` | Claude → ผู้ใช้ | ✅ |
| 5.4 | `@UI.lineItem: [{ type: #FOR_ACTION, invocationGrouping: #CHANGE_SET }]` ให้ปุ่มขึ้น toolbar + multi-select + keys มาถึง handler รอบเดียว | Claude → ผู้ใช้ | ✅ |

**Exit criteria**: ปุ่ม Submit / Reject ขึ้นบน toolbar · ติ๊กหลายแถวแล้วกดได้โดยไม่ error

---

## Phase 6 — Fiori app · IAM · Launchpad — **ผู้ใช้ทำเองทั้งหมด** (ตกลง 2026-09-15)

งานของ Claude ใน RICEFW นี้จบที่ service definition / binding · เฟสนี้ผู้ใช้ทำเอง แล้ว push
ให้ Claude **รีวิว object ใน git** ย้อนหลัง · การแก้คอลัมน์ Reject Reason เป็นงาน**ทีม Fiori** (OQ-17)

**ก่อนส่ง service ให้ทีม Fiori ต้องปิด OQ-18 ก่อน** — BDEF ต้องกลับเป็น managed ธรรมดา
ไม่งั้น update ที่ทีม Fiori ยิงมาไม่ลง table

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 6.1 | ~~service definition / binding~~ — **สร้างไปแล้วที่ Phase 3.8** ตัวเดียวกัน ไม่ใช่ของชั่วคราว | — | ✅ ยุบเข้า 3.8 |
| 6.3 | IAM App `ZIAM_ZARE002_EXT` (type EXT · ผูก `ZUI_ZARE002_O4` + UI5 app) | ผู้ใช้ | ✅ |
| 6.4 | Business Catalog `ZBC_ZARE002` + assignment `ZBC_ZARE002_0001` · Launchpad App Descriptor Item `ZARE002_UI5R` · Fiori app deploy จาก BAS | ผู้ใช้ | ✅ |
| 6.5 | Business Role + assign ให้ user ทดสอบ (Fiori — ไม่ขึ้น git) | ผู้ใช้ | ✅ |
| 6.6 | เปิดจาก Fiori Launchpad ได้จริง — 17 แถวจากข้อมูลจริงของ ZARI002 (2026-09-16) | ผู้ใช้ | ✅ |
| 6.7 | ยืนยัน Customer Name ยังขึ้นตอนเปิดด้วย business user จริง — ขึ้นครบ รวมชื่อไทยหลายท่อนที่ต่อด้วยช่องว่าง | ผู้ใช้ | ✅ |

**Exit criteria**: เปิด app จาก launchpad ด้วย business user ปกติได้ · Customer Name ไม่ว่าง

> object type ของ IAM App / Business Catalog ต้องยืนยันใน ADT ตอนทำจริง (OQ-11)
> ⚠️ ถ้า OQ-15 กลายเป็น "ต้องแยกตาม company code" ต้องกลับไปรื้อ BDEF ที่ Phase 2 ก่อน

---

## Phase 7 — Reject logic · sort (เปิด 2026-09-16)

ขอบเขตหลังตกลง: OQ-13 / 19 / 20 / 21 / 22 / 23 / 24 · **company code (OQ-15) hold** ·
`submitItem` ยังว่าง · `authorization master ( global )` และ `#NOT_REQUIRED` คงเดิม

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 7.5 | metadata ext — เติม `visualizations: [ { type: #AS_LINEITEM } ]` ให้ sort ทำงาน (OQ-20) — เห็นบน launchpad แล้ว 16.09 → 15.09 → 14.09 | Claude → ผู้ใช้ | ✅ |
| 7.1 | Message class `ZARE002` — `001` reason missing (per item) · `002` already rejected · `003` success | Claude → ผู้ใช้ | ✅ |
| 7.2 | `ZCL_ZARE002_STATUS_BUFFER` — static buffer `payment_uuid → status` ระหว่าง action กับ saver · 3 unit test เขียว | Claude → ผู้ใช้ | ✅ |
| 7.3 | BDEF — `with additional save` · `action ( features : instance )` ทั้งสองปุ่ม · `rejectItem result [1] $self` · `field ( features : instance ) RejectReason` | Claude → ผู้ใช้ | ✅ |
| 7.4 | `ZBP_R_ZARE002` — `get_instance_features` · `rejectItem` logic (distinct payment → validate reason ทุก item → buffer → บังคับ save ด้วย update ค่าเดิม) · `lsc_Item` `save_modified` → `UPDATE ztar_i002_pymt SET status = 'R'` | Claude → ผู้ใช้ | ✅ |
| 7.6 | ABAP Unit ของ validation ใน `ZBP_R_ZARE002` | Claude → ผู้ใช้ | ⬜ |
| 7.6a | ~~ทดสอบ backend ผ่าน EML~~ — ไม่ต้องแล้ว 7.7 ข้อ 4 ยืนยัน OQ-24 ผ่าน UI จริง | — | ✅ ยุบเข้า 7.7 |
| 7.6b | inline edit ทำงานบน launchpad — manifest `inlineEdit` + ตัด `@UI.multiLineText` (OQ-25) | ผู้ใช้ + Claude | ✅ |
| 7.7 | ทดสอบบน launchpad — **ผ่าน 4/5** (2026-09-16): validate per item ✅ · reject ทั้ง payment ✅ · readonly + ปุ่ม dim ✅ · `status = R` ใน DB ✅ · ข้อ 5 (2 ใบพร้อมกัน) = all-or-nothing ตาม `#CHANGE_SET` → OQ-26 รอ confirm ว่าต้องการแบบนี้ไหม | ผู้ใช้ | 🟨 |
| 7.8 | ทดสอบ 2 user แก้คนละ item ในใบเดียวกันพร้อมกัน · draft ค้างแล้วกลับมา | ผู้ใช้ | ⬜ |
| 7.9 | รีวิว OQ ทั้งตาราง + object list ตรงกับ tenant | Claude | ⬜ |

**Exit criteria**: Reject ใบที่มีหลาย item แล้ว `ztar_i002_pymt.status = 'R'` จริง · item ที่ไม่มีเหตุผลถูกกันด้วย message · แถวเรียงตาม posting date ล่าสุดก่อน

## Phase 8 — Submit / Reject → post FI document (เปิด 2026-09-17 · รอ spec)

ผู้ใช้แจ้ง 2026-09-16 ตอนปิดวัน: **ทั้ง Submit และ Reject ต้องเอา payment ที่เลือกไป post FI document**
รายละเอียดจะส่งมาให้ · ยังไม่มี object list ยังไม่มี code — เริ่มจากรีวิว spec ก่อนตามกติกา

สิ่งที่ต้องถามทันทีที่ได้ spec:
- Reject post FI document **แบบไหน** (reversal? ใบ reject แยก? หรือแค่ Submit ที่ post) — ประโยคที่แจ้งมาบอกว่า "สองปุ่ม" ต้อง confirm
- released API สำหรับ post: `I_JournalEntryTP` (RAP BO) หรือ `I_OperationalAcctgDocItemCube`… ต้องเช็ค Released Objects บน tenant
- หลัง post สำเร็จ stamp `status` = `S`/`W`/`E` + `salesforce_status` / `salesforce_message` (OQ-21 กลับมามีความหมาย)
- ทำใน action handler ไม่ได้ (ห้ามเขียน DB ใน interaction phase) → post ผ่าน EML ของ `I_JournalEntryTP` ใน handler ได้ (เป็น RAP BO) แต่ commit เกิดพร้อม LUW ของเรา · หรือ post ใน saver `lsc_Item` — ต้องตัดสิน
- OQ-26 (all-or-nothing) ต้องตอบก่อน เพราะ post FI หลายใบใน change set เดียว = ถ้าใบหนึ่ง post ไม่ผ่านทุกใบ rollback

ค้างจาก Phase 7 ที่ยังต้องทำ: 7.6 ABAP Unit · 7.8 concurrency / draft ค้าง · ลบ `ZCL_ZARE002_SPIKE`

---

## นอก scope เฟสนี้ — บันทึกไว้กันลืม

- **สิทธิ์ตาม company code** — hold (OQ-15) · เมื่อทำ: auth object + DCL + `#CHECK` + IAM restriction + role
- **Object Page** — ถ้าวันหน้าต้องดูรายละเอียดรายใบ
- **การแจ้งผลกลับ Salesforce** — เป็นงานของ ZARI003
