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
| 6 | Customer Name | **ไม่มีใน table** | — | `CustomerName` | `_BusinessPartner` | ✘ |
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
| `_BusinessPartner` | `I_BusinessPartner` | `[0..1]` | `$projection.CustomerCode = _BusinessPartner.BusinessPartner` |

`_Payment` เป็น to-one จริง เพราะ `payment_uuid` เป็น key ของ header
→ ดึงขึ้นมาเป็นคอลัมน์ใน projection view ด้วย path expression ได้ปลอดภัย

### `_BusinessPartner` — key ตรงกันโดยไม่ต้องแปลงอะไร (ยืนยัน 2026-09-07)

`ZTAR_I002_ITEM.customer_code` เก็บเป็น **internal format อยู่แล้ว** — ZARI002 ยิงผ่าน
`to_internal_key( )` (`|{ lv_key ALPHA = IN }|`) ก่อน insert ทุกครั้ง
(`zari002/src/zcl_zari002_processor.clas.abap:262`)

`I_BusinessPartner-BusinessPartner` ก็เป็น internal format `CHAR 10` เหมือนกัน
→ **เทียบตรง ๆ ได้เลย ไม่ต้องมี conversion ใน CDS**
(ต่างจากเคส `gl_account` ที่ ZARI002 เคยเจอปัญหา alpha conversion)

### ชื่อลูกค้า — เลือก field ไหนใน `I_BusinessPartner`

| Field | ใช้กับ | หมายเหตุ |
|---|---|---|
| `BusinessPartnerFullName` | **ตัวเลือกหลัก** | ชื่อเต็มที่ระบบต่อให้แล้ว — organization ได้ `OrganizationBPName1..4` ต่อกัน |
| `BusinessPartnerName` | สำรอง | ถ้า `FullName` ว่างบน tenant นี้ |
| `OrganizationBPName1` | สำรอง | ถ้าลูกค้าเป็น organization ล้วนและอยากได้บรรทัดแรกอย่างเดียว |

⚠️ **ต้องดู Data Preview ของ `I_BusinessPartner` บน tenant จริงก่อน** ว่า field ไหนมีค่า —
mockup ต้องการ `ABC Company Limited` ซึ่งเป็นชื่อ organization

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
