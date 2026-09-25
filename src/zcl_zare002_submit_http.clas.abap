"! API ของปุ่ม Submit
"! Fiori ส่ง list PaymentUuid เข้ามา post ทีละใบผ่าน ZCL_ZARE002_SUBMIT และได้ผลลัพธิ์ตอบกลับต่อใบ
"! 1 PaymentUuid ต่อ 1 LUW ใบที่ไม่ผ่านจะไม่กระทบใบอื่น
"! tenant นี้ไม่บังคับ CSRF — GET x-csrf-token: fetch คืน null และ POST ผ่านโดยไม่มี token
"! JSON key เป็น PascalCase
CLASS zcl_zare002_submit_http DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_service_extension.

    TYPES:
      "! request: {"Payments": ["<uuid>", ...]} — uuid รับทั้ง 36 ตัวมีขีด และ 32 ตัวไม่มีขีด
      tt_uuid_text TYPE STANDARD TABLE OF string WITH EMPTY KEY,

      BEGIN OF ty_request,
        payments TYPE tt_uuid_text,
      END OF ty_request,

      "! uuid ที่แปลงแล้ว ไม่ซ้ำ
      tt_uuid TYPE STANDARD TABLE OF sysuuid_x16 WITH EMPTY KEY,

      "! response ต่อใบ
      BEGIN OF ty_result_line,
        payment_uuid        TYPE string,
        payment_document_no TYPE string,
        outcome             TYPE string,
        accounting_document TYPE string,
        message             TYPE string,
      END OF ty_result_line,
      tt_result_line TYPE STANDARD TABLE OF ty_result_line WITH EMPTY KEY,

      "! response ทั้งก้อน
      "! Status S = มีใบที่สำเร็จอย่างน้อย 1 ใบ
      "! Status E = ไม่สำเร็จเลย หรือ body ผิดรูปแบบ
      "! Success = outcome P + A
      "! Error = outcome E
      BEGIN OF ty_response,
        status  TYPE string,
        message TYPE string,
        success TYPE i,
        error   TYPE i,
        results TYPE tt_result_line,
      END OF ty_response,

      "! ตัวอย่างที่ GET ตอบกลับ ไว้ให้ caller ดูโครงสร้างโดยไม่ต้องเปิดเอกสาร
      BEGIN OF ty_usage,
        service  TYPE string,
        method   TYPE string,
        request  TYPE ty_request,
        response TYPE ty_response,
        outcome  TYPE tt_uuid_text,
        note     TYPE tt_uuid_text,
      END OF ty_usage.

    CONSTANTS:
      "! จำนวนใบสูงสุดต่อ 1 request — กัน timeout ฝั่ง browser (post ต่อใบ ~1 วินาที)
      gc_max_payments   TYPE i       VALUE 60,

      gc_msgid          TYPE symsgid VALUE 'ZARE002',

      "! Status ของ response ทั้งก้อน
      "! S = มีใบที่สำเร็จอย่างน้อย 1 ใบ
      "! E = ไม่สำเร็จเลย หรือ body ผิดรูปแบบ
      gc_status_success TYPE string  VALUE 'S',
      gc_status_error   TYPE string  VALUE 'E'.

    "! แปลง body เป็น list uuid
    "! คืน ev_error = ผิดรูปแบบ / ว่าง / เกินค่า max (et_payment_uuid ว่าง)
    "! แยกเป็น static ไว้ทดสอบโดยไม่ต้องมี request จริง
    CLASS-METHODS parse_request
      IMPORTING iv_body         TYPE string
      EXPORTING et_payment_uuid TYPE tt_uuid
                ev_error        TYPE string.

    "! สร้าง response JSON จากผลของ ZCL_ZARE002_SUBMIT
    CLASS-METHODS build_response
      IMPORTING it_result      TYPE zcl_zare002_submit=>tt_result
      RETURNING VALUE(rv_json) TYPE string.

  PRIVATE SECTION.

    "! GET = ตัวอย่าง request และ response ไว้ให้ caller ดูโครงสร้าง
    "! ใช้เช็คว่า service ทำงานอยู่ได้ด้วย
    "! ไม่แตะข้อมูล
    METHODS handle_get
      CHANGING co_response TYPE REF TO if_web_http_response.

    "! POST = parse > process ทีละใบ
    "! คืน HTTP status 200 = body ถูก
    "! คืน HTTP status 400 = body ผิด
    METHODS handle_post
      IMPORTING io_request  TYPE REF TO if_web_http_request
      CHANGING  co_response TYPE REF TO if_web_http_response.

    "! คืน JSON พร้อม status
    METHODS reply
      IMPORTING iv_status   TYPE i
                iv_reason   TYPE string
                iv_json     TYPE string
      CHANGING  co_response TYPE REF TO if_web_http_response.

    "! text uuid (36 มีขีด / 32 ไม่มีขีด)
    "! คืน abap_false = ผิดรูปแบบ
    CLASS-METHODS to_uuid
      IMPORTING iv_text      TYPE string
      EXPORTING ev_uuid      TYPE sysuuid_x16
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    "! text ของ message class — MESSAGE ... INTO
    "! placeholder ละไม่เกิน 50 ตัว
    CLASS-METHODS message_text
      IMPORTING iv_number      TYPE symsgno
                iv_v1          TYPE simple OPTIONAL
                iv_v2          TYPE simple OPTIONAL
      RETURNING VALUE(rv_text) TYPE string.

    "! สร้าง response ของเคส body ผิดรูปแบบ
    "! ใช้โครงเดียวกับเคสปกติ ฝั่ง Fiori จะได้อ่าน Status กับ Message ที่เดียว
    CLASS-METHODS build_error_response
      IMPORTING iv_message     TYPE string
      RETURNING VALUE(rv_json) TYPE string.

ENDCLASS.


CLASS zcl_zare002_submit_http IMPLEMENTATION.

  METHOD if_http_service_extension~handle_request.

    CASE request->get_method( ).
      WHEN 'GET'.
        handle_get( CHANGING co_response = response ).

      WHEN 'POST'.
        handle_post( EXPORTING io_request  = request
                     CHANGING  co_response = response ).

      WHEN OTHERS.
        response->set_status( i_code   = 405
                              i_reason = 'Method Not Allowed' ).

    ENDCASE.

  ENDMETHOD.


  METHOD handle_get.

    " ตัวอย่างล้วน ไม่ได้อ่านจาก DB
    " PaymentUuid ใส่ทั้งแบบ 36 ตัวมีขีด และ 32 ตัวไม่มีขีด เพื่อบอกว่ารับได้ทั้งสองแบบ
    DATA(ls_usage) = VALUE ty_usage(
      service = `ZARE002_SUBMIT`
      method  = `POST /sap/bc/http/sap/ZARE002_SUBMIT`

      request = VALUE #( payments = VALUE #( ( `FA163E19-5F2E-1FE1-AAE6-A0E51561A3EF` )
                                             ( `FA163E195F2E1FE1AAE6A0E51561A3F0` ) ) )

      response = VALUE #(
        status  = `S`
        message = `Payments posted successfully: Success 1 / Error 1`
        success = 1
        error   = 1
        results = VALUE #(
          ( payment_uuid        = `FA163E19-5F2E-1FE1-AAE6-A0E51561A3EF`
            payment_document_no = `1000000002`
            outcome             = `P`
            accounting_document = `3200000010`
            message             = `Payment 1000000002 posted: document 3200000010` )
          ( payment_uuid        = `FA163E19-5F2E-1FE1-AAE6-A0E51561A3F0`
            payment_document_no = `1000000003`
            outcome             = `E`
            accounting_document = ``
            message             = `Payment 1000000003: cheque must be posted manually` ) ) )

      outcome = VALUE #( ( `Status S = สำเร็จอย่างน้อย 1 ใบ` )
                         ( `Status E = ไม่สำเร็จเลย หรือ body ผิด format` )
                         ( `P = post สำเร็จรอบนี้` )
                         ( `A = เคย post ไว้แล้ว รอ clearing` )
                         ( `E = ไม่ผ่าน ดูเหตุผลที่ Message` )
                         ( |Success = P + A, Error = E| ) )

      note = VALUE #( ( |สูงสุด { gc_max_payments } ใบต่อ 1 request, PaymentUuid ซ้ำถูกตัดอัตโนมัติ| )
                      ( `ต่อใบใช้เวลาประมาณ 1 วินาที ตั้ง timeout ฝั่ง client ให้พอ` )
                      ( `ใบที่ไม่ผ่านไม่กระทบใบอื่น body ถูกต้องจะได้ 200 เสมอ` )
                      ( `body ผิด format ได้ 400 ได้ Status เป็น E และได้ Results ว่าง` )
                      ( `ไม่ต้องใช้ CSRF token` ) ) ).

    reply( EXPORTING iv_status   = 200
                     iv_reason   = 'OK'
                     iv_json     = xco_cp_json=>data->from_abap( ls_usage
                                     )->apply( VALUE #( ( xco_cp_json=>transformation->underscore_to_pascal_case ) )
                                     )->to_string( )
           CHANGING  co_response = co_response ).

  ENDMETHOD.


  METHOD handle_post.

    DATA lt_result TYPE zcl_zare002_submit=>tt_result.

    parse_request( EXPORTING iv_body         = io_request->get_text( )
                   IMPORTING et_payment_uuid = DATA(lt_payment_uuid)
                             ev_error        = DATA(lv_error) ).

    IF lv_error IS NOT INITIAL.
      reply( EXPORTING iv_status   = 400
                       iv_reason   = 'Bad Request'
                       iv_json     = build_error_response( lv_error )
             CHANGING  co_response = co_response ).
      RETURN.
    ENDIF.

    " 1 PaymentUuid ต่อ 1 LUW — ZCL_ZARE002_SUBMIT commit เองทุกใบ
    DATA(lo_submit) = NEW zcl_zare002_submit( ).

    LOOP AT lt_payment_uuid INTO DATA(lv_payment_uuid).
      DATA(ls_result) = lo_submit->process( lv_payment_uuid ).

      APPEND ls_result TO lt_result.
    ENDLOOP.

    reply( EXPORTING iv_status   = 200
                     iv_reason   = 'OK'
                     iv_json     = build_response( lt_result )
           CHANGING  co_response = co_response ).

  ENDMETHOD.


  METHOD reply.

    co_response->set_header_field( i_name  = 'Content-Type'
                                   i_value = 'application/json' ).

    co_response->set_status( i_code   = iv_status
                             i_reason = iv_reason ).

    co_response->set_text( iv_json ).

  ENDMETHOD.


  METHOD parse_request.

    DATA ls_request TYPE ty_request.
    DATA lv_uuid TYPE sysuuid_x16.

    CLEAR: et_payment_uuid, ev_error.

    TRY.
        xco_cp_json=>data->from_string( iv_body
          )->apply( VALUE #( ( xco_cp_json=>transformation->pascal_case_to_underscore ) )
          )->write_to( REF #( ls_request ) ).
      CATCH cx_root.
        ev_error = `Body is not valid JSON`.
        RETURN.
    ENDTRY.

    IF ls_request-payments IS INITIAL.
      ev_error = `Payments is empty`.
      RETURN.
    ENDIF.

    IF lines( ls_request-payments ) > gc_max_payments.
      ev_error = |Too many payments ({ lines( ls_request-payments ) }), maximum { gc_max_payments }|.
      RETURN.
    ENDIF.

    LOOP AT ls_request-payments INTO DATA(lv_text).
      IF to_uuid( EXPORTING iv_text = lv_text IMPORTING ev_uuid = lv_uuid ) = abap_false.
        CLEAR et_payment_uuid.
        ev_error = |Invalid PaymentUuid: { lv_text }|.
        RETURN.
      ENDIF.
      APPEND lv_uuid TO et_payment_uuid.
    ENDLOOP.

    " PaymentUuid ซ้ำใน request เดียว = ทำครั้งเดียว
    SORT et_payment_uuid.
    DELETE ADJACENT DUPLICATES FROM et_payment_uuid.

  ENDMETHOD.


  METHOD to_uuid.

    CLEAR ev_uuid.

    rv_ok = abap_false.

    DATA(lv_text) = to_upper( condense( iv_text ) ).

    TRY.
        CASE strlen( lv_text ).
          WHEN 36.
            cl_system_uuid=>convert_uuid_c36_static( EXPORTING uuid     = CONV sysuuid_c36( lv_text )
                                                     IMPORTING uuid_x16 = ev_uuid ).

          WHEN 32.
            cl_system_uuid=>convert_uuid_c32_static( EXPORTING uuid     = CONV sysuuid_c32( lv_text )
                                                     IMPORTING uuid_x16 = ev_uuid ).

          WHEN OTHERS.
            RETURN.

        ENDCASE.

        rv_ok = abap_true.

      CATCH cx_uuid_error.
        CLEAR ev_uuid.
    ENDTRY.

  ENDMETHOD.


  METHOD build_response.

    DATA ls_response TYPE ty_response.
    DATA lv_uuid_c36 TYPE sysuuid_c36.

    LOOP AT it_result INTO DATA(ls_result).
      TRY.
          cl_system_uuid=>convert_uuid_x16_static( EXPORTING uuid     = ls_result-payment_uuid
                                                   IMPORTING uuid_c36 = lv_uuid_c36 ).
        CATCH cx_uuid_error.
          lv_uuid_c36 = |{ ls_result-payment_uuid }|.
      ENDTRY.

      APPEND VALUE #( payment_uuid        = lv_uuid_c36
                      payment_document_no = ls_result-payment_document_no
                      outcome             = ls_result-outcome
                      accounting_document = ls_result-accounting_document
                      message             = ls_result-message ) TO ls_response-results.

      IF ls_result-outcome = zcl_zare002_submit=>gc_outcome_error.
        ls_response-error += 1.
      ELSE.
        ls_response-success += 1.
      ENDIF.
    ENDLOOP.

    " สรุปผลรวมให้ Fiori เอาไปขึ้น popup ได้ทันที ไม่ต้องนับเอง
    " สำเร็จอย่างน้อย 1 ใบ ถือว่า Status เป็น S ถึงจะมีใบที่ตกปนมาก็ตาม
    IF ls_response-success = 0.
      ls_response-status  = gc_status_error.
      ls_response-message = message_text( iv_number = '112'
                                          iv_v1     = |{ ls_response-error }| ).
    ELSEIF ls_response-error = 0.
      ls_response-status  = gc_status_success.
      ls_response-message = message_text( iv_number = '110'
                                          iv_v1     = |{ ls_response-success }| ).
    ELSE.
      ls_response-status  = gc_status_success.
      ls_response-message = message_text( iv_number = '111'
                                          iv_v1     = |{ ls_response-success }|
                                          iv_v2     = |{ ls_response-error }| ).
    ENDIF.

    rv_json = xco_cp_json=>data->from_abap( ls_response
                )->apply( VALUE #( ( xco_cp_json=>transformation->underscore_to_pascal_case ) )
                )->to_string( ).

  ENDMETHOD.


  METHOD message_text.

    MESSAGE ID gc_msgid TYPE 'I' NUMBER iv_number WITH iv_v1 iv_v2 INTO rv_text.

  ENDMETHOD.


  METHOD build_error_response.

    " ไม่มีใบไหนถูกประมวลผลเลย จำนวนทั้งสองฝั่งจึงเป็น 0 และ Results ว่าง
    rv_json = xco_cp_json=>data->from_abap( VALUE ty_response( status  = gc_status_error
                                                               message = iv_message )
                )->apply( VALUE #( ( xco_cp_json=>transformation->underscore_to_pascal_case ) )
                )->to_string( ).

  ENDMETHOD.

ENDCLASS.
