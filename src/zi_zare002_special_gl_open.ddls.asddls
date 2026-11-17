@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Automatic Incoming Payments - Special GL'

// ลูกค้าที่ยังมีบรรทัด Special G/L Z ที่ยังไม่ถูก clear
// 1 row ต่อ company code และลูกค้า
// ดูทุกบรรทัด Z ของลูกค้า ไม่จำกัดว่ามาจากใบไหน
// ใช้ประกอบเงื่อนไข AdvancePayment ของคิว ZI_ZARE002_CLEARING
define view entity ZI_ZARE002_SPECIAL_GL_OPEN
  as select from I_OperationalAcctgDocItem
{
  key CompanyCode,
  key Customer as CustomerCode,

      // จำนวนบรรทัด Z ที่ยังค้าง ไว้ตรวจสอบเวลามีปัญหา
      count( * ) as OpenItemCount
}
where
      FinancialAccountType = 'D'
  and SpecialGLCode        = 'Z'
  and ClearingJournalEntry = ''
group by
  CompanyCode,
  Customer
