<!-- ~/COMMITS.md  gem install aigcm -->

The JIRA ticket reference should be the first thing mentioned in the commit message.
It is useually the basename of the repository root. The repository root is
found in the system environment variable $RR.

A Git commit message includes:

1. **Subject line**: starts with the JIRA ticket and is 50 characters or less, imperative mood.
  - Example: `Fix bug in user login`

2. **Body** (optional): Explain the "why" and "how", wrapped at 72 characters.
  <example>
  This commit fixes the login issue that occurs when the user
  enters incorrect credentials. It improves error handling and
  provides user feedback.
  </example>

  The body should also include bullet points for each change made.

3. **Footer** (optional): Reference issues or breaking changes.
  <example> Closes #123 </example>
  <example> BREAKING CHANGE: API changed </example>
