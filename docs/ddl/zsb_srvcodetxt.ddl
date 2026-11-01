@EndUserText.label : 'Service Request: code texts (status, priority)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zsb_srvcodetxt {
  key client : mandt;
  key code_type : abap.char(10);
  key code : abap.char(1);
  code_text : abap.char(40);
  criticality : abap.int1;
}
