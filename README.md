# Items Network
[![Discord](https://img.shields.io/badge/Discord-join-5865F2?logo=discord&logoColor=white)](https://discord.gg/yqbfZegmm)

Items Network adds a local cable-based virtual logistics system for items and fluids to Factorio 2.0, with Quality support, power delivery through the network, player supply, scripted network inserters, and a network unloading train stop.


> Warning: this mod is currently in beta. Functionality, balance, and interfaces may change.

## Overview

The mod lets you build local item networks on cables, connect terminals and machines to them, pull items from nearby chests, transfer fluids, and return required resources back into production without long inserter chains. It also adds network inserters that can pull filtered items straight out of virtual storage and a dedicated train stop for network-driven unloading.

## How It Works

1. Place a server, which acts as the root node of the network.
2. Place network cables to assemble the network.
3. Place connectors under the server and under the machines you want to connect.
4. The network terminal provides access to the network inventory and settings for that network.
5. Chests connected with a connector automatically supply items into the network.
6. Fluid input and output entities interact with the network accordingly.
7. Connect production machines so the network automatically refills their inputs and pulls out the results.
8. Connect turrets if you want the network to refill their ammunition automatically.
9. Use the network inserter to move a filtered item from virtual storage into a machine, chest, or belt at the inserter drop position.
10. Use the bulk network inserter when you need the same behavior with larger stack transfers.
11. Use the network buffer chest to request exact items from virtual storage.
12. After researching `Player supply`, items requested by the player are delivered from the network on the same surface.
13. Research `Network power conductivity` if you want network cables to conduct electricity.
14. The production combinator lets you set items for production and their maximum amount, and outputs signals matching the shortage of those items.
15. Research `Network train unloading` to unlock a rail stop that unloads wagons from docked trains and refuels locomotives from the network.

## Supported Network Entities

- `Network terminal`: lets you inspect the network inventory and configure it.
- `Network inserter`: pulls one filtered item type from virtual storage and feeds it into the connected target.
- `Bulk network inserter`: same as the network inserter, but based on the bulk/stack inserter tier for larger transfers.
- `Network unloading train stop`: unloads wagons from docked trains and refuels locomotives from the network.
- `Network buffer chest`: requests items from virtual storage and returns trash slots back into the network.
- `Fluid input` and `Fluid output`: move fluids between pipes and the network.
- `Production combinator`: emits shortage signals so connected production can maintain a target stock.

## Quality Support

Items inside the network are tracked together with their quality level. The terminal interface, machine supply logic, and the network buffer chest all work with quality-aware stacks, including recipes that require a specific quality.

## Notes

- Best suited for compact production districts, controlled machine feeding, and local cable-based logistics.
- Network inserters are useful when you want direct filtered output from virtual storage into assemblers, belts, or dedicated buffer lines.
- The network unloading train stop is intended for rail-fed outposts where stopped trains should hand cargo to the network while locomotives are kept fueled.
- The terminal outputs circuit signals for the current amount of items stored in the network, so you can wire a machine to it and control production with enable or disable conditions.
- The production combinator is best used to set recipes on connected machines so the network can maintain a precise target stock of items.