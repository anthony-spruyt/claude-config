# n8n Workflow Templates

This directory contains n8n workflow templates for automating configuration synchronization.

## GitHub App Webhook → Workflow Dispatch

**File:** `github-app-webhook-to-workflow-dispatch.json`

This workflow automatically triggers the sync-to-repos GitHub Actions workflow when:

- A new repository installs the GitHub App (`installation.created`)
- Repositories are added to an existing installation (`installation_repositories.added`)
- A user checks the "Request sync now" checkbox in the dashboard issue (`issues.edited`)

### How It Works

```text
GitHub App Webhook
    ↓
n8n Webhook (receives all events)
    ↓
Route Events (Switch node)
    ├─→ installation.created    → Extract Repos (Created)  ─┐
    ├─→ installation_repos.added → Extract Repos (Added)    ├─→ Trigger Workflow Dispatch
    └─→ issues.sync_requested   → Extract Repo (Issue)     ─┘        (with target_repos)
                                                                          ↓
                                                               GitHub Actions: sync-to-repos.yaml
                                                                          ↓
                                                                   Target Repositories
```

### Event Routing

| Event Type                  | Action    | Trigger Condition           | target_repos                            |
| --------------------------- | --------- | --------------------------- | --------------------------------------- |
| `installation`              | `created` | New app installation        | All repos from `repositories[]`         |
| `installation_repositories` | `added`   | Repos added to installation | Repos from `repositories_added[]`       |
| `issues`                    | `edited`  | Dashboard checkbox checked  | Single repo from `repository.full_name` |

**Issues event filtering:**

- Issue title contains "Claude Config Sync Dashboard"
- Issue body contains `[x] **Request sync now**`

### Setup Instructions

#### 1. Configure GitHub OAuth2 Credential in n8n

1. In n8n, go to **Credentials** → **Add Credential**
2. Select **GitHub OAuth2 API**
3. Enter:
   - **Client ID:** From your GitHub App (`n8n-spruyt-labs`)
   - **Client Secret:** From your GitHub App
4. Click **Connect** and authorize
5. Save as `GitHub OAuth2`

#### 2. Import Workflow

1. Click **Workflows** → **Add Workflow** → **Import from File**
2. Select `github-app-webhook-to-workflow-dispatch.json`
3. Click **Import**

#### 3. Configure Claude Config Sync GitHub App

1. Go to your Claude Config Sync GitHub App settings
2. Under **Webhook**:
   - **Webhook URL:** Copy from n8n webhook node (Production URL)
   - **Active:** ✅ Enabled
3. Under **Permissions**:
   - **Repository permissions → Issues:** Read and write
4. Under **Permissions & events** → **Subscribe to events**:
   - ✅ **Installation**
   - ✅ **Installation repositories**
   - ✅ **Issues** (for dashboard sync requests)
5. Save changes

#### 4. Activate Workflow

Toggle the workflow to **Active** in n8n.

### Testing

Install the GitHub App on a test repository and check:

1. n8n **Executions** tab for successful run
2. GitHub Actions for triggered `sync-to-repos.yaml` workflow

### Troubleshooting

**Webhook not triggering:**

- Check webhook URL in GitHub App settings
- Verify workflow is Active in n8n
- Check GitHub App → Advanced → Recent Deliveries

**Workflow dispatch fails:**

- Verify OAuth2 credential is connected
- Check GitHub App has `actions:write` permission
