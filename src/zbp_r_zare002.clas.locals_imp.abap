CLASS lhc_Item DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    CONSTANTS gc_msgid           TYPE symsgid           VALUE 'ZARE002'.
    CONSTANTS gc_status_rejected TYPE ze_request_status VALUE 'R'.

    TYPES tt_uuid TYPE STANDARD TABLE OF sysuuid_x16 WITH EMPTY KEY.
    TYPES tt_uuid_sorted TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.
    TYPES tr_uuid TYPE RANGE OF sysuuid_x16.

    "! สิทธิ์ระดับ BO — เปิดให้ทุกคนที่เข้า app ได้ (OQ-15 hold)
    "! การคุมว่าใครเข้า app ได้อยู่ที่ IAM App / business catalog ไม่ใช่ที่นี่
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Item
      RESULT result.

    "! payment ที่ status = R แล้ว: RejectReason อ่านอย่างเดียว + ปุ่มทั้งคู่ dim (OQ-13 / OQ-23)
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Item
      RESULT result.

    "! ปุ่ม Submit — ยังว่าง รอเฟส post FI
    METHODS submitItem FOR MODIFY
      IMPORTING keys FOR ACTION Item~submitItem.

    "! ปุ่ม Reject — item ที่ติ๊ก → ทุก item ของ payment นั้น (OQ-04)
    "! validate ทุก item ต้องมี RejectReason (OQ-22) → จดลง buffer ให้ saver stamp status = R
    METHODS rejectItem FOR MODIFY
      IMPORTING keys FOR ACTION Item~rejectItem RESULT result.

    "! คืน payment uuid ที่ status = R แล้ว จากรายการที่ส่งเข้ามา (ซ้ำได้)
    METHODS read_rejected_payments
      IMPORTING it_payment_uuid       TYPE tt_uuid
      RETURNING VALUE(rt_payment_uuid) TYPE tt_uuid_sorted.

ENDCLASS.


CLASS lhc_Item IMPLEMENTATION.

  METHOD get_global_authorizations.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-submitItem = if_abap_behv=>mk-on.
      result-%action-submitItem = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-rejectItem = if_abap_behv=>mk-on.
      result-%action-rejectItem = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zr_zare002 IN LOCAL MODE
      ENTITY Item
        FIELDS ( PaymentUuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    DATA(lt_rejected) = read_rejected_payments(
                          VALUE #( FOR ls_item IN lt_item ( ls_item-PaymentUuid ) ) ).

    result = VALUE #( FOR ls_item IN lt_item
                      LET lv_rejected = xsdbool( line_exists( lt_rejected[ table_line = ls_item-PaymentUuid ] ) )
                      IN
                      ( %tky                = ls_item-%tky
                        %field-RejectReason = COND #( WHEN lv_rejected = abap_true
                                                      THEN if_abap_behv=>fc-f-read_only
                                                      ELSE if_abap_behv=>fc-f-unrestricted )
                        %action-submitItem  = COND #( WHEN lv_rejected = abap_true
                                                      THEN if_abap_behv=>fc-o-disabled
                                                      ELSE if_abap_behv=>fc-o-enabled )
                        %action-rejectItem  = COND #( WHEN lv_rejected = abap_true
                                                      THEN if_abap_behv=>fc-o-disabled
                                                      ELSE if_abap_behv=>fc-o-enabled ) ) ).
  ENDMETHOD.

  METHOD submitItem.
    " ยังไม่มี logic — เฟสนี้เปิดแค่ปุ่มตาม requirement
    " เฟสถัดไป: distinct PaymentUuid จาก keys → item ทั้งหมดของ payment → post FI
  ENDMETHOD.

  METHOD rejectItem.

    " 1. item ที่ติ๊ก → payment ที่เกี่ยว (เลือก item ใด = ทั้ง payment · OQ-04)
    READ ENTITIES OF zr_zare002 IN LOCAL MODE
      ENTITY Item
        FIELDS ( PaymentUuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_selected).

    DATA(lr_payment_uuid) = VALUE tr_uuid(
      FOR GROUPS lv_uuid OF ls_group IN lt_selected GROUP BY ls_group-PaymentUuid
      ( sign = 'I' option = 'EQ' low = lv_uuid ) ).

    " 2. header ของ payment เหล่านั้น + key ของ item ทุกตัว
    SELECT PaymentUuid, PaymentDocumentNo, Status
      FROM zi_zare002_pymt
      WHERE PaymentUuid IN @lr_payment_uuid
      INTO TABLE @DATA(lt_payment).

    SELECT ItemUuid
      FROM zi_zare002_item
      WHERE PaymentUuid IN @lr_payment_uuid
      INTO TABLE @DATA(lt_item_key).

    " ค่า RejectReason อ่านผ่าน EML เพื่อให้ได้ค่าจาก transactional buffer ไม่ใช่แค่ DB
    READ ENTITIES OF zr_zare002 IN LOCAL MODE
      ENTITY Item
        FIELDS ( PaymentUuid BillingDocument RejectReason )
        WITH VALUE #( FOR ls_key IN lt_item_key ( ItemUuid = ls_key-ItemUuid ) )
      RESULT DATA(lt_all_item).

    " 3. ตัดสินทีละ payment
    LOOP AT lt_payment INTO DATA(ls_payment).

      " 3a. reject ซ้ำ — ปุ่ม dim อยู่แล้ว (OQ-23) แต่กันอีกชั้นเผื่อยิงตรง
      IF ls_payment-Status = gc_status_rejected.
        LOOP AT lt_selected INTO DATA(ls_selected)
             WHERE PaymentUuid = ls_payment-PaymentUuid.
          APPEND VALUE #( %tky               = ls_selected-%tky
                          %action-rejectItem = if_abap_behv=>mk-on
                          %fail-cause        = if_abap_behv=>cause-disabled ) TO failed-item.
          APPEND VALUE #( %tky = ls_selected-%tky
                          %msg = new_message( id       = gc_msgid
                                              number   = '002'
                                              severity = if_abap_behv_message=>severity-error
                                              v1       = ls_payment-PaymentDocumentNo ) ) TO reported-item.
        ENDLOOP.
        CONTINUE.
      ENDIF.

      " 3b. ทุก item ของ payment ต้องมี reject reason (OQ-19 / OQ-22)
      "     1 message ต่อ item ที่ว่าง ชี้ไปที่ช่อง RejectReason ของแถวนั้น
      DATA(lv_missing) = abap_false.
      LOOP AT lt_all_item INTO DATA(ls_item)
           WHERE PaymentUuid = ls_payment-PaymentUuid
             AND RejectReason IS INITIAL.
        lv_missing = abap_true.
        APPEND VALUE #( %tky                  = ls_item-%tky
                        %element-RejectReason = if_abap_behv=>mk-on
                        %msg = new_message( id       = gc_msgid
                                            number   = '001'
                                            severity = if_abap_behv_message=>severity-error
                                            v1       = ls_payment-PaymentDocumentNo
                                            v2       = ls_item-BillingDocument ) ) TO reported-item.
      ENDLOOP.

      IF lv_missing = abap_true.
        LOOP AT lt_selected INTO ls_selected
             WHERE PaymentUuid = ls_payment-PaymentUuid.
          APPEND VALUE #( %tky               = ls_selected-%tky
                          %action-rejectItem = if_abap_behv=>mk-on
                          %fail-cause        = if_abap_behv=>cause-unspecific ) TO failed-item.
        ENDLOOP.
        CONTINUE.
      ENDIF.

      " 3c. ผ่าน → จดลง buffer ให้ saver stamp header ตอน save phase
      zcl_zare002_status_buffer=>add( iv_payment_uuid = ls_payment-PaymentUuid
                                      iv_status       = gc_status_rejected ).

      "     บังคับให้ save phase เกิดแน่นอน (OQ-24): update item ทุกตัวของ payment ด้วยค่าเดิม
      "     ถ้าไม่ทำ framework อาจข้าม save เพราะ buffer ของ item ว่าง แล้ว saver ไม่ถูกเรียก
      MODIFY ENTITIES OF zr_zare002 IN LOCAL MODE
        ENTITY Item
          UPDATE FIELDS ( RejectReason )
          WITH VALUE #( FOR ls_update IN lt_all_item
                        WHERE ( PaymentUuid = ls_payment-PaymentUuid )
                        ( %tky         = ls_update-%tky
                          RejectReason = ls_update-RejectReason ) ).

      "     success message ที่ item แรกที่ติ๊กของ payment นี้
      DATA(lv_item_count) = REDUCE i( INIT lv_n = 0
                                      FOR ls_count IN lt_all_item
                                      WHERE ( PaymentUuid = ls_payment-PaymentUuid )
                                      NEXT lv_n = lv_n + 1 ).
      READ TABLE lt_selected INTO ls_selected WITH KEY PaymentUuid = ls_payment-PaymentUuid.
      APPEND VALUE #( %tky = ls_selected-%tky
                      %msg = new_message( id       = gc_msgid
                                          number   = '003'
                                          severity = if_abap_behv_message=>severity-success
                                          v1       = ls_payment-PaymentDocumentNo
                                          v2       = |{ lv_item_count }| ) ) TO reported-item.

    ENDLOOP.

    " 4. คืน instance ที่ติ๊กกลับไปให้ FE โหลดแถวใหม่ (icon / readonly / ปุ่มเปลี่ยน)
    READ ENTITIES OF zr_zare002 IN LOCAL MODE
      ENTITY Item
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_result IN lt_result
                      ( %tky   = ls_result-%tky
                        %param = ls_result ) ).

  ENDMETHOD.

  METHOD read_rejected_payments.
    IF it_payment_uuid IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lr_payment_uuid) = VALUE tr_uuid( FOR lv_uuid IN it_payment_uuid
                                           ( sign = 'I' option = 'EQ' low = lv_uuid ) ).

    SELECT PaymentUuid
      FROM zi_zare002_pymt
      WHERE PaymentUuid IN @lr_payment_uuid
        AND Status       = @gc_status_rejected
      INTO TABLE @rt_payment_uuid.
  ENDMETHOD.

ENDCLASS.


CLASS lsc_Item DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    " หลัง managed runtime เขียน ztar_i002_item แล้ว → stamp status ที่ header ตามที่ action จดไว้ใน buffer
    " เขียนเฉพาะ field ด้วย UPDATE ... SET — ห้าม MODIFY ทั้ง row
    METHODS save_modified REDEFINITION.

    " ล้าง buffer ทุกครั้งที่จบ LUW — ทั้ง commit และ rollback
    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.


CLASS lsc_Item IMPLEMENTATION.

  METHOD save_modified.
    DATA(lt_entry) = zcl_zare002_status_buffer=>get_all( ).
    IF lt_entry IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_now TYPE abp_lastchange_tstmpl.
    GET TIME STAMP FIELD lv_now.
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    LOOP AT lt_entry INTO DATA(ls_entry).
      UPDATE ztar_i002_pymt
        SET status                = @ls_entry-status,
            last_changed_by       = @lv_user,
            last_changed_at       = @lv_now,
            local_last_changed_at = @lv_now
        WHERE payment_uuid = @ls_entry-payment_uuid.
    ENDLOOP.
  ENDMETHOD.

  METHOD cleanup_finalize.
    zcl_zare002_status_buffer=>clear( ).
  ENDMETHOD.

ENDCLASS.
