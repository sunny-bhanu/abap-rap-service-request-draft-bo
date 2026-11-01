@EndUserText.label : 'Draft table for ZSB_I_ServiceRequestItem'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zsb_srvreqitm_d {
  key mandt : mandt;
  key requestuuid : sysuuid_x16;
  key itemno : abap.numc(4);
  material : abap.char(40);
  itemtext : abap.char(60);
  @Semantics.quantity.unitOfMeasure : 'unit'
  quantity : abap.quan(13,3);
  unit : abap.unit(3);
  @Semantics.amount.currencyCode : 'currencycode'
  netamount : abap.curr(15,2);
  currencycode : abap.cuky(5);
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}
