# LangReels AI — How It Works

> A plain-language guide to the user experience and the technical pipeline powering it.

---

## What LangReels Actually Does

A creator records a short video in any language. Within about 3 minutes, that video becomes a multi-language learning reel — subtitled in 15 languages simultaneously, with two distinct viewing modes and sentence-level study controls. No manual transcription, no manual translation, no editing. The entire pipeline is automated.

This document explains what happens at every step, both from the user's perspective and under the hood.

---

## The Two Roles: Creator and Learner

LangReels has two distinct user journeys that intersect around the same content.

**Creators** record short videos (up to 2 minutes) in their native language. They experience an upload flow, a waiting period while AI processes their content, and then a completed reel that is automatically discoverable by learners worldwide.

**Learners** scroll a TikTok-style feed, filter by language, and watch content. They can stay in passive "watch" mode or flip into active "study" mode for the same video without leaving the screen.

---

## The Creator Experience

### 1. Recording or Uploading

The app opens a camera interface styled like TikTok's. Creators can record directly in-app or pick an existing video from their gallery. Hard limits are enforced before anything is uploaded:

- Maximum duration: **2 minutes** (120 seconds)
- Maximum file size: **100MB**
- Format: MP4

If either limit is exceeded, the app rejects the file locally before any upload begins — no wasted bandwidth or processing costs.

### 2. The Upload

Once a video passes local validation, it is uploaded directly to **Firebase Storage** under the path `videos/reels/{userId}/reel_{uuid}.mp4`. The app shows a progress indicator during upload.

The moment the upload completes, Firebase Storage fires an event that kicks off the backend pipeline automatically. The creator doesn't press a "Process" button — the system reacts to the file appearing in storage.

### 3. Waiting While AI Works

The app displays a live processing status that maps to what is actually happening in the backend:

| Status shown to user | What's actually happening                  | Approx. progress |
| -------------------- | ------------------------------------------ | ---------------- |
| Uploading            | Video being written to Firebase Storage    | 10%              |
| Checking content     | Google Video Intelligence moderation scan  | 25%              |
| Transcribing         | AWS Transcribe speech-to-text job          | 65%              |
| Translating          | Google Translate batch across 15 languages | 85%              |
| Ready                | Firestore updated, reel visible in feed    | 100%             |

The app reads a `processingStatus` field on the Firestore reel document in real time via a stream listener. As each Cloud Function updates that field, the UI advances. The creator can navigate away — the processing continues server-side and the reel appears in the feed when complete.

If moderation fails (explicit content detected), the reel is rejected at the 25% stage and the creator is notified. It never reaches transcription or translation.

### 4. The Completed Reel

When processing finishes, the reel is marked `isProcessed: true` and appears in the home feed. The creator's profile updates with the new reel count. From this point on, every viewer sees the content available in all 15 languages.

---

## The Learner Experience

### Browsing the Feed

The home feed is a vertical scroll of processed reels. Learners can filter by source language (the language spoken in the video) to find content in the language they are learning from. The feed loads in pages to keep scrolling smooth.

### Two Subtitle Modes on the Same Video

Every reel has two viewing modes that the learner can toggle without pausing or reloading the video.

**Normal Mode (passive watching)**

Subtitles appear as a continuous stream of words at the bottom of the screen, synchronized at the individual word level. Each word appears at the exact millisecond it is spoken. This is sometimes called "karaoke-style" — the text flows with natural speech rhythm. The learner selects which language to see the subtitles in, and they can change languages while the video is playing.

**Study Mode (active learning)**

The video pauses at sentence boundaries. The learner sees the full current sentence, can read it, then tap to advance to the next sentence, go back to the previous one, or replay the current sentence's audio. This turns a 30-second video clip into a structured micro-lesson with full navigation control.

The switch between these two modes is instant because both data sets — word-level timing and sentence-level timing — are stored separately in Firestore and loaded together when the reel opens. There is no re-fetch when switching modes.

### Language Selection

A language picker lets the learner choose any of the 15 supported languages for subtitles. The translations are already stored in Firestore at the sentence level (and the original word-level data stays in the source language). Switching languages is a local state change — no network call required.

---

## What Is Actually Running in the Backend

### The Four Active Cloud Functions

The codebase has references to an `extractAudio` function in older documentation, but the deployed pipeline does **not** use a separate audio extraction step. The actual deployed functions are:

**1. `moderateContent`** — triggered by Firebase Storage  
**2. `transcribeAndTranslate`** — triggered by Firebase Storage  
**3. `handleTranscribeWebhook`** — HTTP endpoint called by AWS EventBridge  
**4. `reprocessReel`** — callable function for manual reprocessing  
**5. `healthCheck`** — callable function for status monitoring

Functions 1 and 2 both trigger on `onObjectFinalized` (new file in Storage), meaning they fire in **parallel** the moment a video is uploaded. Moderation and transcription start at the same time.

---

### Function 1: Content Moderation

**Service used:** Google Cloud Video Intelligence API

The video is scanned for explicit content using two detection methods running together:

- **Explicit content detection** — frame-by-frame analysis for adult content. Any frame rated higher than `POSSIBLE` fails the check.
- **Label detection** — segment-level scan for labels matching a keyword list (`violence`, `weapon`, `drug`, `hate speech`, `pornography`, `nudity`, `gang`, `terrorist`). A match at ≥70% confidence fails the check.

If either check fails, the reel's status is set to `rejected` in Firestore and processing stops. No transcription or translation job is started. If moderation passes, the status advances to `moderationCompleted`.

---

### Function 2 + 3: Transcription — Event-Driven AWS Transcribe

This is where the architecture gets interesting. The pipeline **does not use OpenAI Whisper** — despite some references in earlier documentation. The actual production implementation uses **AWS Transcribe** with an event-driven pattern specifically designed to avoid Firebase Cloud Function timeout limits.

**Why event-driven?**

AWS Transcribe jobs take 1–3 minutes to complete. Firebase Cloud Functions have a maximum timeout of 9 minutes on the highest tier, but holding a function open and polling is expensive and fragile. The solution splits the work across two functions using AWS EventBridge (SNS) as a callback mechanism:

**`transcribeAndTranslate` does this:**

1. Downloads the video from Firebase Storage to `/tmp/`
2. Uploads the video file directly to an S3 bucket
3. Starts an AWS Transcribe job with `IdentifyLanguage: true` across all 15 supported language codes — AWS auto-detects which language is being spoken
4. Stores the job metadata (jobName, reelId, S3 file key) to a `transcribe_jobs` Firestore collection
5. Updates reel status to `transcribing`
6. **Returns immediately** — the function exits after ~10 seconds, well within timeout limits
7. Deletes the local `/tmp/` video file

The transcription job continues running in AWS independently.

**`handleTranscribeWebhook` does this:**
When AWS Transcribe finishes, EventBridge fires an SNS notification to this HTTP endpoint. The function:

1. Verifies the SNS message (handles subscription confirmation handshake automatically)
2. Looks up the job metadata from the `transcribe_jobs` Firestore collection
3. Retrieves the completed transcript JSON from S3
4. Retrieves the SRT subtitle file from S3 (AWS Transcribe generates this automatically)
5. Parses the SRT into sentence objects with start/end timestamps
6. Extracts individual word timing from the transcript JSON
7. Hands off to the translation pipeline
8. Cleans up: deletes the S3 video file and transcript files, deletes the AWS Transcribe job, removes the `transcribe_jobs` Firestore document

**What comes out of transcription:**

Two data structures extracted from the same AWS Transcribe output:

- `words[]` — every spoken word with millisecond-precision start/end times. Used for the word-by-word subtitle flow in normal mode.
- `sentences[]` — sentence boundaries derived from the SRT file, each with a start/end time span and a confidence score. Used for study mode navigation.

Language detection: AWS Transcribe identifies the spoken language from a hint list of 15 language codes. If the detected code isn't in the supported list, Google Translate's language detection API is called as a fallback to confirm.

---

### Translation: Google Cloud Translation API (Batch Mode)

**Service used:** Google Cloud Translation API v3

This is the most architecturally significant part of the pipeline, and it went through at least two major iterations before reaching the current approach.

**The problem with the previous approach:**

The original design translated the full transcript text as one block per language, then tried to split and align those translated paragraphs back to individual sentences. This "mapping" approach caused sentence truncation — a translated sentence would end mid-phrase because the alignment logic couldn't reliably split arbitrary translated text at the right boundaries.

**The current batch approach:**

Instead of translating full text and splitting, the pipeline sends all sentences as an array in a single API call per language:

```
Input:  ["Sentence 1", "Sentence 2", "Sentence 3", ...]
Output: ["Traducción 1", "Traducción 2", "Traducción 3", ...]
```

Google Translate's batch API guarantees that the output array is the same length as the input array, in the same order. This gives a perfect 1:1 mapping with zero truncation risk.

For a 2-minute video with ~10 sentences, that's 14 API calls (one per non-source language) × 10 sentences per call = 140 translation requests, but they're batched efficiently. The total cost per video is approximately $0.10–0.15.

**Fallback behavior:**

If translation fails for a specific language (network error, API quota, etc.), that language falls back to showing the original text. Processing continues for all remaining languages. A single language failure does not abort the entire job.

**What's stored in Firestore after translation:**

Each sentence object ends up looking like this in the `translations/{reelId}` Firestore document:

```json
{
  "originalText": "Where is the train station?",
  "startTime": 0.0,
  "endTime": 3.5,
  "index": 0,
  "confidence": 0.95,
  "translations": {
    "en": "Where is the train station?",
    "es": "¿Dónde está la estación de tren?",
    "fr": "Où est la gare?",
    "de": "Wo ist der Bahnhof?",
    "ja": "駅はどこですか？",
    "zh": "火车站在哪里？",
    "ar": "أين محطة القطار؟",
    "hi": "रेलवे स्टेशन कहाँ है?",
    "... all 15 languages": "..."
  }
}
```

The `translations/{reelId}` document is linked from the main `reels/{reelId}` document via a `translationsDocPath` field. The Flutter app loads both documents together when opening a reel.

---

### What's in `translation-mapper.js` and `sentence-processor.js`?

These two files exist in the `functions/` directory but are **legacy code from previous pipeline versions**. They implemented the old full-text-then-split approach (the one that caused truncation). The current `index.js` does not import or call either file. They can be deleted from the repo without any impact on the running pipeline — their presence is a historical artifact from the development process.

---

## Service Map: What Each External Service Actually Does

| Service                             | Used for                                                          | Notes                                |
| ----------------------------------- | ----------------------------------------------------------------- | ------------------------------------ |
| **Firebase Storage**                | Stores uploaded videos permanently                                | Source of truth for video files      |
| **Firebase Firestore**              | Reel metadata, processing status, translations, user data         | Real-time listener drives UI updates |
| **Firebase Auth**                   | User accounts (email/password + Google Sign-In)                   | Standard Firebase auth               |
| **Firebase Cloud Functions**        | Orchestrates the pipeline                                         | Node.js 20, serverless               |
| **AWS S3**                          | Temporary storage for video files during transcription            | Files deleted after job completes    |
| **AWS Transcribe**                  | Speech-to-text with automatic language detection + SRT generation | The core transcription engine        |
| **AWS EventBridge / SNS**           | Notifies Firebase when transcription job completes                | Enables the non-polling architecture |
| **Google Cloud Video Intelligence** | Content moderation (explicit content + label detection)           | Runs in parallel with transcription  |
| **Google Cloud Translation API v3** | Batch translation of sentences into 15 languages                  | Final step before reel goes live     |

**OpenAI is not used in the current production pipeline.** The `OPENAI_API_KEY` environment variable referenced in some documentation and the older context document reflects an earlier iteration of the pipeline (v4.0) that used OpenAI Whisper for transcription. The current pipeline (v5.0-event-driven-aws) replaced Whisper with AWS Transcribe. The `OPENAI_API_KEY` env var and its documentation in the fork setup guide can be removed.

---

## Data Flow: End to End

```
User uploads video
        │
        ▼
Firebase Storage (videos/reels/{userId}/reel_{uuid}.mp4)
        │
        ├──────────────────────────┐
        ▼                          ▼
moderateContent             transcribeAndTranslate
(Google Video Intelligence) (starts AWS Transcribe job,
        │                    stores job in Firestore,
        │                    exits immediately)
        ▼                          │
  pass / reject              AWS Transcribe runs
        │                    (1–3 minutes, independent)
        │                          │
        │                          ▼
        │                   AWS EventBridge fires
        │                   → handleTranscribeWebhook
        │                          │
        │                    retrieve transcript + SRT
        │                    from S3
        │                          │
        │                    parse words[] + sentences[]
        │                          │
        │                    batch translate via
        │                    Google Cloud Translate
        │                    (14 API calls, one per
        │                     non-source language)
        │                          │
        │                    write to Firestore:
        │                    translations/{reelId}
        │                          │
        └──────────────────────────┘
                        │
                        ▼
              reels/{reelId}.processingStatus = 'completed'
                        │
                        ▼
              Flutter app stream listener fires
              → UI updates, reel appears in feed
```

---

## Known Limitations and Edge Cases

**Short audio:** Language detection requires at least ~10 seconds of speech. Very short clips may be misidentified.

**Multiple speakers:** AWS Transcribe detects the dominant language of the whole clip, not per-speaker. Mixed-language content will pick one language for the whole reel.

**Background music:** Heavy background music degrades transcription confidence. Confidence scores are stored per-sentence (accessible to the app) but not currently surfaced to users.

**Non-speech content:** Videos with no speech pass moderation but produce empty transcriptions. The reel will complete processing but show no subtitles.

**Translation fallback:** If a language fails during batch translation, it shows the source language text rather than an error. This is intentional — a partial reel is better than no reel.

**S3 cleanup:** If the webhook call fails mid-way through processing, S3 files and the `transcribe_jobs` Firestore document may be left orphaned. The `reprocessReel` function can be used to manually re-trigger the pipeline and clean up stale state.

---

## Processing Versions in Firestore

Reel documents store a `processingVersion` field that indicates which version of the pipeline processed them:

| Version                 | Description                                                    |
| ----------------------- | -------------------------------------------------------------- |
| `v4.0-openai-dual`      | Early version using OpenAI Whisper (deprecated)                |
| `v4.1-batch`            | Whisper + Google Translate batch (deprecated)                  |
| `v5.0-event-driven-aws` | Current: AWS Transcribe + EventBridge + Google Translate batch |

---

## Supported Languages

English, Spanish, French, German, Italian, Portuguese, Russian, Japanese, Korean, Chinese (Simplified), Arabic, Hindi, Kannada, Marathi, Tamil.

---

<div align="center">

[← Back to README](./README.md) · [Architecture](./docs/ARCHITECTURE.md) · [Product & strategy](./docs/PRODUCT.md) · [Fork & setup](./FORK_AND_SETUP.md)

</div>
