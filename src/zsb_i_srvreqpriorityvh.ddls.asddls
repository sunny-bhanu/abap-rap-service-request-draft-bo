@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Service Request Priority - Value Help'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true
define view entity ZSB_I_SrvReqPriorityVH
  as select from zsb_srvcodetxt
{
      @ObjectModel.text.element: ['PriorityText']
      @Search.defaultSearchElement: true
  key code      as Priority,

      @Semantics.text: true
      @Search.defaultSearchElement: true
      code_text as PriorityText
}
where
  code_type = 'PRIORITY'
