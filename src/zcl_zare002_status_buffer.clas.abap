"! กระดาษโน้ตระหว่าง action (interaction phase) กับ saver (save phase) ของ ZR_ZARE002
"! RAP ห้าม action เขียน DB และ header ไม่อยู่ใน BO → action จดที่นี่ saver อ่านแล้ว UPDATE ztar_i002_pymt
"! static เพราะเป็นจุดเดียวที่ทั้งสองฝั่งมองเห็นร่วมกันใน LUW เดียว
CLASS zcl_zare002_status_buffer DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    TYPES:
      "! status ใหม่ที่ action ต้องการให้ saver stamp ลง ztar_i002_pymt
      BEGIN OF ty_entry,
        payment_uuid TYPE sysuuid_x16,
        status       TYPE ze_request_status,
      END OF ty_entry,
      tt_entry TYPE SORTED TABLE OF ty_entry WITH UNIQUE KEY payment_uuid.

    "! payment นี้ต้องได้ status ใหม่ — เรียกจาก action handler (interaction phase)
    "! เรียกซ้ำ payment เดิม = ทับด้วยค่าล่าสุด
    CLASS-METHODS add
      IMPORTING iv_payment_uuid TYPE sysuuid_x16
                iv_status       TYPE ze_request_status.

    "! คืนทุก entry ที่ค้างอยู่ — เรียกจาก saver (save phase)
    CLASS-METHODS get_all
      RETURNING VALUE(rt_entry) TYPE tt_entry.

    "! ล้าง buffer — saver ต้องเรียกใน cleanup_finalize เสมอ ไม่ว่า save สำเร็จหรือ rollback
    "! (OData request เป็น stateless อยู่แล้ว การล้างนี้กันรั่วภายใน request เดียวกัน)
    CLASS-METHODS clear.

  PRIVATE SECTION.

    "! buffer จริง — มีชีวิตแค่ใน request เดียว
    CLASS-DATA gt_entry TYPE tt_entry.

ENDCLASS.



CLASS ZCL_ZARE002_STATUS_BUFFER IMPLEMENTATION.

  METHOD add.
    READ TABLE gt_entry ASSIGNING FIELD-SYMBOL(<lfs_entry>)
         WITH TABLE KEY payment_uuid = iv_payment_uuid.
    IF sy-subrc = 0.
      <lfs_entry>-status = iv_status.
    ELSE.
      INSERT VALUE ty_entry( payment_uuid = iv_payment_uuid
                             status       = iv_status ) INTO TABLE gt_entry.
    ENDIF.
  ENDMETHOD.


  METHOD get_all.
    rt_entry = gt_entry.
  ENDMETHOD.


  METHOD clear.
    CLEAR gt_entry.
  ENDMETHOD.

ENDCLASS.
