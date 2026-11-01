@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Service Request Item - Projection'
@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
define view entity ZSB_C_ServiceRequestItem
  as projection on ZSB_I_ServiceRequestItem
{
  key RequestUuid,

      @EndUserText.label: 'Item'
  key ItemNo,

      @EndUserText.label: 'Material'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_ProductStdVH', element: 'Product' } }]
      Material,

      @EndUserText.label: 'Item Text'
      ItemText,

      @EndUserText.label: 'Quantity'
      Quantity,

      @EndUserText.label: 'Unit'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_UnitOfMeasureStdVH', element: 'UnitOfMeasure' }, useForValidation: true }]
      Unit,

      @EndUserText.label: 'Net Amount'
      NetAmount,

      @EndUserText.label: 'Currency'
      CurrencyCode,

      LocalLastChangedAt,

      /* associations */
      _ServiceRequest : redirected to parent ZSB_C_ServiceRequest,
      _Unit,
      _Currency
}
