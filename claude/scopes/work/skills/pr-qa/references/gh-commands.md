# GitHub CLI Commands Reference for QA

## Repos Configures

| Alias | Repository |
|-------|------------|
| frontend | ForestAdmin/forestadmin |
| backend | ForestAdmin/forestadmin-server |
| agent | ForestAdmin/agent-nodejs |
| zendesk | ForestAdmin/forest-for-zendesk |

## Fetching PR Data

### Get PR Metadata
```bash
gh pr view <PR_ID> --repo ForestAdmin/forestadmin-server --json title,body,author,files,additions,deletions,baseRefName,headRefName,number,url,commits,labels
```

### Get PR Diff
```bash
gh pr diff <PR_ID> --repo ForestAdmin/forestadmin-server
```

### Get PR Comments and Reviews
```bash
gh pr view <PR_ID> --repo ForestAdmin/forestadmin-server --json comments,reviews
```

Useful for understanding:
- Discussions around implementation choices
- Concerns raised by reviewers
- Edge cases already identified

### Get Linked Issues
```bash
gh pr view <PR_ID> --repo ForestAdmin/forestadmin-server --json body | jq -r '.body' | grep -oE '#[0-9]+'
```

### Get PR Checks Status
```bash
gh pr checks <PR_ID> --repo ForestAdmin/forestadmin-server
```

Verify which automated tests passed/failed.

## Useful Queries

### List Modified Files
```bash
gh pr view <PR_ID> --repo ForestAdmin/forestadmin-server --json files --jq '.files[].path'
```

### Get File Content at PR Head
```bash
gh api repos/ForestAdmin/forestadmin-server/contents/<path>?ref=<branch> --jq '.content' | base64 -d
```

### Compare with Base Branch
```bash
gh api repos/ForestAdmin/forestadmin-server/compare/<base>...<head> --jq '.files[].filename'
```
