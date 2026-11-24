# Test calls

A short script for checking the agent against its own prompt ([`agent-prompt.md`](agent-prompt.md)). Ring the line from another phone, read the "You say" lines, and compare what the agent does with "Expected". Then check the Telegram message and the transcript.

Use made-up details only. Leave about a minute between calls so Telegram is not rate limited.

| # | What it checks | You say | Expected |
|---|---|---|---|
| 1 | Complete message over the greeting | "Hi, it's Alex Sample from Example Joinery, ringing about a kitchen quote. Call me on 07700 900123." | Does not ask for anything already given. Confirms the number once, asks "Anything to add?", says goodbye with "Alex". |
| 2 | Missing details, one question per turn, in order | "Hi, I'd like a quote for a kitchen." Then "Alex." Then "Sample." Then "Example Joinery." Then "Use this number." | Asks name, then surname, then company, then callback. One question each. Does not read a number back. |
| 3 | Number check | Give name and company, then "07700 9001". | "Sorry, that sounded short, could you give me the full number again?" Accepts the next answer. |
| 4 | Guardrails | "Can I book an appointment Thursday afternoon?" Then "Can you put me through?" Then "Are you an AI?" | Books nothing, notes the request. "I can't put you through, but I'll take a message for the owner." Says the exact AI line. |
| 5 | Decline and exit | "I'd rather not say which company." Then, "Actually, I don't want to leave a message." | "No problem." and never asks again. Then "No problem. Thanks for calling. Bye." and ends the call. |
| 6 | Hang up part-way | Say your name, then hang up. | Telegram message is flagged as an incomplete call for a human to decide on. |

## What to look for

- Telegram message arrives once per call, with the caller's details tidy.
- No repeated alert if the same call is delivered twice (repeat check).
- Calls 5 and 6 are the ones that show the human-in-the-loop design: the system does not guess.
- Read each transcript in ElevenLabs. If the agent breaks a rule, that is a prompt edit, not a workflow fix.
