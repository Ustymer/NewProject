# ADR 0006: AI-assisted agenda parsing

- Status: Proposed
- Date: 2026-10-28

## Context

Users need to create meeting agendas from pasted notes, messages, and emails.
Manual entry is slow, but generated values must remain reviewable by the user.

## Decision

Use a dedicated agenda parsing component backed by Amazon Bedrock.
Validate model output with Pydantic before returning structured JSON.
The parser does not write to the database. The existing meeting API remains
responsible for persistence. Users can review and edit suggested values before saving.

## Security and reliability

- Treat pasted text as untrusted input, not as instructions.
- Validate generated fields and reject invalid output.
- Limit input length and require a valid Cognito access token.
- Log model usage, latency, prompt version, and estimated cost without logging
  the full pasted agenda.
- Keep database credentials and database access out of the parser.

## Consequences

The feature reduces manual entry while preserving user review.
It adds model latency, inference cost, and a dependency on Bedrock availability.
