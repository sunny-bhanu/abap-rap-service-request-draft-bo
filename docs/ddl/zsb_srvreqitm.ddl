@EndUserText.label : 'Service Request Item'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zsb_srvreqitm {
  key client : mandt;
  key request_uuid : sysuuid_x16;
  key item_no : abap.numc(4);
  material : abap.char(40);
  item_text : abap.char(60);
  @Semantics.quantity.unitOfMeasure : 'unit'
  quantity : abap.quan(13,3);
  unit : abap.unit(3);
  @Semantics.amount.currencyCode : 'currency_code'
  net_amount : abap.curr(15,2);
  currency_code : abap.cuky(5);
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
