# WoW-Forever-FindTreasureTracker
WoW Forever Addon for Dwarven prospectors.

# Find Treasure Tracker

A World of Warcraft addon built for chest hunters and Dwarven prospectors. **Find Treasure Tracker** logs every chest you open, separates stats between **Find Treasure Active** and **Find Treasure Inactive**, calculates Auction House and Vendor loot values, and celebrates high-slot procs with custom audio and visual effects.

---

## Features

* **Chest Rarity Tiers & Proc Tracking:** Automatically classifies opened chests by bonus loot slots above expected into **Legendary** (+4 or more slots), **Epic** (+3 slots), **Rare** (+2 slots), **Uncommon** (+1 slot), and **Common**.
* **Active vs. Inactive Comparison:** Tracks separate buckets for runs with *Find Treasure* active versus inactive, including proc rates, tier breakdowns, max slots seen, and average loot value comparisons.
* **Auction House & Vendor Valuation:** Calculates both vendor sell prices and live Auction House values (via **Auctionator**, **TradeSkillMaster**, or `GetAuctionBuyout`), highlighting your **Most Valuable Drop** and populating the **Top 5 of the Prospector's AH Haul** table in settings with full item hover tooltips.
* **Find Treasure Reminder:** Tints the minimap icon red and triggers a Raid Warning + audio cue if you try to open a chest without *Find Treasure* enabled.
* **Legendary Jackpot Celebration:** Fires a bottom-screen gold coin fountain, top-screen sparkle glow, and custom audio on Legendary finds (with a toggle in settings if you want to disable the coin fountain and secondary sound).
* **Draggable Minimap Button:** Hover for a full side-by-side breakdown of Active vs. Inactive stats, left-click to open settings, or right-click drag to position around the minimap.

---

## Slash Commands

All commands work with `/ftt` or `/ft`:

| Command | Description |
| :--- | :--- |
| `/ftt` | Open the Find Treasure Tracker settings panel. |
| `/ftt share` | Post your active *Find Treasure* stats summary to `/say`. |
| `/ftt log [chest]` | Print recent logged chest contents in chat (optionally filtered by chest name). |
| `/ftt compare` | Compare average loot value with *Find Treasure* Active vs. Inactive. |
| `/ftt testsound [tier]` | Preview the alert banner, sound, and effects (`uncommon`, `rare`, `epic`, or `legendary`). |
| `/ftt debug` | Toggle safe player spell/aura/loot event logging in chat. |
| `/ftt reset` | Reset all saved stats and chest logs (with confirmation prompt). |

---

## Installation

1. Download the latest release `.zip` (or clone this repository).
2. Extract the `FindTreasureTracker` folder into your World of Warcraft `Interface/AddOns/` directory so the path looks like:
   `World of Warcraft/.../Interface/AddOns/FindTreasureTracker/FindTreasureTracker.toc`
3. Restart WoW or type `/reload` in-game.

---

## Dwarven Support Fund

Pour a brew in this ol' prospector's mug:  
[https://buymeacoffee.com/pbg88](https://buymeacoffee.com/pbg88)
