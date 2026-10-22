# Contributing

Thank you for your interest in contributing to the Android AI Engineering System.

## How to Contribute

### Reporting Issues

- Use GitHub Issues to report bugs or request features
- Include steps to reproduce, expected vs. actual behavior, and your environment details
- For security vulnerabilities, see [SECURITY.md](SECURITY.md)

### Submitting Changes

1. Fork the repository
2. Create a feature branch from `main` (`git checkout -b feature/your-feature`)
3. Make your changes following the conventions below
4. Test your changes locally
5. Commit with a clear message describing the change
6. Open a Pull Request against `main`

### Conventions

- **Skills**: each skill lives in `skills/<skill-name>/` with a `SKILL.md` entry point, `references/` for detailed guides, and optionally `examples/`
- **Scripts**: PowerShell scripts go in `scripts/`; use `param()` blocks and include `-WhatIf` / dry-run support where possible
- **Examples**: working example apps go in `examples/<app-name>/` with source only (no build artifacts, no `node_modules/`)
- **Documentation**: Markdown files use ATX headings (`#`), fenced code blocks with language tags, and relative links
- **Secrets**: never hardcode credentials — use environment variables and `.env.example` templates

### Code Style

- **Kotlin**: follow [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html)
- **TypeScript**: use strict mode, prefer `const` over `let`
- **PowerShell**: use approved verbs (`Get-`, `Set-`, `New-`, etc.)

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
