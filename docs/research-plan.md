# Tali product validation protocol

## Decision this research informs

Should Tali continue toward a multi-user release, and which interaction failures must be fixed before inviting more people?

This protocol tests the product's core claim: people can record personally meaningful behavior with low friction and without Tali implying that more, less, streaks, abstinence, or consistency are inherently better.

## Hypotheses and thresholds

| Hypothesis | Measure | Continue threshold | Stop or redesign threshold |
|---|---|---:|---:|
| A first-time user can understand Tali without coaching | Completes create → log → inspect | 4 of 5 participants | 2 or more cannot complete |
| Text entry is materially lower friction than opening the app | Median time and stated preference after both tasks | Text is faster and preferred by at least 3 of 5 | App is faster/preferred by at least 3 of 5 |
| Neutral language does not imply a desired frequency | Participant interpretation after sensitive and ordinary examples | 5 of 5 describe the display as observational | Any participant reports pressure, praise, shame, or implied prescription |
| Time-since controls are discoverable and effective | Finds global and per-habit control without coaching | 4 of 5 within 60 seconds | 2 or more cannot find either control |
| Users trust the data boundary | Can explain local/server/SMS roles after viewing settings | 4 of 5 broadly correct | 2 or more have a materially unsafe misconception |
| Export creates credible ownership | Successfully exports and identifies contents | 4 of 5 | 2 or more cannot export or misunderstand scope |

Five participants are appropriate for formative usability discovery, not statistical proof. The output is a prioritized problem list with evidence, not a market-size or retention claim.

## Participant mix

Recruit five adults who already track, reflect on, or are curious about recurring behavior:

- at least two tracking an emotionally neutral or positive behavior;
- at least two tracking a behavior they do **not** want framed as either a streak or abstinence;
- a mix of technical comfort;
- no requirement to disclose the real behavior they track.

Participants may use invented habits throughout. Do not recruit anyone whose participation depends on sharing health, substance-use, or other sensitive personal data.

## Consent and data minimization

Before the session, say:

> This is a usability study of an unfinished habit-recording app. You can use fictional examples, skip any question, and stop at any time. We are evaluating the product, not you. With your permission, I will take notes about where the interface is clear or confusing. I will not record your real habit data, Apple credentials, phone number, message contents, or exported file.

Record only:

- participant code, not name;
- task completion, time, and observed friction;
- paraphrased comments needed to explain a product problem;
- severity and confidence;
- permission for any short quotation used in the case study.

Delete raw notes after synthesis. Never commit research notes containing participant identifiers or sensitive behavior.

## Session script

### Opening

1. Read the consent statement.
2. Ask: “When you hear *habit tracker*, what do you expect it to want from you?”
3. Ask the participant to think aloud and remind them that silence is fine.

### Tasks

Do not explain where controls are. Give one prompt at a time.

1. “You want to keep a record of stretching. Set that up.”
2. “Record that it happened Sunday at 2 PM and add a short note.”
3. “Show me what Tali knows about stretching.”
4. “Now imagine the behavior is something where a large sobriety-style clock would feel wrong. Change only that habit so Tali does not show time since.”
5. “Make that choice apply to every habit.”
6. “Connect texting, stopping before entering any real credential if this is a prototype session.”
7. “How would you record a behavior by text? What reply do you expect?”
8. “Save Tali as a contact.”
9. “Export everything you would need to leave Tali.”
10. “Sign out another device, then show where you would sign out everywhere.”

### Neutrality probes

Show three static states in counterbalanced order:

- no entries for meditation;
- several cannabis-use entries with irregular gaps;
- a daily medication entry.

Ask:

1. “What, if anything, does Tali seem to want you to do next?”
2. “How would this screen make you feel if this were your data?”
3. “Which words or visual hierarchy create that impression?”
4. “What would make it more observational?”

Do not ask “Does this feel neutral?” before the participant has interpreted the screen; that primes the desired answer.

### Closing

1. “What would stop you from using this with real data?”
2. “What would you expect Tali to remember or forget?”
3. “If Tali disappeared tomorrow, what would you need to take with you?”
4. Ask permission before retaining any quotation.

## Observation rubric

For every task record:

- success: completed without help / completed with one prompt / not completed;
- time to completion;
- wrong turns and recoveries;
- expectation before action;
- visible emotional response;
- language that implies praise, pressure, shame, prescription, or surveillance;
- accessibility issue;
- data-boundary misconception.

Severity:

- **Critical:** risks data loss, cross-user exposure, unwanted disclosure, or a harmful behavioral implication.
- **High:** blocks a core journey without facilitator help.
- **Medium:** causes repeated hesitation or a wrong mental model but is recoverable.
- **Low:** polish issue with little effect on outcome.

## Synthesis and decision log

Within 24 hours:

1. Convert observations into problems, not feature requests.
2. Merge duplicates only when evidence and root cause match.
3. Rank by severity, frequency, and confidence.
4. Link each accepted change to a decision-register entry or issue.
5. Preserve disconfirming evidence.
6. State what the study cannot establish.

Use this template:

```text
Finding:
Evidence:
Participants affected:
Severity:
Likely root cause:
Decision:
Success measure for the change:
Owner and date:
```

Release gate: no unresolved critical finding; every high finding is fixed, explicitly deferred with rationale, or covered by a narrower launch constraint.
