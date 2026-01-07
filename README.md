# Mental Ability Trainer 

![Flutter](https://img.shields.io/badge/Flutter-3.19%2B-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.0%2B-0175C2?logo=dart)
![Hive](https://img.shields.io/badge/Hive-NoSQL-ff6f00)
![Platform](https://img.shields.io/badge/Platform-Android%2012%2B-green)

An offline-first, adaptive learning mobile application designed to assist students preparing for competitive exams like Navodaya (5th Grade), IBPS, UPSC, and Police recruitment.

## 📖 Overview

This application serves as a digital tutor for mental ability tests. Unlike static practice papers, it employs an **Intelligent Bias** system that learns from the student's mistakes and adapts the difficulty of subsequent questions.

The app is engineered to function autonomously in remote areas with **zero network dependency**.

## ✨ Key Features

* **Intelligent Bias:** The app detects incorrect answers and automatically provides a "bias in that direction" for subsequent sums, ensuring students practice their weak areas more often.
* **Instant Feedback Loop:**
    * Visual feedback (Green/Red) is provided immediately upon selection.
    * On an incorrect press, the correct answer is revealed instantly to reinforce learning.
* **Offline Capability:** The entire app, including the question bank and logging system, works in standalone mode without internet connectivity.
* **Coordinator Tools:** Incorrect answers are logged locally for the session, allowing local coordinators to identify and address student-specific errors.
* **Localization:** Full UI support for **Hindi, Marathi, and English**, selectable via the settings menu.
* **Programmable Timer:** A selectable timeout for every question with a sensible default of 2 minutes.

## ⚙️ Operational Modes

The app features distinct modes tailored for different learning stages:

1.  **Linear Mode:**
    * Designed for beginners or specific practice sessions.
    * Allows local coordinators to select a single category (e.g., *Odd Man Out* or *Figure Matching*) for focused learning.

2.  **Random Mode:**
    * Designed for advanced students or those who have completed individual categories.
    * Mixes questions dynamically based on the student's performance and the intelligent bias weights.

## 🛠️ Tech Stack

* **Framework:** **Flutter** (Dart)
    * *Reasoning:* Ensures high-performance rendering of figure patterns and cross-platform compatibility.
* **Database:** **Hive v2** (NoSQL)
    * *Reasoning:* A lightweight, pure-Dart database chosen for its speed and stability in offline environments, ensuring logs and question weights are saved securely without network access.
* **State Management:** **Riverpod/Provider**
    * *Reasoning:* Manages the complex state of the "Intelligent Bias" logic and language switching.
* **Platform Target:** **Android 12+** (API 31+).

---
