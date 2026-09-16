# ZARE002 — Automatic Incoming Payments (Report)

| Item | Value |
|------|-------|
| RICEFW ID | **ZARE002** |
| Description | Automatic Incoming Payments |
| Type | Report (RAP UI — List Report เดี่ยว) |
| Platform | SAP S/4HANA Cloud **Public Edition** |
| Development model | **ABAP Cloud** (Developer Extensibility) — RAP managed BO |
| Protocol | **OData V4** (UI service binding) |
| UI | SAP Fiori elements **List Report ล้วน ไม่มี Object Page** |
| Operation ที่เปิด | **update อย่างเดียว** (แก้ `reject_reason`) — ไม่มี create / delete |
| Draft | **เปิดใช้แล้ว** — draft table `ZTAR_E002_ITEM_D` · `total etag LastChangedAt` |
| Repo sync | abapGit (local ⇄ GitHub ⇄ S/4HANA Cloud) |
| Package | **`ZARE002`** — package เดียว ไม่มี sub-package |
| Data source | `ZTAR_I002_PYMT` / `ZTAR_I002_ITEM` (**เป็นของ package `ZARI002`**) |
| RICEFW ที่เกี่ยวข้อง | **ZARI002** (รับข้อมูลเข้า) · **ZARI003** (ส่งผลกลับ Salesforce) |

## Scope

หน้าจอเดียว แสดง **payment item ทุกบรรทัด** ที่ ZARI002 รับเข้ามา
ผู้ใช้กดแก้ `reject_reason` ได้ในตารางโดยตรง และมีปุ่ม **Submit** / **Reject** บน toolbar

> ⚠️ **เฟสนี้ปุ่ม Submit / Reject เปิดไว้เฉย ๆ ยังไม่มี logic** — ประกาศ action + ให้ปุ่มขึ้น
> และกดได้โดยไม่ error เท่านั้น · logic post FI จริงเป็นงานเฟสถัดไป

```
Salesforce ──▶ SBPA ──▶ ZARI002 ──▶ ZTAR_I002_PYMT  status = 'N'
                        (API)       ZTAR_I002_ITEM
                                          │  ▲
                                     read │  │ update reject_reason
                                          ▼  │
                                    ┌──────────────┐
                                    │   ZARE002    │  ◀── งานนี้
                                    │ List Report  │
                                    └──────────────┘
                                          │
                                     (เฟสถัดไป) post FI → stamp S / W / E
                                          │
                                          ▼
                                       ZARI003 ──▶ Salesforce
```

## Repository layout

```
fplus-zare002/
├── .gitignore
├── README.md
├── CLAUDE.md                     # กฎ/บริบทสำหรับ AI assistant ใน project นี้
├── docs/                         # เอกสาร design (ไม่ถูก sync เข้า SAP)
│   ├── 01_architecture.md        # สถาปัตยกรรม + design decision + เหตุผล
│   ├── 02_implementation_phases.md
│   ├── 03_object_list.md         # รายชื่อ repository object ทั้งหมด + status
│   ├── 04_field_mapping.md       # คอลัมน์บนหน้าจอ ↔ table field
│   ├── 05_ui_spec.md             # UI annotation + พฤติกรรมหน้าจอ
│   └── 06_open_questions.md      # ทะเบียนข้อสงสัย — รีวิวทุกครั้งที่จบ phase
├── .abapgit.xml                  # ← tenant serialize เอง ห้ามแก้มือ (ยังไม่มี)
└── src/                          # ← abapGit sync เฉพาะโฟลเดอร์นี้ (ยังไม่มี)
```

**commit แรกมีแค่เอกสาร** — `.abapgit.xml` และ `src/` ปล่อยให้ tenant serialize ขึ้นมาเอง
หลังผูก abapGit กับ package `ZARE002` แล้ว (บทเรียนจาก ZARI002 — ดู `CLAUDE.md`)

## Sync workflow

| สิ่งที่ทำ | ใคร |
|---|---|
| **ABAP object ทุกชนิด** (CDS, BDEF, behavior pool, DDIC, service def/binding) | **ผู้ใช้** สร้างใน ADT แล้ว push ผ่าน abapGit |
| **เอกสาร** (`docs/`, `README.md`, `CLAUDE.md`) | **Claude** เขียน + commit · ผู้ใช้ push |

Claude ส่ง ABAP code ให้เป็น **code block ใน chat** ไม่เขียนไฟล์ ABAP ลง repo

Remote: https://github.com/Thianthai/fplus-zare002.git

## สถานะปัจจุบัน

**พร้อมส่งต่อทีม Fiori** — BO managed + draft · update `RejectReason` ผ่าน OData ลง `ztar_i002_item` ด้วย managed runtime · ปุ่ม Submit / Reject ขึ้น toolbar (ยังว่าง) · commit `f1063da`
**Phase 6 object ขึ้นครบ** (`1ed936c`) — IAM App `ZIAM_ZARE002_EXT` · catalog `ZBC_ZARE002` · tile `ZARE002_UI5R` → UI5 app `com.fplus.fi.ar.zare002`
เหลือ business role + ทดสอบด้วย business user จริง (6.5–6.7)
