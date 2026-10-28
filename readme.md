# BP Governance: Business Partner change requests on SAP BTP

> **Status: demo on SAP BTP trial, not production.** This is a portfolio exercise. It runs on a
> free trial subaccount, keeps its data in in-memory SQLite (data resets on every restart), and
> reads Business Partners from the SAP Business Accelerator Hub *sandbox*, not from a real S/4HANA system.

An MDG-style approval flow for Business Partner master data, built with the SAP Cloud Application
Programming Model (CAP, Node.js) and a Fiori elements UI. Requesters draft and submit change
requests (create / update / block a BP). Approvers approve or reject them, under the four-eyes
principle. A BP number on an update or block request is checked live against the S/4HANA
Business Partner API.

## What this demonstrates

| Topic | Where |
|---|---|
| CDS domain model (`cuid`, `managed`, code lists) | [db/schema.cds](db/schema.cds) |
| Role-based and instance-based authorization with `@restrict` (`where: 'createdBy = $user'`) | [srv/governance-service.cds](srv/governance-service.cds) |
| Remote entity from `API_BUSINESS_PARTNER` (OData V2), delegated in a custom handler | [srv/external/](srv/external/), [srv/governance-service.js](srv/governance-service.js) |
| Bound actions, a status workflow, the four-eyes check, validation against the remote API on draft activation | [srv/governance-service.js](srv/governance-service.js) |
| Fiori elements list report and object page, driven entirely by annotations (value help on the remote entity, criticality, `OperationAvailable`, side effects) | [app/changerequests/annotations.cds](app/changerequests/annotations.cds) |
| Automated service tests with `cds.test` (14 tests: auth, workflow, remote validation) | [test/governance-service.test.js](test/governance-service.test.js) |
| XSUAA scopes, role templates and **role collections** | [xs-security.json](xs-security.json) |
| Standalone approuter (login, static UI, `/odata` forwarding) | [app/router/xs-app.json](app/router/xs-app.json) |
| MTA build and deploy (`mbt build` + `cf deploy`) | [mta.yaml](mta.yaml) |
| CI/CD with Azure Pipelines (test → build MTA → deploy) | [azure-pipelines.yml](azure-pipelines.yml) |

## Architecture

```
Browser ──► approuter (XSUAA login, serves Fiori app) ──/odata──► CAP service ──► in-memory SQLite
                                                                     │
                                                                     └─► Destination "API_BUSINESS_PARTNER"
                                                                           └─► API Hub sandbox (S/4HANA Cloud BP API)
```

Roles: `Requester` (create; read, edit and submit **own** requests) and `Approver` (read all;
approve or reject, never their own). On BTP they come in through the role collections
`BPGov_Requester`, `BPGov_Approver` and `BPGov_DataSteward` (both roles).

## Run locally

Requires Node.js 22.

```bash
npm ci
npm run watch
```

Open <http://localhost:4004/changerequests/webapp/index.html> and log in as one of the mock users.
The password is the same as the user name:

| User | Roles | Sees |
|---|---|---|
| `alice` | Requester | only their own 2 requests |
| `carol` | Requester | only their own request |
| `bob` | Approver | all requests, can approve or reject |
| `dave` | Requester + Approver | can submit, but cannot approve their own request (four-eyes) |

Locally, `API_BUSINESS_PARTNER` is mocked in-process from
[db/data/API_BUSINESS_PARTNER-A_BusinessPartner.csv](db/data/API_BUSINESS_PARTNER-A_BusinessPartner.csv).

### Tests

```bash
npm test
```

## Import the remote API

`srv/external/API_BUSINESS_PARTNER.cds` was generated with `cds import` from the EDMX specification
on the SAP Business Accelerator Hub. The source EDMX sits next to it. To refresh it:

1. Log in to <https://api.sap.com>, open **Business Partner (A2X)** (`API_BUSINESS_PARTNER`) and
   download the **EDMX** specification.
2. Re-import it:
   ```bash
   cds import API_BUSINESS_PARTNER.edmx --as cds --force
   ```
3. To call the live sandbox locally, copy your API key (api.sap.com → *Show API Key*) into
   `.cdsrc-private.json`. That file is git-ignored:
   ```json
   { "[sandbox]": { "requires": { "API_BUSINESS_PARTNER": {
       "credentials": { "headers": { "APIKey": "<your key>" } } } } } }
   ```
   then run `npm run watch:sandbox`. Save the file as UTF-8 **without** a BOM. Windows PowerShell 5.1's
   `Set-Content -Encoding utf8` adds a BOM, and CAP then fails to parse the file.

## Deploy to the BTP trial

Prerequisites: a BTP trial subaccount with Cloud Foundry enabled, the
[cf CLI v8](https://github.com/cloudfoundry/cli) with the MultiApps plugin
(`cf install-plugin multiapps -r CF-Community`), and on Windows, GNU make for `mbt`
(`winget install ezwinports.make`).

```bash
npm ci
npx mbt build
cf login -a https://api.cf.us10-001.hana.ondemand.com
cf deploy mta_archives/bp-governance_1.0.0.mtar
```

Then, in the BTP cockpit:

1. **Role collections.** Go to *Security → Role Collections*, open `BPGov_Requester` /
   `BPGov_Approver` / `BPGov_DataSteward` and add your user. Log out and back in to get a new token.
2. **Destination.** Go to *Connectivity → Destinations* (subaccount level) and create:
   - Name `API_BUSINESS_PARTNER`, Type `HTTP`, URL `https://sandbox.api.sap.com`,
     Proxy `Internet`, Authentication `NoAuthentication`
   - Additional property `URL.headers.APIKey` = your API Hub key
3. Open the approuter's URL (`cf app bp-governance` shows it).

## CI/CD: Azure Pipelines

[azure-pipelines.yml](azure-pipelines.yml) runs `npm test`, builds the MTA, publishes it as a
pipeline artifact and, on `main` only, deploys it with `cf deploy`.

Setup:

1. Push this folder to an Azure Repos (or GitHub) repository and create a pipeline from the YAML.
2. *Pipelines → Library*: create the variable group **`btp-trial`** with `CF_API`, `CF_ORG`,
   `CF_SPACE`, `CF_USERNAME` and `CF_PASSWORD` (mark it secret).
3. *Pipelines → Environments*: create **`btp-trial`** (you can add a manual approval check here).
4. **Agent.** New Azure DevOps organisations must request the free Microsoft-hosted parallel-job
   grant, and approval can take a few business days. So the pipeline uses a **self-hosted agent**
   in pool `Default`. Install it on your PC (*Project settings → Agent pools → Default → New agent*,
   then run `config.cmd` and `run.cmd`). The machine needs Node.js 22, Git, the cf CLI and GNU make.
   Once the grant is approved, change `pool` to `vmImage: ubuntu-latest`.

`cf auth` reads `CF_USERNAME` / `CF_PASSWORD` from the environment, so the password never appears
on a command line. This works for a trial user logging in with an SAP ID password. A user with
2FA or a custom IdP would need a technical user instead.

## Design decisions and limitations

- **In-memory SQLite instead of HANA Cloud.** HANA Cloud on trial stops every night and has to be
  restarted. For a demo the app ships on SQLite (`:memory:`) and reloads its seed data from
  `srv/data/*.csv` on each start. The build copies the CSVs there with
  [scripts/copy-initial-data.js](scripts/copy-initial-data.js), because `cds build` doesn't.
  **All change requests are lost when the app restarts.** To switch to HANA: `cds add hana`, add an
  `hdi-shared` resource and a db-deployer module to `mta.yaml`, and drop the `db` override in
  `package.json`.
- **Standalone approuter**, not the managed approuter / HTML5 repository / SAP Build Work Zone.
  It keeps the trial setup to two services (XSUAA and destination).
- **Remote BP data is read-only** here. Approving a request only changes its status. It does not
  write back to S/4HANA. In a real MDG scenario the activation step would replicate to the target
  system.
- **Dependencies.** `@sap/approuter` 23.3.0 (latest at the time of writing) still bundles a
  `body-parser` version with an open DoS advisory (`npm audit` in `app/router`). The app's own
  runtime dependencies have no audit findings.
