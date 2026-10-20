"! test ของ ZCL_ZARE002_SUBMIT
"! ครอบการแยกใบเช็คจากค่า payment_method
CLASS ltc_submit DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    "! รูปแบบใหม่ ทั้ง CA และ CR ต้องนับเป็นเช็ค
    METHODS new_format_cheque       FOR TESTING.

    "! ตัวพิมพ์และช่องว่างไม่มีผลต่อการตัดสิน
    METHODS case_and_space_ignored  FOR TESTING.

    "! row เก่าที่ไม่มี prefix ยังต้องนับเป็นเช็ค
    METHODS old_format_cheque       FOR TESTING.

    "! วิธีจ่ายอื่นทั้งแบบใหม่และแบบเก่า และค่าว่าง ไม่ใช่เช็ค
    METHODS other_method_not_cheque FOR TESTING.

ENDCLASS.


CLASS ltc_submit IMPLEMENTATION.

  METHOD new_format_cheque.
    cl_abap_unit_assert=>assert_true( zcl_zare002_submit=>is_cheque( 'CA-Cheque' ) ).
    cl_abap_unit_assert=>assert_true( zcl_zare002_submit=>is_cheque( 'CR-Cheque' ) ).
  ENDMETHOD.

  METHOD case_and_space_ignored.
    cl_abap_unit_assert=>assert_true( zcl_zare002_submit=>is_cheque( 'cr-cheque' ) ).
    cl_abap_unit_assert=>assert_true( zcl_zare002_submit=>is_cheque( 'CA - CHEQUE' ) ).
  ENDMETHOD.

  METHOD old_format_cheque.
    cl_abap_unit_assert=>assert_true( zcl_zare002_submit=>is_cheque( 'Cheque' ) ).
  ENDMETHOD.

  METHOD other_method_not_cheque.
    cl_abap_unit_assert=>assert_false( zcl_zare002_submit=>is_cheque( 'CA-Cash' ) ).
    cl_abap_unit_assert=>assert_false( zcl_zare002_submit=>is_cheque( 'CR-Transfer' ) ).
    cl_abap_unit_assert=>assert_false( zcl_zare002_submit=>is_cheque( 'Transfer' ) ).
    cl_abap_unit_assert=>assert_false( zcl_zare002_submit=>is_cheque( '' ) ).
  ENDMETHOD.

ENDCLASS.
