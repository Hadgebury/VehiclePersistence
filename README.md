# **Vehicle Persistence & Cleanup Script**

### **📌 Overview**

This script prevents vehicles that have been used by a player from despawning while automatically cleaning up abandoned vehicles after a configurable period of inactivity. It ensures **only vehicles that have been driven by players** are tracked, preventing random parked AI vehicles from being affected.

## 📜 License  
This project uses a [custom license](LICENSE.md). **Do not redistribute or modify without permission.**  
---

## **🔧 Key Features**

### **1️⃣ Smart Vehicle Registration**

* **Only tracks player-driven vehicles** – A vehicle is registered when:
  * A player **enters it as a driver**
  * A player **spawns it and interacts with it**
* **Does NOT track:**
  * AI/parked vehicles
  * Vehicles never entered by a player

### **2️⃣ Automatic Cleanup with Warnings**

* **Configurable idle timer (default: 30 mins)**
  * Vehicles untouched for the full duration are removed
* **Warning messages** (customizable intervals):
  * **2 mins, 1 min, and 30 sec warnings** before cleanup
  * **Only the vehicle owner sees warnings** (not global spam)

### **3️⃣ Manual Admin Control**

* **`/cleanupvehicles` command**
  * Forces immediate cleanup of all inactive vehicles
  * Requires ACE permission (`command.cleanupvehicles`)

### **4️⃣ Performance Optimised**

* **Low-impact server checks** (every 30 sec by default)
* **Distance-based occupancy checks** (50m radius)
* **No residual memory leaks** – Cleanly removes tracked vehicles

---

## **⚙️ How It Works**

### **🔹 Vehicle Tracking Logic**

* A vehicle is registered **only when a player enters it** (client-side detection).
* The server tracks:
  * **Owner** (who spawned/used it)
  * **Last used time** (resets if any player enters)
  * **Warning status** (ensures no duplicate warnings)

### **🔹 Cleanup Process**

1. **Checks every 30 seconds** for inactive vehicles.
2. If a vehicle is **unoccupied for 30 mins**:
  * Sits through warning phases (2m, 1m, 30s).
  * Deletes only if still unused after the full timer.
3. **Active vehicles reset the timer** – even brief use extends their life.

### **🔹 Admin Command**

* **`/cleanupvehicles`** → Instantly removes all vehicles meeting idle criteria.
* **Permission-restricted** (adjustable in config).

---

## **📥 Installation**

1. **Add to `resources/` folder**
2. **Ensure in `server.cfg`:**

lua

Copy

Download

ensure AntiVehicleDespawner

3. **Customise settings in `server.lua`** (timers, messages, permissions).

---

## **✅ Why Use This Script?**

✔ **No more disappearing player vehicles**
✔ **Prevents server bloat from abandoned cars**
✔ **Private warnings (no global spam)**
✔ **Supports manual admin cleanup**
✔ **Optimised for performance**

Perfect for roleplay, freeroam, and economy servers! 🚗💨

---

### **🔗 Download & Support**
https://github.com/Hadgebury/VehiclePersistence

|                                         |                                |
|-------------------------------------|----------------------------|
| Code is accessible       | Yes               |
| Subscription-based      | No                 |
| Lines (approximately)  | 300 (Only Around 10 Are For Config/Setup)  |
| Requirements                | None      |
| Support                           | Yes                 |
