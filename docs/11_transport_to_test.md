# 11 — Transport ขึ้น TEST (ZBCUTILITY + ZARI002 + ZARI003 + ZARE002)

ตรวจล่าสุด 2026-09-29 · commit ที่ตรวจ: zbcutility `760677d` · zari002 `52ea5e7` · zari003 `1462f6c` · zare002 `6c420da` (ATC ผ่านแล้วตามที่ผู้ใช้แจ้ง)

## 1. ลำดับ

```
ZBCUTILITY  →  ZARI002  →  ZARI003  →  ZARE002
```

| package | ต้องมาก่อนเพราะ |
|---|---|
| `ZBCUTILITY` | `ZCL_UTILITY` ถูกเรียกจาก `ZCL_ZARI002_SFDC_RESULT` และ `ZCL_ZARI003_SFDC_RESULT` |
| `ZARI002` | เจ้าของ table `ZTAR_I002_PYMT` / `ZTAR_I002_ITEM` และ domain `ZD_REQUEST_STATUS` / `ZD_RESPONSE_STATUS` |
| `ZARI003` | ปุ่ม Reject ของ ZARE002 เรียก `ZCL_ZARI003_SFDC_RESULT` และ `ZCL_ZARI003_REJECT_BATCH` |
| `ZARE002` | ใช้ของทั้ง 3 package ข้างบน |

ขนพร้อมกันในรอบเดียวได้ ถ้าแยกรอบต้องตามลำดับนี้ ไม่งั้น activate ไม่ผ่าน

## 2. ผลตรวจก่อนขน

| เรื่อง | ZBCUTILITY | ZARI003 | ZARE002 | ZARI002 |
|---|---|---|---|---|
| object inactive | 0 | 0 | 0 | 0 |
| comment `·` / `→` / emoji | 0 | 0 | 0 | 7 — **คงไว้รอบนี้** (ของเก่า) |
| เลข OQ / phase / ชื่อ API ชั่วคราวใน comment | 0 | 0 | 0 | OQ-05 1 จุด — คงไว้ |
| ABAP Doc ขาด | 0 | 0 | 0 | ~110 จุด ส่วนใหญ่ test class — **คงไว้รอบนี้** |
| เลขเอกสาร test data ใน comment | 0 | 0 | 0 (มีแค่ใน `ZCL_ZARE002_UTIL`) | — |

`"! ค่าชั่วคราว รอแก้เมื่อได้ spec จาก SBPA` ใน `ZCL_ZARI003_REJECT_BATCH` ตั้งใจคงไว้ (OQ-45)

## 3. ⚠️ Object ที่ต้องลบก่อนส่งมอบ (ยังไม่ลบรอบนี้ — ผู้ใช้สั่ง 2026-09-29)

✅ **`main` ของทั้ง 3 ตัว comment ปิดแล้ว** (zare002 `7a0cb96` · zari002 `e096e9e`) — กด F9 แล้วแค่พิมพ์ว่าไม่มีอะไรเปิดใช้ ขึ้น TEST ได้อย่างปลอดภัย

| Object | Package | หมายเหตุ |
|---|---|---|
| `ZCL_ZARE002_UTIL` | ZARE002 | `main` เคยมี `UPDATE` ล้าง clearing ของ 2 ใบ — comment แล้ว `7a0cb96` |
| `ZCL_ZARI002_SPIKE` | ZARI002 | `purge_all` ลบทั้ง 2 table แบบไม่มี `WHERE` — `main` ไม่เรียกแล้ว `e096e9e` |
| `ZCL_ZARI002_UTIL` | ZARI002 | `main` เคยลบ payment ตามเลขเอกสาร hardcode 5 ใบ — comment แล้ว `e096e9e` |

ไม่มี object อื่นเรียกใช้ 3 ตัวนี้ ลบได้ทันทีเมื่อถึงเวลา

## 4. Config ที่ไม่ติดไปกับ transport — ต้องสร้างบน TEST

| Scenario | ทิศทาง | Arrangement ใน DEV | Communication System | Auth |
|---|---|---|---|---|
| `ZCS_SFDC_TOKEN` | ขาออก → Salesforce | `ZCA_SFDC_TOKEN` | SFDC ของ TEST | Basic (client id / secret) |
| `ZCS_INCOMING_PYMT` | ขาเข้า SBPA → ZARI002 | ของ ZARI002 | SBPA ของ TEST | Basic |
| `ZCS_CLEARING_ITEM` | ขาเข้า BOT → `ZAPI_ZARE002_O4` | `ZCA_CLEARING_ITEM` | SBPA ของ TEST | Basic |
| `ZCS_CLEARING_RESULT` | ขาเข้า BOT → `ZARI003_CLEARING` | `ZCA_CLEARING_RESULT` | SBPA ของ TEST | Basic |
| `ZCS_REJECT_BATCH` | ขาออก → SBPA | `ZCA_REJECT_BATCH` | SBPA ของ TEST | OAuth 2.0 client credentials (token endpoint XSUAA + client id / secret) |
| `ZCS_REJECT_ITEM` | ขาเข้า SBPA → `ZAPI_ZARI003_O4` (Phase 8F · ยังไม่ได้ขึ้น TEST รอบแรก) | `ZCA_REJECT_ITEM` | SBPA ของ TEST | Basic |

อื่น ๆ: business role ที่รวม `ZBC_ZARE002` และ `ZBC_ZARI002` · URL ของ inbound ทั้ง 3 ตัวบน TEST ต้องแจ้ง SBPA / ทีม BOT ใหม่ (host เปลี่ยน)

## 5. ค่าที่ hardcode ใน `ZCL_ZARE002_JOURNAL_ENTRY` — ฟังก์ชันนอลต้องยืนยันว่ามีบน TEST

| ค่า | ใช้ทำอะไร |
|---|---|
| G/L `0011011211` · house bank `SCB01` / `SA001` | บรรทัด bank |
| G/L `0054030012` · cost center `2002010000` · tax code `WP` · business place `0000` | บรรทัด bank charge |
| tax account key `VST` · condition `MWVS` | tax item ของ bank charge |
| G/L `0059090001` | บรรทัด rounding |
| document type `DS` · business transaction `RFPI` | header ของ JE |

## 6. พฤติกรรมที่รู้อยู่แล้วบน TEST

- **Reject**: สำเร็จตามปกติ แต่ `reject_message` จะเป็น error 011 (path ของ SBPA ยังเป็น draft) หรือ 012 (ยังไม่ผูก `ZCA_REJECT_BATCH`) — ไม่กระทบอย่างอื่น (OQ-45)
- **Reject Reason ค้างเมื่อ SFDC ปฏิเสธ** — ตั้งใจ (OQ-36 hold)
- ~~status E ไม่มีใครเขียน~~ — ทำแล้วใน 8H (ยังไม่ได้ขึ้น TEST)

## 7. ของที่เพิ่มหลังขน TEST รอบแรก (ต้องขนรอบหน้า)

| Phase | package | object |
|---|---|---|
| 8F | ZARI003 | `ZI_ZARI003_REJECT_ITEM` · `ZAPI_ZARI003` · `ZAPI_ZARI003_O4` · `ZCS_REJECT_ITEM` + arrangement `ZCA_REJECT_ITEM` บน TEST |
| 8G | ZARI002 | `ZD_SUBMIT_STATUS` · `ZD_CLEARING_STATUS` · `ZE_SUBMIT_STATUS` · `ZE_CLEARING_STATUS` · `ZD_RESPONSE_STATUS` (แก้) |
| 8G | ZARE002 | `ZI_ZARE002_SUBMIT_STATUS_VH` · `ZI_ZARE002_CLEARING_STATUS_VH` · `ZI_ZARE002_SFDC_STATUS_VH` · `ZI_ZARE002_PYMT` · `ZC_ZARE002` + ddlx |

| 8H | ZARI002 | `ZCL_ZARI002_PROCESSOR` (duplicate นับ E) |
| 8H | ZARE002 | `ZCL_ZARE002_SUBMIT` (stamp E) · `ZI_ZARE002_PYMT` (label Payment Amount (Net)) |

| เวลา local | ZBCUTILITY | `ZCL_UTILITY=>get_local_datetime` (`7cf83d5` `c9832e1`) — เรียก `ZCL_PARAM` / `ZCX_PARAM` / `ZTBC_PARAM` ของ package **`ZBCPARAM`** (ผู้ใช้ดูแลเอง 2026-10-05) · parameter `BC/PARAM/TIMEZONE/LOCAL` บน TEST ไม่ตั้งก็ใช้ `UTC+7` สำรอง |
| เวลา local | ZARE002 | `ZBP_R_ZARE002` (`eb5470c`) |
| เวลา local | ZARI003 | `ZCL_ZARI003_SFDC_RESULT` (`a276fb0`) |

ลำดับ: **ZBCPARAM → ZBCUTILITY** → ZARI002 → ZARI003 → ZARE002
