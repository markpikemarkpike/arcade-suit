// Arcade Suit: the only settings most people need. Only Magic mode uses them.
#pragma once

// The Wi-Fi network the suit should join. Normally your own phone's hotspot.
//   iPhone: the name is in Settings > General > About > Name.
//           the password is in Settings > Personal Hotspot > Wi-Fi Password. Pick your own.
// Fill both in and a fresh install goes straight to your hotspot.
// Leave them empty and the suit asks you on first use, through its own little setup network.
// If you fill them in, do not commit this file to a public repo.
#define HOTSPOT_NAME ""
#define HOTSPOT_PASS ""

// The name of the suit's own setup network. It only appears when there is no hotspot to try.
// Its password is not here: each suit makes up its own on first boot and shows it on the M5Stack's screen.
#define SETUP_NETWORK_NAME "ArcadeSuit"
