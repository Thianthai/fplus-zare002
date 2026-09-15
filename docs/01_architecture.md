# ZARE002 — Architecture & Design Decisions

## 1. ภาพรวม

หน้าจอเดียว — Fiori elements **List Report** บน OData V4 แสดง payment item ทุกบรรทัด
ที่ ZARI002 รับเข้ามา ผู้ใช้แก้ `reject_reason` ได้ในตาราง และมีปุ่ม Submit / Reject บน toolbar

```
ZTAR_I002_PYMT ──┐
                 ├──▶ ZI_ZARE002_ITEM ──▶ ZR_ZARE002 ──▶ ZC_ZARE002 ──▶ ZUI_ZARE002_O4
ZTAR_I002_ITEM ──┘      (+ assoc)         (BDEF managed,   (projection    (OData V4 UI)
                                            with draft)     + metadata ext)
```

**ไม่มี Object Page** — `@UI.facet` ห้ามใส่ · ทุกอย่างจบที่ `@UI.lineItem`

---

## 2. `reject_reason` — ตัดสินใจใช้ `ZTAR_I002_ITEM` ไม่แยก table (2026-09-07)

### ข้อสรุป

**ยกเลิก `ZTAR_E002_EDIT` · ใช้ `ZTAR_I002_ITEM.REJECT_REASON` ที่มีอยู่แล้ว**

### หลักฐาน

`ZTAR_I002_ITEM` มี `REJECT_REASON char(200)` อยู่แล้ว และเอกสารของ ZARI002 ระบุตรง ๆ ว่า
field นี้ถูกออกแบบมาให้ ZARE002 เป็นคนเขียนตั้งแต่แรก:

> `zari002/docs/04_field_mapping.md`
> `RejectReason` | `reject_reason` | `char(200)` | out | – | **ZARI002 ไม่เคยเขียน — เป็นของ ZARE002**

> `zari002/docs/01_architecture.md` §3.3.1
> item มีแค่ `reject_reason` (char 200) ซึ่ง **ZARI002 ไม่เคยเขียน** เป็นของ ZARE002
> ที่อยากระบุว่า item ไหนมีปัญหา

`ZTAR_E002_EDIT.reject_reason` จึงเป็น **field ซ้ำกับที่ออกแบบไว้ให้เราแล้ว**
เก็บข้อมูลเดียวกันสองที่ = วันหนึ่งค่าไม่ตรงกันแน่นอน

### เหตุผลทางเทคนิค — managed RAP BO เขียนได้ table เดียว

ถ้าแถวในรายงานมาจาก `ITEM` แต่ field ที่แก้ได้อยู่ที่ `EDIT` จะติดทุกทาง:

| วิธี | ผลที่ได้ |
|---|---|
| root view = `ITEM` **INNER JOIN** `EDIT` | ❌ item ที่ยังไม่เคยถูก reject **หายจากรายงาน** — ซึ่งคือเกือบทุกแถว |
| root view = `ITEM` **LEFT OUTER JOIN** `EDIT` | ❌ `persistent table` เป็น `ITEM` → `reject_reason` ไม่มี mapping → BDEF activate ไม่ผ่าน |
| root persist ที่ `EDIT` | ❌ ต้องมี row ครบทุก item ก่อน → ต้องให้ ZARI002 สร้างให้ (ผูกกันข้าม RICEFW) หรือทำ sync job (race condition) |
| `managed with unmanaged save` + saver class | ⚠️ ทำได้ แต่ต้องเขียน save logic เอง + ผสมกับ draft = งานเพิ่มหลายเท่า เพื่อ field เดียว |

### เหตุผลเดียวที่ฟังขึ้นของการแยก table — และทำไมมันตกไป

"ไม่อยากให้ UI app เขียนทับ table ที่รับ payload เข้ามา" (แยก audit ระหว่างข้อมูลขา inbound
กับข้อมูลที่คนพิมพ์) — เหตุผลนี้ใช้ไม่ได้กับ project นี้ เพราะ **ZARE002 ถูกออกแบบให้เขียน
`ztar_i002_pymt` อยู่แล้ว** (`status` = S/W/E, `salesforce_status`, `salesforce_message`)
การเขียนเพิ่มอีก 1 column จึงไม่ได้สร้าง coupling ใหม่

### ข้อสังเกตของ `ZTAR_E002_EDIT` ที่ทิ้งไป

- key `payment_uuid + item_uuid` **ซ้ำซ้อน** — `item_uuid` เป็น key ของ `ITEM` อยู่แล้ว ใช้ตัวเดียวพอ
- ไม่มี `last_changed_at` เหมือนกัน — ถ้าจะทำ draft ก็ต้องเพิ่มอยู่ดี

### จะกลับมาแยก table เมื่อไหร่

1. มีนโยบายห้าม UI เขียน table ขา inbound
2. ZARI002 เปิด update แล้วมีโอกาสเขียนทับ `reject_reason`
3. ต้องเก็บ **ประวัติ** การแก้ `reject_reason` (ใครแก้ เมื่อไหร่ ค่าเดิมอะไร)

ตอนนี้ยังไม่มีข้อไหนเป็นจริง — ถ้าวันหน้าข้อ 3 เกิดขึ้น ให้ทำเป็น **log table แยก** (append-only)
ไม่ใช่ย้ายที่เก็บค่าปัจจุบัน

---

## 3. รูปทรงของ RAP BO

**เริ่มแบบ non-draft ก่อน** (ตกลง 2026-09-07 — เหตุผลใน §5)

```
managed implementation in class ZBP_R_ZARE002 unique;
strict ( 2 );

define behavior for ZR_ZARE002 alias Item
persistent table ztar_i002_item
lock master
authorization master ( global )
etag master LocalLastChangedAt
{
  update;                      // ไม่มี create / delete
  field ( readonly ) <ทุก field ยกเว้น RejectReason>;
  action Submit;               // เปล่า
  action Reject;               // เปล่า
  mapping for ztar_i002_item corresponding;
}
```

**จุดสำคัญ**

- **ไม่มี `create` / `delete`** — รายงานนี้ไม่เคยสร้างหรือลบ item · row เกิดจาก ZARI002 เท่านั้น
- **ไม่ประกาศ `total etag`** — ประกาศได้เฉพาะ BO ที่มี draft (ZARI002 พิสูจน์แล้ว 2026-08-27)
- `authorization master ( global )` — ทุกคนที่เข้า app ได้เห็นทุกแถวทุก company code (OQ-15)
- Submit / Reject เป็น **instance action** (ไม่ใช่ static) เพื่อให้ปุ่มขึ้น toolbar
  แล้วทำงานกับแถวที่ติ๊กเลือกไว้ตาม mockup ("2 Selected")

ถ้าต้องอัปเกรดเป็น draft จะเพิ่ม `with draft` + `draft table ztar_e002_item_d`
+ `total etag LastChangedAt` เข้าไป — ไม่ได้รื้อของเดิม

### การเขียน `status` ลง header ในเฟส logic — ต้องผ่าน saver ไม่ใช่ action handler (บันทึก 2026-09-15)

`ztar_i002_pymt` **ไม่ได้อยู่ใน BO นี้** (root = item อย่างเดียว) → ใช้ EML เขียนไม่ได้
และ RAP **ห้าม** modify database ใน interaction phase (action handler) → `UPDATE` ตรง ๆ ใน
`submitItem` / `rejectItem` ผิดกติกา

ทางที่ถูก:

```
BDEF   managed implementation ... with additional save;
pool   CLASS lsc_Item DEFINITION INHERITING FROM cl_abap_behavior_saver.
         METHODS save_modified REDEFINITION.
       → UPDATE ztar_i002_pymt SET status = @lv_status, ...
           WHERE payment_uuid IN @lr_payment_uuid.
```

- `with additional save` = framework ยังเขียน `ztar_i002_item` ให้เหมือนเดิม แล้วค่อยเรียก
  `save_modified` เพิ่ม — ไม่ใช่ `with unmanaged save` ที่จะโยนงานเขียน item มาให้เราทั้งหมด
- เขียน**เฉพาะ field** ด้วย `UPDATE ... SET` — **ห้าม `MODIFY ... FROM TABLE`** เพราะแทนที่ทั้ง row
  field ที่ไม่ได้ใส่จะกลายเป็นค่าว่าง
- action handler แค่**จำ**ว่าจะทำอะไร (เช่น เก็บ payment_uuid + status ใหม่ไว้ใน buffer ระดับ class)
  แล้ว saver ค่อยเขียนตอน save phase
- ชื่อ saver class = `lsc_Item` ตามกฎ `lsc_<Entity>`

⚠️ **ตอนนี้ยังไม่มี saver และห้ามมี** — เคยมี `lsc_zr_zare002` ค้างอยู่ใน pool โดย BDEF ไม่ได้
ประกาศ additional/unmanaged save = ไม่เคยถูกเรียก และโค้ดข้างในเป็น `MODIFY` แบบไม่ใส่ key
ถ้าถูกเรียกขึ้นมาจะเขียนทับ row ผิดและล้าง field อื่นทิ้ง → ลบออกใน Phase 5

## 4. ทำไม JOIN ไม่อยู่ที่ root view

requirement เดิมอยากให้ root entity มี field header → field item → `reject_reason` เรียงกัน
แต่ **root view ที่ผูก `persistent table` ต้อง map 1:1 กับ table นั้น** ถ้าเอา
`ztar_i002_pymt` มา join ที่ root view ตรง ๆ field ของ header จะไม่มีที่ให้ map
BDEF จะ activate ไม่ผ่าน (`Field ... is not mapped to a field of the database table`)

**วิธีที่ใช้แทน — ผลลัพธ์บนหน้าจอเหมือนกันเป๊ะ**

| Layer | หน้าที่ |
|---|---|
| `ZI_ZARE002_PYMT` | interface view บน `ztar_i002_pymt` — 1:1 |
| `ZI_ZARE002_ITEM` | interface view บน `ztar_i002_item` — 1:1 + association `_Payment` (to-one, on `payment_uuid`) + `_Customer` |
| `ZR_ZARE002` | root view entity — projection บน `ZI_ZARE002_ITEM` (ยังคง 1:1 กับ table) + expose association |
| `ZC_ZARE002` | **projection view** — ดึง field header ขึ้นมาด้วย path expression `_Payment.CompanyCode as CompanyCode` · field ที่มาจาก path เป็น read-only โดยอัตโนมัติ |

ลำดับคอลัมน์บนหน้าจอคุมที่ `@UI.lineItem.position` ใน metadata extension อยู่แล้ว
ไม่ได้ขึ้นกับลำดับ field ใน root view

---

## 5. Draft — เดิน non-draft ก่อน แล้ววัดผลจริง (ตกลง 2026-09-07)

### เดิมคิดว่าอย่างไร

inline edit ใน List Report ของ Fiori elements V4 **น่าจะ**รองรับเฉพาะ draft-enabled BO
เพราะค่าที่พิมพ์ค้างไว้ยังไม่ save ต้องมีที่เก็บ และ List Report ไม่มี edit mode แบบ Object Page

### ทำไมไม่ยึดข้อนั้นเป็นสมมติฐานตั้งต้น

ต้นทุนของ draft **ไม่ได้อยู่ที่ draft table** แต่อยู่ที่ **ต้องไปแก้ `ZTAR_I002_ITEM`
ซึ่งเป็น table ของ package `ZARI002`** — draft root ต้องประกาศ `total etag` และ
`total etag` ต้องผูกกับ field `abp_lastchange_tstmpl` ที่ item **ยังไม่มี** (header มี)

ZARI002 จงใจไม่ใส่ไว้และเขียนกำกับว่า *"ห้ามไปแก้ให้เท่ากัน"* — แต่เหตุผลของเขาคือ
*"BO นี้เป็น API ไม่มี draft"* และเปิดทางไว้แล้วว่า:

> `zari002/docs/01_architecture.md` §3.4
> `last_changed_at` ... ตั้งใจไว้ให้เป็น `total etag` ... **ถ้าวันหน้าทำ draft ก็พร้อมใช้เป็น total etag ทันที**

การไปแก้ table ของอีก RICEFW เพราะ**สมมติฐานที่ยังไม่ได้พิสูจน์** ไม่คุ้ม

### ลำดับที่เลือกเดิน

1. ทำ BO **non-draft** ให้เสร็จ (Phase 2–3)
2. preview แล้ว**ลองคลิกช่อง Reject Reason พิมพ์ดูจริง ๆ** (Phase 4.1)
3. ถ้าพิมพ์ได้ → จบ ไม่ต้องแตะ table ของ ZARI002 เลย
4. ถ้าพิมพ์ไม่ได้ → ค่อยเพิ่ม `last_changed_at` + draft table + `with draft` (Phase 4.3–4.7)

การอัปเกรดจาก non-draft เป็น draft **เป็นการเติม ไม่ใช่การรื้อ** — root view, projection view,
metadata extension, `field ( readonly )` ทั้งหมดใช้ต่อได้เหมือนเดิม

การเพิ่ม field ท้ายตารางที่มีข้อมูลอยู่เป็น `ALTER TABLE` ธรรมดา **ข้อมูลเดิมไม่หาย**
และผู้ใช้เป็นเจ้าของ ZARI002 เองอยู่แล้ว จึงไม่มี lead time รอทีมอื่น

### Concurrency (ทั้งสองแบบเหมือนกัน)

`local_last_changed_at` ที่ item มีอยู่แล้ว → `etag master` ใช้ได้เต็มรูปแบบ
**แก้คนละ item ในใบเดียวกันพร้อมกันได้ไม่ชนกัน**

ส่วน ZARI002 ที่ `INSERT` + `COMMIT WORK` ตรง ๆ ไม่ผ่าน RAP lock — **ไม่ชนกันในทางปฏิบัติ**
เพราะ ZARI002 **insert อย่างเดียว** ส่วน ZARE002 **update row ที่มีอยู่แล้วอย่างเดียว**

## 6. Customer Name — ดึงจาก `I_BusinessPartner` (ตกลง 2026-09-07)

mockup มีคอลัมน์ **Customer Name** แต่ทั้ง `ztar_i002_pymt` และ `ztar_i002_item`
เก็บแค่ `customer_code` → ดึงชื่อผ่าน association ไปที่ **`I_BusinessPartner`**

```
_BusinessPartner : [0..1] to ZI_ZARE002_BP
  on $projection.CustomerCode = _BusinessPartner.BusinessPartner
```

`ZI_ZARE002_BP` เป็น view เล็ก ๆ บน `I_BusinessPartner` ที่ทำหน้าที่เดียว —
ต่อ `OrganizationBPName1..4` ด้วยช่องว่างเป็น `CustomerName`
(ไม่ใช้ `BusinessPartnerFullName` ของ SAP · เหตุผลและสูตร concat อยู่ใน `04_field_mapping.md` §4)

**key ตรงกันโดยไม่ต้องแปลงอะไร** — `ZTAR_I002_ITEM.customer_code` ถูก ZARI002 ยิงผ่าน
`to_internal_key( )` (`ALPHA = IN`) ก่อน insert ทุกครั้ง จึงเป็น internal format `CHAR 10`
เหมือนกับ `I_BusinessPartner-BusinessPartner` เทียบตรง ๆ ได้เลย
(หลักฐาน: `zari002/src/zcl_zari002_processor.clas.abap:262`)

ที่ต้องมี view คั่นกลางแทนที่จะ associate `I_BusinessPartner` ตรง ๆ เพราะ `CustomerName`
โผล่ได้เฉพาะที่ projection view (root view ผูก persistent table) และ projection view
รับ path expression ได้ดีกว่า expression ซ้อนหลายชั้น — รายละเอียดใน `04_field_mapping.md` §4

### ⚠️ เรื่องสิทธิ์ที่ยังต้องทดสอบ

ZARI002 ต้องใช้ `WITH PRIVILEGED ACCESS` อ่าน `I_Customer` เพราะเรียกจาก communication user
**แต่ ZARE002 เป็น UI ที่ผู้ใช้จริง login** — และที่สำคัญกว่านั้น
**association ใน CDS ใช้ `WITH PRIVILEGED ACCESS` ไม่ได้เลย** ไม่ว่ากรณีไหน
view ถูกอ่านด้วยสิทธิ์ของผู้ใช้เสมอ

ผลถ้า business role ไม่มีสิทธิ์ดู business partner: path expression ของ CDS
สร้าง **LEFT OUTER JOIN** ให้อยู่แล้ว → **แถวไม่หาย** แต่ **Customer Name จะว่าง**
เป็น failure mode ที่ยอมรับได้ ไม่ทำให้รายงานพัง (OQ-09)

---

## 7. ความเสี่ยงที่รู้ตั้งแต่ตอนนี้

| # | เรื่อง | ผลกระทบ |
|---|---|---|
| 1 | **`status` อยู่ระดับ header แต่ `reject_reason` อยู่ระดับ item** | ตอนทำ logic ปุ่ม Reject จริง — เลือก reject 1 item จาก 3 item ในใบเดียวกัน แต่ `status` เขียนได้ทั้งใบเท่านั้น ต้องตกลง business rule ก่อน (OQ-04) |
| 2 | mockup ทำ Payment Document No. เป็น link | ไม่มี Object Page → ต้องเป็น text ธรรมดา หรือ link ออก standard app |
| 3 | mockup ดูเหมือน 1 row = 1 payment แต่ requirement บอก line item level | ใบที่มี 3 item จะได้ 3 แถวที่ header ซ้ำกัน — ยึดตาม requirement (OQ-01) |
| 4 | `reject_reason` ยาว 200 ตัวอักษร | ในตารางต้องใช้ `@UI.multiLineText` ไม่งั้นคอลัมน์กว้างมาก |
| 5 | Cross-package — table เป็นของ `ZARI002` | ถ้า ZARI002 แก้โครงสร้าง CDS ของเราพังทันที ต้องแจ้งกันสองทาง |
| 6 | **สิทธิ์ระดับ company code ยังไม่ตัดสิน** — เดิน `authorization master ( global )` ไปก่อน | ถ้าภายหลังต้องแยกตาม CC ต้องรื้อ BDEF เป็น `( instance )` + เพิ่ม restriction type/field ที่ IAM App และ business role (OQ-15) |
