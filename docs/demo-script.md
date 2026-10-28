# Demo script: BP Governance on SAP BTP

A run sheet for showing this project in an interview, a recruiter call or a team walkthrough.
It has two versions: **5 minutes** (pitch + live app) and **15 minutes** (adds the code tour and
the deployment). The pitch, Scenes 1–5 and the RAP mapping are the core. Everything else is optional.

---

## 1. The 30-second pitch

> "Bad Business Partner data is expensive, so MDG puts every change behind a change request and
> an approval. I built a small version of that on SAP BTP with CAP. Requesters raise create, update
> or block requests. Approvers decide on them, with the four-eyes rule enforced. Every BP number is
> checked live against the S/4HANA Business Partner API. The UI is Fiori elements, driven by
> annotations. It's secured with XSUAA role collections, deployed as an MTA, and shipped by an
> Azure DevOps pipeline. It runs on a BTP trial: a demo, not production."

Then say what you'll show: *"Two users side by side, then the code that makes it work, then how it's deployed."*

---

## 2. Setup checklist (15 minutes before)

- [ ] `npm ci` (if needed), then `npm run watch`. Wait for `server listening on http://localhost:4004`.
- [ ] **Two browsers side by side**, because the local login is HTTP basic auth and each browser
      caches one user:
  - Left, Chrome: `http://localhost:4004/changerequests/webapp/index.html` → log in as `alice` / `alice` (Requester)
  - Right, Edge or a private window: the same URL → log in as `bob` / `bob` (Approver)
- [ ] A terminal with `npm test` ready to run.
- [ ] Your editor open on [srv/governance-service.cds](../srv/governance-service.cds).
- [ ] *If deployed:* BTP cockpit tabs for **Role Collections** and **Destinations**, the approuter
      URL (already logged in), and the last green Azure Pipelines run.
- [ ] Restart `cds watch` just before you start. Data is in memory, so a restart resets the seed data.
- [ ] Zoom the browser to 110–125% and turn on Do Not Disturb.

**Seed data you'll use**

| Request | Owner | Status |
|---|---|---|
| Onboard new logistics supplier (Nordic Freight AB) | alice | Submitted |
| Correct legal name after merger (BP 10100001) | alice | New |
| Block insolvent customer (BP 10100003) | carol | Submitted |

---

## 3. Live demo (Scenes 1–5 take about 5 minutes)

### Scene 1: Each user sees only what they should
**Do:** Point at both windows. Alice's list shows **2** requests. Bob's shows **3**.
**Say:** "Same app, same URL. Alice is a Requester and only sees their own requests. That's
instance-based authorization in the service (`where: createdBy = $user`), not a UI filter. Bob is
an Approver and sees everything."
**Show:** The status colours (orange = Submitted, green = Approved, red = Rejected). They come from
a `criticality` value in the code list, set by one annotation.

### Scene 2: Raise a change request, with live S/4HANA validation
**Do (alice):** **Create** → Title `Update bank-relevant name`, Change Type **Update**, Organization
Name `Domestic DE Supplier 1 GmbH`.
1. Open the **Business Partner** value help. It lists BPs from the S/4HANA API.
   **Say:** "This value help isn't a local table. It's a remote entity from the API Business Hub,
   imported with `cds import`, and the read is delegated to S/4HANA."
2. Type a fake BP, `99999999`, and press **Save** → error *"Business Partner 99999999 does not exist
   in S/4HANA"*, and the field is highlighted.
   **Say:** "When the draft is saved, the service checks the BP against S/4HANA, so bad keys never
   make it in."
3. Pick `10100002` from the value help → **Save**. Status: **New**.

**Optional:** Leave the app mid-edit, then come back. The draft is still there.
*"That's CAP's draft handling, the same idea as RAP draft."*

### Scene 3: Business rules on submit
**Do (alice):** On the new request, press **Submit** → error *"Add a justification before submitting"*.
**Edit** → enter a justification → **Save** → **Submit** → status **Submitted**.
**Say:** "Actions are bound to the entity and only offered in the right status. Submit is available
for New or Rejected requests and hidden otherwise. That's `Core.OperationAvailable`."

### Scene 4: The Approver decides
**Do (bob):** Refresh. The new request appears.
1. Select *Onboard new logistics supplier* → **Approve** → green **Approved**. The Approve button is
   now disabled for that row.
2. Open *Block insolvent customer* → **Reject** → a dialog asks for a reason → `Attach insolvency
   notice` → **Rejected**, and the reason shows on the object page.
**Say:** "Reject without a reason fails on the server, not only in the UI. Carol can fix the
request and resubmit, so the workflow loops."

### Scene 5: Security is enforced in the service, not the UI
**Do:** In Alice's browser, open `http://localhost:4004/odata/v4/governance/ChangeRequests`.
The raw OData response has only Alice's records.
**Say:** "Even if someone skips the UI and calls the API directly, the same rules apply."
Then run **`npm test`** in the terminal. 14 green tests: anonymous access rejected, a Requester
can't approve, an Approver can't create, the status machine, the four-eyes rule and the remote
validation.
**Say:** "The four-eyes case is the test with `dave`, a data steward who has *both* roles. Dave can
submit but still can't approve their own request. `cds.test` is to CAP what ABAP Unit is to ABAP."

*End of the 5-minute version.*

---

## 4. Code tour (about 5 minutes, 15-minute version)

Open these files in order. Spend about a minute on each, and point at the lines you mention.

1. **[db/schema.cds](../db/schema.cds):** the domain model. `cuid` and `managed` give you the key
   and who-changed-it fields for free. Code lists hold status and change type.
2. **[srv/governance-service.cds](../srv/governance-service.cds):** **the slide that matters.**
   The `@restrict` block: CREATE for Requester, own records only via `where`, and the approver
   actions. `@odata.draft.enabled`. The `BusinessPartners` projection on the imported remote service.
3. **[srv/governance-service.js](../srv/governance-service.js):** about 60 lines. `on READ`
   delegates to S/4HANA. A `before CREATE/UPDATE` hook validates the BP. `submit`, `approve` and
   `rejectRequest` implement the status machine, plus the four-eyes check.
4. **[app/changerequests/annotations.cds](../app/changerequests/annotations.cds):** the whole UI
   with no JavaScript. `LineItem`, `Facets`, `ValueList` on the remote entity, `OperationAvailable`.
5. **[test/governance-service.test.js](../test/governance-service.test.js):** readable tests that
   call the real HTTP API as different users.

---

## 5. Deployment and CI/CD (about 3 minutes, 15-minute version)

**If it's deployed on your trial:**
1. Open the **approuter URL**. You get the XSUAA login with your SAP ID, and then the same app.
2. In the cockpit, open **Security → Role Collections**: `BPGov_Requester`, `BPGov_Approver`,
   `BPGov_DataSteward`. They're generated from [xs-security.json](../xs-security.json).
   **Say:** "Removing my Approver collection and logging in again makes the Approve button go away."
3. Open **Connectivity → Destinations → API_BUSINESS_PARTNER**. The API key lives here, not in code.
4. Show **Azure Pipelines**: the last green run with *Build and test → Deploy to BTP trial*.

**If it isn't deployed yet**, show the files instead:
- [mta.yaml](../mta.yaml): three modules (CAP service, UI, approuter) and two services (XSUAA, destination).
- [azure-pipelines.yml](../azure-pipelines.yml): tests run before the build, deploy only on `main`,
  and the password reaches `cf auth` through the environment, never the command line.

**Close with the honest limits.** This builds credibility, so don't skip it:
> "It's a trial demo. Data is in-memory SQLite and resets on restart, because HANA Cloud on trial
> stops every night. It reads from the API Hub sandbox, and approval doesn't write back to S/4.
> To make it real, I'd move to HANA Cloud, replicate to S/4 when a request is approved, and use a
> technical user for the pipeline."

---

## 6. Bridge to ABAP and RAP (your interview advantage)

For an ABAP role, connect every CAP concept to its RAP or classic counterpart:

| In this project (CAP) | ABAP / RAP equivalent |
|---|---|
| CDS entities in `db/schema.cds` | CDS view entities / database tables |
| Service projection in `srv/*.cds` | Projection views + service definition / binding |
| `@restrict` with `where: createdBy = $user` | Authorization objects + DCL access control (`define role`) |
| `@odata.draft.enabled` | RAP draft (`with draft;` in the BDEF) |
| Bound actions `submit` / `approve` | RAP actions in the BDEF + behavior implementation |
| `OperationAvailable` | RAP dynamic feature control (`features: instance`) |
| `before CREATE/UPDATE` validation | RAP `validation ... on save` |
| Remote entity via destination | Consuming OData via service consumption model / SM59 / communication arrangement |
| `cds.test` | ABAP Unit (+ test doubles for CDS and SQL) |
| Change request + approval | MDG change request type, workflow, four-eyes |
| Fiori elements annotations | Metadata extensions (`@UI`) in RAP |

**Say:** "I deliberately built it in CAP to learn BTP side-by-side extensibility. The design maps
one-to-one onto RAP, so on S/4HANA or in an MDG enhancement I'd build the same thing in ABAP."

---

## 7. Questions to expect

- **Why CAP and not RAP?** It's a side-by-side extension on BTP: clean core, no change to S/4.
  For an in-system enhancement (an MDG BAdI or rule), use RAP/ABAP.
- **How is authorization enforced?** At the service layer, with `@restrict` checked on every
  request. The UI only reflects it. XSUAA scopes → role templates → role collections → users.
- **What about real MDG?** Real MDG adds CR types, rule-based workflow, staging and replication.
  This demo models the governance idea: request, validate, approve, separation of duties.
- **How would you test end to end?** Service tests run in the pipeline today. Add Tosca (or
  OPA5/wdi5) UI tests on the deployed approuter URL as a post-deploy stage.
- **How do secrets work?** The API key is in the BTP destination (cloud) or `.cdsrc-private.json`
  (local, git-ignored). The CF password is a secret pipeline variable.
- **What was hard?** The Windows MTA build: `mbt` needs GNU make, and running `npm ci` inside the
  build deletes the running `mbt` binary. Also `cds build` doesn't ship CSV data, which needed a
  build script. Real gotchas make good stories.

---

## 8. If something breaks live

- **The app won't load:** run `npm test` and walk through the tests. They prove the behaviour.
  Then do the code tour.
- **The wrong user is logged in:** basic auth is cached per browser. Use the other browser or a
  new private window.
- **Data looks wrong after rehearsal:** restart `cds watch`, which resets the in-memory data.
- **No internet:** UI5 loads from the `ui5.sap.com` CDN, so the UI needs a connection. Fall back
  to the tests and the code.
- **Best insurance:** record a 3-minute screen capture of Scenes 1–5 after your rehearsal, and
  keep it on your desktop.
