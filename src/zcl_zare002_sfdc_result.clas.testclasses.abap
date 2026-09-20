CLASS ltc_sfdc_result DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    METHODS sample_records
      RETURNING VALUE(rt_record) TYPE zcl_zare002_sfdc_result=>tt_record.

    "! payload เป็น Composite API: allOrNone + compositeRequest + PATCH + url ต่อ item
    METHODS payload_is_composite_shape  FOR TESTING.
    "! ชื่อ field ตรง spec ทั้ง 5 ตัว
    METHODS payload_uses_spec_fields    FOR TESTING.
    "! reject reason ว่าง → ไม่ส่ง key
    METHODS payload_omits_empty_reason  FOR TESTING.
    "! ข้อความมี " ต้องถูก escape ไม่ทำ JSON พัง
    METHODS payload_escapes_quotes      FOR TESTING.
    "! ทุก subrequest 204 → success
    METHODS parse_all_204_is_success    FOR TESTING.
    "! allOrNone rollback: ข้าม PROCESSING_HALTED ไปหาต้นเหตุ + index ถูก
    METHODS parse_finds_root_cause      FOR TESTING.
    "! HTTP 401 body เป็น error ระดับบน → อ่าน errorCode ได้
    METHODS parse_non_200_is_failure    FOR TESTING.
    "! JSON พัง → PARSE_ERROR ไม่ dump
    METHODS parse_garbage_is_parse_err  FOR TESTING.
    "! วันที่ตรงรูปแบบ YYYY-MM-DDThh:mm:ss+0700
    METHODS response_date_has_format    FOR TESTING.

ENDCLASS.


CLASS ltc_sfdc_result IMPLEMENTATION.

  METHOD sample_records.
    rt_record = VALUE #(
      ( item_sf_id = 'a2JAz000000TQ0jMAG' header_sf_id = 'a5jAz0000003QNlIAM'
        status = zcl_zare002_sfdc_result=>gc_status_rejected
        reject_reason = 'Wrong Amount' batch_id = '20260815_090039'
        response_date = '2026-08-27T10:15:30+0700' )
      ( item_sf_id = 'a2JAz000000TQ0kMAG' header_sf_id = 'a5jAz0000003QNlIAM'
        status = zcl_zare002_sfdc_result=>gc_status_rejected
        reject_reason = 'Duplicate' batch_id = '20260815_090039'
        response_date = '2026-08-27T10:15:30+0700' ) ).
  ENDMETHOD.

  METHOD payload_is_composite_shape.
    DATA(lv_json) = zcl_zare002_sfdc_result=>build_payload( sample_records( ) ).

    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS '"allOrNone"' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS 'true' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS '"compositeRequest"' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS '"PATCH"' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS '/sobjects/cgcloud__Order_Payment__c/a2JAz000000TQ0jMAG' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS '"item1"' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS '"item2"' ) ).
  ENDMETHOD.

  METHOD payload_uses_spec_fields.
    DATA(lv_json) = zcl_zare002_sfdc_result=>build_payload( sample_records( ) ).

    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS '"BST_Payment_Collection__c"' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS '"BST_SAP_Status__c"' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS '"BST_SAP_Reject_Reason__c"' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS '"BST_SAP_Batch_Id__c"' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS '"BST_SAP_Response_Date__c"' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS '"Rejected"' ) ).
  ENDMETHOD.

  METHOD payload_omits_empty_reason.
    DATA(lt_record) = sample_records( ).
    DELETE lt_record INDEX 2.
    CLEAR lt_record[ 1 ]-reject_reason.

    DATA(lv_json) = zcl_zare002_sfdc_result=>build_payload( lt_record ).

    cl_abap_unit_assert=>assert_false( xsdbool( lv_json CS 'BST_SAP_Reject_Reason__c' ) ).
  ENDMETHOD.

  METHOD payload_escapes_quotes.
    DATA(lt_record) = sample_records( ).
    lt_record[ 1 ]-reject_reason = 'Amount "wrong"'.

    DATA(lv_json) = zcl_zare002_sfdc_result=>build_payload( lt_record ).

    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS 'Amount \"wrong\"' ) ).
  ENDMETHOD.

  METHOD parse_all_204_is_success.
    DATA(lv_json) = '{"compositeResponse":['
                 && '{"body":null,"httpHeaders":{},"httpStatusCode":204,"referenceId":"item1"},'
                 && '{"body":null,"httpHeaders":{},"httpStatusCode":204,"referenceId":"item2"}]}'.

    DATA(ls_result) = zcl_zare002_sfdc_result=>parse_response( iv_json = lv_json iv_http_status = 200 ).

    cl_abap_unit_assert=>assert_true( ls_result-success ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-record_count exp = 2 ).
    cl_abap_unit_assert=>assert_initial( ls_result-error_code ).
  ENDMETHOD.

  METHOD parse_finds_root_cause.
    " item1 ถูกต้องแต่โดน rollback · item2 คือต้นเหตุ
    DATA(lv_json) = '{"compositeResponse":['
                 && '{"body":[{"errorCode":"PROCESSING_HALTED","message":"The transaction was rolled back since another operation in the same transaction failed."}],'
                 && '"httpHeaders":{},"httpStatusCode":400,"referenceId":"item1"},'
                 && '{"body":[{"message":"data value too large: 20260915_105645_1056 (max length=15)","errorCode":"STRING_TOO_LONG","fields":["BST_SAP_Batch_Id__c"]}],'
                 && '"httpHeaders":{},"httpStatusCode":400,"referenceId":"item2"}]}'.

    DATA(ls_result) = zcl_zare002_sfdc_result=>parse_response( iv_json = lv_json iv_http_status = 200 ).

    cl_abap_unit_assert=>assert_false( ls_result-success ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-error_code  exp = 'STRING_TOO_LONG' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-error_index exp = 2 ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_result-error_message CS 'max length=15' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-record_count exp = 2 ).
  ENDMETHOD.

  METHOD parse_non_200_is_failure.
    DATA(lv_json) = `[{"message":"Session expired or invalid","errorCode":"INVALID_SESSION_ID"}]`.

    DATA(ls_result) = zcl_zare002_sfdc_result=>parse_response( iv_json = lv_json iv_http_status = 401 ).

    cl_abap_unit_assert=>assert_false( ls_result-success ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-http_status exp = 401 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-error_code  exp = 'INVALID_SESSION_ID' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-error_index exp = 0 ).
  ENDMETHOD.

  METHOD parse_garbage_is_parse_err.
    DATA(ls_result) = zcl_zare002_sfdc_result=>parse_response( iv_json        = `<html>Gateway timeout</html>`
                                                               iv_http_status = 504 ).

    cl_abap_unit_assert=>assert_false( ls_result-success ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-error_code exp = zcl_zare002_sfdc_result=>gc_err_parse ).
  ENDMETHOD.

  METHOD response_date_has_format.
    DATA(lv_date) = zcl_zare002_sfdc_result=>build_response_date( ).

    cl_abap_unit_assert=>assert_true(
      xsdbool( matches( val  = lv_date
                        pcre = '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+0700$' ) ) ).
  ENDMETHOD.

ENDCLASS.
