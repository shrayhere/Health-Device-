#include "button.h"
#include "config.h"

// ============================================================
// BUTTON STATE MACHINE
// ============================================================
//
// Supports:
//
// 1 click   -> SINGLE
// 2 clicks  -> DOUBLE
// 3 clicks  -> TRIPLE
//
// Long press and 3-second low-power hold remain separate.
//
// Single/double clicks wait for the double-click gap.
// Triple click is emitted immediately on the third release.
// ============================================================

enum InternalState {

  S_IDLE,

  S_DOWN,

  S_WAIT_CLICKS
};


static InternalState state =
    S_IDLE;


static unsigned long pressStart =
    0;


static unsigned long lastReleaseTime =
    0;


static bool longFired =
    false;


static bool lowPowerFired =
    false;


static int clickCount =
    0;


// ============================================================
// BEGIN
// ============================================================

namespace button {

void begin() {

  pinMode(
      PIN_BUTTON,
      INPUT_PULLUP
  );

  clickCount =
      0;

  state =
      S_IDLE;

  longFired =
      false;

  lowPowerFired =
      false;
}


// ============================================================
// UPDATE
// ============================================================

ButtonEvent update() {

  unsigned long now =
      millis();


  bool rawPressed =
      (
          digitalRead(PIN_BUTTON) ==
          LOW
      );


  // ----------------------------------------------------------
  // DEBOUNCE
  // ----------------------------------------------------------

  static bool stablePressed =
      false;

  static bool lastRawPressed =
      false;

  static unsigned long debounceStart =
      0;


  if (
      rawPressed !=
      lastRawPressed
  ) {

    lastRawPressed =
        rawPressed;

    debounceStart =
        now;
  }


  if (
      now - debounceStart >=
      BTN_DEBOUNCE_MS
  ) {

    stablePressed =
        rawPressed;
  }


  bool pressed =
      stablePressed;


  ButtonEvent result =
      BTN_NONE;


  // ==========================================================
  // STATE: IDLE
  // ==========================================================

  if (
      state ==
      S_IDLE
  ) {

    if (
        pressed
    ) {

      state =
          S_DOWN;

      pressStart =
          now;

      longFired =
          false;

      lowPowerFired =
          false;
    }
  }


  // ==========================================================
  // STATE: BUTTON DOWN
  // ==========================================================

  else if (
      state ==
      S_DOWN
  ) {

    if (
        pressed
    ) {

      unsigned long held =
          now -
          pressStart;


      // ------------------------------------------------------
      // 3 SECOND LOW POWER HOLD
      // ------------------------------------------------------

      if (
          held >=
          BTN_LOWPOWER_HOLD_MS &&
          !lowPowerFired
      ) {

        lowPowerFired =
            true;

        longFired =
            true;

        clickCount =
            0;

        result =
            BTN_LOW_POWER_HOLD;
      }


      // ------------------------------------------------------
      // LONG PRESS
      // ------------------------------------------------------

      else if (
          held >=
          BTN_LONGPRESS_MS &&
          !longFired &&
          !lowPowerFired
      ) {

        longFired =
            true;

        result =
            BTN_LONG_PRESS;
      }
    }


    else {

      // ------------------------------------------------------
      // BUTTON RELEASED
      // ------------------------------------------------------

      unsigned long held =
          now -
          pressStart;


      // ------------------------------------------------------
      // LOW POWER HOLD WAS ALREADY TRIGGERED
      // ------------------------------------------------------

      if (
          lowPowerFired
      ) {

        state =
            S_IDLE;

        clickCount =
            0;

        longFired =
            false;

        lowPowerFired =
            false;
      }


      // ------------------------------------------------------
      // LONG PRESS WAS ALREADY TRIGGERED
      // ------------------------------------------------------

      else if (
          longFired
      ) {

        state =
            S_IDLE;

        clickCount =
            0;

        longFired =
            false;

        lowPowerFired =
            false;
      }


      // ------------------------------------------------------
      // NORMAL SHORT CLICK
      // ------------------------------------------------------

      else if (
          held <
          BTN_LONGPRESS_MS
      ) {

        clickCount++;


        // ----------------------------------------------------
        // THIRD CLICK
        // ----------------------------------------------------
        //
        // Emit triple immediately.
        // There is no reason to wait another 300 ms after
        // the third click has already been completed.
        // ----------------------------------------------------

        if (
            clickCount >=
            3
        ) {

          clickCount =
              0;

          state =
              S_IDLE;

          lastReleaseTime =
              now;

          longFired =
              false;

          lowPowerFired =
              false;

          result =
              BTN_TRIPLE_CLICK;
        }


        // ----------------------------------------------------
        // FIRST / SECOND CLICK
        // ----------------------------------------------------

        else {

          lastReleaseTime =
              now;

          state =
              S_WAIT_CLICKS;
        }
      }
    }
  }


  // ==========================================================
  // STATE: WAITING FOR MORE CLICKS
  // ==========================================================

  else if (
      state ==
      S_WAIT_CLICKS
  ) {

    // --------------------------------------------------------
    // ANOTHER PRESS HAPPENED
    // --------------------------------------------------------

    if (
        pressed
    ) {

      if (
          now -
          lastReleaseTime <=
          BTN_DOUBLE_GAP_MS
      ) {

        state =
            S_DOWN;

        pressStart =
            now;

        longFired =
            false;

        lowPowerFired =
            false;
      }
    }


    // --------------------------------------------------------
    // NO ADDITIONAL CLICK BEFORE TIMEOUT
    // --------------------------------------------------------

    else if (
        now -
        lastReleaseTime >
        BTN_DOUBLE_GAP_MS
    ) {

      if (
          clickCount ==
          1
      ) {

        result =
            BTN_SINGLE_CLICK;
      }

      else if (
          clickCount ==
          2
      ) {

        result =
            BTN_DOUBLE_CLICK;
      }


      clickCount =
          0;

      state =
          S_IDLE;

      longFired =
          false;

      lowPowerFired =
          false;
    }
  }


  return result;
}

} // namespace button