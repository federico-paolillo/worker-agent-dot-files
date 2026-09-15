# AGENTS.md

## Your environment

- This is an Ubuntu VPS with 48 GiB RAM, 12 vCPUs, and 400 GiB disk.
- You run as the unprivileged `codex` user. Never use `sudo`, seek root access,
  or alter system configuration. Ask the user to make system-level changes and
  install system packages.
- Rootless Docker is available and user sessions linger through systemd.
- This host is Internet-facing. Never change firewall rules. Bind published
  Docker and Docker Compose ports to `127.0.0.1` only.
- Manage project runtimes and supported CLI versions through Mise, except Codex,
  which is installed with its official standalone installer.
- Prefer established language and framework idioms over custom solutions.
- Worker branches used hyphenated names like
  `codex/review-remediations-tooling-runtime` because Git cannot have both
  `codex/review-remediations` and `codex/review-remediations/<slice>`.

## Context7

Use the `ctx7` CLI to fetch current documentation whenever the user asks about a
library, framework, SDK, API, CLI tool, or cloud service -- even well-known ones
like React, Next.js, Prisma, Express, Tailwind, Django, or Spring Boot. This
includes API syntax, configuration, version migration, library-specific
debugging, setup instructions, and CLI tool usage. Use even when you think you
know the answer -- your training data may not reflect recent changes. Prefer
this over web search for library docs.

Do not use for: refactoring, writing scripts from scratch, debugging business
logic, code review, or general programming concepts.

### Steps

1. Resolve library: `ctx7 library <name> "<user's question>"` — use the official
   library name with proper punctuation (e.g., "Next.js" not "nextjs",
   "Customer.io" not "customerio", "Three.js" not "threejs")
2. Pick the best match (ID format: `/org/project`) by: exact name match,
   description relevance, code snippet count, source reputation (High/Medium
   preferred), and benchmark score (higher is better). If results don't look
   right, try alternate names or queries (e.g., "next.js" not "nextjs", or
   rephrase the question)
3. Fetch docs: `ctx7 docs <libraryId> "<user's question>"`
4. Answer using the fetched documentation

You MUST call `library` first to get a valid ID unless the user provides one
directly in `/org/project` format. Use the user's full question as the query --
specific and detailed queries return better results than vague single words. Do
not run more than 3 commands per question. Do not include sensitive information
(API keys, passwords, credentials) in queries.

For version-specific docs, use `/org/project/version` from the `library` output
(e.g., `/vercel/next.js/v14.3.0`).

If a command fails with a quota error, inform the user and suggest `ctx7 login`
or setting `CONTEXT7_API_KEY` for higher limits. Do not silently fall back to
training data. Run Context7 CLI requests outside Codex's default sandbox. If a
Context7 CLI command fails with DNS or network errors such as ENOTFOUND, host
resolution failures, or fetch failed, rerun it outside the sandbox instead of
retrying inside the sandbox.

## Herdr

Use Herdr only when the user explicitly requests it. Check `HERDR_ENV=1`, then
read and follow the `herdr` skill before controlling any pane or agent.

## Browser interaction

Use Playwright CLI for browser interaction. Read and follow the `playwright-cli`
skill first. Its fixed headless Ungoogled Chromium configuration must not be
changed; the browser is staged under `~/.local/bin/uchromium/152`.
