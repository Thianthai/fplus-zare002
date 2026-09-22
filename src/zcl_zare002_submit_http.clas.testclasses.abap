"! ทดสอบ parse / response อย่างเดียว — ไม่ต่อ HTTP ไม่ post
CLASS ltc_submit_http DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    "! uuid 36 มีขีด และ 32 ไม่มีขีด → x16 ตัวเดียวกัน · ซ้ำถูกตัด
    METHODS parse_accepts_both_formats FOR TESTING.
    "! body ไม่ใช่ JSON / Payments ว่าง → error
    METHODS parse_rejects_bad_body     FOR TESTING.
    "! uuid ผิดรูปแบบ → error และไม่คืน list บางส่วน
    METHODS parse_rejects_bad_uuid     FOR TESTING.
    "! นับ Success (P+A) / Error (E) และ key เป็น PascalCase
    METHODS response_counts_outcomes   FOR TESTING.
ENDCLASS.


CLASS ltc_submit_http IMPLEMENTATION.

  METHOD parse_accepts_both_formats.
    zcl_zare002_submit_http=>parse_request(
      EXPORTING iv_body         = `{"Payments":["0050568A-1234-1EEF-8A9B-0123456789AB","0050568a12341eef8a9b0123456789ab"]}`
      IMPORTING et_payment_uuid = DATA(lt_uuid)
                ev_error        = DATA(lv_error) ).

    cl_abap_unit_assert=>assert_initial( lv_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_uuid ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = |{ lt_uuid[ 1 ] }| exp = '0050568A12341EEF8A9B0123456789AB' ).
  ENDMETHOD.

  METHOD parse_rejects_bad_body.
    zcl_zare002_submit_http=>parse_request( EXPORTING iv_body  = `not json`
                                            IMPORTING ev_error = DATA(lv_error) ).
    cl_abap_unit_assert=>assert_not_initial( lv_error ).

    zcl_zare002_submit_http=>parse_request( EXPORTING iv_body  = `{"Payments":[]}`
                                            IMPORTING ev_error = lv_error ).
    cl_abap_unit_assert=>assert_equals( act = lv_error exp = `Payments is empty` ).
  ENDMETHOD.

  METHOD parse_rejects_bad_uuid.
    zcl_zare002_submit_http=>parse_request(
      EXPORTING iv_body         = `{"Payments":["0050568A-1234-1EEF-8A9B-0123456789AB","1000000002"]}`
      IMPORTING et_payment_uuid = DATA(lt_uuid)
                ev_error        = DATA(lv_error) ).

    cl_abap_unit_assert=>assert_true( xsdbool( lv_error CS 'Invalid PaymentUuid' ) ).
    cl_abap_unit_assert=>assert_initial( lt_uuid ).
  ENDMETHOD.

  METHOD response_counts_outcomes.
    DATA(lt_result) = VALUE zcl_zare002_submit=>tt_result(
      ( payment_document_no = '1000000001' outcome = 'P' accounting_document = '3200000010' message = 'posted' )
      ( payment_document_no = '1000000002' outcome = 'A' accounting_document = '3200000011' message = 'already' )
      ( payment_document_no = '1000000003' outcome = 'E' message = 'cheque' ) ).

    DATA(lv_json) = zcl_zare002_submit_http=>build_response( lt_result ).

    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS `"Success":2` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS `"Error":1` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS `"PaymentDocumentNo":"1000000003"` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_json CS `"AccountingDocument":"3200000010"` ) ).
  ENDMETHOD.

ENDCLASS.
