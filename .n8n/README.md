# n8n Workflow Templates

This directory contains n8n workflow templates for automating configuration synchronization.

## GitHub App Webhook → Workflow Dispatch

**File:** `github-app-webhook-to-workflow-dispatch.json`

This workflow automatically triggers the sync-to-repos GitHub Actions workflow when:

- A new repository installs the GitHub App
- Repositories are added to an existing installation

### How It Works

```text
GitHub App (installation webhook)
    ↓
n8n Webhook
    ↓ (filter: installation/installation_repositories events)
    ↓ (filter: created/added actions)
GitHub Node (dispatch event)
    ↓
GitHub Actions: sync-to-repos.yaml
    ↓
Target Repositories
```

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

#### 3. Configure GitHub App Webhook

1. Go to https://github.com/settings/apps/n8n-spruyt-labs
2. Under **Webhook**:
   - **Webhook URL:** Copy from n8n webhook node (Production URL)
   - **Active:** ✅ Enabled
3. Under **Permissions & events** → **Subscribe to events**:
   - ✅ **Installation**
   - ✅ **Installation repositories**
4. Save changes

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
