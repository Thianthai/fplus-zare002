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
| 6 | Customer Name | **ไม่มีใน table** | — | `CustomerName` | `_Customer` (released view) | ✘ |
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
| `_Customer` | `I_Customer` (released — ต้องยืนยัน) | `[0..1]` | `$projection.CustomerCode = _Customer.Customer` |

`_Payment` เป็น to-one จริง เพราะ `payment_uuid` เป็น key ของ header
→ ดึงขึ้นมาเป็นคอลัมน์ใน projection view ด้วย path expression ได้ปลอดภัย

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
