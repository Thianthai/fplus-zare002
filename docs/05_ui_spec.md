# ZARE002 — UI Specification

Fiori elements **List Report** บน OData V4 · **ไม่มี Object Page**

## 1. โครงหน้าจอ

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Automatic Incoming Payments                                             │
├──────────────────────────────────────────────────────────────────────────┤
│  [ Filter bar — @UI.selectionField ]                            [ Go ]   │
├──────────────────────────────────────────────────────────────────────────┤
│  Items (5)        2 Selected   [Submit] [Reject] [Export▾] [⚙▾]          │
├──┬───────────┬─────┬──────┬───────┬────────┬────────┬─────┬────┬────────┤
│☐ │Payment    │No.of│Comp. │Posting│Customer│Customer│ ... │Sts │Reject  │
│  │Document No│Items│Code  │Date   │Code    │Name    │     │    │Reason  │
├──┼───────────┼─────┼──────┼───────┼────────┼────────┼─────┼────┼────────┤
│☑ │IF250500001│  1  │ 1000 │15/05/…│C0001001│ABC Co. │ ... │ 🕐 │[      ]│
└──┴───────────┴─────┴──────┴───────┴────────┴────────┴─────┴────┴────────┘
```

## 2. Annotation ที่ต้องใส่ (metadata extension `ZC_ZARE002`)

| เรื่อง | Annotation |
|---|---|
| ชื่อ app / header | `@UI.headerInfo: { typeName: 'Payment Item', typeNamePlural: 'Items' }` |
| คอลัมน์ | `@UI.lineItem: [{ position: 10, importance: #HIGH }]` — เรียง 10, 20, 30 … ตาม `04_field_mapping.md` |
| filter bar | `@UI.selectionField: [{ position: 10 }]` |
| icon สถานะ | `@UI.lineItem: [{ position: 110, criticality: 'StatusCriticality' }]` |
| ช่องพิมพ์ยาว | `@UI.multiLineText: true` ที่ `RejectReason` |
| ปุ่ม toolbar | `@UI.lineItem: [{ type: #FOR_ACTION, dataAction: 'Submit', label: 'Submit' }]` |
| **ห้ามใส่** | `@UI.facet` — จะทำให้เกิด Object Page |

## 3. พฤติกรรมที่ต้องได้

| # | พฤติกรรม | ได้มาจาก |
|---|---|---|
| 3.1 | ~~คลิกช่อง Reject Reason แล้วพิมพ์แก้ได้ทันทีในตาราง~~ **ทำไม่ได้** — ติ๊กแถว → กดปุ่ม **Edit Reject Reason** → กรอกใน dialog แทน | action `setRejectReason` ที่มี parameter · FE generate dialog ให้เอง (OQ-06) |
| 3.2 | กด Save แล้วค่าลง `ztar_i002_item.reject_reason` จริง | `update` ใน BDEF + managed save |
| 3.3 | ติ๊ก checkbox หลายแถวได้ · แสดง "N Selected" | multi-select ของ List Report (เปิดอัตโนมัติเมื่อมี action) |
| 3.4 | ปุ่ม Submit / Reject ขึ้น toolbar และกดได้โดยไม่ error | instance action + `lhc` ที่ไม่ทำอะไร |
| 3.5 | ทุกคอลัมน์อื่นแก้ไม่ได้ | `field ( readonly )` ใน BDEF |
| 3.6 | คลิกแถวแล้ว**ไม่**เปิดหน้าใหม่ | ไม่มี `@UI.facet` |
| 3.7 | Export ได้ | standard FE |

## 4. สิ่งที่ mockup มีแต่จงใจไม่ทำ

| ในรูป | ทำจริง | เหตุผล |
|---|---|---|
| Payment Document No. เป็น link สีน้ำเงิน | **text ธรรมดา** | ไม่มี Object Page ให้ไป · ถ้าอยากได้ link ต้องตกลงว่าจะไปไหน (OQ-02) |
| 1 row = 1 payment (No. of Items = 2 แต่ขึ้นแถวเดียว) | **1 row = 1 item** | ตาม requirement — ใบที่มี 3 item ได้ 3 แถว header ซ้ำกัน (OQ-01) |
| ปุ่ม Submit เขียว / Reject แดง | สีตาม theme | FE ไม่ให้กำหนดสีปุ่ม action เอง — ทำได้แค่ `#FOR_ACTION` ธรรมดา (OQ-03) |
| Status เป็น icon เปล่า ๆ | **ข้อความ + icon สี** | FE V4 ไม่มีโหมด icon-only สำหรับ `@UI.lineItem` ที่มี criticality · ได้ข้อความจาก fixed value ของ domain พร้อม icon สีจาก `StatusCriticality` — อ่านง่ายกว่าและ accessible กว่า (OQ-16) |

## 5. ค่า default ที่ตกลงไว้ (2026-09-07)

ยังไม่มีใครระบุมา — เลือกไว้แบบนี้ก่อน **แก้ทีหลังได้ถูก ๆ ที่ metadata extension ไม่ต้องรื้ออะไร**

| เรื่อง | ค่าที่ใช้ | annotation |
|---|---|---|
| เรียงลำดับเริ่มต้น | `PostingDate` มากไปน้อย แล้ว `PaymentDocumentNo` | `@UI.presentationVariant.sortOrder` |
| Filter bar | Company Code · Posting Date · Status · Customer Code · Payment Document No. | `@UI.selectionField` |
| Default filter | **ไม่มี** — แสดงทุกสถานะตาม mockup | — (OQ-12) |
| Label | ภาษาอังกฤษทั้งหมดตาม mockup | `@EndUserText.label` |
| Invoice Amount | แสดงคู่ currency ตาม standard | `@Semantics.amount.currencyCode` |
| `RejectReason` | แก้ได้ทุกสถานะ ไม่คุมตาม `status` | — (OQ-13) |
| สิทธิ์ | ทุกคนที่เข้า app ได้เห็นทุก company code | `authorization master ( global )` (OQ-15) |

⚠️ ไม่มี default filter แปลว่า **รายการโตไม่มีเพดาน** ตามเวลาที่ ZARI002 ยิงข้อมูลเข้ามา
ถ้าวันหน้าช้าให้ใส่ default date range ที่ `@UI.selectionVariant` — ไม่ต้องแก้ CDS

## 6. ปุ่ม Submit / Reject — เฟสนี้เปล่า

```abap
" ใน lhc_Item
METHOD submit.
  " ยังไม่มี logic — เฟสนี้เปิดแค่ปุ่มตาม requirement
  " เฟสถัดไป: post FI แล้ว stamp status = S / W / E ที่ header
ENDMETHOD.

METHOD reject.
  " ยังไม่มี logic — เฟสนี้เปิดแค่ปุ่มตาม requirement
  " เฟสถัดไป: stamp status = R ที่ header + เขียน reject_reason
ENDMETHOD.
```

**ต้องไม่ raise error และไม่แก้ข้อมูลใด ๆ** — กดแล้วเงียบเป็นพฤติกรรมที่ถูกต้องของเฟสนี้

⚠️ ตอนใส่ logic จริงจะเจอปัญหาว่า **`status` อยู่ระดับ header แต่แถวที่ผู้ใช้ติ๊กเป็นระดับ item**
เลือก reject แค่ 1 item จาก 3 item ในใบเดียวกันแล้ว `status` จะเป็นอะไร — ต้องตกลงก่อน (OQ-04)
