@EndUserText.label : 'Draft table for ZSB_I_ServiceRequest'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zsb_srvreq_d {
  key mandt : mandt;
  key requestuuid : sysuuid_x16;
  requestid : abap.numc(10);
  equipment : abap.char(18);
  plant : abap.char(4);
  description : abap.char(120);
  priority : abap.char(1);
  status : abap.char(1);
  requestedby : abap.char(12);
  requireddate : abap.dats;
  @Semantics.amount.currencyCode : 'currencycode'
  totalamount : abap.curr(15,2);
  currencycode : abap.cuky(5);
  localcreatedby : abp_creation_user;
  localcreatedat : abp_creation_tstmpl;
  locallastchangedby : abp_locinst_lastchange_user;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  lastchangedat : abp_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
