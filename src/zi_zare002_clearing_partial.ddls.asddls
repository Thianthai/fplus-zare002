@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Automatic Incoming Payments - Partial'

// เอกสารรับชำระบางส่วนก่อนหน้าของใบสุดท้าย ที่ BOT ต้องเลือก clear เพิ่มพร้อมกับใบสุดท้าย
// 1 row ต่อ 1 item ของใบสุดท้าย คูณ 1 บรรทัดลูกหนี้ของเอกสารรับชำระบางส่วนที่เจอ
// ใบรับชำระบางส่วนใส่ billing document ไว้ที่ Reference1 ของบรรทัดลูกหนี้ตอน post
// ใบสุดท้ายคือ item ที่ partial_amount ว่าง แต่ยอดที่จ่ายไม่เท่ากับยอด invoice
// เงื่อนไขของใบสุดท้ายต้องตรงกับคิว ZI_ZARE002_CLEARING ทุกข้อ
define view entity ZI_ZARE002_CLEARING_PARTIAL
  as select from ztar_i002_pymt as Payment
    inner join ztar_i002_item as Item on Item.payment_uuid = Payment.payment_uuid

    // บรรทัดลูกหนี้ที่อ้าง billing document เดียวกันใน company code เดียวกับใบ
    inner join I_OperationalAcctgDocItem as Partial
      on  Partial.CompanyCode                   = Payment.company_code
      and Partial.Reference1IDByBusinessPartner = Item.billing_document

    // ใช้ตัดเอกสารที่กลับรายการหรือถูกกลับรายการแล้ว
    inner join I_JournalEntry as PartialHeader
      on  PartialHeader.CompanyCode        = Partial.CompanyCode
      and PartialHeader.FiscalYear         = Partial.FiscalYear
      and PartialHeader.AccountingDocument = Partial.AccountingDocument
{
      // item ของใบสุดท้าย ใช้ผูกกับ ClearingItems
  key Item.item_uuid                       as ItemUuid,

      // เอกสารรับชำระบางส่วนที่ BOT ต้องเลือก clear เพิ่ม
      // เลขเอกสารบัญชี unique แค่ภายใน company code และปีบัญชี จึงต้องส่งคู่กันเสมอ
      @EndUserText.label: 'Partial Payment Doc'
  key Partial.AccountingDocument           as PartialAccountingDocument,

      @EndUserText.label: 'Partial Payment Doc Year'
  key Partial.FiscalYear                   as PartialAccountingDocYear,

      @EndUserText.label: 'Partial Payment Doc Item'
  key Partial.AccountingDocumentItem       as PartialAccountingDocItem,

      // เลขใบฝั่งต้นทางของใบสุดท้าย ไว้ไล่เรื่องย้อนกลับ
      @EndUserText.label: 'Payment Document No.'
      Payment.payment_document_no          as PaymentDocumentNo,

      @EndUserText.label: 'Company Code'
      Payment.company_code                 as CompanyCode,

      // เลขเอกสาร JE ของใบสุดท้าย
      // BOT ใช้จับกลุ่มกับ ClearingItems ของใบเดียวกัน
      @EndUserText.label: 'Payment Doc'
      Payment.payment_accounting_document  as PaymentAccountingDocument,

      @EndUserText.label: 'Payment Doc Year'
      Payment.payment_fiscal_year          as PaymentAccountingDocYear,

      // billing document ที่ใช้หาเอกสารรับชำระบางส่วน
      @EndUserText.label: 'Billing Document'
      Item.billing_document                as BillingDocument,

      @EndUserText.label: 'Customer'
      Partial.Customer                     as CustomerCode,

      @EndUserText.label: 'Partial Payment Currency'
      Partial.TransactionCurrency          as PartialPaymentCurrency,

      // ยอดของบรรทัดลูกหนี้ในเอกสารรับชำระบางส่วน
      // ติดลบเพราะเป็นฝั่งเครดิต
      @Semantics.amount.currencyCode: 'PartialPaymentCurrency'
      @EndUserText.label: 'Partial Payment Amount'
      Partial.AmountInTransactionCurrency  as PartialPaymentAmount
}
where
      // เงื่อนไขเดียวกับคิว ZI_ZARE002_CLEARING
      Payment.payment_accounting_document   <> ''
  and Payment.clearing_accounting_document  =  ''
  and Payment.status                        <> 'R'
  and Item.partial_amount                   =  ''
      // ใบสุดท้าย คือ item ที่ยอดจ่ายไม่เท่ายอด invoice เพราะเคยรับชำระบางส่วนมาก่อน
  and Item.billing_document                 <> ''
  and Item.invoice_amount                   <> Item.amount_paid
      // เฉพาะบรรทัดลูกหนี้ที่ยังไม่ถูก clear
  and Partial.FinancialAccountType          =  'D'
  and Partial.ClearingJournalEntry          =  ''
      // ไม่เอาเอกสารที่กลับรายการ หรือถูกกลับรายการแล้ว
  and PartialHeader.IsReversal              =  ''
  and PartialHeader.IsReversed              =  ''
