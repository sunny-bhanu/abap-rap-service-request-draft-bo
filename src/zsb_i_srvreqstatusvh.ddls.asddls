@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Service Request Status - Value Help'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true
define view entity ZSB_I_SrvReqStatusVH
  as select from zsb_srvcodetxt
{
      @ObjectModel.text.element: ['StatusText']
      @Search.defaultSearchElement: true
  key code        as Status,

      @Semantics.text: true
      @Search.defaultSearchElement: true
      code_text   as StatusText,

      // 0 neutral, 1 negative (red), 2 critical (orange), 3 positive (green)
      criticality as Criticality
}
where
  code_type = 'STATUS'
