@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Automatic Incoming Payments - Clearing'

// รายการที่ post JE แล้วแต่ยังไม่ได้ clear open item
// BOT ดึงไปทำ clearing ผ่าน App: Clear Incoming Payments แล้วส่งเลข clearing กลับมาทาง HTTP service
// 1 row ต่อ 1 item เพราะ customer code อยู่ที่ระดับ item
// BOT รวมแถวเองตาม PaymentAccountingDocument แล้วทำทีละใบ
// ใบที่ clear แล้วจะหลุดจาก view นี้เอง ไม่ต้องมีใครมาลบคิว
define view entity ZI_ZARE002_CLEARING
  as select from ztar_i002_pymt as Payment
    inner join ztar_i002_item as Item on Payment.payment_uuid = Item.payment_uuid

    // ปีบัญชีของ invoice ไม่ได้เก็บไว้ในตาราง ต้องอ่านจากเอกสาร FI จริง
    // ต้อง join ด้วย posting date ด้วย เพราะปีบัญชีเป็นส่วนหนึ่งของ key ของ I_JournalEntry
    // เลขเอกสารเดียวกันเกิดซ้ำได้ในคนละปี ถ้า join แค่ company code กับเลขเอกสารจะได้หลายแถว
    left outer join I_JournalEntry  as Invoice
      on  Invoice.CompanyCode        = Payment.company_code
      and Invoice.AccountingDocument = Item.accounting_document
      and Invoice.PostingDate        = Item.invoice_posting_date
{
      // key ของ view เป็น item uuid เพราะ 1 row คือ 1 item
  key Item.item_uuid                       as ItemUuid,

      // เลขใบฝั่งต้นทาง ไว้ไล่เรื่องย้อนกลับเวลามีปัญหา
      @EndUserText.label: 'Payment Document No.'
      Payment.payment_document_no          as PaymentDocumentNo,

      // ช่อง Company Code บนหน้าจอ clearing
      // จำเป็นคู่กับเลขเอกสารเสมอ เพราะเลขเอกสารบัญชี unique แค่ภายใน company code และปีบัญชี
      @EndUserText.label: 'Company Code'
      Payment.company_code                 as CompanyCode,

      // ช่อง Customer บนหน้าจอ clearing
      // 1 payment มี customer เดียว ทุก row ของใบเดียวกันจึงได้ค่าเท่ากัน
      @EndUserText.label: 'Customer'
      Item.customer_code                   as CustomerCode,

      // ช่อง Journal Entry Date ของเอกสาร clearing
      // ใช้วันเดียวกับ posting date ตาม spec
      @EndUserText.label: 'Journal Entry Date'
      Payment.posting_date                 as JournalEntryDate,

      // ช่อง Posting Date ของเอกสาร clearing
      // ใช้วันที่บันทึกเอกสารรับชำระ ไม่ใช่วันที่ BOT รัน เพื่อให้ลงงวดเดียวกับ JE
      @EndUserText.label: 'Posting Date'
      Payment.posting_date                 as PostingDate,

      // ช่อง Journal Entry Type ของเอกสาร clearing
      // spec กำหนดเป็น DS เหมือนเอกสารรับชำระ
      @EndUserText.label: 'Journal Entry Type'
      cast( 'DS' as abap.char( 2 ) )       as JournalEntryType,

      // เลขเอกสาร invoice ที่ต้องเลือก clear ในคอลัมน์ Journal Entry ของหน้าจอ
      @EndUserText.label: 'Invoice Doc'
      Item.accounting_document             as InvoiceAccountingDocument,

      // ปีบัญชีของ invoice ที่ BOT ต้องใช้เลือกเอกสารในหน้าจอ
      // อ่านจากเอกสาร FI จริง ไม่ได้คำนวณจากวันที่ เพื่อให้ถูกแม้ปีบัญชีไม่ตรงปีปฏิทิน
      // ว่างได้ถ้าหาเอกสารไม่เจอ หรือ user ที่เรียกไม่มีสิทธิ์อ่านเอกสาร FI
      @EndUserText.label: 'Invoice Doc Year'
      Invoice.FiscalYear                   as InvoiceAccountingDocumentYear,

      // เลขเอกสาร JE ที่ ZARE002 post ไว้
      // BOT ส่งค่านี้กลับมาคู่กับเลข clearing เพื่อบอกว่าทำใบไหนเสร็จ
      @EndUserText.label: 'Payment Doc'
      Payment.payment_accounting_document  as PaymentAccountingDocument,

      // ปีบัญชีของเอกสาร JE
      // เลขเอกสารบัญชี unique แค่ภายใน company code และปีบัญชี BOT จึงต้องใช้คู่กันเสมอ
      @EndUserText.label: 'Payment Doc Year'
      Payment.payment_fiscal_year          as PaymentAccountingDocumentYear
}
where
      Payment.payment_accounting_document  <> ''
  and Payment.clearing_accounting_document =  ''
