# 🔐 Purging Secrets from Git History

Because the sensitive files (`google-services.json`, `GoogleService-Info.plist`,
`firebase_options.dart`) were previously committed, their values exist in your
git history even after removing them from the current working tree.

**You must purge the history before making the repo public.**

---

## Option A — git-filter-repo (recommended)

Install:

```bash
pip install git-filter-repo
```

Remove each sensitive file from history:

```bash
git filter-repo --path android/app/google-services.json --invert-paths
git filter-repo --path ios/Runner/GoogleService-Info.plist --invert-paths
git filter-repo --path lib/firebase_options.dart --invert-paths
```

Then force-push:

```bash
git push origin --force --all
git push origin --force --tags
```

---

## Option B — BFG Repo Cleaner (simpler UI)

Download from: https://rtyley.github.io/bfg-repo-cleaner/

```bash
# Delete specific files from all commits
java -jar bfg.jar --delete-files google-services.json
java -jar bfg.jar --delete-files GoogleService-Info.plist
java -jar bfg.jar --delete-files firebase_options.dart

# Clean up and push
git reflog expire --expire=now --all && git gc --prune=now --aggressive
git push origin --force --all
```

---

## After purging

1. Re-add your `.gitignore` entries (if filter-repo reset it).
2. Confirm the files no longer appear in history:
   ```bash
   git log --all --full-history -- android/app/google-services.json
   # Should return nothing
   ```
3. **Rotate your API keys** (even after purging — treat them as compromised):
   - Firebase Android key: Google Cloud Console → APIs & Services → Credentials
   - Firebase iOS key: Google Cloud Console → APIs & Services → Credentials
   - OpenAI key: platform.openai.com/api-keys → delete old, create new
   - AWS keys: IAM → Users → Security credentials → deactivate old, create new

---

## Notify any existing collaborators

Force-pushing rewrites history. Anyone who has cloned the repo will need to
re-clone rather than pull:

```bash
git clone https://github.com/your-org/langreels_ai.git
```

---

<div align="center">

[← Back to README](./README.md) · [Fork & setup](./FORK_AND_SETUP.md)

</div>
