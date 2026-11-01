// Authorization is inherited from the root entity (BDEF: authorization dependent by _ServiceRequest),
// the access control (DCL) therefore lives on ZSB_I_ServiceRequest.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Service Request Item'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZSB_I_ServiceRequestItem
  as select from zsb_srvreqitm

  association to parent ZSB_I_ServiceRequest as _ServiceRequest on $projection.RequestUuid = _ServiceRequest.RequestUuid

  association [0..1] to I_UnitOfMeasure       as _Unit           on $projection.Unit = _Unit.UnitOfMeasure
  association [0..1] to I_Currency            as _Currency       on $projection.CurrencyCode = _Currency.Currency
{
  key request_uuid          as RequestUuid,
  key item_no               as ItemNo,
      material              as Material,
      item_text             as ItemText,
      @Semantics.quantity.unitOfMeasure: 'Unit'
      quantity              as Quantity,
      unit                  as Unit,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      net_amount            as NetAmount,
      currency_code         as CurrencyCode,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      /* associations */
      _ServiceRequest,
      _Unit,
      _Currency
}
