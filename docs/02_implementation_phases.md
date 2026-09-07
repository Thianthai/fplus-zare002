# ZARE002 — Implementation Phases

ทำทีละ phase — จบ phase แล้ว push → ฝั่ง SAP pull + activate → verify → ค่อยขึ้น phase ถัดไป

สัญลักษณ์: `⬜` ยังไม่ทำ · `🟨` กำลังทำ / ส่ง code ให้แล้วรอ activate · `✅` เสร็จ

> **ลำดับนี้ถูกจัดใหม่เมื่อ 2026-09-07** — เดิมเอา DDIC (draft table + แก้ table ของ ZARI002)
> ไว้ก่อน CDS เพราะคิดว่า draft เป็นของบังคับ · ตอนนี้เดินแบบ **non-draft ก่อนแล้ววัดผลจริง**
> DDIC จึงถูกเลื่อนไปเป็น Phase 4 และเป็น **phase ที่อาจไม่ต้องทำเลย**

---

## Phase 0 — Repository & package setup

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 0.1 | สร้าง local repo + `docs/` + `README.md` + `CLAUDE.md` | Claude | ✅ |
| 0.2 | Push commit แรก (เอกสารล้วน) ขึ้น GitHub | ผู้ใช้ | ⬜ |
| 0.3 | สร้าง package `ZARE002` บน tenant | ผู้ใช้ | ⬜ |
| 0.4 | ผูก abapGit repo กับ package `ZARE002` | ผู้ใช้ | ⬜ |
| 0.5 | abapGit push ให้ SAP serialize `.abapgit.xml` + `package.devc.xml` ขึ้นมาเป็น baseline | ผู้ใช้ | ⬜ |
| 0.6 | Claude ตรวจ baseline แล้วอัปเดต path ในเอกสารให้ตรง | Claude | ⬜ |

**Exit criteria**: pull/push ระหว่าง GitHub ↔ tenant ผ่านทั้ง 2 ทาง

> ⚠️ **ห้ามเขียน `.abapgit.xml` / `package.devc.xml` เองล่วงหน้า** — ZARI002 เจอมาแล้วว่า
> folder logic ที่เขียนมือไม่ตรงกับที่ ADT wizard ตั้ง ทำให้ link ไม่ผ่าน (HTTP 500)

---

## Phase 1 — CDS read layer

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 1.1 | `ZI_ZARE002_PYMT` — interface view บน `ztar_i002_pymt` (1:1) | Claude → ผู้ใช้ | ⬜ |
| 1.2 | `ZI_ZARE002_BP` — interface view บน `I_BusinessPartner` ต่อ `OrganizationBPName1..4` เป็น `CustomerName` | Claude → ผู้ใช้ | ⬜ |
| 1.3 | `ZI_ZARE002_ITEM` — interface view บน `ztar_i002_item` (1:1) + association `_Payment` `_BusinessPartner` | Claude → ผู้ใช้ | ⬜ |
| 1.4 | ใส่ `@Semantics.amount.currencyCode` ให้ field จำนวนเงินทุกตัว | Claude → ผู้ใช้ | ⬜ |
| 1.5 | Data Preview `ZI_ZARE002_BP` — ยืนยันว่าชื่อที่ต่อออกมาตรงกับที่ต้องการ ไม่มีช่องว่างซ้อน | ผู้ใช้ | ⬜ |
| 1.6 | Data Preview `ZI_ZARE002_ITEM` — เห็นข้อมูลจริงที่ ZARI002 ยิงเข้ามาครบทุกคอลัมน์ **รวม Customer Name** | ผู้ใช้ | ⬜ |

**Exit criteria**: Data Preview แสดงครบทั้ง 12 คอลัมน์ตาม `04_field_mapping.md`

> phase นี้ **ไม่ขึ้นกับข้อสงสัยที่ค้างอยู่เลยสักข้อ** เริ่มได้ทันที

---

## Phase 2 — RAP Business Object (non-draft)

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 2.1 | `ZR_ZARE002` — root view entity (projection บน `ZI_ZARE002_ITEM`) | Claude → ผู้ใช้ | ⬜ |
| 2.2 | `ZR_ZARE002` — behavior definition **managed ไม่มี draft · update อย่างเดียว** | Claude → ผู้ใช้ | ⬜ |
| 2.3 | `field ( readonly )` ทุก field ยกเว้น `RejectReason` | Claude → ผู้ใช้ | ⬜ |
| 2.4 | `ZBP_R_ZARE002` — behavior pool + `lhc_Item` (ยังว่าง) | Claude → ผู้ใช้ | ⬜ |
| 2.5 | activate BDEF ผ่าน — ยืนยันว่าไม่มี mapping error | ผู้ใช้ | ⬜ |
| 2.6 | ทดสอบ EML update `reject_reason` ได้จริง | ผู้ใช้ | ⬜ |

**Exit criteria**: EML update `reject_reason` แล้วค่าลง `ztar_i002_item` จริง

`authorization master ( global )` — ทุกคนที่เข้า app ได้เห็นทุกแถว (OQ-15)
**ไม่ประกาศ `total etag`** เพราะยังไม่มี draft (ZARI002 พิสูจน์แล้วว่าประกาศไม่ได้ถ้าไม่มี draft)

---

## Phase 3 — Projection + UI annotation

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 3.1 | `ZC_ZARE002` — projection view + path expression ดึง field header + `CustomerName` | Claude → ผู้ใช้ | ⬜ |
| 3.2 | `ZC_ZARE002` — behavior projection (`use update`) | Claude → ผู้ใช้ | ⬜ |
| 3.3 | `ZC_ZARE002` — metadata extension: `@UI.lineItem` เรียง header → item → reject_reason | Claude → ผู้ใช้ | ⬜ |
| 3.4 | Status ใช้ `@UI.criticality` ให้ได้ icon 3 สีตาม mockup | Claude → ผู้ใช้ | ⬜ |
| 3.5 | `@UI.selectionField` — filter bar (ดู `05_ui_spec.md` §6) | Claude → ผู้ใช้ | ⬜ |
| 3.6 | `reject_reason` ใช้ `@UI.multiLineText` | Claude → ผู้ใช้ | ⬜ |
| 3.7 | **ไม่ใส่ `@UI.facet`** — ยืนยันว่าไม่มี Object Page | Claude | ⬜ |
| 3.8 | สร้าง service definition + binding ชั่วคราวเพื่อ preview | ผู้ใช้ | ⬜ |

**Exit criteria**: preview ได้หน้าจอตรง mockup — คอลัมน์ครบ ลำดับถูก icon ขึ้น

---

## Phase 4 — 🔀 จุดตัดสิน: inline edit ได้ไหม

**phase นี้อาจไม่ต้องทำเลย** ขึ้นกับผลทดสอบข้อ 4.1

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 4.1 | **ทดสอบใน preview — คลิกช่อง Reject Reason แล้วพิมพ์แก้ได้ไหม** | ผู้ใช้ | ⬜ |
| 4.2 | ถ้า **ได้** → ปิด OQ-06 · ข้าม 4.3–4.7 ไป Phase 5 เลย | Claude | ⬜ |
| 4.3 | ถ้า **ไม่ได้** → เพิ่ม `last_changed_at : abp_lastchange_tstmpl` ที่ `ZTAR_I002_ITEM` (repo `ZARI002`) | ผู้ใช้ | ⬜ |
| 4.4 | ZARI002 activate + push table ที่แก้แล้ว | ผู้ใช้ | ⬜ |
| 4.5 | สร้าง draft table `ZTAR_E002_ITEM_D` ใน package `ZARE002` | ผู้ใช้ | ⬜ |
| 4.6 | เติม `with draft` + `draft table` + `total etag LastChangedAt` ใน BDEF | Claude → ผู้ใช้ | ⬜ |
| 4.7 | เติม `use draft;` ใน behavior projection | Claude → ผู้ใช้ | ⬜ |
| 4.8 | ทดสอบ 4.1 ซ้ำ | ผู้ใช้ | ⬜ |

**Exit criteria**: คลิกช่อง Reject Reason พิมพ์แก้แล้ว Save ค่าลง `ztar_i002_item` จริง

การเพิ่ม field ท้ายตารางที่มีข้อมูลอยู่เป็น `ALTER TABLE` ธรรมดา **ข้อมูลเดิมไม่หาย**
และ ZARI002 **ไม่ต้องแก้โค้ด** — managed runtime เติมค่าให้เองจาก annotation
(ZARI002 พิสูจน์ไว้แล้ว 2026-08-28)

---

## Phase 5 — Action Submit / Reject (ปุ่มเปล่า)

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 5.1 | ประกาศ `action Submit;` `action Reject;` ใน BDEF | Claude → ผู้ใช้ | ⬜ |
| 5.2 | `use action Submit; use action Reject;` ใน behavior projection | Claude → ผู้ใช้ | ⬜ |
| 5.3 | implement ใน `lhc_Item` — **ไม่ทำอะไร ไม่ raise error** พร้อม comment ว่ารอ logic เฟสถัดไป | Claude → ผู้ใช้ | ⬜ |
| 5.4 | `@UI.lineItem: [{ type: #FOR_ACTION }]` ให้ปุ่มขึ้น toolbar + เปิด multi-select | Claude → ผู้ใช้ | ⬜ |

**Exit criteria**: ปุ่ม Submit / Reject ขึ้นบน toolbar · ติ๊กหลายแถวแล้วกดได้โดยไม่ error

---

## Phase 6 — Service + Fiori app

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 6.1 | `ZUI_ZARE002` — service definition ตัวจริง | Claude → ผู้ใช้ | ⬜ |
| 6.2 | `ZUI_ZARE002_O4` — service binding (OData V4 UI) + publish | ผู้ใช้ | ⬜ |
| 6.3 | IAM App | ผู้ใช้ | ⬜ |
| 6.4 | Business Catalog + app assignment | ผู้ใช้ | ⬜ |
| 6.5 | Business Role + assign ให้ user ทดสอบ (Fiori — ไม่ขึ้น git) | ผู้ใช้ | ⬜ |
| 6.6 | เปิดจาก Fiori Launchpad ได้จริง | ผู้ใช้ | ⬜ |
| 6.7 | ยืนยัน Customer Name ยังขึ้นตอนเปิดด้วย business user จริง (ไม่ใช่ ADT preview) | ผู้ใช้ | ⬜ |

**Exit criteria**: เปิด app จาก launchpad ด้วย business user ปกติได้ · Customer Name ไม่ว่าง

> object type ของ IAM App / Business Catalog ต้องยืนยันใน ADT ตอนทำจริง (OQ-11)
> ⚠️ ถ้า OQ-15 กลายเป็น "ต้องแยกตาม company code" ต้องกลับไปรื้อ BDEF ที่ Phase 2 ก่อน

---

## Phase 7 — Test & handover

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 7.1 | ABAP Unit ของ `ZBP_R_ZARE002` (`ROLLBACK ENTITIES` ใน `setup`) | Claude → ผู้ใช้ | ⬜ |
| 7.2 | ทดสอบกับข้อมูลจริงหลายใบ / หลาย item ต่อใบ | ผู้ใช้ | ⬜ |
| 7.3 | ทดสอบ 2 user แก้คนละ item ในใบเดียวกันพร้อมกัน | ผู้ใช้ | ⬜ |
| 7.4 | ถ้าจบแบบมี draft — ทดสอบ draft ค้าง เปิดแก้แล้วปิด browser แล้วกลับมา | ผู้ใช้ | ⬜ |
| 7.5 | ไล่รีวิว `06_open_questions.md` ทั้งตาราง | Claude | ⬜ |
| 7.6 | อัปเดต `03_object_list.md` ให้ตรงกับของจริงบน tenant | Claude | ⬜ |

**Exit criteria**: ทะเบียนข้อสงสัยไม่มี `⬜` ที่บล็อกการส่งมอบ

---

## นอก scope เฟสนี้ — บันทึกไว้กันลืม

- **logic ปุ่ม Submit** — post FI จริง แล้ว stamp `status` = `S`/`W`/`E` ที่ header
- **logic ปุ่ม Reject** — stamp `status` = `R` + เขียน `reject_reason`
  · ⚠️ ต้องตอบ **OQ-04** ก่อน (`status` อยู่ระดับ header แต่ผู้ใช้ติ๊กเป็นระดับ item)
- **Object Page** — ถ้าวันหน้าต้องดูรายละเอียดรายใบ
- **สิทธิ์ระดับ company code** — ถ้า OQ-15 เปลี่ยนคำตอบ
- **การแจ้งผลกลับ Salesforce** — เป็นงานของ ZARI003
