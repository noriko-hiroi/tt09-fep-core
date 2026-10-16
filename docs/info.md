<!---
This file is used to generate your project's documentation page.
--->

## How it works

Calculates prediction error (e = x - mu) and updates internal state mu using gradient descent.
Includes an adaptive suppression gate (alert_gate) to reduce learning rate during high-variance input.

## How to test

Apply 8-bit Q1.14 input values to ui_in and observe internal state mu on uo_out.

## External hardware

None required.
