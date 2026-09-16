CLASS ltc_status_buffer DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    CONSTANTS:
      lc_uuid_a TYPE sysuuid_x16 VALUE '000000000000000000000000000000A1',
      lc_uuid_b TYPE sysuuid_x16 VALUE '000000000000000000000000000000B2'.

    METHODS setup.

    "! เพิ่ม 2 payment แล้ว get_all ต้องได้ครบ 2 ตามที่ใส่
    METHODS add_then_get_all       FOR TESTING.
    "! เพิ่ม payment เดิมซ้ำ ต้องเหลือ entry เดียวและได้ค่าล่าสุด
    METHODS add_same_uuid_twice    FOR TESTING.
    "! clear แล้ว get_all ต้องว่าง
    METHODS clear_empties_buffer   FOR TESTING.

ENDCLASS.


CLASS ltc_status_buffer IMPLEMENTATION.

  METHOD setup.
    " buffer เป็น static — ล้างก่อนทุก test ไม่ให้ test ก่อนหน้ารั่วมา
    zcl_zare002_status_buffer=>clear( ).
  ENDMETHOD.

  METHOD add_then_get_all.
    zcl_zare002_status_buffer=>add( iv_payment_uuid = lc_uuid_a iv_status = 'R' ).
    zcl_zare002_status_buffer=>add( iv_payment_uuid = lc_uuid_b iv_status = 'R' ).

    DATA(lt_entry) = zcl_zare002_status_buffer=>get_all( ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_entry ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_entry[ payment_uuid = lc_uuid_a ]-status exp = 'R' ).
    cl_abap_unit_assert=>assert_equals( act = lt_entry[ payment_uuid = lc_uuid_b ]-status exp = 'R' ).
  ENDMETHOD.

  METHOD add_same_uuid_twice.
    zcl_zare002_status_buffer=>add( iv_payment_uuid = lc_uuid_a iv_status = 'N' ).
    zcl_zare002_status_buffer=>add( iv_payment_uuid = lc_uuid_a iv_status = 'R' ).

    DATA(lt_entry) = zcl_zare002_status_buffer=>get_all( ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_entry ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_entry[ 1 ]-status exp = 'R' ).
  ENDMETHOD.

  METHOD clear_empties_buffer.
    zcl_zare002_status_buffer=>add( iv_payment_uuid = lc_uuid_a iv_status = 'R' ).

    zcl_zare002_status_buffer=>clear( ).

    cl_abap_unit_assert=>assert_initial( zcl_zare002_status_buffer=>get_all( ) ).
  ENDMETHOD.

ENDCLASS.
