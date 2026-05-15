# Items Network

Russian version: [README.ru.md](README.ru.md)

Items Network adds a cable-based virtual logistics system for items and fluids to Factorio 2.0, with item Quality support.

> Warning: this mod is currently in beta. Functionality, balance, and interfaces may change.

## Overview

The mod lets you build local cable-based item networks, connect terminals and machines to them, pull items from nearby chests, and route the required resources back into production without long inserter chains.

## Features

- Cable-based item network built from `Network cable`
- `Network fluid intake pipe`, which pulls fluids from connected pipes into virtual storage
- `Network fluid output pipe`, which outputs a selected fluid from the network into connected pipes
- `Network terminal` with a custom GUI for browsing and withdrawing items
- Circuit network output from terminals for reading current network contents
- `Network buffer chest`, which requests items from virtual storage and returns trash slots back into the network
- Automatic machine input feeding from network storage
- Full Quality support in storage, requests, GUI, and machine supply
- More even distribution of items across machines to reduce idle time and input overfill

## Entities

- Network cable
- Network terminal
- Network fluid intake pipe
- Network fluid output pipe
- Network buffer chest

## How It Works

1. Place a server.
2. Place network cables to assemble the network.
3. Connect a `Network terminal` to access the shared virtual storage.
4. Chests connect to the network automatically, and the network pulls items from them.
5. Insert a `Network fluid intake pipe` into the cable line and connect it to a fluid pipe to import fluids into the network.
6. Insert a `Network fluid output pipe` into the cable line, choose the required fluid in its interface, and output it into connected pipes.
7. Connect production machines so the network can refill their inputs automatically.
8. Use a `Network buffer chest` to request exact items from virtual storage.

## Quality Support

Items inside the network are tracked together with their quality level. The terminal GUI, machine supply logic, and `Network buffer chest` all work with quality-aware item stacks, including recipes that require a specific quality.

## Research and Recipes

The mod unlocks its devices through the `Item network` technology. After research, you can craft the full set of network entities from the logistics category.

## Notes

- Best suited for compact factory districts, controlled machine feeding, and local cable-based logistics.