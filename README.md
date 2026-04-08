<div align="center">

<br/>

```
███████╗███╗   ██╗ █████╗ ██████╗ ███╗   ██╗███████╗███████╗████████╗
██╔════╝████╗  ██║██╔══██╗██╔══██╗████╗  ██║██╔════╝██╔════╝╚══██╔══╝
███████╗██╔██╗ ██║███████║██████╔╝██╔██╗ ██║█████╗  ███████╗   ██║   
╚════██║██║╚██╗██║██╔══██║██╔═══╝ ██║╚██╗██║██╔══╝  ╚════██║   ██║   
███████║██║ ╚████║██║  ██║██║     ██║ ╚████║███████╗███████║   ██║   
╚══════╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═══╝╚══════╝╚══════╝   ╚═╝   
```

### 📸 Event-Based Collaborative Photo Sharing

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Node.js](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![ML](https://img.shields.io/badge/ML-Image%20Clustering-FF6F00?style=for-the-badge&logo=tensorflow&logoColor=white)](https://www.tensorflow.org)


<br/>

</div>

---

## 🌟 Overview

**SnapNest** is a mobile application designed for **event-based collaborative photo sharing**. It allows users to create private event spaces, invite participants, and collectively upload and browse photos — all in one organized, secure environment.

Beyond simple sharing, SnapNest integrates a **machine learning-based image clustering** feature that automatically groups photos by the people in them, turning a flood of event photos into a neatly organized, browsable collection.

> *"Your memories, organized — not just stored."*

---

## ✨ Features

| Feature | Description |
|---|---|
| 🎉 **Event Creation** | Create private events with a unique join code or invite link |
| 👥 **Collaborative Uploads** | All invited members can upload photos to the shared event album |
| 🔒 **Secure Access Control** | Only invited participants can view or contribute to event content |
| 🤖 **ML Image Clustering** | Automatically groups photos by people using face-based clustering |
| 🗂️ **Smart Organization** | Browse photos by person, time, or contributor |
| 📱 **Cross-Platform** | Built with Flutter — runs on both Android and iOS |


## 🛠️ Tech Stack

### Frontend
- **Flutter** — Cross-platform mobile framework (Dart)
- **Provider / Riverpod** — State management
- **Firebase SDK** — Auth, Firestore, Storage integration

### Backend
- **Node.js + Express** — REST API server
- **Firebase Admin SDK** — Server-side Firebase operations
- **Firebase Firestore** — NoSQL database for events and user data
- **Firebase Storage** — Scalable image storage

### Machine Learning
- **Image Clustering** — Groups event photos by people present
- **Face Detection** — Identifies faces within uploaded images
- **Embedding & Similarity** — Groups similar faces across photos


## 🤖 ML Image Clustering — How It Works

```
📤 Photo Uploaded
      ↓
🔍 Face Detection (per image)
      ↓
🧠 Generate Face Embeddings
      ↓
📊 Cluster Similar Embeddings (e.g., DBSCAN / K-Means)
      ↓
🗂️ Group Photos by Person
      ↓
📱 Display in "People" tab in app
```

Photos are grouped intelligently so users can browse all photos featuring a specific person from the event — without any manual tagging.

---

## 🔐 Access Control

- Every event has a unique **invite link / code**
- Only users added to the event's member list can **view or upload** photos
- Firebase Security Rules enforce access at the database and storage level
- The Node.js backend validates membership before any sensitive operation

---

## 📸 Screenshots

> *(Add screenshots here)*

| Onboarding | Event Home | Photo Gallery | People Clusters |
|---|---|---|---|
| ![](screenshots/onboarding.png) | ![](screenshots/event.png) | ![](screenshots/gallery.png) | ![](screenshots/people.png) |

---

## 🗺️ Roadmap

- [x] Event creation & invite system
- [x] Collaborative photo upload
- [x] Secure access control
- [x] ML-based image clustering by people
- [ ] Push notifications for new uploads
- [ ] Download full event album as ZIP
- [ ] Story-style highlight reels
- [ ] Web version (Flutter Web)

---

## 🤝 Contributing

Contributions are welcome! Please open an issue first to discuss what you'd like to change.

```bash
# Fork → Clone → Create Branch → Commit → Push → PR
git checkout -b feature/your-feature-name
```


<div align="center">

Made with ❤️ by **Praveen**

*SnapNest — Because every event deserves more than a camera roll.*

</div>
