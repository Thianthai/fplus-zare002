@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Business Partner - Customer Name'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_ZARE002_BP
  as select from I_BusinessPartner
{
      @EndUserText.label: 'Customer Code'
  key BusinessPartner as BusinessPartner,

      // OrganizationBPName1..4 ต่อกันด้วยช่องว่างเดียว
      // concat_with_space ตัด trailing blank ของ argument แรกก่อนต่อทุกครั้ง
      // field ว่างตรงกลางจึงไม่ทำให้เกิดช่องว่างซ้อน
      @EndUserText.label: 'Customer Name'
      concat_with_space(
        concat_with_space(
          concat_with_space( OrganizationBPName1, OrganizationBPName2, 1 ),
          OrganizationBPName3, 1 ),
        OrganizationBPName4, 1 ) as CustomerName
}
