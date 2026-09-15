# Verbatim patterns from ~/work/docs

Extracts from the live corpus. Imitate the shape, not the subject.

## Openings

`product/build/layout-editor.mdx`

> The Layout Editor is employer's visual customization tool. It lets you control
> exactly what your operators see and how data is presented, which columns appear
> in tables, how detail views are organized, and how create/edit forms are
> structured.

`get-started/quickstart.mdx`

> You'll have a working employer back-end connected to your database, with the
> employer UI open and ready to configure, in about 15 minutes.

`get-started/deploy.mdx`

> So far you've been working locally. This step covers deploying your employer
> back-end to production and understanding how employer's development workflow
> keeps your environments in sync.

`reference/overview.mdx`

> Technical reference for everything programmable in employer, the agent SDKs, the
> public API, the employer CLI, and the `.employer-schema.json` format.

## The comma appositive

> Inboxes let your team manage tasks and review queues, records that need
> attention, approvals waiting, issues to resolve.

> This is how queue handoffs work, one operator starts a case, leaves it for
> review, another picks it up.

> **Show/hide collections**, click the eye icon next to a collection to toggle
> it.

## A `get-started` step page

```mdx
---
title: "Quickstart"
description: "Get your employer back-end running locally in 15 minutes."
---

You'll have a working employer back-end connected to your database, with the employer UI open and ready to configure, in about 15 minutes.

## Prerequisites

- Node.js 18+ installed
- Your database URI ready (PostgreSQL, MySQL, MongoDB, SQL Server, etc.)
- A employer account ([sign up](https://app.employer.com/signup) if needed)

## Steps

<Steps>
  <Step title="Create a new project">
    Go to [app.employer.com](https://app.employer.com), create a new project, and choose **Self-Hosted**.
  </Step>
  <Step title="Start your back-end">
    In the generated project directory, run:

    ```bash
    npm start
    ```

    You should see:

    ```
    [employer] 🌳  Your agent is running at http://localhost:3310
    ```
  </Step>
</Steps>

## What you have now

A connected employer back-end with every table from your database surfaced as a collection. Operators can browse, search, edit, and delete records out of the box.

## Troubleshooting

<AccordionGroup>
  <Accordion title="Back-end not starting">
    - Check that your `.env` file is present and loaded
    - Ensure port 3310 is not already in use
    - Run `curl http://localhost:3310/employer`, should return employer metadata
  </Accordion>
</AccordionGroup>

## What's next

<Card title="Next: Customize your interface" icon="arrow-right" href="/get-started/customize-your-back-office">
  Organize your collections, fields, and create your first segment.
</Card>
```

## Warnings and infos as actually used

```mdx
<Warning>
  Never commit your `.env` file to version control. Add it to `.gitignore`.
</Warning>

<Info>
  Each environment and team has its own layout. Changes you make in development don't affect production until you deploy them.
</Info>

<Info>
  See [Inbox](/product/manage/inbox) for configuration options.
</Info>
```

A `<Warning>` names a consequence. An `<Info>` carries context or a pointer to
the full reference. Neither reassures.

## Screenshots

```mdx
<Frame caption="Toggle a collection's visibility with the eye icon">
  <img src="/images/master-ui/layout-show-hide-collections.png" alt="Show/hide collections with the eye icon" />
</Frame>
```

## Multi-SDK content

```mdx
<Tabs>
<Tab title="Node.js">

Both plugins need a way to reach the Zendesk API. They accept the same `ZendeskClientProvider` contract as the datasource factory: pass either an already-built `client`, **or** raw credentials (`subdomain`, `email`, `apiToken`) and the plugin builds one for you on the fly.

</Tab>
<Tab title="Ruby">

Both plugins require the [Zendesk datasource](/get-started/connect/data-sources/zendesk) to be registered on your back-end: they need the `Datasource` instance to reach the Zendesk API client.

</Tab>
</Tabs>
```

## Product page closings

`product/execute/workflows.mdx`

> ## Permissions
>
> Workflow execution is governed by the standard role and team permission system.
> A user can only:
>
> - See workflows their team has access to
> - Trigger steps for which their role has the required permissions
> - Access data and actions inside steps based on their scopes
>
> See [Roles & permissions](/get-started/control/roles-permissions) for
> configuration.

## Established H2s, by frequency

`Source code` 21, `Basic usage` 14, `Troubleshooting` 12, `Usage` 10,
`Overview` 9, `Installation` 9, `Examples` 8, `Configuration` 8, `Options` 7,
`How it works` 7, `What's next` 6, `Limitations` 5, `Learn more` 5,
`Prerequisites` 4.

Prefer one of these over inventing a heading.
