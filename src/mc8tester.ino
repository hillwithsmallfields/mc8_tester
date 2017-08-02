// Touchscreen-based multi-connector voltage and current monitor

void setup(void) {
  /* initialize hardware */
  /* show selection screen */
}

void loop()
{
  if (selecting) {
    /* use touchscreen to select connector by name */
  } else {
    /* check touchscreen for commands */

    /* for each channel:
       read current and voltage
       cut off current if too high
       display current and voltage
    */
  }
}
