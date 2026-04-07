# Product & Strategy

This document covers the product rationale, learning science foundation, and business model behind LangReels AI. It's intended for contributors who want to understand _why_ features are designed the way they are, and for anyone evaluating the product direction.

---

## The core problem

Language learning apps are built around structured curricula: flashcards, grammar exercises, vocabulary drills. These work for building foundational knowledge but fail at the thing that actually makes people fluent — exposure to natural, unscripted language used in real cultural contexts.

Authentic content (native speaker videos, podcasts, conversations) is the missing ingredient. But it's hard to learn from: too fast, no subtitles, no way to pause on a specific phrase and study it.

LangReels bridges this gap. Creators record natural videos in their own language. The AI pipeline handles everything else — turning unedited speech into structured, navigable learning content in 15 languages.

---

## Why the format works

### Short-form video as a learning unit

A 60–90 second video maps naturally to a single learning session. It's long enough to contain several complete sentences and cultural context; short enough to replay multiple times in a sitting. The constraint also pushes creators toward focused, conversational content — useful phrases, cultural explanations, everyday situations — rather than lectures.

### Two viewing modes for two learning states

**Normal mode** (karaoke-style subtitles) serves passive acquisition — the learner hears natural speech rhythm while following along visually. Research consistently shows that input slightly above current comprehension level (Krashen's "i+1") drives acquisition better than drilling known material.

**Study mode** (sentence-by-sentence with replay) serves active learning — the learner can isolate a specific sentence, replay it, read it in multiple languages, and decide whether to move on. This mirrors the "deliberate practice" model: focused attention on a specific element, immediate feedback, repetition on demand.

The key product insight: both modes exist on the same video. The learner doesn't choose a "mode" before watching — they flow between passive and active naturally, switching with a single tap.

### Social mechanics and retention

Retention in language learning correlates strongly with motivation, which correlates with a sense of progress and community. The social layer (likes, comments, saves, creator profiles) isn't decoration — it creates the feedback loop that brings learners back. Creators see engagement on their content; learners build a library of saved reels to return to.

---

## Feature design decisions

### Sentence-level granularity (not word-level)

Early versions surfaced word-level data as the primary learning unit. User testing showed this was too granular — learners got stuck on individual words and lost the sentence's meaning and rhythm. Sentence-level navigation matches how fluent speakers actually parse speech: in chunks, not word by word.

Word-level timing is still stored and used for the karaoke subtitle effect in normal mode — it just isn't the navigation primitive.

### Batch translation (not per-sentence API calls)

Sending sentences together to the translation API preserves discourse context. "No, that's not what I meant" translates differently depending on whether the API knows the preceding sentence. Batch calls maintain that context while also being more cost-efficient than 15 × N individual requests.

### Language detection on the creator side (not learner-specified)

The creator doesn't tag their video with a language. AWS Transcribe detects the spoken language automatically. This removes friction for creators (no metadata to fill in) and is more accurate than self-reporting for content in non-dominant dialects.

### Processing happens server-side, asynchronously

The creator uploads and waits. They don't trigger processing, choose settings, or review outputs before the reel goes live. This is intentional: the value proposition is zero-effort content creation. Any step that requires creator input after upload breaks the promise.

The trade-off is that creators can't correct transcription errors. This is an acceptable limitation at this stage — transcription accuracy is high enough (95%+) that most content is usable without correction.

---

## Supported languages

The 15 supported languages were chosen to cover the highest-traffic language learning pairs globally, with additional weight given to Indian regional languages (Kannada, Marathi, Tamil) which are underserved by existing platforms.

English · Spanish · French · German · Italian · Portuguese · Russian · Japanese · Korean · Chinese (Simplified) · Arabic · Hindi · Kannada · Marathi · Tamil

---

## Business model

### Freemium

- **Free tier:** Full access to the feed, normal viewing mode, limited saves
- **Premium:** Unlimited saves, study mode controls, offline access, playback speed controls
- **Pro (creator):** Analytics dashboard, priority processing, enhanced discovery

### B2B / institutional

- Licensing to language schools and universities looking for authentic content supplementary material
- White-label deployments for language learning platforms that want the pipeline without the social layer
- API access for platforms that want to integrate the transcription + translation pipeline into their own products

### Creator economy (future)

- Revenue sharing tied to engagement metrics for high-volume creators
- Sponsored cultural exchange content from tourism boards, cultural organisations
- Premium creator tools: custom branding, download access, advanced analytics

---

## Roadmap

### Near-term (functional improvements)

- **Pronunciation practice** — phonetic display alongside subtitles, record-and-compare
- **Comprehension quizzes** — auto-generated from sentence content
- **Spaced repetition** — saved sentences surfaced again at intervals based on forgetting curves
- **Speed controls** — 0.5×, 0.75× playback for listening practice

### Medium-term (platform expansion)

- **Web app** — Flutter web build or separate React frontend
- **Content recommendation** — ML-based feed personalisation by learner level and interests
- **Learning path tracking** — progress visualisation, streak mechanics
- **Community annotations** — crowd-sourced notes on cultural references within videos

### Scaling considerations

- **Database indexing** — Firestore query performance degrades at scale without careful composite indexes; review before exceeding ~100k reels
- **CDN for video delivery** — Firebase Storage works for development; a CDN layer (CloudFront or equivalent) is needed for global low-latency delivery at scale
- **Translation caching** — popular videos get re-translated every time they're reprocessed; a translation cache keyed on sentence content would reduce costs significantly at scale
- **Processing queue** — at high volume, concurrent Cloud Function invocations may exceed Firebase quotas; a task queue (Cloud Tasks or similar) would provide backpressure

---

## Known limitations

**No creator editing.** If AWS Transcribe misheard a word, the creator currently has no way to correct it before the reel goes live. A correction interface is the highest-priority missing feature for creator experience.

**Single-language audio only.** Videos where speakers switch languages mid-sentence (code-switching, common in many communities) produce unreliable transcription. AWS Transcribe picks one dominant language for the whole clip.

**No real-time processing.** The 2–3 minute pipeline means there's a delay between upload and availability. For a social platform, this is noticeable. Reducing processing time (or showing partial results progressively) is a meaningful UX improvement.

**15-language ceiling is artificial.** Google Translate supports ~100+ languages; AWS Transcribe supports ~30+ for input detection. Expanding the supported set is straightforward technically — the current list was chosen for launch focus, not technical limitation.

---

<div align="center">

[← Back to README](../README.md) · [How it works](../HOW_IT_WORKS.md) · [Architecture](./ARCHITECTURE.md) · [Fork & setup](../FORK_AND_SETUP.md)

</div>
