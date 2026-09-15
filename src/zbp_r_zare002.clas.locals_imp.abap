CLASS lhc_Item DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    "! สิทธิ์ระดับ BO — เปิดให้ทุกคนที่เข้า app ได้ (OQ-15)
    "! การคุมว่าใครเข้า app ได้อยู่ที่ IAM App / business catalog ไม่ใช่ที่นี่
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR Item RESULT result.

ENDCLASS.

CLASS lhc_Item IMPLEMENTATION.

  METHOD get_global_authorizations.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_zr_zare002 DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

  PRIVATE SECTION.

    TYPES tt_ztar_i002_item TYPE TABLE OF ztar_i002_item.

    METHODS modify_table
      IMPORTING it_table TYPE tt_ztar_i002_item.

ENDCLASS.

CLASS lsc_zr_zare002 IMPLEMENTATION.

  METHOD save_modified.

    DATA lt_update TYPE TABLE OF ztar_i002_item.

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD DATA(lv_now).

    LOOP AT update-item INTO DATA(ls_update).
      APPEND INITIAL LINE TO lt_update ASSIGNING FIELD-SYMBOL(<lfs_update>).
      <lfs_update>-reject_reason         = ls_update-RejectReason.
      <lfs_update>-last_changed_by       = lv_user.
      <lfs_update>-last_changed_at       = lv_now.
      <lfs_update>-local_last_changed_at = lv_now.
    ENDLOOP.

    modify_table( it_table = lt_update ).

  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

  METHOD modify_table.
    MODIFY ztar_i002_item FROM TABLE @it_table.
  ENDMETHOD.

ENDCLASS.
