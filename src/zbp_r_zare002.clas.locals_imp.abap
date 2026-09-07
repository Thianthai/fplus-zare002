CLASS lhc_Item DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    "! สิทธิ์ระดับ BO — เปิดให้ทุกคนที่เข้า app ได้ (OQ-15)
    "! การคุมว่าใครเข้า app ได้อยู่ที่ IAM App / business catalog ไม่ใช่ที่นี่
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Item
      RESULT result.

ENDCLASS.

CLASS lhc_Item IMPLEMENTATION.

  METHOD get_global_authorizations.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
