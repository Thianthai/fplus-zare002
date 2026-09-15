# ZARE002 — ทะเบียนข้อสงสัย

รวมทุกอย่างที่ยัง**ไม่เคลียร์** ไว้ที่เดียว — **รีวิวทุกครั้งที่จบ phase**

> เจอจุดไหนไม่ชัดให้ **note ไว้ที่นี่แล้วเดินต่อ** อย่าหยุดรอ

สถานะ: `⬜` เปิดอยู่ · `🟨` มีคำตอบชั่วคราวแล้ว เดินต่อได้ · `✅` ปิด

| # | เรื่อง | เจ้าของคำตอบ | ยกมาจาก | บล็อกอะไร | สถานะ |
|---|--------|-------------|---------|-----------|--------|
| OQ-01 | **1 row = 1 item หรือ 1 payment** — requirement บอก line item level แต่ mockup แสดง IF250500002 ที่มี "No. of Items = 2" เป็นแถวเดียว · ถ้าเป็น item level จริง ใบนั้นต้องได้ 2 แถวที่ header ซ้ำกัน | ผู้ใช้ / business | Phase 0 | ไม่บล็อก — เดินตาม requirement (item level) ไปก่อน · ถ้าผิดต้องรื้อ root entity ใหม่หมด | 🟨 |
| OQ-02 | **Payment Document No. ใน mockup เป็น link** แต่ไม่มี Object Page → จะให้ link ไปไหน หรือเป็น text ธรรมดา | ผู้ใช้ | Phase 0 | ไม่บล็อก — ทำเป็น text ไปก่อน | 🟨 |
| OQ-03 | mockup ทำปุ่ม Submit เขียว / Reject แดง — Fiori elements ไม่ให้กำหนดสีปุ่ม action เอง รับได้ไหม | ผู้ใช้ | Phase 0 | ไม่บล็อก | 🟨 |
| OQ-04 | **`status` อยู่ระดับ header แต่ผู้ใช้ติ๊กระดับ item** — **ตอบแล้ว 2026-09-15**: เลือก item ใดก็ตาม = เลือกทั้ง payment · handler ต้อง distinct `PaymentUuid` จาก keys แล้วทำงานกับ item ทุกตัวของ payment เหล่านั้น · **ทำที่ RAP ล้วน ไม่ต้องแก้ Fiori** · ปุ่มตั้ง `invocationGrouping: #CHANGE_SET` ไว้แล้วตั้งแต่ Phase 5 เพื่อให้ keys ทั้งหมดมาถึง handler รอบเดียว ไม่ post ใบเดิมซ้ำ | — | Phase 0 | ไม่บล็อก — เป็น spec ของเฟส logic แล้ว | 🟨 |
| OQ-05 | `ZD_REQUEST_STATUS` มี 4 ค่า (`N` `C` `R` `E`) แต่ mockup มี 3 icon — `R` กับ `E` ใช้สีแดงเหมือนกันได้ไหม หรือต้องแยก | ผู้ใช้ | Phase 3 | ไม่บล็อก — ใช้สีแดงทั้งคู่ไปก่อน | 🟨 |
| OQ-09 | **สิทธิ์อ่าน `I_BusinessPartner` ของ business role ที่จะใช้จริง** — association ใน CDS ใช้ `WITH PRIVILEGED ACCESS` ไม่ได้ view ถูกอ่านด้วยสิทธิ์ผู้ใช้เสมอ | ผู้ใช้ | Phase 1 | ไม่บล็อก — path expression เป็น LEFT OUTER JOIN แถวไม่หาย แต่ **Customer Name จะว่าง** ถ้าไม่มีสิทธิ์ | ⬜ |
| OQ-10 | ใครเป็นผู้ใช้ app นี้ / business role ที่มีอยู่แล้วตัวไหนที่จะเอา catalog ไปแปะ | ผู้ใช้ | Phase 6 | บล็อก Phase 6.5 | ⬜ |
| OQ-11 | object type ของ IAM App / Business Catalog บน tenant นี้ — ยังไม่เคยทำใน RICEFW ก่อนหน้า (ZARI002 เป็น headless API) | ผู้ใช้ (ADT) | Phase 6 | บล็อก Phase 6.3–6.4 | ⬜ |
| OQ-12 | รายงานควร filter เฉพาะ `status = 'N'` โดย default ไหม หรือแสดงทุกสถานะ · mockup แสดงทั้ง 🕐 ✅ ❌ = แสดงทุกสถานะ | ผู้ใช้ | Phase 3 | ไม่บล็อก — แสดงทุกสถานะตาม mockup ไปก่อน | 🟨 |
| OQ-13 | **`reject_reason` แก้ได้ทุกสถานะหรือเฉพาะ `N`** — ใบที่ post ไปแล้ว (`C`) ควรแก้เหตุผลได้อีกไหม | ผู้ใช้ / business | Phase 3 | ไม่บล็อก — เปิดให้แก้ได้หมดไปก่อน · ถ้าต้องคุมใช้ `field ( features : instance )` เพิ่มทีหลังได้ | ⬜ |
| OQ-14 | ต้อง log ไหมว่าใครแก้ `reject_reason` เป็นอะไรเมื่อไหร่ — ตอนนี้มีแค่ `last_changed_by` ที่เก็บค่าล่าสุด ไม่มีประวัติ | ผู้ใช้ / audit | Phase 3 | ไม่บล็อก — ถ้าต้องการให้ทำเป็น append-only log table แยก **ไม่ใช่** ย้ายที่เก็บค่าปัจจุบัน (ดู `01_architecture.md` §2) | ⬜ |
| OQ-15 | **สิทธิ์ระดับ company code — ผู้ใช้ควรเห็นทุก CC หรือเฉพาะของตัวเอง** · mockup มีทั้ง `1000` และ `2000` ปนกัน · **ยังไม่รู้คำตอบ ตกลงเดิน `authorization master ( global )` ไปก่อน (2026-09-07)** | ผู้ใช้ / business | Phase 0 | ไม่บล็อกตอนนี้ — แต่ถ้าคำตอบเปลี่ยนเป็น "แยกตาม CC" ต้องรื้อ BDEF เป็น `( instance )` + `get_instance_authorizations` + restriction type/field ที่ IAM App และ business role · **ยิ่งตอบช้ายิ่งรื้อเยอะ** | ⬜ |

## ที่ปิดไปแล้ว

| # | เรื่อง | ข้อสรุป | ปิดเมื่อ |
|---|--------|---------|---------|
| OQ-00 | **แยก table `ZTAR_E002_EDIT` เก็บ `reject_reason` หรือใช้จาก `ZTAR_I002_ITEM`** | **ใช้ `ZTAR_I002_ITEM.REJECT_REASON` · ยกเลิก `ZTAR_E002_EDIT`** — field มีอยู่แล้วและ ZARI002 ออกแบบไว้ให้ ZARE002 เขียนตั้งแต่แรก · managed RAP BO เขียนได้ table เดียว การแยก table บังคับให้ต้องใช้ unmanaged save เพื่อ field เดียว · เหตุผลเต็มใน `01_architecture.md` §2 | 2026-09-07 |
| OQ-06 | **inline edit ใน List Report ต้อง draft-enabled จริงหรือไม่** | **คำถามผิดตั้งแต่ต้น** — ทดสอบจริง 2026-09-07 แล้ว **แก้ในตารางไม่ได้ทั้ง draft และ non-draft** · List Report ที่ไม่มี Object Page ไม่มี edit flow ในตัวเอง และ inline / mass edit เป็น feature ระดับ **manifest ของ Fiori app** ซึ่ง Preview ของ service binding ใน ADT ตั้งไม่ได้ · แก้ด้วย **action ที่มี parameter** ให้ FE generate dialog แทน → draft ถูกถอดออก | 2026-09-07 |
| OQ-08 | **ขอเพิ่ม `last_changed_at` ที่ `ZTAR_I002_ITEM`** | **ทำแล้ว** — เพิ่ม `abp_lastchange_tstmpl` ต่อท้าย `last_changed_by` · ZARI002 ไม่ต้องแก้โค้ด · push ขึ้น `fplus-zari002` แล้ว (commit `0762ada`) · ปลดล็อกให้ `total etag LastChangedAt` ประกาศได้ | 2026-09-07 |
| OQ-16 | **Status แสดงเป็น icon เปล่าตาม mockup ได้ไหม** | **ได้ — แยก element** (2026-09-15): `StatusIcon` = `''` ใส่ `@UI.lineItem` + `criticality` → FE วาดแต่ icon · `Status` ตัวจริงถอดออกจาก lineItem เหลือ `@UI.selectionField` เพื่อให้ filter ยังใช้ fixed value ของ domain ได้ · **ไม่เขียนทับ `Status` ด้วย `''`** เพราะ filter จะไม่มีวันเจออะไร | 2026-09-15 |
| OQ-07 | **ชื่อลูกค้าดึงจาก view ไหน** — mockup มี Customer Name แต่ไม่มีใน table | **`I_BusinessPartner`** · `BusinessPartner = customer_code` เทียบตรง ๆ ได้เพราะ ZARI002 แปลง `ALPHA = IN` ก่อน insert อยู่แล้ว · ชื่อลูกค้า **ต่อเอง** จาก `OrganizationBPName1..4` คั่นด้วยช่องว่าง ผ่าน view `ZI_ZARE002_BP` ไม่ใช้ `BusinessPartnerFullName` | 2026-09-07 |

## วิธีใช้

- เจอข้อสงสัยใหม่ระหว่างทำ → **เพิ่มแถวที่นี่ทันที** อย่าเก็บไว้ในหัวหรือใน commit message
- ตอนจบ phase → ไล่ทั้งตาราง ถามเจ้าของคำตอบ แล้วอัปเดตสถานะ
