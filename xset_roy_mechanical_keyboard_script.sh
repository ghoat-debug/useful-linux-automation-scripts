#!/bin/bash

# Turn LED lights on
xset led on

# Wait for 1 second
sleep 1

# Turn LED lights off
xset led off

# Wait for 1 second
sleep 1

# Repeat the loop
while true; do
  # Turn LED lights on
  xset led on

  # Wait for 1 second
  sleep 1

  # Turn LED lights off
  xset led off

  # Wait for 1 second
  sleep 1
done

