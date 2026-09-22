"! ทดสอบ builder อย่างเดียว — ไม่ post
CLASS ltc_journal_entry DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    "! payment ครบ 5 ขา — เช็คจำนวนบรรทัด เครื่องหมาย และสมดุล
    METHODS full_payment_has_five_lines FOR TESTING.
    "! fees / rounding / advance เป็น 0 → เหลือ bank + ลูกหนี้
    METHODS zero_lines_are_skipped       FOR TESTING.
    "! CN (amount_paid ติดลบ) ต้องเป็นเดบิต (บวก) ฝั่ง API
    METHODS credit_note_is_debit          FOR TESTING.
    "! สมดุลไม่ลงตัวคืนผลต่าง
    METHODS unbalanced_returns_difference FOR TESTING.

    "! payment ตั้งต้น: bank 10,779.50 · fees 20 · rounding -0.50 · advance 100 · item 10,700
    METHODS sample_payment
      RETURNING VALUE(rs_payment) TYPE zcl_zare002_journal_entry=>ty_payment.

    "! bank 11011211 ได้ SCB01/SA001 · bank charge ได้ WP + 0000 · G/L อื่นไม่มี house bank
    METHODS house_bank_and_tax_on_lines FOR TESTING.

ENDCLASS.


CLASS ltc_journal_entry IMPLEMENTATION.

  METHOD sample_payment.
    rs_payment = VALUE #( payment_document_no = '1000000002'
                          request_id          = '20260922_100000'
                          company_code        = '2000'
                          posting_date        = '20260922'
                          gl_account          = '0011011003'
                          currency            = 'THB'
                          payment_amount      = '10779.50'
                          fees                = '20.00'
                          rounding_diff       = '-0.50'
                          advance_payment     = '100.00' ).
  ENDMETHOD.

  METHOD full_payment_has_five_lines.
    DATA(lt_item) = VALUE zcl_zare002_journal_entry=>tt_item(
                      ( customer_code = '1000000014' accounting_document = '6000000023'
                        billing_document = 'O600000027' amount_paid = '10700.00' ) ).

    cl_abap_unit_assert=>assert_equals( act = zcl_zare002_journal_entry=>check_balance( is_payment = sample_payment( ) it_item = lt_item )
                                        exp = 0 ).

    DATA(lt_entry) = zcl_zare002_journal_entry=>build( is_payment = sample_payment( ) it_item = lt_item ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_entry ) exp = 1 ).
    DATA(ls_param) = lt_entry[ 1 ]-%param.
    cl_abap_unit_assert=>assert_equals( act = ls_param-accountingdocumenttype exp = 'DS' ).
    cl_abap_unit_assert=>assert_equals( act = ls_param-documentreferenceid    exp = '1000000002' ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_param-_glitems )       exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_param-_aritems )       exp = 2 ).

    " bank +10779.50 · fees +20 · rounding +0.50 (Dr) · customer -10700 · advance -100 (Cr, SpGL Z, baseline +30)
    cl_abap_unit_assert=>assert_equals( act = ls_param-_glitems[ 1 ]-_currencyamount[ 1 ]-journalentryitemamount exp = '10779.50' ).
    cl_abap_unit_assert=>assert_equals( act = ls_param-_glitems[ 2 ]-glaccount  exp = '0054030012' ).
    cl_abap_unit_assert=>assert_equals( act = ls_param-_glitems[ 2 ]-costcenter exp = '2002010000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_param-_glitems[ 3 ]-_currencyamount[ 1 ]-journalentryitemamount exp = '0.50' ).
    cl_abap_unit_assert=>assert_equals( act = ls_param-_aritems[ 1 ]-_currencyamount[ 1 ]-journalentryitemamount exp = '-10700.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_param-_aritems[ 1 ]-assignmentreference exp = '6000000023' ).
    cl_abap_unit_assert=>assert_equals( act = ls_param-_aritems[ 2 ]-specialglcode          exp = 'Z' ).
    cl_abap_unit_assert=>assert_equals( act = ls_param-_aritems[ 2 ]-duecalculationbasedate exp = '20261022' ).
    cl_abap_unit_assert=>assert_equals( act = ls_param-_aritems[ 2 ]-_currencyamount[ 1 ]-journalentryitemamount exp = '-100.00' ).
  ENDMETHOD.

  METHOD zero_lines_are_skipped.
    DATA(ls_payment) = sample_payment( ).
    ls_payment-fees            = 0.
    ls_payment-rounding_diff   = 0.
    ls_payment-advance_payment = 0.
    ls_payment-payment_amount  = '10700.00'.
    DATA(lt_item) = VALUE zcl_zare002_journal_entry=>tt_item(
                      ( customer_code = '1000000014' accounting_document = '6000000023' amount_paid = '10700.00' ) ).

    DATA(lt_entry) = zcl_zare002_journal_entry=>build( is_payment = ls_payment it_item = lt_item ).
    DATA(ls_param) = lt_entry[ 1 ]-%param.

    cl_abap_unit_assert=>assert_equals( act = lines( ls_param-_glitems ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_param-_aritems ) exp = 1 ).
  ENDMETHOD.

  METHOD credit_note_is_debit.
    DATA(ls_payment) = sample_payment( ).
    ls_payment-fees            = 0.
    ls_payment-rounding_diff   = 0.
    ls_payment-advance_payment = 0.
    ls_payment-payment_amount  = '8390.00'.
    DATA(lt_item) = VALUE zcl_zare002_journal_entry=>tt_item(
                      ( customer_code = '1000000014' accounting_document = '6000000023' amount_paid = '10700.00' )
                      ( customer_code = '1000000014' accounting_document = '3400000008' amount_paid = '-2310.00' ) ).

    cl_abap_unit_assert=>assert_equals( act = zcl_zare002_journal_entry=>check_balance( is_payment = ls_payment it_item = lt_item ) exp = 0 ).

    DATA(lt_entry) = zcl_zare002_journal_entry=>build( is_payment = ls_payment it_item = lt_item ).
    DATA(ls_param) = lt_entry[ 1 ]-%param.

    cl_abap_unit_assert=>assert_equals( act = ls_param-_aritems[ 2 ]-_currencyamount[ 1 ]-journalentryitemamount exp = '2310.00' ).
  ENDMETHOD.

  METHOD unbalanced_returns_difference.
    DATA(lt_item) = VALUE zcl_zare002_journal_entry=>tt_item(
                      ( customer_code = '1000000014' accounting_document = '6000000023' amount_paid = '10000.00' ) ).

    cl_abap_unit_assert=>assert_equals( act = zcl_zare002_journal_entry=>check_balance( is_payment = sample_payment( ) it_item = lt_item )
                                        exp = '700.00' ).
  ENDMETHOD.

  METHOD house_bank_and_tax_on_lines.
    DATA(ls_payment) = sample_payment( ).
    ls_payment-gl_account = '0011011211'.
    DATA(lt_item) = VALUE zcl_zare002_journal_entry=>tt_item(
                      ( customer_code = '1000000014' accounting_document = '6000000023' amount_paid = '10700.00' ) ).

    DATA(lt_entry) = zcl_zare002_journal_entry=>build( is_payment = ls_payment it_item = lt_item ).
    DATA(ls_param) = lt_entry[ 1 ]-%param.

    cl_abap_unit_assert=>assert_equals( act = ls_param-_glitems[ 1 ]-housebank        exp = 'SCB01' ).
    cl_abap_unit_assert=>assert_equals( act = ls_param-_glitems[ 1 ]-housebankaccount exp = 'SA001' ).
    cl_abap_unit_assert=>assert_equals( act = ls_param-_glitems[ 2 ]-taxcode          exp = 'WP' ).
    cl_abap_unit_assert=>assert_equals( act = ls_param-_glitems[ 2 ]-businessplace    exp = '0000' ).
    cl_abap_unit_assert=>assert_initial( ls_param-_glitems[ 3 ]-taxcode ).

    ls_payment-gl_account = '0011011003'.
    lt_entry = zcl_zare002_journal_entry=>build( is_payment = ls_payment it_item = lt_item ).
    cl_abap_unit_assert=>assert_initial( lt_entry[ 1 ]-%param-_glitems[ 1 ]-housebank ).
  ENDMETHOD.

ENDCLASS.
