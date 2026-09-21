# ZARE002 — Automatic Incoming Payments (Report)

## Project constraints (ยึดถือตลอด project)

1. **Platform**: SAP S/4HANA Cloud **Public Edition** — Developer Extensibility (tier 3-cloud-only)
2. **ABAP Language Version**: **ABAP for Cloud Development** เท่านั้น ไม่มี fallback เป็น Standard ABAP
3. ใช้ได้เฉพาะ object ที่อยู่ใน **Released APIs (C1 contract)** เท่านั้น — ตรวจสอบทุกครั้งก่อนใช้
   ผ่าน ADT "Released Objects" หรือ view `I_APIStateForCLOUDDevelopment`
4. **ห้าม** ใช้ classic ABAP: `CALL FUNCTION` BAPI แบบตรง, `SELECT` จาก table SAP โดยตรง,
   `WRITE`, dynpro, SAPGUI report — ใช้ released CDS view + released ABAP API + EML แทน
5. Sync ผ่าน **abapGit** เท่านั้น
6. ทุก object ลง package **`ZARE002`** ตัวเดียว (ไม่มี sub-package)
7. **UI เป็น Fiori elements List Report ล้วน ไม่มี Object Page** — ห้ามเผลอใส่ `@UI.facet`

## Naming convention

ใช้กฎกลางใน `~/.claude/CLAUDE.md` ทุกข้อ **แต่เปลี่ยน prefix จาก `Y*` เป็น `Z*` ทั้งหมด**
โดย `<APP>` ของ project นี้ = **`ZARE002`** (RICEFW ID เต็ม รวมตัว `Z` นำหน้า)
— รูปแบบเดียวกับ ZARI002 ทุกประการ

| ชนิด | Pattern | ชื่อจริงใน project |
|------|---------|--------------------|
| Package | `Z<APP>` | `ZARE002` |
| Interface view | `ZI_<APP>_<ENT>` | `ZI_ZARE002_PYMT` · `ZI_ZARE002_ITEM` |
| Root view entity | `ZR_<APP>` | `ZR_ZARE002` |
| Projection view | `ZC_<APP>` | `ZC_ZARE002` |
| Behavior definition (root) | = ชื่อ root view | `ZR_ZARE002` |
| Behavior projection | = ชื่อ projection view | `ZC_ZARE002` |
| Metadata extension | = ชื่อ projection view | `ZC_ZARE002` |
| Behavior pool (root) | `ZBP_R_<APP>` | `ZBP_R_ZARE002` |
| Behavior pool (projection) | `ZBP_C_<APP>` | `ZBP_C_ZARE002` (ถ้าต้องใช้) |
| Local handler class | `lhc_<Entity>` | `lhc_Item` |
| Service definition (UI) | `ZUI_<APP>` | `ZUI_ZARE002` |
| Service binding (UI, V4) | `ZUI_<APP>_O4` | `ZUI_ZARE002_O4` |
| Draft table | — | `ZTAR_E002_ITEM_D` |
| Message class | `Z<APP>` | `ZARE002` |
| IAM App | `ZIAM_<APP>` (+ `_EXT` ระบบต่อให้) | `ZIAM_ZARE002_EXT` |
| Business Catalog | `ZBC_<APP>` | `ZBC_ZARE002` |
| Launchpad App Descriptor Item | `<APP>_UI5R` | `ZARE002_UI5R` |

### ข้อยกเว้นที่ตกลงไว้ (2026-09-07)

- **Draft table ใช้ชื่อ `ZTAR_E002_ITEM_D` ไม่ใช่ `ZTAR_I002_ITEM_D`** — ถึงกฎกลางจะบอกว่า
  draft table = `<table>_D` แต่ active table ตัวจริงเป็นของ package `ZARI002`
  draft table เป็นของ **ZARE002** จึงใช้ namespace ของตัวเองให้ชัด (BDEF ระบุชื่อได้อิสระอยู่แล้ว)
- **ไม่สร้าง data element / domain ใหม่** — reuse `ZE_REQUEST_STATUS` ของ ZARI002
- **class กลางข้าม RICEFW ชื่อ `ZCL_UTILITY`** (ผู้ใช้ตั้ง 2026-09-21) — ไม่มี prefix `<APP>` โดยตั้งใจ
  · method ตั้งชื่อบอกระบบปลายทาง (`get_sfdc_token` ไม่ใช่ `get_token`) · คนละบทบาทกับ
  `ZCL_ZARE002_UTIL` (ชั่วคราว ลบก่อน handover)

### Variable / parameter prefix

ตามกฎกลางเดิมทุกข้อ — `gv_/lv_/gs_/ls_/gt_/lt_/go_/lo_/<fs_>/<lfs_>` และ
`iv_/is_/it_/io_`, `ev_/es_/et_/eo_`, `cv_/cs_/ct_`, `rv_/rs_/rt_/ro_`

### ชื่อภายใน BDEF / CDS

- CDS element alias = **CamelCase** · field ใน DDIC table = snake_case — ห้ามปน
- Determination: `set*` / `calculate*` · Validation: `validate*` · Association: `_<Entity>`
- Draft action (`Prepare` `Edit` `Activate` `Discard` `Resume`) ใช้ชื่อ standard ห้ามเปลี่ยน

## Coding rules

- **`use draft;` + `strict` → ต้องไล่ประกาศ draft action ทีละตัวใน projection**
  (เจอจริง 2026-09-07: `If "use draft" is used with "strict", the draft action "Edit"
  must be included explicitly in the projection.`)
  → `use action Prepare; use action Edit; use action Activate; use action Discard; use action Resume;`
  `use draft;` ครอบให้อัตโนมัติเฉพาะตอน**ไม่มี** `strict` เท่านั้น
- **⚠️ view entity ไม่ใช่ DDIC-based view — อย่าหยิบ annotation ของอีกแบบมาใช้**
  พลาดมาแล้ว 2 ครั้งใน project นี้ (2026-09-07) ทั้งคู่เป็นเรื่องเดียวกัน:
  ของที่ DDIC-based view เขียนเป็น **annotation** ใน view entity หลายตัวเป็น **DDL clause**
  หรือหายไปเลยเพราะอนุมานจาก type ได้เอง · **เจอ syntax ที่ไม่แน่ใจให้ดู template ของ
  view entity โดยตรง อย่าเทียบจากตัวอย่าง DDIC-based view ที่เจอบนเน็ต**

  | เรื่อง | DDIC-based view | view entity |
  |---|---|---|
  | provider contract | `@ObjectModel.provider_contract: #TRANSACTIONAL_QUERY` | `provider contract transactional_query` (clause หลังชื่อ view ก่อน `as projection on`) |
  | currency / unit reference field | `@Semantics.currencyCode: true` | **ไม่ต้องเขียน** — ดูจาก type (`abap.cuky` / `abap.unit`) |

  ```abap
  define root view entity ZC_ZARE002
    provider contract transactional_query
    as projection on ZR_ZARE002
  ```
  root view ถ้าต้องประกาศคู่กันใช้ `provider contract transactional_interface`
- **projection view ที่วางบน root entity ต้องประกาศ `root` ด้วย**
  (เจอจริง 2026-09-07: `ROOT keyword missing in "ZC_ZARE002", since "ZR_ZARE002" has the root property`)
  → `define root view entity ZC_ZARE002 as projection on ZR_ZARE002`
  คุณสมบัติ root ไม่ได้สืบทอดมาให้เอง ต้องเขียนซ้ำทุกชั้นที่ project ต่อ
- **`@Semantics.currencyCode` / `@Semantics.unitOfMeasure` ใช้ใน view entity ไม่ได้**
  (เจอจริง 2026-09-07: `Annotation Semantics.currencyCode is not allowed in view entities`)
  → ดูตารางเทียบข้างบน · แต่ **`@Semantics.amount.currencyCode` /
  `@Semantics.quantity.unitOfMeasure`** บน field จำนวนเงิน/ปริมาณ **ยังใช้ได้ปกติ**
  ชื่อคล้ายกันมาก อย่าลบทิ้งไปด้วยกัน
- **draft-enabled root ต้องมี `create` และ `delete` อย่างน้อยแบบ `internal`** ถึงจะเป็น BO
  update-only ก็ตาม (เจอจริง 2026-09-16: `The operation "create" is required (at least "internal")
  for draft-enabled entity`) — draft machinery ใช้สร้าง/ทิ้ง draft instance ·
  `internal` = ไม่โผล่ใน OData · **ห้าม `use create` / `use delete` ใน projection**
- **key field ใน strict(2) ต้อง `field ( readonly : update ) <Key>`** (warning: `should be
  flagged as "readonly" or "readonly:update"`) — ใช้ `readonly : update` ไม่ใช่ `readonly` เฉย ๆ
  เพราะพอมี `create` (แม้ internal) RAP จะถามหา numbering ให้ key ที่ readonly เต็ม
- **Comment ใน BDEF (`.asbdef`) ใช้ `//` ไม่ใช่ `"`** — `"` เป็นของ ABAP ใช้ใน `.asbdef` ไม่ได้
- **RAP derived type (`TYPE STRUCTURE FOR READ RESULT ...`) ใช้ตรง ๆ ใน method signature ไม่ได้**
  parser จะกิน token ถัดไป (`RETURNING`, `EXPORTING`) เข้ามาเป็นส่วนหนึ่งของ type
  → ประกาศเป็น `TYPES:` alias ก่อนเสมอ แล้วค่อยอ้าง alias ใน signature
- **RAP unit test ต้อง `ROLLBACK ENTITIES` ใน `setup`** — `COMMIT ENTITIES` ที่ fail
  ไม่ทิ้งข้อมูลใน transactional buffer ของค้างจะถูก save ไปพร้อม test ถัดไป
- **`FAILED` / `REPORTED` ต้องระบุ `LATE` ใน handler ของ save phase**
  `FOR VALIDATE ON SAVE` / `FOR DETERMINE ON SAVE` ได้ `failed`/`reported` แบบ **LATE**
- **`total etag` ประกาศได้เฉพาะ BO ที่มี draft** — BO นี้มี draft และประกาศ
  `total etag LastChangedAt` แล้ว · field `last_changed_at` ถูกเพิ่มเข้า `ztar_i002_item`
  (repo `fplus-zari002` commit `0762ada`) เพื่อการนี้โดยเฉพาะ — ดู `docs/01_architecture.md` §5
- **FE inline edit (SAPUI5 ≥ 1.136) ใช้กับ RAP draft BO ได้** — พิสูจน์แล้ว 2026-09-16 ทั้งใน
  demo (`Thianthai/demo-rapedit`) และ ZARE002 · RAP ส่ง `__EntityControl/Updatable = true` ให้ active
  row และรับ PATCH active ตรงโดยไม่สร้าง draft · **อย่าเชื่อประโยค "Edit must be used first" ในเอกสาร
  RAP ว่าครอบคลุมเคสนี้** — Claude เคยสรุปผิดจากประโยคนั้นแล้วเสียเวลาไปครึ่งวัน
  · เปิดที่ manifest: `routing.targets.<LR>.options.settings.inlineEdit.enabledFields: ["<Field>"]`
- **`@UI.multiLineText: true` ทำให้ FE inline edit ไม่ทำงานกับ field นั้น** (เจอจริง 2026-09-16 —
  ช่องเป็น read-only ไม่มีดินสอ ทั้งที่ backend ให้ `Updatable true` + field control `3` · ตัด annotation
  ออกแล้วแก้ได้ทันที) · FE render multiLineText ในตารางเป็น `ExpandableText` ซึ่ง inline edit ไม่จับ
  · **ก่อนใส่ annotation ที่เปลี่ยน control ของช่อง ให้ถามก่อนว่าช่องนั้นต้องแก้ inline ไหม**
- **วิธี debug "ช่องแก้ไม่ได้" ให้ยิง OData ดูค่าจริงก่อนเดา** — `Item?$top=1&$select=__EntityControl,
  __FieldControl` ใน console บอกได้ทันทีว่า backend หรือ FE เป็นคนปฏิเสธ (ใช้ 1 บรรทัด ประหยัดกว่า
  ไล่เทียบ BDEF ทั้งไฟล์)
- **`@UI.presentationVariant` ต้องมี `visualizations: [ { type: #AS_LINEITEM } ]`** ไม่งั้น FE V4
  ไม่หยิบมาเป็น default sort ของ List Report (เจอจริง 2026-09-16 — แถวเรียงตาม insert order)
- **คอลัมน์ที่อยากได้แต่ icon สี** — อย่าเขียนทับ field ข้อมูลด้วย `''` (filter จะพัง)
  ให้เพิ่ม element literal `''` แยก แล้วใส่ `@UI.lineItem` + `criticality` ที่ตัวนั้น
  ส่วน field จริงเหลือ `@UI.selectionField` และ**ห้าม `@UI.hidden`** (จะหายจาก filter bar)
- **⚠️ ก่อนวิเคราะห์ behavior pool ต้อง `git show origin/main:src/<bdef>` อ่าน BDEF ตัวล่าสุดเสมอ**
  (พลาดจริง 2026-09-15: ตัดสินว่า saver "ไม่เคยถูกเรียก" จาก BDEF ของ commit เก่า ทั้งที่ commit
  ถัดมาเปลี่ยนเป็น `with unmanaged save` ไปแล้ว → สั่งลบ saver → BO ไม่มีคนเขียน table)
  ผู้ใช้แก้ BDEF ระหว่าง session ได้เสมอ · BDEF กับ pool ต้องอ่านคู่กันจาก commit เดียวกัน
- **saver class ต้องคู่กับ BDEF เสมอ** — `with unmanaged save` = framework **ไม่เขียน** table
  ต้องมี `lsc_*` เขียนเอง · `with additional save` = framework เขียนแล้วค่อยเรียก saver เพิ่ม
  · ไม่ประกาศทั้งคู่ = saver ไม่เคยถูกเรียก · **แก้ฝั่งเดียวไม่ได้ ต้องแก้พร้อมกันทั้ง BDEF และ pool**
- **saver ของ `with additional save` redefine ได้แค่ `save_modified` + `cleanup_finalize`**
  (เจอจริง 2026-09-16: `The method "CLEANUP" cannot be redefined in accordance with BEHAVIOR
  definition`) — `cleanup` / `finalize` / `check_before_save` / `save` เป็นของ **unmanaged save**
  · ล้าง static buffer ใน `cleanup_finalize` · OData request ของ RAP เป็น stateless (session ใหม่
  ทุก request) static buffer จึงไม่รั่วข้าม request อยู่แล้ว
- **เขียน table นอก BO (เช่น `ztar_i002_pymt`) ต้องทำใน saver (`with additional save`)**
  ไม่ใช่ใน action handler — RAP ห้าม modify database ใน interaction phase
  · เขียนเฉพาะ field ด้วย `UPDATE ... SET` **ห้าม `MODIFY ... FROM TABLE`** (แทนที่ทั้ง row)
  · ดู `docs/01_architecture.md` §3
- **`cx_sxml_error` ไม่ released ใน ABAP Cloud** (เจอจริง 2026-09-20: `The use of Class
  CX_SXML_ERROR is not permitted`) — `cl_sxml_string_reader` ใช้ได้ แต่ exception ของมันจับด้วย
  `CATCH cx_root` แทน
- **`cl_sxml_string_reader=>create( )` auto-detect format** — ส่ง HTML/XML เข้าไปมันจะ parse
  เป็น XML สำเร็จ ไม่ raise (เจอจริง 2026-09-20 จาก unit test) → ห้ามพึ่ง exception เป็นตัวบอกว่า
  body ไม่ใช่ JSON ที่คาด ต้องเช็คเองว่าเจอ member ที่ต้องการหรือไม่
- **table expression `itab[ … ]` รับแค่ `=`** ไม่รับ `<>` / `>` (`Field "TABLE_LINE" is unknown`)
  → เงื่อนไขอื่นใช้ `LOOP AT … WHERE` · **`DATA(x) = 'literal'` ได้ type `c` ไม่ใช่ `string`**
  → ส่งเข้า parameter `string` ไม่ได้ ใช้ backtick `` `…` `` หรือ `&&`
- **Salesforce client credentials ไม่ส่ง `expires_in` → Communication Arrangement cache token ค้าง
  ไม่ refresh เองแม้เจอ 401** (พิสูจน์ 2026-09-21 · SAP Community ยืนยันเป็นพฤติกรรม Public Cloud)
  · Check Connection ที่ arrangement = ขอใหม่ (workaround มือ) · ทางถาวรดู OQ-34 (ขอ token เองผ่าน
  Basic-auth outbound service + ใส่ Bearer เอง) · **`GET /services/data/` ไม่ต้องใช้ token —
  ห้ามใช้เป็น ping พิสูจน์ OAuth** ใช้ `/services/data/v66.0/limits` แทน
- **Path ใน Communication Arrangement เป็น prefix — `set_uri_path( )` ต่อท้าย ไม่ได้แทนที่**
  (เจอจริง 2026-09-21: prefix `/services/oauth2/token` + `set_uri_path` path เดียวกัน → 404)
  → ตั้ง Default Path / Path ของ outbound service เป็น **`/`** แล้วให้ class ใส่ path เต็มเองเสมอ
  (pattern ของ ZARI002) — โดยเฉพาะ scenario ที่ต้องยิงหลาย path
- **ชื่อ field ของ Salesforce ห้ามเชื่อ spec/ตัวอย่าง — ยิง `GET /sobjects/<Object>/describe` ผ่าน
  arrangement ดูของจริง** (เจอจริง 2026-09-20: spec ให้ตารางกับ JSON example ที่ชื่อไม่ตรงกัน เลือกผิด
  → `INVALID_FIELD` ตอน Reject จริง) · describe ใช้เวลา 2 นาที ถูกกว่าถามคนหรือเดา
- **ABAP Doc (`"!`) ทุก class · method · constant group · type** — รวม test class และ `setup`
  · `"!` ใช้ได้เฉพาะหน้า declaration ใน body ใช้ `"` ธรรมดา
  · **`METHODS … REDEFINITION` (เช่น `save_modified` / `cleanup_finalize` ใน `lsc_Item`) ใส่ `"!` ไม่ได้**
  — warning `ABAP Doc comment is in the wrong position` · ใช้ `"` ธรรมดา
- **ห้ามใส่ emoji / สัญลักษณ์ (⚠️ ฯลฯ) ใน comment ของ ABAP object** (ผู้ใช้สั่ง 2026-09-20) —
  ใช้คำแทน เช่น "utility ทดสอบ" · emoji ใช้ได้เฉพาะในเอกสาร markdown
- utility ทดสอบทั้งหมดรวมใน `ZCL_ZARE002_UTIL` ตัวเดียว (method ต่อ 1 งาน · main ปิดไว้ค่าเริ่มต้น)
  ไม่แตกเป็น spike หลาย class · ลบทั้ง class ก่อน handover
- Error ทั้งหมดรวมศูนย์ที่ message class `ZARE002` (สร้างตอนเริ่มใส่ logic ปุ่ม)

## ⚠️ Cross-package — table เป็นของ ZARI002

`ZTAR_I002_PYMT` / `ZTAR_I002_ITEM` อยู่ package **`ZARI002`** คนละ repo คนละ transport
**ZARI002 เป็นเจ้าของ contract ของ table — จะแก้โครงสร้างต้องคุยกันก่อนเสมอ**

| ใคร | ทำอะไรกับ table |
|---|---|
| **ZARI002** | insert อย่างเดียว · เขียน `status = 'N'` · ไม่เคยแตะ `reject_reason` |
| **ZARE002** (งานนี้) | อ่านทุก row · **update `reject_reason` ที่ item** · (เฟสถัดไป) update `status` ที่ header |
| **ZARI003** | อ่านอย่างเดียว |

การแบ่งงานนี้ยืนยันแล้วใน `zari002/docs/01_architecture.md` §9 และ `04_field_mapping.md`
ซึ่งระบุตรง ๆ ว่า `reject_reason` **"ZARI002 ไม่เคยเขียน — เป็นของ ZARE002"**

## Git — การแบ่งงาน

| สิ่งที่ทำ | ใคร commit/push |
|---|---|
| **ABAP object ทุกชนิด** (CDS, BDEF, behavior pool, DDIC, service def/binding) | **ผู้ใช้** |
| **เอกสาร** (`docs/`, `README.md`, `CLAUDE.md`) | **Claude** commit **และ push เอง** ทันทีที่ commit — ไม่ต้องรอสั่ง |

- ⚠️ **"ผม push ขึ้น Git" ของผู้ใช้ = abapGit push จาก ADT เท่านั้น** ไม่ใช่เอกสาร
  (ตีความผิดมาแล้ว 2026-09-07 → 09-15: เอกสารค้าง 13 commit ไม่ได้ push เพราะ Claude รอผู้ใช้)
  **abapGit push จาก ADT ไม่ได้ push เอกสารไปด้วย** — สองฝั่งแยกกันเด็ดขาด
- **ลำดับ push**: Claude push เอกสาร → ผู้ใช้ abapGit push · ถ้า abapGit push ไปก่อน
  local จะ diverge ต้อง `git rebase origin/main` ก่อน push (ไม่ conflict เพราะคนละไฟล์)
- Claude **ห้ามสร้างไฟล์ ABAP ลง repo** (`src/**/*.abap`, `*.ddls.asddls`, `*.asbdef` ฯลฯ)
  → ส่งเป็น **code block ใน chat** ให้ผู้ใช้ copy ไปสร้างใน ADT แล้ว push ผ่าน abapGit เอง
  เหตุผล: source of truth ของ ABAP object คือ tenant และ abapGit reformat code เอง
  ถ้าเขียนลง repo ทั้งสองฝั่งจะชนกัน
- `.abapgit.xml` และ `package.devc.xml` เป็นของที่ **SAP serialize เอง** — ห้าม Claude เขียนหรือแก้มือ
- Claude คอยเช็ค `git log` / `git status` ว่าผู้ใช้ push object อะไรขึ้นมาแล้วบ้าง
  แล้วอัปเดต status ใน `docs/03_object_list.md` ให้ตรง
- Remote: https://github.com/Thianthai/fplus-zare002.git
- ของกลาง (`ZCL_UTILITY` / token scenario) อยู่ repo แยก https://github.com/Thianthai/fplus-zbcutility.git
  (local `~/Claude/projects/fplus/zbcutility`) — เอกสารของมัน Claude ดูแลเหมือนกัน

## ADT ขึ้น HTTP 500 — ลองใหม่ก่อนไล่หาสาเหตุ

เจอมาแล้ว 2 ครั้งบน tenant นี้ระหว่างทำ ZARI002 ทั้งคู่หายเองโดยไม่ได้แก้อะไร
(link abapGit repo · publish HTTP service) — **ลองซ้ำ 1–2 ครั้งก่อนเสมอ**
ถ้ายังไม่ผ่านค่อยไปดู short dump ที่ ADT → Feed Reader → ABAP Runtime Errors

## วิธีทำงานเมื่อข้อมูลยังไม่ครบ

- เจอจุดที่ไม่ชัด → **note ลง `docs/06_open_questions.md` แล้วเดินต่อทันที** อย่าหยุดรอ
- logic ที่ยังตัดสินใจไม่ได้ → เปิดเป็น **ที่ว่าง (empty hook)** ไว้ใน BDEF พร้อม comment
- **จบทุก phase ต้องไล่รีวิวทะเบียนข้อสงสัยทั้งตาราง** ก่อนขึ้น phase ถัดไป
