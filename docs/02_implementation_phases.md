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

## Phase 8A — Reject → แจ้ง Salesforce (เปิด 2026-09-17 · กำลังเคลียร์ spec)

spec จากผู้ใช้ 2026-09-17 (IN #3 Payment Result): หลัง Reject ต้อง PATCH สถานะ + reject reason
กลับ SFDC ที่ `cgcloud__Order_Payment__c` **ราย item** (record Id = `salesforce_item_id`)
· ตัวอย่าง JSON กับ auth ดู `docs/09_sfdc_api.md` (จะสร้างตอน confirm object)

**ตกลงแล้ว (2026-09-17)**
- ชื่อ field API ยึดตาม JSON example (มี `_` คั่น): `BST_Payment_Collection__c` `BST_SAP_Status__c`
  `BST_SAP_Reject_Reason__c` `BST_SAP_Batch_Id__c` `BST_SAP_Response_Date__c`
- Communication Scenario **สร้างเอง** `ZCS_REJECT_RESULT` · ใช้ Communication System `SFDC_DEV`
  ของ ZARI002 (client id เดียวกัน · secret ผู้ใช้ถือ ใส่ใน Fiori)
- `BST_SAP_Batch_Id__c` = `ztar_i002_pymt.request_id`
- ยิงแบบ **composite** (SFDC dev แนะนำ) — 1 คลิก = 1 call · `allOrNone`
- **ส่ง SFDC ไม่สำเร็จ → ห้าม stamp `R`** ผู้ใช้ต้องกด Reject ซ้ำได้ (re-send)
  → **ย้ายจุดยิงจาก `save_modified` ไป `rejectItem`** (interaction phase ยิง HTTP ได้ ห้ามแค่เขียน DB)
  ผล SFDC ผ่าน → buffer + save · พัง → `failed` + `reported` ไม่มีอะไรลง DB
- ผลข้างเคียง: `salesforce_status` มีแต่ `S` (กรณี `E` ไม่ถูก save) — ความล้มเหลวเห็นแค่บนจอ

**ตกลงเพิ่ม (2026-09-17 รอบ 2)**
- composite = **Composite API** `POST /services/data/v66.0/composite` · `compositeRequest[]` · `allOrNone: true` (SFDC dev ยืนยัน 2026-09-20 · sObject Collections ไม่ใช้)
- เกิน **25** item ต่อคลิก (limit ของ Composite API) → **ปฏิเสธ** ด้วย message `ZARE002 004`
- `BST_SAP_Response_Date__c` ต้องเป็น **`+0700`** ตาม spec — UTC + 7 ชม. แล้วต่อ `+0700` คงที่ (ไทยไม่มี DST)
- log ตอนส่งพลาด: **ยังไม่ทำ** แต่ API class คืนผลเป็น structure ไว้ให้ต่อ log table ทีหลังได้

- OQ-26 = **(ก) all-or-nothing** · Batch Id ~~ส่งเต็ม~~ **ตัด 15 ชั่วคราว** (2026-09-21) จนกว่า SFDC ขยาย field (OQ-28)

**Object (เสนอ 2026-09-17 · รอ confirm ชื่อ)**

| # | Object | Type | ชื่อ | Status |
|---|---|---|---|---|
| 8.1 | Outbound Service | SCO3 | `ZARE002_REJECT_RESULT_REST` | ✅ `b76c74c` |
| 8.2 | Communication Scenario outbound | SCO1 | `ZCS_REJECT_RESULT` — OAuth 2.0 client credentials · published | ✅ `b76c74c` |
| 8.3 | Communication Arrangement | Fiori | `ZCA_REJECT_RESULT` × `SFDC_DEV` · Check Connection ✓ (2026-09-20) | ✅ |
| 8.4 | API class | CLAS | `ZCL_ZARE002_SFDC_RESULT` — Composite API · `build_payload` / `parse_response` (sXML) / `build_response_date` (pure) · `send` / `check_connection` · ชื่อ field เป็น constant รอ OQ-30 · `check_connection` = 200 | ✅ `907155b` |
| 8.5 | Message class | MSAG | `ZARE002` — `001` แก้เป็นต่อ payment · `004` (>25) `005` (SFDC error) `006` (unreachable) | ✅ `9799508` |
| 8.6 | Behavior pool | CLAS | `lhc_Item->rejectItem` validate ทุกใบ (reason ≥ 1 item/ใบ) → composite → success เท่านั้นจึง buffer · `error_index` → แถวต้นเหตุ · `lsc_Item` เพิ่ม `salesforce_status = S` | ✅ `9799508` |
| 8.7 | Unit test | | 10 test เขียว: payload ×5 (รวม truncate batch id) · parse ×4 · date — ไม่ต่อ SFDC | ✅ |
| 8.8 | ทดสอบ | | (1) ใบ request_id ≤ 15 → Rejected ใน SFDC · (2) ใบ 20 ตัว → 005 STRING_TOO_LONG ยัง N · (3) A กรอก + B ไม่กรอก → ไม่ยิง SFDC · (4) DB status R + salesforce_status S · (5) filter บัง 2 item → reject ครบ 5 · (6) ไม่กรอกเลย → 001 — **ข้อ 1 ติด `INVALID_FIELD` (OQ-30) chain ถึง SFDC แล้ว status ไม่ stamp ตามกติกา** | 🟨 รอชื่อ field |

ลำดับ: 8.1 → 8.2 → 8.3 (ADT + Fiori ก่อน) → 8.5 → 8.4 + 8.7 → check_connection → 8.6 → 8.8

## Phase 8C — Token กลาง: เลิกพึ่ง cache ของ Communication Arrangement (เปิด 2026-09-21 · OQ-34)

Salesforce ไม่ส่ง `expires_in` → arrangement ถือ token ค้าง ไม่ refresh แม้เจอ 401 (SAP Community ยืนยัน)
→ class กลางขอ token ใหม่ทุกครั้งผ่าน scenario **Basic auth** ไป `/services/oauth2/token`
(secret อยู่ใน Communication System — class ไม่เห็น) แล้ว RICEFW ใส่ `Authorization: Bearer` เอง
· ตก (User Name < 85 / SFDC ไม่รับ Basic จาก SAP) → `ZTBC_PARAM` ตามที่ผู้ใช้ตัดสิน

| # | Object | ชื่อ (เสนอ · รอ confirm) | Status |
|---|---|---|---|
| 8C.0 | เช็ค Fiori: User Name รับ 85 ตัว · scenario มี auth None | — | ⬜ |
| 8C.1 | outbound user Basic ใน `SFDC_DEV` (user = client id · pw = secret) | Fiori | ⬜ |
| 8C.2 | Outbound Service SCO3 | `ZBC_SFDC_TOKEN_REST` | ⬜ |
| 8C.3 | Communication Scenario SCO1 · outbound · Basic | `ZCS_SFDC_TOKEN` | ⬜ |
| 8C.4 | Communication Arrangement | `ZCA_SFDC_TOKEN` × `SFDC_DEV` | ⬜ |
| 8C.5 | class กลาง **`ZCL_UTILITY`** (ผู้ใช้ตั้ง 2026-09-21 · ข้ามRICEFW ไม่มี prefix APP) · `get_sfdc_token( )` → access_token · ไม่ cache · `parse_sfdc_token_response( )` pure | `ZCL_UTILITY` · package **`ZBCUTILITY`** (ตกลง 2026-09-21 · 8C.2/8C.3 ลงที่เดียวกัน) | ⬜ |
| 8C.6 | unit test ของ 8C.5 | | ⬜ |
| 8C.7 | spike ใน `ZCL_ZARE002_UTIL`: Bearer เองผ่าน arrangement Basic → 200 หรือ 401 | ตัดสินว่าต้อง scenario no-auth แยกไหม | ⬜ |
| 8C.8 | `ZCL_ZARE002_SFDC_RESULT` ใช้ token กลาง + Bearer เอง · ping → `/limits` | | ⬜ |
| 8C.9 | scenario ขา data (เฉพาะถ้า 8C.7 = 401) | `ZARE002_SFDC_DATA_REST` · `ZCS_ZARE002_SFDC_DATA` (None) · `ZCA_ZARE002_SFDC_DATA` | ⬜ |
| 8C.10 | เลิกใช้ `ZCS_REJECT_RESULT` | | ⬜ |

ZARI002 ต้องทำแบบ 8C.8 ในรอบของตัวเอง — จดไว้ให้ฝั่งนั้น

## Phase 8B — Submit → post FI document (รอ spec)

ทั้ง Submit และ Reject ต้องเกี่ยวกับ FI document (ผู้ใช้แจ้ง 2026-09-16) — Reject ทำ SFDC ก่อน (8A)
ส่วน post FI ยังไม่มี spec · คำถามที่ต้องถามทันทีที่ได้ spec:
- Reject post FI document **แบบไหน** (reversal? ใบ reject แยก? หรือแค่ Submit ที่ post)
- **`sap_payment_method` ไม่มีแล้ว** (OQ-27) — แยกประเภทการจ่ายจาก `payment_method` (`Cheque` / `Cash` / `Transfer`)
- released API สำหรับ post: `I_JournalEntryTP` หรืออื่น — เช็ค Released Objects
- หลัง post สำเร็จ stamp `status` = `S`/`W`/`E` + แจ้ง SFDC `Completed` ด้วย class เดียวกับ 8A
- post ผ่าน EML ของ BO SAP ใน handler (commit พร้อม LUW เรา) หรือใน saver — ต้องตัดสิน
- OQ-26 (all-or-nothing) กระทบ post หลายใบใน change set เดียว

ค้างจาก Phase 7 ที่ยังต้องทำ: 7.6 ABAP Unit · 7.8 concurrency / draft ค้าง · ลบ `ZCL_ZARE002_SPIKE`

---

## นอก scope เฟสนี้ — บันทึกไว้กันลืม

- **สิทธิ์ตาม company code** — hold (OQ-15) · เมื่อทำ: auth object + DCL + `#CHECK` + IAM restriction + role
- **Object Page** — ถ้าวันหน้าต้องดูรายละเอียดรายใบ
- **การแจ้งผลกลับ Salesforce** — เป็นงานของ ZARI003
