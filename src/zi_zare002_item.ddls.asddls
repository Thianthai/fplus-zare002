@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Automatic Incoming Payments - Item'
define view entity ZI_ZARE002_ITEM
  as select from ztar_i002_item

  association [1..1] to ZI_ZARE002_PYMT as _Payment
    on $projection.PaymentUuid = _Payment.PaymentUuid

  association [0..1] to ZI_ZARE002_BP   as _BusinessPartner
    on $projection.CustomerCode = _BusinessPartner.BusinessPartner
{
      @EndUserText.label: 'Item UUID'
  key item_uuid              as ItemUuid,

      @EndUserText.label: 'Payment UUID'
      payment_uuid           as PaymentUuid,
      @EndUserText.label: 'Salesforce Item ID'
      salesforce_item_id     as SalesforceItemId,
      @EndUserText.label: 'Customer Code'
      customer_code          as CustomerCode,
      @EndUserText.label: 'Billing Note No.'
      billing_note_no        as BillingNoteNo,
      @EndUserText.label: 'Accounting Document'
      accounting_document    as AccountingDocument,
      @EndUserText.label: 'Billing Document'
      billing_document       as BillingDocument,
      @EndUserText.label: 'Invoice Posting Date'
      invoice_posting_date   as InvoicePostingDate,

      @EndUserText.label: 'Currency'
      currency               as Currency,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Invoice Amount'
      invoice_amount         as InvoiceAmount,
      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Amount Paid'
      amount_paid            as AmountPaid,

      @EndUserText.label: 'Partial Payment'
      partial_amount         as PartialAmount,
      @EndUserText.label: 'Sale Submit Date'
      sale_submit_date       as SaleSubmitDate,
      @EndUserText.label: 'Reject Reason'
      reject_reason          as RejectReason,

      @Semantics.user.createdBy: true
      created_by             as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at             as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by        as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at        as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at  as LocalLastChangedAt,

      _Payment,
      _BusinessPartner
}
