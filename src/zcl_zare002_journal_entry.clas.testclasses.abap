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

    " payment ครบทุกขา bank / bank charge / rounding / advance / ลูกหนี้ 1 item
    DATA(lt_item) = VALUE zcl_zare002_journal_entry=>tt_item(
                      ( customer_code       = '1000000014'
                        accounting_document = '6000000023'
                        billing_document    = 'O600000027'
                        amount_paid         = '10700.00' ) ).

    " สมดุลต้องเป็น 0 ก่อน ไม่งั้นบรรทัดที่เหลือไม่มีความหมาย
    cl_abap_unit_assert=>assert_equals(
      act = zcl_zare002_journal_entry=>check_balance( is_payment = sample_payment( )
                                                      it_item    = lt_item )
      exp = 0 ).

    DATA(lt_entry) = zcl_zare002_journal_entry=>build( is_payment = sample_payment( )
                                                       it_item    = lt_item ).
    DATA(ls_param) = lt_entry[ 1 ]-%param.

    " 1 payment = 1 เอกสาร
    cl_abap_unit_assert=>assert_equals( act = lines( lt_entry ) exp = 1 ).

    " header
    cl_abap_unit_assert=>assert_equals( act = ls_param-accountingdocumenttype exp = 'DS' ).
    cl_abap_unit_assert=>assert_equals( act = ls_param-documentreferenceid    exp = '1000000002' ).

    " เอกสารตัวอย่าง 3500000001 เรียง G/L 3 บรรทัดก่อน แล้วจึง AR 2 บรรทัด
    cl_abap_unit_assert=>assert_equals( act = lines( ls_param-_glitems ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_param-_aritems ) exp = 2 ).

    " G/L 001 bank เดบิต 10,779.50
    DATA(ls_bank) = ls_param-_glitems[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_bank-glaccountlineitem exp = '000001' ).
    cl_abap_unit_assert=>assert_equals( act = ls_bank-businessplace     exp = '0000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_bank-_currencyamount[ 1 ]-journalentryitemamount exp = '10779.50' ).
    cl_abap_unit_assert=>assert_initial( ls_bank-assignmentreference ).

    " G/L 002 bank charge เดบิต 20.00
    DATA(ls_charge) = ls_param-_glitems[ 2 ].
    cl_abap_unit_assert=>assert_equals( act = ls_charge-glaccountlineitem exp = '000002' ).
    cl_abap_unit_assert=>assert_equals( act = ls_charge-glaccount         exp = '0054030012' ).
    cl_abap_unit_assert=>assert_equals( act = ls_charge-costcenter        exp = '2002010000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_charge-taxcode           exp = 'WP' ).
    cl_abap_unit_assert=>assert_equals( act = ls_charge-businessplace     exp = '0000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_charge-_currencyamount[ 1 ]-journalentryitemamount exp = '20.00' ).
    cl_abap_unit_assert=>assert_initial( ls_charge-assignmentreference ).

    " G/L 003 rounding
    " rounding_diff ของ sample เป็น -0.50 (ติดลบ) จึงต้องออกมาเป็นเดบิต +0.50
    " บรรทัดนี้ต้องไม่มี tax code
    DATA(ls_rounding) = ls_param-_glitems[ 3 ].
    cl_abap_unit_assert=>assert_equals( act = ls_rounding-glaccountlineitem exp = '000003' ).
    cl_abap_unit_assert=>assert_equals( act = ls_rounding-glaccount         exp = '0059090001' ).
    cl_abap_unit_assert=>assert_equals( act = ls_rounding-businessplace     exp = '0000' ).
    cl_abap_unit_assert=>assert_initial( ls_rounding-taxcode ).
    cl_abap_unit_assert=>assert_equals( act = ls_rounding-_currencyamount[ 1 ]-journalentryitemamount exp = '0.50' ).
    cl_abap_unit_assert=>assert_initial( ls_rounding-assignmentreference ).

    " AR 004 advance
    " advance_payment ของ sample เป็น +100 (รับเพิ่ม) จึงต้องออกมาเป็นเครดิต -100
    " baseline date = posting date 20260922 + 30 วัน
    DATA(ls_advance) = ls_param-_aritems[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_advance-glaccountlineitem      exp = '000004' ).
    cl_abap_unit_assert=>assert_equals( act = ls_advance-customer               exp = '1000000014' ).
    cl_abap_unit_assert=>assert_equals( act = ls_advance-specialglcode          exp = 'Z' ).
    cl_abap_unit_assert=>assert_equals( act = ls_advance-businessplace          exp = '0000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_advance-duecalculationbasedate exp = '20261022' ).
    cl_abap_unit_assert=>assert_equals( act = ls_advance-_currencyamount[ 1 ]-journalentryitemamount exp = '-100.00' ).

    " AR 005 ลูกหนี้
    " amount_paid เป็นบวก (invoice) จึงต้องออกมาเป็นเครดิต -10,700
    " assignment และ item text ต้องว่างตามเอกสารตัวอย่าง
    DATA(ls_receivable) = ls_param-_aritems[ 2 ].
    cl_abap_unit_assert=>assert_equals( act = ls_receivable-glaccountlineitem exp = '000005' ).
    cl_abap_unit_assert=>assert_equals( act = ls_receivable-customer          exp = '1000000014' ).
    cl_abap_unit_assert=>assert_equals( act = ls_receivable-businessplace     exp = '0000' ).
    cl_abap_unit_assert=>assert_initial( ls_receivable-specialglcode ).
    cl_abap_unit_assert=>assert_initial( ls_receivable-assignmentreference ).
    cl_abap_unit_assert=>assert_initial( ls_receivable-documentitemtext ).
    cl_abap_unit_assert=>assert_equals( act = ls_receivable-_currencyamount[ 1 ]-journalentryitemamount exp = '-10700.00' ).

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

    " payment ที่มี CN ปนมากับ invoice
    " invoice 10,700 บวก และ CN 2,310 ลบ เหลือรับเงินจริง 8,390
    " ตัดขา bank charge / rounding / advance ออก เพื่อดูเฉพาะเครื่องหมายของบรรทัดลูกหนี้
    DATA(ls_payment) = sample_payment( ).
    ls_payment-fees            = 0.
    ls_payment-rounding_diff   = 0.
    ls_payment-advance_payment = 0.
    ls_payment-payment_amount  = '8390.00'.

    DATA(lt_item) = VALUE zcl_zare002_journal_entry=>tt_item(
                      ( customer_code       = '1000000014'
                        accounting_document = '6000000023'
                        amount_paid         = '10700.00' )
                      ( customer_code       = '1000000014'
                        accounting_document = '3400000008'
                        amount_paid         = '-2310.00' ) ).

    cl_abap_unit_assert=>assert_equals(
      act = zcl_zare002_journal_entry=>check_balance( is_payment = ls_payment
                                                      it_item    = lt_item )
      exp = 0 ).

    DATA(lt_entry) = zcl_zare002_journal_entry=>build( is_payment = ls_payment
                                                       it_item    = lt_item ).
    DATA(ls_param) = lt_entry[ 1 ]-%param.

    " เหลือ G/L แค่บรรทัด bank และ AR 2 บรรทัดของ item
    cl_abap_unit_assert=>assert_equals( act = lines( ls_param-_glitems ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_param-_aritems ) exp = 2 ).

    " item แรกเป็น invoice ยอดบวก จึงออกมาเป็นเครดิต
    cl_abap_unit_assert=>assert_equals(
      act = ls_param-_aritems[ 1 ]-_currencyamount[ 1 ]-journalentryitemamount
      exp = '-10700.00' ).

    " item ที่สองเป็น CN ยอดลบ จึงกลับข้างเป็นเดบิต
    cl_abap_unit_assert=>assert_equals(
      act = ls_param-_aritems[ 2 ]-_currencyamount[ 1 ]-journalentryitemamount
      exp = '2310.00' ).

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
