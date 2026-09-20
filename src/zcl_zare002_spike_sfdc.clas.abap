CLASS zcl_zare002_spike_sfdc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

ENDCLASS.


CLASS zcl_zare002_spike_sfdc IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    TRY.
        DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                                 comm_scenario = 'ZCS_REJECT_RESULT'
                                 service_id    = 'ZARE002_REJECT_RESULT_REST' ).
        DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

        lo_client->get_http_request( )->set_uri_path(
          '/services/data/v66.0/sobjects/cgcloud__Order_Payment__c/describe' ).

        DATA(lo_response) = lo_client->execute( if_web_http_client=>get ).
        DATA(lv_json)     = lo_response->get_text( ).
        out->write( |HTTP { lo_response->get_status( )-code } · { strlen( lv_json ) } chars| ).
        lo_client->close( ).

        " API name ของ field อยู่ใน "name":"..." — เอาเฉพาะที่ขึ้นต้น BST_
        FIND ALL OCCURRENCES OF PCRE '"name":"(BST_[A-Za-z0-9_]+)"'
             IN lv_json RESULTS DATA(lt_match).

        LOOP AT lt_match INTO DATA(ls_match).
          DATA(ls_sub) = ls_match-submatches[ 1 ].
          out->write( substring( val = lv_json off = ls_sub-offset len = ls_sub-length ) ).
        ENDLOOP.

        IF lt_match IS INITIAL.
          out->write( substring( val = lv_json
                                 len = nmin( val1 = strlen( lv_json ) val2 = 800 ) ) ).
        ENDIF.

      CATCH cx_root INTO DATA(lx_error).
        out->write( lx_error->get_text( ) ).
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
