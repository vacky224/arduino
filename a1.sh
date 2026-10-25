#include <Wire.h>
#include <RTClib.h>
#include "HX711.h"

// --- Pin Definitions ---
const int LOADCELL_DOUT_PIN = 3;
const int LOADCELL_SCK_PIN = 2;
const int BUZZER_PIN = 8;

// --- Scale & Clock Objects ---
HX711 scale;
RTC_DS3231 rtc;

// --- Calibration Factor ---
const float CALIBRATION_FACTOR = 420.0; 

// --- Medication Schedule ---
const int TARGET_HOUR = 22;   // 22 for 10 PM
const int TARGET_MINUTE = 45; // Target time for medication
const float WEIGHT_THRESHOLD = 8.0; // Minimum weight (grams) to consider container present

void setup() {
  Serial.begin(9600);
  
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  if (!rtc.begin()) {
    Serial.println("Couldn't find RTC!");
    while (1);
  }

  // --- AUTOMATIC TIME SYNC ---
  // Active because you aren't using a battery backup. 
  // This syncs the clock to your PC every time the Arduino resets or powers on.
  rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));

  scale.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);
  scale.set_scale(CALIBRATION_FACTOR);
  
  // Keep scale completely empty during reset so this zeroes out correctly!
  scale.tare(); 
  
  Serial.println("Smart Medication Reminder Initialized & Clock Synced.");
}

void loop() {
  DateTime now = rtc.now();
  
  // Take multiple rapid samples and filter out extreme noise spikes using a median sort
  float w1 = scale.get_units(3);
  float w2 = scale.get_units(3);
  float w3 = scale.get_units(3);
  
  float currentWeight = (w1 > w2) ? ((w2 > w3) ? w2 : ((w1 > w3) ? w3 : w1)) : ((w1 > w3) ? w1 : ((w2 > w3) ? w3 : w2));

  // SAFETY CLAMP: Prevent negative drift or erratic spikes from messing up readings
  if (currentWeight < 0.0) {
    currentWeight = 0.0;
  }

  // Print current status to Serial Monitor
  Serial.print("Time: ");
  if (now.hour() < 10) Serial.print("0");
  Serial.print(now.hour());
  Serial.print(":");
  if (now.minute() < 10) Serial.print("0");
  Serial.print(now.minute());
  Serial.print(" | Weight: ");
  Serial.print(currentWeight, 1);
  Serial.println(" g");

  bool timeReached = (now.hour() > TARGET_HOUR) || 
                     (now.hour() == TARGET_HOUR && now.minute() >= TARGET_MINUTE);

  if (timeReached) {
    // If past target time AND container is still sitting on the scale -> ALARM ON
    if (currentWeight >= WEIGHT_THRESHOLD) {
      digitalWrite(BUZZER_PIN, HIGH); // Turn buzzer ON immediately
      Serial.println("ALARM: Medicine not taken! Buzzer active.");
    } 
    // If container has been removed -> CUT BUZZER OFF INSTANTLY
    else {
      digitalWrite(BUZZER_PIN, LOW); // Turn buzzer OFF immediately
      Serial.println("Medicine taken successfully!");
    }
  } else {
    // Before target time, ensure buzzer is quiet
    digitalWrite(BUZZER_PIN, LOW);
  }

  delay(200); // Fast check interval so it responds instantly
}
