HelpLink
Installation Guide
Flutter Android App
Version 1.0.1 |  June 2026
1. System Requirements	3
1.1  Development Machine	3
1.2  Target Device (Android)	3
2. Prerequisites	4
2.1  Flutter SDK	4
2.2  Android Studio	4
2.3  Node.js (for Cloud Functions)	4
2.4  Firebase CLI	4
2.5  Git	5
2.6  Run Flutter Doctor	5
3. Project Setup	6
3.1  Clone the Repository	6
3.2  Install Flutter Dependencies	6
3.3  Install Cloud Functions Dependencies	6
4. Firebase Configuration	7
4.1  Verify google-services.json	7
4.2  Firebase Project Services	7
4.3  Firestore Indexes	7
4.4  Firestore Security Rules	7
4.5  Firebase Storage Rules	7
5. Environment Variables	8
5.1  Create the .env File	8
How to get a Gemini API key:	8
5.2  Cloud Functions Secrets	8
6. Running the App (Development)	9
6.1  Connect an Android Device	9
Option A – Physical Device:	9
Option B – Android Emulator:	9
6.2  Verify Device Detection	9
6.3  Run the App	9
7. Building a Release APK	10
7.1  Build the APK	10
7.2  Locate the APK	10
7.3  Install on Device	10
8. Deploying Cloud Functions	11
8.1  Build the Functions	11
8.2  Deploy All Functions	11
8.3  Deploy a Specific Function	11
8.4  View Function Logs	11
9. Troubleshooting	12

 
1. System Requirements
1.1 Development Machine
Component	Minimum	Recommended
OS	Windows 10 64-bit	Windows 11 64-bit
RAM	8 GB	16 GB
Disk Space	10 GB free	20 GB free
Processor	Intel Core i5	Intel Core i7 or above

1.2 Target Device (Android)
Requirement	Value
Android Version	Android 6.0 (API level 23) or above
RAM	2 GB minimum
Storage	100 MB free
Internet	Required (mobile data or Wi-Fi)
GPS	Required for location features
 
2. Prerequisites
Install the following tools in order before proceeding.

2.1 Flutter SDK
1.	Download Flutter SDK from the official Flutter website: https://docs.flutter.dev/get-started/install/windows
2.	Extract the zip file to C:\flutter (avoid paths with spaces).
3.	Add C:\flutter\bin to your system PATH environment variable:
•	Open Start and search Edit the system environment variables.
•	Click Environment Variables.
•	Under System Variables, select Path, then Edit, then New.
•	Add C:\flutter\bin and click OK.
4.	Verify installation:
flutter --version
Expected output: Flutter 3.x.x • channel stable

2.2 Android Studio
5.	Download and install Android Studio from: https://developer.android.com/studio
6.	During setup, install: Android SDK, Android SDK Platform-Tools, and Android Virtual Device (AVD).
7.	Open Android Studio, go to SDK Manager, and install Android 13.0 (API 33) or higher.
8.	Accept Android licenses:
flutter doctor --android-licenses
Press y to accept all.

2.3 Node.js (for Cloud Functions)
9.	Download and install Node.js LTS version (v18 or above) from: https://nodejs.org/
10.	Verify:
node --version
npm --version

2.4 Firebase CLI
11.	Install Firebase CLI globally:
npm install -g firebase-tools
12.	Login to Firebase:
firebase login
13.	Verify:
firebase --version

2.5 Git
14.	Download and install Git for Windows from: https://git-scm.com/download/win
15.	Verify:
git --version

2.6 Run Flutter Doctor
After all prerequisites are installed, run:
flutter doctor
Ensure there are no critical errors (items marked with a red X). Warnings about iOS can be ignored as this project targets Android only.
 
3. Project Setup
3.1 Clone the Repository
git clone https://github.com/Simoyyy/HelpLink.git
cd HelpLink

Or, if you received the project as a ZIP file:
16.	Extract the ZIP to a folder (e.g., C:\Users\YourName\Desktop\HelpLink).
17.	Open a terminal and navigate to that folder:
cd C:\Users\YourName\Desktop\HelpLink

3.2 Install Flutter Dependencies
flutter pub get
This downloads all packages listed in pubspec.yaml.

3.3 Install Cloud Functions Dependencies
cd functions
npm install
cd ..
 
4. Firebase Configuration
HelpLink uses Firebase for authentication, database, storage, push notifications, and cloud functions. The project already has a Firebase project configured.

4.1 Verify google-services.json
Ensure the file android/app/google-services.json exists in your project. This file links the app to the Firebase project. Do not share this file publicly.

NOTE	If the file is missing, obtain it from the project owner.

4.2Firebase Project Services
The following Firebase services must be enabled in the Firebase Console:
Service	Purpose
Authentication	User sign-in with email/password
Cloud Firestore	Real-time database for requests, messages, users
Firebase Storage	Photo and document uploads
Firebase Cloud Messaging	Push notifications
Cloud Functions	Server-side logic (OTP, notifications, automation)

4.3 Firestore Indexes
Deploy the required Firestore composite indexes:
firebase deploy --only firestore:indexes

4.4 Firestore Security Rules
Deploy security rules:
firebase deploy --only firestore:rules

4.5 Firebase Storage Rules
Deploy storage rules:
firebase deploy --only storage
 
5. Environment Variables
5.1 Create the .env File
Create a file named .env in the project root directory (same level as pubspec.yaml):
GEMINI_API_KEY=your_google_gemini_api_key_here

How to get a Gemini API key:
18.	Go to Google AI Studio: https://aistudio.google.com/
19.	Sign in with a Google account.
20.	Click Get API Key, then Create API Key.
21.	Copy the key and paste it in the .env file.

5.2 Cloud Functions Secrets
The Cloud Functions use Gmail SMTP for sending OTP emails. These secrets are stored securely in Firebase and do not need to be set up locally by developers unless redeploying functions.

If you need to redeploy with new credentials:
firebase functions:secrets:set GMAIL_EMAIL
firebase functions:secrets:set GMAIL_APP_PASSWORD

Follow the prompts to enter the Gmail address and App Password (not the regular Gmail password). Refer to https://support.google.com/accounts/answer/185833 for instructions on generating an App Password.
 
6. Running the App (Development)
6.1 Connect an Android Device
Option A – Physical Device:
22.	On your Android phone, go to Settings, then About Phone, and tap Build Number 7 times to enable Developer Options.
23.	Go to Settings, then Developer Options, and enable USB Debugging.
24.	Connect the phone to your computer via USB.
25.	Accept the Allow USB debugging? prompt on the phone.

Option B – Android Emulator:
26.	Open Android Studio, go to Device Manager, and click Create Device.
27.	Choose a device (e.g., Pixel 6), select a system image (API 33 or above), and click Finish.
28.	Click the green Play button to start the emulator.

6.2 Verify Device Detection
flutter devices
Your device or emulator should appear in the list.

6.3 Run the App
flutter run
The app will compile and launch on the connected device. The first build may take several minutes.

To run in release mode (faster, no debug output):
flutter run --release
 
7. Building a Release APK
To generate an installable APK for distribution:

7.1 Build the APK
flutter build apk --release

7.2 Locate the APK
The built APK is located at:
build\app\outputs\flutter-apk\app-release.apk

7.3 Install on Device
Connect the device and run:
flutter install

Or manually transfer the APK file to the phone and tap it to install (ensure Install from Unknown Sources is enabled in Android settings).
 
8. Deploying Cloud Functions
Cloud Functions handle OTP emails, push notifications, and automated request processing.

8.1 Build the Functions
cd functions
npm run build
cd ..

8.2 Deploy All Functions
firebase deploy --only functions

8.3 Deploy a Specific Function
firebase deploy --only functions:sendEmailVerificationOTP

8.4 View Function Logs
firebase functions:log
 
9. Troubleshooting
Issue	Solution
"flutter: command not found"	Flutter is not in your PATH. Re-check step 2.1 and restart your terminal.
"No devices found" when running flutter devices	Ensure USB Debugging is enabled on the device. Try a different USB cable or port. Restart ADB: run "adb kill-server" then "adb start-server".
"Gradle build failed"	Ensure Android SDK is installed correctly via Android Studio. Clean the build cache by running: flutter clean, then flutter pub get, then flutter run.
App crashes on launch / Firebase not initializing	Verify android/app/google-services.json exists and is the correct file. Ensure the Firebase project has all required services enabled.
OTP emails not being sent	Verify Firebase Cloud Functions are deployed. Check that GMAIL_EMAIL and GMAIL_APP_PASSWORD secrets are set in Firebase. View function logs: firebase functions:log
Google Maps not displaying	Ensure the Google Maps SDK is enabled in your Google Cloud Console. Verify the API key in android/app/src/main/AndroidManifest.xml.
Gemini AI chat not responding	Verify the GEMINI_API_KEY in your .env file is valid. Check your internet connection and API quota at Google AI Studio.
