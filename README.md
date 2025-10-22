# Phaset Action (alpha)

This Action allows you to push a service catalog record and standards (checks) results to your self-hosted Phaset instance.

## Setup and usage

You need to configure your self-hosted Phaset endpoint and set a required secret for an API key, then you are greenlit to just start using the action!

### Updating the record

The record (service catalog) step requires you to have a `phaset.manifest.json` file on disk.

Please see the [Catalogist documentation](https://github.com/mikaelvesavuori/catalogist#manifest) for more details.

### Running the standards check

For the standards check to run and results to be sent, the [Baseline](https://docs.phaset.dev/knowledge-base/baselines/) connected to the Record will be fetched and used. If one is not defined, the default Baseline will be used.

Please see the [StandardLint documentation](https://github.com/mikaelvesavuori/standardlint#configuration) for more details.

### Security

Always ensure you have secure settings regarding what actions you allow.

## Required input arguments

### `api-key`

Phaset API key.

### `endpoint`

Your self-hosted Phaset API endpoint URL. This should be the base integration endpoint, typically ending in `/integration`.

**Example:** `https://phaset.example.com/integration`

## Optional input arguments

### `org-id`

Organization ID. If not provided, will be inferred from the `phaset.manifest.json` file.

### `record-id`

Record ID. If not provided, will be inferred from the `phaset.manifest.json` file.

### `working-directory`

Working directory containing the manifest (relative to repo root). Defaults to `.` (root).

### `run-record`

Whether to update the record (manifest file). Defaults to `true`.

### `run-standards`

Whether to update the standards. Defaults to `true`.

### `run-deployment`

Whether to run the deployment script. Defaults to `false`.

## Example of how to use this action in a workflow

```yml
on: [push]

jobs:
  phaset:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      # Do your things here: build, test, deploy...

      - name: Run Phaset action (alpha)
        uses: phaset/phaset-alpha@v0
        with:
          endpoint: https://phaset.example.com/integration
          api-key: ${{ secrets.PHASET_API_KEY }}
          org-id: 'demoorg'
          record-id: 'demorecord'
          working-directory: 'apps/frontend' # Optional, otherwise root

      # Repeat any number of times if this is a monorepo or other context with multiple manifests
```

## Example with deployment tracking

```yml
on:
  push:
    branches:
      - main

jobs:
  deploy-and-track:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      # Your deployment steps here...

      - name: Track deployment in Phaset
        uses: phaset/phaset-alpha@v0
        with:
          endpoint: https://phaset.example.com/integration
          api-key: ${{ secrets.PHASET_API_KEY }}
          org-id: 'demoorg'
          record-id: 'demorecord'
          run-deployment: 'true'
```
