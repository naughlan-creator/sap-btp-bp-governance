using GovernanceService as service from '../../srv/governance-service';

//
// Field labels, texts and value helps
//
annotate service.ChangeRequests with {
  title            @title: 'Title';
  changeType       @title: 'Change Type'      @Common: {
    Text           : changeType.name,
    TextArrangement: #TextOnly
  };
  businessPartner  @title: 'Business Partner' @Common.ValueList: {
    CollectionPath: 'BusinessPartners',
    Parameters    : [
      {
        $Type            : 'Common.ValueListParameterInOut',
        LocalDataProperty: businessPartner,
        ValueListProperty: 'BusinessPartner'
      },
      {
        $Type            : 'Common.ValueListParameterDisplayOnly',
        ValueListProperty: 'BusinessPartnerFullName'
      },
      {
        $Type            : 'Common.ValueListParameterDisplayOnly',
        ValueListProperty: 'BusinessPartnerIsBlocked'
      }
    ]
  };
  organizationName @title: 'Organization Name';
  country          @title: 'Country';
  city             @title: 'City';
  taxNumber        @title: 'Tax Number';
  justification    @title: 'Justification'    @UI.MultiLineText;
  status           @title: 'Status'           @Common: {
    Text           : status.name,
    TextArrangement: #TextOnly
  };
  rejectionReason  @title: 'Rejection Reason' @UI.MultiLineText;
  createdBy        @title: 'Requested By';
}

annotate service.BusinessPartners with @(Capabilities.SearchRestrictions.Searchable: false) {
  BusinessPartner          @title: 'Business Partner';
  BusinessPartnerFullName  @title: 'Name';
  BusinessPartnerCategory  @title: 'Category';
  BusinessPartnerGrouping  @title: 'Grouping';
  CreationDate             @title: 'Created On';
  BusinessPartnerIsBlocked @title: 'Blocked';
}

//
// Actions: only offered in the matching status; refresh status after execution
//
annotate service.ChangeRequests actions {
  submit  @(
    Core.OperationAvailable: {$edmJson: {$Or: [
      {$Eq: [{$Path: 'in/status_code'}, 'NEW']},
      {$Eq: [{$Path: 'in/status_code'}, 'REJECTED']}
    ]}},
    Common.SideEffects     : {TargetProperties: ['in/status_code', 'in/rejectionReason']}
  );
  approve @(
    Core.OperationAvailable: {$edmJson: {$Eq: [{$Path: 'in/status_code'}, 'SUBMITTED']}},
    Common.SideEffects     : {TargetProperties: ['in/status_code']}
  );
  rejectRequest @(
    Core.OperationAvailable: {$edmJson: {$Eq: [{$Path: 'in/status_code'}, 'SUBMITTED']}},
    Common.SideEffects     : {TargetProperties: ['in/status_code', 'in/rejectionReason']}
  )             (reason @title: 'Reason' @UI.MultiLineText);
}

//
// List report and object page layout
//
annotate service.ChangeRequests with @(
  UI.HeaderInfo         : {
    TypeName      : 'Change Request',
    TypeNamePlural: 'Change Requests',
    Title         : {Value: title},
    Description   : {Value: organizationName}
  },
  UI.SelectionFields    : [
    status_code,
    changeType_code,
    country,
    createdBy
  ],
  // High importance = never hidden by the responsive table on narrow or zoomed screens
  UI.LineItem           : [
    {
      Value            : title,
      ![@UI.Importance]: #High
    },
    {
      Value            : status_code,
      Criticality      : status.criticality,
      ![@UI.Importance]: #High
    },
    {
      Value            : changeType_code,
      ![@UI.Importance]: #High
    },
    {
      Value            : createdBy,
      ![@UI.Importance]: #High
    },
    {Value: businessPartner},
    {Value: organizationName},
    {Value: country},
    {Value: modifiedAt},
    {
      $Type : 'UI.DataFieldForAction',
      Action: 'GovernanceService.approve',
      Label : 'Approve'
    },
    {
      $Type : 'UI.DataFieldForAction',
      Action: 'GovernanceService.rejectRequest',
      Label : 'Reject'
    }
  ],
  UI.Identification     : [
    {
      $Type : 'UI.DataFieldForAction',
      Action: 'GovernanceService.submit',
      Label : 'Submit'
    },
    {
      $Type : 'UI.DataFieldForAction',
      Action: 'GovernanceService.approve',
      Label : 'Approve'
    },
    {
      $Type : 'UI.DataFieldForAction',
      Action: 'GovernanceService.rejectRequest',
      Label : 'Reject'
    }
  ],
  UI.DataPoint #status  : {
    Value      : status_code,
    Title      : 'Status',
    Criticality: status.criticality
  },
  UI.HeaderFacets       : [{
    $Type : 'UI.ReferenceFacet',
    Target: '@UI.DataPoint#status'
  }],
  UI.Facets             : [
    {
      $Type : 'UI.ReferenceFacet',
      ID    : 'Request',
      Label : 'Request',
      Target: '@UI.FieldGroup#Request'
    },
    {
      $Type : 'UI.ReferenceFacet',
      ID    : 'BusinessPartner',
      Label : 'Business Partner Data',
      Target: '@UI.FieldGroup#BusinessPartner'
    },
    {
      $Type : 'UI.ReferenceFacet',
      ID    : 'Admin',
      Label : 'Administrative Data',
      Target: '@UI.FieldGroup#Admin'
    }
  ],
  UI.FieldGroup #Request: {Data: [
    {Value: title},
    {Value: changeType_code},
    {Value: justification},
    {Value: rejectionReason}
  ]},
  UI.FieldGroup #BusinessPartner: {Data: [
    {Value: businessPartner},
    {Value: organizationName},
    {Value: country},
    {Value: city},
    {Value: taxNumber}
  ]},
  UI.FieldGroup #Admin  : {Data: [
    {Value: createdBy},
    {Value: createdAt},
    {Value: modifiedBy},
    {Value: modifiedAt}
  ]}
);
