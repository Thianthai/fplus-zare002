@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Automatic Incoming Payments - Ref Key 3'

// Reference Key 3 ที่อยู่ในเอกสารจริง 1 row ต่อ item
// ใช้แสดงใน report ว่าเขียนลงเอกสารแล้วหรือยัง
// แสดงเฉพาะค่าที่ตรงกับค่าเต็ม คือเลขเอกสารต่อด้วย billing document
// ยังไม่ได้เขียน หรือค่าไม่ตรง ได้ค่าว่าง
// item ที่ไม่มี billing document ไม่มี row ใน view นี้ จึงได้ค่าว่างเช่นกัน
define view entity ZI_ZARE002_REF_KEY3
  as select from ztar_i002_item as Item
    inner join ztar_i002_pymt as Payment on Payment.payment_uuid = Item.payment_uuid

    // บรรทัดลูกค้าของ invoice
    // หาด้วย posting date เพราะ table ไม่ได้เก็บปีบัญชีของ invoice
    left outer join I_OperationalAcctgDocItem as InvoiceLine
      on  InvoiceLine.CompanyCode                   = Payment.company_code
      and InvoiceLine.AccountingDocument            = Item.accounting_document
      and InvoiceLine.PostingDate                   = Item.invoice_posting_date
      and InvoiceLine.FinancialAccountType          = 'D'
      and InvoiceLine.SpecialGLCode                 = ''
      and InvoiceLine.Reference3IDByBusinessPartner = concat( Item.accounting_document, Item.billing_document )

    // บรรทัดลูกหนี้ของ item นี้ในเอกสาร JE ที่ Submit post ไว้
    left outer join I_OperationalAcctgDocItem as PaymentLine
      on  PaymentLine.CompanyCode                   = Payment.company_code
      and PaymentLine.AccountingDocument            = Payment.payment_accounting_document
      and PaymentLine.FiscalYear                    = Payment.payment_fiscal_year
      and PaymentLine.FinancialAccountType          = 'D'
      and PaymentLine.SpecialGLCode                 = ''
      and PaymentLine.Reference3IDByBusinessPartner = concat( Payment.payment_accounting_document, Item.billing_document )
{
  key Item.item_uuid                                 as ItemUuid,

      // รวบเป็น 1 row ต่อ item ให้ key ไม่ซ้ำ
      @EndUserText.label: 'Acc. Ref. Key 3'
      max( InvoiceLine.Reference3IDByBusinessPartner ) as AccRefKey3,

      @EndUserText.label: 'Submit Ref. Key 3'
      max( PaymentLine.Reference3IDByBusinessPartner ) as SubmitRefKey3
}
where
  Item.billing_document <> ''
group by
  Item.item_uuid
