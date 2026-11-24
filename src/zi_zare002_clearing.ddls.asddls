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

    // ลูกค้าที่เคยใช้เงินล่วงหน้าหักกับการรับชำระบางส่วน
    // view ให้ 1 row ต่อ company code และลูกค้า จึงไม่ทำให้แถวซ้ำ
    left outer join ZI_ZARE002_ADVANCE_USED as AdvanceUsed
      on  AdvanceUsed.CompanyCode  = Payment.company_code
      and AdvanceUsed.CustomerCode = Item.customer_code

    // ลูกค้าที่ยังมีบรรทัด Special G/L Z ค้างไม่ถูก clear
    // view ให้ 1 row ต่อ company code และลูกค้า จึงไม่ทำให้แถวซ้ำ
    left outer join ZI_ZARE002_SPECIAL_GL_OPEN as SpecialGlOpen
      on  SpecialGlOpen.CompanyCode  = Payment.company_code
      and SpecialGlOpen.CustomerCode = Item.customer_code

    // เอกสารรับชำระบางส่วนก่อนหน้าที่ BOT ต้อง clear เพิ่ม
    // มีเฉพาะ item ของใบสุดท้าย BOT อ่านด้วย $expand=_PartialPayments
    association [0..*] to ZI_ZARE002_CLEARING_PARTIAL as _PartialPayments
      on $projection.ItemUuid = _PartialPayments.ItemUuid
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
      Invoice.FiscalYear                   as InvoiceAccountingDocYear,

      // Reference Key 3 ของ invoice
      // เลขเอกสาร invoice ต่อด้วย billing document
      // item ที่ไม่มี billing document ได้ค่าว่าง
      @EndUserText.label: 'Invoice Ref. Key 3'
      case
        when Item.billing_document <> ''
          then cast( concat( Item.accounting_document, Item.billing_document ) as abap.char( 20 ) )
        else cast( '' as abap.char( 20 ) )
      end                                  as InvoiceRefKey3,

      // เลขเอกสาร JE ที่ ZARE002 post ไว้
      // BOT ส่งค่านี้กลับมาคู่กับเลข clearing เพื่อบอกว่าทำใบไหนเสร็จ
      @EndUserText.label: 'Payment Doc'
      Payment.payment_accounting_document  as PaymentAccountingDocument,

      // ปีบัญชีของเอกสาร JE
      // เลขเอกสารบัญชี unique แค่ภายใน company code และปีบัญชี BOT จึงต้องใช้คู่กันเสมอ
      @EndUserText.label: 'Payment Doc Year'
      Payment.payment_fiscal_year          as PaymentAccountingDocYear,

      // Reference Key 3 ของบรรทัดลูกหนี้ของ item นี้ในเอกสาร JE
      // เลขเอกสาร JE ต่อด้วย billing document
      // item ที่ไม่มี billing document ได้ค่าว่าง
      @EndUserText.label: 'Payment Ref. Key 3'
      case
        when Item.billing_document <> ''
          then cast( concat( Payment.payment_accounting_document, Item.billing_document ) as abap.char( 20 ) )
        else cast( '' as abap.char( 20 ) )
      end                                  as PaymentRefKey3,

      // สกุลเงินของยอดระดับ header
      @EndUserText.label: 'Payment Currency'
      Payment.currency                     as PaymentCurrency,

      // บอก BOT ว่าต้อง clear บรรทัดเงินรับล่วงหน้าด้วยหรือไม่
      // X เมื่อยอดรวมของบรรทัด Special G/L Z ที่ยังไม่ clear ของลูกค้าเท่ากับ 0
      //   และใบนี้ดึงเงินล่วงหน้ามาหัก คือ advance ติดลบ
      //   หรือ item ไม่ใช่การรับชำระบางส่วน และลูกค้าเคยมีใบรับชำระบางส่วนที่ advance ติดลบ
      // ยอดรวมไม่เท่ากับ 0 ได้ค่าว่าง รอให้ยอดลงตัวในการรับชำระครั้งถัดไป
      // ลูกค้าไม่มีบรรทัด Z ค้างเลยได้ค่าว่าง
      @EndUserText.label: 'Advance Payment'
      case
        when SpecialGlOpen.OpenAmount = 0
         and ( Payment.advance_payment < 0
            or ( Item.partial_amount      =  ''
             and AdvanceUsed.CustomerCode is not null ) )
          then cast( 'X' as abap.char( 1 ) )
        else cast( '' as abap.char( 1 ) )
      end                                  as AdvancePayment,

      _PartialPayments
}
where
      Payment.payment_accounting_document  <> ''
  and Payment.clearing_accounting_document =  ''
      // ใบที่ถูก reject แล้วห้ามส่งให้ BOT clear แม้จะมีเลขเอกสารรับชำระค้างอยู่
      // ตามปกติเกิดไม่ได้ เพราะ Reject ปฏิเสธใบที่ post แล้ว
      // กันไว้เผื่อข้อมูลถูกแก้จากภายนอก
  and Payment.status                       <> 'R'
      // item ที่รับชำระบางส่วนไม่เข้าคิว
      // BOT จะ clear เอกสารของใบเหล่านี้พร้อมใบสุดท้ายผ่าน _PartialPayments
  and Item.partial_amount                  =  ''
