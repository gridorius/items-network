# Items Network

Russian version: [README.ru.md](README.ru.md)

Items Network adds a cable-based virtual item logistics system for Factorio 2.0 with Quality support.

## Overview

Build local item networks with cables, connect terminals and machines to them, absorb items from adjacent chests, and route requested resources back into production without relying on long inserter chains.

## Features

- Cable-based item network built from `Network cable`
- `Absorber network cable` that pulls items from touching chests into virtual storage
- `Network terminal` with a custom GUI for browsing and withdrawing stored items
- Circuit output from terminals for reading current network contents
- `Network buffer chest` that requests items from virtual storage and pushes trash slots back into the network
- Automatic machine input feeding from network storage
- Quality-aware item storage, requests, GUI display, and machine supply
- Even distribution logic for machine input refills to reduce starvation and overfilling

## Included Entities

- Network cable
- Absorber network cable
- Network terminal
- Network buffer chest

## How It Works

1. Place network cables to form a connected cable segment.
2. Attach a network terminal to access the shared virtual inventory.
3. Place absorber cables next to chests to import items into the network.
4. Connect crafting machines to let the network keep their inputs topped up.
5. Use network buffer chests to request exact items from the virtual inventory.

## Quality Support

Items are tracked with their quality level inside the network. The terminal GUI, machine supply logic, and network buffer chest all work with quality-aware item stacks, including recipes that require a specific quality.

## Research And Recipes

The mod unlocks its devices through the `Item network` technology. After research, you can craft the full set of network entities from the logistics category.

## Notes

- Requires the built-in `quality` mod.
- Designed for Factorio 2.0.
- Best used for compact factory districts, controlled machine feeding, and cable-based local logistics.