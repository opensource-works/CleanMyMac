# Session flow audit

## Step 1 — Selective mode after scrolling

Health: Needs improvement.

The mode selector is outside the viewport, and the bottom of the page offers no route back to Cleaning or Pet / Kid. The screen can be mistaken for a standalone feature. Screenshot: `01-selective-scrolled-bottom.png`.

## Step 2 — Selective mode with return control

Health: Healthy.

A quiet, right-aligned **Back to modes** action appears after the primary button. It is visible at the bottom without competing with Start Selective Lock. Screenshot: `02-selective-bottom-with-return.png`.

## Step 3 — Returned to the mode selector

Health: Healthy.

Activating Back to modes scrolls directly to the three mode tabs and preserves the Selective selection. Screenshot: `03-selective-returned-to-tabs.png`.

## Step 4 — Missing Input Monitoring permission

Health: Healthy.

Clicking Start presents the permission error immediately, before any countdown begins. The alert exposes clearly labelled Settings and Cancel actions. Screenshot: `04-permission-alert-immediate.png`.

## Evidence limits

The Pet / Kid and Selective window-hiding behavior was verified through the activation-state implementation and unit coverage for the mode policy. A full live lock was not captured because doing so would intentionally block the computer input used for this audit.
