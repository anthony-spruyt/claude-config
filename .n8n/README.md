# n8n Workflow Templates

This directory contains n8n workflow templates for automating configuration synchronization.

## GitHub App Webhook → Workflow Dispatch

**File:** `github-app-webhook-to-workflow-dispatch.json`

This workflow automatically triggers the sync-to-repos GitHub Actions workflow when:

- A new repository installs the GitHub App
- Repositories are added to an existing installation

### How It Works

1. **Webhook Trigger** - Receives POST requests from GitHub App webhooks
2. **Event Filtering** - Filters for `installation` and `installation_repositories` events
3. **Action Filtering** - Only processes `created` actions (new installs/repos)
4. **Workflow Dispatch** - Triggers the GitHub Actions `sync-to-repos.yaml` workflow
5. **Response** - Returns success confirmation to GitHub

### Setup Instructions

#### 1. Import Workflow to n8n

1. Open your n8n instance
2. Click **Workflows** → **Add Workflow** → **Import from File**
3. Select `github-app-webhook-to-workflow-dispatch.json`
4. Click **Import**

#### 2. Configure Environment Variables

In n8n Settings → Environment Variables, add:

```bash
GITHUB_OWNER=your-github-username
GITHUB_REPO=claude-config
```

#### 3. Configure GitHub Credentials

1. In n8n, go to **Credentials** → **Add Credential**
2. Select **GitHub API**
3. Enter:
   - **Name:** `GitHub PAT`
   - **Access Token:** Create a GitHub Personal Access Token with `repo` and `workflow` scopes
4. Save the credential

#### 4. Get Webhook URL

1. Open the imported workflow
2. Click the **GitHub App Webhook** node
3. Copy the **Production URL** (e.g., `https://n8n.example.com/webhook/github-app-installation`)

#### 5. Configure GitHub App Webhook

1. Go to your GitHub App settings: `https://github.com/settings/apps/<your-app>/advanced`
2. Under **Webhook**:
   - **Webhook URL:** Paste the n8n production URL
   - **Webhook secret:** (optional) Leave blank or configure in n8n webhook node
3. Under **Subscribe to events**, enable:
   - ✅ **Installation**
   - ✅ **Installation repositories**
4. Click **Save changes**

#### 6. Activate Workflow

1. In n8n, click the workflow's **Active** toggle to enable it
2. The workflow is now live and will trigger on new installations

### Testing

#### Test with GitHub App Installation

1. Install the GitHub App on a new repository
2. Check n8n **Executions** tab for successful workflow run
3. Check GitHub Actions for the triggered `sync-to-repos.yaml` workflow

#### Manual Test

Use curl to simulate a GitHub webhook:

```bash
curl -X POST https://n8n.example.com/webhook/github-app-installation \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: installation" \
  -d '{
    "action": "created",
    "installation": {
      "id": 12345,
      "account": {
        "login": "username"
      }
    }
  }'
```

### Troubleshooting

**Webhook not triggering:**

- Verify webhook URL is correct in GitHub App settings
- Check n8n workflow is **Active**
- Review GitHub App webhook delivery logs: `Settings → Apps → Advanced → Recent Deliveries`

**Workflow dispatch fails:**

- Verify GitHub PAT has `repo` and `workflow` scopes
- Check environment variables are set correctly
- Ensure workflow file exists: `.github/workflows/sync-to-repos.yaml`

**Authentication errors:**

- Regenerate GitHub PAT and update in n8n credentials
- Verify PAT hasn't expired

### Architecture

```text
GitHub App
    ↓ (webhook on installation/installation_repositories)
n8n Webhook Node
    ↓ (filter events)
Filter Installation Events
    ↓ (filter actions)
Filter Relevant Actions
    ↓ (POST request)
GitHub API (workflow_dispatch)
    ↓ (triggers)
GitHub Actions: sync-to-repos.yaml
    ↓ (syncs .claude/ to all repos)
Target Repositories
```

### Security Notes

- The webhook is public by default - consider adding webhook signature validation
- Store GitHub PAT securely in n8n credentials (encrypted at rest)
- Use environment variables for configuration (not hardcoded values)
- Review n8n execution logs regularly for unauthorized access attempts

### Customization

To modify which events trigger the sync:

1. Edit **Filter Installation Events** node
2. Add/remove conditions in the filter logic
3. Save and test

Common modifications:

- Add webhook signature validation (GitHub webhook secret)
- Add Slack/Discord notification on successful sync
- Log events to external monitoring service
