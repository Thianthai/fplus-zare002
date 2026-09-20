# ZARE002 — Object List

รายชื่อ repository object ทั้งหมด + ไฟล์ที่จะเกิดใน repo
(`⬜` = ยังไม่สร้าง · `🟨` = ส่ง code ให้ใน chat แล้ว รอผู้ใช้สร้างบน tenant ·
`🟦` = activate ผ่านบน tenant แล้ว **รอ abapGit push** · `✅` = อยู่ใน repo แล้ว)

> **ABAP object ทุกตัวในเอกสารนี้ผู้ใช้เป็นคนสร้างใน ADT และ push เอง** — Claude ส่ง code ให้ทาง chat
> ไม่เขียนไฟล์ ABAP ลง repo (ดู `CLAUDE.md` §Git) คอลัมน์ "ไฟล์" คือ path ที่ abapGit จะ serialize ไปลง

## Package

ทุก object ลง package **`ZARE002`** ตัวเดียว ไม่มี sub-package

| Package | Folder | Description | Status |
|---------|--------|-------------|--------|
| `ZARE002` | `src/` | Automatic Incoming Payments (Report) | ✅ |

baseline ที่ tenant serialize มาแล้ว (commit `7936197`) — object ทุกตัวลง `src/` ตรง ๆ
เหมือน ZARI002 · มี `src/6891044ca05f5bb3d7f71a02635465ht.sush.xml` ติดมาด้วย
เป็น service authorization ที่ระบบสร้างให้เองตอน publish service binding

## DDIC

| Object | Type | ไฟล์ | Phase | Status |
|--------|------|------|-------|--------|
| `ZTAR_E002_ITEM_D` | Draft table ของ `ZR_ZARE002` — สร้างด้วย quick-fix จาก BDEF · include `SYCH_BDL_DRAFT_ADMIN_INC` เป็น `%ADMIN` ครบ | `src/ztar_e002_item_d.tabl.xml` | 4 | ✅ |
| `ZARE002` | Message class — `001` reject reason missing (per item) · `002` already rejected · `003` rejected OK · `004` > 25 items · `005` SFDC success=false · `006` SFDC unreachable · `001–099` Reject · `100+` Submit | `src/zare002.msag.xml` | 7 / 8A | ✅ 001–006 |

**ไม่สร้าง data element / domain ใหม่** — reuse `ZE_REQUEST_STATUS` (package `ZARI002`)

| `ZCL_ZARE002_STATUS_BUFFER` | Class — static buffer `payment_uuid → status` ส่งจาก action ไป saver · `add` / `get_all` / `clear` · 3 unit test | `src/zcl_zare002_status_buffer.clas.abap` | 7 | ✅ |

| `ZCL_ZARE002_UTIL` | ⚠️ **ชั่วคราว** — `if_oo_adt_classrun` รวม 2 spike: `reset_payment` (ล้าง reject_reason · status R→N · ล้างผล SFDC · ทิ้ง draft ของใบที่ระบุ) · `describe_sfdc_object` (GET describe ผ่าน arrangement print field `BST_*`) · main ปิดทั้งคู่ไว้ เปิด comment ก่อน F9 · **ลบทิ้งก่อน handover** · แทน `ZCL_ZARE002_SPIKE` + `ZCL_ZARE002_SPIKE_SFDC` ที่ลบแล้ว (2026-09-20) | `src/zcl_zare002_util.clas.abap` | 7 / 8A | 🟨 temporary |

## Table ที่ใช้ — เป็นของ package `ZARI002` ไม่ใช่ของเรา

| Object | Owner | ZARE002 ทำอะไร | หมายเหตุ |
|---|---|---|---|
| `ZTAR_I002_PYMT` | ZARI002 | read | (เฟสถัดไป) update `status` |
| `ZTAR_I002_ITEM` | ZARI002 | read + **update `reject_reason`** | **เพิ่ม `last_changed_at` แล้ว** — push ขึ้น repo `fplus-zari002` แล้ว (commit `0762ada`) |
| ~~`ZTAR_E002_EDIT`~~ | — | **ยกเลิกแล้ว** | ใช้ `ZTAR_I002_ITEM.REJECT_REASON` แทน — เหตุผลใน `01_architecture.md` §2 |

## CDS

| Object | Type | ไฟล์ | Phase | Status |
|--------|------|------|-------|--------|
| `ZI_ZARE002_PYMT` | Interface view บน `ztar_i002_pymt` (1:1) · + `StatusCriticality` `StatusIcon` · **ไม่มี `SapPaymentMethod`** (2026-09-17) · ⚠️ `PaymentMethod` ขาด label — ใส่ `'Payment Method'` กลับรอบหน้า | `src/zi_zare002_pymt.ddls.asddls` | 1 | ✅ |
| `ZI_ZARE002_ITEM` | Interface view บน `ztar_i002_item` (1:1) + assoc `_Payment` `_BusinessPartner` | `src/zi_zare002_item.ddls.asddls` | 1 | ✅ |
| `ZI_ZARE002_BP` | Interface view บน `I_BusinessPartner` — ต่อ `OrganizationBPName1..4` เป็น `CustomerName` | `src/zi_zare002_bp.ddls.asddls` | 1 | ✅ |
| `ZR_ZARE002` | **Root view entity** — projection บน `ZI_ZARE002_ITEM` | `src/zr_zare002.ddls.asddls` | 2 | ✅ |
| `ZC_ZARE002` | Projection view — + path expression ดึง field header | `src/zc_zare002.ddls.asddls` | 3 | ✅ |
| `ZC_ZARE002` | Metadata extension — UI annotation ทั้งหมด · **ไม่มี `@UI.multiLineText`** (ตัดออก 7.6b) | `src/zc_zare002.ddlx.asddlxs` | 3 / 7 | ✅ |

## Behavior

| Object | Type | ไฟล์ | Phase | Status |
|--------|------|------|-------|--------|
| `ZR_ZARE002` | Behavior definition — managed · with draft · with additional save · update only · features : instance บน RejectReason + 2 action | `src/zr_zare002.bdef.asbdef` | 2 / 7 | ✅ |
| `ZBP_R_ZARE002` | Behavior pool — `lhc_Item` (global auth · instance features · rejectItem: validate → composite SFDC → buffer) + `lsc_Item` (save_modified → `UPDATE ztar_i002_pymt` status R + salesforce_status S · cleanup_finalize) | `src/zbp_r_zare002.clas.abap` | 2 / 7 / 8A | ✅ |
| `ZC_ZARE002` | Behavior projection (`use update` · `use action` · `use draft` ถ้าอัปเกรด) | `src/zc_zare002.bdef.asbdef` | 3 | ✅ |

`ZBP_C_ZARE002` (behavior pool ของ projection) **ยังไม่ต้องสร้าง** — สร้างเมื่อมี logic ที่ต้องอยู่ชั้น projection เท่านั้น

## Service

| Object | Type | ไฟล์ | Phase | Status |
|--------|------|------|-------|--------|
| `ZUI_ZARE002` | Service definition (UI) | `src/zui_zare002.srvd.srvdsrv` | 3 | ✅ |
| `ZUI_ZARE002_O4` | Service binding (UI, OData V4) | `src/zui_zare002_o4.srvb.xml` | 3 | ✅ |

`ZI_ZARE002_PYMT` ได้ element `StatusCriticality` เพิ่มที่ Phase 3.0 (`case` → `abap.int1`)

**ไม่ทำ Web API service** — RICEFW นี้เป็น UI ล้วน ไม่มี consumer ภายนอก

## Authorization / Fiori — ผู้ใช้สร้างเองทั้งหมด (Phase 6 · 2026-09-16)

object type จริงบน tenant นี้ (ปิด OQ-11) และชื่อที่ใช้จริง — **ไม่ตรงกับที่ Claude เสนอไว้ตอนแรก**
(`ZARE002` / `ZARE002_BC`) ยึดตามของจริง:

| Object | Type (abapGit) | ชื่อจริง | หมายเหตุ | Status |
|---|---|---|---|---|
| IAM App | `SIA6` | `ZIAM_ZARE002_EXT` | type **EXT** = External App — ใช้เมื่อ UI เป็น UI5 app ที่ deploy จาก BAS (`UI_APP_ID = ZARE002_UI5R`) · ผูก `ZUI_ZARE002_O4` (`G4BA`) · published | ✅ |
| Business Catalog | `SIA1` | `ZBC_ZARE002` | หน่วยที่ business role เอาไปผูก · published · `IS_RESTRICTABLE_EDITABLE = X` (รองรับ restriction ถ้า OQ-15 เปลี่ยน) | ✅ |
| Business Catalog App Assignment | `SIA7` | `ZBC_ZARE002_0001` | ระบบสร้างตอนผูก IAM App เข้า catalog | ✅ |
| Launchpad App Descriptor Item | `UIAD` | `ZARE002_UI5R` | UI5 app id `com.fplus.fi.ar.zare002` · semantic object `ZARE002` action `manage` · static tile "Automatic Incoming Payments" · ไฟล์เป็น `.uiad.json` | ✅ |
| Fiori app (UI5) | — | สร้าง + deploy จาก BAS โดยผู้ใช้ | inline edit ของ Reject Reason อยู่ใน manifest ของ app นี้ · abapGit อาจไม่ serialize ตัว app | — |
| Business Role + assign user | — (config) | ตั้งใน Maintain Business Roles | ไม่ขึ้น git | ⬜ |

## Connectivity — outbound ไป Salesforce (Phase 8A)

| Object | Type | ไฟล์ | Phase | Status |
|--------|------|------|-------|--------|
| `ZARE002_REJECT_RESULT_REST` | Outbound Service (SCO3) — HTTP | `src/zare002_reject_result_rest.sco3.xml` | 8A | ✅ |
| `ZCS_REJECT_RESULT` | Communication Scenario outbound (SCO1) — OAuth 2.0 client credentials · one instance per client · แยกจาก `ZCS_PAYMENT_RESULT` ของ ZARI002 โดยตั้งใจ | `src/zcs_reject_result.sco1.xml` | 8A | ✅ |
| Communication Arrangement `ZCA_REJECT_RESULT` | Fiori config — `ZCS_REJECT_RESULT` × Communication System `SFDC_DEV` (ของ ZARI002 · client id เดียวกัน · secret อยู่ใน Fiori) · Check Connection ✓ | — ไม่ขึ้น git | 8A | ✅ |
| `ZCL_ZARE002_SFDC_RESULT` | Class — Composite API (25 subrequest/call) PATCH ผล payment ไป SFDC · `build_payload` / `parse_response` / `build_response_date` pure · `send` / `check_connection` | `src/zcl_zare002_sfdc_result.clas.abap` | 8A | ✅ ชื่อ field จริง (`43479c6`) · 9 test เขียว · ping 200 |

## Action ที่ประกาศ

| Action | ชนิด | Phase | Logic | Status |
|---|---|-------|-------|--------|
| `submitItem` | instance action · `#CHANGE_SET` · features : instance | 5 / 7 | **ว่าง** — รอเฟส post FI · dim เมื่อ `R` | ✅ |
| `rejectItem` | instance action · `#CHANGE_SET` · features : instance · `result [1] $self` | 5 / 7 | validate reason ทุก item → buffer → saver stamp `R` | ✅ |
| `Edit` `Activate` `Discard` `Resume` `Prepare` | draft action (standard) | 4 | framework · **ต้องไล่ประกาศทีละตัวใน projection เพราะมี `strict`** | ✅ |
