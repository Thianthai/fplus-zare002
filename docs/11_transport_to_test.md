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

ค่าอ้างอิงจากหน้าจอจริงของ Customizing tenant IA5/100 (ผู้ใช้ส่งมา 2026-11-09) · TEST ตั้งรูปแบบเดียวกัน เปลี่ยนแค่ค่าของ TEST
· secret / client id / API key ไม่บันทึกในเอกสาร

### 4.1 Communication System

| System (DEV) | Host | Port | Outbound OAuth 2.0 → Token Endpoint | Inbound user | Outbound user |
|---|---|---|---|---|---|
| `SBPA_DEV` | `spa-api-gateway-bpi-ap-prod.cfapps.ap11.hana.ondemand.com` | 443 | `f-plus-sbpa.authentication.ap11.hana.ondemand.com/oauth/token` | User ID and Password · `SBPA_DEV` (SBPA / BOT ใช้เรียกทุก scenario ขาเข้า) | **OAuth 2.0 (Basic)** · client id ของ XSUAA (`sb-…\|xsuaa!…`) |
| `SFDC_DEV` | `one-two-trading--dev.sandbox.my.salesforce.com` | 443 | `one-two-trading--dev.sandbox.my.salesforce.com/services/oauth2/token` — ใช้กับแถว Form Field ของ ARI001 เท่านั้น | `SFDC_DEV` — ของ ZSDE001 ไม่เกี่ยวกับงานนี้ | **User ID and Password** = client id / secret ของ connected app (ที่ `ZCA_SFDC_TOKEN` ใช้) · แถว OAuth 2.0 (Form Field) เป็นของ ARI001 |

ไม่เกี่ยวกับ 3 WRICEF นี้: `ABAP_DEV` (เรียก standard API ของตัวเอง) · `FPLUS_DEV` (inbound only ของ IT FPLUS)

SBPA TEST (2026-11-09): ข้อมูลจากทีม SBPA ตรงกับ `SBPA_DEV` ทั้ง host · token endpoint · client id
→ ต่างแค่ **`TRIGGER_ID`** (`0773939a-5de8-4373-973e-a76485ec8e9f`) · client secret / API key เทียบไม่ได้ (ช่อง secure) ให้กรอกตามที่ทีม SBPA ส่งมา

### 4.1b Communication User (แอป Maintain Communication User)

| User (DEV) | Description | ใช้ใน system | ใช้ใน arrangement ของ 3 WRICEF นี้ |
|---|---|---|---|
| `SBPA_DEV` | Interface User for SAP Build Process Automation | `SBPA_DEV` (inbound) | `ZCA_INCOMING_PYMT` · `ZCA_CLEARING_ITEM` · `ZCA_CLEARING_RESULT` · `ZCA_REJECT_ITEM` — ครบ 4 ตัวขาเข้า |

- `ZCA_REJECT_BATCH` / `ZCA_SFDC_TOKEN` เป็นขาออก ไม่ใช้ communication user (ใช้ outbound user ใน system แทน)
- ไม่เกี่ยวกับงานนี้: `SFDC_DEV` (ใช้แค่ `ZCA_CUSTOMER_IN` ของ ZSDE001) · `ABAP_DEV` · `FPLUS_DEV`
- บน TEST: สร้าง communication user ของ SBPA ใหม่ 1 ตัว ผูกเข้า system SBPA ของ TEST แล้วใช้ใน 4 arrangement ขาเข้า · แจ้ง user / password ให้ทีม SBPA / BOT

**สถานะบน TEST (tenant `my443707` IZJ/100 · เทียบหน้าจอ 2026-11-09)**

| รายการ | TEST | ผล |
|---|---|---|
| Communication User | `SBPA_TEST` | ✅ มีแล้ว |
| Communication System `SBPA_TEST` | host · port 443 · Token Endpoint · outbound OAuth 2.0 (Basic) client id เหมือน `SBPA_DEV` ทุกตัว · inbound `SBPA_TEST` | ✅ ตรง |
| Communication System `SFDC_TEST` | host `one-two-trading--sit.sandbox.my.salesforce.com` : 443 · Token Endpoint `…--sit…/services/oauth2/token` · outbound **User ID and Password** (client id ของ org SIT) · ไม่มี inbound user / แถว Form Field (เป็นของ ZSDE001 / ARI001 ไม่ใช่งานนี้) | ✅ ตรงตามที่งานนี้ต้องใช้ |
| `ZCA_INCOMING_PYMT` · `ZCA_CLEARING_ITEM` · `ZCA_CLEARING_RESULT` | ผูก `SBPA_TEST` | ✅ มีแล้ว · `$metadata` ของ `ZAPI_ZARE002` บน TEST (login `SBPA_TEST`) มี `PartialPayments` + `_PartialPayments` แล้ว = 8L ขึ้นครบ ไม่ต้อง publish ใหม่ (2026-11-09) · GET `zari003_clearing` บน TEST ตอบ JSON ตัวอย่างได้ (2026-11-09) |
| `ZCA_REJECT_BATCH` | ผูก `SBPA_TEST` · OAuth 2.0 (Basic) client id เดียวกับ DEV · Path `/` · Service URL `https://spa-api-gateway-bpi-ap-prod.cfapps.ap11.hana.ondemand.com:443/` | ✅ ตรง · กรอก `API_KEY` + `TRIGGER_ID` แล้ว (2026-11-09) · `TRIGGER_ID` = `0773939a-5de8-4373-973e-a76485ec8e9f` ยังเป็นตัวพิมพ์เล็กหลัง save (domain case-sensitive ขึ้น TEST แล้ว) · รอยืนยันด้วย Reject จริง (`reject_message` ว่าง = ยิงสำเร็จ) · arrangement ที่ระบบสร้างให้ตอน import ไม่พก property มา ต้องกรอกเองทุก tenant |
| `ZCA_SFDC_TOKEN` | ผูก `SFDC_TEST` · User ID and Password (client id ของ org SIT) · Path `/` · Service URL `https://one-two-trading--sit.sandbox.my.salesforce.com:443/` | ✅ ตรง · Check Connection ผ่าน (2026-11-09) = เชื่อมต่อ host ได้ · ยังไม่พิสูจน์ client secret (ping ที่ `/` ไม่ขอ token) → ยืนยันด้วย Submit / Reject จริงที่ส่งผลถึง SFDC |
| `ZCA_REJECT_ITEM` | ผูก `SBPA_TEST` + inbound user `SBPA_TEST` · `ZAPI_ZARI003_O4` | ✅ สร้างแล้ว (2026-11-09) · `$metadata` TEST = Customizing ทุก byte |

`SBPA_TEST` outbound OAuth 2.0 (Basic): ใส่ client secret ของ TEST แล้ว (2026-11-09)
· XSUAA ของ SBPA ใช้ client id เดียวกันทุก environment แต่ **secret ต่างกันตาม service key** → ห้าม copy secret ของ DEV
· API key ก็ต่างกันตาม environment เช่นกัน

**สิ่งที่ยังเหลือบน TEST (2026-11-09)**

| # | งาน | ใคร |
|---|---|---|
| 1 | ~~ขน 8F แล้วสร้าง `ZCA_REJECT_ITEM`~~ ✅ 2026-11-09 | ผู้ใช้ |
| 2 | Business role · launchpad · assign user — ส่งต่อฟังก์ชันนอลสร้างเอง (§4.3) | ฟังก์ชันนอล |
| 3 | แจ้งทีม SBPA / BOT (§4.4) | ผู้ใช้ |
| 4 | ยืนยัน master data ที่ code hardcode มีบน TEST (§4.5) | ฟังก์ชันนอล |
| 5 | Reject 1 ใบเพื่อยืนยัน `ZCA_REJECT_BATCH` + `SBPA_TEST` · Submit / Reject ที่ส่งถึง SFDC เพื่อยืนยัน `ZCA_SFDC_TOKEN` | ผู้ใช้ |

Endpoint ขาเข้าบน TEST (host `https://my443707-api.s4hana.cloud.sap`)

| Arrangement | ใครเรียก | Path |
|---|---|---|
| `ZCA_INCOMING_PYMT` | SBPA | `/sap/bc/http/sap/zari002_incoming_pymt` |
| `ZCA_CLEARING_ITEM` | BOT | `/sap/opu/odata4/sap/zapi_zare002_o4/srvd_a2x/sap/zapi_zare002/0001/ClearingItems` |
| `ZCA_CLEARING_RESULT` | BOT | `/sap/bc/http/sap/zari003_clearing` |
| `ZCA_REJECT_ITEM` | SBPA | `/sap/opu/odata4/sap/zapi_zari003_o4/srvd_a2x/sap/zapi_zari003/0001/RejectedItems` |

### 4.3 ส่งต่อฟังก์ชันนอล — Business Role บน TEST

| Business Catalog | App ที่ได้ |
|---|---|
| `ZBC_ZARE002` | Automatic Incoming Payments (รวมปุ่ม Submit / Reject) |
| `ZBC_ZARI002` | app ดู log ของ Incoming Payments |

ขั้นตอน (Maintain Business Roles)
1. สร้าง role ใหม่ หรือเพิ่มเข้า role ของทีม AR ที่มีอยู่
2. Assigned Business Catalogs: เพิ่ม 2 catalog ข้างบน
3. Maintain Restrictions: Read / Write / Value Help = **Unrestricted** (ยังไม่มีสิทธิ์ระดับ company code — OQ-15 hold)
4. Launchpad Space: สร้าง space + page ใส่ tile ของ 2 app
5. Assigned Business Users: ใส่ user ทดสอบ แล้วให้ log off / login ใหม่

ปุ่ม Submit post JE ด้วยสิทธิ์ของ user ที่กด → user ต้องมีสิทธิ์ post เอกสาร FI/AR ด้วย ให้เทียบ catalog มาตรฐานกับ role ที่ใช้ทดสอบบน DEV

### 4.4 แจ้งทีม SBPA / BOT

| รายการ | ค่า |
|---|---|
| Host | `https://my443707-api.s4hana.cloud.sap` |
| Auth | Basic · user **`SBPA_TEST`** · password ส่งแยกทางช่องทางปลอดภัย |
| Endpoint | ตาราง endpoint ขาเข้าข้างบน — path เหมือน DEV ทุกตัว เปลี่ยนแค่ host + user |
| Request / response body | ไม่เปลี่ยนจาก DEV — ดู `10_api_contract.md` |
| BOT ดึงคิว | ใช้ `ClearingItems?$expand=_PartialPayments` (ตรวจแล้วว่ามีบน TEST) |
| BOT ส่งผล clearing | ส่งเฉพาะใบ final · ห้ามส่ง JE ของใบ partial แยก |
| SAP → SBPA | SAP เรียก trigger `0773939a-5de8-4373-973e-a76485ec8e9f` (TEST) พร้อม `RejectBatchID` ทุกครั้งที่ Reject · ทีม SBPA ต้อง deploy trigger นี้ให้พร้อมรับ |

### 4.5 ส่งต่อฟังก์ชันนอล — master data ที่ code hardcode (`ZCL_ZARE002_JOURNAL_ENTRY`)

| กลุ่ม | ค่า | ใช้ทำอะไร |
|---|---|---|
| Document | doc type `DS` · business transaction `RFPI` | header ของ JE |
| Bank | G/L `0011011211` · house bank `SCB01` · account ID `SA001` | บรรทัดเงินเข้าธนาคาร |
| Bank charge | G/L `0054030012` · cost center `2002010000` | บรรทัดค่าธรรมเนียม |
| Tax ของ bank charge | tax code `WP` · business place `0000` · account key `VST` · condition `MWVS` | tax item |
| Rounding | G/L `0059090001` | เศษสตางค์ |
| Advance payment | special G/L indicator `Z` | ยอดรับล่วงหน้า |
| One-time customer | รหัสลูกค้าขึ้นต้น `OT` | แยกการ post ลูกค้าจร |

ข้อมูลทดสอบที่ต้องมีบน TEST ด้วย: customer / invoice / billing document ที่ SBPA จะส่งมา · company code ทดสอบ (DEV ใช้ `2000`)
· Salesforce org SIT ต้องมี custom object / field ชุดเดียวกับ dev org (`BST_SAP_Status__c` · `Integration_Log__c`) — ให้ทีม Salesforce ยืนยัน

### 4.2 Communication Arrangement

| Arrangement | Scenario | System | ทิศทาง | ตั้งเพิ่ม |
|---|---|---|---|---|
| `ZCA_INCOMING_PYMT` | `ZCS_INCOMING_PYMT` | `SBPA_*` | ขาเข้า SBPA → ZARI002 | inbound user |
| `ZCA_CLEARING_ITEM` | `ZCS_CLEARING_ITEM` | `SBPA_*` | ขาเข้า BOT → `ZAPI_ZARE002_O4` | inbound user |
| `ZCA_CLEARING_RESULT` | `ZCS_CLEARING_RESULT` | `SBPA_*` | ขาเข้า BOT → `ZARI003_CLEARING` | inbound user |
| `ZCA_REJECT_ITEM` | `ZCS_REJECT_ITEM` | `SBPA_*` | ขาเข้า SBPA → `ZAPI_ZARI003_O4` | inbound user |
| `ZCA_REJECT_BATCH` | `ZCS_REJECT_BATCH` | `SBPA_*` | ขาออก → SBPA trigger | outbound user OAuth 2.0 (Basic) · Path `/` · `API_KEY` · `TRIGGER_ID` (ตัวพิมพ์เล็กต้องคงอยู่) |
| `ZCA_SFDC_TOKEN` | `ZCS_SFDC_TOKEN` | `SFDC_*` | ขาออก → Salesforce | outbound user User ID and Password · **Path `/`** (scenario มี default `/services/oauth2/token` ต้องแก้ตอนสร้าง ไม่งั้น 404) · Check Connection |

อื่น ๆ: business role ที่รวม `ZBC_ZARE002` และ `ZBC_ZARI002` + launchpad space · URL ของ inbound ทั้ง 4 ตัวบน TEST และ inbound user ต้องแจ้ง SBPA / ทีม BOT ใหม่ (host เปลี่ยน)

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

| 8I | ZARE002 | `ZCL_ZARE002_JOURNAL_ENTRY` · `ZCL_ZARE002_SUBMIT` · message 115 (one-time customer) |

| API #4 | ZARE002 | `ZI_ZARE002_CLEARING` (+ `PaymentCurrency` · `AdvancePayment` · `99272be`) |

| Reject Batch ID | ZARE002 | `ZI_ZARE002_PYMT` · `ZC_ZARE002` + ddlx (`c238f5a`) |
| 8J | ZARI003 | `ZCL_ZARI003_SFDC_RESULT` sObject Collections (`3fe7013`) — **ต้องขนพร้อม ZARE002 8J** |
| 8J | ZARE002 | `ZBP_R_ZARE002` Reject ทีละ payment · message 004 (`b9cbfb1`) — **ต้องขนพร้อม ZARI003 8J** |
| OQ-48 | ZARI003 | `ZD_SBPA_API_KEY` · `ZD_SBPA_TRIGGER_ID` · `ZE_SBPA_API_KEY` · `ZE_SBPA_TRIGGER_ID` · `ZCS_REJECT_BATCH` (`308d284`) · `ZCL_ZARI003_REJECT_BATCH` path (`5fc2af7`) — บน TEST กรอก `API_KEY` / `TRIGGER_ID` หลัง import (ค่าตัวพิมพ์เล็กต้องคงอยู่) |
| Posting Date filter | ZARE002 | `ZC_ZARE002` (`d300e63`) |
| 8L | ZARE002 | `ZCL_ZARE002_JOURNAL_ENTRY` · `ZCL_ZARE002_SUBMIT` (`311f474`) · `ZI_ZARE002_CLEARING_PARTIAL` · `ZI_ZARE002_CLEARING` · `ZAPI_ZARE002` (`3b7ee6c`) — **เฟส B ต้องขนพร้อม ZARI003 8L** · publish `ZAPI_ZARE002_O4` ใหม่ถ้าไม่เห็น `PartialPayments` |
| 8L | ZARI003 | `ZCL_ZARI003_CLEARING_RESULT` · message 016 (`c015650`) |
| 8K | ZARI002 | `ZTAR_I002_PYMT` / `ZTAR_I002_HDRLOG` `payment_method` char(20) + รับค่ารูปแบบใหม่ — **ต้องขนพร้อม ZARE002 8K** |
| 8K | ZARE002 | `ZCL_ZARE002_SUBMIT` (`is_cheque` + test) · `ZCL_ZARE002_UTIL` (`90f43a5`) — **ต้องขนพร้อม ZARI002 8K** |

ลำดับ: **ZBCPARAM → ZBCUTILITY** → ZARI002 → ZARI003 → ZARE002
