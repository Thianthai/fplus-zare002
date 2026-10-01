@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Automatic Incoming Payments - SFDC St.'
@ObjectModel.resultSet.sizeCategory: #XS
// ข้อความของ Salesforce Status จาก fixed value ของ domain ZD_RESPONSE_STATUS
// ค่าว่างคือยังไม่เคยส่งผลไป Salesforce มีข้อความ Not Sent ใน domain
// ตัด W ออกจาก dropdown เพราะไม่มีขั้นไหนเขียนค่านี้
// key ต้องตรงกับ source ไม่งั้นได้ warning
define view entity ZI_ZARE002_SFDC_STATUS_VH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZD_RESPONSE_STATUS' )
{
      @UI.hidden: true
  key domain_name    as DomainName,

      @UI.hidden: true
  key value_position as ValuePosition,

      @ObjectModel.text.element: [ 'SalesforceStatusText' ]
      @EndUserText.label: 'Salesforce Status'
      value_low      as SalesforceStatus,

      @Semantics.text: true
      @EndUserText.label: 'Salesforce Status'
      text           as SalesforceStatusText
}
where language  =  $session.system_language
  and value_low <> 'W'
