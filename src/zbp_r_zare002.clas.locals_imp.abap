"! Handler ของ Root Entity (ZR_ZARE002) — ทำงานใน interaction phase เท่านั้น
"! ห้าม write DB ที่นี่ — การ write ztar_i002_pymt ทำผ่าน ZCL_ZARE002_STATUS_BUFFER จาก lsc_Item
CLASS lhc_Item DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    "! Message Class ของ RICEFW นี้
    "! 001–099 = Reject, 100+ = Submit
    CONSTANTS gc_msgid            TYPE symsgid           VALUE 'ZARE002'.
    "! ค่า Status ที่ header หลัง Reject (domain ZD_REQUEST_STATUS ของ ZARI002)
    CONSTANTS gc_status_rejected  TYPE ze_request_status VALUE 'R'.
    "! ตัดข้อความ Error ของ SFDC ก่อนใส่ message (&2 ของ Message Number 005)
    CONSTANTS gc_sfdc_message_max TYPE i                 VALUE 50.

    "! payment_uuid แบบซ้ำได้ — ใช้ส่งเข้า read_rejected_payments
    TYPES tt_uuid        TYPE STANDARD TABLE OF sysuuid_x16 WITH EMPTY KEY.
    "! payment_uuid แบบไม่ซ้ำ — ผลลัพธ์ของ read_rejected_payments
    TYPES tt_uuid_sorted TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.
    "! range สำหรับ SELECT ... IN
    TYPES tr_uuid        TYPE RANGE OF sysuuid_x16.

    TYPES:
      "! header ของ payment ที่เกี่ยวข้องกับ action — field ที่ต้องใช้ทั้ง validate และส่ง SFDC
      BEGIN OF ty_payment,
        payment_uuid        TYPE sysuuid_x16,
        payment_document_no TYPE ztar_i002_pymt-payment_document_no,
        status              TYPE ze_request_status,
        salesforce_id       TYPE ztar_i002_pymt-salesforce_id,
        request_id          TYPE ztar_i002_pymt-request_id,
      END OF ty_payment,
      tt_payment TYPE STANDARD TABLE OF ty_payment WITH EMPTY KEY.

    "! สิทธิ์ระดับ BO — เปิดให้ทุกคนที่เข้า App ได้ (OQ-15 hold)
    "! การคุมสิทธิ์ว่าใครเข้า App ได้อยู่ที่ IAM App / Business Catalog ไม่ใช่ที่นี่
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Item
      RESULT result.

    "! Payment ที่Sstatus = R แล้ว: RejectReason ห้ามแก้ไข + ปุ่มทั้งหมด dim (OQ-13 / OQ-23)
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Item
      RESULT result.

    "! ปุ่ม Submit — ยังว่าง รอเฟส post FI (8B)
    METHODS submitItem FOR MODIFY
      IMPORTING keys FOR ACTION Item~submitItem.

    "! ปุ่ม Reject — item ที่ติ๊ก → ทุก item ของ payment นั้นจาก table ถึง filter บนจอจะบังไว้ (OQ-04)
    "! 1) validate: payment ต้องมี RejectReason อย่างน้อย 1 item (OQ-31) · ยังไม่ถูก reject (002)
    "!    ใบใดตก ทั้งชุดตก ไม่ยิง SFDC (OQ-26 ก) เพราะ change set ฝั่ง SAP ถูก rollback ทั้งก้อน
    "! 2) PATCH ทุก item ไป SFDC ใน composite call เดียว allOrNone (8A) · เกิน 25 → 004
    "! 3) SFDC รับแล้วเท่านั้น → จดลง buffer ให้ saver stamp status = R · พัง → failed ไม่มีอะไรลง DB
    "!    ผู้ใช้กด Reject ซ้ำได้เสมอ (= re-send)
    METHODS rejectItem FOR MODIFY
      IMPORTING keys FOR ACTION Item~rejectItem RESULT result.

    "! คืน payment uuid ที่ status = R แล้ว จากรายการที่ส่งเข้ามา (ซ้ำได้)
    METHODS read_rejected_payments
      IMPORTING it_payment_uuid        TYPE tt_uuid
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
    " ยังไม่มี logic — Phase 8A เปิดแค่ปุ่มตาม requirement
    " Phase 8B: distinct PaymentUuid จาก keys → item ทั้งหมดของ payment → post FI → แจ้ง SFDC Completed
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
    SELECT PaymentUuid        AS payment_uuid,
           PaymentDocumentNo  AS payment_document_no,
           Status             AS status,
           SalesforceId       AS salesforce_id,
           RequestId          AS request_id
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
        FIELDS ( PaymentUuid BillingDocument SalesforceItemId RejectReason )
        WITH VALUE #( FOR ls_key IN lt_item_key ( ItemUuid = ls_key-ItemUuid ) )
      RESULT DATA(lt_all_item).

    " 3. validate ทีละ payment — ใบใดตก ทั้งชุดตก ไม่ยิง SFDC (OQ-26 ก)
    DATA(lv_any_failed) = abap_false.

    LOOP AT lt_payment INTO DATA(ls_payment).

      " 3a. reject ซ้ำ — ปุ่ม dim อยู่แล้ว (OQ-23) แต่กันอีกชั้นเผื่อยิงตรง
      IF ls_payment-status = gc_status_rejected.
        lv_any_failed = abap_true.
        LOOP AT lt_selected INTO DATA(ls_selected)
             WHERE PaymentUuid = ls_payment-payment_uuid.
          APPEND VALUE #( %tky = ls_selected-%tky
                          %msg = new_message( id       = gc_msgid
                                              number   = '002'
                                              severity = if_abap_behv_message=>severity-error
                                              v1       = ls_payment-payment_document_no ) ) TO reported-item.
        ENDLOOP.
        CONTINUE.
      ENDIF.

      " 3b. payment ต้องมี reject reason อย่างน้อย 1 item (OQ-19 / OQ-31)
      DATA(lv_has_reason) = abap_false.
      LOOP AT lt_all_item INTO DATA(ls_item)
           WHERE PaymentUuid = ls_payment-payment_uuid
             AND RejectReason IS NOT INITIAL.
        lv_has_reason = abap_true.
        EXIT.
      ENDLOOP.

      IF lv_has_reason = abap_false.
        lv_any_failed = abap_true.
        LOOP AT lt_all_item INTO ls_item
             WHERE PaymentUuid = ls_payment-payment_uuid.
          APPEND VALUE #( %tky                  = ls_item-%tky
                          %element-RejectReason = if_abap_behv=>mk-on
                          %msg = new_message( id       = gc_msgid
                                              number   = '001'
                                              severity = if_abap_behv_message=>severity-error
                                              v1       = ls_payment-payment_document_no ) ) TO reported-item.
        ENDLOOP.
      ENDIF.

    ENDLOOP.

    IF lv_any_failed = abap_true.
      failed-item = VALUE #( FOR ls_fail IN lt_selected
                             ( %tky               = ls_fail-%tky
                               %action-rejectItem = if_abap_behv=>mk-on
                               %fail-cause        = if_abap_behv=>cause-unspecific ) ).
      RETURN.
    ENDIF.

    " 4. เตรียม record ให้ SFDC — ทุก item ของทุก payment ที่ผ่าน
    "    ลำดับใน lt_record = ลำดับใน lt_record_item เพื่อ map error_index กลับมาหาแถว
    DATA lt_record      TYPE zcl_zare002_sfdc_result=>tt_record.
    DATA lt_record_item LIKE lt_all_item.
    DATA(lv_response_date) = zcl_zare002_sfdc_result=>build_response_date( ).

    LOOP AT lt_payment INTO ls_payment.
      LOOP AT lt_all_item INTO ls_item WHERE PaymentUuid = ls_payment-payment_uuid.
        APPEND VALUE #( item_sf_id    = ls_item-SalesforceItemId
                        header_sf_id  = ls_payment-salesforce_id
                        status        = zcl_zare002_sfdc_result=>gc_status_rejected
                        reject_reason = ls_item-RejectReason
                        batch_id      = ls_payment-request_id
                        response_date = lv_response_date ) TO lt_record.
        APPEND ls_item TO lt_record_item.
      ENDLOOP.
    ENDLOOP.

    " 4a. เกิน limit ของ Composite API → ปฏิเสธทั้งชุด
    IF lines( lt_record ) > zcl_zare002_sfdc_result=>gc_max_records.
      failed-item = VALUE #( FOR ls_fail IN lt_selected
                             ( %tky               = ls_fail-%tky
                               %action-rejectItem = if_abap_behv=>mk-on
                               %fail-cause        = if_abap_behv=>cause-unspecific ) ).
      READ TABLE lt_selected INTO ls_selected INDEX 1.
      APPEND VALUE #( %tky = ls_selected-%tky
                      %msg = new_message( id       = gc_msgid
                                          number   = '004'
                                          severity = if_abap_behv_message=>severity-error
                                          v1       = |{ lines( lt_record ) }| ) ) TO reported-item.
      RETURN.
    ENDIF.

    " 5. ยิง SFDC ก่อนตัดสินใจ save — SFDC ไม่รับ = ไม่มีอะไรลง DB ผู้ใช้กด Reject ซ้ำได้ (ข้อ 4)
    DATA(ls_send) = NEW zcl_zare002_sfdc_result( )->send( lt_record ).

    IF ls_send-success = abap_false.
      failed-item = VALUE #( FOR ls_fail IN lt_selected
                             ( %tky               = ls_fail-%tky
                               %action-rejectItem = if_abap_behv=>mk-on
                               %fail-cause        = if_abap_behv=>cause-unspecific ) ).

      " message ชี้ไปที่ item ต้นเหตุถ้ารู้ ไม่งั้นแถวแรกที่ติ๊ก
      DATA(ls_culprit) = VALUE #( lt_record_item[ ls_send-error_index ] OPTIONAL ).
      IF ls_culprit IS INITIAL.
        READ TABLE lt_selected INTO ls_selected INDEX 1.
        ls_culprit-%tky = ls_selected-%tky.
      ENDIF.

      IF ls_send-http_status = 0
         OR ls_send-error_code = zcl_zare002_sfdc_result=>gc_err_not_reachable
         OR ls_send-error_code = zcl_zare002_sfdc_result=>gc_err_parse.
        " ต่อไม่ถึง / ตอบมาอ่านไม่ออก
        APPEND VALUE #( %tky = ls_culprit-%tky
                        %msg = new_message( id       = gc_msgid
                                            number   = '006'
                                            severity = if_abap_behv_message=>severity-error
                                            v1       = |{ ls_send-http_status }| ) ) TO reported-item.
      ELSE.
        " SFDC ปฏิเสธ — บอก errorCode + ข้อความ (ตัด 50)
        APPEND VALUE #( %tky = ls_culprit-%tky
                        %msg = new_message( id       = gc_msgid
                                            number   = '005'
                                            severity = if_abap_behv_message=>severity-error
                                            v1       = ls_send-error_code
                                            v2       = substring( val = ls_send-error_message
                                                                  len = nmin( val1 = strlen( ls_send-error_message )
                                                                              val2 = gc_sfdc_message_max ) ) ) ) TO reported-item.
      ENDIF.
      RETURN.
    ENDIF.

    " 6. SFDC รับแล้ว → จดลง buffer ให้ saver stamp header ตอน save phase
    "    + บังคับให้ save phase เกิดแน่นอน (OQ-24): update item ทุกตัวด้วยค่าเดิม
    LOOP AT lt_payment INTO ls_payment.
      zcl_zare002_status_buffer=>add( iv_payment_uuid = ls_payment-payment_uuid
                                      iv_status       = gc_status_rejected ).

      MODIFY ENTITIES OF zr_zare002 IN LOCAL MODE
        ENTITY Item
          UPDATE FIELDS ( RejectReason )
          WITH VALUE #( FOR ls_update IN lt_all_item
                        WHERE ( PaymentUuid = ls_payment-payment_uuid )
                        ( %tky         = ls_update-%tky
                          RejectReason = ls_update-RejectReason ) ).

      DATA(lv_item_count) = REDUCE i( INIT lv_n = 0
                                      FOR ls_count IN lt_all_item
                                      WHERE ( PaymentUuid = ls_payment-payment_uuid )
                                      NEXT lv_n = lv_n + 1 ).
      READ TABLE lt_selected INTO ls_selected WITH KEY PaymentUuid = ls_payment-payment_uuid.
      APPEND VALUE #( %tky = ls_selected-%tky
                      %msg = new_message( id       = gc_msgid
                                          number   = '003'
                                          severity = if_abap_behv_message=>severity-success
                                          v1       = ls_payment-payment_document_no
                                          v2       = |{ lv_item_count }| ) ) TO reported-item.
    ENDLOOP.

    " 7. คืน instance ที่ติ๊กกลับไปให้ Fiori Element โหลดแถวใหม่ (icon / readonly / ปุ่มเปลี่ยน)
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


"! Saver ของ BO (with additional save) — ทำงานหลัง managed runtime เขียน ztar_i002_item แล้ว
"! หน้าที่เดียว: stamp header ตามที่ action จดไว้ใน ZCL_ZARE002_STATUS_BUFFER
"! redefine ได้แค่ save_modified + cleanup_finalize (cleanup / save เป็นของ unmanaged save)
CLASS lsc_Item DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    "! หลัง managed runtime เขียน ztar_i002_item แล้ว → stamp header ตามที่ action จดไว้ใน buffer
    "! ถึงตรงนี้ได้แปลว่า SFDC รับแล้ว (rejectItem ยิงก่อน) → salesforce_status = S ด้วย
    "! เขียนเฉพาะ field ด้วย UPDATE ... SET — ห้าม MODIFY ทั้ง row
    METHODS save_modified REDEFINITION.

    "! ล้าง buffer ทุกครั้งที่จบ LUW — ทั้ง commit และ rollback
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
            salesforce_status     = 'S',
            salesforce_message    = @space,
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
