# Repository Expectations

- Use Conventional Commits: https://www.conventionalcommits.org/en/v1.0.0/
- Always include a commit body with a summary of what changed as a list of items.
- Instructions to build the project are on the README.md file
- Consult `docs/DECISIONS.md` for project context and add new durable project decisions there.
- Run `make verify` for F*/spec changes, run `make extract` for extraction-relevant executable code, dependency, toolchain, or KaRaMeL configuration changes, and run the C smoke gates when generated C boundary/linkage changes.
- Keep the trusted-boundary inventory in `docs/THREAT_MODEL.md` current when adding or removing mocks, admissions, assumptions, or unverified adapters.
