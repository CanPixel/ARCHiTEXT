# Contributing to Architext

Thank you for your interest in contributing to Architext! We welcome contributions from everyone.

## Getting Started

1.  **Fork the repository** on GitHub.
2.  **Clone your fork** locally:
    ```bash
    git clone https://github.com/CanPixel/architext.git
    cd architext
    ```
3.  **Set up the development environment**:
    ```bash
    ./bin/setup
    ```
    This script will install the necessary dependencies and ensure your environment is ready.

## Development Workflow

- **Run tests**: Before submitting a pull request, ensure all tests pass:
  ```bash
  bundle exec ruby test/obsctx_test.rb
  ```
- **Linting**: We use RuboCop to maintain code quality. Run it with:
  ```bash
  bundle exec rubocop
  ```
- **Create a branch**: Use a descriptive branch name for your changes:
  ```bash
  git checkout -b my-feature-name
  ```

## Pull Request Process

1.  Ensure your code follows the existing style and all tests pass.
2.  Update the `README.md` if your changes introduce new features or requirements.
3.  Submit a pull request to the `main` branch.
4.  Provide a clear description of your changes and why they are needed.

## Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.
