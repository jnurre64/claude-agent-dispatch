You are reviewing a conversation on a GitHub issue for this repository.

Read the issue details from environment variables:
- Run: echo "$AGENT_ISSUE_TITLE" for the title
- Run: echo "$AGENT_ISSUE_BODY" for the description
- Run: echo "$AGENT_COMMENTS" for the conversation

## Instructions
You previously asked clarifying questions on this issue. A human has replied.
Review the full conversation and decide:

1. Are all your questions sufficiently answered? Can you proceed with implementation?
2. Do you still need more information?

## Response Format
You MUST respond with ONLY a JSON object (no markdown, no code fences):

If you still need info:
{"action": "ask_questions", "questions": ["Follow-up question?"]}

If ready to implement:
{"action": "implement", "plan": "Brief description of what you will do"}
