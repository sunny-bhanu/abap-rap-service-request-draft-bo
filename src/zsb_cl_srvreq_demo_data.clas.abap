"! <p class="shorttext synchronized">Demo data for the Service Request BO</p>
"! Run as console application in ADT (F9). Inserts the status / priority
"! code texts and creates two sample requests through EML, so numbering,
"! determinations and validations are exercised exactly as in the app.
CLASS zsb_cl_srvreq_demo_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    METHODS insert_code_texts
      IMPORTING out TYPE REF TO if_oo_adt_classrun_out.

    METHODS create_sample_requests
      IMPORTING out TYPE REF TO if_oo_adt_classrun_out.
ENDCLASS.



CLASS zsb_cl_srvreq_demo_data IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    insert_code_texts( out ).
    create_sample_requests( out ).
  ENDMETHOD.


  METHOD insert_code_texts.
    DATA(codes) = VALUE zsb_srvcodetxt_tab(
      ( code_type = 'STATUS'   code = 'N' code_text = 'New'       criticality = 2 )
      ( code_type = 'STATUS'   code = 'A' code_text = 'Approved'  criticality = 3 )
      ( code_type = 'STATUS'   code = 'R' code_text = 'Rejected'  criticality = 1 )
      ( code_type = 'STATUS'   code = 'C' code_text = 'Completed' criticality = 3 )
      ( code_type = 'PRIORITY' code = '1' code_text = 'Very high' )
      ( code_type = 'PRIORITY' code = '2' code_text = 'High' )
      ( code_type = 'PRIORITY' code = '3' code_text = 'Medium' )
      ( code_type = 'PRIORITY' code = '4' code_text = 'Low' ) ).

    MODIFY zsb_srvcodetxt FROM TABLE @codes.
    COMMIT WORK.

    out->write( |{ lines( codes ) } code texts written to ZSB_SRVCODETXT| ).
  ENDMETHOD.


  METHOD create_sample_requests.
    DATA(today) = cl_abap_context_info=>get_system_date( ).

    " pick a plant that exists in this system
    SELECT SINGLE plant FROM i_plant INTO @DATA(plant).
    IF sy-subrc <> 0.
      out->write( 'No plant found in I_Plant - sample requests not created' ).
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zsb_i_servicerequest
      ENTITY ServiceRequest
        CREATE FIELDS ( Equipment Plant Description Priority RequiredDate CurrencyCode )
        WITH VALUE #(
          ( %cid = 'R1' Equipment = 'PUMP-0001'  Plant = plant Priority = '1'
            Description = 'Bearing noise on feed pump - replace bearing set' RequiredDate = today + 3  CurrencyCode = 'INR' )
          ( %cid = 'R2' Equipment = 'CONV-0012'  Plant = plant Priority = '3'
            Description = 'Conveyor belt alignment and roller change'       RequiredDate = today + 14 CurrencyCode = 'INR' ) )
        CREATE BY \_Item FIELDS ( Material ItemText Quantity Unit NetAmount )
        WITH VALUE #(
          ( %cid_ref = 'R1'
            %target  = VALUE #( ( %cid = 'R1I1' Material = 'BEARING-6204' ItemText = 'Deep groove ball bearing' Quantity = 2 Unit = 'EA' NetAmount = '350.00' )
                                ( %cid = 'R1I2' Material = 'GREASE-EP2'   ItemText = 'Lithium grease 1 kg'      Quantity = 1 Unit = 'EA' NetAmount = '150.00' ) ) )
          ( %cid_ref = 'R2'
            %target  = VALUE #( ( %cid = 'R2I1' Material = 'ROLLER-89'    ItemText = 'Carrying roller 89 mm'    Quantity = 6 Unit = 'EA' NetAmount = '2400.00' ) ) ) )
      MAPPED DATA(mapped)
      FAILED DATA(failed)
      REPORTED DATA(reported).

    IF failed IS NOT INITIAL.
      out->write( 'Sample requests not created:' ).
      LOOP AT reported-servicerequest INTO DATA(message) WHERE %msg IS BOUND.
        out->write( message-%msg->if_message~get_text( ) ).
      ENDLOOP.
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF zsb_i_servicerequest
      FAILED DATA(commit_failed)
      REPORTED DATA(commit_reported).

    IF commit_failed IS INITIAL.
      out->write( |{ lines( mapped-servicerequest ) } sample requests with { lines( mapped-item ) } items created| ).
    ELSE.
      out->write( 'Commit failed:' ).
      LOOP AT commit_reported-servicerequest INTO message WHERE %msg IS BOUND.
        out->write( message-%msg->if_message~get_text( ) ).
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
