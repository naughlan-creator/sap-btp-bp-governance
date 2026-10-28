using {bpgov as db} from '../db/schema';
using {API_BUSINESS_PARTNER as bupa} from './external/API_BUSINESS_PARTNER';

@path    : 'governance'
@requires: 'authenticated-user'
service GovernanceService {

  // Requesters see and edit only their own requests; Approvers see everything but cannot edit.
  @odata.draft.enabled
  @restrict: [
    {
      grant: 'CREATE',
      to   : 'Requester'
    },
    {
      grant: ['READ', 'UPDATE', 'DELETE', 'submit'],
      to   : 'Requester',
      where: 'createdBy = $user'
    },
    {
      grant: ['READ', 'approve', 'rejectRequest'],
      to   : 'Approver'
    }
  ]
  entity ChangeRequests   as projection on db.ChangeRequests
    actions {
      action submit()                           returns ChangeRequests;
      action approve()                          returns ChangeRequests;
      action rejectRequest(reason : String(500)) returns ChangeRequests;
    };

  @readonly
  entity ChangeTypes      as projection on db.ChangeTypes;

  @readonly
  entity Statuses         as projection on db.Statuses;

  // Remote entity: delegated live to S/4HANA (API Hub sandbox) in srv/governance-service.js
  @readonly
  @restrict: [{
    grant: 'READ',
    to   : ['Requester', 'Approver']
  }]
  entity BusinessPartners as projection on bupa.A_BusinessPartner {
    key BusinessPartner,
        BusinessPartnerFullName,
        BusinessPartnerCategory,
        BusinessPartnerGrouping,
        CreationDate,
        BusinessPartnerIsBlocked
  };
}
