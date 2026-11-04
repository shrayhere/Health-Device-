#ifndef BUTTON_H
#define BUTTON_H

#include <Arduino.h>

enum ButtonEvent {

  BTN_NONE = 0,

  BTN_SINGLE_CLICK,
  BTN_DOUBLE_CLICK,
  BTN_TRIPLE_CLICK,

  BTN_LONG_PRESS,
  BTN_HOLD_REPEAT,
  BTN_LOW_POWER_HOLD
};

namespace button {

  void begin();
  ButtonEvent update();

}

#endif // BUTTON_H