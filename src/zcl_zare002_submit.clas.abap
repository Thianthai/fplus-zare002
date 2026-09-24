"! submit 1 payment
"! validate + post JE + บันทึกเลขเอกสาร payment/message ลง ztar_i002_pymt
"! 1 payment = 1 LUW — ต้องเรียกนอก RAP (HTTP service API)
"! ยังไม่เรียก BOT และยังไม่บันทึก Status
CLASS zcl_zare002_submit DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      "! outcome ของ 1 payment
      "! P = post รอบนี้
      "! A = post ไว้แล้ว รอ clearing
      "! E = ไม่ผ่าน
      gc_outcome_posted  TYPE c LENGTH 1 VALUE 'P',
      gc_outcome_already TYPE c LENGTH 1 VALUE 'A',
      gc_outcome_error   TYPE c LENGTH 1 VALUE 'E',

      gc_msgid           TYPE symsgid           VALUE 'ZARE002',
      gc_status_rejected TYPE ze_request_status VALUE 'R',
      gc_status_complete TYPE ze_request_status VALUE 'C',

      "! ค่าใน payment_method ที่ต้อง post มือ (ZARI002 เก็บเป็นคำ)
      gc_method_cheque   TYPE ztar_i002_pymt-payment_method VALUE 'Cheque',

      "! ความยาวสูงสุดของ message จาก FI ที่เก็บได้
      "! แบ่งใส่ &2&3&4 ของ message number 108 ส่วนละ 50 ตัว
      "! 150 + ข้อความนำหน้า "Payment <no>: " = ไม่เกิน 200 ตัวของ submit_message
      gc_message_max     TYPE i VALUE 150.

    TYPES:
      "! ผลของ 1 payment — caller เอาไปตอบ Fiori ตรงๆ
      BEGIN OF ty_result,
        payment_uuid        TYPE sysuuid_x16,
        payment_document_no TYPE ztar_i002_pymt-payment_document_no,
        outcome             TYPE c LENGTH 1,
        accounting_document TYPE ztar_i002_pymt-payment_accounting_document,
        fiscal_year         TYPE ztar_i002_pymt-payment_fiscal_year,
        message             TYPE string,
      END OF ty_result.

    "! ทำ 1 payment
    "! validate + post + บันทึก
    "! iv_simulate = สร้าง payload แล้วหยุด ไม่ post ไม่เขียนลง DB (et_entry คืน payload ไว้พิมพ์ออก console)
    METHODS process
      IMPORTING iv_payment_uuid  TYPE sysuuid_x16
                iv_simulate      TYPE abap_bool DEFAULT abap_false
      EXPORTING et_entry         TYPE zcl_zare002_journal_entry=>tt_entry
      RETURNING VALUE(rs_result) TYPE ty_result.

  PRIVATE SECTION.

    TYPES:
      "! header ที่ต้องใช้ทั้ง validate และ build
      BEGIN OF ty_header,
        payment_uuid                 TYPE sysuuid_x16,
        payment_document_no          TYPE ztar_i002_pymt-payment_document_no,
        request_id                   TYPE ztar_i002_pymt-request_id,
        company_code                 TYPE ztar_i002_pymt-company_code,
        posting_date                 TYPE ztar_i002_pymt-posting_date,
        gl_account                   TYPE ztar_i002_pymt-gl_account,
        payment_method               TYPE ztar_i002_pymt-payment_method,
        currency                     TYPE ztar_i002_pymt-currency,
        payment_amount               TYPE ztar_i002_pymt-payment_amount,
        fees                         TYPE ztar_i002_pymt-fees,
        rounding_diff                TYPE ztar_i002_pymt-rounding_diff,
        advance_payment              TYPE ztar_i002_pymt-advance_payment,
        status                       TYPE ze_request_status,
        payment_accounting_document  TYPE ztar_i002_pymt-payment_accounting_document,
        payment_fiscal_year          TYPE ztar_i002_pymt-payment_fiscal_year,
        clearing_accounting_document TYPE ztar_i002_pymt-clearing_accounting_document,
      END OF ty_header.

    "! อ่าน header + item จาก DB
    METHODS read_payment
      IMPORTING iv_payment_uuid TYPE sysuuid_x16
      EXPORTING es_header       TYPE ty_header
                et_item         TYPE zcl_zare002_journal_entry=>tt_item
      RETURNING VALUE(rv_found) TYPE abap_bool.

    "! คืน message แรกที่ไม่ผ่าน (ว่าง = ผ่าน)
    METHODS validate
      IMPORTING is_header         TYPE ty_header
                it_item           TYPE zcl_zare002_journal_entry=>tt_item
      RETURNING VALUE(rv_message) TYPE string.

    "! บันทึกเลขเอกสาร (ถ้ามี) + message ลง header แล้ว COMMIT WORK
    "! เลขเอกสารกับปีบัญชีต้องมาคู่กันเสมอ เก็บแยกกันไม่ได้
    METHODS save_result
      IMPORTING iv_payment_uuid        TYPE sysuuid_x16
                iv_accounting_document TYPE ztar_i002_pymt-payment_accounting_document OPTIONAL
                iv_fiscal_year         TYPE ztar_i002_pymt-payment_fiscal_year OPTIONAL
                iv_message             TYPE string.

    "! text ของ message class — MESSAGE ... INTO
    "! placeholder ละไม่เกิน 50 digits
    METHODS message_text
      IMPORTING iv_number      TYPE symsgno
                iv_v1          TYPE simple OPTIONAL
                iv_v2          TYPE simple OPTIONAL
                iv_v3          TYPE simple OPTIONAL
                iv_v4          TYPE simple OPTIONAL
      RETURNING VALUE(rv_text) TYPE string.

    "! แบ่ง message ของ FI เป็น 3 ส่วน ส่วนละ 50 ตัวสำหรับ &2&3&4 ของ message number 108
    METHODS fi_message_chunks
      IMPORTING iv_message TYPE string
      EXPORTING ev_chunk1  TYPE string
                ev_chunk2  TYPE string
                ev_chunk3  TYPE string.

ENDCLASS.


CLASS zcl_zare002_submit IMPLEMENTATION.

  METHOD process.

    DATA ls_header                      TYPE ty_header.
    DATA lt_item                        TYPE zcl_zare002_journal_entry=>tt_item.
    DATA lv_payment_accounting_document TYPE ztar_i002_pymt-payment_accounting_document.
    DATA lv_payment_fiscal_year         TYPE ztar_i002_pymt-payment_fiscal_year.

    CLEAR et_entry.
    rs_result-payment_uuid = iv_payment_uuid.
    rs_result-outcome      = gc_outcome_error.

    " 1. read payment จาก DB
    DATA(lv_found) = read_payment( EXPORTING iv_payment_uuid = iv_payment_uuid
                                   IMPORTING es_header       = ls_header
                                             et_item         = lt_item ).

    IF lv_found = abap_false.
      rs_result-message = message_text( iv_number = '101'
                                        iv_v1     = |{ iv_payment_uuid }| ).

      RETURN.
    ENDIF.

    rs_result-payment_document_no = ls_header-payment_document_no.

    " 2. ใบที่ post ไว้แล้วแต่ยังไม่มี clearing ให้ทำต่อจากที่ค้าง ไม่ post ซ้ำ ให้ caller ไปเรียก BOT เพื่อทำ clearing ต่อได้เลย
    " ใบที่ reject แล้วไม่เข้าเงื่อนไขนี้ ปล่อยให้ตกไป validate เพื่อได้ message 102
    IF  ls_header-payment_accounting_document IS NOT INITIAL
    AND ls_header-clearing_accounting_document IS INITIAL
    AND ls_header-status <> gc_status_rejected.

      rs_result-outcome             = gc_outcome_already.
      rs_result-accounting_document = ls_header-payment_accounting_document.
      rs_result-fiscal_year         = ls_header-payment_fiscal_year.
      rs_result-message             = message_text( iv_number = '103'
                                                    iv_v1     = ls_header-payment_document_no
                                                    iv_v2     = ls_header-payment_accounting_document ).

      RETURN.
    ENDIF.

    " 3. validate
    rs_result-message = validate( is_header = ls_header
                                  it_item   = lt_item ).

    IF rs_result-message IS NOT INITIAL.
      IF iv_simulate = abap_false.
        save_result( iv_payment_uuid = iv_payment_uuid
                     iv_message      = rs_result-message ).
      ENDIF.

      RETURN.
    ENDIF.

    " 4. ป้องกัน post ซ้ำ รอบก่อนอาจ commit แล้วแต่บันทึกเลขไม่ทัน > ต้องเอาเลขเดิมมาใช้
    zcl_zare002_journal_entry=>find_document(
      EXPORTING iv_company_code        = ls_header-company_code
                iv_reference           = ls_header-payment_document_no
                iv_posting_date        = ls_header-posting_date
      IMPORTING ev_accounting_document = lv_payment_accounting_document
                ev_fiscal_year         = lv_payment_fiscal_year ).

    " เช็คว่าใบนี้เคย post ไปแล้วหรือยัง
    IF lv_payment_accounting_document IS NOT INITIAL.

      " ถ้าเคย post ไปแล้ว เช็คต่อว่ามี payment ใบอื่นที่จองเลขนี้ไว้แล้วหรือเปล่า
      SELECT SINGLE @abap_true
        FROM ztar_i002_pymt
        WHERE payment_accounting_document = @lv_payment_accounting_document
          AND payment_fiscal_year         = @lv_payment_fiscal_year
          AND payment_uuid               <> @iv_payment_uuid
        INTO @DATA(lv_used_elsewhere).

      IF lv_used_elsewhere = abap_false.
        rs_result-outcome             = gc_outcome_posted.
        rs_result-accounting_document = lv_payment_accounting_document.
        rs_result-fiscal_year         = lv_payment_fiscal_year.
        rs_result-message             = message_text( iv_number = '109'
                                                      iv_v1     = ls_header-payment_document_no
                                                      iv_v2     = lv_payment_accounting_document ).

        IF iv_simulate = abap_false.
          save_result( iv_payment_uuid        = iv_payment_uuid
                       iv_accounting_document = lv_payment_accounting_document
                       iv_fiscal_year         = lv_payment_fiscal_year
                       iv_message             = rs_result-message ).
        ENDIF.

        RETURN.
      ENDIF.
    ENDIF.

    " 5. build
    et_entry = zcl_zare002_journal_entry=>build( is_payment = CORRESPONDING #( ls_header )
                                                 it_item    = lt_item ).

    IF iv_simulate = abap_true.
      rs_result-message = `simulate: payload built, nothing posted`.
      RETURN.
    ENDIF.

    " 6. post (LUW ของ JE) แล้วบันทึกผล (LUW ของเรา)
    DATA(ls_post) = zcl_zare002_journal_entry=>post( et_entry ).

    IF ls_post-success = abap_false.
      fi_message_chunks( EXPORTING iv_message = ls_post-message
                         IMPORTING ev_chunk1  = DATA(lv_chunk1)
                                   ev_chunk2  = DATA(lv_chunk2)
                                   ev_chunk3  = DATA(lv_chunk3) ).

      rs_result-message = message_text( iv_number = '108'
                                        iv_v1     = ls_header-payment_document_no
                                        iv_v2     = lv_chunk1
                                        iv_v3     = lv_chunk2
                                        iv_v4     = lv_chunk3 ).

      save_result( iv_payment_uuid = iv_payment_uuid
                   iv_message      = rs_result-message ).

      RETURN.
    ENDIF.

    rs_result-outcome             = gc_outcome_posted.
    rs_result-accounting_document = ls_post-accounting_document.
    rs_result-fiscal_year         = ls_post-fiscal_year.
    rs_result-message             = COND #( WHEN ls_post-accounting_document IS NOT INITIAL
                                            THEN message_text( iv_number = '109'
                                                               iv_v1     = ls_header-payment_document_no
                                                               iv_v2     = ls_post-accounting_document )
                                            " commit ผ่านแต่ query ยังไม่เห็น — เลขจะถูกเก็บรอบถัดไปผ่านข้อ 4.
                                            ELSE message_text( iv_number = '108'
                                                               iv_v1     = ls_header-payment_document_no
                                                               iv_v2     = `posted, document number not found yet` ) ).

    save_result( iv_payment_uuid        = iv_payment_uuid
                 iv_accounting_document = ls_post-accounting_document
                 iv_fiscal_year         = ls_post-fiscal_year
                 iv_message             = rs_result-message ).

  ENDMETHOD.


  METHOD read_payment.

    CLEAR: es_header, et_item.

    rv_found = abap_false.

    SELECT SINGLE
      FROM ztar_i002_pymt
      FIELDS payment_uuid,
             payment_document_no,
             request_id,
             company_code,
             posting_date,
             gl_account,
             payment_method,
             currency,
             payment_amount,
             fees,
             rounding_diff,
             advance_payment,
             status,
             payment_accounting_document,
             payment_fiscal_year,
             clearing_accounting_document
      WHERE payment_uuid = @iv_payment_uuid
      INTO CORRESPONDING FIELDS OF @es_header.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SELECT FROM ztar_i002_item
      FIELDS customer_code,
             accounting_document,
             billing_document,
             amount_paid
      WHERE payment_uuid = @iv_payment_uuid
      ORDER BY accounting_document
      INTO CORRESPONDING FIELDS OF TABLE @et_item.

    rv_found = abap_true.

  ENDMETHOD.


  METHOD validate.

    " 1. validate เคส reject แล้ว / complete แล้ว / มีครบ 2 doc (payment + clearing)
    IF is_header-status = gc_status_rejected
    OR is_header-status = gc_status_complete
    OR ( is_header-payment_accounting_document IS NOT INITIAL AND is_header-clearing_accounting_document IS NOT INITIAL ).
      rv_message = message_text( iv_number = '102'
                                 iv_v1     = is_header-payment_document_no
                                 iv_v2     = is_header-status ).
      RETURN.
    ENDIF.

    " 2. validate เคส payment_method = "Cheque" ต้อง post มือเอง โปรแกรมไม่รองรับ
    IF is_header-payment_method = gc_method_cheque.
      rv_message = message_text( iv_number = '104'
                                 iv_v1     = is_header-payment_document_no ).
      RETURN.
    ENDIF.

    " 3. validate mandatory
    DATA(lv_missing) = COND string( WHEN it_item IS INITIAL THEN `items`
                                    WHEN is_header-gl_account IS INITIAL THEN `G/L account`
                                    WHEN is_header-currency IS INITIAL THEN `currency`
                                    WHEN line_exists( it_item[ customer_code = '' ] ) THEN `customer code` ).

    IF lv_missing IS NOT INITIAL.
      rv_message = message_text( iv_number = '105'
                                 iv_v1     = is_header-payment_document_no
                                 iv_v2     = lv_missing ).
      RETURN.
    ENDIF.

    " 4. validate balance ของทุกขาบัญชี
    " payment_amount + fees - sum( amount_paid ) - rounding_diff - advance_payment = 0
    " payment_amount  ยอดสุทธิที่เข้าบัญชีธนาคารจริง (บรรทัด 001 เดบิต)
    " fees            ค่าธรรมเนียมที่ธนาคารหักไว้ ลูกค้าจ่ายมาเต็มแต่เข้าบัญชีไม่เต็ม (002 เดบิต)
    " amount_paid     ยอดที่ตัดออกจากลูกหนี้รายบรรทัด รวมทุก item (003 เครดิต)(CN ติดลบกลับข้างเอง)
    " rounding_diff   ส่วนต่างปัดเศษสตางค์ / บวก = เก็บเกิน (004 เครดิต) / ลบ = ขาด (004 เดบิต)
    " advance_payment บวก = รับเงินล่วงหน้าเพิ่ม (005 เครดิต) / ลบ = ดึงของเก่ามาใช้ (005 เดบิต)
    DATA(lv_difference) = zcl_zare002_journal_entry=>check_balance( is_payment = CORRESPONDING #( is_header )
                                                                    it_item    = it_item ).

    IF lv_difference <> 0.
      rv_message = message_text( iv_number = '106'
                                 iv_v1     = is_header-payment_document_no
                                 iv_v2     = |{ lv_difference }| ).
      RETURN.
    ENDIF.

    " 5. เงินรับล่วงหน้าติดลบ = ใบนี้ "ใช้" เงินที่ลูกค้าเคยจ่ายล่วงหน้าไว้มาหักกับ invoice
    " เงินรับล่วงหน้าถูกบันทึกไว้ตั้งแต่ payment ใบก่อน เป็นเครดิตลูกหนี้ Special G/L Z ที่ยังไม่ถูก clear
    " บรรทัด 005 ของใบก่อน ตอน advance_payment เป็นบวก และยังค้างเป็น open item อยู่จนถึงตอนนี้
    " ใบนี้จึงกลับข้างเป็นเดบิต Special G/L Z เพื่อล้างยอดค้างนั้น แล้วให้ BOT clear คู่กันทีหลัง
    "
    " ให้ post ได้ก็ต่อเมื่อสองฝั่งนี้เท่ากันพอดี
    " lv_open = ยอดค้างที่สะสมอยู่ในระบบ (ทุกเอกสารเก่าของลูกค้ารายนี้ที่ยังไม่ clear)
    " is_header-advance_payment = ยอดที่ใบนี้ขอใช้
    " ค้างน้อยกว่าที่ขอใช้ = เงินล่วงหน้าไม่พอ
    " ค้างมากกว่า = ใช้ไม่หมด (ไม่ให้ใช้แค่บางส่วน)
    "
    " เทียบเครื่องหมายตรงๆได้เพราะเป็นลบทั้งคู่ — ยอดค้างเป็นเครดิต(ลบ) และยอดที่ขอใช้ก็ส่งมาเป็นลบ
    " customer ตัวแรกพอ — 1 payment มี customer เดียว
    IF is_header-advance_payment < 0.
      DATA(lv_open) = zcl_zare002_journal_entry=>read_special_gl_open_amount(
                        iv_company_code = is_header-company_code
                        iv_customer     = it_item[ 1 ]-customer_code ).

      IF lv_open <> is_header-advance_payment.
        rv_message = message_text( iv_number = '107' ).
        RETURN.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD save_result.

    DATA lv_now TYPE abp_lastchange_tstmpl.

    GET TIME STAMP FIELD lv_now.
    DATA(lv_user)    = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_message) = CONV ztar_i002_pymt-submit_message( iv_message ).

    IF iv_accounting_document IS NOT INITIAL.

      UPDATE ztar_i002_pymt
        SET payment_accounting_document = @iv_accounting_document,
            payment_fiscal_year         = @iv_fiscal_year,
            submit_message              = @lv_message,
            last_changed_by             = @lv_user,
            last_changed_at             = @lv_now,
            local_last_changed_at       = @lv_now
        WHERE payment_uuid = @iv_payment_uuid.

    ELSE.

      UPDATE ztar_i002_pymt
        SET submit_message        = @lv_message,
            last_changed_by       = @lv_user,
            last_changed_at       = @lv_now,
            local_last_changed_at = @lv_now
        WHERE payment_uuid = @iv_payment_uuid.

    ENDIF.

    COMMIT WORK.

  ENDMETHOD.


  METHOD message_text.

    MESSAGE ID gc_msgid TYPE 'I' NUMBER iv_number WITH iv_v1 iv_v2 iv_v3 iv_v4 INTO rv_text.

  ENDMETHOD.


  METHOD fi_message_chunks.

    DATA(lv_text) = substring( val = iv_message
                               len = nmin( val1 = strlen( iv_message )
                                           val2 = gc_message_max ) ).

    ev_chunk1 = substring( val = lv_text
                           off = 0
                           len = nmin( val1 = strlen( lv_text )
                                       val2 = 50 ) ).

    ev_chunk2 = COND #( WHEN strlen( lv_text ) > 50
                        THEN substring( val = lv_text
                                        off = 50
                                        len = nmin( val1 = strlen( lv_text ) - 50
                                                    val2 = 50 ) ) ).

    ev_chunk3 = COND #( WHEN strlen( lv_text ) > 100
                        THEN substring( val = lv_text
                                        off = 100
                                        len = nmin( val1 = strlen( lv_text ) - 100
                                                    val2 = 50 ) ) ).

  ENDMETHOD.

ENDCLASS.
