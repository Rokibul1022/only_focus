# Security Setup Guide

## Critical: Secure Your Credentials

This project has been configured to use environment variables for sensitive data. Follow these steps:

### 1. Google Services Configuration (Android)

The `google-services.json` file contains your Firebase configuration. This file:
- ✅ Is already in `.gitignore` (DO NOT remove this)
- ✅ Should remain in `android/app/` for local development
- ❌ Should NEVER be committed to public repositories

**If you've already committed it:**
1. Rotate your Firebase API keys in Firebase Console
2. Download a new `google-services.json`
3. Remove the file from git history: `git filter-branch --force --index-filter "git rm --cached --ignore-unmatch android/app/google-services.json" --prune-empty --tag-name-filter cat -- --all`

### 2. Groq API Key (Cloud Functions)

The Groq API key is now loaded from environment variables.

**Setup for Firebase Functions:**

```bash
cd functions
firebase functions:config:set groq.api_key="YOUR_ACTUAL_GROQ_API_KEY"
```

**For local development:**

1. Create a `.env` file in the `functions/` directory:
   ```bash
   cp .env.example .env
   ```

2. Add your actual Groq API key:
   ```
   GROQ_API_KEY=your_actual_groq_api_key_here
   ```

3. Install dotenv (if not already installed):
   ```bash
   npm install dotenv
   ```

4. The `.env` file is already in `.gitignore` - DO NOT commit it!

### 3. Verify Security

Before committing any code:

```bash
# Check what files will be committed
git status

# Ensure these files are NOT listed:
# - google-services.json
# - .env
# - Any files containing API keys
```

### 4. If Credentials Were Exposed

If you accidentally committed credentials:

1. **Immediately rotate all exposed keys:**
   - Firebase: Go to Firebase Console → Project Settings → Service Accounts
   - Groq: Go to Groq Console → API Keys → Regenerate

2. **Remove from git history** (use with caution):
   ```bash
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch path/to/sensitive/file" \
     --prune-empty --tag-name-filter cat -- --all
   ```

3. **Force push** (only if necessary and coordinated with team):
   ```bash
   git push origin --force --all
   ```

## Best Practices

- ✅ Use environment variables for all secrets
- ✅ Keep `.gitignore` updated
- ✅ Rotate keys regularly
- ✅ Use different keys for development and production
- ✅ Review code before committing
- ❌ Never hardcode credentials
- ❌ Never commit `.env` files
- ❌ Never share credentials in chat/email
