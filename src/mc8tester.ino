// Touchscreen-based multi-connector voltage and current monitor

/*

 Touchscreen library (display via SPI): https://github.com/adafruit/Adafruit_HX8357_Library

 Touchscreen library (direct touch): https://github.com/adafruit/Adafruit_TouchScreen

 Touchscreen library (I2C/SPI): https://github.com/adafruit/Adafruit_STMPE610

 */

#include <SPI.h>
#include "Adafruit_GFX.h"
#include "Adafruit_HX8357.h"
#include "mc8wiring.h"

// These are 'flexible' lines that can be changed
#define TFT_CS 10
#define TFT_DC 9
#define TFT_RST 8 // RST can be set to -1 if you tie it to Arduino's reset

// Use hardware SPI (on Uno, #13, #12, #11) and the above for CS/DC
Adafruit_HX8357 tft = Adafruit_HX8357(TFT_CS, TFT_DC, TFT_RST);

bool selecting;

int voltage_pins[8] = { A0, A2, A4, A6,
                        A8, A10, A12, A14 };

int current_pins[8] = { A1, A3, A5, A7,
                        A9, A11, A13, A15 };

static void display_at(int position,
                       char *wire_name,
                       int voltage,
                       int current) {
}

void setup(void) {
  /* initialize hardware */
  Serial.begin(9600);
  Serial.println("HX8357D Test!"); 

  tft.begin();

  // read diagnostics (optional but can help debug problems)
  uint8_t x = tft.readcommand8(HX8357_RDPOWMODE);
  Serial.print("Display Power Mode: 0x"); Serial.println(x, HEX);
  x = tft.readcommand8(HX8357_RDMADCTL);
  Serial.print("MADCTL Mode: 0x"); Serial.println(x, HEX);
  x = tft.readcommand8(HX8357_RDCOLMOD);
  Serial.print("Pixel Format: 0x"); Serial.println(x, HEX);
  x = tft.readcommand8(HX8357_RDDIM);
  Serial.print("Image Format: 0x"); Serial.println(x, HEX);
  x = tft.readcommand8(HX8357_RDDSDR);
  Serial.print("Self Diagnostic: 0x"); Serial.println(x, HEX); 

  /* show selection screen */
  selecting = true;
}

void loop()`{
  int selected = 0;             /* which connector we are on */
  
  if (selecting) {
    /* use touchscreen to select connector by name */
  } else {
    /* check touchscreen for commands */

    /* for each channel:
       read current and voltage
       cut off current if too high
       display current and voltage
    */
    for (int i = 0; i < 8; i++) {
      display_at(i,
                 connectors[selected].wire_indices[i],
                 analogRead(voltage_pins[i]),
                 analogRead(current_pins[i]));
    }
  }
}
