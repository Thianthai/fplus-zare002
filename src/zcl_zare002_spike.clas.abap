CLASS zcl_zare002_spike DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    "! payment document ที่จะ reset — แก้ค่านี้แล้วรันใหม่ (F9)
    CONSTANTS gc_payment_document_no TYPE c LENGTH 10 VALUE '1000000002'.

ENDCLASS.



CLASS ZCL_ZARE002_SPIKE IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    SELECT SINGLE payment_uuid, status
      FROM ztar_i002_pymt
      WHERE payment_document_no = @gc_payment_document_no
      INTO @DATA(ls_payment).
    IF sy-subrc <> 0.
      out->write( |Payment { gc_payment_document_no } not found| ).
      RETURN.
    ENDIF.

    " 1. ล้าง reject_reason ของ item ทุกตัวในใบนี้
    UPDATE ztar_i002_item
      SET reject_reason = @space
      WHERE payment_uuid = @ls_payment-payment_uuid.
    DATA(lv_item_count) = sy-dbcnt.

    " 2. status กลับเป็น N เพื่อ Reject ได้อีกรอบ — ลบ block นี้ถ้าอยากคง status เดิม
    UPDATE ztar_i002_pymt
      SET status = 'N'
      WHERE payment_uuid = @ls_payment-payment_uuid.

    " 3. ทิ้ง draft ค้างของ item ในใบนี้ (ถ้ามี) กันค่าเก่าโผล่กลับมา
    DELETE FROM ztar_e002_item_d
      WHERE paymentuuid = @ls_payment-payment_uuid.
    DATA(lv_draft_count) = sy-dbcnt.

    COMMIT WORK.

    out->write( |Payment { gc_payment_document_no }: reject_reason cleared on { lv_item_count } item(s), | &&
                |status { ls_payment-status } -> N, { lv_draft_count } draft(s) removed| ).

  ENDMETHOD.
ENDCLASS.
