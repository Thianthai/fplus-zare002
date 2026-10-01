@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Automatic Incoming Payments - Clearing St.'
@ObjectModel.resultSet.sizeCategory: #XS
// ข้อความของ Clearing Status จาก fixed value ของ domain ZD_CLEARING_STATUS
// key ต้องตรงกับ source ไม่งั้นได้ warning
// กรองภาษาเดียวแล้ว ClearingStatus จึงไม่ซ้ำกัน
define view entity ZI_ZARE002_CLEARING_STATUS_VH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZD_CLEARING_STATUS' )
{
      @UI.hidden: true
  key domain_name    as DomainName,

      @UI.hidden: true
  key value_position as ValuePosition,

      @ObjectModel.text.element: [ 'ClearingStatusText' ]
      @EndUserText.label: 'Clearing Status'
      value_low      as ClearingStatus,

      @Semantics.text: true
      @EndUserText.label: 'Clearing Status'
      text           as ClearingStatusText
}
where language = $session.system_language
