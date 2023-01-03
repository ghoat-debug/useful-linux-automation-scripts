#!/bin/bash

# Turn the LED lights on
ddcutil --setvcp 10 00

# Pause for 1 second
sleep 1

# Turn the LED lights off
ddcutil --setvcp 10 80

# Pause for 1 second
sleep 1

# Repeat the pattern indefinitely
while true; do
  ddcutil --setvcp 10 00
  sleep 1
  ddcutil --setvcp 10 80
  sleep 1
done

