"! งาน background ของ bgPF สำหรับปุ่ม Refresh ของ report ZARE002
"! หาใบที่ post แล้วรอ clear แต่ user clear invoice เองในระบบโดยไม่ผ่าน BOT
"! แล้วปิดใบผ่าน ZCL_ZARI003_CLEARING_RESULT แบบเดียวกับที่ BOT ส่งผลมา
"! บันทึกเลข clearing ตั้งสถานะ Cleared ปิดใบรับชำระบางส่วน และแจ้ง Salesforce ครบเหมือนกรณี BOT
"! ใช้แบบ transactional uncontrolled เพราะ ZCL_ZARI003_CLEARING_RESULT ยิง HTTP และ COMMIT WORK เอง
CLASS zcl_zare002_refresh_bg DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_bgmc_op_single_tx_uncontr.

    TYPES:
      "! item 1 ตัวของใบที่รอ clear
      "! invoice_fiscal_year คือปีของ invoice_posting_date
      BEGIN OF ty_item,
        payment_uuid                TYPE ztar_i002_pymt-payment_uuid,
        company_code                TYPE ztar_i002_pymt-company_code,
        payment_accounting_document TYPE ztar_i002_pymt-payment_accounting_document,
        payment_fiscal_year         TYPE ztar_i002_pymt-payment_fiscal_year,
        accounting_document         TYPE ztar_i002_item-accounting_document,
        invoice_posting_date        TYPE ztar_i002_item-invoice_posting_date,
        invoice_fiscal_year         TYPE i_operationalacctgdocitem-fiscalyear,
        partial_amount              TYPE ztar_i002_item-partial_amount,
      END OF ty_item,

      "! item ของทุกใบที่รอ clear
      tt_item TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY,

      "! บรรทัดลูกค้าของ invoice พร้อมเลข clearing
      "! clearing_document ว่าง = บรรทัดนี้ยังไม่ถูก clear
      BEGIN OF ty_invoice_line,
        company_code         TYPE i_operationalacctgdocitem-companycode,
        accounting_document  TYPE i_operationalacctgdocitem-accountingdocument,
        fiscal_year          TYPE i_operationalacctgdocitem-fiscalyear,
        clearing_document    TYPE i_operationalacctgdocitem-clearingjournalentry,
        clearing_fiscal_year TYPE i_operationalacctgdocitem-clearingjournalentryfiscalyear,
      END OF ty_invoice_line,

      "! บรรทัดลูกค้าของทุก invoice ที่เกี่ยวข้อง
      tt_invoice_line TYPE STANDARD TABLE OF ty_invoice_line WITH EMPTY KEY,

      "! ผลที่จะส่งเข้า ZCL_ZARI003_CLEARING_RESULT 1 แถวต่อ 1 ใบ
      tt_request TYPE STANDARD TABLE OF zcl_zari003_clearing_result=>ty_request WITH EMPTY KEY.

    CONSTANTS:
      "! สถานะของใบที่ post แล้วรอ clear
      gc_status_submitted TYPE ze_request_status VALUE 'S',

      "! ค่าใน partial_amount ของ item ที่รับชำระบางส่วน
      gc_partial          TYPE ztar_i002_item-partial_amount VALUE 'X',

      "! ค่าใน request_id บอกว่าผลมาจากปุ่ม Refresh ไม่ใช่จาก BOT
      gc_request_id       TYPE string VALUE `ZARE002_REFRESH`.

    "! ลงทะเบียนงานไว้ทำหลัง commit ของ LUW ที่เรียก
    "! ไม่ยิง HTTP และไม่ COMMIT จึงเรียกใน save phase ของ RAP ได้
    "! @parameter rv_error | ข้อความเมื่อลงทะเบียนไม่ได้ ว่าง = สำเร็จ
    CLASS-METHODS schedule
      RETURNING VALUE(rv_error) TYPE string.

    "! ตัดสินว่าใบไหนถูก clear ครบแล้ว
    "! ใบที่ปิดได้ต้องเจอบรรทัดลูกค้าของ invoice ทุก item และทุกบรรทัดมีเลข clearing
    "! ใช้เลข clearing ของ item ที่ accounting_document น้อยที่สุด
    "! ปกติทุก item ถูก clear ด้วยเลขเดียวกัน ต่างกันได้เมื่อ user clear พลาด
    "! ข้ามใบรับชำระบางส่วน เพราะใบสุดท้ายของ invoice เดียวกันปิดให้แล้ว และกันแจ้ง Salesforce ซ้ำ
    "! @parameter it_item    | item ของทุกใบที่รอ clear
    "! @parameter it_line    | บรรทัดลูกค้าของ invoice
    "! @parameter rt_request | ใบที่ปิดได้
    CLASS-METHODS decide
      IMPORTING it_item           TYPE tt_item
                it_line           TYPE tt_invoice_line
      RETURNING VALUE(rt_request) TYPE tt_request.

ENDCLASS.



CLASS zcl_zare002_refresh_bg IMPLEMENTATION.


  METHOD schedule.

    TRY.
        DATA(lo_process) = cl_bgmc_process_factory=>get_default( )->create( ).

        lo_process->set_name( 'ZARE002 refresh clearing' ).
        lo_process->set_operation_tx_uncontrolled( NEW zcl_zare002_refresh_bg( ) ).

        " งานจะเริ่มหลัง commit ของ LUW ที่เรียก ถ้า rollback งานจะหายไปด้วย
        lo_process->save_for_execution( ).

      CATCH cx_bgmc INTO DATA(lx_bgmc).
        rv_error = lx_bgmc->get_text( ).
    ENDTRY.

  ENDMETHOD.


  METHOD if_bgmc_op_single_tx_uncontr~execute.

    DATA lt_item TYPE tt_item.
    DATA lt_line TYPE tt_invoice_line.

    " 1. item ของทุกใบที่ post แล้วรอ clear
    SELECT FROM ztar_i002_pymt AS payment
      INNER JOIN ztar_i002_item AS item
        ON item~payment_uuid = payment~payment_uuid
      FIELDS payment~payment_uuid,
             payment~company_code,
             payment~payment_accounting_document,
             payment~payment_fiscal_year,
             item~accounting_document,
             item~invoice_posting_date,
             item~partial_amount
      WHERE payment~status                       = @gc_status_submitted
        AND payment~payment_accounting_document  <> @space
        AND payment~clearing_accounting_document = @space
      INTO CORRESPONDING FIELDS OF TABLE @lt_item.

    IF lt_item IS INITIAL.
      RETURN.
    ENDIF.

    " ปีบัญชีของ invoice ใช้ปีของ posting date
    LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<lfs_item>).
      <lfs_item>-invoice_fiscal_year = <lfs_item>-invoice_posting_date(4).
    ENDLOOP.

    " 2. บรรทัดลูกค้าของ invoice ที่ไม่ใช่ Special G/L พร้อมเลข clearing
    SELECT FROM i_operationalacctgdocitem
      FIELDS CompanyCode                    AS company_code,
             AccountingDocument             AS accounting_document,
             FiscalYear                     AS fiscal_year,
             ClearingJournalEntry           AS clearing_document,
             ClearingJournalEntryFiscalYear AS clearing_fiscal_year
      FOR ALL ENTRIES IN @lt_item
      WHERE CompanyCode          = @lt_item-company_code
        AND AccountingDocument   = @lt_item-accounting_document
        AND FiscalYear           = @lt_item-invoice_fiscal_year
        AND FinancialAccountType = 'D'
        AND SpecialGLCode        = ''
      INTO TABLE @lt_line.

    " 3. ปิดทีละใบ 1 ใบเท่ากับ 1 LUW ของ ZCL_ZARI003_CLEARING_RESULT
    " ใบที่ถูกปิดไปก่อนแล้ว เช่นกด Refresh ซ้อนกัน ZCL_ZARI003_CLEARING_RESULT จะไม่เขียนทับและไม่แจ้ง Salesforce ซ้ำ
    " ไม่โยน exception กลับให้ bgPF เพราะไม่ต้องการให้ระบบรันซ้ำเอง ใบที่ไม่ผ่านกด Refresh ใหม่ได้
    DATA(lo_clearing) = NEW zcl_zari003_clearing_result( ).

    LOOP AT decide( it_item = lt_item
                    it_line = lt_line ) INTO DATA(ls_request).
      lo_clearing->process( ls_request ).
    ENDLOOP.

  ENDMETHOD.


  METHOD decide.

    DATA lv_cleared  TYPE abap_bool.
    DATA lv_found    TYPE abap_bool.
    DATA lv_has_pick TYPE abap_bool.
    DATA lv_pick_doc TYPE ztar_i002_item-accounting_document.
    DATA ls_pick     TYPE ty_invoice_line.

    LOOP AT it_item INTO DATA(ls_item)
         GROUP BY ( payment_uuid = ls_item-payment_uuid )
         INTO DATA(ls_group).

      lv_cleared  = abap_true.
      lv_has_pick = abap_false.
      CLEAR: lv_pick_doc, ls_pick.

      LOOP AT GROUP ls_group INTO DATA(ls_member).

        " ใบรับชำระบางส่วนปิดโดยใบสุดท้ายของ invoice เดียวกัน
        IF ls_member-partial_amount = gc_partial.
          lv_cleared = abap_false.
          EXIT.
        ENDIF.

        lv_found = abap_false.

        LOOP AT it_line INTO DATA(ls_line)
             WHERE company_code        = ls_member-company_code
               AND accounting_document = ls_member-accounting_document
               AND fiscal_year         = ls_member-invoice_fiscal_year.

          lv_found = abap_true.

          IF ls_line-clearing_document IS INITIAL.
            lv_cleared = abap_false.
          ENDIF.

          " เก็บเลข clearing ของ item ที่ accounting_document น้อยที่สุด
          " invoice ที่มีหลายบรรทัดใช้บรรทัดแรกที่เจอ
          IF lv_has_pick = abap_false OR ls_member-accounting_document < lv_pick_doc.
            lv_has_pick = abap_true.
            lv_pick_doc = ls_member-accounting_document.
            ls_pick     = ls_line.
          ENDIF.

        ENDLOOP.

        " ไม่เจอบรรทัดของ invoice ถือว่ายังปิดไม่ได้
        IF lv_found = abap_false.
          lv_cleared = abap_false.
        ENDIF.

        IF lv_cleared = abap_false.
          EXIT.
        ENDIF.

      ENDLOOP.

      IF lv_cleared = abap_false.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( request_id                  = gc_request_id
                      company_code                = ls_member-company_code
                      payment_accounting_document = ls_member-payment_accounting_document
                      payment_accounting_doc_year = ls_member-payment_fiscal_year
                      clearing_document           = ls_pick-clearing_document
                      clearing_document_year      = ls_pick-clearing_fiscal_year
                      clearing_status             = zcl_zari003_clearing_result=>gc_bot_success ) TO rt_request.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
