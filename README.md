# LangReels AI

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-lightgrey?logo=apple)
![Firebase](https://img.shields.io/badge/Firebase-Functions-FFCA28?logo=firebase&logoColor=black)
![AWS](https://img.shields.io/badge/AWS-Transcribe-FF9900?logo=amazonaws&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Sudhir%20Gupta-0077B5?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/product-manager-sudhir-gupta)

> Record a short video in any language. In under 3 minutes, it becomes a multi-language learning reel — transcribed, translated into 15 languages, and subtitled with sentence-level study controls. No manual editing required.

**Flutter (iOS/Android) · Firebase · AWS Transcribe · Google Cloud Translation · Google Video Intelligence**

📖 **[Full case study and product thinking → guptasudhir.com](https://guptasudhir.com/projects/langreels-language-learning)**

---

## Screenshots

<table>
  <tr>
    <td align="center">
      <img src="https://guptasudhir.com/images/projects/langreels/langreels_1.png" width="220" alt="Home feed — vertical video with subtitles"/><br/>
      <sub>Home feed with live subtitles</sub>
    </td>
    <td align="center">
      <img src="https://guptasudhir.com/images/projects/langreels/langreels_2.png" width="220" alt="AI content pipeline — processing status"/><br/>
      <sub>AI processing pipeline</sub>
    </td>
    <td align="center">
      <img src="https://guptasudhir.com/images/projects/langreels/langreels_3.png" width="220" alt="Study mode — sentence navigation controls"/><br/>
      <sub>Study mode with sentence controls</sub>
    </td>
  </tr>
</table>

---

## Sample content

13 short test reels across 12 languages — recorded during development to verify the pipeline. Useful if you want to try the app or test your own fork without recording new content.

| Language   | Script family  |
| ---------- | -------------- |
| Arabic     | Arabic (RTL)   |
| Chinese    | CJK            |
| French     | Latin          |
| German     | Latin          |
| Hindi      | Devanagari     |
| Italian    | Latin          |
| Kannada    | Kannada script |
| Korean     | Hangul         |
| Marathi    | Devanagari     |
| Portuguese | Latin          |
| Russian    | Cyrillic       |
| Spanish    | Latin          |

▶ **[View test reels on YouTube](https://www.youtube.com/playlist?list=PLjtPHYrOEBkPxRAz-W4CtR2ANhMWO2-Xu)**

_Test reels created with [Veed.io](https://veed.io). Each was processed automatically by the pipeline — transcribed by AWS Transcribe and translated into 15 languages by Google Cloud Translation._

---

## What it does

A creator records or uploads a video (up to 2 minutes). The moment it lands in Firebase Storage, an automated pipeline kicks off:

1. **Content moderation** — Google Video Intelligence scans for explicit content in parallel with transcription
2. **Transcription** — AWS Transcribe detects the spoken language and produces word-level timing and sentence boundaries via SRT output
3. **Translation** — Google Translate batch API converts every sentence into 15 languages simultaneously
4. **Delivery** — the completed reel appears in the feed with two viewing modes

Viewers can watch in **normal mode** (word-by-word karaoke-style subtitles) or flip to **study mode** (sentence-by-sentence navigation with replay controls) — switching between them is instant, no reload.

---

## Documentation

| Document                                  | What's in it                                                       |
| ----------------------------------------- | ------------------------------------------------------------------ |
| [How it works](./HOW_IT_WORKS.md)         | Full UX walkthrough + backend pipeline explained in plain language |
| [Architecture](./docs/ARCHITECTURE.md)    | Service map, data flow, Firestore schema, pipeline versions        |
| [Product & strategy](./docs/PRODUCT.md)   | Learning science rationale, feature design decisions, roadmap      |
| [Fork & setup](./FORK_AND_SETUP.md)       | Step-by-step guide to run your own instance                        |
| [Purging git history](./PURGE_HISTORY.md) | Required before making a fork public — removes committed secrets   |

---

## Tech stack

| Layer              | Technology                                              |
| ------------------ | ------------------------------------------------------- |
| Mobile app         | Flutter (iOS + Android), Provider state management      |
| Auth + database    | Firebase Auth, Firestore                                |
| File storage       | Firebase Storage                                        |
| Backend            | Firebase Cloud Functions (Node.js 20)                   |
| Speech-to-text     | AWS Transcribe — auto language detection, SRT output    |
| Job callbacks      | AWS EventBridge (rule) → AWS SNS (topic) → HTTP webhook |
| Translation        | Google Cloud Translation API v3 (batch)                 |
| Content moderation | Google Cloud Video Intelligence API                     |
| Temp file storage  | AWS S3 (ephemeral — deleted after each job)             |

---

## Supported languages

English · Spanish · French · German · Italian · Portuguese · Russian · Japanese · Korean · Chinese · Arabic · Hindi · Kannada · Marathi · Tamil

---

## Quick start

Full instructions are in [Fork & setup](./FORK_AND_SETUP.md). The short version:

```bash
git clone https://github.com/sudhirnagendragupta/langreels_ai_public.git
cd langreels_ai
flutter pub get

# Generate your own Firebase config (do not use committed .example files directly)
flutterfire configure

# Set up backend secrets
cp functions/.env.example functions/.env
# Edit functions/.env with your own API keys

# Deploy
cd functions && npm install && firebase deploy --only functions
cd .. && flutter run
```

You'll need accounts for Firebase, AWS (Transcribe + S3), and Google Cloud (Translation + Video Intelligence). See [Fork & setup](./FORK_AND_SETUP.md) for the full walkthrough including IAM setup, API enablement, and cost estimates (~$0.10–0.15 per video at small scale).

---

## Repository structure

```
langreels_ai/
├── lib/                        # Flutter app
│   ├── models/                 # AILanguageReel, SentenceData, WordData
│   ├── providers/              # Auth, Reel, User, Theme (Provider pattern)
│   ├── screens/                # Home, Create, Profile, Search, Auth
│   ├── services/               # Firebase, Auth service layer
│   └── widgets/                # Video player, subtitle overlays, UI components
├── functions/                  # Firebase Cloud Functions (Node.js)
│   ├── index.js                # All 5 deployed functions
│   ├── sentence-processor.js   # Legacy — not imported, safe to delete
│   ├── translation-mapper.js   # Legacy — not imported, safe to delete
│   └── .env.example            # Environment variable template
├── android/                    # Android runner + google-services.json.example
├── ios/                        # iOS runner + GoogleService-Info.plist.example
├── firestore.rules
├── storage.rules
├── HOW_IT_WORKS.md
├── FORK_AND_SETUP.md
├── PURGE_HISTORY.md
└── docs/
    ├── ARCHITECTURE.md
    └── PRODUCT.md
```

---

## Key design decisions

**Why AWS Transcribe instead of OpenAI Whisper?**
Earlier versions (v4.0) used Whisper. AWS Transcribe was adopted for its native SRT output, built-in language detection across all 15 supported codes, and the event-driven architecture that avoids Cloud Function timeout limits. See [Architecture](./docs/ARCHITECTURE.md).

**Why event-driven (not polling)?**
Transcription jobs take 1–3 minutes. Holding a Cloud Function open to poll AWS would be expensive and fragile. Instead, `transcribeAndTranslate` starts the job and exits in ~10 seconds. When the job completes, AWS EventBridge captures the Transcribe job-complete event, routes it to an SNS topic, which HTTP-posts to `handleTranscribeWebhook` to continue processing. No polling, no timeout risk. The code handles the SNS layer directly; EventBridge is configured in the AWS console as the upstream event rule.

**Why batch translation?**
Earlier versions translated full transcript text and tried to split the result back into sentences — causing truncation. The current approach sends all sentences as an array to Google Translate and gets back a 1:1 mapped array. Zero truncation, simpler code, same API cost.

---

## Contributing

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes
4. Open a pull request

Please open an issue first for significant changes.

---

## License

MIT — see [LICENSE](./LICENSE) for details.

---

## About the author

Built by [Sudhir Gupta](https://guptasudhir.com) — product leader and founder working at the intersection of AI and education. LangReels is an exploration of what happens when you remove all the friction from language learning content creation and let AI handle the heavy lifting.

If you're building something in EdTech or AI-powered mobile, or just want to discuss the architecture, [let's connect](https://www.linkedin.com/in/product-manager-sudhir-gupta).

---

<div align="center">

**Docs:** [How it works](./HOW_IT_WORKS.md) · [Architecture](./docs/ARCHITECTURE.md) · [Product & strategy](./docs/PRODUCT.md) · [Fork & setup](./FORK_AND_SETUP.md) · [Purge history](./PURGE_HISTORY.md)

**[↑ Back to top](#langreels-ai)**

</div>
