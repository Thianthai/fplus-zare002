# ZARE002 — Brief สำหรับทีม Fiori: เปิดแก้คอลัมน์ Reject Reason

> ส่งต่อได้ทั้งไฟล์ · ฝั่ง ABAP (RAP) พร้อมแล้วทั้งหมด งานที่เหลืออยู่ในฝั่ง Fiori app เท่านั้น

## 1. เป้าหมาย

ผู้ใช้**แก้ค่าในคอลัมน์ Reject Reason ได้จาก List Report โดยตรง** (inline edit หรือ mass edit
มาตรฐานของ Fiori elements) กด Save แล้วค่าถูกบันทึกลง backend ผ่าน OData
**ไม่มี Object Page และห้ามเพิ่ม** — app นี้เป็นหน้าจอเดียว

หลังแก้ได้แล้ว ปุ่ม **Reject** บน toolbar (ที่มีอยู่แล้ว) จะทำงานครบวงจร:
validate ว่าทุก item ของ payment มีเหตุผล → stamp status ที่ header → ช่องกลายเป็น readonly

## 2. App / service ที่เกี่ยว

| สิ่งที่ | ค่า |
|---|---|
| UI5 app | `com.fplus.fi.ar.zare002` (deploy จาก BAS) |
| Launchpad App Descriptor Item | `ZARE002_UI5R` · semantic object `ZARE002` / action `manage` |
| IAM App | `ZIAM_ZARE002_EXT` |
| OData V4 service binding | `ZUI_ZARE002_O4` · entity set **`Item`** (CDS projection `ZC_ZARE002`) |
| Fiori elements | **V4 · List Report** (ไม่มี Object Page) |
| ฟิลด์ที่ต้องแก้ได้ | **`RejectReason`** เท่านั้น |

## 3. สิ่งที่ backend รับประกันไว้แล้ว — ไม่ต้องทำซ้ำฝั่ง UI

| # | เรื่อง | ความหมายสำหรับ Fiori |
|---|---|---|
| 1 | **BO เป็น draft-enabled** — expose `Edit` `Activate` `Discard` `Resume` `Prepare` ครบ | mass edit / inline edit มาตรฐานของ FE ใช้ draft flow นี้ได้ทันที ไม่ต้องเรียก action เอง · filter "Editing Status" ที่เห็นอยู่มาจากตรงนี้ |
| 2 | **แก้ได้ field เดียวคือ `RejectReason`** — field อื่น `readonly` ระดับ BDEF | PATCH field อื่นจะถูก backend ปฏิเสธ · **อย่าพยายามทำคอลัมน์อื่นให้แก้ได้** |
| 3 | `RejectReason` **กลายเป็น readonly รายแถว** เมื่อ payment ถูก reject แล้ว (`status = R`) — feature control ฝั่ง RAP | FE จะ render ช่องนั้นเป็นอ่านอย่างเดียวเอง ไม่ต้องเขียน logic |
| 4 | **ไม่มี create / delete** ใน service (`internal` เท่านั้น) | ห้ามเพิ่มปุ่ม Create / Delete — จะ error |
| 5 | Etag: `LocalLastChangedAt` (etag master) · `LastChangedAt` (total etag) | optimistic lock ทำงานตาม standard · 2 คนแก้คนละแถวในใบเดียวกันไม่ชน |
| 6 | Action `submitItem` / `rejectItem` — instance action · `InvocationGrouping = ChangeSet` · `rejectItem` คืน `$self` | ปุ่มขึ้น toolbar อยู่แล้ว · หลัง Reject FE จะโหลดแถวใหม่เอง (icon / readonly / ปุ่ม dim) |
| 7 | Message จาก `rejectItem` ผูก **target = `RejectReason` ของแถวที่ขาดเหตุผล** (1 message ต่อแถว) | message popover มาตรฐานของ FE จะไฮไลต์ช่องของแถวนั้น ไม่ต้องทำ custom |
| 8 | default sort `PostingDate` DESC · คอลัมน์ Status เป็น icon อย่างเดียว (`StatusIcon` + criticality) | ทำที่ annotation แล้ว ไม่ต้องทำใน manifest |

## 4. สิ่งที่ต้องแก้ใน app — ยืนยันจากเอกสาร SAPUI5 แล้ว (2026-09-16)

**inline edit ใน List Report เป็น feature มาตรฐานของ Fiori elements V4 ตั้งแต่ SAPUI5 1.136**
app นี้ Min UI5 **1.148.8** → ใช้ได้ · เงื่อนไข: service ต้อง draft-enabled (เป็นอยู่แล้ว)
ที่มา: [Inline Edit — SAPUI5 docs](https://github.com/SAP-docs/sapui5/blob/main/docs/06_SAP_Fiori_Elements/inline-edit-bb56175.md)

### แก้ไฟล์เดียว `manifest.json` — 2 จุด

**จุดที่ 1 — เปิด inline edit** · `sap.ui5.routing.targets.ItemList.options.settings`

```json
"inlineEdit": {
  "enabledFields": ["RejectReason"]
}
```

ระบุ `RejectReason` ตัวเดียว — field อื่น backend readonly อยู่แล้ว แต่ระบุให้ชัดกันโผล่

**จุดที่ 2 — ปิด Object Page** (generator สร้าง `ItemObjectPage` ติดมา requirement ไม่มี)
· `routing.routes` ลบ route `ItemObjectPage` · `routing.targets` ลบ block `ItemObjectPage`
· `targets.ItemList.options.settings` ลบ block `navigation` ที่ชี้ไป `ItemObjectPage`

### พฤติกรรมของ inline edit ที่ต้องรู้

- คลิกช่อง → พิมพ์ → Enter หรือคลิกออก = **save ทันที ไม่มีปุ่ม Save แยก**
- **อัปเดต active version ตรง ๆ ไม่สร้าง draft** (ตามเอกสาร) — RAP รองรับเพราะ feature นี้
  ออกแบบมาคู่กับ RAP draft BO · ⚠️ ข้อความเดิมในไฟล์นี้ที่ว่า "PATCH active จะถูกปฏิเสธ" **ผิด**
  สำหรับ inline edit — ลบออกแล้ว
- ประเมิน editability รายแถว → แถวที่ payment ถูก reject แล้ว (`R`) จะพิมพ์ไม่ได้เอง
- ไม่รองรับ flexible column layout · ไม่รองรับหลาย entity set ใน List Report (เราไม่มีทั้งคู่)

### ทางสำรอง — Mass Edit (ถ้า inline edit ติดอะไรที่คาดไม่ถึง)

`controlConfiguration["@com.sap.vocabularies.UI.v1.LineItem"].tableSettings.enableMassEdit: true`
· ทุกแถวที่ติ๊กได้ค่าเดียวกัน · ⚠️ key นี้ยังไม่ได้ยืนยันจากเอกสารเท่า inline edit

## 5. สิ่งที่ห้ามทำ

- ห้ามเพิ่ม Object Page / navigation ออกจากแถว
- ห้ามเขียน controller / PATCH เอง — ใช้ `inlineEdit` ของ FE เท่านั้น
- ห้ามทำคอลัมน์อื่นนอกจาก `RejectReason` ให้แก้ได้
- ห้ามเพิ่มปุ่ม Create / Delete
- ห้ามเพิ่ม local annotation ทับของ backend

## 6. ทดสอบหลังแก้ — ใช้ payment ที่มีหลาย item (เช่น `1000000101` มี 5 item)

| # | ทำ | ต้องเห็น |
|---|---|---|
| 1 | คลิกช่อง Reject Reason 1 แถว → พิมพ์ → Enter | save ทันที · reload หน้าแล้วค่ายังอยู่ · Data Preview `ztar_i002_item.reject_reason` มีค่า |
| 2 | ติ๊ก 1 แถวของใบที่**ยังไม่ครบ**เหตุผล → Reject | error **1 ข้อความต่อแถวที่ว่าง** ชี้ช่องของแถวนั้น · ยังไม่ reject |
| 3 | กรอกครบทุกแถว → ติ๊ก 1 แถว → Reject | success · **icon แดงทุกแถวของใบ** · ช่องทุกแถว readonly · ติ๊กแถวของใบนี้ → ปุ่ม Submit / Reject dim ทั้งคู่ |
| 4 | Data Preview `ztar_i002_pymt` where `payment_document_no = '1000000101'` | `status = R` |
| 5 | ติ๊ก 2 ใบพร้อมกัน — ใบหนึ่งครบ ใบหนึ่งขาด → Reject | ใบครบถูก reject · ใบขาดได้ error · ไม่ block กัน |

## 7. ติดต่อ

พฤติกรรม backend ทั้งหมดอยู่ใน repo `fplus-zare002` — `docs/05_ui_spec.md` (UI) และ
`docs/01_architecture.md` §3 (BO) · ถ้า OData ตอบไม่ตรงกับที่เขียนไว้ในหน้านี้ แจ้งฝั่ง ABAP
