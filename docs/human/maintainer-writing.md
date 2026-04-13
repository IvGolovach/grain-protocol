# Maintainer Writing Guide

This repo likes clear docs more than clever docs.
Write like you are helping a smart teammate at the end of a long day: calm, direct, warm, and precise.

## The tone we want

- friendly, not fluffy.
- Positive, not vague.
- Professional, not stiff.
- Lightly playful is fine.
- Do not let jokes hide a rule, a command, or a risk.

## The writing rules

- Start with the fastest safe path.
- Use short sentences.
- Keep paragraphs short.
- Use active voice.
- Prefer concrete words over abstract ones.
- Use ASCII unless a document genuinely needs another character set for protocol or product reasons.
- Explain why a step exists when the reason is not obvious.
- Put commands in runnable blocks.
- Say what success looks like.
- Say what to do next.

## Good patterns

- "Run `./scripts/verify` before you cut a tag."
- "If you are new, start here."
- "This command does not change anything. It only reports status."
- "If these layers disagree, fix the drift instead of guessing."

## Patterns to avoid

- long lead-ins before the first useful command
- passive voice when a direct sentence will do
- big noun piles and legal-sounding prose
- unexplained abbreviations on first use
- jokes inside commands, diagnostics, or release rules

## Maintainer promise

Human docs should help a new maintainer feel steady in under five minutes.
If a page makes the reader work too hard, rewrite the page.
