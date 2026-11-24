# The voicemail agent behind the demo

The n8n workflow in this repo only handles what happens after a call. This page describes the AI agent that takes the call and produces the data the workflow reads. It is the inbound message-taker on my own UK number, built on ElevenLabs Conversational AI. The wording below is paraphrased and made generic: no names, numbers or ids.

The agent prompt was drafted with AI assistance and tuned by calling my own line and reading the transcripts. The full prompt is in [`agent-prompt.md`](agent-prompt.md).

## Job of the agent

Take a complete, accurate message and end the call. It only takes messages. It does not answer questions, book anything or put calls through.

## Conversation flow

| Step | What the agent does |
|---|---|
| 1. Take the message | If the caller already said why they rang, it uses that and never asks them to repeat it. If they have said nothing useful yet, it says "Go ahead and leave a message." If they are mid-number or mid-spelling, it waits. |
| 2. Fill in what is missing | One question per turn, in a fixed order: name, then company, then callback number. A first and last name said together count as a full name, so it only asks "And your surname?" when it has a first name alone. It never asks again for anything already given. If the caller declines, it says "No problem." and moves on. |
| 3. Number check | Once per call, it checks a UK number is a plausible length (treating +44 as 0). Too short or too long gets one gentle "could you give me the full number again?". The caller's last correction wins. |
| 4. Callback check | It reads back only the callback number, once, then asks "Anything to add?" It never recaps the whole message. |
| 5. Close | A short goodbye using the caller's first name, then it ends the call. |

## Guardrails

- It never offers or books appointments, and never promises a callback or a time.
- If asked to put the caller through, it says it can't and offers to take a message.
- If asked whether it is an AI, it says so plainly.
- It never invents names, numbers or details, and never asks for passwords or card numbers.
- After about 90 seconds it moves on to the missing details and the close, without cutting the caller off.
- It never ends the call while the caller is still talking.
- The only tool it has is end-call.

## Structured data it produces

After every call the platform fills in six fields. These are what the n8n workflow reads.

| Field | Meaning |
|---|---|
| `caller_name` | The caller's name, if given |
| `company` | The company or agency, exactly as said. Empty for a personal call or if declined |
| `callback_number` | The number, in E.164 or as spoken |
| `reason` | What the call is about |
| `urgency` | `yes`, `no` or `unclear` |
| `outcome` | `message_taken`, `refused`, `incomplete` or `failed` |

The platform also writes a short summary and a call title. The workflow uses `outcome` to label a call "incomplete, worth a callback?" when the caller hung up early or went silent.

## Why the split

The agent decides what to ask. The workflow decides what to do with the answer. Keeping them apart means either can change without touching the other, and the workflow can be tested with made-up payloads and no phone call.
