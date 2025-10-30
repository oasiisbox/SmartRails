# SmartRails

SmartRails is a lightweight command-line helper that runs small audits on an existing Ruby on Rails project. The current version ships with a single check that verifies that the provided directory looks like a Rails application.

## Installation

Clone the repository and install the gem locally:

```bash
git clone https://github.com/smartrails/smartrails.git
cd smartrails
bundle install
rake install
```

## Usage

Run the audit by providing the path to your Rails application. A plain-text report is printed by default. Use `--format json` to receive machine-readable output.

```bash
smartrails /path/to/rails/app
smartrails --format json /path/to/rails/app
```

The command exits with status code `0` when no issues are found, `2` when findings are detected, and `1` for invalid CLI usage.
