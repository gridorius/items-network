# Items Network

Items Network adds a local cable-based virtual logistics system for items and fluids to Factorio 2.0, with Quality support, power delivery through the network, and player supply.

> Warning: this mod is currently in beta. Functionality, balance, and interfaces may change.

## Overview

The mod lets you build local item networks on cables, connect terminals and machines to them, pull items from nearby chests, transfer fluids, and return required resources back into production without long inserter chains.

## How It Works

1. Place a server, which acts as the root node of the network.
2. Place network cables to assemble the network.
3. Place connectors under the server and under the machines you want to connect.
4. The network terminal provides access to the network inventory and settings for that network.
5. Chests connected with a connector automatically supply items into the network.
6. Fluid input and output entities interact with the network accordingly.
7. Connect production machines so the network automatically refills their inputs and pulls out the results.
8. Connect turrets if you want the network to refill their ammunition automatically.
9. Use the network buffer chest to request exact items from virtual storage.
10. After researching `Player supply`, items requested by the player are delivered from the network on the same surface.
11. Research `Network power conductivity` if you want network cables to conduct electricity.
12. The production combinator lets you set items for production and their maximum amount, and outputs signals matching the shortage of those items.

## Quality Support

Items inside the network are tracked together with their quality level. The terminal interface, machine supply logic, and the network buffer chest all work with quality-aware stacks, including recipes that require a specific quality.

## Notes

- Best suited for compact production districts, controlled machine feeding, and local cable-based logistics.