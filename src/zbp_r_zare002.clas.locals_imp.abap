"! Handler ของ Root Entity (ZR_ZARE002) — ทำงานใน interaction phase เท่านั้น
"! ห้าม write DB ที่นี่ — การ write ztar_i002_pymt ทำผ่าน ZCL_ZARE002_STATUS_BUFFER จาก lsc_Item
CLASS lhc_Item DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    "! message class ของ RICEFW นี้
    "! 001–099 = Reject, 100+ = Submit
    CONSTANTS gc_msgid            TYPE symsgid           VALUE 'ZARE002'.

    "! ค่า status ที่ header หลัง reject (domain ZD_REQUEST_STATUS ของ ZARI002)
    CONSTANTS gc_status_rejected  TYPE ze_request_status VALUE 'R'.

    "! ตัดข้อความ error ของ SFDC ก่อนใส่ message (&2 ของ message number 005)
    CONSTANTS gc_sfdc_message_max TYPE i                 VALUE 50.

    "! payment_uuid แบบซ้ำได้ — ใช้ส่งเข้า read_rejected_payments
    TYPES tt_uuid        TYPE STANDARD TABLE OF sysuuid_x16 WITH EMPTY KEY.

    TYPES:
      "! สภาพของ payment ที่ปุ่มและ validate ใช้ตัดสิน — ดูจากเลขเอกสารที่มีจริง ไม่ใช่ status แค่อย่างเดียว
      BEGIN OF ty_payment_state,
        payment_uuid                 TYPE sysuuid_x16,
        status                       TYPE ze_request_status,
        payment_accounting_document  TYPE ztar_i002_pymt-payment_accounting_document,
        clearing_accounting_document TYPE ztar_i002_pymt-clearing_accounting_document,
      END OF ty_payment_state,
      tt_payment_state TYPE SORTED TABLE OF ty_payment_state WITH UNIQUE KEY payment_uuid.

    "! range สำหรับ SELECT ... IN
    TYPES tr_uuid        TYPE RANGE OF sysuuid_x16.

    TYPES:
      "! header ของ payment ที่เกี่ยวข้องกับ action — field ที่ต้องใช้ทั้ง validate และส่ง SFDC
      BEGIN OF ty_payment,
        payment_uuid                TYPE sysuuid_x16,
        payment_document_no         TYPE ztar_i002_pymt-payment_document_no,
        status                      TYPE ze_request_status,
        salesforce_id               TYPE ztar_i002_pymt-salesforce_id,
        request_id                  TYPE ztar_i002_pymt-request_id,
        payment_accounting_document TYPE ztar_i002_pymt-payment_accounting_document,
      END OF ty_payment,
      tt_payment TYPE STANDARD TABLE OF ty_payment WITH EMPTY KEY.

    "! สิทธิ์ระดับ BO — เปิดให้ทุกคนที่เข้า App ได้
    "! การคุมสิทธิ์ว่าใครเข้า App ได้อยู่ที่ IAM App / Business Catalog ไม่ใช่ที่นี่
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Item
      RESULT result.

    "! payment ที่ reject แล้ว (R) หรือ post JE แล้ว: RejectReason ห้ามแก้ + Reject ปิด
    "! Submit ปิดเมื่อ R หรือมีทั้ง Payment Doc และ Clearing Doc แล้ว
    "! ปุ่มเป็นแค่คำใบ้ให้ UI — handler ต้อง validate ซ้ำจาก DB เสมอ
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Item
      RESULT result.

    "! ปุ่ม Submit — ยังว่าง รอเฟส post FI (8B)
    METHODS submitItem FOR MODIFY
      IMPORTING keys FOR ACTION Item~submitItem.

    "! ปุ่ม Reject
    "! 1) validate payment ต้องมี RejectReason อย่างน้อย 1 item
    "!    ใบไหนไม่ผ่าน = ทั้งชุดไม่ผ่าน และไม่ call SFDC เพราะ change set ฝั่ง SAP ถูก rollback ทั้งหมด
    "! 2) PATCH ทุก item ไป SFDC ใน composite call เดียว
    "! 3) SFDC รับแล้วเท่านั้นถึงจะ write ลง buffer เพื่อให้ saver stamp status = R
    "!    ถ้า SFDC รับไม่สำเร็จ จะไม่มีอะไรถูก write ลง DB เพื่อให้ user กด Reject ซ้ำได้เสมอ (re-send)
    "! 4) reject ทุก item ของ payment นั้น
    METHODS rejectItem FOR MODIFY
      IMPORTING keys FOR ACTION Item~rejectItem RESULT result.

    "! อ่าน status + เลข JE + เลข clearing ของ payment ที่ส่งเข้ามา (uuid ซ้ำได้)
    METHODS read_payment_state
      IMPORTING it_payment_uuid TYPE tt_uuid
      RETURNING VALUE(rt_state) TYPE tt_payment_state.

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

    DATA(lt_state) = read_payment_state(
                       VALUE #( FOR ls_item IN lt_item ( ls_item-PaymentUuid ) ) ).

    result = VALUE #( FOR ls_item IN lt_item
                      LET ls_state    = VALUE #( lt_state[ payment_uuid = ls_item-PaymentUuid ] OPTIONAL )
                          lv_rejected = xsdbool( ls_state-status = gc_status_rejected )
                          lv_posted   = xsdbool( ls_state-payment_accounting_document IS NOT INITIAL )
                          lv_cleared  = xsdbool( ls_state-clearing_accounting_document IS NOT INITIAL )
                      IN
                      ( %tky                = ls_item-%tky
                        " แก้ reason ได้เฉพาะใบที่ยังไม่ reject และยังไม่ post
                        %field-RejectReason = COND #( WHEN lv_rejected = abap_true OR lv_posted = abap_true
                                                      THEN if_abap_behv=>fc-f-read_only
                                                      ELSE if_abap_behv=>fc-f-unrestricted )
                        " Submit ทำต่อได้จนกว่าจะมีครบ 2 doc (มีแค่ Payment Doc = ยังต้อง clearing)
                        %action-submitItem  = COND #( WHEN lv_rejected = abap_true
                                                        OR ( lv_posted = abap_true AND lv_cleared = abap_true )
                                                      THEN if_abap_behv=>fc-o-disabled
                                                      ELSE if_abap_behv=>fc-o-enabled )
                        " post แล้วย้อน reject ไม่ได้
                        %action-rejectItem  = COND #( WHEN lv_rejected = abap_true OR lv_posted = abap_true
                                                      THEN if_abap_behv=>fc-o-disabled
                                                      ELSE if_abap_behv=>fc-o-enabled ) ) ).

  ENDMETHOD.


  METHOD submitItem.
    " ยังไม่มี logic โดยตั้งใจ — รอ spec post FI (Phase 8B)
  ENDMETHOD.


  METHOD rejectItem.

    " 1. ดึง key ของ payment ที่เลือกจากหน้าจอ
    READ ENTITIES OF zr_zare002 IN LOCAL MODE
      ENTITY Item
        FIELDS ( PaymentUuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_selected).

    DATA(lr_payment_uuid) = VALUE tr_uuid(
      FOR GROUPS lv_uuid OF ls_group IN lt_selected GROUP BY ls_group-PaymentUuid
      ( sign = 'I' option = 'EQ' low = lv_uuid ) ).

    " 2. ดึง header field ของ payment ที่เลือกจากหน้าจอ
    SELECT PaymentUuid               AS payment_uuid,
           PaymentDocumentNo         AS payment_document_no,
           Status                    AS status,
           SalesforceId              AS salesforce_id,
           RequestId                 AS request_id,
           PaymentAccountingDocument AS payment_accounting_document
      FROM zi_zare002_pymt
      WHERE PaymentUuid IN @lr_payment_uuid
      INTO TABLE @DATA(lt_payment).

    " 3. ดึง key ของทุก item ของ payment
    SELECT ItemUuid
      FROM zi_zare002_item
      WHERE PaymentUuid IN @lr_payment_uuid
      INTO TABLE @DATA(lt_item_key).

    " 4. อ่านค่า RejectReason ผ่าน EML เพื่อให้ได้ค่าจาก transactional buffer ไม่ใช่ค่าจาก DB
    READ ENTITIES OF zr_zare002 IN LOCAL MODE
      ENTITY Item
        FIELDS ( PaymentUuid
                 BillingDocument
                 SalesforceItemId
                 RejectReason )
        WITH VALUE #( FOR ls_key IN lt_item_key ( ItemUuid = ls_key-ItemUuid ) )
      RESULT DATA(lt_all_item).

    " 5. validate ทีละ payment
    " ต้องผ่านทั้งชุด หรือไม่ผ่านทั้งชุด ถ้าไม่ผ่านจะไม่ยิง SFDC
    DATA(lv_any_failed) = abap_false.

    LOOP AT lt_payment INTO DATA(ls_payment).

      " 5.1 validate reject ซ้ำ — ฝั่ง Fiori Element ปุ่ม disable อยู่แล้ว แต่ป้องกัน call api ตรงไม่ผ่าน UI
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

      " 5.2 validate post แล้ว — JE ออกไปแล้ว reject ย้อนไม่ได้ (UI ปิดปุ่มให้ แต่ extension อาจข้าม)
      IF ls_payment-payment_accounting_document IS NOT INITIAL.
        lv_any_failed = abap_true.

        LOOP AT lt_selected INTO ls_selected
          WHERE PaymentUuid = ls_payment-payment_uuid.

          APPEND VALUE #( %tky = ls_selected-%tky
                          %msg = new_message( id       = gc_msgid
                                              number   = '007'
                                              severity = if_abap_behv_message=>severity-error
                                              v1       = ls_payment-payment_document_no
                                              v2       = ls_payment-payment_accounting_document ) ) TO reported-item.
        ENDLOOP.

        CONTINUE.
      ENDIF.

      " 5.3 validate payment ต้องมี reject reason อย่างน้อย 1 item
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

    " 6. เตรียม record ให้ SFDC — ทุก item ของทุก payment
    " ลำดับใน lt_record = ลำดับใน lt_record_item เพื่อ map error_index กลับคืนแถวเดิม
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

    " เช็คว่าถ้าเกิน limit ของ Composite API ให้ปฏิเสธทั้งหมด
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

    " 7. ยิง SFDC ก่อน write ลง DB
    " ถ้า SFDC ไม่รับ = ไม่มีอะไร write ลง DB เปิดให้ user กด Reject ซ้ำได้
    " ปิดการยิง SFDC ชั่วคราวเพื่อทดสอบฝั่ง SAP — บรรทัดล่างจำลองว่า SFDC รับทุก record
    " เปิดบรรทัดจริงกลับและลบบรรทัดจำลองก่อน handover
*   DATA(ls_send) = NEW zcl_zare002_sfdc_result( )->send( lt_record ).
    DATA(ls_send) = VALUE zcl_zare002_sfdc_result=>ty_result( success      = abap_true
                                                              record_count = lines( lt_record ) ).

    IF ls_send-success = abap_false.
      failed-item = VALUE #( FOR ls_fail IN lt_selected
                             ( %tky               = ls_fail-%tky
                               %action-rejectItem = if_abap_behv=>mk-on
                               %fail-cause        = if_abap_behv=>cause-unspecific ) ).

      " message ชี้ไปที่ item แต่ถ้าระบุ item ไม่ได้จะเลือกแถวแรกเสมอ
      DATA(ls_culprit) = VALUE #( lt_record_item[ ls_send-error_index ] OPTIONAL ).

      IF ls_culprit IS INITIAL.
        READ TABLE lt_selected INTO ls_selected INDEX 1.
        ls_culprit-%tky = ls_selected-%tky.
      ENDIF.

      IF ls_send-http_status = 0
         OR ls_send-error_code = zcl_zare002_sfdc_result=>gc_err_not_reachable
         OR ls_send-error_code = zcl_zare002_sfdc_result=>gc_err_parse.
        " ต่อไม่ถึง / อื่นๆ
        APPEND VALUE #( %tky = ls_culprit-%tky
                        %msg = new_message( id       = gc_msgid
                                            number   = '006'
                                            severity = if_abap_behv_message=>severity-error
                                            v1       = |{ ls_send-http_status }| ) ) TO reported-item.
      ELSE.
        " SFDC ปฏิเสธ — บอก errorCode + ข้อความ (ตัดแค่ 50 digits)
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

    " 8. ส่งให้ SFDC สำเร็จ > write ลง buffer เพื่อให้ saver stamp header ตอน save phase
    " MODIFY ด้านล่างเขียน RejectReason ด้วยค่าเดิมโดยตั้งใจ — บังคับให้ save phase เกิดขึ้นแน่นอน
    " ถ้าไม่ทำ framework อาจข้าม save เพราะ item ไม่มีอะไรเปลี่ยน แล้ว saver จะไม่ถูกเรียก (ห้ามลบออก)
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

    " 9. คืน instance ที่ติ๊กกลับไปให้ Fiori Element โหลดแถวใหม่ (icon/readonly/button)
    READ ENTITIES OF zr_zare002 IN LOCAL MODE
      ENTITY Item
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_result IN lt_result
                      ( %tky   = ls_result-%tky
                        %param = ls_result ) ).

  ENDMETHOD.


  METHOD read_payment_state.

    IF it_payment_uuid IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lr_payment_uuid) = VALUE tr_uuid( FOR lv_uuid IN it_payment_uuid
                                           ( sign = 'I' option = 'EQ' low = lv_uuid ) ).

    SELECT PaymentUuid                AS payment_uuid,
           Status                     AS status,
           PaymentAccountingDocument  AS payment_accounting_document,
           ClearingAccountingDocument AS clearing_accounting_document
      FROM zi_zare002_pymt
      WHERE PaymentUuid IN @lr_payment_uuid
      INTO TABLE @rt_state.

  ENDMETHOD.

ENDCLASS.


"! saver ของ BO (with additional save) — ทำงานหลัง managed runtime เขียน ztar_i002_item แล้ว
"! หน้าที่เดียวคือ stamp header ตามที่ action จดไว้ใน ZCL_ZARE002_STATUS_BUFFER
"! redefine ได้แค่ save_modified + cleanup_finalize (cleanup/save เป็นของ unmanaged save)
CLASS lsc_Item DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    " หลัง managed runtime เขียน ztar_i002_item แล้ว > stamp header ตามที่ action จดไว้ใน buffer
    " ถึงตรงนี้ได้แปลว่า SFDC รับแล้ว (rejectItem ยิงก่อน) > salesforce_status = S ด้วย
    " เขียนเฉพาะ field ด้วย UPDATE ... SET — ห้าม MODIFY ทั้ง row
    METHODS save_modified REDEFINITION.

    " clear buffer ทุกครั้งที่จบ LUW — ทั้ง commit และ rollback
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
