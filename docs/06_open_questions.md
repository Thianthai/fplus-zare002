# ZARE002 — ทะเบียนข้อสงสัย

รวมทุกอย่างที่ยัง**ไม่เคลียร์** ไว้ที่เดียว — **รีวิวทุกครั้งที่จบ phase**

> เจอจุดไหนไม่ชัดให้ **note ไว้ที่นี่แล้วเดินต่อ** อย่าหยุดรอ

สถานะ: `⬜` เปิดอยู่ · `🟨` มีคำตอบชั่วคราวแล้ว เดินต่อได้ · `✅` ปิด

| # | เรื่อง | เจ้าของคำตอบ | ยกมาจาก | บล็อกอะไร | สถานะ |
|---|--------|-------------|---------|-----------|--------|
| OQ-01 | **1 row = 1 item หรือ 1 payment** — requirement บอก line item level แต่ mockup แสดง IF250500002 ที่มี "No. of Items = 2" เป็นแถวเดียว · ถ้าเป็น item level จริง ใบนั้นต้องได้ 2 แถวที่ header ซ้ำกัน | ผู้ใช้ / business | Phase 0 | ไม่บล็อก — เดินตาม requirement (item level) ไปก่อน · ถ้าผิดต้องรื้อ root entity ใหม่หมด | 🟨 |
| OQ-02 | **Payment Document No. ใน mockup เป็น link** แต่ไม่มี Object Page → จะให้ link ไปไหน หรือเป็น text ธรรมดา | ผู้ใช้ | Phase 0 | ไม่บล็อก — ทำเป็น text ไปก่อน | 🟨 |
| OQ-03 | mockup ทำปุ่ม Submit เขียว / Reject แดง — Fiori elements ไม่ให้กำหนดสีปุ่ม action เอง รับได้ไหม | ผู้ใช้ | Phase 0 | ไม่บล็อก | 🟨 |
| OQ-04 | **`status` อยู่ระดับ header แต่ `reject_reason` อยู่ระดับ item** — ผู้ใช้ติ๊ก reject 1 item จาก 3 item ในใบเดียวกัน `status` ของใบนั้นจะเป็นอะไร | ผู้ใช้ / FI | Phase 0 | **ไม่บล็อกเฟสนี้** (ปุ่มยังเปล่า) แต่ **บล็อกเฟสถัดไปเต็ม ๆ** ต้องตอบก่อนเขียน logic | ⬜ |
| OQ-05 | `ZD_REQUEST_STATUS` มี 4 ค่า (`N` `C` `R` `E`) แต่ mockup มี 3 icon — `R` กับ `E` ใช้สีแดงเหมือนกันได้ไหม หรือต้องแยก | ผู้ใช้ | Phase 4 | ไม่บล็อก — ใช้สีแดงทั้งคู่ไปก่อน | 🟨 |
| OQ-06 | **inline edit ใน List Report ต้อง draft-enabled จริงหรือไม่** — ถ้าทำ non-draft ได้จะประหยัด draft table + ไม่ต้องแก้ table ของ ZARI002 | Claude + ผู้ใช้ (spike) | Phase 0 | **บล็อก Phase 1 ทั้งก้อน** — ต้องรู้ก่อนตัดสินใจว่าจะขอแก้ `ztar_i002_item` ไหม | ⬜ |
| OQ-08 | **ขอเพิ่ม `last_changed_at` ที่ `ZTAR_I002_ITEM`** — table เป็นของ package `ZARI002` และเอกสารเขาเขียนว่า "ห้ามแก้ให้เท่ากัน" (แต่เหตุผลคือ "BO นั้นไม่มี draft" ซึ่งเปลี่ยนไปแล้ว) | ผู้ใช้ / เจ้าของ ZARI002 | Phase 1 | **บล็อก Phase 3** ถ้า OQ-06 ตอบว่าต้องใช้ draft | ⬜ |
| OQ-09 | **สิทธิ์อ่าน `I_BusinessPartner` ของ business role ที่จะใช้จริง** — association ใน CDS ใช้ `WITH PRIVILEGED ACCESS` ไม่ได้ view ถูกอ่านด้วยสิทธิ์ผู้ใช้เสมอ | ผู้ใช้ | Phase 2 | ไม่บล็อก — path expression เป็น LEFT OUTER JOIN แถวไม่หาย แต่ **Customer Name จะว่าง** ถ้าไม่มีสิทธิ์ | ⬜ |
| OQ-10 | ใครเป็นผู้ใช้ app นี้ / business role ที่มีอยู่แล้วตัวไหนที่จะเอา catalog ไปแปะ | ผู้ใช้ | Phase 6 | บล็อก Phase 6.5 | ⬜ |
| OQ-11 | object type ของ IAM App / Business Catalog บน tenant นี้ — ยังไม่เคยทำใน RICEFW ก่อนหน้า (ZARI002 เป็น headless API) | ผู้ใช้ (ADT) | Phase 6 | บล็อก Phase 6.3–6.4 | ⬜ |
| OQ-12 | รายงานควร filter เฉพาะ `status = 'N'` โดย default ไหม หรือแสดงทุกสถานะ · mockup แสดงทั้ง 🕐 ✅ ❌ = แสดงทุกสถานะ | ผู้ใช้ | Phase 4 | ไม่บล็อก — แสดงทุกสถานะตาม mockup ไปก่อน | 🟨 |
| OQ-13 | **`reject_reason` แก้ได้ทุกสถานะหรือเฉพาะ `N`** — ใบที่ post ไปแล้ว (`C`) ควรแก้เหตุผลได้อีกไหม | ผู้ใช้ / business | Phase 4 | ไม่บล็อก — เปิดให้แก้ได้หมดไปก่อน · ถ้าต้องคุมใช้ `field ( features : instance )` เพิ่มทีหลังได้ | ⬜ |
| OQ-14 | ต้อง log ไหมว่าใครแก้ `reject_reason` เป็นอะไรเมื่อไหร่ — ตอนนี้มีแค่ `last_changed_by` ที่เก็บค่าล่าสุด ไม่มีประวัติ | ผู้ใช้ / audit | Phase 4 | ไม่บล็อก — ถ้าต้องการให้ทำเป็น append-only log table แยก **ไม่ใช่** ย้ายที่เก็บค่าปัจจุบัน (ดู `01_architecture.md` §2) | ⬜ |

## ที่ปิดไปแล้ว

| # | เรื่อง | ข้อสรุป | ปิดเมื่อ |
|---|--------|---------|---------|
| OQ-00 | **แยก table `ZTAR_E002_EDIT` เก็บ `reject_reason` หรือใช้จาก `ZTAR_I002_ITEM`** | **ใช้ `ZTAR_I002_ITEM.REJECT_REASON` · ยกเลิก `ZTAR_E002_EDIT`** — field มีอยู่แล้วและ ZARI002 ออกแบบไว้ให้ ZARE002 เขียนตั้งแต่แรก · managed RAP BO เขียนได้ table เดียว การแยก table บังคับให้ต้องใช้ unmanaged save เพื่อ field เดียว · เหตุผลเต็มใน `01_architecture.md` §2 | 2026-09-07 |
| OQ-07 | **ชื่อลูกค้าดึงจาก view ไหน** — mockup มี Customer Name แต่ไม่มีใน table | **`I_BusinessPartner`** · `BusinessPartner = customer_code` เทียบตรง ๆ ได้เพราะ ZARI002 แปลง `ALPHA = IN` ก่อน insert อยู่แล้ว · field ชื่อใช้ `BusinessPartnerFullName` (ยืนยันด้วย Data Preview ที่ Phase 2.4) | 2026-09-07 |

## วิธีใช้

- เจอข้อสงสัยใหม่ระหว่างทำ → **เพิ่มแถวที่นี่ทันที** อย่าเก็บไว้ในหัวหรือใน commit message
- ตอนจบ phase → ไล่ทั้งตาราง ถามเจ้าของคำตอบ แล้วอัปเดตสถานะ
