# Google Cloud setup

Optional. You need this only if you deploy Cloud Functions through the Blueprint overlay's
deployment workflow. If you do not deploy to Google Cloud, skip this guide entirely — the
core kit has no cloud dependency.

Placeholders look like `<this>` — replace the whole thing, brackets included.

> **Quote your `--format` arguments.** `--format='value(name)'` works. `--format=value(name)`
> fails in both zsh and bash, because the shell tries to interpret the parentheses before
> gcloud ever sees them. Every command below is already quoted correctly.

---

## 1. Account

You need a Google account and a Google Cloud project. Projects that deploy anything need
**billing enabled** — Cloud Functions has a free tier, but the project still has to be
attached to a billing account to deploy at all.

If your organization already has a billing account, ask an administrator to grant you the
Billing Account User role rather than creating your own.

---

## 2. Authentication

Install the SDK:

```
brew install --cask google-cloud-sdk
```

Two separate logins, and both matter:

```
gcloud auth login
gcloud auth application-default login
```

*(both syntax verified, not executed — each requires an interactive browser login.)*

The first authenticates the `gcloud` command itself. The second writes Application Default
Credentials, which is what client libraries use when your code runs locally. Doing only
the first is a common source of "it works in the shell but the code says unauthenticated".

Confirm the active account:

```
gcloud auth list --format='value(account)'
```

And confirm the token actually mints — presence of an account is not proof it still works,
since credentials expire:

```
gcloud auth print-access-token
```

The deployment workflow runs exactly this check before it touches anything, and stops if
it fails.

---

## 3. Minimum configuration

### Create or select a project

```
gcloud projects create <your-project-id> --name="<Your Project Name>"
```

*(syntax verified, not executed — it creates a real cloud resource.)*

The project ID is globally unique across all of Google Cloud, permanent, and cannot be
renamed later. Lowercase letters, digits, and hyphens.

Set it as your default so later commands do not need `--project`:

```
gcloud config set project <your-project-id>
```

Confirm:

```
gcloud config get-value project
```

### Attach billing

Find your billing account ID:

```
gcloud billing accounts list
```

*(syntax verified, not executed — output contains real billing identifiers.)*

Then link it:

```
gcloud billing projects link <your-project-id> --billing-account=<your-billing-account-id>
```

*(syntax verified, not executed — it changes billing state.)*

### Enable only the services these workflows use

```
gcloud services enable cloudfunctions.googleapis.com run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com
```

*(syntax verified, not executed — it changes project state.)*

Four services, and no more:

| Service | Why the workflow needs it |
|---|---|
| `cloudfunctions.googleapis.com` | The functions themselves |
| `run.googleapis.com` | 2nd-gen functions run on Cloud Run, and IAM policy is read there |
| `cloudbuild.googleapis.com` | Builds the container on deploy |
| `artifactregistry.googleapis.com` | Stores the built image |

These four IDs were confirmed against a project that actually runs these deployments.
Enabling more than you need widens the surface for no benefit.

---

## 4. Verification

Run these four. All should succeed:

```
gcloud auth list --format='value(account)'
gcloud config get-value project
gcloud auth print-access-token
gcloud services list --enabled --format='value(config.name)'
```

The first two show who and where. The third proves the credential is live rather than
merely present — this is the one that catches expired credentials, and it is the check the
deployment workflow itself performs. The fourth should list the four services above.

If `gcloud auth print-access-token` fails, re-run `gcloud auth login`. Expired credentials
are the single most common cause of a deploy stopping before it starts.

---

## Command provenance

| Command | Status |
|---|---|
| `gcloud --version` | executed |
| `gcloud auth list --format='value(account)'` | executed |
| `gcloud config get-value project` | executed |
| `gcloud auth print-access-token` | executed |
| `gcloud projects list --limit=1 --format='value(projectId)'` | executed |
| `gcloud services list --enabled --format='value(config.name)'` | executed |
| `gcloud config list --format='value(core.account)'` | executed |
| `gcloud functions deploy` | syntax verified — deploys a real resource |
| `gcloud run services get-iam-policy` | syntax verified |
| `gcloud projects create` | syntax verified — creates a real resource |
| `gcloud billing accounts list` | syntax verified — output carries real billing IDs |
| `gcloud billing projects link` | syntax verified — changes billing state |
| `gcloud services enable` | syntax verified — changes project state |
| `gcloud auth login`, `gcloud auth application-default login` | syntax verified — interactive browser login |
| `gcloud config set project` | syntax verified — writes local config |
| `brew install --cask google-cloud-sdk` | not executed — already installed on the verifying machine |
