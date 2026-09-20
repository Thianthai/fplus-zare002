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

    "! describe cgcloud__Order_Payment__c ผ่าน arrangement แล้ว print field ที่ขึ้นต้น BST_ (ใช้ปิด OQ-30)
    METHODS describe_sfdc_object
      IMPORTING out TYPE REF TO if_oo_adt_classrun_out.

ENDCLASS.



CLASS zcl_zare002_util IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    "! เปิด comment บรรทัดที่ต้องการก่อน F9 — ค่าเริ่มต้นไม่ทำอะไร กันรันพลาด
*    spike_sfdc_api( out ).
*    spike_eml( out ).

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

    " 2. status กลับเป็น N + ล้างผล SFDC เพื่อ Reject ได้อีกรอบ — ลบ block นี้ถ้าอยากคง status เดิม
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

  METHOD describe_sfdc_object.

    TRY.
        DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                                 comm_scenario = 'ZCS_REJECT_RESULT'
                                 service_id    = 'ZARE002_REJECT_RESULT_REST' ).
        DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

        lo_client->get_http_request( )->set_uri_path(
          '/services/data/v66.0/sobjects/cgcloud__Order_Payment__c/describe' ).

        DATA(lo_response) = lo_client->execute( if_web_http_client=>get ).
        DATA(lv_json)     = lo_response->get_text( ).
        out->write( |HTTP { lo_response->get_status( )-code } · { strlen( lv_json ) } chars| ).
        lo_client->close( ).

        " API name ของ field อยู่ใน "name":"..." — เอาเฉพาะที่ขึ้นต้น BST_
        FIND ALL OCCURRENCES OF PCRE '"name":"(BST_[A-Za-z0-9_]+)"'
             IN lv_json RESULTS DATA(lt_match).

        LOOP AT lt_match INTO DATA(ls_match).
          DATA(ls_sub) = ls_match-submatches[ 1 ].
          out->write( substring( val = lv_json off = ls_sub-offset len = ls_sub-length ) ).
        ENDLOOP.

        IF lt_match IS INITIAL.
          out->write( substring( val = lv_json
                                 len = nmin( val1 = strlen( lv_json ) val2 = 800 ) ) ).
        ENDIF.

      CATCH cx_root INTO DATA(lx_error).
        out->write( lx_error->get_text( ) ).
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
