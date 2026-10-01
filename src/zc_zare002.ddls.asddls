@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Automatic Incoming Payments'
@Metadata.allowExtensions: true
define root view entity ZC_ZARE002
  provider contract transactional_query
  as projection on ZR_ZARE002
{
  key ItemUuid,

      /* ---------- header : ZTAR_I002_PYMT ---------- */
      _Payment.RequestId                              as RequestId,
      _Payment.SalesforceId                           as SalesforceId,
      _Payment.PaymentDocumentNo                      as PaymentDocumentNo,
      _Payment.NumberOfItemsInPayment                 as NumberOfItemsInPayment,
      @Consumption.filter.defaultValue: '2000'
      _Payment.CompanyCode                            as CompanyCode,
      _Payment.PostingDate                            as PostingDate,
      _Payment.GlAccount                              as GlAccount,
      _Payment.PaymentMethod                          as PaymentMethod,
      _Payment.ChequeNo                               as ChequeNo,
      _Payment.IssueDate                              as IssueDate,
      _Payment.DueOn                                  as DueOn,
      _Payment.ChequeBankBranch                       as ChequeBankBranch,

      _Payment.Currency                               as PaymentCurrency,

      @Semantics.amount.currencyCode: 'PaymentCurrency'
      _Payment.RoundingDiff                           as RoundingDiff,
      @Semantics.amount.currencyCode: 'PaymentCurrency'
      _Payment.AdvancePayment                         as AdvancePayment,
      @Semantics.amount.currencyCode: 'PaymentCurrency'
      _Payment.Fees                                   as Fees,
      @Semantics.amount.currencyCode: 'PaymentCurrency'
      _Payment.PaymentAmount                          as PaymentAmount,

      @ObjectModel.text.element: [ 'StatusText' ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_ZARE002_STATUS_VH', element: 'Status' } } ]
      _Payment.Status                                 as Status,
      _Payment.StatusText                             as StatusText,
      @ObjectModel.text.element: [ 'SalesforceStatusText' ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_ZARE002_SFDC_STATUS_VH', element: 'SalesforceStatus' } } ]
      _Payment.SalesforceStatus                       as SalesforceStatus,
      _Payment.SalesforceStatusText                   as SalesforceStatusText,
      _Payment.SalesforceMessage                      as SalesforceMessage,
      _Payment.PaymentAccountingDocument              as PaymentAccountingDocument,
      _Payment.ClearingAccountingDocument             as ClearingAccountingDocument,
      _Payment.SubmitMessage                          as SubmitMessage,
      _Payment.ClearingMessage                        as ClearingMessage,
      @ObjectModel.text.element: [ 'SubmitStatusText' ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_ZARE002_SUBMIT_STATUS_VH', element: 'SubmitStatus' } } ]
      _Payment.IsSubmitted                            as IsSubmitted,
      _Payment._SubmitStatusText.SubmitStatusText     as SubmitStatusText,
      @ObjectModel.text.element: [ 'ClearingStatusText' ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_ZARE002_CLEARING_STATUS_VH', element: 'ClearingStatus' } } ]
      _Payment.IsCleared                              as IsCleared,
      _Payment._ClearingStatusText.ClearingStatusText as ClearingStatusText,
      
      /* ---------- item : ZTAR_I002_ITEM ---------- */
      PaymentUuid,
      SalesforceItemId,
      CustomerCode,
      _BusinessPartner.CustomerName                   as CustomerName,
      BillingNoteNo,
      AccountingDocument,
      BillingDocument,
      InvoicePostingDate,
      Currency,
      InvoiceAmount,
      AmountPaid,
      PartialAmount,
      SaleSubmitDate,

      /* ---------- field เดียวที่แก้ได้ ---------- */
      RejectReason,

      /* ---------- admin ---------- */
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt
}
