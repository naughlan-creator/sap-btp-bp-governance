import cds from '@sap/cds'

export default class GovernanceService extends cds.ApplicationService {
  async init() {
    const { ChangeRequests, BusinessPartners } = this.entities
    const bupa = await cds.connect.to('API_BUSINESS_PARTNER')

    // Remote entity: forward reads to S/4HANA (mocked locally, API Hub sandbox or destination when deployed)
    this.on('READ', BusinessPartners, req => bupa.run(req.query))

    // On draft activation: UPDATE / BLOCK must reference a BP that exists in S/4HANA
    this.before(['CREATE', 'UPDATE'], ChangeRequests, async req => {
      const { changeType_code, businessPartner } = req.data
      if (changeType_code === 'CREATE') return
      if (!businessPartner) return req.error(400, `Business Partner is required for change type ${changeType_code}`, 'in/businessPartner')
      const bp = await bupa.run(SELECT.one.from(BusinessPartners).where({ BusinessPartner: businessPartner }))
      if (!bp) req.error(400, `Business Partner ${businessPartner} does not exist in S/4HANA`, 'in/businessPartner')
    })

    this.on('submit', ChangeRequests, async req => {
      const cr = await this.#load(req, ['NEW', 'REJECTED'])
      if (!cr.justification) return req.reject(400, 'Add a justification before submitting')
      return this.#setStatus(req, 'SUBMITTED', { rejectionReason: null })
    })

    this.on('approve', ChangeRequests, async req => {
      await this.#load(req, ['SUBMITTED'], { fourEyes: true })
      return this.#setStatus(req, 'APPROVED')
    })

    this.on('rejectRequest', ChangeRequests, async req => {
      if (!req.data.reason) return req.reject(400, 'A rejection reason is required')
      await this.#load(req, ['SUBMITTED'], { fourEyes: true })
      return this.#setStatus(req, 'REJECTED', { rejectionReason: req.data.reason })
    })

    return super.init()
  }

  async #load(req, allowedStatuses, { fourEyes = false } = {}) {
    const cr = await SELECT.one.from(req.subject).columns('status_code', 'createdBy', 'justification')
    if (!cr) return req.reject(404)
    if (!allowedStatuses.includes(cr.status_code))
      req.reject(409, `Not allowed in status ${cr.status_code} (expected ${allowedStatuses.join(' or ')})`)
    if (fourEyes && cr.createdBy === req.user.id)
      req.reject(403, 'Four-eyes principle: you cannot decide on your own change request')
    return cr
  }

  async #setStatus(req, status_code, extra = {}) {
    await UPDATE(req.subject).with({ status_code, ...extra })
    return SELECT.one.from(req.subject)
  }
}
