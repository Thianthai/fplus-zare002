@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Automatic Incoming Payments - Payment'
define view entity ZI_ZARE002_PYMT
  as select from ztar_i002_pymt
  association [0..1] to ZI_ZARE002_STATUS_VH          as _StatusText         on $projection.Status           = _StatusText.Status
  association [0..1] to ZI_ZARE002_SFDC_STATUS_VH     as _SfdcStatusText     on $projection.SalesforceStatus = _SfdcStatusText.SalesforceStatus
  association [0..1] to ZI_ZARE002_SUBMIT_STATUS_VH   as _SubmitStatusText   on $projection.IsSubmitted      = _SubmitStatusText.SubmitStatus
  association [0..1] to ZI_ZARE002_CLEARING_STATUS_VH as _ClearingStatusText on $projection.IsCleared        = _ClearingStatusText.ClearingStatus
{
      @EndUserText.label: 'Payment UUID'
  key payment_uuid                  as PaymentUuid,

      @EndUserText.label: 'Request ID'
      request_id                    as RequestId,
      @EndUserText.label: 'Salesforce ID'
      salesforce_id                 as SalesforceId,
      @EndUserText.label: 'Payment Document No.'
      payment_document_no           as PaymentDocumentNo,
      @EndUserText.label: 'No. of Items in Payment'
      number_of_items_in_payment    as NumberOfItemsInPayment,
      @EndUserText.label: 'Company Code'
      company_code                  as CompanyCode,
      @EndUserText.label: 'Posting Date'
      posting_date                  as PostingDate,
      @EndUserText.label: 'G/L Account'
      gl_account                    as GlAccount,
      @EndUserText.label: 'Payment Method'
      payment_method                as PaymentMethod,
      @EndUserText.label: 'Cheque No.'
      cheque_no                     as ChequeNo,
      @EndUserText.label: 'Issue Date'
      issue_date                    as IssueDate,
      @EndUserText.label: 'Due On'
      due_on                        as DueOn,
      @EndUserText.label: 'Cheque Bank Branch'
      cheque_bank_branch            as ChequeBankBranch,

      @EndUserText.label: 'Currency'
      currency                      as Currency,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Rounding Difference'
      rounding_diff                 as RoundingDiff,
      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Advance Payment'
      advance_payment               as AdvancePayment,
      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Fees'
      fees                          as Fees,
      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Payment Amount (Net)'
      payment_amount                as PaymentAmount,

      // Status ของรายการ
      @EndUserText.label: 'Status'
      status                        as Status,

      // ข้อความของ Status จาก domain ZD_REQUEST_STATUS ตามภาษาที่ login
      @EndUserText.label: 'Status Text'
      _StatusText.StatusText        as StatusText,

      // field สำหรับเก็บ Status ของการส่งไปให้ SFDC
      @EndUserText.label: 'Salesforce Status'
      salesforce_status             as SalesforceStatus,

      // ข้อความของ Salesforce Status จาก domain ZD_RESPONSE_STATUS
      @EndUserText.label: 'Salesforce Status Text'
      _SfdcStatusText.SalesforceStatusText as SalesforceStatusText,
      
      @EndUserText.label: 'Salesforce Message'
      salesforce_message            as SalesforceMessage,

      // field สำหรับ Submit

      // เลขเอกสารรับชำระที่ Submit post ไว้
      @EndUserText.label: 'Submit Document'
      payment_accounting_document   as PaymentAccountingDocument,

      // เลขเอกสาร clearing ที่ BOT ส่งกลับมา
      @EndUserText.label: 'Clearing Document'
      clearing_accounting_document  as ClearingAccountingDocument,

      // ข้อความล่าสุดของขั้น Submit
      @EndUserText.label: 'Submit Message'
      submit_message                as SubmitMessage,

      // ข้อความล่าสุดของขั้น clearing ที่ได้จาก BOT
      @EndUserText.label: 'Clearing Message'
      clearing_message              as ClearingMessage,

      // สถานะของขั้น Submit สำหรับ filter บนหน้าจอ
      // S คือ post เอกสารรับชำระแล้ว
      // N คือยังไม่ post
      // ชื่อ element คงเป็น IsSubmitted ไว้ เพราะ frontend และ variant ที่บันทึกไว้อ้างชื่อนี้
      // ข้อความอ่านผ่าน _SubmitStatusText ใน ZC_ZARE002
      // ใช้ path ใน view นี้ไม่ได้ เพราะ association อ้าง field ที่คำนวณขึ้นเอง
      @EndUserText.label: 'Submit Status'
      cast( case when payment_accounting_document <> '' then 'S' else 'N' end
            as ze_submit_status )   as IsSubmitted,

      // สถานะของขั้น clearing สำหรับ filter บนหน้าจอ
      // C คือได้เลขเอกสาร clearing จาก BOT แล้ว
      // N คือยังไม่ได้
      // ชื่อ element คงเป็น IsCleared ไว้ด้วยเหตุผลเดียวกัน
      // ข้อความอ่านผ่าน _ClearingStatusText ใน ZC_ZARE002 ด้วยเหตุผลเดียวกับ IsSubmitted
      @EndUserText.label: 'Clearing Status'
      cast( case when clearing_accounting_document <> '' then 'C' else 'N' end
            as ze_clearing_status ) as IsCleared,
      
      @Semantics.user.createdBy: true
      created_by                    as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at                    as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by               as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at               as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at         as LocalLastChangedAt,

      _StatusText,
      _SfdcStatusText,
      _SubmitStatusText,
      _ClearingStatusText
}
