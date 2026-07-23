# Tali formative research kit

This kit turns the [research protocol](research-plan.md) into materials that can be used without
improvising around sensitive data. It is for five formative usability sessions, not clinical
research, market sizing, or a claim that the product is safe for every use.

## Recruitment message

> I am testing Tali, an unfinished iPhone app for recording when personally meaningful activities
> happen. A 35–45 minute remote session will involve completing a few tasks with fictional examples
> and talking through what the interface seems to communicate. You never need to name or discuss a
> real habit, health condition, medication, or substance use. I am testing the product, not you.
> Participation is voluntary, and you may skip a question or stop at any time. If you are interested,
> reply and I will send a short eligibility form and the study details.

Do not recruit by asking people to disclose the behavior they track. Recruit outside any
facilitator–participant relationship where declining could feel costly.

## Screener

Collect the minimum needed to select a varied sample, then delete screener responses after
scheduling.

1. Are you 18 or older? **Yes / No**
2. Do you regularly use an iPhone? **Yes / No**
3. Have you used any app, note, calendar, or spreadsheet to remember when something happened?
   **Often / Sometimes / Never**
4. How comfortable are you trying an unfinished app? **Comfortable / Unsure / Not comfortable**
5. Which session format works for you? **Remote screen share / In person / Either**
6. Is there any accessibility accommodation that would help you participate? **Optional free text**
7. May the researcher contact you only to schedule this session? **Yes / No**

Exclude anyone under 18 or unwilling to participate voluntarily. “Never tracked anything” is not an
automatic exclusion; one such participant can test first-use comprehension.

## Pre-session checklist

- Assign a participant code such as `P01`; do not put their name in notes.
- Use a clean simulator or test device with the `-tali-demo` fixture.
- Disable notifications and remove personal accounts, messages, and habit records.
- Prepare fictional activity cards: **stretching**, **watering plants**, **cannabis use**, and
  **medication**.
- Confirm the participant can choose a fictional activity instead.
- Do not ask the participant to type an Apple credential, phone number, pairing code, or real note.
- Decide whether quotations are needed. Audio or video recording is off by default.
- Open the observation worksheet before the session.

## Consent script and confirmation

Read this verbatim:

> This is a usability study of an unfinished habit-recording app. Participation is voluntary. You
> can use fictional examples, skip any question, take a break, or stop at any time. We are evaluating
> the product, not you. I will take notes about whether the interface is clear or confusing. Please
> do not enter real habit data, Apple credentials, phone numbers, message contents, or private notes.
> I will identify this session only by a participant code. Raw notes will be deleted after findings
> are synthesized. Do you consent to participate and to this note-taking?

Record only:

- `Consent to participate: yes / no`
- `Consent to retain an anonymized quotation: yes / no / ask per quote`
- `Consent date`

Stop if consent is not an unambiguous yes. Consent to participate does not imply consent to record
audio, video, or a screen.

## Facilitator guide

### Introduction

1. Read the consent script.
2. Say: “Please think aloud when you can. Silence is also okay.”
3. Ask: “When you hear *habit tracker*, what do you expect it to want from you?”
4. Do not describe Tali as neutral before the interpretation tasks.

### Core tasks

Give one prompt at a time. Do not point to the relevant control.

| ID | Prompt | Core signal |
| --- | --- | --- |
| T1 | “You want to keep a record of stretching. Set that up.” | First-use comprehension |
| T2 | “Record that stretching happened Sunday at 2 PM and add ‘hips felt better.’” | Backdating and notes |
| T3 | “Show me what Tali knows about stretching.” | Detail and history model |
| T4 | “Imagine a large sobriety-style clock would feel wrong for this activity. Hide it only here.” | Per-activity elapsed-time control |
| T5 | “Now make that choice apply to every activity.” | Global elapsed-time control |
| T6 | “Show how you would connect texting, but stop before entering any credential or phone number.” | Data boundary and onboarding |
| T7 | “How would you record an activity by text, and what reply would you expect?” | SMS mental model |
| T8 | “Save Tali as a contact.” | Contact affordance |
| T9 | “Export everything you would need if you stopped using Tali.” | Ownership and scope |
| T10 | “Show where you would remove another signed-in device, then sign out everywhere.” | Session safety |

If a participant is blocked, wait 30 seconds before giving a neutral prompt such as “What are you
looking for?” Mark the task as assisted. Never teach the route and then count it as unassisted.

### Neutrality probes

Show these states in a different order for each participant:

- meditation with no entries;
- cannabis use with irregular gaps;
- a daily medication entry.

Ask:

1. “What, if anything, does this screen seem to want you to do next?”
2. “How might this screen feel if this were your data?”
3. “Which words, numbers, colors, or visual hierarchy create that impression?”
4. “What would make it feel more observational?”

Do not ask “Does this feel neutral?” until after the participant has formed an interpretation.

### Closing

1. “What would stop you from using this with real data?”
2. “What would you expect Tali to remember or forget?”
3. “If Tali disappeared tomorrow, what would you need to take with you?”
4. For each candidate quotation, ask whether the paraphrase is accurate and may be retained.
5. Remind the participant how and when session notes will be deleted.

## Observation worksheet

Copy this section into a private, access-limited working document. Do not commit completed
worksheets.

```text
Participant code:
Date:
Facilitator:
Device / build:
Consent to participate:
Quotation permission:

Pre-task expectation:

| Task | Result: unassisted / assisted / failed | Time | Wrong turns and recovery | Expectation before action |
|------|----------------------------------------|------|--------------------------|---------------------------|
| T1   |                                        |      |                          |                           |
| T2   |                                        |      |                          |                           |
| T3   |                                        |      |                          |                           |
| T4   |                                        |      |                          |                           |
| T5   |                                        |      |                          |                           |
| T6   |                                        |      |                          |                           |
| T7   |                                        |      |                          |                           |
| T8   |                                        |      |                          |                           |
| T9   |                                        |      |                          |                           |
| T10  |                                        |      |                          |                           |

Neutrality interpretation:
Trust or data-boundary misconception:
Accessibility observation:
Emotional response attributable to the interface:
Potential quotation (only if permitted):
Facilitator uncertainty or possible bias:
```

## Findings matrix

Keep findings about product behavior, not participant traits.

| Finding ID | Problem statement | Evidence count | Severity | Confidence | Likely root cause | Decision | Success measure |
| --- | --- | ---: | --- | --- | --- | --- | --- |
| F-001 | Example: People cannot distinguish local export from connected-account export. | 0/5 | — | — | — | — | — |

Severity:

- **Critical:** potential data loss, cross-user exposure, unwanted disclosure, or a harmful
  behavioral implication.
- **High:** blocks a core journey without facilitator help.
- **Medium:** creates a repeated wrong turn or unsafe mental model but is recoverable.
- **Low:** polish issue with little effect on the outcome.

Confidence considers the quality and consistency of evidence, not just frequency. Preserve
disconfirming evidence and facilitator uncertainty.

## Synthesis agenda

Within 24 hours of the fifth session:

1. Review observations without participant names or sensitive examples.
2. Turn observations into problem statements; keep requested solutions as supporting evidence.
3. Merge only findings with the same evidence and root cause.
4. Apply the thresholds in `research-plan.md`.
5. Resolve every critical finding before external release.
6. Fix each high finding, explicitly defer it with rationale, or narrow the launch so users cannot
   reach the unsafe path.
7. Add accepted product decisions to `decision-register.md`.
8. Record what five formative sessions cannot establish: prevalence, retention, clinical benefit,
   broad accessibility, or market demand.
9. Delete raw notes and screener responses after the findings are verified.

## Research report outline

```text
Decision investigated:
Participants and limitations:
Method:
What supported the product thesis:
What contradicted the product thesis:
Critical and high findings:
Decisions made:
Deferred questions:
Evidence that must be collected next:
Raw-note deletion date:
```

