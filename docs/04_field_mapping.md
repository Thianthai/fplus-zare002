# ZARE002 — Field Mapping

คอลัมน์บนหน้าจอ (ตาม mockup) ↔ field ในฐานข้อมูล ↔ ชื่อ element ใน CDS

## 1. คอลัมน์ที่แสดง — เรียงตาม mockup

| # | คอลัมน์บนหน้าจอ | มาจาก table | Field | CDS element | ที่มา | แก้ได้ |
|---|---|---|---|---|---|---|
| 1 | Payment Document No. | `ZTAR_I002_PYMT` | `payment_document_no` | `PaymentDocumentNo` | `_Payment` | ✘ |
| 2 | No. of Items in Payment | `ZTAR_I002_PYMT` | `number_of_items_in_payment` | `NumberOfItemsInPayment` | `_Payment` | ✘ |
| 3 | Company Code | `ZTAR_I002_PYMT` | `company_code` | `CompanyCode` | `_Payment` | ✘ |
| 4 | Posting Date | `ZTAR_I002_PYMT` | `posting_date` | `PostingDate` | `_Payment` | ✘ |
| 5 | Customer Code | `ZTAR_I002_ITEM` | `customer_code` | `CustomerCode` | item | ✘ |
| 6 | Customer Name | **ไม่มีใน table** | — | `CustomerName` | `_BusinessPartner` (ต่อ 4 field — §4) | ✘ |
| 7 | Billing Note No. | `ZTAR_I002_ITEM` | `billing_note_no` | `BillingNoteNo` | item | ✘ |
| 8 | Accounting Document | `ZTAR_I002_ITEM` | `accounting_document` | `AccountingDocument` | item | ✘ |
| 9 | Billing Document | `ZTAR_I002_ITEM` | `billing_document` | `BillingDocument` | item | ✘ |
| 10 | Invoice Amount | `ZTAR_I002_ITEM` | `invoice_amount` | `InvoiceAmount` | item | ✘ |
| 11 | Status | `ZTAR_I002_PYMT` | `status` | `Status` | `_Payment` | ✘ |
| 12 | Reject Reason | `ZTAR_I002_ITEM` | `reject_reason` | `RejectReason` | item | **✔** |

> **`RejectReason` เป็น field เดียวที่แก้ได้ทั้งหน้าจอ** — ที่เหลือ `field ( readonly )` ทั้งหมด

## 2. Field ที่ไม่ได้แสดงแต่ต้องมีใน entity

| Field | ทำไมต้องมี |
|---|---|
| `ItemUuid` | key ของ entity |
| `PaymentUuid` | ใช้ผูก association `_Payment` |
| `Currency` | `@Semantics.amount.currencyCode` ของ `InvoiceAmount` — ขาดไม่ได้ ไม่งั้น activate ไม่ผ่าน |
| `StatusCriticality` | virtual/calculated element ให้ `@UI.criticality` วาด icon 3 สี |
| `LocalLastChangedAt` | `etag master` |
| `LastChangedAt` | `total etag` ของ draft — **ยังไม่มีใน table ต้องขอเพิ่ม** |
| `CreatedBy` `CreatedAt` `LastChangedBy` | admin field |

## 3. Field ที่มีใน table แต่ไม่ใช้ในหน้าจอนี้

**Header** — `request_id` `salesforce_id` `gl_account` `payment_method` `sap_payment_method`
`cheque_no` `issue_date` `due_on` `cheque_bank_branch` `rounding_diff` `advance_payment`
`fees` `payment_amount` `salesforce_status` `salesforce_message`

**Item** — `salesforce_item_id` `invoice_posting_date` `amount_paid` `partial_amount` `sale_submit_date`

> เก็บไว้ใน interface view ได้ ไม่เสียหาย — แค่ไม่ใส่ `@UI.lineItem` ให้มัน
> เผื่อวันหน้าเพิ่มคอลัมน์หรือทำ Object Page

## 4. Association

| Association | Target | Cardinality | On |
|---|---|---|---|
| `_Payment` | `ZI_ZARE002_PYMT` | `[1..1]` | `$projection.PaymentUuid = _Payment.PaymentUuid` |
| `_BusinessPartner` | **`ZI_ZARE002_BP`** | `[0..1]` | `$projection.CustomerCode = _BusinessPartner.BusinessPartner` |

`_Payment` เป็น to-one จริง เพราะ `payment_uuid` เป็น key ของ header
→ ดึงขึ้นมาเป็นคอลัมน์ใน projection view ด้วย path expression ได้ปลอดภัย

### `_BusinessPartner` — key ตรงกันโดยไม่ต้องแปลงอะไร (ยืนยัน 2026-09-07)

`ZTAR_I002_ITEM.customer_code` เก็บเป็น **internal format อยู่แล้ว** — ZARI002 ยิงผ่าน
`to_internal_key( )` (`|{ lv_key ALPHA = IN }|`) ก่อน insert ทุกครั้ง
(`zari002/src/zcl_zari002_processor.clas.abap:262`)

`I_BusinessPartner-BusinessPartner` ก็เป็น internal format `CHAR 10` เหมือนกัน
→ **เทียบตรง ๆ ได้เลย ไม่ต้องมี conversion ใน CDS**
(ต่างจากเคส `gl_account` ที่ ZARI002 เคยเจอปัญหา alpha conversion)

### ชื่อลูกค้า — ต่อเอง 4 field (ตกลง 2026-09-07)

**ไม่ใช้ `BusinessPartnerFullName` ของ SAP** — ต่อ `OrganizationBPName1..4` เองด้วยช่องว่างคั่น

```
CustomerName =
  concat_with_space(
    concat_with_space(
      concat_with_space( OrganizationBPName1, OrganizationBPName2, 1 ),
      OrganizationBPName3, 1 ),
    OrganizationBPName4, 1 )
```

**ไม่ต้องดักกรณี field ว่าง** — `concat_with_space` ตัด trailing blank ของ arg แรกก่อนต่อทุกครั้ง
ชื่อที่ใช้แค่ `Name1` กับ `Name3` จึงได้ `ABC Ltd` ไม่ใช่ `ABC  Ltd`

| เรื่อง | ค่า |
|---|---|
| ความยาวผลลัพธ์ | `CHAR 163` (40×4 + ช่องว่าง 3) — คุมความกว้างคอลัมน์ที่ UI annotation ไม่ต้อง cast |
| field ต้นทาง | `I_BusinessPartner-OrganizationBPName1` … `4` แต่ละตัว `CHAR 40` |

⚠️ **ผลที่ตามมา**: ชื่อที่ ZARE002 แสดง เป็นชื่อที่**เราต่อเอง** ไม่ใช่ชื่อที่ SAP standard app
แสดง ถ้าวันหน้า SAP เปลี่ยนวิธีประกอบชื่อใน `BusinessPartnerFullName` ของเราจะไม่เปลี่ยนตาม
— เป็นสิ่งที่ตั้งใจ ไม่ใช่ bug

### ทำไมต้องมี `ZI_ZARE002_BP` คั่นกลาง ไม่ associate `I_BusinessPartner` ตรง ๆ

`CustomerName` **ห้ามอยู่ใน `ZR_ZARE002`** — root view ผูก `persistent table ztar_i002_item`
field ที่ไม่มีในตารางจะ map ไม่ได้ BDEF activate ไม่ผ่าน (เหตุผลเดียวกับ field header
ดู `01_architecture.md` §4) → `CustomerName` ต้องโผล่ที่ **projection view** เท่านั้น

แต่ projection view รับ **path expression** ได้ดี ส่วน expression ซับซ้อนอย่าง
`concat_with_space` ซ้อน 3 ชั้น ไม่การันตีว่าจะผ่าน — จึงย้าย concat ไปไว้ที่ view เล็ก ๆ
ตัวเดียวแล้วให้ projection view เรียกเป็น path ธรรมดา

```
ZI_ZARE002_BP:  select from I_BusinessPartner
                { key BusinessPartner, <concat 4 field> as CustomerName }

ZC_ZARE002:     _BusinessPartner.CustomerName as CustomerName    // path ธรรมดา
```

ได้ประโยชน์เพิ่ม: logic การประกอบชื่ออยู่ที่เดียว แก้ทีเดียวจบ

## 5. Status — ค่าและสีตาม mockup

`status` ผูก domain `ZD_REQUEST_STATUS` (ของ ZARI002)

| ค่า | ความหมาย | icon ใน mockup | `@UI.criticality` |
|---|---|---|---|
| `N` | New — รอดำเนินการ | 🕐 นาฬิกาเหลือง | `2` (Warning) |
| `C` | Complete | ✅ ติ๊กเขียว | `3` (Positive) |
| `R` | Reject | ❌ กากบาทแดง | `1` (Negative) |
| `E` | Error | ❌ กากบาทแดง | `1` (Negative) |

> mockup มี 3 icon แต่ domain มี 4 ค่า — `R` กับ `E` ใช้สีเดียวกัน (OQ-05)

## 6. หน่วยเงิน

`InvoiceAmount` เป็น `curr(23,2)` → ต้องมี `@Semantics.amount.currencyCode: 'Currency'`
และ `Currency` ต้องอยู่ใน entity เดียวกัน — `ztar_i002_item.currency` copy มาจาก header อยู่แล้ว
