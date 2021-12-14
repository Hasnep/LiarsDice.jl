# LiarsDice.jl

A WIP simulation of the game [Liar's Dice](https://en.wikipedia.org/wiki/Dudo), also known as Dudo or Perudo.

To simulate 100 games where five of the same strategy play each other, run:

```julia
include("src/LiarsDice.jl")
strategies = [strategy_basic, strategy_basic, strategy_basic, strategy_basic, strategy_basic]
winners = [
    GameState(strategies; n_dice = 5, starting_player = mod(i, 1:length(strategies))) |> roll |> simulate for
    i = 1:100
]

# Plot number of wins
using Plots: bar
bar(
    [count(winners .== i) for i = 1:length(strategies)];
    orientation = :h,
    yticks = (1:length(strategies), 1:length(strategies)),
    yflip = true
)
```

To play a game against the basic strategy, run:

```julia
include("src/LiarsDice.jl")
strategies = [strategy_basic, strategy_basic, strategy_basic]
GameState(strategies; n_dice = 5, starting_player = 1) |> roll |> simulate
```
