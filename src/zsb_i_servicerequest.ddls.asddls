@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Service Request'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.semanticKey: ['RequestId']
define root view entity ZSB_I_ServiceRequest
  as select from zsb_srvreq

  composition [0..*] of ZSB_I_ServiceRequestItem as _Item

  association [0..1] to ZSB_I_SrvReqStatusVH     as _Status   on $projection.Status = _Status.Status
  association [0..1] to ZSB_I_SrvReqPriorityVH   as _Priority on $projection.Priority = _Priority.Priority
  association [0..1] to I_Plant                  as _Plant    on $projection.Plant = _Plant.Plant
  association [0..1] to I_Currency               as _Currency on $projection.CurrencyCode = _Currency.Currency
{
  key request_uuid          as RequestUuid,
      request_id            as RequestId,
      equipment             as Equipment,
      plant                 as Plant,
      description           as Description,
      priority              as Priority,
      status                as Status,
      requested_by          as RequestedBy,
      required_date         as RequiredDate,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      total_amount          as TotalAmount,
      currency_code         as CurrencyCode,

      // administrative fields, filled by the RAP framework
      @Semantics.user.createdBy: true
      local_created_by      as LocalCreatedBy,
      @Semantics.systemDateTime.createdAt: true
      local_created_at      as LocalCreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      /* associations */
      _Item,
      _Status,
      _Priority,
      _Plant,
      _Currency
}
