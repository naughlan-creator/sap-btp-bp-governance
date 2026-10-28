/*
 * STUB of the S/4HANA Cloud Business Partner API (API_BUSINESS_PARTNER, OData V2).
 * It has the same shape that `cds import` generates, cut down to the fields this app uses.
 * Replace it with the real import. See README, "Import the remote API":
 *   cds import API_BUSINESS_PARTNER.edmx --as cds --force
 */
@cds.external: true
service API_BUSINESS_PARTNER {}

@cds.external: true
@cds.persistence.skip: true
entity API_BUSINESS_PARTNER.A_BusinessPartner {
  key BusinessPartner          : String(10) not null;
      BusinessPartnerFullName  : String(81);
      BusinessPartnerCategory  : String(1);
      BusinessPartnerGrouping  : String(4);
      CreationDate             : Date;
      BusinessPartnerIsBlocked : Boolean;
}
