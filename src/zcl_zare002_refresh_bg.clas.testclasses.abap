"! ทดสอบการตัดสินว่าใบไหนถูก clear ครบแล้ว
"! ไม่อ่านหรือเขียน database
CLASS ltc_refresh DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    "! ทุก item clear แล้วด้วยเลขต่างกัน -> ปิดได้ ใช้เลขของ item ที่ accounting_document น้อยที่สุด
    METHODS all_items_cleared            FOR TESTING.
    "! มี item ที่ยังไม่ clear -> ไม่ปิด
    METHODS one_item_open                FOR TESTING.
    "! ไม่เจอบรรทัดของ invoice -> ไม่ปิด
    METHODS invoice_line_missing         FOR TESTING.
    "! ใบรับชำระบางส่วน -> ไม่ปิดเอง
    METHODS partial_payment_skipped      FOR TESTING.

    "! item 1 ตัวของใบตัวอย่าง
    "! @parameter iv_uuid     | payment uuid
    "! @parameter iv_document | accounting document ของ invoice
    "! @parameter iv_partial  | partial_amount
    "! @parameter rs_item     | item
    METHODS item
      IMPORTING iv_uuid        TYPE ztar_i002_pymt-payment_uuid
                iv_document    TYPE ztar_i002_item-accounting_document
                iv_partial     TYPE ztar_i002_item-partial_amount OPTIONAL
      RETURNING VALUE(rs_item) TYPE zcl_zare002_refresh_bg=>ty_item.

ENDCLASS.


CLASS ltc_refresh IMPLEMENTATION.

  METHOD item.

    rs_item = VALUE #( payment_uuid                = iv_uuid
                       company_code                = '2000'
                       payment_accounting_document = '3500000150'
                       payment_fiscal_year         = '2026'
                       accounting_document         = iv_document
                       invoice_posting_date        = '20261021'
                       invoice_fiscal_year         = '2026'
                       partial_amount              = iv_partial ).

  ENDMETHOD.

  METHOD all_items_cleared.

    DATA(lv_uuid) = CONV ztar_i002_pymt-payment_uuid( '00000000000000000000000000000001' ).

    " ใส่ item เลขมากก่อน เพื่อพิสูจน์ว่าเลือกจากเลขเอกสาร ไม่ใช่จากลำดับ
    DATA(lt_request) = zcl_zare002_refresh_bg=>decide(
      it_item = VALUE #( ( item( iv_uuid = lv_uuid iv_document = '6000000193' ) )
                         ( item( iv_uuid = lv_uuid iv_document = '6000000191' ) ) )
      it_line = VALUE #( ( company_code = '2000' accounting_document = '6000000193' fiscal_year = '2026'
                           clearing_document = '3500000146' clearing_fiscal_year = '2026' )
                         ( company_code = '2000' accounting_document = '6000000191' fiscal_year = '2026'
                           clearing_document = '3500000143' clearing_fiscal_year = '2026' ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_request ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_request[ 1 ]-clearing_document
                                        exp = '3500000143' ).
    cl_abap_unit_assert=>assert_equals( act = lt_request[ 1 ]-payment_accounting_document
                                        exp = '3500000150' ).
    cl_abap_unit_assert=>assert_equals( act = lt_request[ 1 ]-clearing_status
                                        exp = zcl_zari003_clearing_result=>gc_bot_success ).

  ENDMETHOD.

  METHOD one_item_open.

    DATA(lv_uuid) = CONV ztar_i002_pymt-payment_uuid( '00000000000000000000000000000001' ).

    DATA(lt_request) = zcl_zare002_refresh_bg=>decide(
      it_item = VALUE #( ( item( iv_uuid = lv_uuid iv_document = '6000000191' ) )
                         ( item( iv_uuid = lv_uuid iv_document = '6000000192' ) ) )
      it_line = VALUE #( ( company_code = '2000' accounting_document = '6000000191' fiscal_year = '2026'
                           clearing_document = '3500000143' clearing_fiscal_year = '2026' )
                         ( company_code = '2000' accounting_document = '6000000192' fiscal_year = '2026' ) ) ).

    cl_abap_unit_assert=>assert_initial( lt_request ).

  ENDMETHOD.

  METHOD invoice_line_missing.

    DATA(lv_uuid) = CONV ztar_i002_pymt-payment_uuid( '00000000000000000000000000000001' ).

    DATA(lt_request) = zcl_zare002_refresh_bg=>decide(
      it_item = VALUE #( ( item( iv_uuid = lv_uuid iv_document = '6000000191' ) )
                         ( item( iv_uuid = lv_uuid iv_document = '6000000192' ) ) )
      it_line = VALUE #( ( company_code = '2000' accounting_document = '6000000191' fiscal_year = '2026'
                           clearing_document = '3500000143' clearing_fiscal_year = '2026' ) ) ).

    cl_abap_unit_assert=>assert_initial( lt_request ).

  ENDMETHOD.

  METHOD partial_payment_skipped.

    DATA(lv_uuid) = CONV ztar_i002_pymt-payment_uuid( '00000000000000000000000000000001' ).

    DATA(lt_request) = zcl_zare002_refresh_bg=>decide(
      it_item = VALUE #( ( item( iv_uuid = lv_uuid iv_document = '6000000191' iv_partial = 'X' ) ) )
      it_line = VALUE #( ( company_code = '2000' accounting_document = '6000000191' fiscal_year = '2026'
                           clearing_document = '3500000143' clearing_fiscal_year = '2026' ) ) ).

    cl_abap_unit_assert=>assert_initial( lt_request ).

  ENDMETHOD.

ENDCLASS.
