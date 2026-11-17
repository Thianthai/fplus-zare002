@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Automatic Incoming Payments - Advance'

// ลูกค้าที่เคยใช้เงินรับล่วงหน้าหักกับการรับชำระบางส่วน
// 1 row ต่อ company code และลูกค้า
// ใช้ประกอบเงื่อนไข AdvancePayment ของคิว ZI_ZARE002_CLEARING
// นับเฉพาะใบที่ post JE แล้ว และไม่ถูก reject
// ใบที่ advance ติดลบ คือใบที่ดึงเงินล่วงหน้าที่เคยรับไว้มาหักกับ invoice
define view entity ZI_ZARE002_ADVANCE_USED
  as select distinct from ztar_i002_pymt as Payment
    inner join ztar_i002_item as Item on Item.payment_uuid = Payment.payment_uuid
{
  key Payment.company_code as CompanyCode,
  key Item.customer_code   as CustomerCode
}
where
      Payment.payment_accounting_document <> ''
  and Payment.status                      <> 'R'
  and Payment.advance_payment             <  0
  and Item.partial_amount                 =  'X'
