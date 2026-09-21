# ZARE002 — ทะเบียนข้อสงสัย

รวมทุกอย่างที่ยัง**ไม่เคลียร์** ไว้ที่เดียว — **รีวิวทุกครั้งที่จบ phase**

> เจอจุดไหนไม่ชัดให้ **note ไว้ที่นี่แล้วเดินต่อ** อย่าหยุดรอ

สถานะ: `⬜` เปิดอยู่ · `🟨` มีคำตอบชั่วคราวแล้ว เดินต่อได้ · `⏸` hold โดยผู้ใช้ · `✅` ปิด

| # | เรื่อง | เจ้าของคำตอบ | ยกมาจาก | บล็อกอะไร | สถานะ |
|---|--------|-------------|---------|-----------|--------|
| OQ-15 | **สิทธิ์ระดับ company code** — **hold (2026-09-16)** หลังตกลงว่าจะแยกตาม CC คุมด้วย business role · **ข้อเท็จจริงที่ต้องจำ: ตอนนี้ยังไม่มีอะไรกรองแถวเลย** — role ให้แค่สิทธิ์เข้า app · `#NOT_REQUIRED` · `( global )` · ไม่มี auth object · ข้อมูลเป็น 2000 ล้วนจึงยังไม่เห็นปัญหา · วันที่ CC 1000 เข้ามา ทุกคนจะเห็นทั้งสองบริษัท · เมื่อกลับมาทำ: auth object `Z_ARE002` + DCL `ZC_ZARE002` + `#CHECK` + IAM App restriction + role · **ไม่ต้องมี `get_instance_authorizations`** เพราะ DCL กันการอ่านแล้ว modify ล้มเอง | ผู้ใช้ | Phase 0 | ไม่บล็อก Reject logic — แต่เป็นความเสี่ยงทันทีที่มีข้อมูล CC 1000 | ⏸ hold |
| OQ-28 | **`BST_SAP_Batch_Id__c` ฝั่ง SFDC ยาว 15 แต่ `request_id` จริงยาว 20** — spec SFDC ให้ตัวอย่าง `20260815_090039` (รูปแบบที่ SAP สร้างเองตอน SBPA ไม่ส่ง) แต่ตั้งแต่ 2026-09-16 SBPA ส่ง `RequestId` เองเป็น `20260915_105645_1056` (zari002 OQ-26 · field ขยายเป็น 25 แล้ว) → ส่งค่าจริงเข้า SFDC จะ `STRING_TOO_LONG` composite ล้มทั้ง call | ผู้ใช้ + SFDC dev | Phase 8A | **ตัดสินแล้ว 2026-09-17: ส่ง `request_id` เต็มไม่ตัด** · **เจอจริง 2026-09-21**: Reject ใบ `request_id` 20 ตัว → `STRING_TOO_LONG SAP Batch ID: data value too large: 20260918_16075…` · status ไม่ถูก stamp (ถูกต้อง) · = chain ผ่านถึง validation ของ SFDC แล้ว · **ผู้ใช้ตัดสิน 2026-09-21: ตัดเหลือ 15 ตัวชั่วคราว** (`gc_batch_id_max` ใน `build_payload` + test) จนกว่า SFDC ขยายเป็น 25 · เสีย suffix `_hhmm` ที่แยก request ในวินาทีเดียวกัน — **ต้องเอาการตัดออกทันทีที่ SFDC ขยาย** | 🟨 stopgap |
| OQ-35 | **test data มี `salesforce_item_id` ที่ไม่มีใน sandbox** — Reject จริง 2026-09-21 ได้ HTTP 200 แต่ subrequest `NOT_FOUND` · ต้องใช้ใบที่ SBPA ยิงเข้ามาจริง หรือขอ/query record Id จริงจาก sandbox มาใส่ใบทดสอบ | ผู้ใช้ | 8.8 | **บล็อก 8.8 ข้อ 1** — ไม่ใช่ปัญหา code | ⬜ |
| OQ-36 | **Reject Reason ลง DB ก่อน Reject สำเร็จ** — inline edit ของ FE ส่ง PATCH ทันทีที่ออกจากช่อง (LUW แยกจาก action) · action fail ย้อน rollback ไม่ได้ · เจอ 2026-09-21 ตอน Reject ได้ NOT_FOUND · รอบก่อนไม่ค้างเพราะพิมพ์แล้วกดปุ่มทันที (PATCH กับ action อยู่ change set เดียวกัน) · ทางแก้ถ้าจะแก้: reason เป็น parameter ของ action (`ZA_ZARE002_REJECT` popup) แต่จะได้ reason เดียวต่อ payment | ผู้ใช้ | 8.8 | **hold** ผู้ใช้สั่ง 2026-09-21 "ยังไม่ต้องแก้ ปล่อยไว้ก่อน" · reason ค้างที่ status N ไม่มีใครอ่าน ไม่กระทบ ZARI003/SFDC | ⏸️ |
| OQ-14 | ต้อง log ไหมว่าใครแก้ `reject_reason` เป็นอะไรเมื่อไหร่ — ตอนนี้มีแค่ `last_changed_by` ที่เก็บค่าล่าสุด ไม่มีประวัติ | ผู้ใช้ / audit | Phase 3 | ไม่บล็อก — ถ้าต้องการให้ทำเป็น append-only log table แยก **ไม่ใช่** ย้ายที่เก็บค่าปัจจุบัน (ดู `01_architecture.md` §2) | ⬜ |

## OQ ที่เคยอ้างอิงใน code — ถอดออกจาก comment ตอนส่งมอบ (2026-09-21) แต่ยังตามได้จากตารางนี้

| จุดใน code | เรื่อง | OQ |
|---|---|---|
| `lhc_Item->get_global_authorizations` — `authorization master ( global )` | สิทธิ์ตาม company code ยัง hold | **OQ-15 (hold)** |
| `lhc_Item->get_instance_features` | readonly + ปุ่ม dim เมื่อ `R` | OQ-13 · OQ-23 (ปิด) |
| `lhc_Item->rejectItem` ขั้น 1–3 อ่านทุก item จาก table | ติ๊กใด = ทั้ง payment | OQ-04 (ปิด) |
| `rejectItem` ขั้น 5 all-or-nothing | ใบใดตกทั้งชุดตก | OQ-26 (ปิด · ก) |
| `rejectItem` ขั้น 5.2 reason ≥ 1 item | | OQ-19 · OQ-22 · OQ-31 (ปิด) |
| `rejectItem` ขั้น 8 `MODIFY ENTITIES` ค่าเดิม | บังคับ save phase ให้ saver ถูกเรียก | OQ-24 (ปิด) |
| `lsc_Item->save_modified` `salesforce_status = 'S'` | | OQ-21 (ปิด) |
| `ZCL_ZARE002_SFDC_RESULT` `gc_batch_id_max = 15` | ตัด batch id ชั่วคราว | **OQ-28 (stopgap — ลบเมื่อ SFDC ขยาย)** |
| `ZCL_ZARE002_SFDC_RESULT` `gc_fld_*` | ชื่อ field จาก describe | OQ-30 (ปิด) |
| `ZCL_ZARE002_SFDC_RESULT` composite 25 | | OQ-29 (ปิด) |
| `ZCL_ZARE002_SFDC_RESULT` `send` → `ZCL_UTILITY=>create_sfdc_client` | token cache ค้าง | OQ-34 (ปิด) |
| `build_payload` ไม่ส่ง reason ว่าง | | OQ-32 (ปิด) |

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
| OQ-24 | **`save_modified` ถูกเรียกไหมถ้า action ไม่แก้ field ของ item** | **ถูกเรียก** — ทดสอบ 7.7 ข้อ 4 (2026-09-16) `ztar_i002_pymt.status = R` ลง DB จริง · ใช้ fallback (update RejectReason ค่าเดิมเพื่อบังคับ save phase) ตั้งแต่ต้น จึงยังไม่รู้ว่าถ้าไม่มี fallback จะถูกเรียกไหม — ไม่จำเป็นต้องรู้ | 2026-09-16 |
| OQ-27 | **ZARI002 ลบ `sap_payment_method` ออกจาก `ZTAR_I002_PYMT`** | **ฝั่ง ZARE002 เสร็จ 2026-09-17** (`c78b6a2`) — ถอดออกจาก `ZI_ZARE002_PYMT` + `ZC_ZARE002` ไม่เหลือการอ้างถึง · ZARI002 ลบ column ได้ · เก็บตก: label `'Payment Method (Text)'` ของ `payment_method` ถูกลบทั้งบรรทัดแทนที่จะเปลี่ยนเป็น `'Payment Method'` → ใส่กลับรอบหน้า (ไม่บล็อก) | 2026-09-17 |
| OQ-26 | **Reject หลายใบพร้อมกัน — ใบที่ตกลากใบที่ผ่านตกด้วยไหม** | **(ก) all-or-nothing** (confirm 2026-09-17) — ใบใดตก validation ทั้งชุดไม่ถูก reject · ไม่ยิง SFDC · เข้ากับ composite `allOrNone` | 2026-09-17 |
| OQ-29 | **endpoint composite ตัวไหน** | **Composite API** (SFDC dev ยืนยัน 2026-09-20) — `POST /services/data/v66.0/composite` · `compositeRequest[]` · `allOrNone: true` · **25 subrequest/call** → message `004` = 25 · parse `compositeResponse[].httpStatusCode` (204 = ผ่าน · ข้าม `PROCESSING_HALTED` หาตัวต้นเหตุ) · sObject Collections ไม่ใช้ | 2026-09-20 |
| OQ-31 | **กติกา Reject เปลี่ยน** | (1) ติ๊ก item ครบ — **ยกเลิก** คง OQ-04 (ติ๊กใด = ทั้ง payment จาก table) · (2) **reject reason อย่างน้อย 1 item ต่อ payment** — code ส่งแล้ว 2026-09-20 · message `001` เป็นต่อ payment ชี้ทุกแถวของใบ | 2026-09-20 |
| OQ-32 | **item ที่ไม่มี reject reason ส่งไป SFDC ยังไง** | **SFDC รับทุก item ได้** (ผู้ใช้ยืนยัน 2026-09-20) → ส่งเฉพาะที่กรอก item ว่างไม่ส่ง field — code ทำอยู่แล้ว | 2026-09-20 |
| OQ-22 | **scope ของ validation reject reason** | ~~ทุก item~~ → **อย่างน้อย 1 item ต่อ payment** (เปลี่ยน 2026-09-20 ดู OQ-31) | 2026-09-20 |
| OQ-30 | **API name ของ 5 field บน `cgcloud__Order_Payment__c` ตัวจริง** | **ปิด 2026-09-20 ด้วย describe จาก sandbox**: `BST_PaymentCollection__c` `BST_SAP_Status__c` `BST_SAP_RejectReason__c` `BST_SAP_BatchId__c` `BST_SAP_ResponseDate__c` — ตรง**ตาราง**ใน spec · JSON example ผิด 4 ตัว (มี `_` เกิน) · Reject จริงเคยได้ `INVALID_FIELD` ก่อนแก้ · แก้ constant 5 ตัว + test | 2026-09-20 |
| OQ-02 | **Payment Document No. ใน mockup เป็น link** | ทำเป็น text ธรรมดา — เห็นบน launchpad แล้วผู้ใช้ไม่ทักท้วง (default ยืน) | 2026-09-21 |
| OQ-03 | **สีปุ่ม Submit / Reject** | สีตาม theme — เห็นบน launchpad แล้วผู้ใช้ไม่ทักท้วง | 2026-09-21 |
| OQ-04 | **`status` header vs `reject_reason` item** | **ติ๊ก item ใด = reject ทุก item ของ payment จาก table** (ยืนยันซ้ำ 2026-09-20 ถึง filter จะบัง) — implement ใน `rejectItem` ขั้น 1–3 · `#CHANGE_SET` ให้ keys มาถึงรอบเดียว | 2026-09-21 |
| OQ-05 | **R / E สีเดียวกัน** | แดงทั้งคู่ — เห็นบน launchpad แล้วผู้ใช้ไม่ทักท้วง | 2026-09-21 |
| OQ-12 | **default filter** | ไม่มี — แสดงทุกสถานะ · ผู้ใช้ไม่ทักท้วง | 2026-09-21 |
| OQ-13 | **`reject_reason` แก้ได้ทุกสถานะ?** | หลัง `R` ห้ามแก้ — implement ใน `get_instance_features` (`%field-RejectReason` read_only) ทดสอบผ่าน 7.7 | 2026-09-21 |
| OQ-19 | **Reject ต้องมี reject reason** | อย่างน้อย 1 item ต่อ payment (OQ-31) — implement ใน `rejectItem` ขั้น 5.2 · message `001` | 2026-09-21 |
| OQ-21 | **Reject เขียน `salesforce_status` ไหม** | เขียน `S` เมื่อ SFDC รับ (saver) · `salesforce_message` ว่าง · ไม่มี `E` เพราะกรณีพังไม่ save | 2026-09-21 |
| OQ-23 | **ปิด Submit ด้วยเมื่อ `R`** | ปิดทั้งคู่ — implement ใน `get_instance_features` ทดสอบผ่าน 7.7 | 2026-09-21 |
| OQ-33 | **401 INVALID_SESSION_ID วันถัดมา** | รวมเข้า OQ-34 (สาเหตุ = token cache ค้าง) · `check_connection` ย้ายไป `/limits` แล้ว | 2026-09-21 |
| OQ-34 | **token cache ของ Communication Arrangement ค้าง (Salesforce ไม่ส่ง `expires_in`)** | **ปิด 2026-09-21** — `ZCL_UTILITY=>get_sfdc_token` ขอใหม่ทุก call ผ่าน `ZCA_SFDC_TOKEN` (Basic · secret ใน Communication System) + `ZCL_ZARE002_SFDC_RESULT` ใส่ Bearer เอง · Reject จริงหลังแก้: composite ถึง SFDC HTTP 200 ไม่มี 401 อีก (ตกที่ข้อมูล NOT_FOUND ซึ่งเป็นคนละเรื่อง) · 8C.10 ลบชุด OAuth เดิมแล้ว `651ec78` · **ZARI002 / ARI001 ต้องย้ายตาม** (ทะเบียนอยู่ที่ `fplus-zbcutility/docs/01_objects.md`) | 2026-09-21 |
| OQ-07 | **ชื่อลูกค้าดึงจาก view ไหน** — mockup มี Customer Name แต่ไม่มีใน table | **`I_BusinessPartner`** · `BusinessPartner = customer_code` เทียบตรง ๆ ได้เพราะ ZARI002 แปลง `ALPHA = IN` ก่อน insert อยู่แล้ว · ชื่อลูกค้า **ต่อเอง** จาก `OrganizationBPName1..4` คั่นด้วยช่องว่าง ผ่าน view `ZI_ZARE002_BP` ไม่ใช้ `BusinessPartnerFullName` | 2026-09-07 |

## วิธีใช้

- เจอข้อสงสัยใหม่ระหว่างทำ → **เพิ่มแถวที่นี่ทันที** อย่าเก็บไว้ในหัวหรือใน commit message
- ตอนจบ phase → ไล่ทั้งตาราง ถามเจ้าของคำตอบ แล้วอัปเดตสถานะ
