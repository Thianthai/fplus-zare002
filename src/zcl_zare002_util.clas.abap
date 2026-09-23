"! utility ทดสอบของ ZARE002 — เขียน DB ตรงข้าม RAP / ยิง SFDC ตรง · ลบทิ้งก่อน handover
"! เลือก method ที่จะรันใน main แล้ว F9
CLASS zcl_zare002_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    CLASS-METHODS class_constructor.

  PRIVATE SECTION.
    "! payment document ที่จะ reset — แก้ list นี้แล้วรันใหม่ (F9) · ใบที่ไม่พบจะบอกใน output ไม่หยุดทำใบอื่น
    TYPES tt_payment_document_no TYPE STANDARD TABLE OF ztar_i002_pymt-payment_document_no WITH EMPTY KEY.

    CLASS-DATA gt_payment_document_no TYPE tt_payment_document_no.

    "! ใบต้นแบบที่ set_test_data จะ clone โครงสร้างมาใช้
    CONSTANTS gc_template_document_no TYPE ztar_i002_pymt-payment_document_no VALUE '1000000002'.

    CONSTANTS:
      "! ค่าของใบทดสอบ ตั้งให้ครบทั้ง 5 ขาบัญชี bank / bank charge / rounding / advance / ลูกหนี้
      "! ดู docs/09_submit_analysis.md หัวข้อเอกสารตัวอย่าง 5 ขา
      gc_test_company_code    TYPE ztar_i002_pymt-company_code        VALUE '2000',
      gc_test_posting_date    TYPE ztar_i002_pymt-posting_date        VALUE '20260922',
      gc_test_gl_account      TYPE ztar_i002_pymt-gl_account          VALUE '0011011211',
      gc_test_payment_method  TYPE ztar_i002_pymt-payment_method      VALUE 'Transfer',
      gc_test_currency        TYPE ztar_i002_pymt-currency            VALUE 'THB',
      gc_test_payment_amount  TYPE ztar_i002_pymt-payment_amount      VALUE '10791.00',
      gc_test_fees            TYPE ztar_i002_pymt-fees                VALUE '10.00',
      gc_test_rounding_diff   TYPE ztar_i002_pymt-rounding_diff       VALUE '1.00',
      gc_test_advance_payment TYPE ztar_i002_pymt-advance_payment     VALUE '100.00',
      gc_test_customer_code   TYPE ztar_i002_item-customer_code       VALUE '1000000014',
      gc_test_acctg_document  TYPE ztar_i002_item-accounting_document VALUE '6000000021',
      gc_test_billing_doc     TYPE ztar_i002_item-billing_document    VALUE 'O600000025',
      gc_test_invoice_amount  TYPE ztar_i002_item-invoice_amount      VALUE '10700.00',
      gc_test_amount_paid     TYPE ztar_i002_item-amount_paid         VALUE '10700.00'.

    "! abap_true = สร้าง payload แล้วพิมพ์ ไม่ post · abap_false = post จริง (ได้เอกสารใหม่ทุกครั้งที่ F9)
    CONSTANTS gc_submit_simulate TYPE abap_bool VALUE abap_true.

    "! สร้างใบทดสอบใหม่ 1 ใบสำหรับลอง Submit
    "! clone โครงสร้างจากใบต้นแบบ แล้วทับด้วยค่าของเอกสารตัวอย่าง 5 ขา
    "! payment_document_no เดินเลขต่อจากเลขล่าสุดใน ztar_i002_pymt
    "! item มีตัวเดียวชี้ไป invoice 6000000021 ที่ยังไม่ถูก clear
    "! ไม่แตะใบต้นแบบและใบอื่นเลย
    METHODS set_test_data
      IMPORTING out TYPE REF TO if_oo_adt_classrun_out.

    "! reset ทุกใบใน gt_payment_document_no ให้ Reject ซ้ำได้ — ล้าง reject_reason ทุก item · status → N · ล้างผล SFDC · ทิ้ง draft
    METHODS reset_payment
      IMPORTING out TYPE REF TO if_oo_adt_classrun_out.

    "! ขอ token จาก ZCL_UTILITY แล้วยิง describe ผ่าน arrangement Basic ตัวเดียวกัน โดยใส่ Authorization: Bearer เอง
    METHODS test_sfdc_bearer
      IMPORTING out TYPE REF TO if_oo_adt_classrun_out.

    "! Submit ทุกใบใน gt_payment_document_no ผ่าน ZCL_ZARE002_SUBMIT — แทน POC post JE
    METHODS submit_poc
      IMPORTING out TYPE REF TO if_oo_adt_classrun_out.

ENDCLASS.



CLASS zcl_zare002_util IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    " เปิด comment บรรทัดที่ต้องการก่อน F9 — ค่าเริ่มต้นไม่ทำอะไร กันรันพลาด
*    reset_payment( out ).
*    test_sfdc_bearer( out ).
*    set_test_data( out ).
*    submit_poc( out ).

  ENDMETHOD.

  METHOD class_constructor.
    " payment document ที่ utility จะทำงานด้วย (reset_payment / submit_poc)
    " แก้ list ใน class_constructor แล้วรันใหม่ (F9)
    gt_payment_document_no = VALUE #( ( '1000002300' ) ).
*    gt_payment_document_no = VALUE #( ( '1000000002' ) ).
*                                      ( '1000000102' ) ).
  ENDMETHOD.

  METHOD reset_payment.

    LOOP AT gt_payment_document_no INTO DATA(lv_payment_document_no).

      SELECT SINGLE payment_uuid, status, salesforce_status
        FROM ztar_i002_pymt
        WHERE payment_document_no = @lv_payment_document_no
        INTO @DATA(ls_payment).
      IF sy-subrc <> 0.
        out->write( |Payment { lv_payment_document_no }: not found| ).
        CONTINUE.
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

      out->write( |Payment { lv_payment_document_no }: reject_reason cleared on { lv_item_count } item(s), | &&
                  |status { ls_payment-status } -> N, salesforce_status { ls_payment-salesforce_status } -> blank, | &&
                  |{ lv_draft_count } draft(s) removed| ).

    ENDLOOP.

    COMMIT WORK.

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

  METHOD submit_poc.

    out->write( |submit_poc: simulate = { gc_submit_simulate }| ).

    LOOP AT gt_payment_document_no INTO DATA(lv_payment_document_no).

      SELECT SINGLE payment_uuid
        FROM ztar_i002_pymt
        WHERE payment_document_no = @lv_payment_document_no
        INTO @DATA(lv_payment_uuid).
      IF sy-subrc <> 0.
        out->write( |Payment { lv_payment_document_no }: not found| ).
        CONTINUE.
      ENDIF.

      DATA lt_entry TYPE zcl_zare002_journal_entry=>tt_entry.

      DATA(ls_result) = NEW zcl_zare002_submit( )->process( EXPORTING iv_payment_uuid = lv_payment_uuid
                                                                       iv_simulate     = gc_submit_simulate
                                                             IMPORTING et_entry        = lt_entry ).

      LOOP AT zcl_zare002_journal_entry=>describe( lt_entry ) INTO DATA(lv_line).
        out->write( lv_line ).
      ENDLOOP.

      out->write( |Payment { lv_payment_document_no }: outcome { ls_result-outcome } | &&
                  |doc { ls_result-accounting_document } - { ls_result-message }| ).

    ENDLOOP.

  ENDMETHOD.

  METHOD set_test_data.

    DATA lv_now TYPE abp_lastchange_tstmpl.

    " 1. clone ทั้ง row จากใบต้นแบบ
    " วิธีนี้ทำให้ field ที่ไม่ได้คิดถึงติดมาครบ ไม่ต้องไล่ใส่ทีละช่อง
    SELECT SINGLE *
      FROM ztar_i002_pymt
      WHERE payment_document_no = @gc_template_document_no
      INTO @DATA(ls_header).

    IF sy-subrc <> 0.
      out->write( |Template payment { gc_template_document_no } not found| ).
      RETURN.
    ENDIF.

    " item ตัวแรกของใบต้นแบบใช้เป็นแม่แบบของ item ใบใหม่
    SELECT SINGLE *
      FROM ztar_i002_item
      WHERE payment_uuid = @ls_header-payment_uuid
      INTO @DATA(ls_item).

    IF sy-subrc <> 0.
      out->write( |Template payment { gc_template_document_no } has no item| ).
      RETURN.
    ENDIF.

    " 2. เลขใบใหม่ เดินต่อจากเลขล่าสุดในตาราง
    " เลขในตารางเป็นตัวเลขเติมศูนย์ 10 หลักทุกใบ MAX จึงให้ตัวที่มากที่สุดจริง
    SELECT SINGLE MAX( payment_document_no )
      FROM ztar_i002_pymt
      INTO @DATA(lv_max_document_no).

    DATA(lv_next_number) = CONV i( lv_max_document_no ) + 1.
    DATA(lv_new_document_no) = CONV ztar_i002_pymt-payment_document_no(
                                 |{ lv_next_number WIDTH = 10 PAD = '0' ALIGN = RIGHT }| ).

    " 3. key ใหม่ของทั้ง header และ item
    TRY.
        DATA(lv_payment_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(lv_item_uuid)    = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error INTO DATA(lo_uuid_error).
        out->write( |Cannot create UUID: { lo_uuid_error->get_text( ) }| ).
        RETURN.
    ENDTRY.

    GET TIME STAMP FIELD lv_now.
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_request_id) = CONV ztar_i002_pymt-request_id(
                            |{ cl_abap_context_info=>get_system_date( ) }_{ cl_abap_context_info=>get_system_time( ) }| ).

    " 4. ทับ header ด้วยค่าของเอกสารตัวอย่าง
    " salesforce id ปล่อยว่าง ใบนี้ไม่ได้มาจาก SBPA จริง ไม่ควรส่งผลอะไรกลับไป
    " สถานะตั้งต้นเหมือนใบที่เพิ่งรับเข้ามา ยังไม่มีเอกสารและยังไม่มี message
    ls_header-payment_uuid                 = lv_payment_uuid.
    ls_header-payment_document_no          = lv_new_document_no.
    ls_header-request_id                   = lv_request_id.
    ls_header-salesforce_id                = space.
    ls_header-number_of_items_in_payment   = 1.
    ls_header-company_code                 = gc_test_company_code.
    ls_header-posting_date                 = gc_test_posting_date.
    ls_header-gl_account                   = gc_test_gl_account.
    ls_header-payment_method               = gc_test_payment_method.
    ls_header-cheque_no                    = space.
    ls_header-issue_date                   = '00000000'.
    ls_header-due_on                       = '00000000'.
    ls_header-cheque_bank_branch           = space.
    ls_header-currency                     = gc_test_currency.
    ls_header-payment_amount               = gc_test_payment_amount.
    ls_header-fees                         = gc_test_fees.
    ls_header-rounding_diff                = gc_test_rounding_diff.
    ls_header-advance_payment              = gc_test_advance_payment.
    ls_header-status                       = 'N'.
    ls_header-salesforce_status            = space.
    ls_header-salesforce_message           = space.
    ls_header-payment_accounting_document  = space.
    ls_header-clearing_accounting_document = space.
    ls_header-submit_message               = space.
    ls_header-created_by                   = lv_user.
    ls_header-created_at                   = lv_now.
    ls_header-last_changed_by              = lv_user.
    ls_header-last_changed_at              = lv_now.
    ls_header-local_last_changed_at        = lv_now.

    " 5. ทับ item ด้วย invoice ที่ยังไม่ถูก clear
    " reject_reason ปล่อยว่าง ใบนี้จะเอาไปทดสอบ Submit ไม่ใช่ Reject
    ls_item-item_uuid             = lv_item_uuid.
    ls_item-payment_uuid          = lv_payment_uuid.
    ls_item-salesforce_item_id    = space.
    ls_item-customer_code         = gc_test_customer_code.
    ls_item-billing_note_no       = space.
    ls_item-accounting_document   = gc_test_acctg_document.
    ls_item-billing_document      = gc_test_billing_doc.
    ls_item-invoice_posting_date  = gc_test_posting_date.
    ls_item-currency              = gc_test_currency.
    ls_item-invoice_amount        = gc_test_invoice_amount.
    ls_item-amount_paid           = gc_test_amount_paid.
    ls_item-partial_amount        = space.
    ls_item-sale_submit_date      = gc_test_posting_date.
    ls_item-reject_reason         = space.
    ls_item-created_by            = lv_user.
    ls_item-created_at            = lv_now.
    ls_item-last_changed_by       = lv_user.
    ls_item-last_changed_at       = lv_now.
    ls_item-local_last_changed_at = lv_now.

    " 6. บันทึก
    INSERT ztar_i002_pymt FROM @ls_header.
    IF sy-subrc <> 0.
      out->write( |Insert header failed for { lv_new_document_no }| ).
      ROLLBACK WORK.
      RETURN.
    ENDIF.

    INSERT ztar_i002_item FROM @ls_item.
    IF sy-subrc <> 0.
      out->write( |Insert item failed for { lv_new_document_no }| ).
      ROLLBACK WORK.
      RETURN.
    ENDIF.

    COMMIT WORK.

    " สมดุลที่คาดไว้ ควรเป็น 0 ถ้าค่าคงที่ข้างบนถูกต้อง
    DATA(lv_balance) = ls_header-payment_amount
                     + ls_header-fees
                     - ls_item-amount_paid
                     - ls_header-rounding_diff
                     - ls_header-advance_payment.

    out->write( |Test payment { lv_new_document_no } created| ).
    out->write( |  company { ls_header-company_code } posting { ls_header-posting_date } | &&
                |G/L { ls_header-gl_account } { ls_header-currency }| ).
    out->write( |  payment { ls_header-payment_amount } fees { ls_header-fees } | &&
                |rounding { ls_header-rounding_diff } advance { ls_header-advance_payment }| ).
    out->write( |  item customer { ls_item-customer_code } invoice { ls_item-accounting_document } | &&
                |paid { ls_item-amount_paid }| ).
    out->write( |  balance { lv_balance } (must be 0)| ).
    out->write( |  ใส่เลขนี้ใน gt_payment_document_no ของ class_constructor แล้วรัน submit_poc| ).

  ENDMETHOD.

ENDCLASS.
