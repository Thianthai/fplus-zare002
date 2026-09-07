# ZARE002 — Implementation Phases

ทำทีละ phase — จบ phase แล้ว push → ฝั่ง SAP pull + activate → verify → ค่อยขึ้น phase ถัดไป

สัญลักษณ์: `⬜` ยังไม่ทำ · `🟨` กำลังทำ / ส่ง code ให้แล้วรอ activate · `✅` เสร็จ

---

## Phase 0 — Spike + repository setup

ต้องรู้คำตอบ 2 ข้อก่อนลงมือจริง เพราะมันเปลี่ยนทั้ง object list

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 0.1 | **Spike: inline edit ใน List Report ต้องใช้ draft จริงไหม** — ลองสร้าง BO ทิ้ง ๆ ทั้งสองแบบบน tenant แล้วดูว่าช่องแก้ได้ไหม | ผู้ใช้ + Claude | ⬜ |
| 0.2 | ~~เช็ค view ที่ให้ชื่อลูกค้า~~ — **ตอบแล้ว 2026-09-07**: ใช้ `I_BusinessPartner` · `BusinessPartner = customer_code` | ผู้ใช้ | ✅ |
| 0.3 | สร้าง local repo + `docs/` + `README.md` + `CLAUDE.md` | Claude | 🟨 |
| 0.4 | Push commit แรก (เอกสารล้วน) ขึ้น GitHub | ผู้ใช้ | ⬜ |
| 0.5 | สร้าง package `ZARE002` บน tenant | ผู้ใช้ | ⬜ |
| 0.6 | ผูก abapGit repo กับ package `ZARE002` | ผู้ใช้ | ⬜ |
| 0.7 | abapGit push ให้ SAP serialize `.abapgit.xml` + `package.devc.xml` ขึ้นมาเป็น baseline | ผู้ใช้ | ⬜ |
| 0.8 | Claude ตรวจ baseline แล้วอัปเดต path ในเอกสารให้ตรง | Claude | ⬜ |

**Exit criteria**: รู้คำตอบเรื่อง draft แล้ว · pull/push ระหว่าง GitHub ↔ tenant ผ่านทั้ง 2 ทาง

> ⚠️ **ห้ามเขียน `.abapgit.xml` / `package.devc.xml` เองล่วงหน้า** — ZARI002 เจอมาแล้วว่า
> folder logic ที่เขียนมือไม่ตรงกับที่ ADT wizard ตั้ง ทำให้ link ไม่ผ่าน (HTTP 500)

---

## Phase 1 — DDIC

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 1.1 | **ขอเพิ่ม `last_changed_at : abp_lastchange_tstmpl` ที่ `ZTAR_I002_ITEM`** — คุยกับฝั่ง ZARI002 (เป็นการเพิ่ม field ล้วน ไม่ต้องแก้โค้ด) | ผู้ใช้ | ⬜ |
| 1.2 | ZARI002 activate + push table ที่แก้แล้ว | ผู้ใช้ | ⬜ |
| 1.3 | สร้าง draft table `ZTAR_E002_ITEM_D` ใน package `ZARE002` | ผู้ใช้ | ⬜ |

**Exit criteria**: `ZTAR_I002_ITEM` มี `last_changed_at` แล้ว · draft table activate ผ่าน

> ถ้า Phase 0.1 สรุปว่าไม่ต้องใช้ draft → **ข้าม Phase 1 ทั้งก้อน**

---

## Phase 2 — CDS read layer

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 2.1 | `ZI_ZARE002_PYMT` — interface view บน `ztar_i002_pymt` (1:1) | Claude → ผู้ใช้ | ⬜ |
| 2.2 | `ZI_ZARE002_BP` — interface view บน `I_BusinessPartner` ต่อ `OrganizationBPName1..4` เป็น `CustomerName` | Claude → ผู้ใช้ | ⬜ |
| 2.3 | `ZI_ZARE002_ITEM` — interface view บน `ztar_i002_item` (1:1) + association `_Payment` `_BusinessPartner` | Claude → ผู้ใช้ | ⬜ |
| 2.4 | ใส่ `@Semantics.amount.currencyCode` ให้ field จำนวนเงินทุกตัว | Claude → ผู้ใช้ | ⬜ |
| 2.5 | Data Preview `ZI_ZARE002_BP` — ยืนยันว่าชื่อที่ต่อออกมาตรงกับที่ต้องการ และไม่มีช่องว่างซ้อน | ผู้ใช้ | ⬜ |
| 2.6 | ทดสอบ Data Preview — เห็นข้อมูลจริงที่ ZARI002 ยิงเข้ามา ครบทุกคอลัมน์ที่ต้องใช้ **รวม Customer Name** | ผู้ใช้ | ⬜ |

**Exit criteria**: Data Preview แสดงครบทั้ง 12 คอลัมน์ตาม `04_field_mapping.md`

---

## Phase 3 — RAP Business Object

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 3.1 | `ZR_ZARE002` — root view entity (projection บน `ZI_ZARE002_ITEM`) | Claude → ผู้ใช้ | ⬜ |
| 3.2 | `ZR_ZARE002` — behavior definition (managed, with draft, **update อย่างเดียว**) | Claude → ผู้ใช้ | ⬜ |
| 3.3 | `field ( readonly )` ทุก field ยกเว้น `RejectReason` | Claude → ผู้ใช้ | ⬜ |
| 3.4 | `ZBP_R_ZARE002` — behavior pool + `lhc_Item` (ยังว่าง) | Claude → ผู้ใช้ | ⬜ |
| 3.5 | activate BDEF ผ่าน — ยืนยันว่าไม่มี mapping error | ผู้ใช้ | ⬜ |

**Exit criteria**: BDEF activate ผ่าน · ทดสอบ EML update `reject_reason` ได้จริง

---

## Phase 4 — Projection + UI annotation

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 4.1 | `ZC_ZARE002` — projection view + path expression ดึง field header | Claude → ผู้ใช้ | ⬜ |
| 4.2 | `ZC_ZARE002` — behavior projection (`use update` · `use draft`) | Claude → ผู้ใช้ | ⬜ |
| 4.3 | `ZC_ZARE002` — metadata extension: `@UI.lineItem` เรียง header → item → reject_reason | Claude → ผู้ใช้ | ⬜ |
| 4.4 | Status ใช้ `@UI.criticality` ให้ได้ icon 3 สีตาม mockup | Claude → ผู้ใช้ | ⬜ |
| 4.5 | `@UI.selectionField` — filter bar | Claude → ผู้ใช้ | ⬜ |
| 4.6 | `reject_reason` ใช้ `@UI.multiLineText` | Claude → ผู้ใช้ | ⬜ |
| 4.7 | **ไม่ใส่ `@UI.facet`** — ยืนยันว่าไม่มี Object Page | Claude | ⬜ |

**Exit criteria**: preview จาก service binding ได้หน้าจอตรง mockup · แก้ `reject_reason` แล้ว save ลง table จริง

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
| 6.1 | `ZUI_ZARE002` — service definition | Claude → ผู้ใช้ | ⬜ |
| 6.2 | `ZUI_ZARE002_O4` — service binding (OData V4 UI) + publish | ผู้ใช้ | ⬜ |
| 6.3 | IAM App | ผู้ใช้ | ⬜ |
| 6.4 | Business Catalog + app assignment | ผู้ใช้ | ⬜ |
| 6.5 | Business Role + assign ให้ user ทดสอบ (Fiori — ไม่ขึ้น git) | ผู้ใช้ | ⬜ |
| 6.6 | เปิดจาก Fiori Launchpad ได้จริง | ผู้ใช้ | ⬜ |

**Exit criteria**: เปิด app จาก launchpad ด้วย business user ปกติ (ไม่ใช่ ADT preview) ได้

> object type ของ IAM App / Business Catalog ต้องยืนยันใน ADT ตอนทำจริง — ยังไม่เคยทำใน RICEFW นี้

---

## Phase 7 — Test & handover

| # | งาน | ฝั่ง | Status |
|---|-----|------|--------|
| 7.1 | ABAP Unit ของ `ZBP_R_ZARE002` (`ROLLBACK ENTITIES` ใน `setup`) | Claude → ผู้ใช้ | ⬜ |
| 7.2 | ทดสอบกับข้อมูลจริงหลายใบ / หลาย item ต่อใบ | ผู้ใช้ | ⬜ |
| 7.3 | ทดสอบ 2 user แก้คนละ item ในใบเดียวกันพร้อมกัน | ผู้ใช้ | ⬜ |
| 7.4 | ทดสอบ draft ค้าง — เปิดแก้แล้วปิด browser แล้วกลับมา | ผู้ใช้ | ⬜ |
| 7.5 | ไล่รีวิว `06_open_questions.md` ทั้งตาราง | Claude | ⬜ |
| 7.6 | อัปเดต `03_object_list.md` ให้ตรงกับของจริงบน tenant | Claude | ⬜ |

**Exit criteria**: ทะเบียนข้อสงสัยไม่มี `⬜` ที่บล็อกการส่งมอบ

---

## นอก scope เฟสนี้ — บันทึกไว้กันลืม

- **logic ปุ่ม Submit** — post FI จริง แล้ว stamp `status` = `S`/`W`/`E` ที่ header
- **logic ปุ่ม Reject** — stamp `status` = `R` + เขียน `reject_reason`
- **Object Page** — ถ้าวันหน้าต้องดูรายละเอียดรายใบ
- **การแจ้งผลกลับ Salesforce** — เป็นงานของ ZARI003
