"! ABAP Unit tests for the Service Request business object.
"! The CDS and Open SQL test doubles keep the tests away from real data;
"! the behavior itself (numbering, determinations, validations, actions)
"! runs unchanged through EML.
CLASS ltc_service_request DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CLASS-DATA cds_test_environment TYPE REF TO if_cds_test_environment.
    CLASS-DATA sql_test_environment TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.

    METHODS create_sets_defaults           FOR TESTING RAISING cx_static_check.
    METHODS past_required_date_is_rejected FOR TESTING RAISING cx_static_check.
    METHODS unknown_plant_is_rejected      FOR TESTING RAISING cx_static_check.
    METHODS approve_changes_status         FOR TESTING RAISING cx_static_check.
    METHODS items_update_header_total      FOR TESTING RAISING cx_static_check.

    METHODS create_request
      IMPORTING required_date TYPE d
                plant         TYPE zsb_srvreq-plant DEFAULT '1000'
      RETURNING VALUE(uuid)   TYPE sysuuid_x16.

ENDCLASS.


CLASS ltc_service_request IMPLEMENTATION.

  METHOD class_setup.
    cds_test_environment = cl_cds_test_environment=>create_for_multiple_cds(
      i_for_entities = VALUE #(
        ( i_for_entity = 'ZSB_I_SERVICEREQUEST'     i_select_base_dependencies = abap_true )
        ( i_for_entity = 'ZSB_I_SERVICEREQUESTITEM' i_select_base_dependencies = abap_true )
        ( i_for_entity = 'I_PLANT' ) ) ).

    sql_test_environment = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZSB_SRVREQ' ) ( 'ZSB_SRVREQITM' )
                                   ( 'ZSB_SRVREQ_D' ) ( 'ZSB_SRVREQITM_D' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    cds_test_environment->destroy( ).
    sql_test_environment->destroy( ).
  ENDMETHOD.


  METHOD setup.
    cds_test_environment->clear_doubles( ).
    sql_test_environment->clear_doubles( ).

    DATA plants TYPE STANDARD TABLE OF i_plant WITH EMPTY KEY.
    plants = VALUE #( ( Plant = '1000' PlantName = 'Test plant' ) ).
    cds_test_environment->insert_test_data( plants ).
  ENDMETHOD.


  METHOD teardown.
    ROLLBACK ENTITIES.
  ENDMETHOD.


  METHOD create_request.
    MODIFY ENTITIES OF zsb_i_servicerequest
      ENTITY ServiceRequest
        CREATE FIELDS ( Equipment Plant Description Priority RequiredDate CurrencyCode )
        WITH VALUE #( ( %cid         = 'REQ1'
                        Equipment    = 'PUMP-0001'
                        Plant        = plant
                        Description  = 'Replace worn bearing'
                        Priority     = '2'
                        RequiredDate = required_date
                        CurrencyCode = 'INR' ) )
      MAPPED DATA(mapped)
      FAILED DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_initial( failed ).
    uuid = mapped-servicerequest[ 1 ]-RequestUuid.
  ENDMETHOD.


  METHOD create_sets_defaults.
    DATA(uuid) = create_request( cl_abap_context_info=>get_system_date( ) + 7 ).

    COMMIT ENTITIES RESPONSE OF zsb_i_servicerequest
      FAILED DATA(failed)
      REPORTED DATA(reported).
    cl_abap_unit_assert=>assert_initial( failed ).

    SELECT SINGLE status, currency_code, requested_by, request_id
      FROM zsb_srvreq
      WHERE request_uuid = @uuid
      INTO @DATA(row).

    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( exp = 'N'   act = row-status ).
    cl_abap_unit_assert=>assert_equals( exp = 'INR' act = row-currency_code ).
    cl_abap_unit_assert=>assert_not_initial( row-requested_by ).
    cl_abap_unit_assert=>assert_not_initial( row-request_id ).
  ENDMETHOD.


  METHOD past_required_date_is_rejected.
    create_request( cl_abap_context_info=>get_system_date( ) - 1 ).

    COMMIT ENTITIES RESPONSE OF zsb_i_servicerequest
      FAILED DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial( failed-servicerequest ).
    cl_abap_unit_assert=>assert_equals(
      exp = if_abap_behv=>mk-on
      act = VALUE #( reported-servicerequest[ %msg IS NOT INITIAL ]-%element-RequiredDate OPTIONAL ) ).
  ENDMETHOD.


  METHOD unknown_plant_is_rejected.
    create_request( required_date = cl_abap_context_info=>get_system_date( ) + 7
                    plant         = '9999' ).

    COMMIT ENTITIES RESPONSE OF zsb_i_servicerequest
      FAILED DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial( failed-servicerequest ).
  ENDMETHOD.


  METHOD approve_changes_status.
    DATA(uuid) = create_request( cl_abap_context_info=>get_system_date( ) + 7 ).
    COMMIT ENTITIES RESPONSE OF zsb_i_servicerequest
      FAILED DATA(failed)
      REPORTED DATA(reported).
    cl_abap_unit_assert=>assert_initial( failed ).

    MODIFY ENTITIES OF zsb_i_servicerequest
      ENTITY ServiceRequest
        EXECUTE approve FROM VALUE #( ( RequestUuid = uuid ) )
      RESULT DATA(result)
      FAILED failed
      REPORTED reported.

    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_equals( exp = 'A' act = result[ 1 ]-%param-Status ).

    COMMIT ENTITIES RESPONSE OF zsb_i_servicerequest
      FAILED failed
      REPORTED reported.
    cl_abap_unit_assert=>assert_initial( failed ).
  ENDMETHOD.


  METHOD items_update_header_total.
    DATA(uuid) = create_request( cl_abap_context_info=>get_system_date( ) + 7 ).

    MODIFY ENTITIES OF zsb_i_servicerequest
      ENTITY ServiceRequest
        CREATE BY \_Item
        FIELDS ( Material ItemText Quantity Unit NetAmount )
        WITH VALUE #( ( RequestUuid = uuid
                        %target     = VALUE #(
                          ( %cid = 'ITM1' Material = 'BEARING-6204' ItemText = 'Deep groove ball bearing'
                            Quantity = 2 Unit = 'EA' NetAmount = '350.00' )
                          ( %cid = 'ITM2' Material = 'GREASE-EP2'   ItemText = 'Lithium grease'
                            Quantity = 1 Unit = 'EA' NetAmount = '150.00' ) ) ) )
      MAPPED DATA(mapped)
      FAILED DATA(failed)
      REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( mapped-item ) ).
    " early numbering: 10, 20
    cl_abap_unit_assert=>assert_equals( exp = '0010' act = mapped-item[ 1 ]-ItemNo ).
    cl_abap_unit_assert=>assert_equals( exp = '0020' act = mapped-item[ 2 ]-ItemNo ).

    READ ENTITIES OF zsb_i_servicerequest
      ENTITY ServiceRequest
        FIELDS ( TotalAmount CurrencyCode )
        WITH VALUE #( ( RequestUuid = uuid ) )
      RESULT DATA(requests).

    cl_abap_unit_assert=>assert_equals( exp = '500.00' act = requests[ 1 ]-TotalAmount ).

    READ ENTITIES OF zsb_i_servicerequest
      ENTITY Item
        FIELDS ( CurrencyCode )
        WITH VALUE #( ( RequestUuid = uuid ItemNo = '0010' ) )
      RESULT DATA(items).

    " item inherited the header currency
    cl_abap_unit_assert=>assert_equals( exp = 'INR' act = items[ 1 ]-CurrencyCode ).

    COMMIT ENTITIES RESPONSE OF zsb_i_servicerequest
      FAILED failed
      REPORTED reported.
    cl_abap_unit_assert=>assert_initial( failed ).
  ENDMETHOD.

ENDCLASS.
