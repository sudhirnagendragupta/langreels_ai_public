# 🍴 Fork & Setup Guide

This guide walks you through everything needed to run your own instance of LangReels AI. The app uses Firebase (Flutter + Cloud Functions), Google Cloud Translation + Video Intelligence, and AWS Transcribe — you'll need accounts for each.

---

## Prerequisites

Before you begin, install the following tools:

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (≥ 3.x)
- [Node.js](https://nodejs.org/) (≥ 18.x) — required for Firebase Cloud Functions
- [Firebase CLI](https://firebase.google.com/docs/cli): `npm install -g firebase-tools`
- [FlutterFire CLI](https://firebase.flutter.dev/docs/cli): `dart pub global activate flutterfire_cli`
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) (optional, for S3 bucket setup)

---

## Step 1 — Clone the repo

```bash
git clone https://github.com/sudhirnagendragupta/langreels_ai_public.git
cd langreels_ai
flutter pub get
```

---

## Step 2 — Create a Firebase project

1. Go to [https://console.firebase.google.com](https://console.firebase.google.com) and click **Add project**.
2. Give it a name (e.g. `my-langreels`). Enable Google Analytics if you want it.
3. In the project, enable the following services:
   - **Authentication** → Sign-in providers: Email/Password and Google
   - **Firestore Database** → Start in production mode
   - **Storage** → Start in production mode
   - **Functions** → Requires Blaze (pay-as-you-go) plan

---

## Step 3 — Generate Firebase config files

These files are **gitignored** and must be generated for your own project. From the repo root:

```bash
firebase login
flutterfire configure
```

The FlutterFire CLI will prompt you to select your project and will automatically generate:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

> **Tip:** Example/template versions of these files are committed as `.example` files if you want to understand their structure before running the CLI.

---

## Step 4 — Set up Google Cloud Translation API

1. In [Google Cloud Console](https://console.cloud.google.com), select your Firebase project.
2. Navigate to **APIs & Services → Library** and enable:
   - **Cloud Translation API**
   - **Video Intelligence API**
3. No additional credentials needed — your Firebase service account is used automatically by Cloud Functions.

---

## Step 5 — Set up AWS (Transcribe + S3 + SNS + EventBridge)

The transcription pipeline uses four AWS services wired together. **Important:** complete Steps 6 and 7 (configure + deploy Cloud Functions) before finishing Step 5.3 — you need the deployed webhook URL before creating the SNS subscription.

**5.1 Create an S3 bucket**

- Go to S3 → Create bucket
- Choose a unique name (e.g. `my-langreels-transcribe`)
- Select your preferred region (e.g. `us-east-1`)
- Block all public access; keep all other defaults

**5.2 Create an IAM user**

- Go to IAM → Users → Create user
- Attach policies: `AmazonTranscribeFullAccess` + `AmazonS3FullAccess` + `AmazonSNSFullAccess`
- Security credentials → Create access key → copy the **Access Key ID** and **Secret Access Key**

**5.3 Create an SNS topic and subscription** _(complete after Step 7)_

- Go to SNS → Topics → Create topic → select **Standard**
- Name it (e.g. `my-langreels-transcribe-notifications`)
- Once created, go to Subscriptions → Create subscription:
  - Protocol: **HTTPS**
  - Endpoint: your `handleTranscribeWebhook` Cloud Function URL (from `firebase functions:list` after Step 7)
- AWS immediately sends a `SubscriptionConfirmation` POST — the function handles this automatically and status changes from `PendingConfirmation` to **Confirmed** within seconds
- Verify status shows **Confirmed** before proceeding

**5.4 Create an EventBridge rule**

- Go to EventBridge → Rules → Create rule
- Name it something descriptive (e.g. `trigger-webhook-on-transcribe-complete`)
- Event source: **AWS events or EventBridge partner events**
- Event pattern — paste this JSON exactly:
  ```json
  {
    "source": ["aws.transcribe"],
    "detail-type": ["Transcribe Job State Change"],
    "detail": {
      "TranscriptionJobStatus": ["COMPLETED", "FAILED"]
    }
  }
  ```
- Target: **SNS topic** → select the topic you created in step 5.3
- This rule fires whenever any Transcribe job in your account reaches `COMPLETED` or `FAILED` — the webhook looks up the job name in Firestore to find the corresponding reel

---

## Step 6 — Configure Cloud Functions environment

Copy the example env file and fill in your values:

```bash
cd functions
cp .env.example .env
```

Open `functions/.env` and replace each placeholder:

```bash
GCLOUD_PROJECT=your-firebase-project-id     # From Firebase Console → Project Settings
AWS_ACCESS_KEY_ID=AKIA...                   # From IAM user you created
AWS_SECRET_ACCESS_KEY=...                   # From IAM user you created
AWS_REGION=us-east-1                        # Must match your S3 bucket region
AWS_S3_BUCKET=my-langreels-transcribe       # The S3 bucket name you created

# Email configuration (Nodemailer / Resend SMTP)
SMTP_CONNECTION_URI=smtps://resend:re_...   # Your SMTP connection URI
DEFAULT_FROM=LangReels <noreply@yourdomain.com>
DEFAULT_REPLY_TO=support@yourdomain.com
ADMIN_EMAIL=admin@yourdomain.com            # Destination for bug reports and feedback
```

> ⚠️ Never commit `.env` — it's listed in `.gitignore`.

---

## Step 7 — Deploy Cloud Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

After deploying, get your `handleTranscribeWebhook` URL:

```bash
firebase functions:list
# Copy the URL for handleTranscribeWebhook
```

Then go back to AWS SNS → your topic → Subscriptions → Create subscription, and paste that URL as the HTTPS endpoint. AWS will immediately send a `SubscriptionConfirmation` POST — the function handles this automatically and confirms within seconds.

To verify everything is working:

```bash
firebase functions:call healthCheck
```

You should see a JSON response confirming all services are connected.

---

## Step 8 — Deploy Firestore rules and indexes

```bash
firebase deploy --only firestore
firebase deploy --only storage
```

---

## Step 9 — Run the app

```bash
cd ..   # back to repo root
flutter run
```

For a specific platform:

```bash
flutter run -d android
flutter run -d ios       # requires Xcode on macOS
```

---

## Environment variable reference

| Variable                | Where to get it                                   |
| ----------------------- | ------------------------------------------------- |
| `GCLOUD_PROJECT`        | Firebase Console → Project Settings → Project ID  |
| `AWS_ACCESS_KEY_ID`     | AWS IAM → Users → Security credentials            |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM → Users → Security credentials            |
| `AWS_REGION`            | The region you chose when creating your S3 bucket |
| `AWS_S3_BUCKET`         | The name of the S3 bucket you created             |

---

## Troubleshooting

**`MissingPluginException` on launch**
Run `flutter clean && flutter pub get`, then restart.

**Functions deploy fails with "requires Blaze plan"**
Upgrade your Firebase project to the Blaze (pay-as-you-go) plan. Cloud Functions are not available on the free Spark plan.

**`google-services.json` not found**
Re-run `flutterfire configure` from the project root. Make sure you're logged into the correct Firebase account.

**AWS Transcribe job failing**
Check that your IAM user has both `AmazonTranscribeFullAccess` and `AmazonS3FullAccess`, and that `AWS_REGION` matches the region of your S3 bucket.

**Translation not working / only some languages**
Confirm the Cloud Translation API is enabled in your GCP project. Check Cloud Functions logs:

```bash
firebase functions:log
```

---

## Estimated running costs

| Service                  | Usage               | Approx. cost                 |
| ------------------------ | ------------------- | ---------------------------- |
| Google Cloud Translation | Per character       | ~$20 per 1M chars            |
| AWS Transcribe           | Per minute of audio | ~$0.024/min                  |
| AWS S3                   | Storage + requests  | < $1/month at small scale    |
| Firebase Functions       | Per invocation      | Free tier covers light usage |
| Firebase Firestore       | Reads/writes        | Free tier covers light usage |

At small scale (a few hundred videos/month), total cost is typically under **$5–15/month**.

---

## Contributing

Pull requests welcome! Please open an issue first to discuss significant changes.

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes
4. Push and open a PR

---

## License

MIT — see [LICENSE](LICENSE) for details.

---

<div align="center">

[← Back to README](./README.md) · [How it works](./HOW_IT_WORKS.md) · [Architecture](./docs/ARCHITECTURE.md) · [Purge history](./PURGE_HISTORY.md)

</div>
