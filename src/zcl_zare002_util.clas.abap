"! utility ทดสอบของ ZARE002 — เขียน DB ตรงข้าม RAP / ยิง SFDC ตรง · ลบทิ้งก่อน handover
"! เลือก method ที่จะรันใน main แล้ว F9
CLASS zcl_zare002_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    "! payment document ที่จะ reset — แก้ค่านี้แล้วรันใหม่ (F9)
    CONSTANTS gc_payment_document_no TYPE c LENGTH 10 VALUE '1000000002'.

    "! reset payment 1 ใบให้ Reject ซ้ำได้ — ล้าง reject_reason ทุก item · status R → N + ล้างผล SFDC · ทิ้ง draft
    METHODS reset_payment
      IMPORTING out TYPE REF TO if_oo_adt_classrun_out.

    "! ขอ token จาก ZCL_UTILITY แล้วยิง describe ผ่าน arrangement Basic ตัวเดียวกัน โดยใส่ Authorization: Bearer เอง
    METHODS test_sfdc_bearer
      IMPORTING out TYPE REF TO if_oo_adt_classrun_out.

ENDCLASS.



CLASS zcl_zare002_util IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    " เปิด comment บรรทัดที่ต้องการก่อน F9 — ค่าเริ่มต้นไม่ทำอะไร กันรันพลาด
*    reset_payment( out ).
*    test_sfdc_bearer( out ).

  ENDMETHOD.

  METHOD reset_payment.

    SELECT SINGLE payment_uuid, status
      FROM ztar_i002_pymt
      WHERE payment_document_no = @gc_payment_document_no
      INTO @DATA(ls_payment).
    IF sy-subrc <> 0.
      out->write( |Payment { gc_payment_document_no } not found| ).
      RETURN.
    ENDIF.

    " 1. ล้าง reject_reason ของ item ทุกตัวในใบนี้
    UPDATE ztar_i002_item
      SET reject_reason = @space
      WHERE payment_uuid = @ls_payment-payment_uuid.
    DATA(lv_item_count) = sy-dbcnt.

    " 2. status กลับเป็น N + ล้างผล SFDC เพื่อ Reject ได้อีกรอบ
    UPDATE ztar_i002_pymt
      SET status             = 'N',
          salesforce_status  = @space,
          salesforce_message = @space
      WHERE payment_uuid = @ls_payment-payment_uuid.

    " 3. ทิ้ง draft ค้างของ item ในใบนี้ (ถ้ามี) กันค่าเก่าโผล่กลับมา
    DELETE FROM ztar_e002_item_d
      WHERE paymentuuid = @ls_payment-payment_uuid.
    DATA(lv_draft_count) = sy-dbcnt.

    COMMIT WORK.

    out->write( |Payment { gc_payment_document_no }: reject_reason cleared on { lv_item_count } item(s), | &&
                |status { ls_payment-status } -> N, { lv_draft_count } draft(s) removed| ).


  ENDMETHOD.

  METHOD test_sfdc_bearer.

    " 1. ขอ token — print แค่สถานะ ห้าม print token
    DATA(ls_token) = zcl_utility=>get_sfdc_token( ).
    out->write( |get_sfdc_token: HTTP { ls_token-http_status } · success { ls_token-success } · | &&
                |token length { strlen( ls_token-access_token ) } · instance { ls_token-instance_url }| ).
    IF ls_token-success = abap_false.
      out->write( |  error: { ls_token-error_code } { ls_token-error_message }| ).
      RETURN.
    ENDIF.

    " 2. describe ผ่าน arrangement token (Basic Auth.) + Bearer ที่เราใส่เอง
    TRY.
        DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                                 comm_scenario = 'ZCS_SFDC_TOKEN'
                                 service_id    = 'ZBC_SFDC_TOKEN_REST' ).
        DATA(lo_client)  = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).
        DATA(lo_request) = lo_client->get_http_request( ).

        lo_request->set_uri_path( '/services/data/v66.0/sobjects/cgcloud__Order_Payment__c/describe' ).
        lo_request->set_header_field( i_name  = 'Authorization'
                                      i_value = |Bearer { ls_token-access_token }| ).

        DATA(lo_response) = lo_client->execute( if_web_http_client=>get ).
        DATA(lv_status)   = lo_response->get_status( )-code.
        DATA(lv_body)     = lo_response->get_text( ).
        lo_client->close( ).

        out->write( |describe via Basic-arrangement + own Bearer: HTTP { lv_status } · { strlen( lv_body ) } chars| ).
        IF lv_status <> 200.
          out->write( |  body: { substring( val = lv_body len = nmin( val1 = strlen( lv_body ) val2 = 200 ) ) }| ).
        ENDIF.

      CATCH cx_root INTO DATA(lx_error).
        out->write( |describe failed: { lx_error->get_text( ) }| ).
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
