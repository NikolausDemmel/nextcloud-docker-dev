# Nextcloud Server/Core Development Guide

This guide covers developing and contributing to Nextcloud server core (not plugins). For plugin development, see `CLAUDE.md`.

## Overview

The Nextcloud server code is in the `workspace/` directory using git worktrees:

```
workspace/
├── server/          # Main repository (master branch)
├── stable31/        # stable31 branch worktree
├── stable30/        # stable30 branch worktree
└── ...
```

**Working with a specific version:**
```bash
cd workspace/stable31
git status
git branch
```

## Frontend Development

Nextcloud server includes Vue.js frontend code that must be built before changes take effect.

### Build Process

**Development build (fast, with source maps):**
```bash
cd workspace/stable31
npm run dev
```

**Production build (optimized, minified):**
```bash
npm run build
```

**Watch mode (auto-rebuild on changes):**
```bash
npm run watch
```

### Important Notes

- **Changes to `.vue` or `.js` files in `apps/*/src/` require rebuilding**
- Built files are output to `dist/` directory
- **Never commit built files (`dist/`) to git** - they are generated during build
- The build process uses webpack and takes ~10 seconds
- If dependencies change, run `npm ci` to clean install packages

### Frontend Code Locations

Common locations for frontend code:
- `apps/settings/src/` - Settings app Vue components
- `apps/files/src/` - Files app
- `core/src/` - Core Nextcloud UI components
- `apps/*/src/mixins/` - Reusable Vue mixins

**Example: Editing a settings component**
```bash
# 1. Edit the source file
vim apps/settings/src/mixins/UserRowMixin.js

# 2. Rebuild
npm run dev

# 3. Refresh browser to see changes
```

## Testing with Cypress

Nextcloud uses Cypress for E2E (end-to-end) testing of the UI.

### Running Cypress Tests

**Run all tests:**
```bash
cd workspace/stable31
npx cypress run
```

**Run specific test file:**
```bash
npx cypress run --e2e --spec "cypress/e2e/settings/users_groups_display_name.cy.ts" --browser chrome
```

**Run in CI mode (skips applying local changes):**
```bash
CI=true npx cypress run --e2e --spec "..." --browser chrome
```

**Open Cypress GUI (interactive mode):**
```bash
npx cypress open
```

### How Cypress Tests Work

1. **Fresh Container**: Cypress creates a fresh Docker container for each test run
2. **Applies Local Changes**: Without `CI=true`, Cypress copies your local code into the container
3. **Runs Tests**: Tests run against the containerized Nextcloud instance
4. **Cleanup**: Container is destroyed after tests complete

**Key Implications:**
- **No cleanup needed in tests** - each run gets a fresh container
- Use `CI=true` when testing against committed code (not local changes)
- Without `CI=true`, your uncommitted changes are copied into the test container
- Test containers run on `http://localhost:8083`

### Writing Cypress Tests

**Test file location:**
```
cypress/e2e/settings/my_test.cy.ts
```

**Basic test structure:**
```typescript
import { User } from '@nextcloud/cypress'
import { getUserListRow, toggleEditButton } from './usersUtils'

const admin = new User('admin', 'admin')

describe('My Feature Test', () => {
	let testUser: User

	before(() => {
		cy.createRandomUser().then((user) => {
			testUser = user
		})
		cy.login(admin)
		cy.visit('/settings/users')
	})

	// No after() hook needed - container is destroyed automatically

	it('Does something', () => {
		// Test implementation
	})
})
```

**Important Testing Patterns:**

1. **No cleanup hooks needed** - Cypress uses fresh containers
2. **Use cy.runOccCommand()** for OCC commands
3. **Use cy.createRandomUser()** instead of manual user creation
4. **Intercept API calls** with `cy.intercept()` for waiting
5. **Get actual displayed text** with `.invoke('text')` to avoid timeouts

**Example: Testing with long group names**
```typescript
// Long group names get hashed to create group ID
const groupName = `Test Group with Very Long Name ${randomString(80)}`
cy.runOccCommand(`group:add '${groupName}'`)

// Verify group ID !== display name
cy.runOccCommand('group:list --output=json').then((result) => {
	const groups = JSON.parse(result.stdout)
	// Group ID will be a hash, display name will be the full name
	expect(groupId).to.not.equal(displayName)
})
```

## Dependencies and Package Management

**Clean install (recommended after pulling changes):**
```bash
npm ci
```

**Install/update packages:**
```bash
npm install
```

**Check for outdated packages:**
```bash
npm outdated
```

**Notes:**
- `npm ci` installs packages locally to `node_modules/` (not globally)
- Package lock file is `package-lock.json`
- After dependency changes, rebuild with `npm run dev`

## Contributing to Nextcloud Server

### Commit Requirements

Nextcloud requires specific commit formatting:

**1. Conventional Commits:**
```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:** `fix`, `feat`, `docs`, `style`, `refactor`, `test`, `chore`

**Example:**
```
fix(settings): Initialize group display names from store

When editing a user, if groups have display names different from their
IDs (e.g., long group names that get hashed), the group selector was
showing the group ID instead of the display name after page reload.

Fixes #55785
```

**2. Developer Certificate of Origin (DCO):**

Every commit must be signed off with `-s` flag:
```bash
git commit -s -m "fix(settings): Description"
```

This adds:
```
Signed-off-by: Your Name <your.email@example.com>
```

**3. SPDX License Headers:**

New files require SPDX license headers:
```javascript
/**
 * SPDX-FileCopyrightText: 2025 Nextcloud GmbH and Nextcloud contributors
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
```

For existing files with generic headers, add yourself to `AUTHORS.md` instead.

### Creating a Pull Request

**Using gh CLI (recommended):**

```bash
# 1. Ensure changes are committed
git commit -s -m "fix(settings): Description"

# 2. Create fork and push (gh handles this automatically)
gh pr create --draft --base stable31 --title "fix(settings): Title" --body "Description"
```

**Manual process:**

```bash
# 1. Create a fork on GitHub (if you don't have one)
gh repo fork nextcloud/server --clone=false

# 2. Add fork as remote
git remote add fork git@github.com:YourUsername/server.git

# 3. Push your branch
git push fork stable31:my-feature-branch

# 4. Create PR via GitHub UI or:
gh pr create --draft --base stable31 --head YourUsername:my-feature-branch
```

### Development Workflow Example

**Full workflow for fixing a bug:**

```bash
# 1. Navigate to the correct version
cd workspace/stable31

# 2. Create/edit source files
vim apps/settings/src/mixins/UserRowMixin.js

# 3. Rebuild frontend
npm run dev

# 4. Test manually in browser
# Visit http://stable31.local

# 5. Write/update Cypress test
vim cypress/e2e/settings/my_test.cy.ts

# 6. Run test to verify fix
npx cypress run --e2e --spec "cypress/e2e/settings/my_test.cy.ts"

# 7. Verify test fails without fix
# (Temporarily revert changes, rebuild, run test, then restore)

# 8. Commit with DCO sign-off
git add apps/settings/src/mixins/UserRowMixin.js
git commit -s -m "fix(settings): Description

Detailed explanation of the fix.

Fixes #12345"

# 9. Commit test separately
git add cypress/e2e/settings/my_test.cy.ts
git commit -s -m "test(settings): Add regression test for issue #12345"

# 10. Push and create PR
gh pr create --draft --base stable31
```

## Common Gotchas

1. **Forgot to rebuild after code changes**
   - Symptom: Changes don't appear in browser
   - Fix: Run `npm run dev`

2. **Committed dist/ files**
   - Symptom: Huge diffs in PR with binary files
   - Fix: Unstage with `git reset dist/`, rebuild is done by CI

3. **Cypress test passes even without fix**
   - Symptom: Test doesn't catch the bug
   - Fix: Verify test scenario actually triggers the bug condition

4. **Test cleanup hooks failing**
   - Symptom: Tests fail in `after()` or `afterEach()` hooks
   - Fix: Remove cleanup hooks - Cypress uses fresh containers

5. **Forgot DCO sign-off**
   - Symptom: PR checks fail with "DCO check failed"
   - Fix: Amend commit with `git commit --amend -s`

6. **CI=true blocks testing local changes**
   - Symptom: Cypress tests don't see your local code changes
   - Fix: Run without `CI=true` to test uncommitted changes

## Key Differences from Plugin Development

| Aspect | Plugin Development | Server/Core Development |
|--------|-------------------|------------------------|
| Code Location | `data/apps-extra/user_vo/` | `workspace/stable31/apps/` |
| Changes Take Effect | Immediately | After `npm run dev` |
| Testing | Manual + custom tests | Cypress E2E tests |
| Build Process | Not needed | Required for frontend |
| Commit Requirements | None (your repo) | DCO + Conventional Commits |
| Distribution | Package as tar.gz | Merged into core |

## References

- [Nextcloud Developer Portal](https://nextcloud.com/developer/)
- [Cypress Documentation](https://docs.cypress.io/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [DCO Information](https://developercertificate.org/)
