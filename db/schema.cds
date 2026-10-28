namespace bpgov;

using {
  cuid,
  managed,
  sap.common.CodeList
} from '@sap/cds/common';

/**
 * A governed change to Business Partner master data (MDG-style change request).
 * Requesters draft and submit; Approvers approve or reject (four-eyes principle).
 */
entity ChangeRequests : cuid, managed {
  title            : String(100) @mandatory;
  changeType       : Association to ChangeTypes @mandatory;
  businessPartner  : String(10); // BP number in S/4HANA (required for UPDATE / BLOCK)
  organizationName : String(80) @mandatory;
  country          : String(3);
  city             : String(40);
  taxNumber        : String(20);
  justification    : String(1000);
  status           : Association to Statuses default 'NEW' @readonly;
  rejectionReason  : String(500) @readonly;
}

entity ChangeTypes : CodeList {
  key code : String(10);
}

entity Statuses : CodeList {
  key code        : String(10);
      criticality : Integer; // 0 neutral, 1 negative, 2 critical, 3 positive
}
