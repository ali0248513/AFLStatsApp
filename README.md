# 📱 AFL Match Tracker

A real-time, cross-platform sports analytics app built with **Flutter** and **Firebase**, designed for Australian Football League (AFL) match tracking and performance analysis.

---

## 🚀 Features

- 📊 **Live Match Tracking**: Log goals, marks, tackles in real-time
- 🔥 **Live Stats**: Automatic sync using Firestore listeners
- 👥 **Player Comparison**: View comparative performance across matches
- 📱 **Cross-Platform**: Android, iOS, Web, Windows, macOS, Linux
- 🗂 **Match History & Summaries**
- 🎨 **Clean UI** with responsive theming
- 🔒 **Modular & Scalable Architecture**

---

## 📷 Screenshots

### 🏠 Home Screen
![Home](https://github.com/user-attachments/assets/5b245a79-c001-492b-8125-737403560308)

### 📊 Match Summary View
![Summary](https://github.com/user-attachments/assets/80a02463-efbf-46a4-b5e9-a7b556050f4c)

### 🔍 Player Comparison
![Comparison](https://github.com/user-attachments/assets/affff6c1-0409-4ea6-81fb-49adbf64a842)

### 🧑‍🤝‍🧑 Team Stats
![Team Stats](https://github.com/user-attachments/assets/0532bc0d-47d2-46ee-9f01-75539c91f8f7)

### 🧾 Action Logging Screen
![Log Action](https://github.com/user-attachments/assets/0e0e94b5-3790-425c-8414-9a6202aced09)

### ⌛ Quarter Timer
![Timer](https://github.com/user-attachments/assets/fc688fa8-eebb-49c5-916b-32579aa1cc1c)

### 📂 Match History
![History](https://github.com/user-attachments/assets/a25098b6-1fe9-4af0-ba2f-0c384f40d138)

### ⚙️ Settings / About Screen
![About](https://github.com/user-attachments/assets/1741456c-d7da-4ea5-b7e4-cb4ede4cb97e)

### 📈 Real-time Stats View
![Live Stats](https://github.com/user-attachments/assets/5d296f29-2966-4079-b538-76b7481cbb60)

### 🔒 Role-based Access Screens
![Role UI](https://github.com/user-attachments/assets/152bea08-89f9-4159-bfdf-870d95523694)

### 📁 Player Profiles
![Player Profiles](https://github.com/user-attachments/assets/bf34b9c0-e4a5-4df6-bb09-bc935349fed4)

---

## 🛠 Tech Stack

- **Flutter** – UI Framework
- **Dart** – Programming Language
- **Firebase** – Backend and real-time DB (Firestore)
- **Firestore Listeners** – Real-time sync

---

## 🔧 Firebase Setup

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/).
2. Enable Firestore.
3. Add app (iOS, Android, Web, etc.) to Firebase.
4. Download and add google-services.json or GoogleService-Info.plist to respective folders.
5. For Web, update index.html with Firebase config snippet.
6. Initialize Firebase in main.dart:
   
dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await Firebase.initializeApp();
     runApp(MyApp());
   }

---
##📦 Installation
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
