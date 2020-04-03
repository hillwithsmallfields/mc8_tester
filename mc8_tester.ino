#include <Adafruit_STMPE610.h>

#include <Adafruit_SPITFT_Macros.h>
#include <Adafruit_GFX.h>
#include <gfxfont.h>
#include <Adafruit_SPITFT.h>

/* Touchscreen-based multi-connector voltage and current monitor

   I rebuilt and extended my Land Rover, and rewired it my own way.
   Instead of using a conventional wiring loom, I used 8-core trailer
   cables with MC8 connectors, mostly radiating from a central hub
   inside the dashboard.  The connections are documented in an orgmode
   file, with some conventions on how to read the tables in it, and I
   wrote some elisp to generate the wiring instructions for building
   the hub.  After a couple of attempts at 8-core cable debuggers
   using LEDs, I decided to do it properly, and make an Arduino-based
   tester that knows what is on each pin of each cable, and, when told
   what connector it is plugged inline with, can show a list of the
   pins, along with the voltages and currents on them.

   This uses an Arduino Mega, as it needs 16 analog inputs (8 voltage,
   8 current).

   Touchscreen library (display via SPI): https://github.com/adafruit/Adafruit_HX8357_Library
   This also needs https://github.com/adafruit/Adafruit_GFX

   Touchscreen library (I2C/SPI --- we are using I2C to leave SPI for
   the display): https://github.com/adafruit/Adafruit_STMPE610

   Hardware details:

   Touch screen mounting holes are 2mm in each dimension from the
   corners or 90mm x 60mm apart.

   Software notes:

   Screen coordinates have origin at top left corner; the size is
   320x480.  The built-in font size is 5x8 pixels.  See
   https://learn.adafruit.com/adafruit-gfx-graphics-library/overview
   for introduction.

   void drawRect(uint16_t x0, uint16_t y0, uint16_t w, uint16_t h, uint16_t color);
   void fillRect(uint16_t x0, uint16_t y0, uint16_t w, uint16_t h, uint16_t color);
   void drawRoundRect(uint16_t x0, uint16_t y0, uint16_t w, uint16_t h, uint16_t radius, uint16_t color);
   void fillRoundRect(uint16_t x0, uint16_t y0, uint16_t w, uint16_t h, uint16_t radius, uint16_t color);
   void setCursor(uint16_t x0, uint16_t y0);
   void setTextColor(uint16_t color);
   void setTextColor(uint16_t color, uint16_t backgroundcolor);
   void setTextSize(uint8_t size);
   void setTextWrap(boolean w);
   void print(...);
   void fillScreen(uint16_t color);
   void setRotation(uint8_t rotation);
   uint16_t width();
   uint16_t height();

 */

#include <SPI.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_HX8357.h>
#include <Adafruit_STMPE610.h>
#include "mc8wiring.h"
#include "wiring.h"

// These are 'flexible' lines that can be changed
#define TFT_CS 10
#define TFT_DC 9
#define TFT_RST 8 // RST can be set to -1 if you tie it to Arduino's reset

// Use hardware SPI for the screen (on Uno, #13, #12, #11) and the above for CS/DC
Adafruit_HX8357 tft = Adafruit_HX8357(TFT_CS, TFT_DC, TFT_RST);

// Use hardware I2C for the touch reader
// Connect to hardware I2C port only!
// SCL to I2C clock (#A5 on Uno) and SDA to I2C data (#A4 on Uno)
// tie MODE to GND and POWER CYCLE (there is no reset pin)

// todo: any changes to make it work on the Mega

Adafruit_STMPE610 touch = Adafruit_STMPE610();

bool selecting;
int select_column = 36;         /* todo: find a suitable value */

#define N_WIRES 8

int voltage_pins[N_WIRES] = { A0, A2, A4, A6,
                              A8, A10, A12, A14 };

int current_pins[N_WIRES] = { A1, A3, A5, A7,
                              A9, A11, A13, A15 };

int16_t row_height;
int16_t char_width = 8;

#define NUMBER_COLUMN 1
#define VOLTAGE_COLUMN 4
#define CURRENT_COLUMN 8
#define LABEL_COLUMN 12

int16_t screen_width;

/* Display a name, voltage, and current at one of 8 positions on the
   screen.  Set the background colour according to some conditions. */
static void display_at(int position,
                       char *wire_name,
                       int voltage,
                       int current) {
  uint16_t y = (position + 1) * row_height;
  
  tft.setCursor(NUMBER_COLUMN * char_width, y);
  tft.setTextColor(HX8357_BLACK, HX8357_WHITE);
  tft.print(position+1);

  tft.setCursor(VOLTAGE_COLUMN * char_width, y);
  tft.setTextColor(voltage > 9 ? HX8357_RED : HX8357_BLUE, voltage > 9 ? HX8357_YELLOW: HX8357_CYAN);
  tft.print(voltage);

  tft.setCursor(CURRENT_COLUMN * char_width, y);
  tft.setTextColor(HX8357_BLACK, HX8357_WHITE);
  tft.print(current);

  tft.setCursor(LABEL_COLUMN * char_width, y);
  tft.setTextColor(HX8357_BLACK, HX8357_WHITE);
  tft.print(wire_name);
}

void setup(void) {
  /* initialize hardware */
  Serial.begin(9600);
  Serial.println("HX8357D Test!");

  tft.begin();
  tft.setRotation(1);           /* todo: experiment with this */
  screen_width = tft.width();
  uint16_t screen_height = tft.height();
  tft.setTextWrap(false);
  row_height = screen_height / (N_WIRES + 2);
  if (row_height > 30) {
    tft.setTextSize(2);
    char_width *= 2;
  }
  touch.begin(0x41);            /* default I2C address for touch reader */

  /* read diagnostics (optional but can help debug problems) */
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

  /* start with measurements display until the user selects a connector */
  selecting = false;
}

#define ABOVE_SELECTION 6
#define BELOW_SELECTION 6

void start_displaying_connector(int selected) {
  tft.fillScreen(HX8357_WHITE);
  tft.setTextColor(HX8357_BLUE);
  tft.drawRect(0, row_height, screen_width, row_height, HX8357_BLUE);
  tft.setCursor(0, row_height);
  tft.print(connectors[selected].label);
  for (unsigned int i = 0; i < 8; i++) {
    uint16_t y = (i + 1) * row_height;
    tft.drawRoundRect(NUMBER_COLUMN * char_width, y,
                      (VOLTAGE_COLUMN - NUMBER_COLUMN) * char_width, row_height - 2,
                      3, HX8357_BLACK);
    tft.drawRoundRect(VOLTAGE_COLUMN * char_width, y,
                      (CURRENT_COLUMN - VOLTAGE_COLUMN) * char_width, row_height - 2,
                      3, HX8357_BLACK);
    tft.drawRoundRect(CURRENT_COLUMN * char_width, y,
                      (LABEL_COLUMN - CURRENT_COLUMN) * char_width, row_height - 2,
                      3, HX8357_BLACK);
    tft.drawRoundRect(NUMBER_COLUMN * char_width, y,
                      screen_width - ((LABEL_COLUMN * char_width) + 2), row_height - 2,
                      3, HX8357_BLACK);
  }
  tft.drawRoundRect(NUMBER_COLUMN, row_height * 9,
                    screen_width, row_height,
                    3, HX8357_YELLOW);
  tft.setTextColor(HX8357_BLACK, HX8357_YELLOW);
  tft.print("Change connector");
}

void display_selection_list(unsigned int first,
                            uint16_t offset) {
}

void move_to_row(int i) {
}

void draw_label(int i, char *label, bool active) {
}

void loop() {
  int selected = unspecified_index;             /* which connector we are on */

  uint16_t x, y;
  uint8_t z;
  uint16_t old_x, old_y;
  bool old_touched;

  if (selecting) {
    /* use touchscreen to select connector by name */
    for (int i = 0; i < ABOVE_SELECTION+BELOW_SELECTION; i++) {
      int which = i;              /* todo: calculate this */
      move_to_row(i);
      draw_label(i, connectors[which].label, which == selected);
    }

    /* todo: find the real calls for this */

    bool touched = touch.touched();
    if (touched) {
      touch.readData(&x, &y, &z);
      if (old_touched) {
        selected += y - old_y;
      } else if (x <= select_column)
        {
          selected = y;         /* todo: scale this */
          selecting = false;
          start_displaying_connector(selected);
        }
    }
    old_x = x; old_y = y; old_touched = touched;
  } else {
    bool touched = touch.touched();
    if (touched) {
      touch.readData(&x, &y, &z);
      /* are we in the back button? */
      if (y > row_height * 8) {
        selecting = true;
        tft.fillScreen(HX8357_BLACK);
      } else {
        /* nothing to do here for now; if I fitted pass transistors or
           relays I might later make it possible to connect and
           disconnect lines */
      }
    }

    /* for each channel:
       read current and voltage
       cut off current if too high
       display current and voltage
    */
    for (unsigned int i = 0; i < 8; i++) {
      display_at(i,
                 labels[connectors[selected].wire_indices[i]],
                 analogRead(voltage_pins[i]),
                 analogRead(current_pins[i]));
    }
  }
}
