@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Automatic Incoming Payments'
define root view entity ZR_ZARE002
  as select from ZI_ZARE002_ITEM
{
  key ItemUuid,

      PaymentUuid,
      SalesforceItemId,
      CustomerCode,
      BillingNoteNo,
      AccountingDocument,
      BillingDocument,
      InvoicePostingDate,
      Currency,
      InvoiceAmount,
      AmountPaid,
      PartialAmount,
      SaleSubmitDate,
      RejectReason,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Payment,
      _BusinessPartner
}
