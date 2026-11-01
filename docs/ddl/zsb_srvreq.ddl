@EndUserText.label : 'Service Request'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zsb_srvreq {
  key client : mandt;
  key request_uuid : sysuuid_x16;
  request_id : abap.numc(10);
  equipment : abap.char(18);
  plant : abap.char(4);
  description : abap.char(120);
  priority : abap.char(1);
  status : abap.char(1);
  requested_by : abap.char(12);
  required_date : abap.dats;
  @Semantics.amount.currencyCode : 'currency_code'
  total_amount : abap.curr(15,2);
  currency_code : abap.cuky(5);
  local_created_by : abp_creation_user;
  local_created_at : abp_creation_tstmpl;
  local_last_changed_by : abp_locinst_lastchange_user;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
  last_changed_at : abp_lastchange_tstmpl;
}
