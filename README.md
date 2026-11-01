# abap-rap-service-request-draft-bo

A complete, draft-enabled **RAP business object** built with **ABAP Cloud** rules: a maintenance *Service Request* with items, approval actions and a Fiori Elements UI, written from scratch as a reference for the patterns I use on S/4HANA projects.

![ABAP Cloud](https://img.shields.io/badge/ABAP%20Cloud-RAP-0FAAFF?logo=sap&logoColor=white)
![Draft](https://img.shields.io/badge/RAP-managed%20%2B%20draft-0FAAFF)
![OData V4](https://img.shields.io/badge/OData-V4%20UI%20service-0FAAFF)
![abapGit](https://img.shields.io/badge/layout-abapGit-333333?logo=git&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)

## What it demonstrates

| Area | Where | Pattern |
|---|---|---|
| Data model | `zsb_srvreq`, `zsb_srvreqitm`, draft tables, `zsb_srvcodetxt` | UUID root key, **compound child key** (parent UUID + item number), RAP admin fields, draft tables with `%admin` include |
| CDS | `ZSB_I_ServiceRequest`, `ZSB_I_ServiceRequestItem` | Root view entity + composition, associations only to **released** SAP views (`I_Plant`, `I_Currency`, `I_UnitOfMeasure`) |
| Value helps | `ZSB_I_SrvReqStatusVH`, `ZSB_I_SrvReqPriorityVH` | Code/text table with a `Criticality` column that drives the UI colours, no `CASE` in the views |
| Projection | `ZSB_C_ServiceRequest`, `ZSB_C_ServiceRequestItem` | `transactional_query`, text elements via association, standard value helps (`I_PlantStdVH`, `I_ProductStdVH`, …) |
| Behaviour | `ZSB_I_ServiceRequest.bdef` | `managed`, `strict ( 2 )`, `with draft`, **early numbering** (root + child), etag/lock/authorization master/dependent, instance feature control, mandatory/readonly fields |
| Actions | `approve`, `reject`, `complete` | Status machine with `features : instance`, `result [1] $self`, success messages |
| Determinations | `setInitialValues`, `setRequestId`, `setItemDefaults`, `calculateTotalAmount`, `recalcTotalOnDelete` | On-modify defaults, **number range with fallback** on save, header total kept in sync, including after **item deletion** (possible because the parent key is part of the item key) |
| Validations | `validateRequiredDate`, `validatePlant`, `validatePriority`, `validateQuantity` | `%state_area` reset pattern, `%element` highlighting, plant check against `I_Plant` in one round trip |
| Side effects | `ZSB_C_ServiceRequest.bdef` | `field NetAmount affects field _ServiceRequest.TotalAmount` |
| Authorization | `ZSB_I_ServiceRequest.dcls`, `ZSB_C_ServiceRequest.dcls` | PFCG aspect on the interface view, `inheriting conditions` on the projection |
| UI | `*.ddlx` | Header data points with criticality, facets, list/identification/selection fields, actions in list and object page |
| Tests | `zsb_bp_i_servicerequest.clas.testclasses.abap` | ABAP Unit with CDS + Open SQL test doubles, exercising numbering, defaults, validations, actions and totals through EML |
| Demo data | `ZSB_CL_SRVREQ_DEMO_DATA` | `if_oo_adt_classrun` console app that fills code texts and creates sample requests via EML |

## Object overview

```
ZSB_C_ServiceRequest (projection, transactional_query) ─┐
   └─ ZSB_C_ServiceRequestItem                           │  ZSB_UI_SERVICEREQUEST (service definition)
                                                         │  └─ ZSB_UI_SERVICEREQUEST_O4 (OData V4 UI binding, create in ADT)
ZSB_I_ServiceRequest (root view entity) ─────────────────┘
   ├─ composition  _Item   → ZSB_I_ServiceRequestItem
   ├─ association  _Status → ZSB_I_SrvReqStatusVH   (zsb_srvcodetxt, CODE_TYPE = STATUS)
   ├─ association  _Priority → ZSB_I_SrvReqPriorityVH (zsb_srvcodetxt, CODE_TYPE = PRIORITY)
   ├─ association  _Plant  → I_Plant        (released)
   └─ association  _Currency → I_Currency   (released)

Behaviour: ZSB_I_ServiceRequest.bdef  →  implementation class ZSB_BP_I_SERVICEREQUEST
           ZSB_C_ServiceRequest.bdef  (projection, use draft, use side effects)
Tables:    ZSB_SRVREQ / ZSB_SRVREQ_D, ZSB_SRVREQITM / ZSB_SRVREQITM_D, ZSB_SRVCODETXT
Messages:  ZSB_RAP_SRVREQ
```

### Status flow

```
            approve            complete
   New ───────────────► Approved ───────────► Completed
    │
    │ reject
    ▼
 Rejected
```

Feature control: `approve`/`reject` only in *New*, `complete` only in *Approved*; `update` and item creation are disabled once a request is *Completed* or *Rejected*; `delete` only in *New*.

## Design notes

**Why a compound item key (RequestUuid + ItemNo) instead of an item UUID?**
A determination `on save { delete; }` cannot read the deleted instance any more, but it still receives its key. With the parent UUID inside the item key, the header total can be recalculated after an item is deleted without any extra bookkeeping. It also gives users a readable item number (10, 20, 30 …) assigned by early numbering, like purchase-order items.

**Numbering.** UUIDs are assigned with early numbering so the key is known immediately after `CREATE`. The human-readable `RequestId` is assigned when the active instance is created (at draft activation), from number range object `ZSB_SRVREQ` / interval `01`. If the object is not maintained (typical for a sandbox) the code falls back to `MAX(request_id) + 1` so the demo still works; for production, maintain the number range (SNRO) and drop the fallback.

**Clean core.** No direct access to SAP tables anywhere: plant validation and value helps go through released `I_*` views, system date and user come from `cl_abap_context_info`, and all objects are ABAP-for-Cloud-Development compliant (language version 5).

**Criticality without `CASE`.** The status colour is a data attribute of the status code (`zsb_srvcodetxt-criticality`), exposed through the value-help association. New statuses need a table entry, not a code change.

**Known simplification.** Deleting an item inside a *draft* updates the header total at activation (on-save determination), not instantly, because the on-modify determination cannot fire for deletions. In productive apps I usually add `entity _Item affects field TotalAmount` side effects plus a lightweight recalculation action if the instant refresh matters.

## Installation

The repository follows the abapGit folder layout (`/src/`, prefix logic).

**Option A: abapGit (recommended)**
1. Create package `ZSB_RAP_SRVREQ` (software component `ZLOCAL` or your own) in ADT.
2. In abapGit, *New Online* → this repository URL → package `ZSB_RAP_SRVREQ` → *Pull*. Activate everything.
3. Create the service binding `ZSB_UI_SERVICEREQUEST_O4` (OData V4, UI) on service definition `ZSB_UI_SERVICEREQUEST` and *Publish* it. Service bindings are generated objects, so they are not part of the repository.
4. Run `ZSB_CL_SRVREQ_DEMO_DATA` (F9) to load code texts and two sample requests.
5. *Preview* the `ServiceRequest` entity from the service binding, or add the app to a launchpad space.

**Option B: copy sources**
Create the objects in ADT with the names in `src/` and paste the sources. Table DDL sources are in [`docs/ddl`](docs/ddl) for readability (the `*.tabl.xml` files are the abapGit representation of the same tables).

Target release: S/4HANA 2023 / ABAP Platform 2023 (7.58) or BTP ABAP Environment. Authored against those syntax rules; if your release is older, `strict ( 2 )`, `Activate optimized` and side effects may need to be relaxed. Please pull into a sandbox first and raise an issue if an object does not activate on your release.

## Running the tests

Select `ZSB_BP_I_SERVICEREQUEST` in ADT → *Run As → ABAP Unit Test* (Ctrl+Shift+F10). Five tests cover defaults, required-date and plant validations, the `approve` action and the header total / item numbering.

## Repository layout

```
.abapgit.xml
LICENSE
README.md
docs/ddl/                 readable DDL of all tables
src/
  package.devc.xml
  zsb_srvreq*.tabl.xml      tables + draft tables
  zsb_srvcodetxt*.          code/text table and table type
  zsb_i_*.ddls.asddls       interface views and value helps
  zsb_c_*.ddls.asddls       projection views
  zsb_*.ddlx.asddlxs        metadata extensions (UI)
  zsb_*.bdef.asbdef         behaviour definitions
  zsb_bp_i_servicerequest.clas.*   behaviour implementation + unit tests
  zsb_*.dcls.asdcls         access controls
  zsb_ui_servicerequest.srvd.srvdsrv  service definition
  zsb_rap_srvreq.msag.xml   message class
  zsb_cl_srvreq_demo_data.clas.abap   demo data console app
```

## License

MIT, see [LICENSE](LICENSE). Original demo code; no customer or employer objects.
