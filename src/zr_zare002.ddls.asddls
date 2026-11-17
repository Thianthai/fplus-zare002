@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Automatic Incoming Payments'
// root ของ BO
// field ของ header และ CustomerName ไปโผล่ที่ ZC_ZARE002 ผ่าน association
define root view entity ZR_ZARE002
  as select from ZI_ZARE002_ITEM
  // Reference Key 3 ที่อยู่ในเอกสารจริง แสดงใน report ผ่าน ZC_ZARE002
  association [0..1] to ZI_ZARE002_REF_KEY3 as _RefKey3
    on $projection.ItemUuid = _RefKey3.ItemUuid
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
      _BusinessPartner,
      _RefKey3
}
