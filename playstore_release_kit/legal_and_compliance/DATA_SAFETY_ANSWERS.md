# Google Play Data Safety Form Answers for BizPilot AI

When publishing to Google Play Console, use these exact answers in the **Data safety** section:

---

### 1. Does your app collect or share any of the required user data types?
- **Answer:** **No**, if purely used in offline mode without personal analytics.
- If using customer contact logging for Khata:
  - **Financial Info:** Purchase history (Stored on device, not shared with third parties).
  - **Contact Info:** Phone number / Name of customer (Stored locally for ledger & WhatsApp link generation).

### 2. Is data encrypted in transit?
- **Answer:** **Yes**. All network requests to the backend API use HTTPS.

### 3. Do you provide a way for users to request data deletion?
- **Answer:** **Yes**. Users can clear local storage and delete individual records anytime from within the app settings.

### 4. Permissions Breakdown:
- `CAMERA`: Used for real-time barcode scanning. Data is processed locally in-memory and discarded immediately after recognition.
- `BLUETOOTH_CONNECT / BLUETOOTH_SCAN`: Used to pair with thermal receipt printers. No audio or location data is collected.
