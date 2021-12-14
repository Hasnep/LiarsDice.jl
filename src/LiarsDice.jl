using StatsBase: modes

# Player
struct Player
    n_dice::Integer
    hand::Vector{Integer}
    alive::Bool
    strategy::Function

    Player(n, h, a, s) = new(n, h, a, s)
    Player(n, s) = new(n, [], true, s)
end

# Bid
struct Bid
    number::Integer
    value::Integer

    Bid(n, v) = v ∈ 1:6 ? new(n, v) : error("Value $v is not valid.")
    Bid() = new(0, 0)
end

Base.:(>)(x::Bid, y::Bid) = (y.number == 0 && y.value == 0) || (x.number > y.number) || (x.number == y.number && x.value > y.value)
Base.:(==)(x::Bid, y::Bid) = x.number == y.number && x.value == y.value

# Game state
struct GameState
    players::Vector{Player}
    turn::Integer
    bid::Bid

    GameState(players, turn, bid) = new(players, turn, bid)
    GameState(strategies; n_dice, starting_player) = new(Player.(n_dice, strategies), starting_player, Bid())
end

# View
struct View
    hand::Vector{Integer}
    n_dice::Vector{Integer}
    turn::Integer
    bid::Bid
    View(g, i) = new(g.players[i].hand, length.(getfield.(g.players, :hand)), g.turn, g.bid)
end

# Rolling
roll(n::Integer) = rand(1:6, n)
roll(p::Player) = Player(p.n_dice, roll(p.n_dice), p.alive, p.strategy)
roll(g::GameState) = GameState(roll.(g.players), g.turn, g.bid)

# Get players still in
get_alive_players(g::GameState) = filter(p -> p.alive, g.players)
get_n_alive_players(x) = length(get_alive_players(x))

# End turn
function next_player_index(g)::Integer
    n_players = length(g.players)
    turn = g.turn
    turn = mod(turn + 1, 1:n_players)
    while !(g.players[turn].alive)
        turn = mod(turn + 1, 1:n_players)
    end
    return turn
end
function previous_player_index(g)::Integer
    n_players = length(g.players)
    turn = g.turn
    turn = mod(turn - 1, 1:n_players)
    while !(g.players[turn].alive)
        turn = mod(turn - 1, 1:n_players)
    end
    return turn
end
end_turn(g) = GameState(g.players, next_player_index(g), g.bid)

# Count dice
get_all_dice(g) = vcat(getfield.(g.players, :hand)...)
count_dice(g, value) = count(get_all_dice(g) .== value)

# Remove dice
function remove_dice(p::Player)::Player
    new_n_dice = p.n_dice - 1
    return new_n_dice > 0 ? Player(new_n_dice, [], true, p.strategy) : Player(0, [], false, p.strategy)
end
remove_dice(players::Vector{Player}, player_index::Integer)::Vector{Player} =
    [i == player_index ? remove_dice(p) : p for (i, p) in enumerate(players)]

# Actions
raise(g::GameState, new_bid::Bid) = new_bid > g.bid ? (GameState(g.players, g.turn, new_bid) |> end_turn) : g
function doubt(g::GameState)
    if g.bid == Bid()
        return g
    else
        losing_player_index = count_dice(g, g.bid.value) >= g.bid.number ? g.turn : previous_player_index(g)
        g = GameState(remove_dice(g.players, losing_player_index), losing_player_index, Bid())
        g = g.players[losing_player_index].alive ? g : GameState(g.players, next_player_index(g), Bid())
        return g |> roll
    end
end


get_winner(g::GameState)::Union{Integer,Missing} =
    (get_n_alive_players(g) == 1) ? (findfirst(getfield.(g.players, :alive))) : missing

function simulate(g::GameState)::Integer
    while ismissing(get_winner(g))
        action = g.players[g.turn].strategy(View(g, g.turn))
        g = (action == Bid()) ? doubt(g) : raise(g, action)
    end
    return get_winner(g)
end




# Strategies
n_dice_other_players(v::View) = sum(v.n_dice) - length(v.hand)
random_raised_bid(v::View)::Bid = Bid(v.bid.number + 1, rand(1:6))

"""
Probability of getting at least n of a value when rolling m dice.

``p = \\frac{1}{6^m} \\sum_{i=n}^m \\binom{m}{i} 5^{m - i}``
"""
p(n, m) = n > m ? 0 : sum(binomial(m, i) * 5^(m - i) for i = n:m) / (6^m)

function strategy_basic(v::View)
    most_common_value_in_hand = maximum(modes(v.hand))
    if v.bid == Bid()
        return Bid(1, most_common_value_in_hand)
    else
        probability_of_current_bid_being_wrong = let v = v, bid = v.bid, hand = v.hand
            n_in_hand = count(hand .== bid.value)
            1 - p(bid.number - n_in_hand, n_dice_other_players(v))
        end

        proposed_new_bid_value = most_common_value_in_hand
        proposed_new_bid_number = v.bid.number + (v.bid.value >= proposed_new_bid_value)
        proposed_new_bid = Bid(proposed_new_bid_number, proposed_new_bid_value)
        probability_of_proposed_new_bid_being_right = let v = v, bid = proposed_new_bid, hand = v.hand
            n_in_hand = count(hand .== bid.value)
            p(bid.number - n_in_hand, n_dice_other_players(v))
        end

        return probability_of_proposed_new_bid_being_right >= probability_of_current_bid_being_wrong ? proposed_new_bid : Bid()
    end
end

function strategy_human(v::View)
    println("===")
    println(v.bid == Bid() ? "Opening bid" : "$(v.bid.number) $(v.bid.value)s")
    println("Hand: $(join(sort(v.hand), ' '))")
    println(join(v.n_dice, " "))
    input = readline()
    if length(input) == 0
        return Bid()
    else
        return Bid(parse.(Int, split(input, ","))...)
    end
end
