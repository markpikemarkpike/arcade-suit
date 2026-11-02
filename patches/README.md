# About this patch

`webserver-timeouts.patch` changes `libraries/WebServer/src/Parsing.cpp` in the Arduino core for the ESP32.
That file is Copyright (c) 2015 Ivan Grokhotkov and is licensed under the GNU Lesser General Public License, version 2.1 or later.
The patch quotes a few lines of it for context, so the patch carries the same license. It is not covered by this repo's MIT license.

What it does: adds a 4 second limit to reading an upload, and stops the form parser after 4 empty passes.
