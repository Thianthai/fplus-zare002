CLASS zcl_zare002_sfdc_result DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      "! 1 record = 1 item บน cgcloud__Order_Payment__c (= 1 subrequest ใน composite)
      BEGIN OF ty_record,
        item_sf_id    TYPE ztar_i002_item-salesforce_item_id,
        header_sf_id  TYPE ztar_i002_pymt-salesforce_id,
        status        TYPE string,
        reject_reason TYPE ztar_i002_item-reject_reason,
        batch_id      TYPE ztar_i002_pymt-request_id,
        response_date TYPE string,
      END OF ty_record,
      tt_record TYPE STANDARD TABLE OF ty_record WITH EMPTY KEY,

      "! ผลของ 1 composite call — โครงนี้เอาไปเขียน log table ทีหลังได้ตรง ๆ (OQ-4)
      BEGIN OF ty_result,
        http_status   TYPE i,
        success       TYPE abap_bool,
        record_count  TYPE i,
        error_code    TYPE string,
        error_message TYPE string,
        error_index   TYPE i,
      END OF ty_result.

    CONSTANTS:
      "! ค่า picklist BST_SAP_Status__c — case-sensitive
      gc_status_rejected   TYPE string VALUE 'Rejected',
      gc_status_completed  TYPE string VALUE 'Completed',
      "! limit ของ Composite API — subrequest ต่อ call
      gc_max_records       TYPE i      VALUE 25,
      "! error_code ที่ class นี้สร้างเอง (ไม่ได้มาจาก SFDC)
      gc_err_not_reachable TYPE string VALUE 'NOT_REACHABLE',
      gc_err_too_many      TYPE string VALUE 'TOO_MANY_RECORDS',
      gc_err_parse         TYPE string VALUE 'PARSE_ERROR'.

    "! สร้าง JSON ของ Composite API: allOrNone + 1 PATCH subrequest ต่อ record
    "! ใช้ builder เพราะ transformation อัตโนมัติจะทำชื่อ `__c` พัง และ escape ข้อความให้
    "! ไม่ส่ง reject reason ถ้าว่าง (field เป็น conditional)
    CLASS-METHODS build_payload
      IMPORTING it_record      TYPE tt_record
      RETURNING VALUE(rv_json) TYPE string.

    "! อ่าน compositeResponse — สำเร็จเมื่อ HTTP 200 และทุก subrequest เป็น 204
    "! ถ้าพัง หา error ต้นเหตุตัวแรกโดยข้าม PROCESSING_HALTED (ผลพวงของ allOrNone rollback)
    "! HTTP ≠ 200 (เช่น 401) body เป็น array ของ error ระดับบน อ่านได้เหมือนกัน
    CLASS-METHODS parse_response
      IMPORTING iv_json          TYPE string
                iv_http_status   TYPE i
      RETURNING VALUE(rs_result) TYPE ty_result.

    "! เวลาปัจจุบันในรูปแบบที่ SFDC ต้องการ `YYYY-MM-DDThh:mm:ss+0700` (spec IN #3)
    CLASS-METHODS build_response_date
      RETURNING VALUE(rv_date) TYPE string.

    "! POST composite 1 ครั้งผ่าน Communication Arrangement แล้วอ่านผล
    "! ไม่โยน exception — ต่อไม่ถึงคืน http_status 0 + NOT_REACHABLE ให้ผู้เรียกตัดสินเอง
    METHODS send
      IMPORTING it_record        TYPE tt_record
      RETURNING VALUE(rs_result) TYPE ty_result.

    "! GET /services/data/ — 200 = arrangement + OAuth ใช้ได้ · 401 = id/secret ผิด · 0 = ต่อไม่ถึง
    METHODS check_connection
      RETURNING VALUE(rv_status) TYPE i.

  PRIVATE SECTION.

    CONSTANTS:
      gc_comm_scenario   TYPE sxco_cds_object_name VALUE 'ZCS_REJECT_RESULT',
      gc_service_id      TYPE c LENGTH 40          VALUE 'ZARE002_REJECT_RESULT_REST',
      gc_path_composite  TYPE string VALUE '/services/data/v66.0/composite',
      gc_path_sobject    TYPE string VALUE '/services/data/v66.0/sobjects/cgcloud__Order_Payment__c/',
      gc_path_ping       TYPE string VALUE '/services/data/',
      gc_sobject_type    TYPE string VALUE 'cgcloud__Order_Payment__c',

      "! ชื่อ field API — ยืนยันจาก describe ของ SFDC sandbox 2026-09-20 (OQ-30 ปิด)
      gc_fld_collection  TYPE string VALUE 'BST_PaymentCollection__c',
      gc_fld_status      TYPE string VALUE 'BST_SAP_Status__c',
      gc_fld_reason      TYPE string VALUE 'BST_SAP_RejectReason__c',
      gc_fld_batch       TYPE string VALUE 'BST_SAP_BatchId__c',
      gc_fld_date        TYPE string VALUE 'BST_SAP_ResponseDate__c',

      gc_http_ok         TYPE i      VALUE 200,
      gc_http_no_content TYPE i      VALUE 204,
      "! subrequest ที่ไม่ได้ผิดเองแต่โดน rollback เพราะ allOrNone — ไม่ใช่ต้นเหตุ
      gc_halted          TYPE string VALUE 'PROCESSING_HALTED',

      "! ประเทศไทย UTC+7 ไม่มี DST — ถ้า tenant / ธุรกิจย้าย time zone แก้ 2 ค่านี้พร้อมกัน
      gc_tz_offset_hours TYPE i      VALUE 7,
      gc_tz_offset_text  TYPE string VALUE '+0700'.

    TYPES:
      BEGIN OF ty_error,
        error_code TYPE string,
        message    TYPE string,
        index      TYPE i,
      END OF ty_error,
      tt_error TYPE STANDARD TABLE OF ty_error WITH EMPTY KEY.

    "! สร้าง HTTP client ผ่าน Communication Arrangement (OAuth อยู่ที่ platform)
    METHODS create_client
      RETURNING VALUE(ro_client) TYPE REF TO if_web_http_client
      RAISING   cx_http_dest_provider_error
                cx_web_http_client_error.

ENDCLASS.


CLASS zcl_zare002_sfdc_result IMPLEMENTATION.

  METHOD build_payload.

    DATA(lo_builder) = xco_cp_json=>data->builder( ).

    lo_builder->begin_object(
      )->add_member( 'allOrNone'        )->add_boolean( abap_true
      )->add_member( 'compositeRequest' )->begin_array( ).

    LOOP AT it_record INTO DATA(ls_record).
      DATA(lv_index) = sy-tabix.

      lo_builder->begin_object(
        )->add_member( 'method'      )->add_string( 'PATCH'
        )->add_member( 'url'         )->add_string( |{ gc_path_sobject }{ ls_record-item_sf_id }|
        )->add_member( 'referenceId' )->add_string( |item{ lv_index }|
        )->add_member( 'body'        )->begin_object(
          )->add_member( gc_fld_collection )->add_string( CONV #( ls_record-header_sf_id )
          )->add_member( gc_fld_status     )->add_string( ls_record-status
          )->add_member( gc_fld_batch      )->add_string( CONV #( ls_record-batch_id )
          )->add_member( gc_fld_date       )->add_string( ls_record-response_date ).

      IF ls_record-reject_reason IS NOT INITIAL.
        lo_builder->add_member( gc_fld_reason )->add_string( CONV #( ls_record-reject_reason ) ).
      ENDIF.

      lo_builder->end_object( )->end_object( ).
    ENDLOOP.

    rv_json = lo_builder->end_array( )->end_object( )->get_data( )->to_string( ).

  ENDMETHOD.


  METHOD parse_response.

    rs_result-http_status = iv_http_status.

    " เดิน JSON ด้วย sXML เพราะ body ของ subrequest เป็น null ตอนสำเร็จ / array ตอนพัง
    " (polymorphic) ซึ่ง write_to โครงสร้างคงที่รับไม่ได้
    DATA lt_status TYPE STANDARD TABLE OF i WITH EMPTY KEY.
    DATA lt_error  TYPE tt_error.
    DATA lv_member TYPE string.
    FIELD-SYMBOLS <lfs_error> TYPE ty_error.

    TRY.
        DATA(lo_reader) = cl_sxml_string_reader=>create(
                            cl_abap_conv_codepage=>create_out( )->convert( iv_json ) ).

        DO.
          DATA(lo_node) = lo_reader->read_next_node( ).
          IF lo_node IS INITIAL.
            EXIT.
          ENDIF.

          CASE lo_node->type.

            WHEN if_sxml_node=>co_nt_element_open.
              DATA(lo_open) = CAST if_sxml_open_element( lo_node ).
              CLEAR lv_member.
              LOOP AT lo_open->get_attributes( ) INTO DATA(lo_attribute).
                IF lo_attribute->qname-name = 'name'.
                  lv_member = lo_attribute->get_value( ).
                ENDIF.
              ENDLOOP.
              " ทุก object เป็น error ที่เป็นไปได้ — ตัวที่ไม่มี errorCode จะถูกทิ้งตอนท้าย
              IF lo_open->qname-name = 'object'.
                APPEND INITIAL LINE TO lt_error ASSIGNING <lfs_error>.
                <lfs_error>-index = lines( lt_status ) + 1.
              ENDIF.

            WHEN if_sxml_node=>co_nt_value.
              DATA(lv_value) = CAST if_sxml_value_node( lo_node )->get_value( ).
              CASE lv_member.
                WHEN 'httpStatusCode'.
                  APPEND CONV i( lv_value ) TO lt_status.
                WHEN 'errorCode'.
                  IF <lfs_error> IS ASSIGNED.
                    <lfs_error>-error_code = lv_value.
                  ENDIF.
                WHEN 'message'.
                  IF <lfs_error> IS ASSIGNED.
                    <lfs_error>-message = lv_value.
                  ENDIF.
              ENDCASE.
              CLEAR lv_member.

          ENDCASE.
        ENDDO.

      CATCH cx_root.
        rs_result-success    = abap_false.
        rs_result-error_code = gc_err_parse.
        RETURN.
    ENDTRY.

    DELETE lt_error WHERE error_code IS INITIAL.
    rs_result-record_count = lines( lt_status ).

    " ไม่มีทั้ง subrequest status และ error = body ไม่ใช่รูปแบบที่รู้จัก (เช่น HTML จาก gateway)
    IF lt_status IS INITIAL AND lt_error IS INITIAL.
      rs_result-success       = abap_false.
      rs_result-error_code    = gc_err_parse.
      rs_result-error_message = substring( val = iv_json
                                           len = nmin( val1 = strlen( iv_json ) val2 = 100 ) ).
      RETURN.
    ENDIF.

    " สำเร็จ = call 200 และทุก subrequest 204
    DATA(lv_all_no_content) = abap_true.
    LOOP AT lt_status INTO DATA(lv_status) WHERE table_line <> gc_http_no_content.
      lv_all_no_content = abap_false.
      EXIT.
    ENDLOOP.

    IF iv_http_status = gc_http_ok
       AND lt_status IS NOT INITIAL
       AND lv_all_no_content = abap_true.
      rs_result-success = abap_true.
      RETURN.
    ENDIF.

    rs_result-success = abap_false.

    " error ต้นเหตุ = ตัวแรกที่ไม่ใช่ PROCESSING_HALTED · ถ้าไม่มีเลยเอาตัวแรก
    READ TABLE lt_error INTO DATA(ls_error) WITH KEY error_code = gc_halted.
    LOOP AT lt_error INTO ls_error WHERE error_code <> gc_halted.
      EXIT.
    ENDLOOP.
    IF sy-subrc <> 0.
      READ TABLE lt_error INTO ls_error INDEX 1.
    ENDIF.

    rs_result-error_code    = ls_error-error_code.
    rs_result-error_message = ls_error-message.
    rs_result-error_index   = COND #( WHEN iv_http_status = gc_http_ok THEN ls_error-index ELSE 0 ).

  ENDMETHOD.


  METHOD build_response_date.

    DATA lv_timestamp TYPE timestamp.
    DATA lv_date      TYPE d.
    DATA lv_time      TYPE t.

    GET TIME STAMP FIELD lv_timestamp.                                     " UTC
    lv_timestamp = cl_abap_tstmp=>add( tstmp = lv_timestamp
                                       secs  = gc_tz_offset_hours * 3600 ).
    CONVERT TIME STAMP lv_timestamp TIME ZONE 'UTC' INTO DATE lv_date TIME lv_time.

    rv_date = |{ lv_date(4) }-{ lv_date+4(2) }-{ lv_date+6(2) }T| &&
              |{ lv_time(2) }:{ lv_time+2(2) }:{ lv_time+4(2) }{ gc_tz_offset_text }|.

  ENDMETHOD.


  METHOD send.

    rs_result-record_count = lines( it_record ).

    IF it_record IS INITIAL.
      rs_result-success = abap_true.
      RETURN.
    ENDIF.

    IF lines( it_record ) > gc_max_records.
      rs_result-success    = abap_false.
      rs_result-error_code = gc_err_too_many.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_client)  = create_client( ).
        DATA(lo_request) = lo_client->get_http_request( ).

        lo_request->set_uri_path( gc_path_composite ).
        lo_request->set_header_field( i_name  = 'Content-Type'
                                      i_value = 'application/json' ).
        lo_request->set_text( build_payload( it_record ) ).

        DATA(lo_response) = lo_client->execute( if_web_http_client=>post ).

        rs_result = parse_response( iv_json        = lo_response->get_text( )
                                    iv_http_status = lo_response->get_status( )-code ).
        rs_result-record_count = lines( it_record ).

        lo_client->close( ).

      CATCH cx_root.
        " ต่อไม่ถึง หรือ Communication Arrangement พัง
        rs_result-http_status = 0.
        rs_result-success     = abap_false.
        rs_result-error_code  = gc_err_not_reachable.
    ENDTRY.

  ENDMETHOD.


  METHOD check_connection.

    TRY.
        DATA(lo_client) = create_client( ).
        lo_client->get_http_request( )->set_uri_path( gc_path_ping ).

        DATA(lo_response) = lo_client->execute( if_web_http_client=>get ).
        rv_status = lo_response->get_status( )-code.

        lo_client->close( ).

      CATCH cx_root.
        rv_status = 0.
    ENDTRY.

  ENDMETHOD.


  METHOD create_client.

    DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                             comm_scenario = gc_comm_scenario
                             service_id    = gc_service_id ).

    ro_client = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

  ENDMETHOD.

ENDCLASS.
