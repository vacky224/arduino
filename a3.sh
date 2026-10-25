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
const int TARGET_HOUR = 2;    // Set to 2 AM
const int TARGET_MINUTE = 56; // Set to 53 for immediate testing
const float WEIGHT_THRESHOLD = 3.0; // Trigger threshold in grams (container/load present)

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
  
  // --- Initialization & User Prompts ---
  Serial.println("Smart Medication Reminder Initialized.");
  Serial.println("Calibration Complete and you can add a load");
}

void loop() {
  DateTime now = rtc.now();
  
  // Average of 5 raw samples to eliminate jitter and ensure consistent weight readings
  long rawVal = scale.read_average(5);          
  
  // Calculate weight manually: (Raw - Baseline) / Calibration Factor
  float currentWeight = (float)(rawVal - ZERO_OFFSET) / CALIBRATION_FACTOR;

  // SAFETY CLAMP: Prevent negative drift or erratic spikes below zero
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

  // Check if current time has reached or passed the scheduled medication time
  bool timeReached = (now.hour() > TARGET_HOUR) || 
                     (now.hour() == TARGET_HOUR && now.minute() >= TARGET_MINUTE);

  if (timeReached) {
    // --- MEDICATION TIME ACTIVE ---
    
    if (currentWeight >= WEIGHT_THRESHOLD) {
      // Medicine has NOT been taken (container/load is still on the scale) -> BUZZER ON
      digitalWrite(BUZZER_PIN, HIGH); 
      Serial.println("ALARM: Medicine not taken! Buzzer active.");
    } 
    else {
      // Medicine HAS been taken (container/load was removed) -> BUZZER OFF
      digitalWrite(BUZZER_PIN, LOW); 
      Serial.println("Medicine taken successfully!");
    }
  } else {
    // Before schedule time -> Keep buzzer off
    digitalWrite(BUZZER_PIN, LOW);
  }

  delay(200); 
}
