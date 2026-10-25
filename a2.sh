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

// --- Calibration & Offset ---
long ZERO_OFFSET = 605300; // Empty baseline raw count
const float CALIBRATION_FACTOR = 233.3; // Corrected factor for 45g load span

// --- Medication Schedule ---
const int TARGET_HOUR = 22;   // 22 for 10 PM
const int TARGET_MINUTE = 45; // Target time for medication
const float WEIGHT_THRESHOLD = 3.0; // Trigger threshold in grams

void setup() {
  Serial.begin(9600);
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  if (!rtc.begin()) {
    Serial.println("Couldn't find RTC!");
    while (1);
  }

  // --- AUTOMATIC TIME SYNC ---
  rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));

  scale.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);
  
  Serial.println("Smart Medication Reminder Fully Initialized & Calibrated.");
}

void loop() {
  DateTime now = rtc.now();
  
  long rawVal = scale.read();          
  
  // Calculate weight manually: (Raw - Baseline) / Calibration Factor
  float currentWeight = (float)(rawVal - ZERO_OFFSET) / CALIBRATION_FACTOR;

  // SAFETY CLAMP: Prevent negative drift or spikes below zero
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
  Serial.print(" | Raw: ");
  Serial.print(rawVal);
  Serial.print(" | Weight: ");
  Serial.print(currentWeight, 1);
  Serial.println(" g");

  bool timeReached = (now.hour() > TARGET_HOUR) || 
                     (now.hour() == TARGET_HOUR && now.minute() >= TARGET_MINUTE);

  if (timeReached) {
    // If past target time AND medicine container/load is still sitting on the scale -> ALARM ON
    if (currentWeight >= WEIGHT_THRESHOLD) {
      digitalWrite(BUZZER_PIN, HIGH); 
      Serial.println("ALARM: Medicine not taken! Buzzer active.");
    } 
    // If container/load has been removed -> CUT BUZZER OFF
    else {
      digitalWrite(BUZZER_PIN, LOW); 
      Serial.println("Medicine taken successfully!");
    }
  } else {
    digitalWrite(BUZZER_PIN, LOW);
  }

  delay(200); 
}
