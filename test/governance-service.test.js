import cds from '@sap/cds'
import { describe, it } from 'node:test'

// --with-mocks serves API_BUSINESS_PARTNER in-process from db/data, like `cds watch` does
const { GET, POST, expect } = cds.test('serve', 'all', '--with-mocks', '--in-memory').in(import.meta.dirname, '..')

const as = user => ({ auth: { username: user, password: user } })
const CR = id => `/odata/v4/governance/ChangeRequests(ID=${id},IsActiveEntity=true)`
const ONBOARD = '3f1c2a10-0001-4c3e-9a01-000000000001' // alice, SUBMITTED
const RENAME = '3f1c2a10-0002-4c3e-9a01-000000000002' // alice, NEW
const BLOCK = '3f1c2a10-0003-4c3e-9a01-000000000003' // carol, SUBMITTED

describe('Authorization (@restrict)', () => {
  it('rejects anonymous access', async () => {
    await expect(GET('/odata/v4/governance/ChangeRequests')).to.be.rejectedWith(/401/)
  })

  it('shows Requesters only their own change requests', async () => {
    const { data } = await GET('/odata/v4/governance/ChangeRequests', as('alice'))
    expect(data.value.map(cr => cr.createdBy)).to.have.members(['alice', 'alice'])
  })

  it('shows Approvers all change requests', async () => {
    const { data } = await GET('/odata/v4/governance/ChangeRequests', as('bob'))
    expect(data.value).to.have.length(3)
  })

  it('does not let Approvers create change requests', async () => {
    await expect(POST('/odata/v4/governance/ChangeRequests', { title: 'x' }, as('bob'))).to.be.rejectedWith(/403/)
  })

  it('does not let Requesters approve', async () => {
    await expect(POST(`${CR(BLOCK)}/approve`, {}, as('alice'))).to.be.rejectedWith(/403/)
  })
})

describe('Remote Business Partner API', () => {
  it('reads Business Partners through the remote service', async () => {
    const { data } = await GET('/odata/v4/governance/BusinessPartners?$top=3', as('alice'))
    expect(data.value).to.have.length(3)
    expect(data.value[0]).to.have.property('BusinessPartnerFullName')
  })
})

describe('Change request workflow', () => {
  it('lets an Approver approve a submitted request', async () => {
    const { data } = await POST(`${CR(ONBOARD)}/approve`, {}, as('bob'))
    expect(data.status_code).to.equal('APPROVED')
  })

  it('refuses to approve twice', async () => {
    await expect(POST(`${CR(ONBOARD)}/approve`, {}, as('bob'))).to.be.rejectedWith(/409/)
  })

  it('requires a reason to reject', async () => {
    await expect(POST(`${CR(BLOCK)}/rejectRequest`, {}, as('bob'))).to.be.rejectedWith(/reason is required/)
  })

  it('rejects with a reason, and the requester can resubmit', async () => {
    const { data } = await POST(`${CR(BLOCK)}/rejectRequest`, { reason: 'Attach insolvency notice' }, as('bob'))
    expect(data).to.include({ status_code: 'REJECTED', rejectionReason: 'Attach insolvency notice' })
    const { data: again } = await POST(`${CR(BLOCK)}/submit`, {}, as('carol'))
    expect(again).to.include({ status_code: 'SUBMITTED', rejectionReason: null })
  })

  it('lets the owner submit a new request', async () => {
    const { data } = await POST(`${CR(RENAME)}/submit`, {}, as('alice'))
    expect(data.status_code).to.equal('SUBMITTED')
  })

  it('enforces the four-eyes principle', async () => {
    // dave is a data steward with both roles: they may submit, but not approve their own request
    const { data: { ID } } = await POST('/odata/v4/governance/ChangeRequests', {
      title: 'New customer', changeType_code: 'CREATE', organizationName: 'Acme Corp', justification: 'Signed contract'
    }, as('dave'))
    await POST(`/odata/v4/governance/ChangeRequests(ID=${ID},IsActiveEntity=false)/GovernanceService.draftActivate`, {}, as('dave'))
    await POST(`${CR(ID)}/submit`, {}, as('dave'))
    await expect(POST(`${CR(ID)}/approve`, {}, as('dave'))).to.be.rejectedWith(/Four-eyes/)
  })
})

describe('Draft activation validates against S/4HANA', () => {
  const draft = async body => {
    const { data } = await POST('/odata/v4/governance/ChangeRequests', body, as('alice'))
    return `/odata/v4/governance/ChangeRequests(ID=${data.ID},IsActiveEntity=false)`
  }
  const activate = url => POST(`${url}/GovernanceService.draftActivate`, {}, as('alice'))

  it('rejects an UPDATE for a Business Partner that does not exist', async () => {
    const url = await draft({ title: 'Fix name', changeType_code: 'UPDATE', businessPartner: '99999999', organizationName: 'Nobody Inc' })
    await expect(activate(url)).to.be.rejectedWith(/does not exist/)
  })

  it('accepts an UPDATE for an existing Business Partner', async () => {
    const url = await draft({ title: 'Fix name', changeType_code: 'UPDATE', businessPartner: '10100002', organizationName: 'Domestic DE Supplier One' })
    const { data } = await activate(url)
    expect(data).to.include({ status_code: 'NEW', createdBy: 'alice' })
  })
})
