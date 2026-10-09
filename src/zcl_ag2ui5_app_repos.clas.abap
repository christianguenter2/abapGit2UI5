"! Start app: every abapGit repository of the system. Start it with
"! ?app_start=zcl_ag2ui5_app_repos
CLASS zcl_ag2ui5_app_repos DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    "! Every response keeps a safe identity URL; no pushed history or draft ID
    CLASS-METHODS route_dispatch IMPORTING io_client TYPE REF TO z2ui5_if_client.
    CLASS-METHODS write_route
      IMPORTING io_client TYPE REF TO z2ui5_if_client iv_key TYPE string OPTIONAL
                iv_diff TYPE abap_bool DEFAULT abap_false.

    CLASS-METHODS labels_css RETURNING VALUE(rv_css) TYPE string.

    TYPES:
      BEGIN OF ty_row,
        key             TYPE string,
        name            TYPE string,
        package         TYPE string,
        url             TYPE string,
        branch_display  TYPE string,
        branch_link     TYPE string,
        deserialized_at TYPE string,
        offline         TYPE abap_bool,
        favorite        TYPE abap_bool,
        favorite_icon   TYPE string,
        favorite_text   TYPE string,
        labels          TYPE zif_ag2ui5_repo_service=>ty_labels,
        label_preview   TYPE zif_ag2ui5_repo_service=>ty_labels,
        label_more      TYPE string,
        "! Navigation for every repository
        nav_type        TYPE string,
      END OF ty_row,
      ty_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    DATA mt_repos  TYPE ty_rows.
    DATA mv_search TYPE string.
    DATA mv_favorites_only TYPE abap_bool.
    DATA mv_empty TYPE abap_bool.
    DATA mv_empty_text TYPE string.
    "! LIST or TILES; switched on the client, stored per user
    DATA mv_layout TYPE string VALUE `TILES`.
    DATA mt_labels TYPE zif_ag2ui5_repo_service=>ty_labels.
    DATA mv_labels_title TYPE string.

    DATA mv_delete_title TYPE string.
    DATA mv_delete_text TYPE string.
    DATA mv_delete_confirmation TYPE string.
    DATA mv_delete_transport TYPE string.
    DATA mv_delete_error TYPE string.
    DATA mt_delete_objects TYPE zif_ag2ui5_repo_service=>ty_delete_objects.
    DATA mt_delete_transports TYPE zif_ag2ui5_repo_service=>ty_transports.
    DATA mt_delete_messages TYPE zif_ag2ui5_repo_service=>ty_messages.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.
    "! The unfiltered list; mt_repos is what the search leaves of it
    DATA mt_all TYPE ty_rows.
    DATA mi_service TYPE REF TO zif_ag2ui5_repo_service.
    DATA ms_delete_preview TYPE zif_ag2ui5_repo_service=>ty_delete_preview.
    DATA mv_delete_failed TYPE abap_bool.
    DATA mv_delete_package TYPE string.
    DATA mv_label_filter TYPE string.

    METHODS route_app
      IMPORTING iv_key TYPE string iv_diff TYPE abap_bool
      EXPORTING ev_message TYPE string
      RETURNING VALUE(ro_app) TYPE REF TO z2ui5_if_app.
    METHODS resolve_route
      IMPORTING iv_hash TYPE string
      EXPORTING ev_key TYPE string ev_diff TYPE abap_bool ev_error TYPE string.
    "! Joint project logo, embedded so the app needs no external image host
    CLASS-METHODS project_logo RETURNING VALUE(rv_uri) TYPE string.
    METHODS view_display.
    METHODS tiles_display
      IMPORTING
        io_content TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS on_event.
    METHODS load_repos.
    METHODS apply_search.
    METHODS favorite_set.
    METHODS favorites_filter IMPORTING iv_value TYPE string.
    METHODS favorite_display IMPORTING io_parent TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS labels_display IMPORTING io_parent TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS label_items IMPORTING io_parent TYPE REF TO z2ui5_cl_ui5_view_builder iv_wrapping TYPE abap_bool DEFAULT abap_false.
    METHODS labels_open.
    METHODS label_filter IMPORTING iv_label TYPE string.
    CLASS-METHODS filtered_repos
      IMPORTING it_rows TYPE ty_rows iv_search TYPE string iv_favorites_only TYPE abap_bool
                iv_label TYPE string OPTIONAL
      RETURNING VALUE(rt_rows) TYPE ty_rows.
    METHODS open_repo.
    METHODS service RETURNING VALUE(ri_service) TYPE REF TO zif_ag2ui5_repo_service.
    METHODS actions_display IMPORTING io_parent TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS delete_open IMPORTING iv_action TYPE string.
    METHODS delete_display.
    METHODS delete_confirm.
    METHODS delete_clear.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ag2ui5_app_repos IMPLEMENTATION.

  METHOD route_dispatch.
    " A new root list runs exactly the cold-start resolver against fresh data.
    " No handover data: explicit Back to list uses bound data to bypass it.
    io_client->nav_app_leave( NEW zcl_ag2ui5_app_repos( ) ).
  ENDMETHOD.

  METHOD write_route.
    DATA(lv_route) = `/`.
    IF strlen( iv_key ) = 12 AND iv_key CO `0123456789`.
      lv_route = |/repo/{ iv_key }|.
      IF iv_diff = abap_true.
        lv_route = lv_route && `/diff`.
      ENDIF.
    ENDIF.
    io_client->follow_up_action( val = io_client->cs_event-hash_routing t_arg = VALUE #( ( `DEFAULT` ) ) ).
    io_client->follow_up_action( val = io_client->cs_event-app_state_set_active t_arg = VALUE #( ( ` ` ) ) ).
    io_client->follow_up_action( val = io_client->cs_event-hash_attach_changed t_arg = VALUE #( ( `ROUTE_CHANGED` ) ) ).
    io_client->follow_up_action( val = io_client->cs_event-hash_replace t_arg = VALUE #( ( lv_route ) ) ).
  ENDMETHOD.

  METHOD route_app.
    CLEAR ev_message.
    ro_app = zcl_ag2ui5_app_status=>create( iv_key ).
    IF iv_diff = abap_false.
      RETURN.
    ENDIF.
    TRY.
        " Resolve the aggregate against fresh Status, never an index or draft.
        DATA(ls_status) = service( )->get_status( iv_key = iv_key ).
        IF ls_status-offline = abap_false AND line_exists( ls_status-rows[ changed = abap_true ] ).
          DATA(lt_changed) = ls_status-rows.
          DELETE lt_changed WHERE changed = abap_false.
          ro_app = zcl_ag2ui5_app_repo_diff=>create( iv_key = iv_key iv_title = ls_status-name
            it_files = zcl_ag2ui5_repo_service=>sort_status_rows( it_rows = lt_changed iv_by = `FILE` iv_changes_first = abap_true ) ).
        ELSE.
          ev_message = `Repository diff unavailable; showing fresh Status`.
        ENDIF.
      CATCH zcx_abapgit_exception.
        " Status shows the load error or login; a failed read replays no action.
        ev_message = `Repository diff could not be loaded; showing fresh Status`.
    ENDTRY.
  ENDMETHOD.

  METHOD resolve_route.
    CLEAR: ev_key, ev_diff, ev_error.
    IF iv_hash IS INITIAL OR iv_hash = `#` OR iv_hash = `#/`.
      RETURN.
    ENDIF.
    IF strlen( iv_hash ) <> 19 AND strlen( iv_hash ) <> 24.
      ev_error = `Invalid repository route; returned to the list`.
      RETURN.
    ENDIF.
    IF iv_hash(7) <> `#/repo/` OR ( strlen( iv_hash ) = 24 AND substring( val = iv_hash off = 19 ) <> `/diff` ).
      ev_error = `Invalid repository route; returned to the list`.
      RETURN.
    ENDIF.
    DATA(lv_key) = substring( val = iv_hash off = 7 len = 12 ).
    IF lv_key CN `0123456789`.
      ev_error = `Invalid repository key; returned to the list`.
      RETURN.
    ENDIF.
    TRY.
        DATA(lt_repos) = service( )->list_repos( ).
        IF line_exists( lt_repos[ key = lv_key ] ).
          ev_key = lv_key.
          ev_diff = xsdbool( strlen( iv_hash ) = 24 ).
        ELSE.
          ev_error = `Unknown repository key; returned to the list`.
        ENDIF.
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        ev_error = lx_error->get_text( ).
    ENDTRY.
  ENDMETHOD.


  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->get_event( ) = `ROUTE_CHANGED`.
      zcl_ag2ui5_app_repos=>route_dispatch( client ).
      RETURN.
    ENDIF.
    write_route( client ).
    " Explicit list handovers must not dispatch the previous request's hash.
    DATA lv_route_error TYPE string.
    IF client->check_on_init( ) AND client->get( )-r_event_data IS NOT BOUND.
      resolve_route( EXPORTING iv_hash = client->get( )-s_config-hash
                     IMPORTING ev_key = DATA(lv_key) ev_diff = DATA(lv_diff) ev_error = lv_route_error ).
      IF lv_key IS NOT INITIAL.
        DATA lv_route_message TYPE string.
        DATA(lo_route_app) = route_app( EXPORTING iv_key = lv_key iv_diff = lv_diff IMPORTING ev_message = lv_route_message ).
        client->nav_app_leave( app = lo_route_app r_data = lv_route_message ).
        RETURN.
      ENDIF.
    ENDIF.
    IF client->check_on_navigated( ).
      " back on the list, a repository was left: the Git credentials of the
      " session login go, and the session needs no state any more. abap2UI5
      " switches back only when this app made the session stateful itself:
      " on now, off in the next round trip (SESSION_END)
      service( )->logoff( ).
      IF zcl_ag2ui5_app_login=>is_stateful( ) = abap_true.
        client->set_session_stateful( abap_true ).
        client->follow_up_action( val   = client->cs_event-start_timer
                                  t_arg = VALUE #( ( `SESSION_END` ) ( `10` ) ) ).
      ENDIF.
      mv_layout = zcl_ag2ui5_settings=>get_instance( )->get(
                    iv_key     = zif_ag2ui5_settings=>c_key-repos_layout
                    iv_default = `TILES` ).
      mv_favorites_only = xsdbool( zcl_ag2ui5_settings=>get_instance( )->get(
        iv_key = zif_ag2ui5_settings=>c_key-repos_favorites_only iv_default = `` ) = `X` ).
      " also on the way back from a pull, so "Last pull" is current
      load_repos( ).
      view_display( ).
      " a page that created a repository hands its message over when it leaves
      DATA(lr_message) = client->get( )-r_event_data.
      IF lr_message IS BOUND.
        ASSIGN lr_message->* TO FIELD-SYMBOL(<lv_message>).
        DATA(lv_message) = CONV string( <lv_message> ).
        IF lv_message CP `LABEL_FILTER:*`.
          label_filter( substring( val = lv_message off = 13 ) ).
        ELSE.
          client->message_toast_display( lv_message ).
        ENDIF.
      ENDIF.
      " start typing right away: the cursor behind what is in the field,
      " scheduled for after the response, when the view is rendered
      DATA(lv_end) = |{ strlen( mv_search ) }|.
      client->follow_up_action( val   = client->cs_event-set_focus
                                t_arg = VALUE #( ( `search` ) ( lv_end ) ( lv_end ) ) ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.
    IF lv_route_error IS NOT INITIAL.
      client->message_box_display( text = lv_route_error type = `information` ).
    ENDIF.

  ENDMETHOD.

  METHOD project_logo.
    rv_uri = `data:image/png;base64,`
      && `iVBORw0KGgoAAAANSUhEUgAAAeAAAACXCAYAAADNhIhYAACAAElEQVR42uy9d6BlV1n3/3nW3uec2+bO3Cl32p0+SYaEZNKAYEgi`
      && `XVQUxI6NIiCggIBie1HBBjZQ8X3tKDZEBER67xhIN30mM5neZ+7cds7Ze31/f6xdz71TEsCIv/MkM3PvKWuv8qynF+hDH/rQhz70`
      && `oQ996EMf+tCHPvShD33oQx/60Ic+9KEPfehDH/rQhz70oQ996EMf+tCHPvShD33oQx/60Ic+9KEPfehDH/rQhz70oQ996EMf+tCH`
      && `PvShD33oQx/60Ic+9KEPfehDH/rQhz70oQ996EMf+tCHPvShD33oQx/60Ic+9KEPfehDH/rQhz70oQ996EMf+tCHPvShD33oQx/6`
      && `0Ic+9KEPfehDH/rQhz70oQ996EMf+tCHPvShD33oQx/60Ic+9KEPfehDH/rQhz70oQ996EMf+tCHPvShD33oQx/60Ic+9KEPfehD`
      && `H/rQhz70oQ996EMf+tCHPvShD33oQx/60Ic+9KEPfehDH/rQhz70oQ996EMf+tCHPvShD3145MC+3gMuXbEWEBCDgQmMFOHxPkLm`
      && `wZVPNjPMDMwgMcyDEBYbjQi6El6iATiF78iEBN6M1BwRwuQR4NOU44cPArB63RY63QSLIDJQ6kkRDXOAD2OnDvMO4SEWzhxmAgyP`
      && `4fCYSxFAYghDqYEHRRFx7EGQpgZeIHAxuEjgPakEzpAc5sMiXGQgQ14kiZibnQFgbvr4I40PfehDH/rQh/8m+JoZ8Iqly2mMrSKd`
      && `PY2L4mzUjKkSWLEp/3RgbAKQKqMofytjxuXbVp2mZd/Nvy9hApExcAsfdeYYHF7E9OTJ4rNC2ZzyscIzjfozq+MbIDPwLszR5bNX`
      && `eB7VeWaD5ZOork/54qq7UO6GR8iHzyfdBIBjhx78bzj+PvShD33owyMFXxMDHl+7AYDIRZiL8GnaMLMRYJFgQMJl7MgLIeGC/lo+`
      && `N+NZgfsIWcaoBM5ZYJPKeV/28eLDgRMqG8epZ34mvLCMV6rk84ZZeNMjk2GGKYxrZkhGyYsNiMKXTRjehC+EAZPLfvCAKoq9k2SS`
      && `wvqyZZuFJULGl0UXp2lkk+1uMj3UanrvPcPDizl9+jiH9+9+pHGkD33oQx/68A2Ah8WAV6/bjJSCOWbbMwy1hlcCV4JdBVwETICN`
      && `YEQETpkZlonI2avmzUGBOxVvOavPrzbXTIsWZgoqMDnvrgyNLz+MUSrQLvuct9rHw+eUDxPecdmfbI54y8cNH3PZI2oMGHCSXDlk`
      && `+I5ZuY7swR3gGGi3YbcCN0r6ryiKZpJulyRNcc5x5ECfEfehD33ow/8meMgMeNXaTQC4qIHUXQTuScBzgWswxoFmbp8tmGGPuTm8`
      && `Fj5h5zMDy0aqWXVVvlU8h8L0XT4tV7AfhqyRfa1uMjaqJujeefV+vbrJQRu2isSRv5dr80wbthP4gKR3pElydxzHaafbJYoiDu/f`
      && `9dDX0Ic+9KEPffgfCQ+JK61cuyn4U9PUombjUWb2UxLPBlYDDgtm2NrAUuEdLVivCiZWZ5cFo628alWuW/1RPZPPfbLK3K0971bN`
      && `vuSW5jNwzp7HLbhJ58GAzwMKHpyZ1S0TSdqgWyX+3Hv/LufcyTRN+1pwH/rQhz78L4LofD+4at1mELS7XWs2m9dg9tvA92K2OARA`
      && `mSz3sFZColTjsflbMqsyXyttx1Z+k7PJB1a4hK2imeZD9TLfMvjKchaXR1T3PEWFvTqMU6jyPYFe1hNodT469gKfMdWGtVzhjsEm`
      && `gGvMLJJ0q3NubnTxUhS16MxNfV2RoA996EMf+vDfD+fNgEdGlxBFMXHsLsTsDcDTg4/XClaWq3JmZij3pSrnfi7wGpkV3NNKLhrs`
      && `0Vl+DvXXA/S+5vJxrByHjLGHsSpc2jJhwKTaOEYIDMvnW3w/PLL2fczMSn+zo5fv98yvd95Wfy+bbxb7nUWOV5R/mdmImXu0mU0i`
      && `3YZZMjgwyOlTxx5pvOlDH/rQhz58jXBeJugVKyeIGk2Axebs1xEvAmuF6F7IfaKVSOQuUpssMCkfR6XNt2BbPRMoTbJSxZOcfaeW`
      && `02SFul2EV1ltHCpWaiv8tsqM4j3PQ2EUw7L3Q0BYppkX2U7zzc1nMFSXTym+VWjeNdWfGBgwy5KTqXiEw3wdaAfwygN7drx/fE1w`
      && `Axw+sOsbgA596EMf+tCH/y6Iz/WB1mATydOdnbHm0PDTEd8PtMqI4goPk44ANwJfBfYD7ezdnBEX3l8KRtuTilT8lHOrghOZYaZc`
      && `rc6Tf1TTYosZBYWXvMSHM8wheQ/ey+f8MQxu5qx0xXphPmO4wdUs5bFXsiypqMKQe6SInPfnE1clzqpwROeigTMYBbsA9HjgYrBm`
      && `dfWEvdsMvGTVxJb/cpF7IOl0H2m86UMf+tCHPnyNcE4GvGrtNtpz0wArwL4XtJLcVWqiEqF8B/BHwIc9HBwZHunOzs4g78lDpgIv`
      && `I+NDHvMZh8wMst77MsqYvLBUsNimeMDnvBi8QiUsoCujKyPUs3JlnpCHtQ3x5AFYFUOaikOp+OiccajrSm06EchD5IgMmgaNYnmG`
      && `nCOSz0pmuFKtFph8mI+FQh8iwrK5CkMWEaEyaxkR2L1DiEN77mdi3ZZhiQsFLzL4QcwWC8myqOnMbnCdmZ7abbf/Iopj/0gjTh/6`
      && `0Ic+9OFrg3My4NOnDrNodBmdzuxVwOMolLMi+teA+4BflPQhcy51EnEUodQvMmMETCadbsTRdJoktKKEdjpA2hA+Ea6b4hoxPvFR`
      && `FEVLDGsBXROnXOw6UdplIDJIY5R6oiilFce0FLJvY0sDX/bC6NKV4RPj78dTFg/gYrml8lrivffe7OTuxUMnV89M+tecdOxXzEAr`
      && `Qi4iRcjnVa0CI2+nCe0kRS7GuRinJKvHISTDN2J8lg7sfULi58BFQExKAr4DMiKB4gbeRSRJF7kOUsy6tRcATGN2s8n/KlgKvACj`
      && `pax6SdhvFoE92UXRP5vZqUcacfrQhz70oQ9fG5yTATeaA8zOnG64OH6MwUqyas0ZGGgWeHvq/Ucj59JMO1x0evLUEzGeAWwCUuC+`
      && `bpJ+0MHn2mk8jaW4JBsnTk3ebYii6DsxniBsmcEUpv+UT99jPr57Fi9cwp69D5x1vjsuX8/htuea9bD3EKuirr4zini6ma1X5OS9`
      && `dm7uTn90Fj7wzgsGD913aIqRZoM1t+x5xA5hzcQmlKa4RvOQpD83eCziMZXaXdkn9WgzWwf0GXAf+tCHPnyTwzkZsHMOnBsB2yJo`
      && `ktVpzBRhA+6X8cFG7DreA94PYPaTwM8AE+SR1mapoe8Q9nsGfwPMAVg0gNL2o4BfMbNvB0bL4Xk62LVJ5F+/7/TSr64bPXv0780X`
      && `raLdTXnsCOw/Em1smf85J36AxC/NY5+d9Di8f9qQ4+qDx2Z+a+2A23s4Tdl3+RrW3rL/ETmE/XsfYPnyVbRCUNpdctHHZFxuEBUK`
      && `cNCFVwMXSrrjEZloH/rQhz704esG7lwfyHy3IwTib9V3MrgXsTf1WcchsyuFXgJsyNJlc5esgW0F+2nBlamLMHOQzg1j9hLMvgdj`
      && `ERQOVA82IHg68NMbFh0b87IzzvNLF63i9TumuGA44kjq1g6YfjGCH8drTN6nSr1X4j2pvMGy2Oz5A5F73Yzc2vWtAdrAgavWP2IH`
      && `cfToQaKRpag50EH6EmKytPCTJ20NAhOjY8sesXn2oQ996EMfvj5wTgYcUnPVEiyqxPECRUOiU6A2Eql8BDwRbL1CDFX4XJmt64Et`
      && `wA2x93E2/kaDJ5vRQOE7xfeCA9QJrhO2LTnDHO+7ZA3TqXjvY5ZytJ1ONOVf51L9sHkNWKj3bGXJDmFmHudaZvxEw/jlE2l3/ToX`
      && `3j18xcQjdhidow+ibhfn7JDBVC3lKey1A4bvvf1G4sHWIzbPPvShD33ow9cO52bA5T+ut25z9rsPDX4MPC2kjeSm7TxJN9dcQ1Bv`
      && `E2yzh0ZWwWoNsJwFCkVVqkcuASYSPz/4947tE/jIeMLSJgdm0rUN08/j+XGkoaJoVTZXcxb+BGFAwDDwozG8bpJozWKDtoODV617`
      && `RA7j4LGjecmOLOQ737V8Pwwzcww1zBrn9B70oQ996EMf/gfDORlwpvWesWdCWYZKAB6zTvGewLKee1ZRnzOtNM8G7mZvlo8o61qR`
      && `DS3D2r3Vn/ddspxLFg+yKTaOdrS6Cb/oxPMwjWRZT0UisNWGrxXiGDbpxxvSL8x5rVmeGh15Dl/+CGnCeWdEKyuO5K8XJUPw9RrZ`
      && `fehDH/rQh286ODsDdhEKxSPhTD0J8r/MwCVtg9uAWUIv3zqrC7xvxrDbm2adyAwHu53ZLqolnJWZt8PPZrDHGfc1Kkz04FVrOdme`
      && `4uRMh0lYOWB6jcGPAUN17lRp0lAt1KHiF+/FoJd+IoKfn3W2ZlnUQMCRK9Y+kmdjhXTTu/VpCmm/GEcf+tCHPnwzw9kZcKXew7ym`
      && `uRQJwZVykw1JfAzpRnlZ6Idb1oLOmOmNDj7W9UpjjKa5vQ7+2dAJFOo75xWsCJWipmLj34YdDwxmfGj/lasBMTG6Ai+/wnleYZ7n`
      && `GRoyMxVaL6Bg/w7KeF7zuXAyK++qJIxhxE9E6HUzabp6NI6YExx8BH3CVv2/FD5EG5jrM+A+9KEPffhmhrMz4ERFpFVZFjKDsk2C`
      && `clXXScT4nYbeaOiDBicQCZBgTJrx8cjsN4dI7m04GAI6adKNpb918r8L/l6kNiIFtR3aGRlvGTD+7EjK3AoHu69cyerWUgYtxptW`
      && `mPc/h/RTwJKK2bY6y9qvmaM5j8eqxFWbMBYJnt8wfmnOpxMrmhEdjP3//dHRgrN3S7R+Law+9KEPffimhrNH8uStASQ5c3V2oPLv`
      && `3Kc6TcwQiRpKPpm4xg7BDQbbsoLJOyLj0yOmnVM+8h1vRBEMuoiO6dgA/GEX+2wqvgXTMmHHI+zLA6Yb57ymljjHoPMcsYTlyRQp`
      && `Wmni1YgXAyNkxaIr0yvbGoVKkWWU10LGdAvFH4EhQz9hZnY61W+Nm997jIijV69n+Vce/IYfSLatPqtlnU+uqJktMGuANVsw3f6G`
      && `z6cPfehDH/rwjYHzCKUt+ybMe1l5597Agk/uvY+RiY1kpbJ27zf+dgs0cbDj2GBn/dJZJDFksHvvjmKoC9dvwmAmhc9e1uDzh+Ua`
      && `K+JG97Z2xxsw4IyPLJ0mdsYiP0iHdIVJPyvxk8AIhZuarFa0ysClfKpW0X9r4kMGRVlrSTCE9KMNs2TW3G8ugUNT8hy7aoJlX937`
      && `DT2QrG9iNQq6LHkSGja5wcEhoqhBu8+A+9CHPvThmxbOIw/4bCHQxRjFJ/bu3cWefXuIgQ2CRHQST2fL0hke3WyTmrhr987aMPc+`
      && `+AADZqwweDDFz0jtPUnix+OYlot439gM60fGGCWiY7ZCntfiebGJxbUYMStaAteinvOpBv9wxUxtvVKF8sa/MhhBekEEv9AxVo9G`
      && `TbpeHPuGm6Mtn+cCW51/wCHsIY7bhz70oQ99+J8E55VMuhADznXJLL12XpDW7j07531nB2eGW3fvXPD1vY9Zz71zCevmpmijlU56`
      && `NeJFgkWUNT6yiRZpv/M6BGYlHSvdECl6GVYb95arQ8CQl54fmVnHp28ea8Z7TyfiyOVrWXHLvm/kuURUhaM8oCwz+Jti7DwyyP63`
      && `QWPxGlIvli8aJIoNpSk4F+wCErMzUzRbg5w8uo9uN/naH9iH/zGwet0WUu+LKM3EJ1lhgkwCz7McBHiPa8QhQtSLw/t3fg3P3Yx5`
      && `R5ekbP5GuI9pmtKwJsSwf8+Oh/2MbzR8esUwczNdVqwZZWjAGHBiupNwcqpNHDket2v6kZ7i/2/hoVRzqLeRz1iCWZbT+w2AnVeO`
      && `IyVc3WgxjV8WST8D/CRoFCw0AM5aFobI6TxouMJVMRQFJV3ykKaWVcPKF5L1FVbJdnMLtSHDRiQ9H6NxOuGNg7B/0jmOXLmOFTd9`
      && `/Rs4ZF0eXZ6UVWRmVSSciAZO//9hwKsmtoTUK+eKYireOmY+agBjGCsQRyIXHXbOad1FV7Dzjhsf6Wn34WuEZas28Oxt23jvPfcg`
      && `Hzqs7dt9H2vXb42cuSYwaDAANDPfUxdjBudmJTrTp9vp4iUDrF6/Fe89h6anGR8e5vDe82PIK9duwnvhnMc8DYylwKiZdQ2OgaZo`
      && `oG6nw4pVExw5+I11Tz0UOHD5SjyiKUdsDjOj6RwxhkcohmRwmFRwfHSUyU6HDcvW8Om9d/Otu88vw2LXtuUARA1H5HJa7IjNkBOp`
      && `yxqnJ2J6ukscO7bec/ysY+64OBszgtiBixyYIzILXdoT4eXpeLHj4DGWjw5jQx0uGXk0D84+QMs1cC7rcSuH0hR5H+ZhHiEO7ws9`
      && `Ba6oTOXui8JzFzUdLiZYRwuekPlazQVzr1fGcwKR9l4Z/zAS86Qe5EKxC5nhcCiFRath+UcO1dZ7fgx4XtN5q/6bMl8B/pph7/Zx`
      && `1g6sZrp9kjnnl8WpXiPpxYglFEzfqm7eQgqWT7BmC9uwkeji7bhNF8DIIpSm+COH8Pfdjb/3TnToYNCisrJYudnXrCzVkbVBGEb8`
      && `eCw6bfQ7o+jAJHDsirUsu/nrqwlnOVI+67hcTKL8wSoB6P+7YXztpsJZb80GvtONZW6xpVpr1ni0Oa4SXAasM7MvNAcGXx/HjT3H`
      && `Dux6pKfeh68RVqzdCMD777+PsSWLODU5PeK9X7Nm/dZHAZc4c5sFqyxYwgYslInrgE6B7RfsGhlt3Zumugt4cMOS1qSzIISvmtjE`
      && `wXN0VVu5dhMA3ntnFm1z5r4P41pg3KBjZvc1Gq3/8Gn6waGhRSfWbboQpXD0yCPLhHddsgwhms7RkGNnd8rWN4YHQcNz3g8ZNFzg`
      && `FgkwZzAzm6bTawZH/OmpY1yyeBlHLoMVtx0863NOXr6WVGKkGdOMmoELFIqPg9QgicFEGk8zO9Ll/bfu58TFKxm789CCYx599GpS`
      && `idEoZoAWJANhzGYaImLiFKIuIJLUs3Rdk+GNlzK3+06mO4dY21hCFA3DjIe0DXEXBheFZNbBBqgFs6cY2zrMYDzC0fYxln/1EMcu`
      && `n2Au9Yw1YwajJnSbkBg0UlCUNawHum1woemBigJTQMtBnCl03kEk6DpII4gcuC6kc0we6TJ3zWb27j/O1gdPAufDgMODeqtAU2GA`
      && `cqEt/dcNDly5mn3TJxhtDpGQjkeeVyJ+CjFq4LOIqtIcFPy6IVQ4TXHLx4me/l3ET3smbss23NBQuYne40+dJL3jZrrvfSfJ5z6B`
      && `n5nCoijIGXnmMmXkdBCENGjiec7wHXNvHsEOtJVyaPtaVt769WPCmRWtkls9T7pRYgnO/ndrwCvWbMhWq0hmE5b6i10cXQZcgdkl`
      && `SOskG8FwWdDdIPA3Zran2Rx8pKffh4cJ4ys3MbqiwekTXTo+dVHk1kyenn6sGTeY2eOALcH9pIZRTY6vOZ+8QYrZNLAH+NKeU51P`
      && `Al+Q/D6zKI0YYtmacQ7v3zV/Dhnz9967KIq+Bfg/ZnY90MhVEYmrgaeZiy7vdOb+4IH77zgwdWyKlWvWc2j/Nz5bohfuuXIFF9oI`
      && `BzXHqtGlHJ88vjhF2zY0hi9DPMqwTc5sOdAymQRdYBK0eyRu3DmbJrdh3DWXdI+MtAZ1+NK1DI2OcvS+u9h4uP6s3VetQik4s3iu`
      && `m148m8xcIIhMCMyHLjsyouxIvE7I66vPuH7zMR1Z2Ny9N9emsXhG6SUzTF9k0UxkzmEyOTNPKki9hITsBPI3tffvONFRguGjKa9H`
      && `49sX0zBHA8BE57QhYbMK2qhxArMbO8nMEVVyOWPnrO39xo6fvQxmB4gyfhIYgGGgyGTgzeMFKoyUXRlJcA5mLdxNyAkM7wwzmeyY`
      && `g6946cTM5Fz53HOerC2gb4ki8skkp8wa/PWABx+1BCUpF46sIPHpchOvQrwkMN88gEqFX9csC2B2DpwRbb6Axo/9FPG3Ph2GFwXu`
      && `WeQxh/XYkqU0rnsy0YUX07nwUdb5l7/FHz9a+lk1rw8v2TEsMvF8h1wi/c5wFB04iefolRMsv+nrKfnKqWofLw8jzKM7B3Hj6/i8`
      && `/5kw0GjR7rYvNXi94DEGyzAbCFHh5rPqZt6Cv9yZWQQWWmj24ZsKxpZNMDY+xuzpWeZmhWHLB+L424HngD0GWEGgV77CaFX8VEDm`
      && `iDLFwBIZY6BHI54FfNVF8Xvk9f6Nl27dP31imgsufiyHDuxk8sTR2gjOGeaiTcDPG/bk4k3VruRy0IvMOJb65K1ja8dmBweWAWdn`
      && `wBvXrKXdGKORTOFdVBQm8Dj2PXj/Q967E1euAaDjE+LILTpx6sQTnOxZgmsJ1qFhmUXlErJ/s0pFmGZMOmjiptHW4Acx9+FDq+P9`
      && `m45OMXkKTjx6nLE76ly4ZY4ETUj6VWTXYcFlVwasWFGF2MSkOX7TJqf/mqZLz7QOc4aXJoBfNex6zILy48FbQZWVxcqejJx7g08n`
      && `3yFinxItR/wK2BMpEk9rjQDyYvqnzPjtSd/5iwat9P7LxkEQwxLv9UozfsDMYijdfka+FgXemrFlK98OP5hRukFlYBbKPMkMHUe8`
      && `4fbDx9+xft2Y5+QB4HzTkMocnsoBBru0sMj09alMfGDLUlatWs3U5BQdpUtNvFLiJcASK9JyevXBsGYh3Mo1NJ73cuKnPhOL4/LT`
      && `KqtaWOZkFYZbuYbWc1+ItVrM/fWfwNTpwoxddcCq9ClLaFTihWDMeP32iNzBaSeOX7mOpV8nn7AzcyacyrIh1WVrZnaWxsD/biO0`
      && `mePQqZO2ZHjoUuCpGMOYCcmrLBCGqMfGqF8j+5sOxldvYvma5Zw8chJBnLb9VWb2EuA7MJZnF9ADufct/6qVcqqKpi+qk6r813Hg`
      && `GYjHm9nTZk7M/CHYl6enT3ZXrt1E3Bjg+OEgRAcBzjnDPwl0AyGzIiMANfzywGJh32dE/2HO7piZOcrZYPXaTbQBpzlmBkcYas8M`
      && `C2tFMBklSbJ59QZ2Hth93nt3ZPtqUi9aLXPTqS6OZS8CvlvG2qCVKusoi8/K6pdfLuniEGZbBJtNPNmZvnvD0c6fKk0/veHiibkT`
      && `p6Y4culqVtwemIbkaZiR4JeCXexheVV7KapDKCO2ZkvNuMi5KPKyBRmw8yKKDRK/DHOXYLa0LFhYKV9Yxu4sxdgauWaEl5e0GNgm`
      && `WBrod0YVXGCKKmtBLEba2oCGSWmXUKJRaExwtbCVueqVY1qBRDmVqc6lmBOFGzP/bj3dRotlXDg+1IrNKPolnIcGnD+oRxcrg5Vs`
      && `wTDphwgHto3z73cf5geWjuDTdHlkvMKLlyIWB7d3eF5ZbMMKITg0LYyJnvTtxNc9JXjwK9OvfKlyNS3UuxgcovHM78ffcyfdj76v`
      && `15RVbHgdbRkyeF4ESep481DKoa6DE1esYezm/V/bRtTiyAoJoAoeIe86D33sbyIwDM152Yh5pLQWhZb7IAozUBFHZ05pkQbeh//5`
      && `ML56Pd6Lk0dO4FMtMsdzgJ8GLjUjplYW/gzEJvOQFbc0p1eqEM0yr34x8GxMFxj8fpJ0/2X69MmZudmZnkF9E7gcbNgyIqMsArta`
      && `Sz6zyq0HNqXYHZGLaqOsXrsByYfqOUow5/CzM8bQ8HirM3dlYvYUYI2wtw94/xFv51/j7ujla5BEkip2bXuSmV4n7FqwRmY39QVj`
      && `oPyrCDgtCE0lTwSNpV7PNLjEzP7U+/Tt44uHjp3ueo5tG2fZ3YdpeaHIyNQ7n/Fen59SRWEJvN+Qy3nhGSCKDBcZUlBVVT2zeX3y`
      && `wAxfrVlsOZcND82a/dQVGCHw8mZ4lw08ImhGhhetFAZC7Sl5inHz6hHVdJnqZCy3wpY7SSbYVDcd84Z8w0FU+fp5dUM6g6Unl0bK`
      && `6s0PE+6/eiV+wPF9V02QdJPlwCvkeanEEuXszyrMt1b+I5vfyjU0nvQdMDSSBWIJfEU1zySnsiVhbkY3bPEY8dOeiY0tA+/L2iOV`
      && `P+WPll+6RZJegPSq1LQ8kkjMcezKr7F2dD36q+fFysFZet5DflOCGZ3ZEwCp1UuMzsM11b/29Y8I7MM3BMZXrmXJRVfSGGjg03Sx`
      && `OX4K+HWDy82I6DlKg4WZLyWxtGpKkmV+vJ5vZH9dBvxa5NxPeJ8OLR5b2jtsDCzNZbzC/lW4s6zMpDBaGKNjatXqD6xdtxWziChq`
      && `oYEGFiK3L7Ch4Z/w8FbBnwpeLvh+j31727lG9zzp6P7t60kJYcJxZN8m+C0vbkCKAVmVM2XzzPRRigCaCn0rZf2wQo+2evELhr2q`
      && `nWjpUKvBwKIBAFoGaSbzVJx7lEw3O6+K1qOspLHOGC3kijIO+RDVfnBWSQspnQ8yeW/tdYvDaWTLrNauMFWimXP/hCQLzQoYdC6Y`
      && `VoxBYKjck+KJPR31rMLySlKUqwO9mGZ5vFS2mNiiWvzOWRmwqwxU+aE3Hjo4ufXwyN6Ry5ezKh1ghIjU+zETr5b0cg9Lc7yolmSs`
      && `2IUrzEo0Hr0dt2ETyGe4VaQSFZ+pXcbqpjrDbXs0bss2SL2qYxemh4xpl55ZCVgs+Z9y4rWg8aaHjjxHLn/4XZRU/pc1jlBhzsgQ`
      && `yRh2ZtH/7kAjQwyNjpD5d6kSlNp+KbeNkIWPU/af7sP/aIiGRpnceQc+SRaZ2U8BP2dmE3k8ZUZWCjJwpnEkFbGiyhqsUJKAqihd`
      && `jJK5tNab2auduSt6BzezFJhhAR4efB41sS8BZicH5momaoNcBx137eSpuOjXBO8Afh/pexU05zijzoMec/488htuvWgVR33E745e`
      && `i0nfYrhfA67IJp4x21wkydZeUciK4v11cpj9W2h63hvLPbzMOXuR7yRDSSdh8oo1KDa89zlf9WXGZ8nUq13cQmCSPD74cxcEs5os`
      && `VU0Hrc2ycrcljBRmNi/L/YS1oLz8J1PpxROWd/gzmRGZkQZcG5QxYPUJLDTNuqW9FzGqZ5//VLIs5+VrQshZGbDPBlVVFMk3K7Px`
      && `K7MLPxyad/CSFQw31tDBkxjLTLxC8BIFM5GvYUaxrarvrpBFMfHWi3BDwxX/0HxpJD815ZJsRX5zS8ZwG7eGFow+BCEXLQyVn2NF`
      && `RiuCIW2RFy8S9qrUbHzEYjxwYPvDZcKW1aSu3vBCfgOwVsgEfpjjf3OABLEbNQWJvipnFjsPdUEekMnx9YlI6MM3Elav24KSNvK+`
      && `Zc79MGY/bWZLKUlp5QIv/GMGQdtbiCDmny8FeKtwh/zjbaBbGzcI3B2wW4EZFqBCdQcf+8AesLbhM2fZ+NoNQbOK7FHC3iLjrwWv`
      && `Bh5j0uIMh1VwBZDhOFeBnZu2reI/9s6yPury2pOf34jn1YjtYMqse1UFrTQ7F9mLqiyiuiCrvFswcC+zJd7sxRa5p4wsncx3PBdy`
      && `erSangPKhKFqK9gzQeSKedbPTCUbr2pdpUYrLAkxURKuyqlyaqHKurK/nCnUhmhY2P7IGDIYqLkoF+JphZm9+nsVdVRKO3Xrvpkx`
      && `L3flnFS8t41u+WLB0XzGpc81VA12bFpJ4mPmkuMILXGyl5ns5cBiywPqampuubOFJpqT5TjGlixFLiqnUfQjrDGvwlZfz6Y1aLaw`
      && `saUQRfPKWFa7QYl5yr4yx/6LTf7VbZ+uWGRGKuPw9odnjs6k7ywVqWJ1J1jeWz6m8b+8EIcZDDQBw6l2evm/Vv+wFbaYPgP+JoFo`
      && `yWKc2XUGP4OxipJkWx5ZZ7YQ96v9VnqGcrWv6q/Lrq5V7aEAWITZQeCPJH9bbVAB3qeCjwBfos4SslEMSU7SNPAe4N5e7TfxXTOz`
      && `pwo9y8zWmJnLvzqfuAuf/Xc2eNRwgxdcMMI0akVOP2zGUzL760IUWLmvTjnVLrlRzwczK0JVgw0DesF6b/zw9KlFq+QcUdB+C3fn`
      && `Qk8t40ez/6woYrYgWKEBV+rgW10oqHqfMi1VzsHorft6eXbdLJ4bLOXzXTAn4bxIBM3hMVJpiaQByMtuLACFdWUh5S7jD4U1pgfd`
      && `wk++Zh/nHAy4QvTzX+tDZidn/qHRvB3rV7J2YoDhoZhULDXpVQpVrpYVRoYqgy2Cvaozq/5oPVFSPQ7znrmpdylVM3XPAeahCXWb`
      && `hvVeSXlpicRPOeznZsTK4QjaOPZf8dBqRxsVUbUQW+vrNf91Cjv/Hw6p86XvBwrhtyQUOV8uXALCUs54gfrwPwJWT2wGwJ84NQH2`
      && `08BFFJespqVSVyWqpL0gzW2CljqT/ewBR546kkGusWWapwOOmPhDL/93mM112vXGJl5irjtzD+K3gc+AOiAXxpZD3kk6JfEOef2F`
      && `F9OkKQf3hSpbFkU4FzlJ4yE9Dq/sKktW0wsKNF6YM9fgYCdlEGiKC4DvwTFSFCOqbJmVg9aseISusS73Gs5TTotfrHr3THCD5J4w`
      && `2hKOBoWNrrqO8qs98nEWvLaAC6l4bHmpM5OrVdSPyriVV4LQ4RRNdXroYa9coNpzAiaU9fTVPmSCJYKmas/qmWNN66uuNSdMJb8o`
      && `rKx5ME9Yi4/M5CqDnzUK2rnC6TxPAqwIlBZKfJ0f3H3RGjZvH+bUzjnSVEsdepXgZ4ysyEYliCLP8VXlefV9CYxWSRd/9JBIE4gb`
      && `WURcdeM4O1pL0GmjE8fAp6W+Vbc1VS4+tXPKKkxL0ojBi5wZiezNSyw9fOohtjLM0izCRa9HcRb7nbZatUjvbxSsWreVKIo5eeo4`
      && `wwMDRHEckLY2LYPCkibMBfNU0zVpp21csV2OyVMnMOeJEEkXvBkhZTfL2E+7XPd9P8ktH38PkkjlkFRvTLHQnhQbZyEGgIjx9Vvx`
      && `05NErUFcVElJK6To8FkBSj3d2Tmaw0OYOQ7sue9r3ruV6zbRTedYPDrOwT07WTy2oieiMt+6kOzglTJz8gTbHns9e3fcxYHd97Fq`
      && `3WaiOGZuZoaZ0ydr/sW40cT7FJ+mRHGDsfE1dHfcBxMTleAR49SJI/gkQXKYi5H3uMjTGhxieGQJqQ/BfAf37AglPyXSdA4XNfN0`
      && `nFpluIKaIGZnpxkdGaM9N4eLHAfPo8TjqnVbckoVY/b9oCeRZ4JUy6/mCmzV31DsGseAewR3GOySmMq4xZDBSuAChSCr1ZAFcxWE`
      && `0QzTKZP+SOLPzNyUfJe4UebVH9xzP2s2XsCADSrtdD8RNRuHJPt+M10rGCf0K98DfAjxLmJ/0KUxVPLPu5n61yytjhUKthC1PNPr`
      && `dRhycFxyI3A92DZyNlX1cOc0v2JPzRSbU8BksBFpsWCk2PTiclS2PSBRPtgKHM+Y6ujDhp3OKV9+PMo/uxAExhvkizNZSnNFqfDl`
      && `Fjy4wLsaIc+8DnKAB19Wyu+5YQWXKOzAxVMwImfEci41RlOFKppn4hXZCbmqrKhcqqqKTlrou9Y1mMHkq2UKzsqA60WeSwSp1IIu`
      && `jv58dI49W8aJHEzeP0sqljj0MomfwhjNzCSFk/UMnlyoPDHkdRmkKem9d6HpKdziMUo8XEB1rwYjVNd64hjprh3gU8NFhf2qfpSV`
      && `YecX58xNPYtAL3BGZ86i31uEjs95x7Er17PspnMz4YAlWjimLc/Hji2UV/sGwep1m7NocOHTLsOji82lSQtsjEDglhN6MDuC1nEC`
      && `OGDGEbDpyDslJKRph9GhtczMnSKxrg0NL4oC24VGq3KUFDJhevOH/8VbowHecGoByTyDMzoDoRLBskiCkxG3hlDkGsDSyryHs+E6`
      && `2bz3m3NHB4ZH5oiC/WjVxIWY6WEz4pUTm0HQiodpz8ywaMlSh9lINodxQvnEGJRVI+KAmR0ZGF0ys3fHXUJifPUanIuRh0azZSNL`
      && `lkVIhcnKnMPnUrZzOsaxdPGGjTiB0gTiGPPeFi1eGvnU473PLKAhzMFFMd6nqXNOrcEBNmQHSWQ4DZk5PwC2DFgNWgLWJGiXpw0O`
      && `gR0aGBieSpPER3GU4c0WDpxPU4Jwy7cCz8EYycyOlmsMdWWmOGwDZoHPAP8s+BLYvrlud3rlwBK/NWrxmZmDbiBqNA2WG1yO8WzE`
      && `d2C2ohxDsyb+TvB/zTgpiYN7d9emt2JiI0qCYOIakRe6XXL3mLEGNKYQRXOk3Z47NDg4nMqXbo9V6zbjzOER3cjJUpU6UqHlVUhS`
      && `5iYTyAu5CCbWb8HMBX1YKU7igeHVXDG5i1iiBSOYXQcMlWNUjOvZLclJtMNOGfqQmT6M7EFMkWCTxDM8eorEcHZ7ZNU063xcI+9O`
      && `foVgFWanrdSeq5SxwiCDYJ4Lz8p5xRnIVuSzXcq4QNChKitawGQPeSZUXUmyUC+ghm9W8McwJ58ZTX3ones8tpgQeR8GqW0m+Y52`
      && `Hbpb4gDBTSrKWCUVrN1K40Bu0cc4hPHJpYMj6dTcbDHo2fOAcz9jnsU8bwfDC844Z/LajdsmmFjqONUR3USjDl6O+BkzlrGgzLDA`
      && `fluNieYiDwiSO2/H77zP3JWPy6LM8pSEylSlYpdqOyuR3HYL6d135gMW3gtyN0Sp6FXkzCzgNpOCVOiHLEG8NDYl3nhLi/T4dCf4`
      && `hMdv3XvOZdZCM2r4FqDTmSGOWufcsocDq9ZuDl59FwFqgFsXeT0eF10LPMoCQV4ENLITSWXMGhwBuxvxWZk+g7Sz1RjuTrWPYcaw`
      && `w57h4vgaQtVUCCa53OafWxbuxPSveI4bIu56aBbiZmGmqlrXyuPItk4QNyJ86kcURZdj9jQTjwOtA0aFGiGhUx6zaZP2Y3aHTF9A`
      && `+qLDdluUdn0CazZcwP7d58+EV6zaSHOoSdJJaEQRqTQitC2KGtcC14AuNLEUlBW5xRs2Bxw2c3fHsfsc3n9KsCtuDCc+WGMWm9l3`
      && `xlH8aPKI8Iz2ZTaQSGhytDP8QfA3eUk4B2m6VGbPdC7a5lwUK2iCWFbQAiNF3Cnp/e3ZuRNav4W0LRc1bMIiXZ9VInoUsEqB0Oea`
      && `ZBvjONh9zrhR0ueB/7I4niRJ2LDl0bTb0wvWWs7Li6amKJJ7GujSmuZlNWJaPWIHHAL+UujPzSW7UUMIGlHEseQ0R5MpWlHsLdQ3`
      && `3jvYcHunO+nnndnHkH4W42oTc2b2j5K92UU6knSNQ/vnV55awghTzKKQvrpcYhGWZkKxTZo5Z9jIwMDQIkkJ4shjt22Z/MrdD5C6`
      && `FDMXm3yj6X3DcC2VgTg1rLUcYQM0XaRRZ9ZwBPOqCxWUfCvtzG5qH/XHBhYT2ykEqxy6WGYLcL8qkZIZdtTBHxr8RdtOHG65FeCh`
      && `4dqW+OgDiNd48ULlzJyixGLNvJy5jleZbEPqua/qFCjmsQC9kvLQVZzXmWVncgZsqliKysHK2hfl3MKcUsvE0jrNLDl/jUhkPNu7`
      && `THkL9arMmWe0UAALy+c8DfSUM35fnvdjoSK0zdfqjcyilVsFMq7QbYvJ7txcze97dgZcqMCFQphZ+qz2tKg+0Xnwn9tWcfWGiNlj`
      && `KT5laYReKtkrgGWUCfLnp9L1iicBAUyHD9D+wLtxmy7Axpb24EJu0ra6CTO4xfEH9tJ93zvR5Amst4hHIWnBwiaU7LQsZ8LFTi1B`
      && `vNzMnJe9ZfGgHZ2aE0e2T7DiLEy44lIorpcqczaQkg6yr68Jes2GrVmMglCaOnPRVmTfDTwTuBSxCMvM4vPnbMBG4CrgWcB/YfZO`
      && `KX1Pw8UPJD69wNAvA5dRFhqo3CrIqmccQBwg0fsVG4mLadLpSUmoE7Dai5JmZtOo1eAq4AeBZyKtAxqq+FFKbQSATRiPB34IuMPD`
      && `+5D9u7y/x6eJX7l2A87F59TsVk1soT3TptGKAQYS7x9j8L2YPQ2xAdRiIRwPZpxNhHKL34PZzQb/LPn3RM7t99JjgV/N9rfuFMk3`
      && `Qngz2wC8ErPpA4/dwZr/3HKd0BslVlqWIlniJjmp2ot00sXRv6dJuiJu2jMU9u3xwKJgt873uizeALYBaTvwXcBe4ONK03cZfLGb`
      && `dKYlv6A2nFuZnWedTN9ueUvRnO9az8dL7Dho8GYv/XkURadTD53ZlLhpHN5fZ/TD4+t4xtb1fObBA0SRO6FU78Q4ivRisD3e660D`
      && `w/GDM6c7NFsLk78pZvF4LJh4fxHYZlhUmWGhUgm6mP79y/fe/xYcJ4Fx75PnIC6QWdPjr6UUnMqFBSUtR0cDXQv2ex5rC0vN+6zE`
      && `qusk8cCHF/vkIx0lHeTxuLWGVuK9ySoF8yrcLrMid830z5K9DbOTTb+EbncmK3jRkMFeB28z06Wp7En5IZfegB76DyNmrE29aIRk`
      && `A/MLxhHNc5tl+tD8Q64icab5lg7g2njFFa+MW5ZAzmzsKjrS9pgDKESFbHCXl5cw8IosZN5UbMk9yCgwaVqwWw13LBlq0JhqU9gA`
      && `KlYDk7LOSVbMDSDOLtCSStniszJgFY2OpGJfattigLydo/bQ+uGI00c9qdliM71U4hWYlpNnOuWLUK/kM29COcGqiUKm4MdLPvEh`
      && `ulu30Xz2D8LA0IJjmavsVmbySm+7Cd32FQwPri5OFPE9FbGy56eKTbvCUIKGtxSvl5mZOgm/P9jg5JE5z/7ta1lzpgYOWV9Fk8xX`
      && `d7zCgwdtAGcNZpnl6wHLxpaQdmeJ4iEwBp3Fz5DxUuAaCybbSkJW5VIW5KMWdzqMuAZxCWbXJ0p/DyNGLKWKqspYYu6bCwMsAcaj`
      && `VmRp6kVUFhtRdb8pBODsZ0GoBT3cavB9wM8C2zFr5CJ4VbcK1dELV0K264yCXSt0ucQzXMwfy/sPWBTP+jRh1YatHNy9cJ3eVeu2`
      && `IMHQ6CA+SZc5sx8Dngdsk9SgFGWrEkfFRlUYUoaB64FLgWu8928CVmKMBfOYFQQyN+9li4qAVZKazrnpia9sMTNWIBsjz2uxTK9Q`
      && `lVSwDGxt0k23mrmfBT3HQs1llUQr3+HMLZeXwAvVppoSW4CNoCcJ+zsp/Qvn4gMIVk9s4cDekgnHrsHA8mFmj0xdQchbzU8/NxMW`
      && `dtPiaMQ0xp95+b8EO20GJ45O0Z7t6RCQwfThPbzrcCgJu2piMzKlQp9wuNvB5sbGB0/edfMdNJvjdDoLjyFEly5NmheDPcOCC6ME`
      && `ozo/CBW7/tXMnZT3l8p4rZltyqwNC7sGVR0NwLbKuMAIFYcLImPOnNlmnG7pyPamMrrOHTLvP2/eX42xzJwNIHPKG2NnjjyHDmD2`
      && `Xjmd9KmYObiftaGaJCevWEMkiNGuLvYFg+sU+IF611qhbbEXY/t37WPrlnXIK5PtystYmHrrVS9zD90ZabvlXup5+9NTPhMqdNZk`
      && `MhWlJsvsbKs+uIdQVC4eZInJAwqNKipUJrO65T+GGzHnjOl0pMnpK9ey7JM7QIaXkSvhls1v0dgID969jw0Hzt5r+awMuCJeFDNZ`
      && `II78rObjE1esBQ9d+UWR8TKJnyH44gLzrUgb8xlmYQLO9l217cm/KYJPTCeP0/67/weRo/ltz8IWj2USCUVUmonyQDOJJNp+FfFT`
      && `v4PuR/8ddduUzgEVnykRpeclZePnxv7c2pRdBhljBi93Rif1/MmKgejE/m7C3ivWMrFAK0NVNfWs/F0vvXa5efzrBK3R8ezhfrHB`
      && `CzFebqXG5Sv7PD8Sve6eySVIb8FH/EzBKuBjmEUVl1cpFhZfzEz4hlRYXhxZn7Oezc9Lk+R33aTQF/a5BO1tM7mFqv6cUmjL3QeV`
      && `rQdksiHQt4JtNBePY+7tFjVmumdA81UTm5BC9IZPtQGznwV+FGMskyvme2cWkLAr4A3GFDTycWAHheu3QtFyJhBQJT8ee/xTns0X`
      && `PvTPZnGj2JziuwsaL7jUjCcB34VZK999LfDB/Mn57ck8dQoHZRcI/ZzBJuBNfoC73VwQTg7mmrDB7NGpFsa1GVOrXXnlF8nKIAiZ`
      && `Pg76syiKT5kZe3fdy/nCwb07WTmxCcNS4CDA4X2nWTa+gWOHd5/1uxFNgCYhCq3Yk6KMIwUfcIgBYMA5I4VhC+bcKl7NcymeYY99`
      && `zTpjkGXvjHpoyBzTZnRcdI9HL3feNsWmbZHZo814lMEmEyskhiU1Me400105ouTMF2DJzfs5tX0NzHW7DLaOAV1EXL/PddaXqWHx`
      && `eKu8rHkZ0CqKWRk2W3XZnT1xo4icLRG7+HxV+laFEIpMtM1xO69YkUdwZ/pybY6Z+FrR48w0YLDEqqfba4YOS52VZ2rxyVMWfWJ2`
      && `CTAqscjwZrJZzE4ZTHoXtadOzTC6YhGTq5YwepaWtWdlwI2skXPJFXqhtGb1bu7RKyZCnFDYgtEIXox4pWXMt4evoWqV9eq17Dnj`
      && `EjHzs6qQBufQ4QN0/uIt6IF7iZ/4DKJtl8KixT1F1PNNNTDDrZ1g4EWvBBfR+eC70dxcgX5Wwciac78qoVWOvWDPxRpMEmOgVxq4`
      && `Oa8/Xu2i46cQ+65cx9oFGzhURI35viPJeR5Cydgzwur1WwlLSgFGDXsZ2M+CCtdAxcIzz8WzABGp8OiCzV4t2AIsKrpZFRahysoq`
      && `gRTqtKERFdeHghJkUmkPOmZzWQJ8D4Fo+gUZb4/3oYIJpT5vmUglNmK8DjQr838fy7rLV23g6MGScA80Ap11zpHKTxj8EvAjGAPB`
      && `LJwvaN7xVphwQQkq1oCspZv0JOCxUATJVOZclYWymA8Z7/6rNzO+ej1RYNoLF/QpLQJN4PtAI+RBVpbbIet4rvxoS5k8269iFt7M`
      && `hiU9Fxh1bX7FwV0psGzVOo4d3JPT66VmXAlEBX0vkUmVZzpgP9jbPz2+Y9/1hzYzderYQ8bxQ+fo+3smsBgjySw2FReQrMqELRe6`
      && `g1yMI0TDzPfT9BJPVehKjhP1e1ASQw9JR/gIzxKDUygdlQ4sStIDNw1EXxz1vrHI3OIGtt5MWw0uNGwFxod96g8BjN1SZwInLl0Z`
      && `4nmHGk3BCrBGvvfzskaKU5E3Y+62I+hb1qiKsue3p2d7s27dsnzLy0cv+PmQ05NtecgeL2zola9kL2exJlKwnctAISR5GGxRMct5`
      && `porCMp0AF03SfJKwa4BNgrFgbGAK2G/GbU7+i2BfXTI0cujU3CwnL1+Ll1h66/w+AecwQefbNs+QS1U6cguI+d45nDzebJGTXizx`
      && `KozlzCMk1AgjyhXuisQz74yLWPEKq85+tBDR3Hn3P5LcdCOtV/4K0WOuDW/lAoXrxRyDlWto/uiL0OQpuh99f3h+5KjesDyZqzj8`
      && `cj6lk6wqROQLCMr3UsHLI8zNwB8ucdHJnXMd9l0+wdpbqj5hkWk8Z/KtWBoPoOg8GlmdAzZt2sSuXTsx0yC4HwN7OVW/vGrHUsOC`
      && `HltNtgs93K1Ej2X5Xii/3UEMrQc75sdd+OGTBWZdIEtF2gEFM2xR57xHK89Paf5u1ve9eus9sA7xWpM71Ol0PhRFkVZObOFQZlZd`
      && `tnYC7z3eJ6Nm7mXAD2IMBITRWciwKvhXQRejZlgnrGnxmc6vbgWy3iX3mBisqCBT+V4kWF4J2gR6Akirx1k7J4VwU1EmpQdJtAF8`
      && `B3A6Rb8UuWh/c3CYY9loZqwDNuaWqLK0n+Y/BP4T+NINh7eSSkyfnuS/C5qGkmyl5JbdQEQyelDd7soJZGXsClndoNdaVQud6ine`
      && `Me/oQq1HJ2RtGXtnjvCo+8LM/mrbGM9btkpfOniwM2zuiIwjDee+Ou2TeMAajTR1bXPyPR2cmBuOaSceGjES6wlWo4YZvpSByrtc`
      && `aP8hc+DIldvX4LzhI4VmgRUdpZh/zVIWooUrSDYPsq0Lf2UCumqcQtmsjCIiByxv05O9Zb13bF5sQanHFPvvjEVeGqnluspqTybQ`
      && `g00efkuytYKRXNvoMZx/m4dDhr5wuj37DuBTzrkp5Dl15QSLe9rWnpWKd1VrTKDeyZuCv9I5yhpgwJEr14FEio1E3r9E4tVmrGSh`
      && `gKteA79VXzrDcRUSae4VzW5zfpEl83MdbHgRNr66ECTyIiT+1ImQLzw8EspO5sRg7XpaL34VdLt0P/cxlOcEF5boMhKqd36Wo18v`
      && `TymUCQlsuRk/3XLW7cAfb241Tn1qRuy6bIKNt+0tRnRmkbFAKlKm+uX9rr9W2LVrFyem5xgbHnoq6FWg1VAkdS/oa+iRjFVjavm5`
      && `LMSdqwmHBR4VmF6zdOFjcGmwWpNYvvO1mK0wYHHb5mkYuY+5mHjpPs1en5+7X0a6VRHwUUI/FzfiB834ryw7heXj6+nMzoEpiuLG`
      && `cxDPlzGSP6a04NgZmVjtBc1/qYBeY16VrhS4SYTJfv73/42/fNMrilDzknmUI+WxMKWFwfKNodenEDYqvKd6ShA+uHQWkipagu/D`
      && `7L4kSX4/IZkbX7spR4ItlObn+Rm+xe5p2sRnEuxQhHBnyDEdGl/J0oFRumkS8paLteVLy7UDX+JcoSRVG+gYab5PBknsoVurbKjS`
      && `M53zmcqDlJWCzD1ENStNPXldC535gp8sXnWGnDe4qdskF0yff/cJnn/3ieJT+y5bxXRXDDeiRCgx54mdY9FXSyvbzPpBZtatxc3O`
      && `YV6LhP2o4OrskKnFZWTCcnHtjJMSuxrO5ulFpfZRNfvUdBHvLPTIWQhknrLifX1nSgEgpy1Z2bOsxJYBzmE+s8oU8lz1FvfKS9nI`
      && `3gvnbAlisNcqW1+g4YNlcHk+0UJ2tHJuggZinUffb+LxBn+bev82YQeiBVD4HD5gyxna/Jnl5hfKPwCHr1yXT3o0ln4S8WpgXDWf`
      && `b0WIqXlHziofFQddtCepxnX20HFbupTmM55FtGFj1kjBIRN+dobOu96BOnO0fuAnYPHSDNEMnMNt2kLrpa+GNKH72Y8FAS+KyIKj`
      && `yoNZQLtRYcCpn5/lpvJAnJea+JlYdDvS/3vysJ3a0+5RGStLWwjirDjC1wIr125AiLGhwfXASzKTa5nPvsAJ9EBFhyk+o15cKU+4`
      && `vFa50lRWD6wJMkYzQSngfR5rVHB1WxhPqi+WhK7CU/IrkltOitOotjzpXV5Jya8xs+ca/EYcMb1qYjOduQ5Do8Mkne5lBi/qte70`
      && `7tkZsHsh2XzBna6tK1tcha2aoQhk//53v4uLXM0YU+BKCNqyOi+ty8A9E7LK83pFBMuDJ6sugUwzlgWz+Y+Yc5+JIve5TjfBy7vI`
      && `oi1IAwsvtmLUEEdk3NIAP93pMHlo4cyBlcPL6SQdEp9YwxoDWbTy/N0ryVRVxSt2VtBZOUzn8HSGp3MngGXF0vM+rwuIocGwg3n5`
      && `fCPU85Ez2ZHmz3NhT59FkcmlOA50m4SiX/Nh7W0HORec2ryVgdOncKlfkpq9GHixsOE8Qq92wyo7Fiik3W/43WB5wZ35xavn+QvD`
      && `9hqYdDaiVbB5HzTxfJj5gbmFAcxypZkcoSvkyCgCducdhckVVMnh5ZcLC2lYPVJ5HsFlpdF3XiHF4pegkCoX9AXrhb3ShUC5N0ra`
      && `f+LKdYxV3I7nYMBRrlCGX/O5yAobe1Xu2X3VBvAp3rmRhvcvNOnVGOMlneuxbdUwdR79zLdgngFH1WNRuW35wciQu/gyi6+5DovL`
      && `Cjd4kT5wH+0P/BvJ7geUtrs2+NwXwJJlwfLhwu66zRfSesnPorRL8pXPg7MyyVrKMlgL1TZ7pvKDKtSA3uVmMoIXWgF6VWQWnfT2`
      && `ttWxP/XpS1Zx+X8dZGt2fPOkwFr90HMXbT8rDK0BDJ90oyhqfCfStUWcXc2FW0Ovch3lC7OEWrhdQhm3RQatXiN8zjpL/M65YG2V`
      && `+X1zWASWkhLsmWE6ZX7gfKNeeLFX0M0uUAfjNGIu27RhieHwnGwa1XUWrQAKG7Is+HS/C3iPM/tPL9EaaJG0u4Pm7DnA9nmzKfTB`
      && `BYUFgI6ZTSnk1UZIw8AgFG34FuRR+ZSotOOpaLd24uiBIt6tmjJYMzrU9Ihy97JPOonUjBlgOlP7Qqs20chYcja/gjjlEnGxeAVZ`
      && `ZwvwXUmS3Bw5mwaaoAmV0bYL6huZdnkQsVcLb0MBc0kbwDXj5g3Ad5vZIMEEbMEaTEqwsbssv8BnelNu71TWeWzv0Rn+waxxf9Aw`
      && `R8pdyoxtOd0pZBEVCrUHeR+2xefiCUGWVqHViSzg3eYvOudT5XeL8w4F4yxbzMNzPZ3avhzM4U8cA7EohZcIvQqzFUHw7hUZevAG`
      && `Zg0+julYXgwqu0+ujtbFzyrtwmaZFr/wzQW8PFEmBajCX8rp1GXBTKcpWHpGjX29VnPZq7fnOjmfhvitbiOikWhpIhr1GhGVbKQy`
      && `6rr2fvGcitBRr55oXsawhx91cELYmww71b36Iu6MH2T7l2bPcZpRvriqBJizkjJ33oC2oCVPRzY84P2LTXoNYhVWBnZUmXB1f89g`
      && `8ey5elUyTomkpYCi4pxag8Q3PA23ai1KU5RVlaHdpvvJj+B33Cebm6Xz93+JiyOaz30htmgsrCerMBVtezQDP/065v7kd0hu+qKp`
      && `24XUF+UjirqmoX90OYeqVbXEtmoTLRQq4q1CvKaltHnS+z++otU41gKONAdZkVZUYqlXOTOlCUUZhocBW9aMMttJkFhHCFwaVZ4y`
      && `cSZ6pyLfPjG0U2afQnwR2CNpzrBhjG2C6xHXWiiuXxYvqZT4rv9Wc/6ZIApVd0yRKs3ZKlGRZxKjKzjlCGX3vgx8XNIdwAlEBKw2`
      && `eCzYU4CLgUZhtsgVugqqZ6zGW6jc9HSf+pvN6Lo4Ik39ZkxPRwwC5xMVZ4Qyil8EPg7cA5wmyBkTwNXAU4AL6UkJyZm5ZVSnJt9n`
      && `ZlvJiOKYJOnm3VWt1/+XralikCkeYBkO3Av6iMSXBHuCCcjGkC4yuB7Z4zBW9Nho1Gu3DxZuNc3sGWbuX8zsxqzY/bLsfIqwI+v1`
      && `W4RRjuLshGFn1H4LxJRfZGYvAvs+LWTBMc5A+PNjNjDmwObM0t9HlihpBPpX8fJVyHqhDGVk2gNePgWxU3ATcIkFTrUYbChH97Po`
      && `wLOIU0BSSyUy5My+KDg2zLkKNywMJy5fw4Fb9rPqyg04JaPe8zIvvVIwbuBdYeycr7pCEABMuh3sP8zibpomCFeKFdXTKwW06p4b`
      && `4DyckbyYrLhAtRayQU6qSJIlO1UWUpI/4IzmJ8o3M1YZGWbdVaOM3rbHdVYsWQYWlwSmKo1kd642ZMUBpgWoUmGNLcy0I/I838zu`
      && `n4vSv/PpTLJpdg2w4/zSkOYZDnpEXkN8/0CKh5Em/vnmeS3GuEI6ynyqnlG8PDG7so6KWltdVPZyrwu2nEB5Bt7jNl9I43HXI4uy`
      && `BGqPJPyuHXQ/8h+i08a1Wqg7R+e9/4iNjdF69g9jA2X2gMxwF15C8/k/jZ+dQQ8+gI0uxlyE2nP4yZMwPZVFRBYB7/OWml1WK/Ta`
      && `cg88aKmhVww6Fx2T3rLxb37yGFt+G/ej11Q6aM27tb7tEpw7EyqfGyZnOgwPxnS6/mpCzmk2Jy248wUWwhTwXsGfIt1Cx8/Qiomi`
      && `oM1257ofi+Lo7w2eJPFy4PFgcVUGLWLVakbMmoLmLCvSaM0CPaq4T6F69IRhVhzFdwn+r6R3dZPk4PDwkE+T4M/ffOnl3HfLV95r`
      && `4h8MXiKzHyQrCJHrJlZYtGrQAr4Vs7/AOJB0u+acewyBWc4/jIVDoG8idN/5gMTRVjNSmho4o9vpYOb+xRyXI16C8T0WIjNrAnwp`
      && `4S9sC7jo0Y/jtq9+GkVRrknW3l841gkDZkAfBP2xl//yjO/OjTWGkcHwwADHJ0//h3P2dkPPIATrXQH1s6laRzIS5Qla8HUyfRXR`
      && `UBBWCjG1Jr2Wc/Jgk4h6h4QzgjXBVhBY5hkEoV7mUtdeDAaQrcEsknySzM0Sj4y4nm9bxm2UU0AVHsdw9b1P/8u5+KcRK2UMGvYS`
      && `4FmlyHkG9it9xtAfg01iobilmZkzS52x84Jk+vjOaJCHeutPbF8FScKqq9eDT8e9eKnEywiNb3w1vcFKk4gK/4zJOeyEmf2dSXcX`
      && `OFgxgpYW4QpuVfkRdVfVgqfjaha4kq0WYlo9PDHQ3fw/l9MRKyZS4dnVE8ye4gA7df1GGvtOxBhLgciKwKzyK4UdIOe4hQNDvcaK`
      && `cuE9TImgma9CvKiZRl9tmd027TrAuUzQWoD5ZreruhuzcvzOkjQ+1ub7DV5joeatrxAA67FaZa/lokatqEDPIS5kbKz9U/lJqNmi`
      && `8aRnmFu9NjuErD9smtL93Cfx+x6EgRZELmi706do/9NfYXFM8zu+FwaHS/MhhrvkCgZ+9vVw8kSosBXHaHYWf2APyU3/SfL5T6L9`
      && `e4LNOJe0zQqrhGqTtIJ3ZCv0Zm7M4KUjxuzdv/+Bt164fud0Xki9iLzs3RZ7+KWgR1dMEDljbjYZsNhdZbBUUFT9qF6ios6MMExd`
      && `Ye9G+lWc7ZL30DAOPhhKNS5atpIrLr1C9+649/iBPTvetXrdlt3Ab4CelHsdLVebVBh4FhJdZYqANLfAWO1jxW/zvohCafZdwBtS`
      && `798VR1H3+IlDTJ6O6U6fAiBNE9K022m1hm9Ok+7rkRLg+TJrQdWDXTVDWU5pLzKzC0AHkAaBxyFGCqliITQtA77uRPqlxPuPRUa6`
      && `bt0EDz74IIf37wZg9bqtpGnSdtb6snxnr5lNAS8EmplFPBgwVR5JIZyXGp5aA0OYdxCFOkHWM50qHlX+6gL/ivHrraGBHbNTMyyK`
      && `Bnhwd8i5HV+zkQ0bNvgH9+w5Ihf/vVO6T9JvYVxpVSJZreFbPq0FPFapRpwLXeAWuMgqrWDFRibe+4eca1fVNPONLy9cJvDX7Apl`
      && `X3PLCh7LQM1mPp71DJ0Pq9rLRfySUuB+wf3tGdzgEN+mYnWWc4CSYOXGMrMHLUk/JufavfTNgPeNPpaLp2/jNfuOnvdeHL8y60ke`
      && `N5HS1WCvlnieYImZaR5prZlEIKMACei9Qu+2OOqOrF/F5AN7slnl9ad68CuXbaiR6hDaUsQn1CHFct9LZrmh1IAr1obcilrynzIk`
      && `OpeCCtp7BiEV4WVoyb/fRRK5hhljBUcrNeWKpyfj6MqrPVChjIVMtoC3qfLIMOXtDp7Zle5qYl04RzvCOCdH9bkVM8zi7ZkBHWsn`
      && `lxr+pQbryDVfy0mQqihXH6QnDL8msxRfq/mG5iONMnEo9eYuvNgaT3gS1hrA4giLws3wB/aSfOnTwglrZHKH99BN0d49zP6/P6T9`
      && `r/+AnzqNzy+MgWs0aVxyOY1rn0h88XaiCy8h3n41jac/m4GX/wIDP/dG3BXXZONVNL1cQ8txujJmz/3yBsuc10sXO55yz9Rt88Jz`
      && `e4NkWkQ0eHgm6HanG6YV2VLEpWSmzl7Zp0ddN8RXJf0hxi75IDBVu9+cPnaIz3zqQxgRqyY248zdCPwOcC/SQkR3IdFKgQGHQFLn`
      && `jbKz+AIfzdCnaPsFc8Dfeu/f48y6zjkWDS8qmC/AwT07ObJ/D7PTk4AdBN4KfKGYWd3oWzV7CRgDPTrgtluKFOozV51VRfOw4uyM`
      && `YA7/v176eORcKoyvfOmzBfMFOLDnfsxEt30ai9w+ZH8AfLbYskogVe9Lyn2PwPFj+0L/nTOaXevIR+BANyK9yRHtmD09jWHsr5SR`
      && `PLx/Fzd+8dO86R9uZsu2y9Ok0/kk8HuIAyH8t3xWlflWONQ2QkGWhUnUfCueAS0zix5CsGHl+Co+hMr3C3pixUxrd0tC+d1vNpuF`
      && `hkcPqhYewZIcU9Jl4+DeHfhuSiNOnSp23ZxULXgKQad08mL/ngfYt2cnex7cwYO77+eBXffDne/jzt27zncvOH75apSmGA6UrkH2`
      && `ixIvAsaqNS5qWmt9ZmYitdAT+c0jzYEDn79xD/d/5Magz4U9NKpHf/ajQR4+8eXfWvgjOY302SbW8tB7zWC5+9MK16jKSQQxSCp0`
      && `vuIm57Kw4b2kaLaLmRuQNKZQnLL4rBVBt9no5RQ6wHFDRwxNZc8yzcfh2u9mSKZBpGfI+zWuqOJyFkgKxlETcYqAs8wOz5Ma3Rbo`
      && `O0xcYtZj1uidV2koAGoo3LPHVdnTyk9StuOt3x4PrQGiG56GW78piFwuixZOU9Ivfhr/wL0WkpY9pCkkXnR9MJQdOkTnb/6U5IPv`
      && `wTpzOAtmkcLOn//xPqQueQ/DI8RPeCJDP/8GGjc8DWs08lCPGjkoyLcWoDVhXG9ibYT90D2Tg8vTKtr1MCABnvScjbvPBCNDA1mb`
      && `OVaCNpSqh0wVPaRODG0K+Ic06dzu05CHc6bayAf23Iczw4dYlM8B/yJpLqtENu+SWp1ICuQ7abgKcVStBVKX4SoyTXbjAHSz5P8+`
      && `juPZRqPB3l33Mnl84cjQ1uAQQnTauhd4B/LHValDvxDqErS5ralXA2M1ZhP0EB6pKj4VM/4C4n1x5JI08Rw6Q9u+Q/t2Y8Qg0Wwm`
      && `D2D8JXCEovFKUXCtFzJy4/XgjjuJYlfT86pzyUVeFQkUnMLsbwR3pUrAGYf2PbDg/H78+sV84SPvJGo0PPBR4GOlMqKKBS7/L58b`
      && `KzFbR7hpaRlPkk/Nek7ZDBjDbPgclsuMAJdPK70SVR2IXEu3QCyLOsy9kOe/s6j8veLkqCBdzyzm8+o4+zPvMTXtt3KzUzPT15rd`
      && `AHD8iqD5xq0hhDZL9qsSzwNGcKUiWTOS1qdniMTgA4Z+aXTFxXdOtmd57OWrueA05JXq8r7G3hcMrybTVEYOZMtMT3zsLy44Z+eL`
      && `nMYeN17Jf6oOmIIJV1qj51pzXYZeaHkqrLMu2JJnkBK8XKYsVEhgRhOl1KSbTPptM73IwY9H8LNOeqeJkyr6Ky9w/SuLkfxFJm1P`
      && `5Nl3yaqzM2CPp5ebFCawkjm7a6PuqHl/DVKzCAeu7WON686fXXWPrZcBVJh9fWN7tlfY5gtoXPtEaA1kIoeQPDqwl+QTHwpm5CQx`
      && `0sw17QyLTBY73EALnT5B+2P/jo4drUnOhQKkTIKtashmRFsvYuD5Lye+6NIKruSei5wUlGpBHkjdixrO2N4wtnSMtDQtzsefDuJM`
      && `pRHPBVEU4YLVaBxYVtNTMtFYVcoVMP4BjE/EjWbqfVqWFjwDHOvO5FSrLfFhQhnA8lhtAd2s1Bp9lM6CRJIooOGZiGAhthmYdcE+`
      && `LNkD3ovZ2YVTNXKYm5oEQbNlAr4Adn8uefeYUCEQbhTag60ys0EzW0VBp+v2gzyTMRtlBvhE2vX70vTsZiqAI4cexDujkzQE9mWM`
      && `2+dhunoeGZhQEUi2sGhW/1ZFPr4H+JxzziM4vHfXOXFI3jM8OHoc8SngFFiISLD5LhOCGXzIYJXk24Sgs3q6SPVil5L6csPGDGPV`
      && `xKazTygs3spV5tpTzijmnWhOW+e/lsFVeW5LXsO22L26zlg8NHtu0VgzVl59vzbTMiWsMkg+2wjc19hj5ej2NaG4hAzfbV8g8X8Q`
      && `z6XodlQR6mspO+R/zMCb6cMYr++cjm45dfhODFh6y4HKpKsbPe88cpG+lPaER2DJGRQHZ1VL0zyVrCC7QYDKdLCaZpbTAYog94oZ`
      && `tucQiMxwCO/9KUN/4qQ3mfReQ7ebdNRQN/f4G8KJTzp4eST9hpn9K/DBqdH4L5zZq8z4Y+Bk7VSt/KdCWyUYNWP7bJJGcF55wGEg`
      && `WW3ccsHAhPlliHVZu9pec03maKEMkllIyisKKufsVXXBMleW8gUVHsXsLjUHaDzxaXIbtxipD43EJEgSks99At12E9ZNQukx58JE`
      && `TWAuHH4cwUCLxlXX4JatqKQahH+Di7Q86IKRWFC+o4svo/kdz8HvvAc/N9uLmHVZpJDjKl6KII0taaGVqdnuwobSo/0aWJTl+j8c`
      && `cBhzncSihq0gu5TlY6oSfJUwchdir5lx5MCecz6jffAAB8mar8MOsJ1IG6o0p0Zq8/Xl/N8nyDXodhvEsc87giyAn9Vt4RRw80CD`
      && `bjsRRw+efZ7Hjx0GDrN6YjPAQYwHwB6ba3ClYynTp6ywsy4xY1BeYxhNqzhKyklVVhTSD+5oDFo6eTTl9OkHOBeUnISjwD2E2tQu`
      && `e1m5emu5Wpc5obLUnx4VogdP8t0qhaD7BIcfijg3ftllHLnjDjDuBY4KjQHz8sBK/x1NYLzdVbvVsIOSfF0HU26jK4mutAKYALtT`
      && `52XtCW6OvOBX2bvJzswkalhUNXnC55pCnSySPF9Gj1Wv8vl5Nr+s2olVCpCVu1/QQQo+JnBpytcER7evRcCgjA66SJ5fB30XRitM`
      && `yXqude9iMEOpGR9H/MqopbdMjoTPL7mlLCRtsQ8l2k1mPfpuzW2bLTn70edu54Uol4y8+G1NhlqwVo/KYqkVm13JeELARBZUlmtr`
      && `VvIvM1KXR7ArnVPzC0Ou81UvjRJKJW8wsU1wsYmtZpwAfj917osu9QxuHKdz7wEWn+ySOnfQHH/sxHrBjwQZrGx8W8Y5kQkl1hC6`
      && `cCC2IeD0OZJJc65bMcSXJ1XENjRC19ZWriHWc6Gq+1Zm9c4zbJfnRQ1fc4JmORHMpH2r2OkN3LoNNK57qllzINg7Uo98it+7m+5/`
      && `vAc/MxWYbJQx3EJyyp6WpLjxNTSuezI2NDRPcCqt4RVpq5hiGC96/HW49ZvFArEj1oN55ZlUDatZGZ2KNaswt1a+06BJgwYPCwxc`
      && `w8zKnFPKkDErTRzFBCXQUaCjc6lvC+KPmwGO5qJZZkYptYYeMVqARaHVcKSIXt0jF3zqG4sBU2Z2PCUm9IM+3xlGGNEc2HHAL4S2`
      && `5LgWfmtJigk4f/b7E2Y+DTrhU7Fs/PyEpoO7d4Sofe/bko5KpHkkQCHYF/tbRID5qqmO3guY73nFqqLgNz5hom1wRtPzvPndfHP+`
      && `42lgujKVhdZvBFfXiFKfSjxIMOJkbxbCqFUuvwiEcLtSHzsilixdsfAWyyP5OUl3C52UNAOaBk0Bk0hTBL9dfZo1Y2kJuWi7eM2K`
      && `QpJZoPVJL3sJRAnDXGbFTkBJ1eebu5IqHLDGZSpn9DDgyPY1CJhjgDn8ZUJvlPQshTaYWaRyz4ILi29Yg0kdw95n2OvcyNgtk4rA`
      && `YElPHelUxR5qwd2p7VLFNqszW4DK6EzL7IYlW7XeoJi6TboSGVXK9WWga1XTL81Tcpkw4mHQ2njRFnbE4+6a7gx+KMK/1dL0Zwz/`
      && `Qw69qIH/YsOnWORovftmFt1xkDQ2jJSU6LAZ7zY4FPBAhVhuxY0r8ooNY5UzN+qcO0damasQzWKnynKf2eH5KdmszGZd1lqiYqWp`
      && `qnmVPSipQM2sXLOflySmNDPOV68RhnPE19xAtG5T8M26zBDkRfdznyS5979EFGHOzFzNxl3kQClNiSY24cbXBB+vuTKAu0dUKGtV`
      && `VMs/Gza+Wm7bJXD37T0SdiFd50RG5agqeYiYxHM4C9yo+P2rCrQ5p5ienThvqPrmegZRLh3WTuZrKHlZtL8zoiLAsgxaDGtXeKbC`
      && `x80IibkdU/ghK8nZ04O6igHFv7mp5Vx8sTZHlw9pRcCMynkWp1BgQH6dzuBEzM64IkPKE3yfTE13H/oGCl+YdisnVvxT9HCl6I6a`
      && `ehG7Wg+BIom7psyp0D0fEt1PUhE1imGL2ZS6xoI7E0WRYcb9hHS2VvGdSqWzCpIMAtdZZH8P7D8TkQ812/1p0ugPgM8LZTnZlmJK`
      && `DSKwG4DvBwZVw5n6UeXjCbhjz62sYsKTBbdVZdMF0iHnWXNK8lvYAHspXs9RI6KHx3yPXh58vveScqFmrwZ+VeKpgkZvLMA8xT+/`
      && `o6gD/LMZv/nqHXvvefPmcIsW6uTjcHhEaGmQCX5Vml61CWWCjiFvPlR5WQgcjq4qJY1rl7xq7VT11fD5msEne7py+cmK61xatYLp`
      && `1wvGbg8NEk5ctjybR8RIa4bEOy/fnYtcNCcCFliWTZPD4pv2c3r7OLHvEiw1thuxpnIdrBBucpElmOUXexjJ53FGcFKhjS1Eh3Nk`
      && `vd9HR28wf58Z2yuMudAV65Ypq+9GwXxU+UBOUiriftW0pywIysuUprgNm2lc/1QYGiois2XgDxwk+cIngTQrPJ6vJ8tMyx+nbOtX`
      && `r8OGF5U0QHVrUZVI9JaPMGfQauHWbYA4xiRTLtYtoOrPk+nCbt7fhV0DztYkFX2mVrBWEKdn6NVwXiCUyltks2BpYLrznWFVIclg`
      && `qfc0nLO5h/gkzDSoaj/VwjZUCjDh9fKnRsvodCH1KY1zpA9WQqAHkRZDirPzd6RlNe+ahG5KlpUqIud+VsGUbC86YIlQ2mPrzbeu`
      && `95WWmQ0BHDt2ft18xpaHLlUOa3g0SmizU+X/5XZW5Zlii11vckG9xUP5hgtnYy2D6fE1Gzm8f9c553fw4KfZuPGpEHooD9cXX5Pp`
      && `Kg+zzqlO4pc3ovsJMQHLqh8LdQEqxstg3HwM6FvWNFe9a78ZHD9D/17v5Ez3DMym92hiOROTl3GA9zGrQVoaZi5NU+C7CUw9PLGQ`
      && `REpyU9uwXW1WrwuCcOUWV0grVYpeI16Qk/2QPKral84AhrCHzoGPXL4mk9JidyE8HvQGiesgFJbK3L2ahwTlkh1oBvgnM73BEe96`
      && `06Y1AGdsoxfQ3mF5q9CcBlbsGT0nZEgOh51J0EtNeVKTUy+7qNF+qLhPKky/QmaLHbca68gbyFlZuLCAsdvOP72rCotuPcypy1cD`
      && `Og52sCQXVvKQyvln82lFgeacnYr3mPLUS6QDvcL+I21Myrn/MDhhUBO6qnwq4GtVFGHeiPOJCZl4n5stBcMjZus3mV2yHbvsKqKn`
      && `fTdu67bwhUzDtTQh+fJn8DvuEXEU/L6ucog+tOoO1a1C9zcbGg5makrVItd0cotVaQ7Oi6xVcMUZNjIKURRYtKz8gs+dFgteQgNO`
      && `JfC+mbYOR+Z68tYLQ7QgJBqmPOS7mp0pNIYagJ00YxarofOZRPkLzbEaxJJla87rOeNrN+XnPGGhylNOWKn9PD8QxHzSyH52FaNS`
      && `Pn/VzqGwLaBRiQu6iUXnV5Qq6+WLR/LjSOuol/suCEp1/wWnQXMhT9eSypqKT9ZPzZZ677cuW7aF8fHx85rXqaMuP6sxgwvoqW9c`
      && `sxqV1NR62Oy89BCVtCj8HvZ7s9CKmoZ3Dlg38WSaIy0EmyUt7dEiFzJGJ5KOrl+xTMgOALf3jtkbO565mVZg9iP7OofWQmif2QsH`
      && `9zyAZKQyZgYbtI+dZEfnM0x1xki7LRR0jPlSQSFkq+e5AdZeuhkjb+mYX9zSqFgM0TOfcrSUvJd1USX+LDFLYM4eYpfRo1eEu9gR`
      && `Lib5VkNvMnGDGZG5Im4hYEmPDyzbBDM06eAvDf0qLt6V+JCmuOSmM/ewzS1N+a+1mjhQ3OtS7zCH2SIkd0Z5upEVqnQMmGXlbPOt`
      && `XlCHN8zMW+ZOrNRWsAXdoEYQYwuGnYoFaKgugL3XXMrk9nFObV/FqctXc+qKNZy6ZA2nLl+Y9qkwsePrCGHBuFe3CGcTk+dctrr5`
      && `fLJqWQu/G/j7EkvMxR+Tcx+1vKRh/vHctkiVTuVSSqXocRlMXrMOW2CW0PUwOEx8w1Ns4JW/zMCv/QGDb3grg7/xR7R++AUwMoq8`
      && `sj8ef2Af3Y9/AJ08BkkaSlKmuY/aKIKvnJXpRu120Kxzza+n/GFuvq0z5Ipg7GWaPo2lacEv5Qttuay+WEQh5pjEnDf7lxnpvb8x`
      && `stQrj+8/k0+o1+zyEMALfOLBOKIQuHRGyNYqYLPBt5yePG2NZpNV67ae9Rmr1m0JuddSDPZEsNW1fF5VCn2VW5LJAubaFiEgseDi`
      && `KUzDZHtHEdlSOR4bMONbgeXmbEFiXYXwvhG1mphxBbCFBQN2qiYY80iHE88ccAizGbMy270anJcRD0+IlL72yJH7xswcF17+2HOe`
      && `0Yp1KY2gDVyM2aWVxOJ5RN9KSlWSvNDFzM5gtu3tPbgVuKI9MItzjsbgyFnn9qjLrsTFEe3pzhLgemBxzjZ64ibKSFSYMzj4pO/8`
      && `YRLfnSLkN2e+46pZsVDyixsIPNGMFwCjAKvWb2FVz9ke3ruTw3t3cmjPDg7s2cmBvTtDy0gJF0eQOxpqe1Y53oq3JXOH4A/M5pSo`
      && `Z1EVFlwynaICfJ6iEzxxFZN1+LPgrc3o31lNPVX44MXj6JqNyByJMzdgPB30G0iPC0wmCwpfQKcp6G2IJD5pxtvM7Lcsjvdoro3S`
      && `lCU37T/7BCzN0gw1B2oXdL6qJ1RcNJn+sT6VDaUyTl22cv6Q5vjLxlMAW43ZKLl1vGZqLNWfjM/OhMTtgskoU5hK8lo5QSv1pqKe`
      && `/9RVE0xtH+f0lWuZvGqCU4vWsbazxwjNGS4Gvg3YlMvAJ3rmPnnFmpDu6twiTEurKkX1llGn2rOS2tI5GPACumjv+zLwqyLs7a2R`
      && `fYmzN8v4VI+JQ70ko4oYZ5KIyj3DkLdo3SZr/dRrrfVzv0Hju3+IePtjiDZfQLxxC275ClwU4XINN0nofuoj+Bu/BO0udJNC0y3P`
      && `L9NYncv6/np05ADK0leUYyvz+Z0qfxc7LA/tOfTgA0aa1jXJ3COfS2D5xRUmqZN63tmG31zfah58zymfOz2qBKz64HmBtw8FOkmS`
      && `+QbtELCvLmTlGzMvdn8xZj+0aHTR5mYzxnufRzjPg1XrNgOhfZxz7krQDxCircsnWK0se8XPgIFFafZjI00yLaQS8VYlanX0MeA6`
      && `M/uudrsTpWmazeXMYGb4dnc1sucAK1hY3KlCgtkDh/fuaIPtMzhM7z3PwzYLykxkZk8GnjC6ZiMnDx9i2eqJMz5gYvOjMKDjtdTg`
      && `h0L+7PzMo9pulFzLSkHRclGvXC61q5ej4VLge5uzA6tc5Pih576YsfGFJf3xVRs4fuwkV1x/CIMbzHi6mRVurCKcvsfebWbHwfbM`
      && `TE8xODiUAp8H7qHoKJJXE6ofT0YxRw1eauJ5iBHzhlKxcu3C+JfD6onNCKOTtnOOW9I6qxCBGncqTaRTnVbPNahkvCzQPiq/mmn5`
      && `6SJHOfvYGSotVz6fM7GzwEc3rePbFg1yvJNyREkzEs8y7HdM9rhqUk6JDOUa8/INmUB7zIy3xGZvwnGgu+cwRI6x2w5xLnCnT2fb`
      && `aNMSJ2t4aPV/SxOxXexxF3sXMXrXISYvGSvGm7xqLWbwks6HB5EeL2mEnG9YWUSxUn7RQG2PDns/l5YpSuXz6vw3p9gqDUYhEwZJ`
      && `pHGTkTgxh18cyV866Yd+3BO9xWPv8OKvvXitYr9MZix5/OPre4HHm8Ob2wS2oXa6FYGkjEMTmaX4dB0pF4CUfOGlsasYv9hp57FI`
      && `nzjW5bLl7a92zX7FwxcK71RNgbA6zpdEqqbLZJuVXRsjumAbA6/5FZrPeS62YlX4qPeFpKU8ujPXZNMEDh7AkiSLenY5s1UvgSiE`
      && `Ewn/wH3o8MFMYNYCVG8hIcQKZu0P7CW9+47McJVXcapoBhVTuiTzXknH8+7TKW9cg3vgtulZhubapLmjmh5pPdspT4IWbFZ/bohc`
      && `8A/Kc8zM7jLLGgNa7q3KmUcPD5aeALzci5VxFJOmnuWrN9Y+Mr5mC94bJodgi8GrgMvynVOJOFWen5cjzW286lio3W0+qVylYpDC`
      && `fF1e9kK7WAq8tNlsXu/itgHzBIVlE5thxdpsSRrB9DyMp1OYGsPoPeiY05STJm5fs+ECkI4Ady6IFLleGublwdaZ2StOH9h96fjy`
      && `DRgRGy96NHFjSfGNlWs34eImPk0QGjGz5wHPgtBXoWp9yQZXTznB8mYFwlJxXdaFyJplL3zjKcCL0zQd++hH3gcexnvOduXEZnDG`
      && `2IaV3PLZVZcBPw02geFL9o+VKlaO8JjEDkn7PvnBf6bT6SD5+4GPEmo995jKKzQiWEo8sFLwWtArZKzvnEwMg2Ur1rFq3QXFHEfW`
      && `rOclV93AsomNyIwfvnIdSTeZQLqMkApVkasXtC5lmCgYTupoWzdn9uZIFMpy/jmPw9eLpFU+Xjmqkj6YzJvOYYN+ygQcSzxzsuZy`
      && `i77Pid+SeHTAf1fRtnsOvf70owZvQfxBKp0gEY1VS3HOOH3FGk5fsZapK9cwdcVaTl+xlskr1jB55RpOX7mW09vXYItDS1wznTZj`
      && `n1GJ3awKUiVTlGCN4EdN6fipyyZw3YTJK1ajJ16GUs/QsJmMxwueIcp06nwgzUMSJs1sbztapMwlWDGkltRFBRrlk8tMU17INQEW`
      && `m3TlZNJ4QSL3Vo/9k7C3CnuesMuFWyXxTNB1vtvi1Je+yPFNAwCcvGINqRyR/ADSU8DWWO71rWBNEZeZNTyROJh4P9X1/uxBWCW9`
      && `E/meLFCb2LzEzi58/nCTf5hLv/T9rehXmsYbHVzTS3BLTm4qLkGBhRU+n0knNraM+LkvIrr2iVgUGsSU0cclfhV3CqA1QPydzyG9`
      && `/y78TV8sCiOQ40KOLqUQZJiRPPgA8Y2fx226IARSVS1XlQVUrWaFMJx60s9/Cr9nl3KLV1mQQeWCMmFYUjuRvee07NcvuKZ1v/3l`
      && `EX57SwMYwfuiGmbF7Fqu0acJ9hACjapw7MADrJrYzIE9O6bWbrzwqwanBEtUS8Gpagi5C8kGhX7cZE0v/6dm3NMYbHTXbLoAfMAs`
      && `lzo6pC2Fco2vBJ5JVuqyMMrOqxRj1UrKMkONNKspHEVQRMxlDKeYYqleFadr5kGPNvF6+cEhjE/NtKPptRu3ZuU8hEURS713glXO`
      && `uecK/RRo1Iq28+XNzWspF0K1dK/gThMQ2ut9RfA9FiJ6cyzLEN5RjccAe4LErx07uf/3nIu+0hDtlatXIFserI8OVqxaaz5N1zmz`
      && `HwFeAozlOxZuh5ULr1CiTHFyue7rcNBzT6v3r2LfDbY7YxHopYYb9mny5824uSNqRn7t+q2lcOtF4lzz1J7DjwVejfGEqg1D84Mb`
      && `8hl2gS9770+aGU95xqv43Gf/fHZuavp9ZnynhWYgqs1SlVmGFXqM1cBrkR7bWtb4F7w+F0VuH+omKyfWadBFtBXbvx3ZhzPXBCb+`
      && `6Za915rxXcD1mDXzdLuqdWteFLQ8B/fuZMm6ZUCr5oaq345a8U0ZoZd2VNAMR/UKlwdhBX2rH4+1IjMnc6xfvwXzoXJF6kIS7zXd`
      && `Ge6OWxye8kx54lHnnxV5+2XgArK2fLVwwUKOrj4aMLxhX3XoFtBWwHypIoTo8ToBqKLONMaDLmq007SLg9MY92K0zWjleei1/S2W`
      && `R+zRcww77nz6/2xw4MEY/MyxQxhueGZK3+Kx1wo25UkRxflYJUy+QDk7gLEvcsHxmuVd142TlUuTbUnxduRQStLy0o96+ElgA9ii`
      && `rGR9nnmQGbhtteBlUbO9K5qdu7W7eLlOXpGForVno7TVeorge4UGjGov4wUspyKR2HGy2541s/PrblUgGCXDyeU3Sa4rLBVsiuEH`
      && `W5HedMQ+9boV9ouR6Y0Y15YmkNxcn7Olmjm6eKfkpEb8uOtpXPdkiOLsQyWZVPWv6kVxDnfRo2h874+Q7N6BjhysCA6W30HLkoGK`
      && `wTQ9Q+f978Jtv5r40VdUdlHU4tGUazdB8pJEesctdD7wb2h2Ngs51DwcrCDStMQ7OuhNFww1dn70U7O8be0wL91xiPENK1Ao4JpH`
      && `0Zf3IWxLOtOZJLaB8zm6BWFq6ggTGy8C8Z8y7kdcXbmoKmzQuekjq+Ji2BIZL3DwGBdFH6Srz3u0F6kNDKdO6x1cK+kZyB6F0SgO`
      && `p1f/qjijqptkoNj5IKFGDiqVsOqbqfoLRQs3c6AnWDAHfXi45T/uU+7GmBYWk/rxVhRdgfR0mV0LtjhjcvVEkfwR5cw7ZnwSr8P7`
      && `9+xgy7bt6czM9BcNdoFto+TX82aZceSmoe8ELowj95GpublPIe2UZxbUNLHSObcd8e3ANWaMVOX5cvfyk5m3FyZkE5u2seueW4mb`
      && `rQX1nwXMoDnzW2HoZZg9ltje7VN9BTiCkeI1iNl6B98KfDuwDZUJXOVAlamFFxzGHuATzUaz0/Ud3vn217B24zbA32y4fxZsNRig`
      && `uPTzLD4VudBGDZ6JdC3GnVEcfQWzHWbRiXZgHIMOljlzW5AuBy4CWwIlLi9QBrkgI7lBBaAz7WxwOLdlVb5iFBHOPbsYytx2MyN0`
      && `lOlBWSxnuRjVRiwIEVwgF21uR7rd5NjUnrHDjcbQoPxwDJP/0hqZe0H7NA0fMYJdZl6/AHYRzmrzrzd9nQ+ZBHJ1Cm8BS7JpOVGE`
      && `jKYE/2puvc0Jncxs0jn3R0ln5h8Nl7ajuBtJtyFOCFtdw8v8ytc7X4xJvMxjj01c4/PCDuPcAHCJxBMEG8isspk9pabw5YiVvfJf`
      && `wAHvfZEIUSBeVc6v3ONCsHM4ix1KbEDwGInLyMJkiwyzYv75V3WDPH+QDoz8jZO/UdK0YUvSVusGwQuFXWhWYb5Wf3xmHTHEpJdu`
      && `nRha7Ftbt52bAQd8cR1gporAhUlAGu16mh540tEBPrG8y6tWSl92fOZb4HVOehPiGhUxCYXmUkPgikkyPMV7bPEY8ROehI0tK3ax`
      && `1KdVubI2f97miK5+PNEll6NPfpiaUlAIvxUzVGbC9jvvo/P2t2Ev/lnclm3kPoj5SK2M+Xr8vXfSfvufkuy8NyupVr3W+XMzIinm`
      && `nNnfmnNvXGTaf99sl8cMRzxtxz4et3ZT1oDVLTFjsLTfFA0ZvMTU+IYLdeDAPec6ujPC4OASkiQFuD+Kow+b6VKkRqW79bzsyIrm`
      && `0AIeg9nloBMmOwa0CX7eZcComWWMl5KvFbm+ubJqBX8vnyFJeOey6NHUsLiXKFf2tZxbb7czA21E9kKMHzDjMHnfXWOZYcsErRyL`
      && `SiZZxUCqOfAOeADsw3Gz0QHsUVd8q77y2fffac4+bsZWICpStwrvQSVYLKw1Ai4BLjL4MZkdNWPWRFOh0cMYoStTLvT2rKlAq8Kc`
      && `Usw12+0Vq9ax8+5bK3LDmelxTl8KjA1WjusRjzWzo8AJgt87P9sxshTKQoCuoLjRG+drKeKTgttSpaxrr+Vw5wE2XXQFd9/6+bb3`
      && `6d+b2XXAU3t3vyiMV56syuR5Wwq6DrNvAbqBkWT7K2KCYuHCEVrlNGCBSOTq/hSmzygpjV2ViRVEvHojsjfMcKS5pJ5lxxIxV6yi`
      && `+ux6zQNhXO6x1zc97xGa3NMcGAdt76AtMfzrNp+843PxYLuRzOKbjQtcqk1FB+d8arbAYc9HJBMsA1teVRRz5aZahqpkJoVnA4On`
      && `m4vfA0xF4XP/BdznYbXrfXh+k0pMFcaw4Fu9uE6h5K5TCFU3K9MXrP5XjZzmvb4/h2ZOeg30iuLFDSkLSFXlzCBReG+OVNMY9xDK`
      && `xQ7kSlKViRaXziz20vUmrgDbC3YaWCKxzhtDOZeoBRpXuJPKlKQ7Pbq17T2f/tyHz82AM6ydAjtQR8TcmmJbPLayjY6dFrznyDQb`
      && `VjS4Sg3dtdh94aJT+mUn/SbS46o7UMcQ6CGgYadXryG6YBvmHPKesltWmcNb1kKrZX2FnxctJrrkcpLPfgJTlyqJyGqFFYFOhVLt`
      && `PclnP2F+eprmDz6f+KprYGgkaNUVBu7l0elJ/Fe/SPsf/4rk1q8QEoSyjXdWZlyp6JjRTuBdCbx5wLHfOce6CN74wAkuWr+JjoeL`
      && `uontaDQuUcj/VEUEM6Btpv1JktCwJl0eUlpuAUcO7GHl2i24yOaQ3qXQ4/UKCppXFW7yrS10hFyUihArEONV5TFYbCrm7OL+5eKw`
      && `zaP85Q0DwKf5JUhTQt/IcvS6Ump1/boaBBTqF5qF6NnFUDg5VFVCrG5jqON+jrCiC3xQxu3dbhdA7//Ht/C4a7918sE9+96L+DYz`
      && `toTA70JjqKJ4Xh1HWY9sByy1ai5s6DFbIX+VRS4sAdbnm8k3HoXAwrr50GA+bayLwIEJZ2pHi5A6tq62ivDHl3nclTcL94DyTzrQ`
      && `HuB9I3F8YrLb5cHWPiS4/SsfJ46bSOw2423AVnqi0AumUXUw5LcgE2iy+9sEmrkNoMxFNZ+rhCW7XEAOMcs7MxTVrAAcMSa8UN4g`
      && `odAArDbJOrMqmsp3PWmCp+GOEszTpc+oar8ojYMt0LMETwY6GANgQ8LiFFzq9OG7hhbtPfrqxzL6R59zzsAX+U2lgVZl4Y/yIfMD`
      && `rDX/1fnIVWBR5VVJUR7gnARhY08URZ80uAaIKwbf+dhVeZCCjT4vH1qoLLVrU9EiKYk+Bv9lxudMIzrcfJBlc2uze2w9sRt121Gx`
      && `94EmWTrYSGy283mwfZhtrZCm+o6EwXMSs4gQHZ2/J1cVE+u4VRpoA/2ZNexDHc/BOIKn7zuPag7ywqd+Crif0DfUzIyQ0GWS2UUp`
      && `3LCqEUXHvXh1OsqV/3mAZQ62TEpvc4s+1cV+WXBjNZ1k3lXoPX8z3IqV2OIxtECR1KrRodzgUjjI33PrNmKtAeaT1/qJ50pmiALq`
      && `KPniZ5j77V+m8ye/g//8x9Gu+9Ch/fhD+/EP3EvyqQ/R/sM3MPc7v0zylS9A0ilxvpBICxOaCeYS+OfT3n5tYtAeOJCIsZv3MHjT`
      && `Pv5l8QRDBkeiJrviaL1HTxcarNoasiEPSdyLwczMw2O+ORzatwMDUp/eAfw56DicMQhTVSG2vAoZs80TwKyokl7Z7nmcON/vniMv`
      && `RUfzgXa6KBfNK2Vez7aoTMuwDH+KOxFm75Wbs42FSHFtp2v6iXGL0N/jdFppeGfdlsvYd+AQ8ukXQe8KHZ8ofAwUrDSMmY1aZ8vZ`
      && `nBT4Zs2waaUoUfl+tsY84KkcKDBGTEm3k7Oa+TafGnunNnotWLAyv8qfHsVK1bDrAjVKO6ASwb9L+uzpILRweM8DABzZ/yCrVy/B`
      && `OZOX/yjwNrCjuQIx7wTqJ1wcSs0VVVlQbr3I5pEbDCgik8vvKpPgcrnzVN5mTBZnNdjOMJHanAKZDcpA+fGBRSbELoKGVXmsMW/z`
      && `yOiEWCI0DrYIzDCHObcecysZHGXj89+ZmbZVlOOtTqbiPjdEJVuvxO76Hc0JXwU/jHKfqsJkhjteIQZ2ycAQg41mJzJ7X2R2Dzk/`
      && `qWJdId1WUy97t3Uh5lVZk1kePGsOThv2L/LpfYk6DKcD+Q2rbWbJPG3e8IEaIJemmNktzvgU5Dd7IXyyYk/ydDIzE84ql6A8w2KF`
      && `dUuombgF8f7Frbg7lwZR7ZwMOElSWsOtDuJm4Egemh8q1yChRSl64ZFO8oQBn7goI27fejBmhRkvTKf0xbZ9sgO/gPGfPSQhP+Ey`
      && `nbFCOENP31xJr5hBemMQ802qnXj23tAILm4swOBzep0ZIYuejkE9ssiJw/vV+dd3MPNrr2bm517C9OteyszrXsrMz79E7V//OXXf`
      && `907SwwezgSykVnsfhJYsB9h7mfea8eJvOtjrtwza/beeFutaYQ2PWr+VyHuOEtMiXZYYP+nFE3qxJpv+VyV2P6S6gWeBmZk54jhO`
      && `BO8C/hmpXWV2PVBJ2s72qziU+cSklhdQ1b9qLCjf++qxWOSSOIjIoaWhimdb5VmW6665sKUKbszfu5qldP6+Zm/WeUwmOB0QvCX1`
      && `/mbfzSqeAXt23Mav/82HiBuNKUl/AXwSQnKkspzECktSUHGtNodCa5fmTS5ft2VyXKVQ2PyJl+yVj737r1Dk5qu8lQdYIRNm1ozC`
      && `u7DQJVkYGaoO82LeVaoOn0P+TxtRdHJseJjDPS0Y9+49zszMaZxFsxJ/DXobWV668krA89ifVWdV+1MRWIqQ5JpaVQnTza0owUtr`
      && `hkgJrTPfPzQy0Fm3+WKGmmOl9akXKypG2gzzzMAJK2zYx47uzKwEuhPYXUX+gr5VLQjlCj2h427OSuXFeCLWM/4KTKp0UsvHsyJl`
      && `qk79Kwy/14RSFCGpS6O9rSKNyr2wIsjCnMGX9+0gVUrk09tN+jPEsdLV2HNCtadXqlNUw6fnb0dNzzIsNbMPOvRO5xpJww2w5sa5`
      && `+eWSi2ErqrjVH+69N+ukeHHKjH8w9EBVQK5tcUWjsAqGWe9naoFGtdk44IiMv5rF3zXjxXirBXAeQVgS3bkuwE1m7jZgTT7DLBpZ`
      && `gu1Cv3HaorcOwMev3njR8RVxpOfu7RJbzN89ZpF/5117P/nUIfdLzvhNiauUFy9fCBEzBPKddtZUuv7+vFVanXjUiM/sDCRdTPWS`
      && `gvnaKv9gpdyci7TgvXTyhPkTx8GrrK/pXCaguir9qx2UBKR+JpX/hy72mxNxuve5949w7LRjaom4YfUWDhORkDZjs81d7AWSfsyM`
      && `EVWxR0VT948gTX6d+C8+TenMzDG4ZORod7b9x2a2FvgOgq+y2l2kKkr3aqMVntFzyckVZtoE81RU+0btZqo4gdR7iIxuOkArdKWu`
      && `723xwEwyrY5TMZbX7UmqXyTmX9riBIMq44ROAX8m6b2xc2mSphzZt6v4/Ot+8AZc5Dh4auf9q5dseZNhy0FXo9JuWhm7Mpu6jpav`
      && `X8WO5d8RhMhSkdVxq5J/cl23vi05vhR5ZXUaVJeAyW3X9My55v20Yl+rS8qZW+Heym4N6FaJ37LZ9I7ugHF8amoe7h3etzPkaYdz`
      && `OSH0xyZawl4ILKMsw1e5ztXs8Zx5LFyTu1hlD0PJDSAqPf9TwL9j9lbMf2V2Zg55mCNEhhXqQK5sV/hW2BkBuPyyuB6VRvg9hvsk`
      && `cAmUZmirHXWlNKuVv+fbLBhJvDZ+5+2vjDa96yupV7XxbgWB6mymsgeVsy8yM8pTzEew6oWu3pvK8Ll+JODavXByWYKPGl2T3mnw`
      && `aEk/LmhZ1SXRi3N2hqKV9UvZi5YOuNXgj2ajxv5BnzCdnqx8uBT2C721tyJjOb7L0cecMOnLYP9g4jUyDVklpmRe0Zb8tapuMR8q`
      && `4TQ4pA7YOxPxntgsEWLndKhDc04GfOTQblasXoekfc3mwLswrgFbXGxQsTR7vIdNs/CFOaWfP9hO9ntTaiSsuXHWvJpqTDl70Yi/`
      && `7dmt5OJ1kYazfoAhdqU8aCvO/dhRNDWJWzaei8WF9tsrL4UYsxy5ss03w+/fg9pzGU+va2EV+ahcSpUsVrJIhIlo/nZXTR3V6HnM`
      && `0TVnN6bx4XfMuQc/23XXmDBGUajpA5LMlIwKHmXePwGzSwn1agvJoHLOX5T8J+NGpNnp2XMd23nB5IkDrFy9kbnJaaZmpu9avGTJ`
      && `rxo0gKcQapVWy4JVb219D4qA9qoqa0hyoF1gnwWeQSCs9So9+YnnnEWWEHlkkAx6DYR09HOJHAZMyrgPeBQwnGNTXpu9wJGFDq/3`
      && `jgX/5SmDPxP8iTmmSB1H9tf7IB/ev4uNF17CancBM3MznxluDb4BeKPQZZQabIlBlQfPU+xU8rhsKxyw34ydwOVmNtyLv/maMhLr`
      && `AHvac15YzfyzuvZcMNOS54co+CHQOnpqeNbvWDg3zadHecZ+/uvtiF/vJsknmoMxrbjB7l0LBwwe3BO04pUTW4kiO+K9vdmZDgEv`
      && `BfIE7gpvyPBmvv9iHjL0/NwTe4wDEuBe4O2gd8RxvD/rP40ZtKIpLOsGUhNdzHpYSsCYgnlVUhflRRy7Ge95J/AkYLsgb2dfjFIz`
      && `l1J7Wr71DQ8XHndRa+DvvzBTFvewfP+rVpBqt5zeeIIaqBilQrcqXCqvnS8rEBTMrFpvMWjMnq73hyPn3mJonJB+GM1/bJXDLkBL`
      && `VUHYIHsSchtkDtsB/G6S8qWWS4mHI8Y/c7JYSD2HsK6i1eh89rKzbN8c+MTNmuOvEBcivldGbJnVLec56rm/BSrO19xzo0EeF98R`
      && `vDuV//1li4aOMjyIffC24gvnlYY0MDCE9977NPl3c9ENoB+kzO8sEECwWuJ7QN8h1FXIEA1oaZh3pr+Ya0QPKGq9ciT1G1wa0nsq`
      && `WFKkGZmRHtxHuuM+3IYtwW5QYwK95CxrtGBlLQCdniS94xbU7ZD3F8oPYwF8W0A56JG7KwJnnmqUv58PkBPJLp4PtE1vm43X7k3t`
      && `512OzhWZRQZeig2aElH2pF7Vycl4APjzZPr0gwwtYnBomK8XHDqwi1UTmxkdXczFm+2WO3fqtQavQDwbWBFE5LxYR9nTqHJHi8Pv`
      && `DQE0szskvRnjKNiTUCVeqvLB7MOQYUNqgUKe9p4RV1j56rfM8uMpMPAU8IfA45B+jBB45fNv5CUGqdyOCtJRirMShP320l+aOBLq`
      && `iy9M8Y8dOcLyFSvBy3dT/8E4cjPAzwLXG4yQMbUybKkSElRo5eVqUJ4YbTsx/S4hReRi8rF6CEkYtZg7+3ffl+UBl2J6FnE+n+aF`
      && `SX0W+ArwMsJzXOVAKedbVanq7Cx7p43xeeC3uqn/VCOOk0azxeTU5HlgoUhSiI1jPtWfmrO7gZdjPMFgNDuu8NTiDubzObNgWHsx`
      && `s2tnmtlesP8A/R3iRpx1ut1Q2Obgnh2sWb+FDa3D7NWEVK30Qw/yVh+h6p4FaA016Mx1wesmnHubxOuBNaFgZbmf1Qx0ZWUKrBwX`
      && `wHm44LRzi7bcuXtGA7nhUBX0L4lWr4Gp58xzw27NtmAVmpfLwsXXy+XXtWdg8S0HOHXlBHEU0fG6K4b/A3Tk9Z0yhsH8vASFM/xa`
      && `luYuNCQzkzfsdqHf8aneEzuXjAw3ObH79LwjrlpIzHreyvlK9r43K3w73nlaNB7s4t+QffTZklq5vNnb+aye6LWwJm+SM3FK8E6P`
      && `vWnZYLxz34lp2ofr9+G8WurseeAevPc04vgw0h8SSsmpODcVZ5rT45aZjZizUTMbdeYWmdmIYFHXa+hjc+beMuV4ILEQ6ZqmJi9T`
      && `3n6IzMR78gTp5z+BTh7v2cwcL+pBD7mWG6IPPMmtX1Vy200hwiXXBEIwqqls/14Zj+oNq2WyV/HiTIgd9BCjY8YH2o4/no7YkxCb`
      && `NCQYJrSgGiEQ0xHDRgwbAHOU+YLlWkJaxAnQ25A+Eg+PShJ7dz/8FKSF4GDmn7v93i6jQ6N3Ar8C/AKBOM8Gr6byLiV51nslfacQ`
      && `+nLvyCmCX/kVXfl/AE5Z0DhQoBBWfKn4k5kuJLq5X/TAcSwEPORhR2XMelFdvgjs65q4X+I3wH4buBvLNbpCDwqF+LK/K26L/PnH`
      && `gX8FftpLbzU4kp/7gT33L7h3p08c5uTkCRIvnLPkwNTej5vxCsN+R3AHYd0ZwczJW28tw0BFM3yelNmHzXiNT/SXEocQaYUylX9C`
      && `KdOcA7Ux0uNH9uOiSJj5eg0cVf7OTi8g/IykfyIUTvlXhdSjfOxwYYq67YUJMZ+DUxAw7gX+AHhFe2b641EUJanE7Ow0Jw6fuah/`
      && `Dof27mDm9AnSUKN87uChBz8I+hmD1wOfkzFN7uUso3xz8a/nFpegIvtAhtHFbKfgrwUvE/qFZmvg86lPO/KeCMfBPTuyPTJmNAh5`
      && `kk9QEjMRnqIPi0ruHwLVilsRYHaqkwumHaR/Ar0J2F3w3XzqhVbf07A+8+1acHWNJRYNpjJSEXsvJynQTS9TCLiyvHZ6UUM9W3/5`
      && `J9y//A6a5Xco+9P7nez1IDmGi1PIJBksvmkvkogkBk13IH7B0B848UBFR6/EMOWYqELbzUT8fP1mkjM0aeLfQK/seP8uM5vrpp7j`
      && `J2dZ/kBZMjP/DtUc4kBLsj3wxbZadnaJl3mJJV/dT5qKXYdOsPjJF90l3C857G3O2J/f2ZKEVO5BgXlWiyMKHzXvjPsMflvwq0uH`
      && `dP+DU10akWPL3fVSn+elAefQSVJmT5y4eXjp0l/F7A3Atdmig5RfBMr8f+2da5AlZ3nff8/7dp85c9uZ2Zmd2dnZm3YXECAQQiRR`
      && `YowxVS4KU2UqBbGr7PDFKagkNo7tVBGoJAQDrqRiOXZiy0UCKRPrA7ZlUMlAggrbQEFQCqEbWq20q11Juzuzc9ud++2c7n6ffOju`
      && `c/rMrtBKSDu74vlVbc3sOWd6unu6+3mf2/8p74DyS7njxXYUvr4BITh+uw6HnZKVz6jS2SzC0tkD3yR72x3Iz/0CeN8uwNJKa53Q`
      && `8ToiZFNTJPf+OWHuQsVramsltIyHbt/X7aHK1gpnexyi46UyVJGocn/D8ccbXiaD5G5tsZnKhL9CN6J0YS7rZC7fWQA+q4H/ieTi`
      && `9TNXOTT9xTIzeYbRicOcmz3LUP/QXCPjC7HjO054N8jPAWQEFBUAABT4SURBVG9EGSGvzvbkuY3yUkyBBsicwKOKfhXV+7v6e6dZ`
      && `30RgSpXvIxpXbI9UvpQ9ZqcVTvbHXhvNlIkjo4QkPS3iHkF4nbBNp6/1HFCA7ytMeyezaSp/6BzfQfUfF573YYTe4npv+01CArIB`
      && `zCA8jPJVVf3WWG/39OzGFl1xxHNnnnrBc7c4MwnAvkOvYbRnLyrutITsTpD7FX5BhJ9V9Aj5yMMY8FKEFDRvl9oq/taPA/cB9wfn`
      && `zrpIVFWfFPQBhbdIayxhsVgp6zlhC9XvOifrqrnMnnfF47zDpbjS2lEQSKLY/12zmT4l8B6ED5D3Kw+pUhPB54vBfDQKSqLCquTF`
      && `Rd9SuA8Nj3oXrUdddZxrG7MXoHU7rC0vsLa8wL6DxxgZHkecO6Mh3IXI18hbc94N3IoyCtRV1YNccbxBcVEU1ySXgKdR/q+KfgPl`
      && `eL0WLzWSlLmZKaIoYnWpcxSdhsCiG0ZVzwg8gvC6SmVBufAorztV1R8AcxUXBIC56fxeHd9/BGAF5X8gnEP4MOgdRTLKtWIVl0cz`
      && `gyobzslU7OS+OuHS791+lJkTTy2IsKTQ1VkI3hEz3batjvut+K7w3JVWBq26H2Wgr7hSEZUE4Xymobn9nA8+MsXCrftYzaDLuWcb`
      && `IftPkeM7TvRXQN6BsBeol9411a+dD9ZMhEWE48BfqvLX/f29k6vr68Te0f/9c5f9vZ0ImeiGIPMKR6vNzMXavTxGJyIboDNJyJLY`
      && `5eZvz2MznD06wsxXn6DWHT8r8CmQ7zn0g6D/EGQ3qlHbVlRFpMokBCrQRGRaRL6JcLdm8kBPzNaXzzT4B6MxY49OPu8NcFXsP/xa`
      && `NMvYWF2W7v6B2xH57eLG2E1lJdru122f45apkvyEKRA74edrGb/Rm7Lfa65+pJW0WbFc8sdupv4vPkp0x0+jca1YNF6uNFUa4TB7`
      && `gcYX/oTmfX+purXZvpyLT3ZYgO0h6HbxIe2wZCXenz85L3NglLyr/OtNzx+ve86m+Tzl9t1RmT/cOlHaDg/mh1uuuDKBJwX9XAjh`
      && `buejxTRNmK0UAL2SHDjyBtI0wTlHkiTOOzckwmtA3gDF+DrV3uLGWRe4SK4IdRzVk42QLHbHXRpCKK6B4ET8QdBDCq5IJRSrYimN`
      && `SKaqsxCeFZFkazOhq14jBI29d0cRGS+MTivLkJufAEKmQc8lafO8d3Hwcd6znWVaF3E3SS4a8lpVHSWfTgQia6jOqshp4ISonglZ`
      && `WI3iSLMQiGsxG2sbXJo996LO3b4DR/JIuosQJ6RZVnPi94K+XvLzdwB0QJUaQiKwpLkhO64ajqMy77wLqkqWpCDixbuDAvuEfPBB`
      && `URNXXqQZ6IbAmVq9a2lrq4GiziH/HORO0Hr7Bsn/HG3nEUDuUvTjwLqIkKXBiZNREW6WXOHrIOhu8mH2qeTRjQvkEYYnVXWy5qWR`
      && `qpBmGU7kao1v+2bY5sHunbiJLE2Ju7ryc5ioc44hEbkZ9DbN8/wT5M+dXcVACEU1AVZRnVc4p/A0qk+o6tOiXIxqtSRoIGSBek+d`
      && `tZU1Ls6cvWyndg+P09XdjarG4twREdmnqGsvxNW3rkK0Cfp00DApiEpQZqYv3+b4xAGQmDTblDjuOQDyLuBnQI+BFPcTjrzVc13y`
      && `BdkZ0EdikQf6hSd+ePbMugDnbp0YrKu+V+CIOBEnkvdgqIbSA9FinDttO1rIlbYKpqFof5NW83o5vb4VB1REcPnrDmVFRL62kK2c`
      && `7KPO2PH5y45z/s17aWjGLlejf1cvC6urg5F3bxaVnwJuU+WwoiMKPaKaz23NlfRWEZlB5ESeytAH0iDn616zrUypxY5Tz63y9y5e`
      && `ntJYvn0/WZrF3rt3BuUOVB1CMdNFXBncFvCIXEL0a7t6+56dmp9j/4nF9nZuO4hqXkiXRghJtscJ/0iUd6rwJpQJVAeAWvEsz1S0`
      && `IXnU6BmQh4Jz306RxwbSbHnLO07Mb+IE/v65K88bflEGuG/XCL09dcRFxL3dhK1kQkXeC/p+hbeK6iDgO6psWvrHlV9a6Z2KgffW`
      && `Uj7SH5iIVEO7xr4jHusPHqP2Tz6If9e7keGxfMACUs5NyI1+s0E4eZzknrtp/N3X0Y31zvVx265e5hF0/NZWvJrOXJcIlfRatbFO`
      && `miryt1vCf9uIORtaS+T2Vrf1wFZtPLRWoYnAec2rnb+I6oPAlo88jUaDuekXZwxeKrtG9jK6ey9rG6uEkOG9BxHGx0eYPD8dibgu`
      && `VYmLTptEM2nsPTySXrywRAj5qDIvEeKFkGWoBpyLysPsyOVXW8q05dBBFhTnHBq09fvLx0K7TkOLLC9oUJKkifMR89OvZ+/+00CG`
      && `iOCdY3Or6SMvtUK4AVSTNEsbfYPDWWNzHQlFBLFYNMxexWD6H8Xeg0eLAKYi4nDOcWn2kgwMDtTEUVOHy2XUtLm8stDcvXtUg4aO`
      && `VHN5L4jv1GHfXlhVel59vb2sbWxALgH5YeD3Balr5/VeCRoowF0B/bjAesi0DHsiAp//4mn+2S8eiYEagi8ikM2N1UZzYLivjOWj`
      && `OGbPP/2yX4f7Dr0WJRDSXK048hGT50/K6N7D3c65PhH6Vehz4iJUgmpIgE1FlzXo6szkM419B4+Rhfy8SuRYXrqIc571Mq11BcYm`
      && `bmrdluJ8WVBYcQ3bvcWl3xFChoh73kXy+IEjpGk+eyKOu1iaXJXBif5dIoySFycOkldJb4GsOGUxIszvXltYubRrjz537gw4DyFD`
      && `bz8E37ifv377T7u9DvFF8Dkj00yVepFEbqSCJ+Cc0FW8XoxLJ3jHViaaCngyXBAR58myFAn5zzQFFYmoCxKFwNpWQ28eGQtTK0v0`
      && `12rsefzKk5P+3839PJKs8r6uUeKap+YdaxuJ7+mKh5wwqsKoogOREmeqIWhYl8BiwM01VOfGP/tLGxd/7S8QHKnm2bmxHz5/KmP5`
      && `bQdoNJrsOXaM00+dcCFyomQqQfAiSOxRr7hGxtxaU18/PKi7eno5Pz/HwSeXOrZ16bYJsjzdSppljHT3Mr+52h07PyrKuKqOOujx`
      && `IhpUkwzWRZhPlQtrzfTiSG89XU+VoW7HyUvLTPT3s/sH559331+UAW7dGPuPEtIE31WHpOnV+wmFtwnyU4K+UUXGtKziz6/Y3HS1`
      && `xIAkz4GTP6O6Rd0He7LoQ/0M9aEDIbTyIaqhKL/IMqR/F9HtdxC96z34m29BBneD97C1ic5OkT34XdJv/w3p6VP5/N/WE79ytEpH`
      && `vFcqb5SBi1YsBtqJe9FOY1F6wk4EkeaDTZn7jyuueSLR4EFFnLRSZfnPhdJoFF5+2QGfIrIo8JzAY6APoPoEUW1ZkzzSc2FbD+VO`
      && `MLQnF0WqdUW0Gu+K6DHqaG41OXjTm3nsof+907vawcj4TWQKsauupfJ4W9DA2vIiu4ZGWnnwV4LB4QnW19cZGBggivKFCK6dO8pC`
      && `RldXF1PP/fhGbO+BowTF+XyG7h8I0p3Hx6TV9l7JuwhwF/AxYH36fPsc7D94M1vNNbwvhghV7E3IlK21LWrdNRYuXptFYX1wN6f/`
      && `10O8+cNvJ45q+XSzMiJVDj8JZX4978FvNpr8/AfexT1f+BrNrYUfbwdeRiYOHiNpZES1XOStbGlUKUo10wSnudRcnDZo1Po4d+4U`
      && `AO8b7ea+uU3+6uYRjsYRvZJX9HpolTyUifkkFCMhBHxe5dkKLKoIaZEqdflseEQcIYRinnQu2Sbi8nxTULIskGa5cT588urP58pb`
      && `D9BIUuJC1K7LeUQ0H+WX5VqUTQ1shdz9X95sIsBrT1+66t8xdcseIF/QZ64sYsj3X3yx6sgCWQYTvwzy8bkX3ObkrWMkqvR5TySO`
      && `GKHHO6ToD2k0FCewGTJShUYW+JuzS7x9YhdHnnzh7cNLNMAA43sP0Fyapb7nAHjP/vlTTA0e6VKhH5FB0G5aaU5xrgh/KBochEhE`
      && `Iwc+z8y61/ksunMg3DGk2b8m6CHK6rkyKSHkShciuJ4+ZHhPYYAj2FyHhXl0ZYmQJIWsdlEs0BFj7ogCd7zQKb9YiTBXtXk6NgXF`
      && `gy3JnLvny1vR5//rqq6kWW5nnXMi4gjiCflqSUPhMYQyEaqoEhJUVlCWnJMtXJSpZvkCJ4qZPHfl4h/DuBLjB44S8ijarwJ/ILmO`
      && `87ZsRys/JMCfKPwb2WaAjWvDgfGjrC7O0t03gJOAbzZwjSYaec6uLe/07r3sJG89whPZJYalTrc6UgksZE0eWtpAgH96vrHTu3hF`
      && `nrhlNxlKr0bU8NSdIE65mDaZbyT0RZ7bnlp60dt9UUVYVaZncrd6QpRsc5Pzu48gmTYQGkVOkMvivVTyrtAKq3lRjnmlV5PHk4zE`
      && `q/47J24CkVDGTBRBxedKMBvrsLaGPvsMgBazfrfpkBSr46pYefXt4v2OQtii8KslELJtx4t6qSLiF4SgjUzcVzaUzxyK5amaKEFy`
      && `bcFWdHrbv9IBqSi1tBKaikBIaG6u4+OaGV/jRaOaq7A55zxF9UmrbULLIS8ved1tvMycn87z5Utbaz/mlm4M4ofLRd6Ntbh44/FX`
      && `JoLykg1wydS5l2fV/KE37KOmbM2p3j3snReRj4Hs13Z5vxbyh7TCur6Ir5TWrCh82173lf+vUzy34+t2P7kSki6nsrQEWYpVg+Ca`
      && `QcKX0qC/cyjm1NL6Ju9bbfKpS1dOthvGNUG2Z1ikdSV3KlG3L34zx4axM1xVH/C14Gcj+GYKQ5FfT7z7U3HudwUmi360quwltCqu`
      && `2w+bauV16xOF71xpVqV8tdXBV/l41XKXL2pr6x2x5wSRe9T5TwzW41NPJ4FD9ciMr7HjtBImQmg3TbcaqCkLttrtCoS8KdTMsGFc`
      && `a64bA3zLDy9wq1N6ap6a6kYT/TNF/zPKBdWiqDh/unRE0Kp9Za3ur+LDRWt5aypIkRbuqF7MqeR42ynf4q0Ot4G81UG+kuI+M9gf`
      && `n+l58Cx9aeCLs4sYxs6jODKgHEbQKZogVZMs5Q112QLTMIxrwI8dgn45OfbYDACnbhthxNU3ErI/jcXHwEdVdQwkdMSFoaJNR2dP`
      && `b+ubsk+pbIHpHCTepvLD26QiyuyvQhPlvgz9D3tq+tS5Sw2+Ve9j3xMXdvrUGQZQ1EoEh3Otolda5QYdC8vSDS7yK+YBG8Y157rx`
      && `gKsMSMzFdIuYaK2Jfl5zCbfpUpKzMgyG7ZOQO6bRafXDFWe2wwPe7glfJhhDEYveQvmLTPi3u13Xk1PNwEB3zDt/QoonjBuDXDM9`
      && `ADgplQalLDisFD9UbosXmG1gGMYrxHVpgMcenqZfIgIOr6wkIfscQe8U1en2PrcywlWJi7YuJ+2ItVY829YDqaNUpYzGlanltkx0`
      && `kYNuAl9SJ5/cE9We/uTFMyAZp1ZvrEo+49VPWQWdT1Mq66uK+6Gq4FEIyFjy1zB2jusqBF1l/NE8HH3+9cN012urIcs+5yUShY8i`
      && `jKoWY72K6SFlOE0q2azOqmcpJUFbVNuC2mOdqu8igmaI/J8M/bRTeeZMY4NDrpv9D0/v9CkyjOehWJiWymHFa9WWekrpQfC6rdLB`
      && `MIxrw3XpAVep+YjNJMGJX81EPyfo74syT9tfbbUI5c+bzvxuy/YWcx6k450fufyXXOeVezP49yNxz8mGBkZ8zIeefXnm8RrGK0GS`
      && `bCm5Pu1mcdE7FRy5PrBTLSbpQAq6TAjZNm1LwzCuAdetB1wydnyWubeMgfe4EFYyzf67d9455DeDMpYr31Oq5VXErNqhtrIIpTU3`
      && `uFX13C7HKr3hwk9w5JNUvpyJfnKke9+ph1dOM+q7eTC7mvmmhrEzqCrd3QMaQvYdEX4PdTepqINWo7zm4nMI6AKq96TLlzbjweGd`
      && `3nXD+Injhoo8Td6yh95ajUwZiIRfU9XfUpURckn+dkFn5djak1/ab+bR5pb3q+X3Wgp5iKQoX1LRT0RETy+HTRazJm95fGmnT4Fh`
      && `/EjGJg6TZYH3v/8d3Hvv97qck652Xx7lcN9cTEZJGpMrm/HeHsQLM9do2pZhGDk3lAGeu3UviQZ64oggOuiC+5covxWU4VI9ozqv`
      && `u/VlW3itFCPP32tPNSpGDKeK3BvgE5HzJ5uhSeyjHznRwjCuJ0b3HUZVcc4jrj1FKkc6bg7N8gDSzIVnd3q3DeMnjhvKAANcvG0f`
      && `3b1Kc9ORKUMePqLKRwIMo+0yqmpD0eUDDkt9aVoSWkUhSkOQezPV3xn5lfecPPFf7mZ03x7mL0zxhpmdPnLDMAzj1cQNZ4BLZt62`
      && `l1rwBNEhp/LrqPyrgA6L5jO5WpOUqsdZajpvdwpQQbUB8ueKfCqu155ZWVxhZXmNN85en9M5DMMwjBsbv9M78FL52PguEqfU1G8F`
      && `eNzlwzBvBXqgc+pSZRSRcJnxRcjDzl9W5ZOi+kzSTOjqqnHojMlLGoZhGK8M130b0vMx8tAFvAoDD59HYBHRuwT+CHSBfCZ1u7yZ`
      && `/BulPddB29MbmiBfDcinR9505MypqXl85Bl+dGqnD9EwDMN4FXPDhqCrXLptDJEIVd0N/CYqvw4yhGgoY89Vieiy2hm0KfClgHxm`
      && `pN7z5HOLi5y9cJF3mrqkYRiG8Qpz3fcBXw2CI2iKk2ghQ//Q52K4v4HKIKDaUQVdKFypNkG+GJx+2jt5Zn5zg6G+fm5as5GChmEY`
      && `xivPDRuCrrL7kVwiOqRbeGQBkT8S4bMiuiSCk5b8c6E3qZoE5V5FPyOBZ5pJRt3HnF2b3OlDMQzDMH5CeFWEoKvM3j5BDUeG7ong`
      && `I8CvquqYKr5Qql/NVL6SqP5uX+SfWk5SDjxhPUaGYRjGteVVEYKu4hGaKDXV+US508MDGvRnQMdQXVXlB5nqN8b7uqen1zbpi2/Y`
      && `QnDDMAzjBuZV5wEDzN++n1SEOAsM1SNOLG3G3ZGrhSykr3nHmxpz3z3BahYYiD3fnlzhAwtWdWUYhmFcW16VBrjk+Ov2sNnM2NUd`
      && `E3uBEPje8gbvHuplz+OzO717hmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEY`
      && `hmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEYhmEY`
      && `hmEYhmEYNxT/HxYtHYqISS96AAAAAElFTkSuQmCC`.
  ENDMETHOD.

  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:core`   v = `sap.ui.core`
            )->a( n = `xmlns:f`      v = `sap.f`
            )->a( n = `xmlns:card`   v = `sap.f.cards`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%` ).

    " the header is an overflow toolbar: on a narrow screen the buttons move
    " into its menu, the title stays
    DATA(page) = view->ele( `Page` ).
    DATA(header_content) = page->ele( `customHeader` )->ele( `OverflowToolbar` ).
    header_content->ele( `Image`
        )->a( n = `src`        v = project_logo( )
        )->a( n = `alt`        v = `abapGit2UI5`
        )->a( n = `tooltip`    v = `abapGit2UI5 - abapGit in the browser`
        )->a( n = `width`      v = `9rem`
        )->a( n = `class`      v = `ag2ui5ProjectLogo`
        )->a( n = `decorative` v = `false`
        )->ele( `layoutData`
            )->tag( `OverflowToolbarLayoutData`
                )->a( n = `priority` v = `Low` ).
    header_content->ele( `Title`
        )->a( n = `text`  v = `Repositories`
        )->a( n = `level` v = `H2`
        )->ele( `layoutData`
            )->tag( `OverflowToolbarLayoutData`
                )->a( n = `priority`   v = `NeverOverflow`
                )->a( n = `shrinkable` v = `false` ).
    header_content->tag( `ToolbarSpacer` ).
    header_content->ele( `OverflowToolbarToggleButton`
        )->a( n = `text`    v = `Favorites only`
        )->a( n = `icon`    v = `sap-icon://favorite`
        )->a( n = `tooltip` v = `Favorites only`
        )->a( n = `pressed` v = client->_bind( mv_favorites_only )
        )->a( n = `press`   v = client->_event( val = `FAVORITES_FILTER` arg = `${$parameters>/pressed}` )
        )->ele( `layoutData`
            )->tag( `OverflowToolbarLayoutData`
                )->a( n = `priority` v = `Low` ).
    header_content->tag( `Button`
        )->a( n = `text`  v = `New repository`
        )->a( n = `icon`  v = `sap-icon://add`
        )->a( n = `press` v = client->_event( `NEW` ) ).
    " icon only in the bar, with its text in the overflow menu
    header_content->tag( `OverflowToolbarButton`
        )->a( n = `icon`    v = `sap-icon://refresh`
        )->a( n = `text`    v = `Refresh`
        )->a( n = `tooltip` v = `Refresh`
        )->a( n = `press`   v = client->_event( `REFRESH` ) ).

    page->ele( `subHeader`
        )->ele( `Toolbar`
            )->tag( `SearchField`
                )->a( n = `id`          v = `search`
                )->a( n = `value`       v = client->_bind( mv_search )
                )->a( n = `placeholder` v = `Search name, package, URL or label`
                )->a( n = `search`      v = client->_event( `SEARCH` )
            )->ele( `SegmentedButton`
                )->a( n = `selectedKey`     v = client->_bind( mv_layout )
                )->a( n = `selectionChange` v = client->_event( `LAYOUT` )
                )->ele( `items`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`     v = `LIST`
                        )->a( n = `icon`    v = `sap-icon://list`
                        )->a( n = `tooltip` v = `List`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`     v = `TILES`
                        )->a( n = `icon`    v = `sap-icon://grid`
                        )->a( n = `tooltip` v = `Tiles` ).

    " both layouts are in the view; the toggle only switches which one shows
    DATA(content) = page->ele( `content` ).
    content->tag( n = `HTML` ns = `core`
        )->a( n = `content` v = labels_css( ) ).
    DATA(table) = content->ele( `Table`
        )->a( n = `items`      v = client->_bind( mt_repos )
        )->a( n = `noDataText` v = `No repositories found`
        )->a( n = `visible`    v = |\{= $\{{ client->_bind( val = mv_layout path = abap_true ) }\} === 'LIST' && !$\{{ client->_bind( val = mv_empty path = abap_true ) }\} \}| ).

    DATA(columns) = table->ele( `columns` ).
    columns->ele( `Column`
        )->a( n = `width` v = `3rem`
        )->tag( n = `Icon` ns = `core`
            )->a( n = `src` v = `sap-icon://favorite`
            )->a( n = `tooltip` v = `Favorite` ).
    columns->ele( `Column`
        )->tag( `Text`
            )->a( n = `text` v = `Name` ).
    columns->ele( `Column`
        )->a( n = `minScreenWidth` v = `Tablet`
        )->a( n = `demandPopin`    v = `true`
        )->tag( `Text`
            )->a( n = `text` v = `Package` ).
    columns->ele( `Column`
        )->a( n = `minScreenWidth` v = `Desktop`
        )->a( n = `demandPopin`    v = `true`
        )->tag( `Text`
            )->a( n = `text` v = `URL` ).
    columns->ele( `Column`
        )->a( n = `minScreenWidth` v = `Tablet`
        )->a( n = `demandPopin`    v = `true`
        )->tag( `Text`
            )->a( n = `text` v = `Reference` ).
    columns->ele( `Column`
        )->a( n = `minScreenWidth` v = `Desktop`
        )->a( n = `demandPopin`    v = `true`
        )->tag( `Text`
            )->a( n = `text` v = `Last pull` ).
    columns->ele( `Column`
        )->a( n = `minScreenWidth` v = `Tablet`
        )->a( n = `demandPopin`    v = `true`
        )->a( n = `width` v = `10rem`
        )->tag( `Text`
            )->a( n = `text` v = `Actions` ).

    DATA(cells) = table->ele( `items`
        )->ele( `ColumnListItem`
            )->a( n = `type`  v = `{NAV_TYPE}`
            )->a( n = `press` v = client->_event( val = `OPEN` arg = `${KEY}` )
            )->ele( `cells` ).
    favorite_display( cells ).
    DATA(name_cell) = cells->ele( `VBox` ).
    name_cell->tag( `ObjectIdentifier`
        )->a( n = `title` v = `{NAME}` ).
    labels_display( name_cell ).
    cells->tag( `Text`
        )->a( n = `text` v = `{PACKAGE}` ).
    " a link opens in a new tab; a click on it does not open the repository
    cells->tag( `Link`
        )->a( n = `text`   v = `{URL}`
        )->a( n = `href`   v = `{URL}`
        )->a( n = `target` v = `_blank` ).
    cells->tag( `Link`
        )->a( n = `text`    v = `{BRANCH_DISPLAY}`
        )->a( n = `href`    v = `{BRANCH_LINK}`
        )->a( n = `enabled` v = `{= !!${BRANCH_LINK} }`
        )->a( n = `target`  v = `_blank` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{DESERIALIZED_AT}` ).
    actions_display( cells ).

    tiles_display( content ).

    DATA(empty) = content->ele( `VBox`
        )->a( n = `visible` v = client->_bind( mv_empty )
        )->a( n = `alignItems` v = `Center`
        )->a( n = `class` v = `sapUiLargeMargin` ).
    empty->tag( `Text`
        )->a( n = `text` v = client->_bind( mv_empty_text ) ).
    empty->tag( `Button`
        )->a( n = `text` v = `Show all repositories`
        )->a( n = `visible` v = client->_bind( mv_favorites_only )
        )->a( n = `press` v = client->_event( `SHOW_ALL` ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

  METHOD tiles_display.

    DATA(grid) = io_content->ele( n = `GridContainer` ns = `f`
        )->a( n = `items`   v = client->_bind( mt_repos )
        )->a( n = `visible` v = |\{= $\{{ client->_bind( val = mv_layout path = abap_true ) }\} === 'TILES' && !$\{{ client->_bind( val = mv_empty path = abap_true ) }\} \}|
        )->a( n = `class`   v = `sapUiSmallMargin` ).
    grid->ele( n = `layout` ns = `f`
        )->tag( n = `GridContainerSettings` ns = `f`
            )->a( n = `columnSize` v = `20rem`
            )->a( n = `gap`        v = `1rem` ).

    " a click on the header opens the repository, as a table row does
    DATA(card) = grid->ele( n = `Card` ns = `f`
        )->a( n = `width` v = `100%` ).
    DATA(header) = card->ele( n = `header` ns = `f`
        )->ele( n = `Header` ns = `card`
            )->a( n = `title`    v = `{NAME}`
            )->a( n = `subtitle` v = `{PACKAGE}`
            )->a( n = `iconSrc`  v = `{= ${OFFLINE} ? 'sap-icon://disconnected' : 'sap-icon://cloud' }`
            )->a( n = `press`    v = client->_event( val = `OPEN` arg = `${KEY}` ) ).

    " Header actions stay separate from the repository-opening press event.
    DATA(header_actions) = header->ele( n = `toolbar` ns = `card` ).
    favorite_display( header_actions ).

    DATA(box) = card->ele( n = `content` ns = `f`
        )->ele( `VBox`
            )->a( n = `class` v = `sapUiSmallMarginBeginEnd sapUiTinyMarginBottom` ).

    labels_display( box ).

    " a link opens in a new tab; a click on it does not open the repository
    " a URL has no blank to wrap at: cut it off at the card's inner width
    " (column 20rem less the margins); the tooltip has all of it
    box->tag( `Link`
        )->a( n = `text`    v = `{URL}`
        )->a( n = `href`    v = `{URL}`
        )->a( n = `target`  v = `_blank`
        )->a( n = `width`   v = `18rem`
        )->a( n = `tooltip` v = `{URL}` ).
    box->ele( `ObjectAttribute`
        )->a( n = `title`   v = `Reference`
        )->a( n = `visible` v = `{= !!${BRANCH_DISPLAY} }`
        )->ele( `customContent`
            )->tag( `Link`
                )->a( n = `text`    v = `{BRANCH_DISPLAY}`
                )->a( n = `href`    v = `{BRANCH_LINK}`
                )->a( n = `enabled` v = `{= !!${BRANCH_LINK} }`
                )->a( n = `target`  v = `_blank` ).
    box->tag( `ObjectAttribute`
        )->a( n = `title`   v = `Last pull`
        )->a( n = `text`    v = `{DESERIALIZED_AT}`
        )->a( n = `visible` v = `{= !!${DESERIALIZED_AT} }` ).
    actions_display( box ).

  ENDMETHOD.

  METHOD on_event.

    CASE client->get_event( ).
      WHEN `SESSION_END`.
        " second half of the switch back to stateless, see main( )
        client->set_session_stateful( abap_false ).
        zcl_ag2ui5_app_login=>set_stateful( abap_false ).
      WHEN `SEARCH`.
        CLEAR mv_label_filter.
        apply_search( ).
      WHEN `LABEL_FILTER`.
        label_filter( client->get_event_arg( ) ).
      WHEN `LABELS`.
        labels_open( ).
      WHEN `LABELS_CLOSE`.
        client->popover_destroy( ).
        CLEAR: mt_labels, mv_labels_title.
      WHEN `FAVORITE`.
        favorite_set( ).
      WHEN `FAVORITES_FILTER`.
        favorites_filter( client->get_event_arg( ) ).
      WHEN `SHOW_ALL`.
        favorites_filter( `` ).
      WHEN `REFRESH`.
        load_repos( ).
      WHEN `OPEN`.
        open_repo( ).
      WHEN `LAYOUT`.
        " switching happens on the client; the server only remembers it
        zcl_ag2ui5_settings=>get_instance( )->set( iv_key   = zif_ag2ui5_settings=>c_key-repos_layout
                                                   iv_value = mv_layout ).
      WHEN `NEW`.
        client->nav_app_call( zcl_ag2ui5_app_new_repo=>create( ) ).
      WHEN `REMOVE` OR `UNINSTALL`.
        delete_open( client->get_event( ) ).
      WHEN `DELETE_CONFIRM`.
        delete_confirm( ).
      WHEN `DELETE_CANCEL`.
        client->popup_destroy( ).
        delete_clear( ).
        load_repos( ).
    ENDCASE.

  ENDMETHOD.

  METHOD load_repos.

    TRY.
        DATA(lt_repos) = service( )->list_repos( ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.

    CLEAR mt_all.
    LOOP AT lt_repos INTO DATA(ls_repo).
      DATA(ls_row) = CORRESPONDING ty_row( ls_repo ).
      ls_row-nav_type = `Navigation`.
      ls_row-favorite_icon = COND #( WHEN ls_row-favorite = abap_true
        THEN `sap-icon://favorite` ELSE `sap-icon://unfavorite` ).
      ls_row-favorite_text = COND #( WHEN ls_row-favorite = abap_true
        THEN `Remove from favorites` ELSE `Add to favorites` ).
      LOOP AT ls_row-labels INTO DATA(ls_label) FROM 1 TO 3.
        INSERT ls_label INTO TABLE ls_row-label_preview.
      ENDLOOP.
      ls_row-label_more = COND #( WHEN lines( ls_row-labels ) > 3 THEN |+{ lines( ls_row-labels ) - 3 }| ).
      INSERT ls_row INTO TABLE mt_all.
    ENDLOOP.

    apply_search( ).

  ENDMETHOD.

  METHOD apply_search.

    mt_repos = filtered_repos( it_rows = mt_all iv_search = COND #( WHEN mv_label_filter IS INITIAL THEN mv_search )
      iv_favorites_only = mv_favorites_only iv_label = mv_label_filter ).
    mv_empty = xsdbool( mt_repos IS INITIAL ).
    mv_empty_text = COND #( WHEN mv_favorites_only = abap_false THEN `No repositories found`
      WHEN NOT line_exists( mt_all[ favorite = abap_true ] ) THEN `No favorites yet`
      ELSE `No favorites match your search` ).

  ENDMETHOD.

  METHOD filtered_repos.

    LOOP AT it_rows INTO DATA(ls_row).
      IF iv_favorites_only = abap_true AND ls_row-favorite = abap_false.
        CONTINUE.
      ENDIF.
      IF iv_label IS NOT INITIAL AND NOT line_exists( ls_row-labels[ text = iv_label ] ).
        CONTINUE.
      ENDIF.
      DATA(lv_label_match) = abap_false.
      LOOP AT ls_row-labels INTO DATA(ls_label).
        IF ls_label-text CS iv_search.
          lv_label_match = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF iv_search IS NOT INITIAL AND NOT ( ls_row-name CS iv_search OR ls_row-package CS iv_search OR ls_row-url CS iv_search
        OR lv_label_match = abap_true ).
        CONTINUE.
      ENDIF.
      INSERT ls_row INTO TABLE rt_rows.
    ENDLOOP.
    SORT rt_rows BY favorite DESCENDING package ASCENDING name ASCENDING key ASCENDING.

  ENDMETHOD.

  METHOD labels_display.

    DATA(row) = io_parent->ele( `HBox`
        )->a( n = `visible` v = `{= ${LABELS}.length > 0 }`
        )->a( n = `alignItems` v = `Center`
        )->a( n = `wrap` v = `Wrap`
        )->a( n = `class` v = `ag2ui5RepoTags sapUiTinyMarginTop sapUiTinyMarginBottom` ).
    DATA(tags) = row->ele( `FlexBox`
        )->a( n = `wrap` v = `Wrap`
        )->a( n = `items` v = `{path: 'LABEL_PREVIEW', templateShareable: false}` ).
    DATA(items) = tags->ele( `items` ).
    label_items( items ).
    row->tag( `Button`
        )->a( n = `text` v = `{LABEL_MORE}`
        )->a( n = `visible` v = `{= !!${LABEL_MORE} }`
        )->a( n = `tooltip` v = `Show all repository labels`
        )->a( n = `type` v = `Transparent`
        )->a( n = `press` v = client->_event( val = `LABELS`
             t_arg = VALUE #( ( `${KEY}` ) ( `$event.getSource().getId()` ) ) ) ).

  ENDMETHOD.

  METHOD label_items.

    io_parent->ele( `Link`
        )->a( n = `text` v = `{TEXT}`
        )->a( n = `tooltip` v = `{TEXT}`
        )->a( n = `wrapping` b = iv_wrapping
        )->a( n = `press` v = client->_event( val = `LABEL_FILTER` arg = `${TEXT}` )
        )->a( n = `class` v = `ag2ui5RepoTag`
        )->ele( `customData`
            )->tag( n = `CustomData` ns = `core`
                )->a( n = `key` v = `tag-color`
                )->a( n = `value` v = `{COLOR}`
                )->a( n = `writeToDom` v = `true` ).

  ENDMETHOD.

  METHOD label_filter.

    DATA(lv_label) = iv_label.
    IF lv_label IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT mt_all INTO DATA(ls_row).
      IF line_exists( ls_row-labels[ text = lv_label ] ).
        mv_label_filter = lv_label.
        mv_search = lv_label.
        client->popover_destroy( ).
        CLEAR: mt_labels, mv_labels_title.
        apply_search( ).
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD labels_open.

    READ TABLE mt_all INTO DATA(ls_row) WITH KEY key = client->get_event_arg( ).
    IF sy-subrc <> 0 OR ls_row-labels IS INITIAL OR client->get_event_arg( 2 ) IS INITIAL.
      RETURN.
    ENDIF.
    mt_labels = ls_row-labels.
    mv_labels_title = |Labels - { ls_row-name }|.
    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `FragmentDefinition` ns = `core`
            )->a( n = `xmlns` v = `sap.m`
            )->a( n = `xmlns:core` v = `sap.ui.core` ).
    DATA(popover) = popup->ele( `Popover`
        )->a( n = `title` v = client->_bind( mv_labels_title )
        )->a( n = `contentWidth` v = `20rem`
        )->a( n = `placement` v = `Auto` ).
    DATA(content) = popover->ele( `content` ).
    content->tag( n = `HTML` ns = `core`
        )->a( n = `content` v = labels_css( ) ).
    DATA(tags) = content->ele( `FlexBox`
        )->a( n = `items` v = client->_bind( mt_labels )
        )->a( n = `wrap` v = `Wrap`
        )->a( n = `class` v = `ag2ui5RepoTags ag2ui5RepoLabelsAll sapUiSmallMargin` ).
    DATA(items) = tags->ele( `items` ).
    label_items( io_parent = items iv_wrapping = abap_true ).
    popover->ele( `footer`
        )->ele( `OverflowToolbar`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `text` v = `Close`
                )->a( n = `press` v = client->_event( `LABELS_CLOSE` ) ).
    client->popover_display( xml = popup->stringify( ) by_id = client->get_event_arg( 2 ) ).

  ENDMETHOD.

  METHOD labels_css.

    rv_css = `<style>` &&
      `.ag2ui5ProjectLogo \{background:#fff;border-radius:.375rem;padding:.25rem;box-sizing:border-box\}` &&
      `.ag2ui5RepoTags .ag2ui5RepoTag \{font-size:.75rem;border-radius:.375rem;padding:.1875rem .5rem;` &&
      `margin:.125rem .25rem .125rem 0;max-width:9rem;box-sizing:border-box;` &&
      `color:var(--sapTextColor);background:var(--sapList_Background);border:1px solid transparent\}` &&
      `.ag2ui5RepoLabelsAll .ag2ui5RepoTag \{max-width:100%;overflow-wrap:anywhere\}` &&
      `.ag2ui5RepoTag[data-tag-color="blue"] \{color:#0057a7;background:#e9f3ff\}` &&
      `.ag2ui5RepoTag[data-tag-color="teal"] \{color:#006b67;background:#e3f5f1\}` &&
      `.ag2ui5RepoTag[data-tag-color="purple"] \{color:#6941a5;background:#f1eafa\}` &&
      `.ag2ui5RepoTag[data-tag-color="rose"] \{color:#9d3568;background:#fcebf3\}` &&
      `.ag2ui5RepoTag[data-tag-color="amber"] \{color:#865600;background:#fff2d9\}` &&
      `.ag2ui5RepoTag[data-tag-color="slate"] \{color:#435a73;background:#edf1f6\}` &&
      `html[class*="_dark"] .ag2ui5RepoTag[data-tag-color="blue"] \{color:#99caff;background:#16364f\}` &&
      `html[class*="_dark"] .ag2ui5RepoTag[data-tag-color="teal"] \{color:#85d6cd;background:#183d3a\}` &&
      `html[class*="_dark"] .ag2ui5RepoTag[data-tag-color="purple"] \{color:#d1b2ff;background:#35264b\}` &&
      `html[class*="_dark"] .ag2ui5RepoTag[data-tag-color="rose"] \{color:#f3a8ce;background:#49273a\}` &&
      `html[class*="_dark"] .ag2ui5RepoTag[data-tag-color="amber"] \{color:#f3ce87;background:#47391d\}` &&
      `html[class*="_dark"] .ag2ui5RepoTag[data-tag-color="slate"] \{color:#b4c8dc;background:#2e3d4d\}` &&
      `html[class*="_hcb"] .ag2ui5RepoTags .ag2ui5RepoTag,html[class*="_hcw"] .ag2ui5RepoTags .ag2ui5RepoTag \{` &&
      `color:var(--sapTextColor);background:var(--sapList_Background);border-color:var(--sapContent_ForegroundBorderColor)\}` &&
      `</style>`.

  ENDMETHOD.

  METHOD favorite_display.

    io_parent->tag( `ToggleButton`
        )->a( n = `icon`    v = `{FAVORITE_ICON}`
        )->a( n = `tooltip` v = `{FAVORITE_TEXT}`
        )->a( n = `pressed` v = `{= !!${FAVORITE} }`
        )->a( n = `type`    v = `Transparent`
        )->a( n = `press`   v = client->_event( val = `FAVORITE`
                                                  t_arg = VALUE #( ( `${KEY}` ) ( `${$parameters>/pressed}` ) ) ) ).

  ENDMETHOD.

  METHOD favorite_set.

    TRY.
        DATA(lv_key) = client->get_event_arg( ).
        DATA(lv_favorite) = service( )->set_favorite( iv_key = lv_key iv_favorite = client->get_event_arg( 2 ) ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        " Restore the server's previous rows, including the star's pressed state.
        apply_search( ).
        view_display( ).
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.
    " Keep the confirmed state even if refreshing the repository list fails.
    LOOP AT mt_all ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE key = lv_key.
      <ls_row>-favorite = lv_favorite.
      <ls_row>-favorite_icon = COND #( WHEN lv_favorite = abap_true
        THEN `sap-icon://favorite` ELSE `sap-icon://unfavorite` ).
      <ls_row>-favorite_text = COND #( WHEN lv_favorite = abap_true
        THEN `Remove from favorites` ELSE `Add to favorites` ).
    ENDLOOP.
    apply_search( ).
    load_repos( ).
    client->message_toast_display( COND #( WHEN lv_favorite = abap_true
      THEN `Repository added to favorites` ELSE `Repository removed from favorites` ) ).

  ENDMETHOD.

  METHOD favorites_filter.

    DATA(lv_value) = COND string( WHEN iv_value = ` ` THEN `` ELSE iv_value ).
    IF zcl_ag2ui5_settings=>get_instance( )->set(
      iv_key = zif_ag2ui5_settings=>c_key-repos_favorites_only iv_value = lv_value ) = abap_false.
      mv_favorites_only = xsdbool( zcl_ag2ui5_settings=>get_instance( )->get(
        iv_key = zif_ag2ui5_settings=>c_key-repos_favorites_only iv_default = `` ) = `X` ).
      client->message_box_display( text = `Favorites filter could not be saved` type = `error` ).
    ELSE.
      mv_favorites_only = xsdbool( lv_value = `X` ).
    ENDIF.
    apply_search( ).

  ENDMETHOD.

  METHOD service.
    ri_service = mi_service.
    IF ri_service IS NOT BOUND.
      ri_service = NEW zcl_ag2ui5_repo_service( ).
    ENDIF.
  ENDMETHOD.

  METHOD actions_display.
    io_parent->ele( `HBox`
        )->a( n = `justifyContent` v = `End`
        )->tag( `Button`
            )->a( n = `text` v = `Remove`
            )->a( n = `type` v = `Transparent`
            )->a( n = `tooltip` v = `Remove registration; keep SAP objects`
            )->a( n = `press` v = client->_event( val = `REMOVE` arg = `${KEY}` )
        )->tag( `Button`
            )->a( n = `text` v = `Uninstall`
            )->a( n = `type` v = `Transparent`
            )->a( n = `tooltip` v = `Delete SAP objects and remove registration`
            )->a( n = `press` v = client->_event( val = `UNINSTALL` arg = `${KEY}` ) ).
  ENDMETHOD.

  METHOD delete_clear.
    CLEAR: ms_delete_preview, mv_delete_failed, mv_delete_title, mv_delete_text,
      mv_delete_package, mv_delete_confirmation, mv_delete_transport,
      mv_delete_error, mt_delete_objects, mt_delete_transports, mt_delete_messages.
  ENDMETHOD.

  METHOD delete_open.
    delete_clear( ).
    TRY.
        ms_delete_preview = service( )->preview_delete(
          iv_key = client->get_event_arg( ) iv_action = iv_action ).
        mv_delete_package = ms_delete_preview-package.
        mt_delete_objects = ms_delete_preview-objects.
        IF ms_delete_preview-transport_required = abap_true.
          mt_delete_transports = service( )->list_transports( `K` ).
          INSERT VALUE #( text = `Choose a request` ) INTO mt_delete_transports INDEX 1.
        ENDIF.
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        delete_clear( ).
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.
    IF iv_action = `REMOVE`.
      mv_delete_title = `Remove repository`.
      mv_delete_text = |Remove { ms_delete_preview-name } from package { mv_delete_package }? | &&
        `SAP objects and the remote repository will remain. Local abapGit settings will be removed.`.
    ELSE.
      mv_delete_title = `Uninstall repository`.
      mv_delete_text = |Uninstall { ms_delete_preview-name } from package { mv_delete_package }? | &&
        |Delete the { lines( mt_delete_objects ) } objects listed below and remove registration. | &&
        `This can delete table data and cannot be undone. The remote repository will remain. ` &&
        `Transportable packages may remain until the deletion transport is released.`.
    ENDIF.
    delete_display( ).
  ENDMETHOD.

  METHOD delete_display.
    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `FragmentDefinition` ns = `core`
            )->a( n = `xmlns` v = `sap.m`
            )->a( n = `xmlns:core` v = `sap.ui.core` ).
    DATA(dialog) = popup->ele( `Dialog`
        )->a( n = `title` v = client->_bind( mv_delete_title )
        )->a( n = `contentWidth` v = `45rem`
        )->a( n = `stretch` v = `{device>/system/phone}` ).
    DATA(content) = dialog->ele( `content`
        )->ele( `VBox`
            )->a( n = `class` v = `sapUiSmallMargin` ).
    content->tag( `MessageStrip`
        )->a( n = `text` v = client->_bind( mv_delete_text )
        )->a( n = `type` v = `Warning`
        )->a( n = `showIcon` v = `true` ).
    content->tag( `MessageStrip`
        )->a( n = `text` v = client->_bind( mv_delete_error )
        )->a( n = `type` v = `Error`
        )->a( n = `showIcon` v = `true`
        )->a( n = `visible` v = |\{= !!$\{{ client->_bind( val = mv_delete_error path = abap_true ) }\} \}| ).
    IF ms_delete_preview-action = `UNINSTALL`.
      DATA(table) = content->ele( `Table`
          )->a( n = `items` v = client->_bind( mt_delete_objects )
          )->a( n = `noDataText` v = `No SAP objects to delete` ).
      DATA(columns) = table->ele( `columns` ).
      columns->ele( `Column`
          )->a( n = `width` v = `5rem`
          )->tag( `Text`
              )->a( n = `text` v = `Type` ).
      columns->ele( `Column`
          )->tag( `Text`
              )->a( n = `text` v = `Object` ).
      columns->ele( `Column`
          )->a( n = `minScreenWidth` v = `Tablet`
          )->a( n = `demandPopin` v = `true`
          )->tag( `Text`
              )->a( n = `text` v = `Package` ).
      table->ele( `items`
          )->ele( `ColumnListItem`
              )->ele( `cells`
                  )->tag( `Text`
                      )->a( n = `text` v = `{OBJ_TYPE}`
                  )->tag( `Text`
                      )->a( n = `text` v = `{OBJ_NAME}`
                  )->tag( `Text`
                      )->a( n = `text` v = `{PACKAGE}` ).
      content->tag( `Label`
          )->a( n = `text` t = |Type { mv_delete_package } to confirm uninstall|
          )->a( n = `labelFor` v = `deleteConfirmation` ).
      content->tag( `Input`
          )->a( n = `id` v = `deleteConfirmation`
          )->a( n = `value` v = client->_bind( mv_delete_confirmation )
          )->a( n = `valueLiveUpdate` v = `true` ).
    ENDIF.
    IF ms_delete_preview-transport_required = abap_true.
      content->tag( `Label`
          )->a( n = `text` v = `Workbench transport request`
          )->a( n = `labelFor` v = `deleteTransport` ).
      content->ele( `Select`
          )->a( n = `id` v = `deleteTransport`
          )->a( n = `width` v = `100%`
          )->a( n = `selectedKey` v = client->_bind( mv_delete_transport )
          )->a( n = `items` v = client->_bind( mt_delete_transports )
          )->ele( `items`
              )->tag( n = `Item` ns = `core`
                  )->a( n = `key` v = `{TRKORR}`
                  )->a( n = `text` v = `{= ${TRKORR} ? ${TRKORR} + ' ' + ${TEXT} : ${TEXT} }` ).
    ENDIF.
    content->ele( `List`
        )->a( n = `items` v = client->_bind( mt_delete_messages )
        )->a( n = `showNoData` v = `false`
        )->ele( `items`
            )->ele( `CustomListItem`
                )->ele( `content`
                    )->tag( `Text`
                        )->a( n = `text` v = `{TEXT}` ).
    DATA(buttons) = dialog->ele( `buttons` ).
    buttons->tag( `Button`
        )->a( n = `text` v = `Cancel`
        )->a( n = `press` v = client->_event( `DELETE_CANCEL` ) ).
    buttons->tag( `Button`
        )->a( n = `text` t = COND string( WHEN ms_delete_preview-action = `REMOVE` THEN `Remove` ELSE `Uninstall` )
        )->a( n = `type` v = `Reject`
        )->a( n = `enabled` b = xsdbool( mv_delete_failed = abap_false )
        )->a( n = `press` v = client->_event( `DELETE_CONFIRM` ) ).
    client->popup_display( popup->stringify( ) ).
  ENDMETHOD.

  METHOD delete_confirm.
    IF ms_delete_preview-key IS INITIAL OR mv_delete_failed = abap_true.
      RETURN.
    ENDIF.
    CLEAR: mv_delete_error, mt_delete_messages.
    TRY.
        DATA(ls_result) = service( )->delete_repo( is_preview = ms_delete_preview
          iv_confirmation = mv_delete_confirmation iv_transport = mv_delete_transport ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        mv_delete_error = lx_error->get_text( ).
        RETURN.
    ENDTRY.
    IF ls_result-outcome <> zif_ag2ui5_repo_service=>c_outcome-removed AND
       ls_result-outcome <> zif_ag2ui5_repo_service=>c_outcome-uninstalled.
      mv_delete_failed = abap_true.
      mt_delete_messages = ls_result-messages.
      mv_delete_error = `Uninstall did not finish. Some objects may already be deleted. ` &&
        `Registration is retained. Cancel and open a new preview to inspect the remaining objects.`.
      delete_display( ).
      RETURN.
    ENDIF.
    DATA(lv_message) = COND string( WHEN ls_result-outcome = zif_ag2ui5_repo_service=>c_outcome-removed
      THEN `Repository registration removed; SAP objects retained`
      ELSE `Repository uninstalled` ).
    client->popup_destroy( ).
    delete_clear( ).
    load_repos( ).
    client->message_toast_display( lv_message ).
  ENDMETHOD.

  METHOD open_repo.

    READ TABLE mt_all INTO DATA(ls_row) WITH KEY key = client->get_event_arg( ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    client->nav_app_call( zcl_ag2ui5_app_status=>create( ls_row-key ) ).

  ENDMETHOD.

ENDCLASS.
