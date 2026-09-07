@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Automatic Incoming Payments - Payment'
define view entity ZI_ZARE002_PYMT
  as select from ztar_i002_pymt
{
      @EndUserText.label: 'Payment UUID'
  key payment_uuid                as PaymentUuid,

      @EndUserText.label: 'Request ID'
      request_id                  as RequestId,
      @EndUserText.label: 'Salesforce ID'
      salesforce_id               as SalesforceId,
      @EndUserText.label: 'Payment Document No.'
      payment_document_no         as PaymentDocumentNo,
      @EndUserText.label: 'No. of Items in Payment'
      number_of_items_in_payment  as NumberOfItemsInPayment,
      @EndUserText.label: 'Company Code'
      company_code                as CompanyCode,
      @EndUserText.label: 'Posting Date'
      posting_date                as PostingDate,
      @EndUserText.label: 'G/L Account'
      gl_account                  as GlAccount,
      @EndUserText.label: 'Payment Method (Text)'
      payment_method              as PaymentMethod,
      @EndUserText.label: 'Payment Method'
      sap_payment_method          as SapPaymentMethod,
      @EndUserText.label: 'Cheque No.'
      cheque_no                   as ChequeNo,
      @EndUserText.label: 'Issue Date'
      issue_date                  as IssueDate,
      @EndUserText.label: 'Due On'
      due_on                      as DueOn,
      @EndUserText.label: 'Cheque Bank Branch'
      cheque_bank_branch          as ChequeBankBranch,

      @EndUserText.label: 'Currency'
      currency                    as Currency,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Rounding Difference'
      rounding_diff               as RoundingDiff,
      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Advance Payment'
      advance_payment             as AdvancePayment,
      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Fees'
      fees                        as Fees,
      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Payment Amount'
      payment_amount              as PaymentAmount,

      status                      as Status,

      // สีของ icon สถานะบนหน้าจอ — 1 แดง · 2 เหลือง · 3 เขียว · 0 เทา
      @EndUserText.label: 'Status Criticality'
      cast(
        case status
          when 'N' then 2   // New      — รอดำเนินการ
          when 'C' then 3   // Complete
          when 'R' then 1   // Reject
          when 'E' then 1   // Error
          else          0
        end as abap.int1 )  as StatusCriticality,
        
      salesforce_status           as SalesforceStatus,
      @EndUserText.label: 'Salesforce Message'
      salesforce_message          as SalesforceMessage,

      @Semantics.user.createdBy: true
      created_by                  as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at                  as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by             as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at             as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at       as LocalLastChangedAt
}
