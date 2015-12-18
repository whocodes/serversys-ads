# Server-Sys Ads
[![Build Status](https://travis-ci.org/whocodes/serversys-ads.svg?branch=master)](https://travis-ci.org/whocodes/serversys-ads)

This module is still unfinished until Server-Sys Web is available for module incorporation.

## Description
Server-Sys Ads is a simple module for Server-Sys that implements SQL based chat-only advertisements.

## Compatibility
* Any SourceMod compatible game.

## Features
* Cross-server/game chat advertisement support.
* Takes advantage of Server-Sys' SQL system.
* Many place-holder tags for real-time info display
	1. **{{SERVER_NAME}}** - the name of the current server defined in `configs/serversys/core.cfg`
	2. **{{SERVER_IP}}** - the IP of the current server defined in `configs/serversys/core.cfg`
	3. **{{SERVER_MAP}}** - the current map on the server
	4. **{{SERVER_NEXTMAP}}** - the next map on the server (or **undefined**)
	5. **{{PLAYER_NAME}}** - the name of the player the ad is being displayed to
	6. **{{VAR_COLOR}}** - the variable color phrase defined in `configs/serversys/ads.cfg`
	7. **{{DEF_COLOR}}** - the default color phrase defined in `configs/serversys/ads.cfg`
* Command for players to opt-out of advertisements.

## Requirements
* [Server-Sys](https://github.com/whocodes/serversys) and it's requirements
