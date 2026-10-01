@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Automatic Incoming Payments - Submit St.'
@ObjectModel.resultSet.sizeCategory: #XS
// ข้อความของ Submit Status จาก fixed value ของ domain ZD_SUBMIT_STATUS
// key ต้องตรงกับ source ไม่งั้นได้ warning
// กรองภาษาเดียวแล้ว SubmitStatus จึงไม่ซ้ำกัน
define view entity ZI_ZARE002_SUBMIT_STATUS_VH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZD_SUBMIT_STATUS' )
{
      @UI.hidden: true
  key domain_name    as DomainName,

      @UI.hidden: true
  key value_position as ValuePosition,

      @ObjectModel.text.element: [ 'SubmitStatusText' ]
      @EndUserText.label: 'Submit Status'
      value_low      as SubmitStatus,

      @Semantics.text: true
      @EndUserText.label: 'Submit Status'
      text           as SubmitStatusText
}
where language = $session.system_language
