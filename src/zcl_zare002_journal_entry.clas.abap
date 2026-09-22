"! สร้างและ post journal entry ของ 1 payment ผ่าน BO interface I_JournalEntryTP (spec Submit ข้อ 3)
"! build เป็น pure method ทดสอบได้โดยไม่ post · post/find_document แตะระบบจริง
"! ต้องเรียกนอก RAP (HTTP service / console) เพราะมี COMMIT ENTITIES · ไม่โยน exception คืน structure
CLASS zcl_zare002_journal_entry DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      "! header ของ payment ที่ builder ต้องใช้ (จาก ztar_i002_pymt)
      BEGIN OF ty_payment,
        payment_uuid        TYPE sysuuid_x16,
        payment_document_no TYPE ztar_i002_pymt-payment_document_no,
        request_id          TYPE ztar_i002_pymt-request_id,
        company_code        TYPE ztar_i002_pymt-company_code,
        posting_date        TYPE ztar_i002_pymt-posting_date,
        gl_account          TYPE ztar_i002_pymt-gl_account,
        currency            TYPE ztar_i002_pymt-currency,
        payment_amount      TYPE ztar_i002_pymt-payment_amount,
        fees                TYPE ztar_i002_pymt-fees,
        rounding_diff       TYPE ztar_i002_pymt-rounding_diff,
        advance_payment     TYPE ztar_i002_pymt-advance_payment,
      END OF ty_payment,

      "! item ของ payment — 1 item = 1 บรรทัดลูกหนี้
      "! billing_document ไม่ได้ใช้ในเอกสารบัญชี เก็บไว้ส่งให้ BOT ตอน clearing (8B.5)
      BEGIN OF ty_item,
        customer_code       TYPE ztar_i002_item-customer_code,
        accounting_document TYPE ztar_i002_item-accounting_document,
        billing_document    TYPE ztar_i002_item-billing_document,
        amount_paid         TYPE ztar_i002_item-amount_paid,
      END OF ty_item,
      tt_item TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY,

      "! payload ของ action Post — 1 แถวต่อ 1 เอกสาร
      tt_entry TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post,

      "! ผลของ post — สำเร็จ = COMMIT ผ่าน · accounting_document ได้จาก find_document หลัง commit
      BEGIN OF ty_post_result,
        success             TYPE abap_bool,
        accounting_document TYPE ztar_i002_pymt-payment_accounting_document,
        message             TYPE string,
      END OF ty_post_result,

      "! บรรทัด text สำหรับพิมพ์ payload ดูก่อน post (simulate)
      tt_text TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    TYPES:
      "! house bank id / account id (hbkid / hktid ไม่ released)
      ty_house_bank         TYPE c LENGTH 5,
      ty_house_bank_account TYPE c LENGTH 5.

    CONSTANTS:
      "! document type ของเอกสารรับชำระ
      gc_doc_type             TYPE c LENGTH 2  VALUE 'DS',

      "! business transaction type ของเอกสารรับชำระ
      gc_bus_trans_type       TYPE c LENGTH 4  VALUE 'RFPI',
      gc_gl_bank_charge       TYPE c LENGTH 10 VALUE '0054030012',
      gc_gl_rounding          TYPE c LENGTH 10 VALUE '0059090001',
      gc_cost_center          TYPE c LENGTH 10 VALUE '2002010000',
      gc_special_gl_code      TYPE c LENGTH 1  VALUE 'Z',
      gc_baseline_days        TYPE i           VALUE 30,

      "! currency role 00 = transaction currency
      gc_currency_role        TYPE c LENGTH 2  VALUE '00',

      "! prefix ของ %cid — ต่อด้วย payment_document_no
      gc_cid_prefix           TYPE string      VALUE 'PAY',

      "! bank charge ต้องมี tax code 0% + business place
      gc_tax_code_bank_charge TYPE c LENGTH 2  VALUE 'WP',

      "! account key ของภาษีซื้อ ใช้คู่กับ tax code WP ในบรรทัด tax statement
      gc_tax_account_key      TYPE c LENGTH 3  VALUE 'VST',

      "! condition type ของภาษีซื้อ ต้องใส่คู่กับ account key ไม่งั้นได้ Error: KSCHL is empty
      gc_tax_condition_type   TYPE c LENGTH 4  VALUE 'MWVS',

      gc_business_place       TYPE c LENGTH 4  VALUE '0000',

      "! G/L bank incoming บังคับระบุ house bank
      "! G/L อีก 4 ตัว (11011212-15) ไม่บังคับ ไม่ต้องระบุ
      gc_gl_bank_scb          TYPE c LENGTH 10 VALUE '0011011211',
      gc_house_bank_scb       TYPE c LENGTH 5  VALUE 'SCB01',
      gc_house_bank_acct_scb  TYPE c LENGTH 5  VALUE 'SA001'.

    "! payment_amount + fees - sum(amount_paid) - rounding_diff - advance_payment ต้องเป็น 0
    "! คืนผลต่าง (0 = balanced)
    CLASS-METHODS check_balance
      IMPORTING is_payment           TYPE ty_payment
                it_item              TYPE tt_item
      RETURNING VALUE(rv_difference) TYPE ztar_i002_pymt-payment_amount.

    "! สร้าง payload 1 เอกสาร: bank / bank charge / ลูกหนี้ต่อ item / rounding / advance (Special G/L)
    "! เครื่องหมายฝั่ง API
    "! เดบิต = บวก
    "! เครดิต = ลบ
    "! บรรทัดที่ยอด 0 = ไม่ส่ง
    CLASS-METHODS build
      IMPORTING is_payment      TYPE ty_payment
                it_item         TYPE tt_item
      RETURNING VALUE(rt_entry) TYPE tt_entry.

    "! แปลง payload เป็นบรรทัด text ไว้พิมพ์ตอน simulate
    CLASS-METHODS describe
      IMPORTING it_entry       TYPE tt_entry
      RETURNING VALUE(rt_text) TYPE tt_text.

    "! EXECUTE post + COMMIT ENTITIES — fail ที่ใดที่หนึ่ง = ROLLBACK ไม่มีเอกสารเกิด
    "! ห้ามเรียกจากใน RAP handler/saver
    CLASS-METHODS post
      IMPORTING it_entry         TYPE tt_entry
      RETURNING VALUE(rs_result) TYPE ty_post_result.

    "! หาเลขเอกสารจาก DocumentReferenceID (late numbering — MAPPED ให้แค่ %pid)
    "! ใช้ทั้งหลัง post และก่อน post เพื่อกันการ post ซ้ำเมื่อรอบก่อน commit แล้วแต่บันทึกเลขไม่ทัน
    CLASS-METHODS find_document
      IMPORTING iv_company_code                TYPE ztar_i002_pymt-company_code
                iv_reference                   TYPE ztar_i002_pymt-payment_document_no
                iv_posting_date                TYPE ztar_i002_pymt-posting_date
      RETURNING VALUE(rv_accounting_document)  TYPE ztar_i002_pymt-payment_accounting_document.

    "! ยอดรวม Special G/L Z open item ของ customer (เครดิตติดลบ) เคส advance ติดลบ
    CLASS-METHODS read_special_gl_open_amount
      IMPORTING iv_company_code  TYPE ztar_i002_pymt-company_code
                iv_customer      TYPE ztar_i002_item-customer_code
      RETURNING VALUE(rv_amount) TYPE ztar_i002_pymt-advance_payment.

    "! house bank / account ของบัญชี bank incoming — มีเฉพาะ G/L ที่บังคับ (mapping คงที่) นอกนั้นว่าง
    CLASS-METHODS derive_house_bank
      IMPORTING iv_gl_account         TYPE ztar_i002_pymt-gl_account
      EXPORTING ev_house_bank         TYPE ty_house_bank
                ev_house_bank_account TYPE ty_house_bank_account.

  PRIVATE SECTION.

    TYPES:
      "! แถวเดียวของ payload — จาก tt_entry เพราะ TABLE FOR ACTION IMPORT รับ path ต่อท้ายไม่ได้
      ty_entry           TYPE LINE OF tt_entry,

      "! _GLItems ของ 1 เอกสาร
      tt_gl_item         TYPE ty_entry-%param-_glitems,
      ty_gl_item         TYPE LINE OF tt_gl_item,

      "! _ARItems ของ 1 เอกสาร
      tt_ar_item         TYPE ty_entry-%param-_aritems,

      "! _TaxItems ของ 1 เอกสาร
      tt_tax_item        TYPE ty_entry-%param-_taxitems,

      "! ยอด 1 บรรทัดใน _CurrencyAmount (โครงเดียวกันทุก node)
      tt_currency_amount TYPE ty_gl_item-_currencyamount,

      "! เลขบรรทัด (docln6)
      "! ต้องเป็นตัวเลขเติมศูนย์ 000001 ไม่ใช่ char ชิดขวาที่มีช่องว่างนำหน้า
      ty_line_no         TYPE n LENGTH 6.

    "! รวบยอด 1 ตัวเป็น _CurrencyAmount
    "! iv_tax_base ใส่เฉพาะบรรทัด tax statement
    CLASS-METHODS amount
      IMPORTING iv_currency      TYPE ztar_i002_pymt-currency
                iv_amount        TYPE ztar_i002_pymt-payment_amount
                iv_tax_base      TYPE ztar_i002_pymt-payment_amount OPTIONAL
      RETURNING VALUE(rt_amount) TYPE tt_currency_amount.

ENDCLASS.


CLASS zcl_zare002_journal_entry IMPLEMENTATION.

  METHOD check_balance.

    rv_difference = is_payment-payment_amount
                  + is_payment-fees
                  - REDUCE #( INIT lv_sum TYPE ztar_i002_item-amount_paid
                              FOR ls_item IN it_item
                              NEXT lv_sum = lv_sum + ls_item-amount_paid )
                  - is_payment-rounding_diff
                  - is_payment-advance_payment.

  ENDMETHOD.


  METHOD amount.

    rt_amount = VALUE #( ( currencyrole           = gc_currency_role
                           currency               = iv_currency
                           journalentryitemamount = iv_amount
                           taxbaseamount          = iv_tax_base ) ).

  ENDMETHOD.


  METHOD build.

    DATA lt_gl_item  TYPE tt_gl_item.
    DATA lt_ar_item  TYPE tt_ar_item.
    DATA lt_tax_item TYPE tt_tax_item.
    DATA lv_line     TYPE i.

    " เลขบรรทัดต้องไล่ให้จบฝั่ง G/L ก่อนแล้วค่อยต่อฝั่ง AR
    " bank 001 / bank charge 002 / rounding 003 แล้วจึง advance 004 / ลูกหนี้ 005
    " ทุกบรรทัดไม่ส่ง assignment ระบบเติมจาก sort key ของแต่ละบัญชีเอง

    " ขาบัญชี 001 G/L Bank Incoming
    " บันทึกบัญชีเงินฝากธนาคารที่รับเงินเข้า
    " payment_amount = ยอดสุทธิที่เข้าบัญชีจริง (หักค่าธรรมเนียมแล้ว) = เดบิตเสมอ
    " G/L มาจาก header ของ payment ที่ SBPA ส่งมา (มี 5 บัญชีตามธนาคาร)
    " ไม่ส่ง assignment ระบบเติมจาก sort key ของบัญชีเอง
    " value date = posting date (วันที่เงินเข้าบัญชีจริง)
    " business place = 0000 ใส่ทุกบรรทัด
    " house bank / account ใส่เฉพาะ G/L ที่ระบบบังคับ ดูจาก derive_house_bank
    derive_house_bank( EXPORTING iv_gl_account         = is_payment-gl_account
                       IMPORTING ev_house_bank         = DATA(lv_house_bank)
                                 ev_house_bank_account = DATA(lv_house_bank_account) ).

    lv_line += 1.
    APPEND VALUE #( glaccountlineitem   = CONV ty_line_no( lv_line )
                    glaccount           = is_payment-gl_account
                    businessplace       = gc_business_place
                    valuedate           = is_payment-posting_date
                    housebank           = lv_house_bank
                    housebankaccount    = lv_house_bank_account
                    _currencyamount     = amount( iv_currency = is_payment-currency
                                                  iv_amount   = is_payment-payment_amount )
                  ) TO lt_gl_item.

    " ขาบัญชี 002 G/L Bank Charge
    " บันทึกค่าธรรมเนียมธนาคาร (ถ้ามี)
    " fees = ส่วนที่ธนาคารหักไว้ ลูกค้าจ่ายเต็มแต่เงินเข้าบัญชีไม่เต็ม = เดบิตเสมอ
    " cost center = 2002010000 (ระบบ derive profit center 2000 ให้เอง)
    " tax code = WP (Non-taxable Purchase 0%)
    " business place = 0000
    " ไม่ส่ง assignment ระบบเติมจาก sort key ของบัญชีเอง
    IF is_payment-fees <> 0.
      lv_line += 1.
      APPEND VALUE #( glaccountlineitem   = CONV ty_line_no( lv_line )
                      glaccount           = gc_gl_bank_charge
                      costcenter          = gc_cost_center
                      taxcode             = gc_tax_code_bank_charge
                      businessplace       = gc_business_place
                      _currencyamount     = amount( iv_currency = is_payment-currency
                                                    iv_amount   = is_payment-fees )
                    ) TO lt_gl_item.
    ENDIF.

    " ขาบัญชี 003 G/L Rounding Adjustment
    " บันทึกส่วนต่างปัดเศษสตางค์ (ถ้ามี)
    " rounding_diff เป็นบวก = เครดิต (ส่ง -rounding_diff)
    " rounding_diff เป็นลบ = เดบิต (ส่ง -rounding_diff)
    " business place = 0000
    " ไม่ส่ง assignment ระบบเติมจาก sort key ของบัญชีเอง
    " ไม่ใส่ tax code ได้ ถึงแม้ G/L master ตั้ง TaxCodeIsRequired ไว้
    IF is_payment-rounding_diff <> 0.
      lv_line += 1.
      APPEND VALUE #( glaccountlineitem   = CONV ty_line_no( lv_line )
                      glaccount           = gc_gl_rounding
                      costcenter          = gc_cost_center
                      businessplace       = gc_business_place
                      _currencyamount     = amount( iv_currency = is_payment-currency
                                                    iv_amount   = - is_payment-rounding_diff )
                    ) TO lt_gl_item.
    ENDIF.

    " ขาบัญชี 004 Customer Special G/L
    " บันทึกเงินรับล่วงหน้า (ถ้ามี) แยกจากบรรทัดลูกหนี้ปกติด้วย Special G/L = Z
    " advance_payment เป็นบวก = รับเงินล่วงหน้าเพิ่ม = เครดิต (ส่ง -advance_payment)
    " advance_payment เป็นลบ = ดึงของเก่ามาใช้หักกับ invoice = เดบิต (ส่ง -advance_payment)
    " เคสติดลบต้องมียอดค้างพอดีกับที่ขอใช้ ดู validate ข้อ 5 ของ ZCL_ZARE002_SUBMIT
    " baseline date = posting date + 30 วัน (ใช้ตั้งวันครบกำหนดของยอดล่วงหน้า)
    " business place = 0000
    " ไม่ส่ง G/L account และ tax code ระบบ derive ให้เองจาก config ของ Special G/L
    " customer ตัวแรกพอ เพราะ 1 payment มี customer เดียว
    " ถ้าไม่มี item = ไม่รู้ว่า customer ไหน ให้ข้ามบรรทัดนี้ไปเลย
    IF is_payment-advance_payment <> 0 AND it_item IS NOT INITIAL.
      lv_line += 1.
      APPEND VALUE #( glaccountlineitem      = CONV ty_line_no( lv_line )
                      customer               = it_item[ 1 ]-customer_code
                      specialglcode          = gc_special_gl_code
                      businessplace          = gc_business_place
                      duecalculationbasedate = is_payment-posting_date + gc_baseline_days
                      _currencyamount        = amount( iv_currency = is_payment-currency
                                                       iv_amount   = - is_payment-advance_payment )
                    ) TO lt_ar_item.
    ENDIF.

    " ขาบัญชี 005 G/L Account Receivable
    " บันทึกล้างลูกหนี้ 1 บรรทัดต่อ 1 item
    " amount_paid เป็นบวก (invoice) = เครดิต (ส่ง -amount_paid)
    " amount_paid เป็นลบ (CN) = เดบิต (ส่ง -amount_paid)
    " business place = 0000
    " ไม่ใส่ assignment และ item text
    " BOT จะจับคู่ตอน clearing จาก customer และจำนวนเงินแทน
    LOOP AT it_item INTO DATA(ls_item).
      lv_line += 1.
      APPEND VALUE #( glaccountlineitem = CONV ty_line_no( lv_line )
                      customer          = ls_item-customer_code
                      businessplace     = gc_business_place
                      _currencyamount   = amount( iv_currency = is_payment-currency
                                                  iv_amount   = - ls_item-amount_paid )
                    ) TO lt_ar_item.
    ENDLOOP.

    " ขาบัญชี 006 tax statement ของขาบัญชี 002 G/L Bank Charge
    " FI ต้องการ tax statement ทุกครั้งที่บรรทัด G/L มี tax code ถึงอัตราจะเป็น 0 ก็ตาม
    " หน้าจอคำนวณและสร้างให้เอง แต่ API ไม่สร้างให้ ต้องส่งมาเอง
    " ไม่งั้นได้ Error: Tax statement item missing for tax code WP
    " ยอดภาษี = 0 เพราะ WP เป็น 0 เปอร์เซ็นต์
    " ฐานภาษี = ยอดค่าธรรมเนียม
    " ไม่ระบุ G/L account ระบบ derive จาก tax code กับ account key เอง
    IF is_payment-fees <> 0.
      lv_line += 1.
      APPEND VALUE #( glaccountlineitem     = CONV ty_line_no( lv_line )
                      taxcode               = gc_tax_code_bank_charge
                      taxitemclassification = gc_tax_account_key
                      conditiontype         = gc_tax_condition_type
                      _currencyamount       = amount( iv_currency = is_payment-currency
                                                      iv_amount   = 0
                                                      iv_tax_base = is_payment-fees )
                    ) TO lt_tax_item.
    ENDIF.

    " header ของเอกสาร
    " doc type = DS
    " business transaction type = RFPI (ของเอกสารรับชำระ)
    " document date = posting date
    " tax determination date = posting date (บังคับใส่เพราะ company code เปิด time-dependent tax)
    " reference = payment_document_no (ไว้หาเลขเอกสารกลับหลัง commit (late numbering))
    " header text = request_id ของ SBPA (ไว้ไล่ย้อนว่ามาจาก request ไหน)
    rt_entry = VALUE #(
      ( %cid   = |{ gc_cid_prefix }{ is_payment-payment_document_no }|
        %param = VALUE #( companycode                  = is_payment-company_code
                          businesstransactiontype      = gc_bus_trans_type
                          accountingdocumenttype       = gc_doc_type
                          documentdate                 = is_payment-posting_date
                          postingdate                  = is_payment-posting_date
                          taxdeterminationdate         = is_payment-posting_date
                          documentreferenceid          = is_payment-payment_document_no
                          accountingdocumentheadertext = is_payment-request_id
                          createdbyuser                = cl_abap_context_info=>get_user_technical_name( )
                          _glitems                     = lt_gl_item
                          _aritems                     = lt_ar_item
                          _taxitems                    = lt_tax_item ) ) ).

  ENDMETHOD.


  METHOD describe.

    LOOP AT it_entry INTO DATA(ls_entry).
      DATA(lv_total) = CONV ztar_i002_pymt-payment_amount( 0 ).

      APPEND |Header {  ls_entry-%param-companycode } { ls_entry-%param-accountingdocumenttype } | &&
             |{ ls_entry-%param-businesstransactiontype } post { ls_entry-%param-postingdate } | &&
             |ref { ls_entry-%param-documentreferenceid } text { ls_entry-%param-accountingdocumentheadertext }|
          TO rt_text.

      LOOP AT ls_entry-%param-_glitems INTO DATA(ls_gl).
        DATA(ls_gl_amount) = VALUE #( ls_gl-_currencyamount[ 1 ] OPTIONAL ).
        lv_total += ls_gl_amount-journalentryitemamount.
        APPEND |  GL [{ ls_gl-glaccountlineitem }] { ls_gl-glaccount } { ls_gl_amount-journalentryitemamount } | &&
               |{ ls_gl_amount-currency } cc { ls_gl-costcenter } tax { ls_gl-taxcode } | &&
               |bplace { ls_gl-businessplace } bank { ls_gl-housebank }/{ ls_gl-housebankaccount } | &&
               |assign { ls_gl-assignmentreference } value { ls_gl-valuedate }|
            TO rt_text.
      ENDLOOP.

      LOOP AT ls_entry-%param-_aritems INTO DATA(ls_ar).
        DATA(ls_ar_amount) = VALUE #( ls_ar-_currencyamount[ 1 ] OPTIONAL ).
        lv_total += ls_ar_amount-journalentryitemamount.
        APPEND |  AR [{ ls_ar-glaccountlineitem }] { ls_ar-customer } spgl { ls_ar-specialglcode } | &&
               |{ ls_ar_amount-journalentryitemamount } { ls_ar_amount-currency } | &&
               |bplace { ls_ar-businessplace } | &&
               |assign { ls_ar-assignmentreference } text { ls_ar-documentitemtext } | &&
               |baseline { ls_ar-duecalculationbasedate }|
            TO rt_text.
      ENDLOOP.

      LOOP AT ls_entry-%param-_taxitems INTO DATA(ls_tax).
        DATA(ls_tax_amount) = VALUE #( ls_tax-_currencyamount[ 1 ] OPTIONAL ).
        lv_total += ls_tax_amount-journalentryitemamount.
        APPEND |  TAX [{ ls_tax-glaccountlineitem }] tax { ls_tax-taxcode } | &&
               |key { ls_tax-taxitemclassification } cond { ls_tax-conditiontype } | &&
               |{ ls_tax_amount-journalentryitemamount } { ls_tax_amount-currency } | &&
               |base { ls_tax_amount-taxbaseamount }|
            TO rt_text.
      ENDLOOP.

      APPEND |  balance { lv_total } (must be 0)| TO rt_text.
    ENDLOOP.

  ENDMETHOD.


  METHOD post.

    DATA lv_message TYPE string.

    MODIFY ENTITIES OF i_journalentrytp
      ENTITY journalentry
      EXECUTE post FROM it_entry
      MAPPED   DATA(ls_mapped)
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    " รวม message ทุกตัว ยกเว้น RW 609 "Error in document: BKPFF ..." ที่ไม่บอกสาเหตุ
    LOOP AT ls_reported-journalentry INTO DATA(ls_msg).
      DATA(ls_t100) = ls_msg-%msg->if_t100_message~t100key.

      IF ls_t100-msgid = 'RW' AND ls_t100-msgno = '609'.
        CONTINUE.
      ENDIF.

      lv_message = lv_message && COND #( WHEN lv_message IS INITIAL THEN `` ELSE ` | ` )
                              && ls_msg-%msg->if_message~get_text( ).
    ENDLOOP.

    IF ls_failed-journalentry IS NOT INITIAL.
      ROLLBACK ENTITIES.
      rs_result-success = abap_false.
      rs_result-message = COND #( WHEN lv_message IS INITIAL THEN `Post failed without message` ELSE lv_message ).
      RETURN.
    ENDIF.

    COMMIT ENTITIES
      RESPONSE OF i_journalentrytp
      FAILED   DATA(ls_commit_failed)
      REPORTED DATA(ls_commit_reported).

    DATA(lv_commit_subrc) = sy-subrc.

    LOOP AT ls_commit_reported-journalentry INTO DATA(ls_commit_msg).
      lv_message = lv_message && COND #( WHEN lv_message IS INITIAL THEN `` ELSE ` | ` )
                              && ls_commit_msg-%msg->if_message~get_text( ).
    ENDLOOP.

    IF lv_commit_subrc <> 0 OR ls_commit_failed-journalentry IS NOT INITIAL.
      rs_result-success = abap_false.
      rs_result-message = COND #( WHEN lv_message IS INITIAL THEN `Commit failed without message` ELSE lv_message ).
      RETURN.
    ENDIF.

    rs_result-success = abap_true.
    rs_result-message = lv_message.

    " เลขเอกสารจริงหาจาก reference — %pid ของ late numbering ใช้ไม่ได้นอก save phase
    DATA(ls_first) = VALUE #( it_entry[ 1 ] OPTIONAL ).
    rs_result-accounting_document = find_document( iv_company_code = ls_first-%param-companycode
                                                   iv_reference    = CONV #( ls_first-%param-documentreferenceid )
                                                   iv_posting_date = ls_first-%param-postingdate ).

  ENDMETHOD.


  METHOD find_document.

    " เอกสารล่าสุดที่ reference ตรง — ไม่ผูกปี เพราะปีบัญชีมาจาก posting date อยู่แล้ว
    SELECT AccountingDocument
      FROM i_journalentry
      WHERE CompanyCode            = @iv_company_code
        AND DocumentReferenceID    = @iv_reference
        AND PostingDate            = @iv_posting_date
        AND AccountingDocumentType = @gc_doc_type
        AND IsReversed             = ''
      ORDER BY AccountingDocument DESCENDING
      INTO @rv_accounting_document
      UP TO 1 ROWS.
    ENDSELECT.

  ENDMETHOD.


  METHOD read_special_gl_open_amount.

    SELECT SUM( AmountInTransactionCurrency )
      FROM i_operationalacctgdocitem
      WHERE CompanyCode                = @iv_company_code
        AND Customer                   = @iv_customer
        AND FinancialAccountType       = 'D'
        AND SpecialGLCode              = @gc_special_gl_code
        AND ClearingJournalEntry       = ''
      INTO @rv_amount.

  ENDMETHOD.


  METHOD derive_house_bank.

    CLEAR: ev_house_bank, ev_house_bank_account.

    " เทียบแบบ 10 หลักมี 0 นำหน้า กันค่าจาก SBPA ที่อาจมาไม่เต็ม
    IF |{ iv_gl_account ALPHA = IN }| = gc_gl_bank_scb.
      ev_house_bank         = gc_house_bank_scb.
      ev_house_bank_account = gc_house_bank_acct_scb.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
