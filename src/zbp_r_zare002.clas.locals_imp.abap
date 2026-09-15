CLASS lhc_Item DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    "! สิทธิ์ระดับ BO — เปิดให้ทุกคนที่เข้า app ได้ (OQ-15)
    "! การคุมว่าใครเข้า app ได้อยู่ที่ IAM App / business catalog ไม่ใช่ที่นี่
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Item
      RESULT result.

    "! ปุ่ม Submit — เฟสนี้ว่าง
    "! เฟสถัดไป: distinct PaymentUuid จาก keys → อ่าน item ทั้งหมดของ payment เหล่านั้น → post FI
    METHODS submitItem FOR MODIFY
      IMPORTING keys FOR ACTION Item~submitItem.

    "! ปุ่ม Reject — เฟสนี้ว่าง
    "! เฟสถัดไป: distinct PaymentUuid จาก keys → อ่าน item ทั้งหมดของ payment เหล่านั้น → status = R
    METHODS rejectItem FOR MODIFY
      IMPORTING keys FOR ACTION Item~rejectItem.

ENDCLASS.

CLASS lhc_Item IMPLEMENTATION.

  METHOD get_global_authorizations.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-submitItem = if_abap_behv=>mk-on.
      result-%action-submitItem = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-rejectItem = if_abap_behv=>mk-on.
      result-%action-rejectItem = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD submitItem.
    " ยังไม่มี logic — เฟสนี้เปิดแค่ปุ่มตาม requirement
    " ต้องไม่ raise error และไม่แก้ข้อมูล กดแล้วเงียบคือพฤติกรรมที่ถูกต้อง
  ENDMETHOD.

  METHOD rejectItem.
    " ยังไม่มี logic — เฟสนี้เปิดแค่ปุ่มตาม requirement
    " ต้องไม่ raise error และไม่แก้ข้อมูล กดแล้วเงียบคือพฤติกรรมที่ถูกต้อง
  ENDMETHOD.

ENDCLASS.
