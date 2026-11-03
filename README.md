# Stock Inventory Manager

This Flutter app records stock for a small retailer. Install Flutter, run `flutter pub get`, and obtain the registered web app settings for the lecturer's Firebase project. The app uses `firebase_core` and `cloud_firestore`. Class project ID: labtest-78fe3. Create firebase.local.json with FIREBASE_PROJECT_ID, FIREBASE_API_KEY, FIREBASE_APP_ID and FIREBASE_SENDER_ID from the registered web app. This file contains the four web configuration values and is excluded from Git. Run from this directory:

```sh
flutter run -d chrome --dart-define-from-file=firebase.local.json
```

Each valid submission creates an auto-ID document in `stockItems`. The SKU must match STK- followed by three digits. The trimmed item name needs three characters. Choose Electronics, Stationery, Hardware or Grocery. Quantity and reorderLevel are nonnegative integers. unitPrice is a positive RM amount. Firestore assigns the createdAt server timestamp. The form retains entered values after a failed write.

The inventory listens for Firestore snapshots. A partial keyword matches either name or SKU regardless of case. Category and low-stock restrictions apply together. Low stock includes equality between quantity and reorder level. Toggle quantity order to sort the visible items. Clear Filters restores the full list.

## Test log

| Input | Expected | Actual / evidence |
|---|---|---|
| Submit blank form | Field errors and no write | Automated validation test passed in test/widget_test.dart. [Field errors](screenshots/invalid.png). |
| Save STK-101 USB C Cable, Electronics, 4, RM19.90, reorder 5; STK-102 Notebook, Stationery, 25, RM4.50, reorder 10; STK-103 Wireless Mouse, Electronics, 1, RM35.00, reorder 3. Reload. | Three saved records; ascending quantity order 103, 101, 102 | Three required records retrieved. STK-104 was also saved from the app. [Inventory](screenshots/inventory.png). Reload check pending. |
| Search mouse with Electronics and Low stock only | Only STK-103; Clear Filters restores all saved items | Three required records retrieved. STK-104 was also saved from the app. [Inventory](screenshots/inventory.png). Reload check pending. |



