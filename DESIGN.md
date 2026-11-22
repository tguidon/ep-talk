---
name: EP Talk
description: A compact macOS console for the EP-2350 push-to-talk link.
colors:
  chassis: "#181E24"
  screen: "#0D1216"
  rule: "#323B43"
  text: "#EFF2F3"
  secondary: "#A3B2BF"
  ready: "#9CD9BF"
  signal: "#FFB870"
typography:
  display:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "34px"
    fontWeight: 600
    letterSpacing: "-1px"
  headline:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "28px"
    fontWeight: 500
    letterSpacing: "-0.45px"
  control:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "13px"
    fontWeight: 500
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "12px"
    fontWeight: 400
  label:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "10px"
    fontWeight: 600
    letterSpacing: "1.05px"
  reading:
    fontFamily: "SF Mono, ui-monospace, monospace"
    fontSize: "11px"
    fontWeight: 500
rounded:
  telemetry: "13px"
  meter-segment: "1.3px"
spacing:
  window-inline: "25px"
  telemetry-inset: "18px"
  readout-gap: "8px"
  meter-gap: "3px"
components:
  telemetry:
    backgroundColor: "{colors.screen}"
    textColor: "{colors.text}"
    rounded: "{rounded.telemetry}"
    padding: "{spacing.telemetry-inset}"
  arm:
    backgroundColor: "{colors.ready}"
    textColor: "{colors.screen}"
    typography: "{typography.control}"
  disarm:
    backgroundColor: "{colors.rule}"
    textColor: "{colors.text}"
    typography: "{typography.control}"
---

# Design System: EP Talk

## Overview

**Creative North Star: "Radio console"**

The interface takes its cues from compact NASA communications controls. A dark chassis holds an inset readout for link state and level. A few native controls put setup and changes within reach of the readout.

**Key Characteristics:**

- A status headline and a short line of guidance share the telemetry panel.
- Mint and amber convey operational states.
- Native menus, buttons and sheets handle configuration.

## Colors

Cool slate supports pale lettering and two signal colors.

### Primary

- **Link mint:** Marks a ready link, tints the Arm action and fills the normal range of the input meter.

### Secondary

- **Signal amber:** Marks transmitting or a condition that needs attention. It also marks high meter levels and setup messages.

### Neutral

- **Chassis slate:** Main window and sheet background.
- **Telemetry black:** Inset screen for the status headline and meter.
- **Slate rule:** Borders, dividers and unlit meter segments.
- **Pale text:** Primary headings and labels.
- **Cool secondary text:** Status guidance, quieter labels and inactive indicators.

**The Signal Color Rule.** Use mint and amber for a live state or an action tied to that state. Pair state color with a readable status.

## Typography

The system sans-serif supports the product name, state and instructions. System monospaced text separates the numeric level and shortcut from surrounding labels.

- **Display** (34 pt, semibold): Window name.
- **Headline** (28 pt, medium): Active status.
- **Control** (13 pt, medium; semibold for Arm): Configuration labels and main action.
- **Body** (12 pt, regular): Readout guidance.
- **Label** (10 pt, semibold, tracked uppercase): Input meter caption.
- **Reading** (11 pt, medium, monospaced): Level in dBFS. The shortcut uses a 13 pt monospaced label.

## Layout

The desktop console stacks the header, telemetry, configuration and footer with 25 pt side margins and a 510 pt minimum width. Configuration uses divided rows with labels at left and controls at right. The setup and shortcut recorder open as sheets.

## Elevation & Depth

The telemetry surface sits inward through a darker fill and a single slate border. The window and sheets carry the surrounding chassis color and use macOS chrome.

## Shapes

The telemetry panel has a 13 pt corner radius and a 1 pt outline. A 9 pt round lamp pairs with the state headline. The segmented meter repeats softly squared marks with 3 pt gaps. Buttons, menus, checkboxes and sheets retain their native shape.

## Components

### Arm and Disarm

Use the native prominent button with a power symbol and text. Mint identifies Arm. Slate identifies Disarm.

### Telemetry

Use one inset panel with 18 pt padding. The state headline pairs with the lamp and link symbol, with guidance underneath. Below the rule, pair a caption and dBFS value with the 32-segment meter. Expose the level and link as accessibility values.

### Audio Input and Shortcut

Use a native menu for available audio inputs and mark the selection with a checkmark. The shortcut button displays the binding and opens the recorder sheet. The recorder shows feedback where the user presses the combination.

### Setup Footer

Use a compact native button for Mic Setup and a checkbox for Open at login. Permission requests sit above this footer when access needs attention.

## Do's and Don'ts

### Do:

- Do keep the state name beside the lamp.
- Do use native controls for keyboard and focus behavior.

### Don't:

- Don't use the meter as a substitute for connection or transmission status.
