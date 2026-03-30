---

### 2. Frontend Repository-r jonno README.md (`LankaTransit`)

Ei code ti copy kore apnar frontend (Flutter) repository-r `README.md` file e paste korun:

```markdown
# 📱 LankaTransit Mobile Application

The LankaTransit mobile app is the user-facing client for Sri Lanka's next-generation bus transport network. Developed with Flutter, this cross-platform application provides distinct, feature-rich interfaces for Passengers, Bus Drivers, Bus Owners, and System Admins, bringing Uber-like convenience to public transportation.

## 🌟 Key Features

* **📍 Live Bus Tracking:** Integrates Google Maps API alongside open-source mapping APIs (for place search/routing) to provide passengers with real-time bus locations and accurate ETA calculations.
* **🎭 Multi-Role Architecture:**
  * **Passengers:** Search routes, view live maps, purchase digital tickets, and manage passes.
  * **Drivers:** Start/end trips, broadcast live location, and view passenger manifests.
  * **Bus Owners:** Manage fleet details, view revenue, and upload compliance documents.
  * **Admins:** Oversee the entire ecosystem, approve documents, and manage user roles.
* **📷 QR Ticket Scanner:** Built-in ticket scanning functionality for drivers/conductors to quickly validate digital tickets using device cameras.
* **📄 Document Management:** Seamless document upload screens for drivers and owners to submit licenses and registration details directly from their phones.
* **🎨 Modern UI/UX:** A clean, intuitive, and responsive interface designed to work flawlessly on a wide range of iOS and Android devices.

## 🛠️ Tech Stack

* **Framework:** Flutter (Dart)
* **Maps & Routing:** Google Maps SDK & Open-Source location search APIs
* **State Management & Networking:** Standard Flutter HTTP and state handlers (compatible with RESTful APIs)
* **Platform Support:** Android & iOS

## ⚙️ Getting Started

### Prerequisites
* Flutter SDK (Latest stable version)
* Android Studio / VS Code with Flutter plugins
* A valid Google Maps API Key

### Installation

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd lankatransit_app
