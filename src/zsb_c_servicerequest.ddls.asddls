@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Service Request - Projection'
@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.semanticKey: ['RequestId']
@Search.searchable: true
define root view entity ZSB_C_ServiceRequest
  provider contract transactional_query
  as projection on ZSB_I_ServiceRequest
{
      @EndUserText.label: 'Request UUID'
  key RequestUuid,

      @EndUserText.label: 'Service Request'
      @Search.defaultSearchElement: true
      RequestId,

      @EndUserText.label: 'Equipment'
      @Search.defaultSearchElement: true
      Equipment,

      @EndUserText.label: 'Plant'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_PlantStdVH', element: 'Plant' }, useForValidation: true }]
      @ObjectModel.text.element: ['PlantName']
      Plant,
      _Plant.PlantName        as PlantName,

      @EndUserText.label: 'Description'
      @Search.defaultSearchElement: true
      Description,

      @EndUserText.label: 'Priority'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZSB_I_SrvReqPriorityVH', element: 'Priority' }, useForValidation: true }]
      @ObjectModel.text.element: ['PriorityText']
      Priority,
      _Priority.PriorityText  as PriorityText,

      @EndUserText.label: 'Status'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZSB_I_SrvReqStatusVH', element: 'Status' } }]
      @ObjectModel.text.element: ['StatusText']
      Status,
      _Status.StatusText      as StatusText,
      _Status.Criticality     as StatusCriticality,

      @EndUserText.label: 'Requested by'
      RequestedBy,

      @EndUserText.label: 'Required by'
      RequiredDate,

      @EndUserText.label: 'Total Amount'
      TotalAmount,

      @EndUserText.label: 'Currency'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_CurrencyStdVH', element: 'Currency' }, useForValidation: true }]
      CurrencyCode,

      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      /* associations */
      _Item : redirected to composition child ZSB_C_ServiceRequestItem,
      _Status,
      _Priority,
      _Plant,
      _Currency
}
