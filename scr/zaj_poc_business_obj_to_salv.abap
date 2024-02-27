REPORT zaj_poc_business_obj_to_salv.

DATA container      TYPE REF TO cl_gui_custom_container.
DATA salv_table     TYPE REF TO cl_salv_table.
DATA ok_code        TYPE syucomm.
DATA io_sap_bus_obj TYPE swo_objtyp.
DATA io_obj_key_1   TYPE /pino/ddgold_object_id.
DATA io_obj_key_2   TYPE /pino/ddgold_object_id.
DATA io_obj_key_3   TYPE /pino/ddgold_object_id.


CLASS business_obj_to_alv DEFINITION.

  PUBLIC SECTION.
    DATA dyn_salv_table TYPE REF TO data.

    METHODS main.

    METHODS event_bus_obj_changed IMPORTING bus_obj   TYPE swo_objtyp
                                            obj_key_1 TYPE /pino/ddgold_object_id OPTIONAL
                                            obj_key_2 TYPE /pino/ddgold_object_id OPTIONAL
                                            obj_key_3 TYPE /pino/ddgold_object_id OPTIONAL.

    METHODS fill_data IMPORTING struct    TYPE REF TO  cl_abap_structdescr
                                obj_key_1 TYPE /pino/ddgold_object_id OPTIONAL
                                obj_key_2 TYPE /pino/ddgold_object_id OPTIONAL
                                obj_key_3 TYPE /pino/ddgold_object_id OPTIONAL.

    METHODS display_dynpro.
    METHODS fill_salv_container RETURNING VALUE(salv_table) TYPE REF TO cl_salv_table.
    METHODS create_container.

    METHODS create_sow_key_struct IMPORTING bus_obj       TYPE swo_objtyp
                                  RETURNING VALUE(struct) TYPE cl_abap_structdescr=>component_table.

    METHODS set_swotrk_from_sap_object
      IMPORTING business_obj    TYPE swo_objtyp
      RETURNING VALUE(key_info) TYPE /pino/ddgold_swotrk_tt.

  PRIVATE SECTION.
    DATA key_fields TYPE /pino/ddgold_swotrk_tt.

ENDCLASS.


CLASS business_obj_to_alv IMPLEMENTATION.
  METHOD main.
    display_dynpro( ).
  ENDMETHOD.

  METHOD display_dynpro.
    CALL SCREEN '0100'.
  ENDMETHOD.

  METHOD set_swotrk_from_sap_object.
    CALL FUNCTION 'SWO_QUERY_KEYFIELDS'
      EXPORTING objtype = business_obj
      TABLES    info    = key_info[].
  ENDMETHOD.

  METHOD fill_salv_container.
  ENDMETHOD.

  METHOD create_container.
    IF cl_salv_table=>is_offline( ) = abap_false.
      container = NEW cl_gui_custom_container( 'CC_DISPLAY_SALV' ).
    ENDIF.
  ENDMETHOD.

  METHOD create_sow_key_struct.
    DATA abap_component TYPE abap_componentdescr.

    key_fields = set_swotrk_from_sap_object( bus_obj ).

    LOOP AT key_fields INTO DATA(key_field).
      DATA(field) = cl_abap_typedescr=>describe_by_name( |{ key_field-refstruct }| & |-| & |{ key_field-reffield }| ).
      abap_component-name  = key_field-editelem.
      abap_component-type ?= field.
      APPEND abap_component TO struct.
    ENDLOOP.
  ENDMETHOD.

  METHOD event_bus_obj_changed.
    DATA(struct) = cl_abap_structdescr=>create( p_components = create_sow_key_struct( bus_obj )
                                                p_strict     = space ).
    DATA(table) = cl_abap_tabledescr=>create( struct ).

    CREATE DATA dyn_salv_table TYPE HANDLE table.

    fill_data( struct    = struct
               obj_key_1 = obj_key_1
               obj_key_2 = obj_key_2
               obj_key_3 = obj_key_3 ).
  ENDMETHOD.

  METHOD fill_data.
    DATA obj_key_table TYPE TABLE OF string.
    FIELD-SYMBOLS <table> TYPE STANDARD TABLE.

    ASSIGN dyn_salv_table->* TO <table>.

    obj_key_table = VALUE #( ( CONV string( obj_key_1 ) ) ( CONV string( obj_key_2 ) ) ( CONV string( obj_key_3 )  ) ).
    LOOP AT obj_key_table INTO DATA(obj_key).
      IF obj_key IS INITIAL.
        CONTINUE.
      ENDIF.
      APPEND INITIAL LINE TO <table> ASSIGNING FIELD-SYMBOL(<line>).
      LOOP AT key_fields INTO DATA(key_field).

        ASSIGN COMPONENT key_field-keyfield OF STRUCTURE <line> TO FIELD-SYMBOL(<field>).
        <field> = obj_key+key_field-offset(key_field-outlength).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

INITIALIZATION.
  DATA(cls_main) = NEW business_obj_to_alv( ).

START-OF-SELECTION.
  cls_main->main( ).

  MODULE status_0100 OUTPUT.

    IF container IS NOT BOUND.
      cls_main->create_container( ).
    ENDIF.

    FIELD-SYMBOLS <fs_tab> TYPE ANY TABLE.
    ASSIGN cls_main->dyn_salv_table->* TO <fs_tab>.

    IF <fs_tab> IS NOT ASSIGNED.
      RETURN.
    ENDIF.

    IF salv_table IS BOUND.
      salv_table->set_data( CHANGING t_table = <fs_tab> ).
    ELSE.
      TRY.
          cl_salv_table=>factory( EXPORTING r_container    = container
                                            container_name = 'CC_DISPLAY_SALV'
                                  IMPORTING r_salv_table   = salv_table
                                  CHANGING  t_table        = <fs_tab> ).

        CATCH cx_salv_msg ##NO_HANDLER.
      ENDTRY.
    ENDIF.
    salv_table->refresh( ).
    salv_table->display( ).

  ENDMODULE.

  MODULE user_command_0100 INPUT.

    IF ok_code <> 'BTN_CREATE'.
      RETURN.
    ENDIF.

    IF io_sap_bus_obj IS INITIAL.
      RETURN.
    ENDIF.

    cls_main->event_bus_obj_changed( bus_obj   = io_sap_bus_obj
                                     obj_key_1 = io_obj_key_1
                                     obj_key_2 = io_obj_key_2
                                     obj_key_3 = io_obj_key_3 ).

  ENDMODULE.