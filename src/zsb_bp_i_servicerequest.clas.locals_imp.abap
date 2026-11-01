"----------------------------------------------------------------------
" Handler: ServiceRequest (root)
"----------------------------------------------------------------------
CLASS lhc_servicerequest DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF c_status,
        new       TYPE zsb_srvreq-status VALUE 'N',
        approved  TYPE zsb_srvreq-status VALUE 'A',
        rejected  TYPE zsb_srvreq-status VALUE 'R',
        completed TYPE zsb_srvreq-status VALUE 'C',
      END OF c_status,
      BEGIN OF c_priority,
        highest TYPE zsb_srvreq-priority VALUE '1',
        lowest  TYPE zsb_srvreq-priority VALUE '4',
      END OF c_priority,
      c_default_currency TYPE zsb_srvreq-currency_code VALUE 'INR',
      c_msgid            TYPE symsgid VALUE 'ZSB_RAP_SRVREQ',
      c_number_range     TYPE cl_numberrange_runtime=>nr_object VALUE 'ZSB_SRVREQ'.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ServiceRequest RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR ServiceRequest RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE ServiceRequest.

    METHODS earlynumbering_cba_item FOR NUMBERING
      IMPORTING entities FOR CREATE ServiceRequest\_Item.

    METHODS approve FOR MODIFY
      IMPORTING keys FOR ACTION ServiceRequest~approve RESULT result.

    METHODS reject FOR MODIFY
      IMPORTING keys FOR ACTION ServiceRequest~reject RESULT result.

    METHODS complete FOR MODIFY
      IMPORTING keys FOR ACTION ServiceRequest~complete RESULT result.

    METHODS setinitialvalues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ServiceRequest~setInitialValues.

    METHODS setrequestid FOR DETERMINE ON SAVE
      IMPORTING keys FOR ServiceRequest~setRequestId.

    METHODS validaterequireddate FOR VALIDATE ON SAVE
      IMPORTING keys FOR ServiceRequest~validateRequiredDate.

    METHODS validateplant FOR VALIDATE ON SAVE
      IMPORTING keys FOR ServiceRequest~validatePlant.

    METHODS validatepriority FOR VALIDATE ON SAVE
      IMPORTING keys FOR ServiceRequest~validatePriority.

    "! Sets the status of the given instances (shared by the three actions)
    METHODS set_status
      IMPORTING keys   TYPE TABLE FOR KEY OF zsb_i_servicerequest
                status TYPE zsb_srvreq-status.

    "! Highest number already consumed; the caller adds 1..n.
    "! Uses number range object ZSB_SRVREQ (interval 01) and falls back to
    "! MAX(request_id) when the object is not maintained (demo systems).
    METHODS get_last_request_id
      IMPORTING quantity      TYPE i
      RETURNING VALUE(result) TYPE zsb_srvreq-request_id.

ENDCLASS.


CLASS lhc_servicerequest IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Demo: no restriction. In a productive BO check a custom authorization
    " object here, e.g.
    "   AUTHORITY-CHECK OBJECT 'ZSB_SRVREQ' ID 'ACTVT' FIELD '01'.
    " and return if_abap_behv=>auth-unauthorized where it fails.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-approve = if_abap_behv=>mk-on.
      result-%action-approve = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-reject = if_abap_behv=>mk-on.
      result-%action-reject = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-complete = if_abap_behv=>mk-on.
      result-%action-complete = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.


  METHOD get_instance_features.
    READ ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY ServiceRequest
        FIELDS ( Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requests)
      FAILED failed.

    result = VALUE #(
      FOR request IN requests
      LET is_new   = xsdbool( request-Status = c_status-new )
          is_final = xsdbool( request-Status = c_status-completed OR request-Status = c_status-rejected )
      IN
      ( %tky              = request-%tky
        %features-%update = COND #( WHEN is_final = abap_true
                                    THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
        %features-%delete = COND #( WHEN is_new = abap_true
                                    THEN if_abap_behv=>fc-o-enabled  ELSE if_abap_behv=>fc-o-disabled )
        %assoc-_Item      = COND #( WHEN is_final = abap_true
                                    THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
        %action-approve   = COND #( WHEN is_new = abap_true
                                    THEN if_abap_behv=>fc-o-enabled  ELSE if_abap_behv=>fc-o-disabled )
        %action-reject    = COND #( WHEN is_new = abap_true
                                    THEN if_abap_behv=>fc-o-enabled  ELSE if_abap_behv=>fc-o-disabled )
        %action-complete  = COND #( WHEN request-Status = c_status-approved
                                    THEN if_abap_behv=>fc-o-enabled  ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.


  METHOD earlynumbering_create.
    " UUID keys are assigned here so that the key is known to the consumer
    " right after CREATE (early numbering), no DB round trip required.
    LOOP AT entities INTO DATA(entity).
      DATA(uuid) = entity-RequestUuid.
      IF uuid IS INITIAL.
        TRY.
            uuid = cl_system_uuid=>create_uuid_x16_static( ).
          CATCH cx_uuid_error.
            APPEND VALUE #( %cid = entity-%cid %is_draft = entity-%is_draft ) TO failed-servicerequest.
            APPEND VALUE #( %cid = entity-%cid %is_draft = entity-%is_draft
                            %msg = new_message( id = c_msgid number = '009'
                                                severity = if_abap_behv_message=>severity-error ) )
              TO reported-servicerequest.
            CONTINUE.
        ENDTRY.
      ENDIF.
      APPEND VALUE #( %cid             = entity-%cid
                      %is_draft        = entity-%is_draft
                      %key-RequestUuid = uuid ) TO mapped-servicerequest.
    ENDLOOP.
  ENDMETHOD.


  METHOD earlynumbering_cba_item.
    " Item numbers are assigned per request in steps of 10, continuing after
    " the highest number that already exists in the buffer or on the database.
    READ ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY ServiceRequest BY \_Item
        FROM CORRESPONDING #( entities )
      LINK DATA(item_links).

    LOOP AT entities INTO DATA(entity).
      DATA(max_item_no) = REDUCE zsb_srvreqitm-item_no(
        INIT max = CONV zsb_srvreqitm-item_no( '0000' )
        FOR link IN item_links
          WHERE ( source-RequestUuid = entity-RequestUuid )
        NEXT max = COND #( WHEN link-target-ItemNo > max THEN link-target-ItemNo ELSE max ) ).

      LOOP AT entity-%target INTO DATA(item).
        DATA(item_no) = item-ItemNo.
        IF item_no IS INITIAL.
          max_item_no += 10.
          item_no = max_item_no.
        ENDIF.
        APPEND VALUE #( %cid             = item-%cid
                        %is_draft        = item-%is_draft
                        %key-RequestUuid = entity-RequestUuid
                        %key-ItemNo      = item_no ) TO mapped-item.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD approve.
    set_status( keys = CORRESPONDING #( keys ) status = c_status-approved ).

    READ ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY ServiceRequest ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    result = VALUE #( FOR request IN requests ( %tky = request-%tky %param = request ) ).
    reported-servicerequest = VALUE #(
      FOR request IN requests
      ( %tky = request-%tky
        %msg = new_message( id = c_msgid number = '005' severity = if_abap_behv_message=>severity-success
                            v1 = request-RequestId ) ) ).
  ENDMETHOD.


  METHOD reject.
    set_status( keys = CORRESPONDING #( keys ) status = c_status-rejected ).

    READ ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY ServiceRequest ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    result = VALUE #( FOR request IN requests ( %tky = request-%tky %param = request ) ).
    reported-servicerequest = VALUE #(
      FOR request IN requests
      ( %tky = request-%tky
        %msg = new_message( id = c_msgid number = '006' severity = if_abap_behv_message=>severity-success
                            v1 = request-RequestId ) ) ).
  ENDMETHOD.


  METHOD complete.
    set_status( keys = CORRESPONDING #( keys ) status = c_status-completed ).

    READ ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY ServiceRequest ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    result = VALUE #( FOR request IN requests ( %tky = request-%tky %param = request ) ).
    reported-servicerequest = VALUE #(
      FOR request IN requests
      ( %tky = request-%tky
        %msg = new_message( id = c_msgid number = '007' severity = if_abap_behv_message=>severity-success
                            v1 = request-RequestId ) ) ).
  ENDMETHOD.


  METHOD set_status.
    MODIFY ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY ServiceRequest
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = status ) )
      FAILED DATA(update_failed)
      REPORTED DATA(update_reported).
  ENDMETHOD.


  METHOD setinitialvalues.
    READ ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY ServiceRequest
        FIELDS ( Status CurrencyCode RequestedBy )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    DELETE requests WHERE Status IS NOT INITIAL
                      AND CurrencyCode IS NOT INITIAL
                      AND RequestedBy IS NOT INITIAL.
    CHECK requests IS NOT INITIAL.

    MODIFY ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY ServiceRequest
        UPDATE FIELDS ( Status CurrencyCode RequestedBy )
        WITH VALUE #(
          FOR request IN requests
          ( %tky         = request-%tky
            Status       = COND #( WHEN request-Status IS INITIAL
                                   THEN c_status-new ELSE request-Status )
            CurrencyCode = COND #( WHEN request-CurrencyCode IS INITIAL
                                   THEN c_default_currency ELSE request-CurrencyCode )
            RequestedBy  = COND #( WHEN request-RequestedBy IS INITIAL
                                   THEN cl_abap_context_info=>get_user_technical_name( )
                                   ELSE request-RequestedBy ) ) )
      REPORTED DATA(update_reported).

    reported = CORRESPONDING #( DEEP update_reported ).
  ENDMETHOD.


  METHOD setrequestid.
    " Runs once per instance when the active instance is created
    " (for draft-enabled BOs that is at activation, like SAP's own apps).
    READ ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY ServiceRequest
        FIELDS ( RequestId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    DELETE requests WHERE RequestId IS NOT INITIAL.
    CHECK requests IS NOT INITIAL.

    DATA(request_id) = get_last_request_id( lines( requests ) ).

    LOOP AT requests ASSIGNING FIELD-SYMBOL(<request>).
      request_id += 1.
      <request>-RequestId = request_id.
    ENDLOOP.

    MODIFY ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY ServiceRequest
        UPDATE FIELDS ( RequestId )
        WITH VALUE #( FOR request IN requests ( %tky = request-%tky RequestId = request-RequestId ) )
      REPORTED DATA(update_reported).

    reported = CORRESPONDING #( DEEP update_reported ).
  ENDMETHOD.


  METHOD get_last_request_id.
    TRY.
        cl_numberrange_runtime=>number_get(
          EXPORTING
            nr_range_nr       = '01'
            object            = c_number_range
            quantity          = CONV #( quantity )
          IMPORTING
            number            = DATA(last_number)
            returned_quantity = DATA(returned_quantity) ).
        result = last_number - returned_quantity.
      CATCH cx_number_ranges.
        " Number range object not maintained (typical for a demo system):
        " fall back to the highest number used so far.
        SELECT MAX( request_id ) FROM zsb_srvreq INTO @result.
    ENDTRY.
  ENDMETHOD.


  METHOD validaterequireddate.
    READ ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY ServiceRequest
        FIELDS ( RequiredDate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    DATA(today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT requests INTO DATA(request).
      " clear the state area first so that a corrected value removes the old message
      APPEND VALUE #( %tky = request-%tky %state_area = 'VALIDATE_REQUIRED_DATE' ) TO reported-servicerequest.

      IF request-RequiredDate IS INITIAL OR request-RequiredDate < today.
        APPEND VALUE #( %tky = request-%tky ) TO failed-servicerequest.
        APPEND VALUE #( %tky                  = request-%tky
                        %state_area           = 'VALIDATE_REQUIRED_DATE'
                        %msg                  = new_message( id       = c_msgid
                                                             number   = '001'
                                                             severity = if_abap_behv_message=>severity-error
                                                             v1       = request-RequiredDate )
                        %element-RequiredDate = if_abap_behv=>mk-on ) TO reported-servicerequest.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD validateplant.
    READ ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY ServiceRequest
        FIELDS ( Plant )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    " one round trip for all plants: released CDS view, no direct table access
    DATA plants TYPE SORTED TABLE OF i_plant WITH UNIQUE KEY Plant.
    plants = CORRESPONDING #( requests DISCARDING DUPLICATES MAPPING Plant = Plant EXCEPT * ).
    DELETE plants WHERE Plant IS INITIAL.

    IF plants IS NOT INITIAL.
      SELECT FROM i_plant FIELDS plant
        FOR ALL ENTRIES IN @plants
        WHERE plant = @plants-plant
        INTO TABLE @DATA(valid_plants).
    ENDIF.

    LOOP AT requests INTO DATA(request).
      APPEND VALUE #( %tky = request-%tky %state_area = 'VALIDATE_PLANT' ) TO reported-servicerequest.

      IF request-Plant IS INITIAL OR NOT line_exists( valid_plants[ plant = request-Plant ] ).
        APPEND VALUE #( %tky = request-%tky ) TO failed-servicerequest.
        APPEND VALUE #( %tky           = request-%tky
                        %state_area    = 'VALIDATE_PLANT'
                        %msg           = new_message( id       = c_msgid
                                                      number   = '002'
                                                      severity = if_abap_behv_message=>severity-error
                                                      v1       = request-Plant )
                        %element-Plant = if_abap_behv=>mk-on ) TO reported-servicerequest.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD validatepriority.
    READ ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY ServiceRequest
        FIELDS ( Priority )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    LOOP AT requests INTO DATA(request).
      APPEND VALUE #( %tky = request-%tky %state_area = 'VALIDATE_PRIORITY' ) TO reported-servicerequest.

      IF request-Priority < c_priority-highest OR request-Priority > c_priority-lowest.
        APPEND VALUE #( %tky = request-%tky ) TO failed-servicerequest.
        APPEND VALUE #( %tky              = request-%tky
                        %state_area       = 'VALIDATE_PRIORITY'
                        %msg              = new_message( id       = c_msgid
                                                         number   = '003'
                                                         severity = if_abap_behv_message=>severity-error
                                                         v1       = request-Priority )
                        %element-Priority = if_abap_behv=>mk-on ) TO reported-servicerequest.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


"----------------------------------------------------------------------
" Handler: Item (child)
"----------------------------------------------------------------------
CLASS lhc_item DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZSB_RAP_SRVREQ'.

    METHODS setitemdefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~setItemDefaults.

    METHODS calculatetotalamount FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~calculateTotalAmount.

    METHODS recalctotalondelete FOR DETERMINE ON SAVE
      IMPORTING keys FOR Item~recalcTotalOnDelete.

    METHODS validatequantity FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateQuantity.

    "! Distinct parent keys for a set of item keys (the parent key is part of the item key)
    METHODS request_keys_of
      IMPORTING item_keys     TYPE TABLE FOR KEY OF zsb_i_servicerequest\\Item
      RETURNING VALUE(result) TYPE TABLE FOR KEY OF zsb_i_servicerequest.

    "! Sums the net amounts of all (remaining) items and writes the header total
    METHODS recalculate_total
      IMPORTING request_keys TYPE TABLE FOR KEY OF zsb_i_servicerequest.

ENDCLASS.


CLASS lhc_item IMPLEMENTATION.

  METHOD setitemdefaults.
    " new items inherit the currency of their request
    READ ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY Item
        FIELDS ( CurrencyCode )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    DELETE items WHERE CurrencyCode IS NOT INITIAL.
    CHECK items IS NOT INITIAL.

    READ ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY ServiceRequest
        FIELDS ( CurrencyCode )
        WITH CORRESPONDING #( request_keys_of( CORRESPONDING #( items ) ) )
      RESULT DATA(requests).

    MODIFY ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( CurrencyCode )
        WITH VALUE #(
          FOR item IN items
          ( %tky         = item-%tky
            CurrencyCode = VALUE #( requests[ %is_draft   = item-%is_draft
                                              RequestUuid = item-RequestUuid ]-CurrencyCode OPTIONAL ) ) )
      REPORTED DATA(update_reported).

    reported = CORRESPONDING #( DEEP update_reported ).
  ENDMETHOD.


  METHOD calculatetotalamount.
    recalculate_total( request_keys_of( CORRESPONDING #( keys ) ) ).
  ENDMETHOD.


  METHOD recalctotalondelete.
    " Deleted instances cannot be read any more, but the parent key is part of
    " the item key, and that is all we need to recalculate the header total.
    recalculate_total( request_keys_of( CORRESPONDING #( keys ) ) ).
  ENDMETHOD.


  METHOD validatequantity.
    READ ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY Item
        FIELDS ( Quantity )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    LOOP AT items INTO DATA(item).
      APPEND VALUE #( %tky = item-%tky %state_area = 'VALIDATE_QUANTITY' ) TO reported-item.

      IF item-Quantity <= 0.
        APPEND VALUE #( %tky = item-%tky ) TO failed-item.
        APPEND VALUE #( %tky              = item-%tky
                        %state_area       = 'VALIDATE_QUANTITY'
                        %msg              = new_message( id       = c_msgid
                                                         number   = '004'
                                                         severity = if_abap_behv_message=>severity-error
                                                         v1       = item-ItemNo )
                        %element-Quantity = if_abap_behv=>mk-on ) TO reported-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD request_keys_of.
    LOOP AT item_keys INTO DATA(item_key)
         GROUP BY ( uuid = item_key-%key-RequestUuid is_draft = item_key-%is_draft )
         INTO DATA(group).
      APPEND VALUE #( %is_draft        = group-is_draft
                      %key-RequestUuid = group-uuid ) TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD recalculate_total.
    CHECK request_keys IS NOT INITIAL.

    READ ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY ServiceRequest
        FIELDS ( TotalAmount )
        WITH CORRESPONDING #( request_keys )
      RESULT DATA(requests).

    READ ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY ServiceRequest BY \_Item
        FIELDS ( NetAmount )
        WITH CORRESPONDING #( request_keys )
      RESULT DATA(items).

    LOOP AT requests ASSIGNING FIELD-SYMBOL(<request>).
      <request>-TotalAmount = REDUCE #( INIT sum TYPE zsb_srvreq-total_amount
                                        FOR item IN items
                                          WHERE ( %is_draft   = <request>-%is_draft
                                              AND RequestUuid = <request>-RequestUuid )
                                        NEXT sum = sum + item-NetAmount ).
    ENDLOOP.

    MODIFY ENTITIES OF zsb_i_servicerequest IN LOCAL MODE
      ENTITY ServiceRequest
        UPDATE FIELDS ( TotalAmount )
        WITH VALUE #( FOR request IN requests ( %tky = request-%tky TotalAmount = request-TotalAmount ) )
      FAILED DATA(update_failed)
      REPORTED DATA(update_reported).
  ENDMETHOD.

ENDCLASS.
