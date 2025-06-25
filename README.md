AFL Match Tracker is a real-time, cross-platform sports analytics application built using **Flutter** and **Firebase**, designed specifically for the **Australian Football League (AFL)**. It enables users to track matches live, log player actions, compare statistics, and analyze performance — all from an intuitive and responsive interface.

## 🚀 Features

- 📊 **Live Match Tracking**: Log actions such as goals, marks, and tackles in real-time.
- 🔥 **Real-Time Stats**: See player and team stats update live using Firestore listeners.
- 👥 **Player Comparison**: Compare performance between multiple players across matches.
- 📱 **Cross-Platform**: Fully compatible with Android, iOS, Web, Windows, macOS, and Linux.
- 🗂 **Match History & Summaries**: Access detailed match breakdowns and chronological event logs.
- 🎨 **Clean UI**: Fully responsive design with consistent theming and intuitive navigation.
- 🔒 **Modular Architecture**: Organized codebase for scalability and maintainability.

---

## 📷 Screenshots

![image](https://github.com/user-attachments/assets/0e1ea974-de3a-415e-9865-411e31972285)


---

## 🛠 Tech Stack

- **Flutter** (UI Framework)
- **Firebase** (Cloud Firestore for real-time DB)
- **Dart** (Programming Language)
- **Firestore Listeners** (Live data syncing)

---
## 🔧 Firebase Setup

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/).
2. Enable Firestore.
3. Add app (iOS, Android, Web, etc.) to Firebase.
4. Download and add `google-services.json` or `GoogleService-Info.plist` to respective folders.
5. For Web, update `index.html` with Firebase config snippet.
6. Initialize Firebase in `main.dart`:
   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await Firebase.initializeApp();
     runApp(MyApp());
   }

---
## 📦 Installation
Prerequisites
Flutter SDK: https://flutter.dev/docs/get-started/install

Firebase account

🚧 Challenges Faced
Real-time state synchronization during fast-paced matches

Firebase platform setup (especially for Web)

Preventing illogical action sequences during play

Ensuring smooth performance during rapid action logging

🌱 Future Enhancements
Firebase Authentication for personalized data views

Export match data to CSV/PDF

Offline support with local caching

Admin panel for user and team management

Advanced charts and visual analytics

📚 References & Inspiration
Flutter Documentation

Firebase Docs

The Net Ninja - Flutter Playlist

Fireship.io

OpenAI ChatGPT (architecture suggestions)

Stack Overflow

📄 License
MIT License – feel free to use, modify, and contribute!

🙌 Contributions
Contributions are welcome! Fork the repository, submit a pull request, or open an issue for discussion.


---
Have questions or suggestions? Open an issue or reach out at: ali0248513@gmail.com
